// Regression tests for issue #95's remediation: AppShell invalidates
// [todayTotalMlProvider] on every app resume so the day-window UI
// recomputes "now" (see navigation/shell.dart). [reminderReschedulerProvider]
// also watches [todayTotalMlProvider] to re-run [ReminderScheduler.reschedule]
// whenever the total actually changes (a log/delete). A plain `ref.watch`
// would rebuild on the resume-triggered resubscription too — even when the
// resubscribed stream re-emits the exact same total — re-anchoring the
// hydration reminder to that resume moment, which notifications.md
// §Scheduling reserves for "logging a drink". These prove the
// `_todayTotalMlValueProvider` wrapper in providers.dart suppresses the
// no-op rebuild while still reacting to a genuine value change — and that
// pairing the total with [todayDayStartProvider] means a genuine
// day-boundary rollover still notifies even when the total happens to
// repeat (e.g. a zero-intake streak), which a total-value-only suppression
// would otherwise silently swallow.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/services/notification_service.dart';
import 'package:drinks_mate/src/services/reminder_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts [reschedule] calls instead of exercising real scheduling logic —
/// the provider-rebuild count is what this test cares about, not
/// [ReminderScheduler]'s own behaviour (covered by reminder_scheduler_test.dart).
/// Extends (rather than implements) [ReminderScheduler] since its
/// `_notifications`/`_drinks` fields are library-private and can't be
/// satisfied from outside `reminder_scheduler.dart` — the dummy super-call
/// args below are never touched because [reschedule] is fully overridden.
class _CountingReminderScheduler extends ReminderScheduler {
  _CountingReminderScheduler(super.notifications, super.drinks);

  int rescheduleCalls = 0;

  @override
  Future<void> reschedule({
    required UserPreferences prefs,
    DrinkPreset? defaultDrinkPreset,
    DateTime? now,
  }) async {
    rescheduleCalls++;
  }
}

UserPreferences _prefs() {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  return UserPreferences(
    id: kUserPreferencesId,
    username: 'tester',
    dailyGoalMl: 2000,
    dayBoundaryHour: 5,
    units: 'metric',
    currency: 'EUR',
    reminderEnabled: true,
    reminderStartHour: 8,
    reminderEndHour: 22,
    reminderIntervalMin: 90,
    inactivityReminderEnabled: false,
    weeklySummaryEnabled: false,
    bacOnLockScreenEnabled: false,
    approachingCapNotifEnabled: false,
    soberEstimateNotifEnabled: false,
    alcoholicPresetsAlwaysVisible: true,
    installedAt: epoch,
    createdAt: epoch,
    updatedAt: epoch,
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
      'reminderReschedulerProvider does not re-run reschedule() when '
      'todayTotalMlProvider is invalidated but re-emits the same total '
      '(app-resume day-window refresh, issue #95), but does re-run it when '
      'the total genuinely changes', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final scheduler = _CountingReminderScheduler(
      FakeNotificationService(),
      DrinksRepository(db),
    );
    var total = 0;

    final container = ProviderContainer(
      overrides: [
        userPreferencesProvider.overrideWith((ref) => Stream.value(_prefs())),
        defaultDrinkPresetProvider.overrideWith((ref) async => null),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        todayTotalMlProvider.overrideWith((ref) => Stream.value(total)),
      ],
    );
    addTearDown(container.dispose);

    // Keep reminderReschedulerProvider alive, mirroring _AppGate in
    // app.dart — a provider nobody watches never initializes. Riverpod only
    // rebuilds a dirty provider when it's next read/watched (pull-based),
    // not the instant an upstream dependency's Future resolves — so each
    // step below awaits the upstream future to let the new value land, then
    // explicitly `container.read`s reminderReschedulerProvider to force the
    // (possible) rebuild before inspecting the call count.
    container.listen(reminderReschedulerProvider, (_, __) {});
    await container.read(userPreferencesProvider.future);
    await container.read(defaultDrinkPresetProvider.future);
    await container.read(todayTotalMlProvider.future);
    container.read(reminderReschedulerProvider);
    final baseline = scheduler.rescheduleCalls;
    expect(baseline, 1, reason: 'initial settle should reschedule once');

    // Simulate AppShell._invalidateDayWindowProviders on resume: the
    // total is unchanged, only the subscription is fresh.
    container.invalidate(todayTotalMlProvider);
    await container.read(todayTotalMlProvider.future);
    container.read(reminderReschedulerProvider);

    expect(
      scheduler.rescheduleCalls,
      baseline,
      reason: 'an unchanged total must not re-anchor the hydration '
          'reminder to the resume moment',
    );

    // A genuine total change (a drink logged/deleted) must still
    // re-trigger reschedule().
    total = 500;
    container.invalidate(todayTotalMlProvider);
    await container.read(todayTotalMlProvider.future);
    container.read(reminderReschedulerProvider);

    expect(
      scheduler.rescheduleCalls,
      baseline + 1,
      reason: 'a real total change must still re-run reschedule()',
    );
  });

  test(
      'reminderReschedulerProvider still re-runs reschedule() on a genuine '
      'day-boundary rollover even when the total re-emits an identical '
      'value (e.g. 0 ml -> 0 ml on a zero-intake streak) — '
      'ReminderScheduler places only a single one-time notification for the '
      'daily inactivity reminder per reschedule() call, so it depends on '
      'reschedule() running again at least once per day', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final scheduler = _CountingReminderScheduler(
      FakeNotificationService(),
      DrinksRepository(db),
    );
    var dayStart = DateTime(2026, 7, 19, 5);

    final container = ProviderContainer(
      overrides: [
        userPreferencesProvider.overrideWith((ref) => Stream.value(_prefs())),
        defaultDrinkPresetProvider.overrideWith((ref) async => null),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        todayTotalMlProvider.overrideWith((ref) => Stream.value(0)),
        todayDayStartProvider.overrideWith((ref) => dayStart),
      ],
    );
    addTearDown(container.dispose);

    container.listen(reminderReschedulerProvider, (_, __) {});
    await container.read(userPreferencesProvider.future);
    await container.read(defaultDrinkPresetProvider.future);
    await container.read(todayTotalMlProvider.future);
    container.read(reminderReschedulerProvider);
    final baseline = scheduler.rescheduleCalls;
    expect(baseline, 1, reason: 'initial settle should reschedule once');

    // Simulate AppShell._invalidateDayWindowProviders on a resume that
    // genuinely crosses a day boundary: the total happens to stay at 0 ml
    // (a zero-intake streak), but the day window has advanced.
    dayStart = dayStart.add(const Duration(days: 1));
    container.invalidate(todayTotalMlProvider);
    container.invalidate(todayDayStartProvider);
    await container.read(todayTotalMlProvider.future);
    container.read(reminderReschedulerProvider);

    expect(
      scheduler.rescheduleCalls,
      baseline + 1,
      reason: 'a genuine day-boundary rollover must re-run reschedule() '
          'even when the total happens to repeat, or the once-daily '
          'inactivity reminder never gets placed for the new day',
    );
  });
}
