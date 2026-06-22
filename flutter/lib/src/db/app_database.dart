import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/drink_entry_table.dart';
import 'tables/drink_preset_table.dart';
import 'tables/user_preferences_table.dart';
import 'tables/user_profile_table.dart';

part 'app_database.g.dart';

/// Stable UUID for "Glass of water" — referenced by UserPreferences later.
const String kWaterGlassPresetId = 'f47ac10b-58cc-4372-a567-0e02b2c3d001';

/// Well-known primary key for the UserPreferences singleton.
///
/// Using a fixed id enforces the singleton at the storage layer (INSERT OR
/// IGNORE on a known PK). Not a random UUID — this is intentional (C1 allows
/// well-known ids for singleton records).
const String kUserPreferencesId = 'preferences-singleton-v1';

/// Phase-1 Drift database — schema version 3.
///
/// v1 (issue #1): empty schema baseline.
/// v2 (issue #2): DrinkPreset + DrinkEntry tables + default-preset seeding.
/// v3 (issue #9): UserProfiles + UserPreferences tables + preferences seeding.
///
/// Phase-2-only entities (Account / Friendship / ShareSetting) must never
/// appear here (C0/C1).
///
/// Drift row types are named [DrinkPresetRow] / [DrinkEntryRow] /
/// [UserProfileRow] / [UserPreferencesRow] (via @DataClassName) to avoid name
/// collisions with the pure-Dart domain models in lib/src/models/.
@DriftDatabase(
  tables: [DrinkPresets, DrinkEntries, UserProfiles, UserPreferencesTable],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Add an `if (from < N)` block for each schema version bump.
          // Each block must be cumulative — a user upgrading directly from v1
          // to v3 must run BOTH the v1→v2 and v2→v3 blocks in sequence.
          if (from < 2) {
            await m.createTable(drinkPresets);
            await m.createTable(drinkEntries);
          }
          if (from < 3) {
            await m.createTable(userProfiles);
            await m.createTable(userPreferencesTable);
          }
        },
        beforeOpen: (_) async {
          await _seedMissingDefaultPresets();
          await _seedDefaultPreferences();
        },
      );

  // ---------------------------------------------------------------------------
  // Seeding — F14 default non-alcoholic presets
  // ---------------------------------------------------------------------------

  /// Idempotently inserts any missing default presets (F14).
  ///
  /// Runs in [beforeOpen] so it fires on both fresh install (after onCreate)
  /// and after an upgrade from v1 (after onUpgrade). Uses INSERT OR IGNORE so
  /// existing rows — including user-edited defaults — are left untouched.
  Future<void> _seedMissingDefaultPresets() async {
    final now = DateTime.now().toUtc();
    final companions = _defaultPresetCompanions(now);
    await batch((b) {
      b.insertAll(drinkPresets, companions, mode: InsertMode.insertOrIgnore);
    });
  }

  static List<DrinkPresetsCompanion> _defaultPresetCompanions(DateTime now) => [
        _preset(
          id: kWaterGlassPresetId,
          name: 'Glass of water',
          beverageType: 'water',
          volumeMl: 200,
          iconKey: 'glass',
          iconColor: '#3b82f6',
          sortOrder: 1,
          now: now,
        ),
        _preset(
          id: 'f47ac10b-58cc-4372-a567-0e02b2c3d002',
          name: 'Bottle of water (0.5L)',
          beverageType: 'water',
          volumeMl: 500,
          iconKey: 'bottle',
          iconColor: '#3b82f6',
          sortOrder: 2,
          now: now,
        ),
        _preset(
          id: 'f47ac10b-58cc-4372-a567-0e02b2c3d003',
          name: 'Can of water (0.33L)',
          beverageType: 'water',
          volumeMl: 330,
          iconKey: 'can',
          iconColor: '#3b82f6',
          sortOrder: 3,
          now: now,
        ),
        _preset(
          id: 'f47ac10b-58cc-4372-a567-0e02b2c3d004',
          name: 'Glass of tea',
          beverageType: 'tea',
          volumeMl: 250,
          iconKey: 'mug',
          iconColor: '#15803d',
          sortOrder: 4,
          now: now,
        ),
        _preset(
          id: 'f47ac10b-58cc-4372-a567-0e02b2c3d005',
          name: 'Cup of coffee',
          beverageType: 'coffee',
          volumeMl: 200,
          iconKey: 'mug',
          iconColor: '#92400e',
          sortOrder: 5,
          now: now,
        ),
        _preset(
          id: 'f47ac10b-58cc-4372-a567-0e02b2c3d006',
          name: 'Espresso',
          beverageType: 'coffee',
          volumeMl: 30,
          iconKey: 'small_cup',
          iconColor: '#92400e',
          sortOrder: 6,
          now: now,
        ),
        _preset(
          id: 'f47ac10b-58cc-4372-a567-0e02b2c3d007',
          name: 'Glass of juice',
          beverageType: 'juice',
          volumeMl: 200,
          iconKey: 'glass',
          iconColor: '#ea580c',
          sortOrder: 7,
          now: now,
        ),
        _preset(
          id: 'f47ac10b-58cc-4372-a567-0e02b2c3d008',
          name: 'Glass of lemonade',
          beverageType: 'soft_drink',
          volumeMl: 200,
          iconKey: 'glass',
          iconColor: '#7c3aed',
          sortOrder: 8,
          now: now,
        ),
        _preset(
          id: 'f47ac10b-58cc-4372-a567-0e02b2c3d009',
          name: 'Glass of milk',
          beverageType: 'milk',
          volumeMl: 200,
          iconKey: 'glass',
          iconColor: '#d1d5db',
          sortOrder: 9,
          now: now,
        ),
        _preset(
          id: 'f47ac10b-58cc-4372-a567-0e02b2c3d010',
          name: 'Alcohol-free beer (0.33L)',
          beverageType: 'non_alcoholic_beer',
          volumeMl: 330,
          iconKey: 'beer_glass',
          iconColor: '#b45309',
          sortOrder: 10,
          now: now,
        ),
      ];

  static DrinkPresetsCompanion _preset({
    required String id,
    required String name,
    required String beverageType,
    required int volumeMl,
    required String iconKey,
    required String iconColor,
    required int sortOrder,
    required DateTime now,
  }) =>
      DrinkPresetsCompanion.insert(
        id: id,
        name: name,
        beverageType: beverageType,
        volumeMl: volumeMl,
        iconKey: iconKey,
        iconColor: iconColor,
        isUserCreated: false,
        sortOrder: sortOrder,
        createdAt: now,
        updatedAt: now,
      );

  // ---------------------------------------------------------------------------
  // Seeding — UserPreferences singleton (issue #9)
  // ---------------------------------------------------------------------------

  /// Idempotently inserts the [UserPreferences] singleton on every open.
  ///
  /// Uses INSERT OR IGNORE so existing rows (including user-edited fields) are
  /// left untouched. [installedAt] is captured at first-open time and never
  /// changes because subsequent opens are ignored (D3 migration strategy).
  Future<void> _seedDefaultPreferences() async {
    final now = DateTime.now().toUtc();
    final companion = UserPreferencesTableCompanion.insert(
      id: kUserPreferencesId,
      // 2 000 ml placeholder; onboarding updates this via weightKg × 30.
      dailyGoalMl: 2000,
      dayBoundaryHour: const Value(5),
      units: const Value('metric'),
      currency: const Value('EUR'),
      reminderEnabled: true,
      reminderStartHour: const Value(8),
      reminderEndHour: const Value(22),
      reminderIntervalMin: const Value(90),
      inactivityReminderEnabled: true,
      weeklySummaryEnabled: true,
      defaultDrinkPresetId: const Value(kWaterGlassPresetId),
      bacOnLockScreenEnabled: true,
      // Party Mode notifications are OFF by default (notifications.md §4).
      approachingCapNotifEnabled: false,
      soberEstimateNotifEnabled: false,
      installedAt: now.millisecondsSinceEpoch,
      createdAt: now,
      updatedAt: now,
    );
    await into(
      userPreferencesTable,
    ).insert(companion, mode: InsertMode.insertOrIgnore);
  }

  // ---------------------------------------------------------------------------
  // DrinkPreset queries
  // ---------------------------------------------------------------------------

  Stream<List<DrinkPresetRow>> watchVisiblePresets() => (select(drinkPresets)
        ..where((t) => t.isHidden.equals(false) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();

  Future<DrinkPresetRow?> getPresetById(String id) =>
      (select(drinkPresets)..where((t) => t.id.equals(id))).getSingleOrNull();

  // ---------------------------------------------------------------------------
  // DrinkEntry queries
  // ---------------------------------------------------------------------------

  /// Insert a new drink entry (snapshot semantics).
  Future<void> insertDrinkEntry(DrinkEntriesCompanion companion) =>
      into(drinkEntries).insert(companion);

  /// Reactive stream of the sum of [volumeMl] for live entries within
  /// [start, end) (both UTC) whose [beverageType] is in [allowedTypes].
  ///
  /// [allowedTypes] must be the canonical stored strings (e.g. 'water').
  /// Pass only non-alcoholic types to get the hydration total — alcoholic
  /// entries must never contribute to the daily-water goal (data-model.md
  /// §BeverageType: "the two flows are strictly disjoint").
  Stream<int> watchTotalMlInWindow(
    DateTime startUtc,
    DateTime endUtc,
    List<String> allowedTypes,
  ) {
    final expr = drinkEntries.volumeMl.sum();
    final query = selectOnly(drinkEntries)
      ..addColumns([expr])
      ..where(
        drinkEntries.deletedAt.isNull() &
            drinkEntries.consumedAt.isBiggerOrEqualValue(startUtc) &
            drinkEntries.consumedAt.isSmallerThanValue(endUtc) &
            drinkEntries.beverageType.isIn(allowedTypes),
      );
    return query.watchSingle().map((row) => row.read(expr) ?? 0);
  }

  // ---------------------------------------------------------------------------
  // UserPreferences queries
  // ---------------------------------------------------------------------------

  /// Reactive stream of the singleton [UserPreferencesRow].
  Stream<UserPreferencesRow> watchPreferences() => (select(
        userPreferencesTable,
      )..where((t) => t.id.equals(kUserPreferencesId)))
          .watchSingle();

  /// One-shot read of the singleton [UserPreferencesRow].
  Future<UserPreferencesRow> getPreferences() => (select(
        userPreferencesTable,
      )..where((t) => t.id.equals(kUserPreferencesId)))
          .getSingle();

  /// Partial update of the singleton preferences row.
  Future<void> updatePreferences(UserPreferencesTableCompanion companion) =>
      (update(
        userPreferencesTable,
      )..where((t) => t.id.equals(kUserPreferencesId)))
          .write(companion);

  // ---------------------------------------------------------------------------
  // UserProfile queries
  // ---------------------------------------------------------------------------

  /// Reactive stream of the first live [UserProfileRow] (null if none exists).
  Stream<UserProfileRow?> watchProfile() => (select(
        userProfiles,
      )..where((t) => t.deletedAt.isNull()))
          .watchSingleOrNull();

  /// One-shot read of the first live profile (null if none exists).
  Future<UserProfileRow?> getProfile() => (select(
        userProfiles,
      )..where((t) => t.deletedAt.isNull()))
          .getSingleOrNull();

  /// Insert or replace the user profile by id.
  Future<void> upsertProfile(UserProfilesCompanion companion) =>
      into(userProfiles).insertOnConflictUpdate(companion);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'drinks_mate.db'));
    return NativeDatabase.createInBackground(file);
  });
}
