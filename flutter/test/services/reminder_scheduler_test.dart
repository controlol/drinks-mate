import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/services/notification_service.dart';
import 'package:drinks_mate/src/services/reminder_scheduler.dart';

// ---------------------------------------------------------------------------
// Helper: open an in-memory database (no file I/O, safe in tests). Mirrors
// drinks_repository_test.dart / preferences_repository_test.dart.
// ---------------------------------------------------------------------------
AppDatabase _memDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// Creates and returns a non-alcoholic water preset via the real repository
/// (not a mock) — used as the reminder scheduler's `defaultDrinkPreset`.
Future<DrinkPreset> _waterPreset(
  DrinksRepository repo, {
  int volumeMl = 200,
}) {
  return repo.createPreset(
    name: 'Test Water',
    beverageType: BeverageType.water,
    volumeMl: volumeMl,
    iconKey: 'glass',
    iconColor: '#3b82f6',
    sortOrder: 1,
  );
}

/// UserPreferences fixture builder. All fields are required by the
/// constructor except username/defaultDrinkPresetId/bacCapGramsPerL — see
/// user_preferences.dart. installedAt defaults to a few days before the
/// `now` values used throughout this file (2026-01-14) so tests don't
/// accidentally trip the 7-day inactive-user silence rule unless explicitly
/// testing it.
UserPreferences _prefs({
  int dailyGoalMl = 2000,
  int dayBoundaryHour = 5,
  bool reminderEnabled = true,
  int reminderStartHour = 8,
  int reminderEndHour = 22,
  int reminderIntervalMin = 90,
  bool inactivityReminderEnabled = false,
  bool weeklySummaryEnabled = false,
  DateTime? installedAt,
}) {
  final now = DateTime.now().toUtc();
  return UserPreferences(
    id: 'test-prefs',
    dailyGoalMl: dailyGoalMl,
    dayBoundaryHour: dayBoundaryHour,
    units: 'metric',
    currency: 'EUR',
    reminderEnabled: reminderEnabled,
    reminderStartHour: reminderStartHour,
    reminderEndHour: reminderEndHour,
    reminderIntervalMin: reminderIntervalMin,
    inactivityReminderEnabled: inactivityReminderEnabled,
    weeklySummaryEnabled: weeklySummaryEnabled,
    bacOnLockScreenEnabled: false,
    approachingCapNotifEnabled: false,
    soberEstimateNotifEnabled: false,
    installedAt: installedAt ?? DateTime(2026, 1, 10),
    createdAt: now,
    updatedAt: now,
  );
}

/// Returns the subset of `svc.scheduled` belonging to the hydration batch
/// (slot ids are `kHydrationReminderNotificationId * 1000 + i`).
Iterable<({int id, DateTime scheduledTime, String body})> _hydrationSlots(
  FakeNotificationService svc,
) =>
    svc.scheduled
        .where((e) => e.id ~/ 1000 == kHydrationReminderNotificationId)
        .map((e) => (id: e.id, scheduledTime: e.scheduledTime, body: e.body));

