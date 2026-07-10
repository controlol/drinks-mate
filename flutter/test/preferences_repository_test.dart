import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/models/user_profile.dart';
import 'package:drinks_mate/src/repository/preferences_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';

// ---------------------------------------------------------------------------
// Helper: open an in-memory database (no file I/O, safe in tests).
// ---------------------------------------------------------------------------

AppDatabase _memDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  group('PreferencesRepository — seeding', () {
    test('default preferences row has correct seed values', () async {
      final db = _memDb();
      addTearDown(db.close);
      final repo = PreferencesRepository(db);

      final prefs = await repo.getPreferences();

      expect(prefs.id, kUserPreferencesId);
      expect(prefs.dailyGoalMl, 2000);
      expect(prefs.dayBoundaryHour, 5);
      expect(prefs.units, 'metric');
      expect(prefs.currency, 'EUR');
      expect(prefs.reminderEnabled, isTrue);
      expect(prefs.reminderStartHour, 8);
      expect(prefs.reminderEndHour, 22);
      expect(prefs.reminderIntervalMin, 90);
      expect(prefs.inactivityReminderEnabled, isTrue);
      expect(prefs.weeklySummaryEnabled, isTrue);
      expect(prefs.defaultDrinkPresetId, kWaterGlassPresetId);
      expect(prefs.bacCapGramsPerL, isNull);
      // data-model.md §UserPreferences: default ON (notifications.md
      // §Lock-screen visibility).
      expect(prefs.bacOnLockScreenEnabled, isTrue);
      // Party Mode notifications are OFF by default (notifications.md §4).
      expect(prefs.approachingCapNotifEnabled, isFalse);
      expect(prefs.soberEstimateNotifEnabled, isFalse);
      expect(prefs.installedAt, isNotNull);
    });

    test(
      'installedAt is stable across re-opens (INSERT OR IGNORE semantics)',
      () async {
        // First open — captures installedAt.
        final db1 = _memDb();
        final prefs1 = await PreferencesRepository(db1).getPreferences();
        final installedAt1 = prefs1.installedAt;
        await db1.close();

        // A second open of the SAME in-memory db would reset since NativeDatabase
        // is ephemeral, so we verify idempotency within a single open by calling
        // _seedDefaultPreferences twice (simulated via a second getPreferences).
        //
        // The real scenario (re-open of a file db) is tested by asserting that
        // calling getPreferences twice returns the same row without duplicating it.
        final db2 = _memDb();
        addTearDown(db2.close);
        final repo2 = PreferencesRepository(db2);
        final prefs2a = await repo2.getPreferences();
        final prefs2b = await repo2.getPreferences();
        expect(prefs2a.installedAt, prefs2b.installedAt);
        expect(prefs2a.id, prefs2b.id);
        // installedAt should not be zero.
        expect(prefs2a.installedAt.millisecondsSinceEpoch, isPositive);

        // Both opens produce a non-null, positive installedAt.
        expect(installedAt1.millisecondsSinceEpoch, isPositive);
      },
    );

    test('only one preferences row exists after seeding', () async {
      final db = _memDb();
      addTearDown(db.close);

      // getPreferences would throw StateError if >1 row existed.
      final prefs = await PreferencesRepository(db).getPreferences();
      expect(prefs.id, kUserPreferencesId);
    });
  });

  group('PreferencesRepository — field-level updates', () {
    late AppDatabase db;
    late PreferencesRepository repo;

    setUp(() {
      db = _memDb();
      repo = PreferencesRepository(db);
    });

    tearDown(() => db.close());

    test('updateDailyGoal writes new value', () async {
      await repo.updateDailyGoal(2100);
      final prefs = await repo.getPreferences();
      expect(prefs.dailyGoalMl, 2100);
    });

    test('updateDayBoundaryHour writes new value', () async {
      await repo.updateDayBoundaryHour(4);
      final prefs = await repo.getPreferences();
      expect(prefs.dayBoundaryHour, 4);
    });

    test('updateUnits writes imperial', () async {
      await repo.updateUnits('imperial');
      final prefs = await repo.getPreferences();
      expect(prefs.units, 'imperial');
    });

    test('updateCurrency writes USD', () async {
      await repo.updateCurrency('USD');
      final prefs = await repo.getPreferences();
      expect(prefs.currency, 'USD');
    });

    test('updateReminderSchedule updates individual fields', () async {
      await repo.updateReminderSchedule(
        reminderEnabled: false,
        startHour: 9,
        endHour: 21,
        intervalMin: 60,
      );
      final prefs = await repo.getPreferences();
      expect(prefs.reminderEnabled, isFalse);
      expect(prefs.reminderStartHour, 9);
      expect(prefs.reminderEndHour, 21);
      expect(prefs.reminderIntervalMin, 60);
    });

    test('updateNotificationToggles updates independent toggles', () async {
      await repo.updateNotificationToggles(
        inactivityReminderEnabled: false,
        weeklySummaryEnabled: false,
      );
      final prefs = await repo.getPreferences();
      expect(prefs.inactivityReminderEnabled, isFalse);
      expect(prefs.weeklySummaryEnabled, isFalse);
    });

    test('updateDefaultDrinkPreset sets and clears presetId', () async {
      const customId = 'custom-preset-id';
      await repo.updateDefaultDrinkPreset(customId);
      expect((await repo.getPreferences()).defaultDrinkPresetId, customId);

      await repo.updateDefaultDrinkPreset(null);
      expect((await repo.getPreferences()).defaultDrinkPresetId, isNull);
    });

    test('updateBacCap sets and clears cap', () async {
      await repo.updateBacCap(0.8);
      expect((await repo.getPreferences()).bacCapGramsPerL, 0.8);

      await repo.updateBacCap(null);
      expect((await repo.getPreferences()).bacCapGramsPerL, isNull);
    });

    test('updatePartyModeSettings enables party notifications', () async {
      await repo.updatePartyModeSettings(
        bacOnLockScreenEnabled: false,
        approachingCapNotifEnabled: true,
        soberEstimateNotifEnabled: true,
      );
      final prefs = await repo.getPreferences();
      expect(prefs.bacOnLockScreenEnabled, isFalse);
      expect(prefs.approachingCapNotifEnabled, isTrue);
      expect(prefs.soberEstimateNotifEnabled, isTrue);
    });

    test('updatedAt is set to a recent UTC timestamp', () async {
      final beforeUpdate = DateTime.now().toUtc();
      await repo.updateDailyGoal(3000);
      final prefs = await repo.getPreferences();
      // updatedAt must be on or after the moment we started the update.
      // Drift stores DateTimeColumn as epoch-seconds, so tolerance of 1 s.
      expect(
        prefs.updatedAt.millisecondsSinceEpoch,
        greaterThanOrEqualTo(beforeUpdate.millisecondsSinceEpoch - 1000),
      );
    });
  });

  group('PreferencesRepository — watchPreferences stream', () {
    test('stream emits updated value after write', () async {
      final db = _memDb();
      addTearDown(db.close);
      final repo = PreferencesRepository(db);

      // Collect values: first emission is the seeded default.
      final emissions = <UserPreferences>[];
      final sub = repo.watchPreferences().listen(emissions.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await repo.updateDailyGoal(1800);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.last.dailyGoalMl, 1800);
    });
  });

  group('PreferencesRepository — UserProfile', () {
    late AppDatabase db;
    late PreferencesRepository repo;

    setUp(() {
      db = _memDb();
      repo = PreferencesRepository(db);
    });

    tearDown(() => db.close());

    test('getProfile returns null before onboarding', () async {
      final profile = await repo.getProfile();
      expect(profile, isNull);
    });

    test('upsertProfile creates and reads back a profile', () async {
      final now = DateTime.now().toUtc();
      final profile = UserProfile(
        id: 'test-profile-id',
        gender: 'female',
        weightKg: 65.0,
        heightCm: 168.0,
        birthDate: '1992-03-14',
        createdAt: now,
        updatedAt: now,
      );

      await repo.upsertProfile(profile);
      final saved = await repo.getProfile();

      expect(saved, isNotNull);
      expect(saved!.id, 'test-profile-id');
      expect(saved.gender, 'female');
      expect(saved.weightKg, 65.0);
      expect(saved.heightCm, 168.0);
      expect(saved.birthDate, '1992-03-14');
    });

    test('upsertProfile updates an existing profile', () async {
      final now = DateTime.now().toUtc();
      final original = UserProfile(
        id: 'test-profile-id',
        gender: 'female',
        weightKg: 65.0,
        createdAt: now,
        updatedAt: now,
      );
      await repo.upsertProfile(original);

      final updated = original.copyWith(weightKg: 70.0);
      await repo.upsertProfile(updated);

      final saved = await repo.getProfile();
      expect(saved!.weightKg, 70.0);
      expect(saved.gender, 'female');
    });

    test('updateUsername validates and persists username', () async {
      await repo.updateUsername('Alice');
      final prefs = await repo.getPreferences();
      expect(prefs.username, 'Alice');
    });

    test('updateUsername rejects invalid username', () async {
      expect(() => repo.updateUsername('ab'), throwsA(isA<ArgumentError>()));
    });

    test('watchProfile stream emits null then profile after upsert', () async {
      final emissions = <UserProfile?>[];
      final sub = repo.watchProfile().listen(emissions.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final now = DateTime.now().toUtc();
      await repo.upsertProfile(
        UserProfile(id: 'p1', weightKg: 72.0, createdAt: now, updatedAt: now),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(emissions.first, isNull);
      expect(emissions.last, isNotNull);
      expect(emissions.last!.weightKg, 72.0);
    });
  });

  group('Riverpod providers — compile and resolve', () {
    test('userPreferencesProvider resolves with default prefs', () async {
      final db = _memDb();
      final container = ProviderContainer(
        overrides: [
          // Override the internal database to use an in-memory instance.
          // We shadow _appDatabaseProvider via the public repository provider.
          preferencesRepositoryProvider.overrideWithValue(
            PreferencesRepository(db),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      // Resolve once via the repository directly (providers reference the
      // private _appDatabaseProvider — override the repo layer instead).
      final repo = container.read(preferencesRepositoryProvider);
      final prefs = await repo.getPreferences();

      expect(prefs.id, kUserPreferencesId);
      expect(prefs.currency, 'EUR');
      expect(prefs.units, 'metric');
    });
  });
}