void main() {
  // A fixed midweek Wednesday, well within the default 08:00–22:00 active
  // hours and within the default 05:00 day-boundary window.
  final midWeekAfternoon = DateTime(2026, 1, 14, 14, 0);

  group('ReminderScheduler — hydration reminder', () {
    late AppDatabase db;
    late DrinksRepository repo;
    late FakeNotificationService svc;
    late ReminderScheduler scheduler;

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
      svc = FakeNotificationService();
      scheduler = ReminderScheduler(svc, repo);
    });

    tearDown(() => db.close());

    test(
      '1. enabled, mid-window, below goal (zero intake) → schedules a '
      'non-empty hydration batch',
      () async {
        final preset = await _waterPreset(repo);

        await scheduler.reschedule(
          prefs: _prefs(),
          defaultDrinkPreset: preset,
          now: midWeekAfternoon,
        );

        final slots = _hydrationSlots(svc).toList();
        expect(slots, isNotEmpty);
        expect(slots.every((s) => s.body.isNotEmpty), isTrue);
      },
    );

    test(
      '1b. quick-log action label uses the beverage-type noun ("water"), '
      'not the preset display name ("Test Water") — notifications.md §Notification '
      'quick-log action names the example "Log water · 200 ml"',
      () async {
        final preset = await _waterPreset(repo); // preset.name == 'Test Water'

        await scheduler.reschedule(
          prefs: _prefs(),
          defaultDrinkPreset: preset,
          now: midWeekAfternoon,
        );

        final hydrationEntries = svc.scheduled
            .where((e) => e.id ~/ 1000 == kHydrationReminderNotificationId);
        expect(hydrationEntries, isNotEmpty);
        for (final entry in hydrationEntries) {
          expect(entry.quickLogActionLabel, 'Log water · 200 ml');
        }
      },
    );

    test('2. reminderEnabled=false → hydration batch is cancelled', () async {
      final preset = await _waterPreset(repo);

      await scheduler.reschedule(
        prefs: _prefs(reminderEnabled: false),
        defaultDrinkPreset: preset,
        now: midWeekAfternoon,
      );

      expect(_hydrationSlots(svc), isEmpty);
      expect(
        svc.cancelled,
        contains(kHydrationReminderNotificationId * 1000),
      );
    });

    test(
      '3. goal already met today → hydration reminders are cancelled, not '
      'scheduled',
      () async {
        final preset = await _waterPreset(repo, volumeMl: 2000);
        // Log enough non-alcoholic intake today (day window for
        // midWeekAfternoon, boundary=5, is [Jan14 05:00, Jan15 05:00)) to
        // reach the default 2000 ml goal.
        await repo.logDrink(
          preset: preset,
          consumedAt: DateTime(2026, 1, 14, 10, 0),
        );

        await scheduler.reschedule(
          prefs: _prefs(),
          defaultDrinkPreset: preset,
          now: midWeekAfternoon,
        );

        expect(_hydrationSlots(svc), isEmpty);
        expect(
          svc.cancelled,
          contains(kHydrationReminderNotificationId * 1000),
        );
      },
    );

    test(
      '4. inactive-user silence (installedAt >7 days ago, no drinks at all) '
      '→ hydration reminders cancelled even though enabled and goal not met',
      () async {
        final preset = await _waterPreset(repo);

        await scheduler.reschedule(
          prefs: _prefs(
            installedAt: midWeekAfternoon.subtract(const Duration(days: 10)),
          ),
          defaultDrinkPreset: preset,
          now: midWeekAfternoon,
        );

        expect(_hydrationSlots(svc), isEmpty);
        expect(
          svc.cancelled,
          contains(kHydrationReminderNotificationId * 1000),
        );
      },
    );

    test(
      '5. reset-on-log: earliest scheduled slot is not before '
      'consumedAt + reminderIntervalMin',
      () async {
        final preset = await _waterPreset(repo); // 200 ml, well below goal
        final consumedAt = DateTime(2026, 1, 14, 13, 50); // 10 min before now
        await repo.logDrink(preset: preset, consumedAt: consumedAt);

        await scheduler.reschedule(
          prefs: _prefs(reminderIntervalMin: 90),
          defaultDrinkPreset: preset,
          now: midWeekAfternoon, // 14:00
        );

        final slots = _hydrationSlots(svc).toList();
        expect(slots, isNotEmpty);
        final earliest = slots
            .map((s) => s.scheduledTime)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        final earliestAllowed = consumedAt.add(const Duration(minutes: 90));

        expect(
          !earliest.isBefore(earliestAllowed),
          isTrue,
          reason: 'earliest slot $earliest must not be before '
              '$earliestAllowed (consumedAt + reminderIntervalMin)',
        );
      },
    );

    test(
      '6a. toggle enabled→disabled→enabled: reschedule reacts immediately '
      'each time, and re-enabling does not leave the batch stuck off',
      () async {
        final preset = await _waterPreset(repo);

        await scheduler.reschedule(
          prefs: _prefs(reminderEnabled: true),
          defaultDrinkPreset: preset,
          now: midWeekAfternoon,
        );
        expect(_hydrationSlots(svc), isNotEmpty);

        await scheduler.reschedule(
          prefs: _prefs(reminderEnabled: false),
          defaultDrinkPreset: preset,
          now: midWeekAfternoon,
        );
        expect(_hydrationSlots(svc), isEmpty);
        expect(
          svc.cancelled,
          contains(kHydrationReminderNotificationId * 1000),
        );

        await scheduler.reschedule(
          prefs: _prefs(reminderEnabled: true),
          defaultDrinkPreset: preset,
          now: midWeekAfternoon,
        );
        expect(_hydrationSlots(svc), isNotEmpty);
      },
    );
  });

  group('ReminderScheduler — inactivity reminder', () {
    late AppDatabase db;
    late DrinksRepository repo;
    late FakeNotificationService svc;
    late ReminderScheduler scheduler;

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
      svc = FakeNotificationService();
      scheduler = ReminderScheduler(svc, repo);
    });

    tearDown(() => db.close());

    test(
      '6b. toggle enabled→disabled→enabled reacts immediately each time '
      '(kInactivityReminderNotificationId)',
      () async {
        await scheduler.reschedule(
          prefs: _prefs(inactivityReminderEnabled: true),
          now: DateTime(2026, 1, 14, 9, 0),
        );
        expect(
          svc.scheduled.any((e) => e.id == kInactivityReminderNotificationId),
          isTrue,
        );

        await scheduler.reschedule(
          prefs: _prefs(inactivityReminderEnabled: false),
          now: DateTime(2026, 1, 14, 9, 0),
        );
        expect(
          svc.scheduled.any((e) => e.id == kInactivityReminderNotificationId),
          isFalse,
        );
        expect(svc.cancelled, contains(kInactivityReminderNotificationId));

        await scheduler.reschedule(
          prefs: _prefs(inactivityReminderEnabled: true),
          now: DateTime(2026, 1, 14, 9, 0),
        );
        expect(
          svc.scheduled.any((e) => e.id == kInactivityReminderNotificationId),
          isTrue,
        );
      },
    );

    test(
      '7a. fires once at noon (12:00) when noon is within active hours',
      () async {
        await scheduler.reschedule(
          prefs: _prefs(inactivityReminderEnabled: true),
          now: DateTime(2026, 1, 14, 9, 0), // before noon, same day
        );

        final entry = svc.scheduled
            .singleWhere((e) => e.id == kInactivityReminderNotificationId);
        expect(entry.scheduledTime, DateTime(2026, 1, 14, 12, 0));
      },
    );

    test(
      '7b. noon snaps to the active-hours start when 12:00 is outside '
      'active hours (reminderStartHour=13)',
      () async {
        await scheduler.reschedule(
          prefs: _prefs(
            inactivityReminderEnabled: true,
            reminderStartHour: 13,
            reminderEndHour: 22,
          ),
          now: DateTime(2026, 1, 14, 9, 0),
        );

        final entry = svc.scheduled
            .singleWhere((e) => e.id == kInactivityReminderNotificationId);
        expect(entry.scheduledTime, DateTime(2026, 1, 14, 13, 0));
      },
    );

    test(
      '7c. inactivityReminderEnabled=false → cancelled instead of scheduled',
      () async {
        await scheduler.reschedule(
          prefs: _prefs(inactivityReminderEnabled: false),
          now: DateTime(2026, 1, 14, 9, 0),
        );

        expect(
          svc.scheduled.any((e) => e.id == kInactivityReminderNotificationId),
          isFalse,
        );
        expect(svc.cancelled, contains(kInactivityReminderNotificationId));
      },
    );

    test(
      '7d. noon snaps to the active-hours START even when active hours '
      'close before noon (reminderEndHour=10) — notifications.md names only '
      '"start", never "the nearer edge"',
      () async {
        await scheduler.reschedule(
          prefs: _prefs(
            inactivityReminderEnabled: true,
            reminderStartHour: 6,
            reminderEndHour: 10,
          ),
          now: DateTime(2026, 1, 14, 3, 0),
        );

        final entry = svc.scheduled
            .singleWhere((e) => e.id == kInactivityReminderNotificationId);
        expect(entry.scheduledTime, DateTime(2026, 1, 14, 6, 0));
      },
    );

    test(
      '7e. fireTime is anchored on the day-boundary-aligned "today", not the '
      'raw calendar date — a pre-boundary reschedule() call still fires at '
      'noon of the correct logical day',
      () async {
        // 02:00 with the default 05:00 boundary is still logically
        // "yesterday" (dayWindow shifts back) — fireTime must still land on
        // today's calendar noon (12:00), not get pushed to tomorrow.
        await scheduler.reschedule(
          prefs: _prefs(inactivityReminderEnabled: true),
          now: DateTime(2026, 1, 14, 2, 0),
        );

        final entry = svc.scheduled
            .singleWhere((e) => e.id == kInactivityReminderNotificationId);
        expect(entry.scheduledTime, DateTime(2026, 1, 14, 12, 0));
      },
    );

    test(
      '8. suppressed once a drink is logged today, even with the toggle on '
      '(notifications.md §Anti-spam principles)',
      () async {
        final preset = await _waterPreset(repo);
        await repo.logDrink(
          preset: preset,
          consumedAt: DateTime(2026, 1, 14, 10, 0), // today
        );

        await scheduler.reschedule(
          prefs: _prefs(inactivityReminderEnabled: true),
          defaultDrinkPreset: preset,
          now: midWeekAfternoon,
        );

        expect(
          svc.scheduled.any((e) => e.id == kInactivityReminderNotificationId),
          isFalse,
        );
        expect(svc.cancelled, contains(kInactivityReminderNotificationId));
      },
    );

    test(
      '11a. inactive-user silence also cancels the inactivity reminder',
      () async {
        await scheduler.reschedule(
          prefs: _prefs(
            inactivityReminderEnabled: true,
            installedAt: midWeekAfternoon.subtract(const Duration(days: 10)),
          ),
          now: midWeekAfternoon,
        );

        expect(
          svc.scheduled.any((e) => e.id == kInactivityReminderNotificationId),
          isFalse,
        );
        expect(svc.cancelled, contains(kInactivityReminderNotificationId));
      },
    );
  });

  group('ReminderScheduler — weekly summary', () {
    late AppDatabase db;
    late DrinksRepository repo;
    late FakeNotificationService svc;
    late ReminderScheduler scheduler;

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
      svc = FakeNotificationService();
      scheduler = ReminderScheduler(svc, repo);
    });

    tearDown(() => db.close());

    test(
      '6c. toggle enabled→disabled→enabled reacts immediately each time '
      '(kWeeklySummaryNotificationId)',
      () async {
        await scheduler.reschedule(
          prefs: _prefs(weeklySummaryEnabled: true),
          now: midWeekAfternoon,
        );
        expect(
          svc.scheduled.any((e) => e.id == kWeeklySummaryNotificationId),
          isTrue,
        );

        await scheduler.reschedule(
          prefs: _prefs(weeklySummaryEnabled: false),
          now: midWeekAfternoon,
        );
        expect(
          svc.scheduled.any((e) => e.id == kWeeklySummaryNotificationId),
          isFalse,
        );
        expect(svc.cancelled, contains(kWeeklySummaryNotificationId));

        await scheduler.reschedule(
          prefs: _prefs(weeklySummaryEnabled: true),
          now: midWeekAfternoon,
        );
        expect(
          svc.scheduled.any((e) => e.id == kWeeklySummaryNotificationId),
          isTrue,
        );
      },
    );

    test(
      '9a. schedules for the next Sunday at 20:00 when 20:00 is within '
      'active hours',
      () async {
        // midWeekAfternoon = Wed 2026-01-14 14:00 → next Sunday = 2026-01-18.
        await scheduler.reschedule(
          prefs: _prefs(weeklySummaryEnabled: true),
          now: midWeekAfternoon,
        );

        final entry = svc.scheduled
            .singleWhere((e) => e.id == kWeeklySummaryNotificationId);
        expect(entry.scheduledTime.weekday, DateTime.sunday);
        expect(entry.scheduledTime, DateTime(2026, 1, 18, 20, 0));
      },
    );

    test(
      '9b. 20:00 snaps to the active-hours end when active hours close '
      'earlier (reminderEndHour=18)',
      () async {
        await scheduler.reschedule(
          prefs: _prefs(
            weeklySummaryEnabled: true,
            reminderStartHour: 8,
            reminderEndHour: 18,
          ),
          now: midWeekAfternoon,
        );

        final entry = svc.scheduled
            .singleWhere((e) => e.id == kWeeklySummaryNotificationId);
        expect(entry.scheduledTime, DateTime(2026, 1, 18, 18, 0));
      },
    );

    test(
      '10a. 0/7 days on goal → exact "slow week" body '
      '(notifications.md §Weekly summary)',
      () async {
        // No drink entries at all in the ISO week (Mon Jan 12 – Sun Jan 18)
        // that the Jan 18 20:00 firing reports on.
        await scheduler.reschedule(
          prefs: _prefs(weeklySummaryEnabled: true),
          now: midWeekAfternoon,
        );

        final entry = svc.scheduled
            .singleWhere((e) => e.id == kWeeklySummaryNotificationId);
        expect(
          entry.body,
          'A slow week — every day is a fresh start. Tap to see your chart.',
        );
      },
    );

    test(
      '10b. 7/7 days on goal → exact "perfect week" body '
      '(notifications.md §Weekly summary)',
      () async {
        final preset = await _waterPreset(repo, volumeMl: 2000);
        // ISO week Mon 2026-01-12 – Sun 2026-01-18 (the week the Jan 18
        // 20:00 firing reports on). Log a goal-meeting entry on each day.
        for (var day = 12; day <= 18; day++) {
          await repo.logDrink(
            preset: preset,
            consumedAt: DateTime(2026, 1, day, 10, 0),
          );
        }

        await scheduler.reschedule(
          prefs: _prefs(weeklySummaryEnabled: true),
          defaultDrinkPreset: preset,
          now: midWeekAfternoon,
        );

        final entry = svc.scheduled
            .singleWhere((e) => e.id == kWeeklySummaryNotificationId);
        expect(entry.body, 'Perfect week: 7/7 days at goal 💧 nice.');
      },
    );

    test(
      '11b. inactive-user silence also cancels the weekly summary',
      () async {
        await scheduler.reschedule(
          prefs: _prefs(
            weeklySummaryEnabled: true,
            installedAt: midWeekAfternoon.subtract(const Duration(days: 10)),
          ),
          now: midWeekAfternoon,
        );

        expect(
          svc.scheduled.any((e) => e.id == kWeeklySummaryNotificationId),
          isFalse,
        );
        expect(svc.cancelled, contains(kWeeklySummaryNotificationId));
      },
    );
  });
}
