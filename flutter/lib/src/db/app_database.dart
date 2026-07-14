import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/drink_entry_table.dart';
import 'tables/drink_preset_table.dart';
import 'tables/meal_table.dart';
import 'tables/party_session_price_table.dart';
import 'tables/party_session_table.dart';
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
const String kUserPreferencesId = 'a0000000-0000-0000-0000-000000000001';

/// Phase-1 Drift database — schema version 5.
///
/// v1 (issue #1): empty schema baseline.
/// v2 (issue #2): DrinkPreset + DrinkEntry tables + default-preset seeding.
/// v3 (issue #9): UserProfiles + UserPreferences tables + preferences seeding.
/// (issue #16): added 4 default alcoholic presets to beforeOpen seeding;
///   no DDL change → schema stays at v3.
/// v4 (issue #21): PartySessions + PartySessionPrices + Meals tables;
///   DrinkEntries gains partySessionId/priceTokens/tokenValueMinor/
///   tokenValueCurrency columns.
/// v5 (issue #68 / PR #69 review remediation): UserPreferences gains
///   alcoholicPresetsAlwaysVisible (default true) — governs whether
///   ManageDrinksScreen shows alcoholic presets unconditionally or only
///   while a party session is active.
///
/// Phase-2-only entities (Account / Friendship / ShareSetting) must never
/// appear here (C0/C1).
///
/// Drift row types are named [DrinkPresetRow] / [DrinkEntryRow] /
/// [UserProfileRow] / [UserPreferencesRow] / [PartySessionRow] /
/// [PartySessionPriceRow] / [MealRow] (via @DataClassName) to avoid name
/// collisions with the pure-Dart domain models in lib/src/models/.
@DriftDatabase(
  tables: [
    DrinkPresets,
    DrinkEntries,
    UserProfiles,
    UserPreferencesTable,
    PartySessions,
    PartySessionPrices,
    Meals,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Add an `if (from < N)` block for each schema version bump.
          // Each block must be cumulative — a user upgrading directly from v1
          // to v5 must run every earlier block in sequence.
          if (from < 2) {
            await m.createTable(drinkPresets);
            await m.createTable(drinkEntries);
          }
          if (from < 3) {
            await m.createTable(userProfiles);
            await m.createTable(userPreferencesTable);
          }
          if (from < 4) {
            await m.createTable(partySessions);
            await m.createTable(partySessionPrices);
            await m.createTable(meals);
            await m.addColumn(drinkEntries, drinkEntries.partySessionId);
            await m.addColumn(drinkEntries, drinkEntries.priceTokens);
            await m.addColumn(drinkEntries, drinkEntries.tokenValueMinor);
            await m.addColumn(drinkEntries, drinkEntries.tokenValueCurrency);
          }
          if (from < 5) {
            await m.addColumn(
              userPreferencesTable,
              userPreferencesTable.alcoholicPresetsAlwaysVisible,
            );
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
        // Alcoholic defaults — visible only when Party Mode is active (F14).
        // Colours from BeverageType.defaultIconColor.
        _preset(
          id: 'f47ac10b-58cc-4372-a567-0e02b2c3d011',
          name: 'Small beer (0.2L)',
          beverageType: 'beer',
          volumeMl: 200,
          abvPercent: 5.0,
          iconKey: 'plastic_cup',
          iconColor: '#d97706',
          sortOrder: 11,
          now: now,
        ),
        _preset(
          id: 'f47ac10b-58cc-4372-a567-0e02b2c3d012',
          name: 'Beer (0.33L)',
          beverageType: 'beer',
          volumeMl: 330,
          abvPercent: 5.0,
          iconKey: 'beer_glass',
          iconColor: '#d97706',
          sortOrder: 12,
          now: now,
        ),
        _preset(
          id: 'f47ac10b-58cc-4372-a567-0e02b2c3d013',
          name: 'Glass of wine',
          beverageType: 'wine',
          volumeMl: 175,
          abvPercent: 12.0,
          iconKey: 'wine_glass',
          iconColor: '#be185d',
          sortOrder: 13,
          now: now,
        ),
        _preset(
          id: 'f47ac10b-58cc-4372-a567-0e02b2c3d014',
          name: 'Shot of spirit',
          beverageType: 'spirit',
          volumeMl: 30,
          abvPercent: 40.0,
          iconKey: 'shot_glass',
          iconColor: '#0369a1',
          sortOrder: 14,
          now: now,
        ),
      ];

  static DrinkPresetsCompanion _preset({
    required String id,
    required String name,
    required String beverageType,
    required int volumeMl,
    double? abvPercent,
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
        abvPercent: Value(abvPercent),
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
      // data-model.md §UserPreferences / notifications.md §Lock-screen
      // visibility: default ON — we surface the choice without recommending
      // either side, but the seed itself defaults to showing BAC.
      bacOnLockScreenEnabled: true,
      // Party Mode notifications are OFF by default (notifications.md §4).
      approachingCapNotifEnabled: false,
      soberEstimateNotifEnabled: false,
      // Default ON — alcoholic presets are always visible in Manage Drinks
      // unless the user opts into session-only visibility (features.md F14).
      alcoholicPresetsAlwaysVisible: const Value(true),
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

  /// One-shot read of the most recent live entry's [consumedAt], across every
  /// beverage type (alcoholic entries count as engagement too). Null if the
  /// user has never logged a drink.
  ///
  /// Used by the reminder scheduler for the inactive-user silence check
  /// (notifications.md §Inactive-user silence: `last_engagement` is the most
  /// recent `DrinkEntry.consumedAt`, any type).
  Future<DateTime?> getLatestDrinkConsumedAt() async {
    final row = await (select(drinkEntries)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.consumedAt)])
          ..limit(1))
        .getSingleOrNull();
    return row?.consumedAt;
  }

  /// One-shot sum of [volumeMl] for live entries within [startUtc, endUtc)
  /// whose [beverageType] is in [allowedTypes]. Same filter as
  /// [watchTotalMlInWindow], but a single read for scheduling-time queries
  /// that don't need a live subscription.
  Future<int> getTotalMlInWindow(
    DateTime startUtc,
    DateTime endUtc,
    List<String> allowedTypes,
  ) async {
    final expr = drinkEntries.volumeMl.sum();
    final query = selectOnly(drinkEntries)
      ..addColumns([expr])
      ..where(
        drinkEntries.deletedAt.isNull() &
            drinkEntries.consumedAt.isBiggerOrEqualValue(startUtc) &
            drinkEntries.consumedAt.isSmallerThanValue(endUtc) &
            drinkEntries.beverageType.isIn(allowedTypes),
      );
    final row = await query.getSingle();
    return row.read(expr) ?? 0;
  }

  /// One-shot read of `(consumedAt, volumeMl)` pairs for live entries within
  /// [startUtc, endUtc) whose [beverageType] is in [allowedTypes]. Same filter
  /// as [watchEntriesInWindow], for one-shot multi-day aggregation (e.g. the
  /// weekly-summary ISO-week goal count).
  Future<List<(DateTime, int)>> getEntriesInWindow(
    DateTime startUtc,
    DateTime endUtc,
    List<String> allowedTypes,
  ) async {
    final rows = await (select(drinkEntries)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.consumedAt.isBiggerOrEqualValue(startUtc) &
                t.consumedAt.isSmallerThanValue(endUtc) &
                t.beverageType.isIn(allowedTypes),
          ))
        .get();
    return rows.map((r) => (r.consumedAt, r.volumeMl)).toList();
  }

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

  /// Reactive stream of `(consumedAt, volumeMl)` pairs for live entries within
  /// `[startUtc, endUtc)` whose [beverageType] is in [allowedTypes].
  ///
  /// Use this for multi-day aggregations (e.g. 7-day stats) where the caller
  /// groups/bucketes the rows in Dart after loading.
  Stream<List<(DateTime, int)>> watchEntriesInWindow(
    DateTime startUtc,
    DateTime endUtc,
    List<String> allowedTypes,
  ) {
    final query = select(drinkEntries)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.consumedAt.isBiggerOrEqualValue(startUtc) &
            t.consumedAt.isSmallerThanValue(endUtc) &
            t.beverageType.isIn(allowedTypes),
      );
    return query.watch().map(
          (rows) => rows.map((r) => (r.consumedAt, r.volumeMl)).toList(),
        );
  }

  /// Reactive stream of full [DrinkEntryRow]s within `[startUtc, endUtc)`
  /// whose [beverageType] is in [allowedTypes], ordered newest-first.
  ///
  /// Used by the S6 Today Drinks Log screen to show entries the user can
  /// edit or soft-delete.
  Stream<List<DrinkEntryRow>> watchEntriesInWindowFull(
    DateTime startUtc,
    DateTime endUtc,
    List<String> allowedTypes,
  ) {
    return (select(drinkEntries)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.consumedAt.isBiggerOrEqualValue(startUtc) &
                t.consumedAt.isSmallerThanValue(endUtc) &
                t.beverageType.isIn(allowedTypes),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.consumedAt)]))
        .watch();
  }

  /// Partial update of a [DrinkEntryRow]: only [volumeMl] and/or [consumedAt]
  /// may be changed (log immutability — snapshot fields are never rewritten).
  ///
  /// Always bumps [updatedAt] to [updatedAtUtc].
  Future<void> updateDrinkEntryPartial(
    String id, {
    int? volumeMl,
    DateTime? consumedAtUtc,
    required DateTime updatedAtUtc,
  }) {
    final companion = DrinkEntriesCompanion(
      volumeMl: volumeMl != null ? Value(volumeMl) : const Value.absent(),
      consumedAt:
          consumedAtUtc != null ? Value(consumedAtUtc) : const Value.absent(),
      updatedAt: Value(updatedAtUtc),
    );
    return (update(
      drinkEntries,
    )..where((t) => t.id.equals(id)))
        .write(companion);
  }

  /// Soft-deletes a [DrinkEntryRow] by setting [deletedAt] = [deletedAtUtc].
  ///
  /// The row is never hard-deleted (F7 — soft-delete rule).
  Future<void> softDeleteDrinkEntry(String id, DateTime deletedAtUtc) {
    final companion = DrinkEntriesCompanion(
      deletedAt: Value(deletedAtUtc),
      updatedAt: Value(deletedAtUtc),
    );
    return (update(
      drinkEntries,
    )..where((t) => t.id.equals(id)))
        .write(companion);
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
  Stream<UserProfileRow?> watchProfile() => (select(userProfiles)
        ..where((t) => t.deletedAt.isNull())
        ..limit(1))
      .watchSingleOrNull();

  /// One-shot read of the first live profile (null if none exists).
  Future<UserProfileRow?> getProfile() => (select(userProfiles)
        ..where((t) => t.deletedAt.isNull())
        ..limit(1))
      .getSingleOrNull();

  /// Insert or replace the user profile by id.
  Future<void> upsertProfile(UserProfilesCompanion companion) =>
      into(userProfiles).insertOnConflictUpdate(companion);

  // ---------------------------------------------------------------------------
  // DrinkPreset CRUD (issue #16)
  // ---------------------------------------------------------------------------

  /// All non-deleted presets (including hidden) ordered by [sortOrder].
  /// Used by the "Manage drinks" settings UI.
  Stream<List<DrinkPresetRow>> watchAllPresets() => (select(drinkPresets)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();

  /// Non-deleted, non-hidden alcoholic presets ordered by [sortOrder].
  /// Used by Party Mode (log-drink picker — party-session.md §Price overrides
  /// explicitly excludes hidden presets).
  ///
  /// [alcoholicTypes] is the list of stored beverage-type strings to include
  /// (derived from [BeverageType] at the repository layer so this method stays
  /// free of domain-model imports).
  Stream<List<DrinkPresetRow>> watchAlcoholicPresets(
    List<String> alcoholicTypes,
  ) {
    return (select(drinkPresets)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.isHidden.equals(false) &
                t.beverageType.isIn(alcoholicTypes),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Insert a new user-created preset.
  Future<void> insertPreset(DrinkPresetsCompanion companion) =>
      into(drinkPresets).insert(companion);

  /// Highest [sortOrder] among non-deleted presets, or null if none exist.
  ///
  /// A `COUNT` of non-deleted presets is *not* a safe stand-in for this —
  /// [softDeletePreset] leaves the row in place (only [deletedAt] is set), so
  /// the count of live presets can be lower than the highest sortOrder still
  /// in use. See [reorderPresets]'s doc comment for the same MAX-vs-COUNT
  /// distinction.
  Future<int?> getMaxPresetSortOrder() async {
    final maxSortOrder = drinkPresets.sortOrder.max();
    final query = selectOnly(drinkPresets)
      ..addColumns([maxSortOrder])
      ..where(drinkPresets.deletedAt.isNull());
    final row = await query.getSingle();
    return row.read(maxSortOrder);
  }

  /// Partial update of a preset row. Only fields wrapped in [Value] are written.
  /// Returns the number of rows affected (0 if [id] not found).
  Future<int> updatePresetFields(String id, DrinkPresetsCompanion companion) =>
      (update(drinkPresets)..where((t) => t.id.equals(id))).write(companion);

  /// Sets [isHidden] to [hidden] for the given preset id.
  Future<void> setPresetHidden(String id, bool hidden, DateTime now) =>
      (update(drinkPresets)..where((t) => t.id.equals(id))).write(
        DrinkPresetsCompanion(isHidden: Value(hidden), updatedAt: Value(now)),
      );

  /// Soft-deletes a preset by setting [deletedAt].
  Future<void> softDeletePreset(String id, DateTime now) =>
      (update(drinkPresets)..where((t) => t.id.equals(id))).write(
        DrinkPresetsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );

  /// Bulk-updates [sortOrder] (and [updatedAt]) for every non-deleted preset,
  /// in a single transaction. Ids in [orderedIds] receive sortOrder 1..N (in
  /// the order given); any other non-deleted preset not in [orderedIds] keeps
  /// its relative order and is appended after, at N+1... This renumbers the
  /// *entire* non-deleted set — including seeded defaults not passed in — so
  /// a partial [orderedIds] can never collide with an untouched preset's
  /// existing sortOrder.
  ///
  /// Throws [ArgumentError] if [orderedIds] contains duplicates, or
  /// [StateError] if it contains an id that does not exist or is deleted.
  Future<void> reorderPresets(List<String> orderedIds, DateTime now) =>
      transaction(() async {
        if (orderedIds.toSet().length != orderedIds.length) {
          throw ArgumentError.value(
            orderedIds,
            'orderedIds',
            'Contains duplicate ids',
          );
        }

        final all = await (select(drinkPresets)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
        final validIds = all.map((r) => r.id).toSet();
        if (!orderedIds.every(validIds.contains)) {
          throw StateError(
            'orderedIds contains an id that does not exist or is deleted.',
          );
        }

        final movedIds = orderedIds.toSet();
        final remainingIds =
            all.map((r) => r.id).where((id) => !movedIds.contains(id));
        final finalOrder = [...orderedIds, ...remainingIds];

        for (var i = 0; i < finalOrder.length; i++) {
          await (update(
            drinkPresets,
          )..where((t) => t.id.equals(finalOrder[i])))
              .write(
            DrinkPresetsCompanion(
              sortOrder: Value(i + 1),
              updatedAt: Value(now),
            ),
          );
        }
      });

  // ---------------------------------------------------------------------------
  // PartySession queries (issue #21)
  // ---------------------------------------------------------------------------

  /// Reactive stream of the current open session (`endedAt IS NULL`), or null.
  /// At most one live row can match — enforced by [PartySessionRepository].
  Stream<PartySessionRow?> watchActiveSession() => (select(partySessions)
        ..where((t) => t.endedAt.isNull() & t.deletedAt.isNull())
        ..limit(1))
      .watchSingleOrNull();

  /// One-shot read of the current open session, or null.
  Future<PartySessionRow?> getActiveSession() => (select(partySessions)
        ..where((t) => t.endedAt.isNull() & t.deletedAt.isNull())
        ..limit(1))
      .getSingleOrNull();

  Future<PartySessionRow?> getPartySessionById(String id) =>
      (select(partySessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// The most recently *ended* session (`endedAt IS NOT NULL`), ordered by
  /// `endedAt` descending — feeds the "copy prices from last session"
  /// shortcut (party-session.md §Starting a session — pricing prompt).
  Future<PartySessionRow?> getMostRecentEndedSession() => (select(partySessions)
        ..where((t) => t.endedAt.isNotNull() & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.endedAt)])
        ..limit(1))
      .getSingleOrNull();

  Future<void> insertPartySession(PartySessionsCompanion companion) =>
      into(partySessions).insert(companion);

  /// Partial update of a session row (end it, toggle prices, edit tokens).
  /// Returns the number of rows affected (0 if [id] not found).
  Future<int> updatePartySessionFields(
    String id,
    PartySessionsCompanion companion,
  ) =>
      (update(partySessions)..where((t) => t.id.equals(id))).write(companion);

  // ---------------------------------------------------------------------------
  // PartySessionPrice queries (issue #21)
  // ---------------------------------------------------------------------------

  /// Live (non-deleted) price overrides for [sessionId].
  Future<List<PartySessionPriceRow>> getSessionPrices(String sessionId) =>
      (select(partySessionPrices)
            ..where(
              (t) => t.partySessionId.equals(sessionId) & t.deletedAt.isNull(),
            ))
          .get();

  /// Reactive stream of [getSessionPrices] — feeds the session-prices control
  /// ("off — using regular prices" label) and the "Manage prices" sheet.
  Stream<List<PartySessionPriceRow>> watchSessionPrices(String sessionId) =>
      (select(partySessionPrices)
            ..where(
              (t) => t.partySessionId.equals(sessionId) & t.deletedAt.isNull(),
            ))
          .watch();

  Future<void> insertSessionPrice(PartySessionPricesCompanion companion) =>
      into(partySessionPrices).insert(companion);

  Future<void> updateSessionPriceById(
    String id,
    PartySessionPricesCompanion companion,
  ) =>
      (update(
        partySessionPrices,
      )..where((t) => t.id.equals(id)))
          .write(companion);

  // ---------------------------------------------------------------------------
  // Meal queries (issue #21)
  // ---------------------------------------------------------------------------

  Future<void> insertMeal(MealsCompanion companion) =>
      into(meals).insert(companion);

  /// Reactive stream of live meals for [sessionId], oldest first.
  Stream<List<MealRow>> watchSessionMeals(String sessionId) => (select(meals)
        ..where(
          (t) => t.partySessionId.equals(sessionId) & t.deletedAt.isNull(),
        )
        ..orderBy([(t) => OrderingTerm.asc(t.eatenAt)]))
      .watch();

  // ---------------------------------------------------------------------------
  // DrinkEntry — Party Session queries (issue #21)
  // ---------------------------------------------------------------------------

  /// Reactive stream of live entries belonging to [sessionId], oldest first.
  Stream<List<DrinkEntryRow>> watchSessionEntries(String sessionId) =>
      (select(drinkEntries)
            ..where(
              (t) => t.partySessionId.equals(sessionId) & t.deletedAt.isNull(),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.consumedAt)]))
          .watch();

  /// Most recently consumed live alcoholic entry in [sessionId], or null if
  /// none — used to compute the lazy 12h auto-end mark.
  Future<DrinkEntryRow?> getLastAlcoholicEntryInSession(
    String sessionId,
    List<String> alcoholicTypes,
  ) =>
      (select(drinkEntries)
            ..where(
              (t) =>
                  t.partySessionId.equals(sessionId) &
                  t.deletedAt.isNull() &
                  t.beverageType.isIn(alcoholicTypes),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.consumedAt)])
            ..limit(1))
          .getSingleOrNull();

  /// Live alcoholic entries with no session (orphans), for absorption.
  Future<List<DrinkEntryRow>> getOrphanAlcoholicEntries(
    List<String> alcoholicTypes,
  ) =>
      (select(drinkEntries)
            ..where(
              (t) =>
                  t.partySessionId.isNull() &
                  t.deletedAt.isNull() &
                  t.beverageType.isIn(alcoholicTypes),
            ))
          .get();

  /// Assigns [entryId] to [sessionId] (orphan absorption) and bumps
  /// [updatedAtUtc] — the one spec-sanctioned side-effect mutation of a
  /// [DrinkEntryRow] (data-model.md §Meal → Relationship to DrinkEntry).
  Future<void> absorbOrphanEntry(
    String entryId,
    String sessionId,
    DateTime updatedAtUtc,
  ) =>
      (update(drinkEntries)..where((t) => t.id.equals(entryId))).write(
        DrinkEntriesCompanion(
          partySessionId: Value(sessionId),
          updatedAt: Value(updatedAtUtc),
        ),
      );

  // ---------------------------------------------------------------------------
  // History — alcohol charts + day drill-down (issue #26)
  // ---------------------------------------------------------------------------

  /// Reactive stream of live sessions whose window `[startedAt, endedAt)`
  /// overlaps `[startUtc, endUtc)`, ordered by [startedAt]. An active session
  /// (`endedAt IS NULL`) is treated as open-ended — it overlaps any window
  /// that starts before "now" could reach, so it's included whenever
  /// `startedAt < endUtc`.
  Stream<List<PartySessionRow>> watchSessionsOverlapping(
    DateTime startUtc,
    DateTime endUtc,
  ) {
    return (select(partySessions)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.startedAt.isSmallerThanValue(endUtc) &
                (t.endedAt.isNull() | t.endedAt.isBiggerThanValue(startUtc)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .watch();
  }

  /// Live [DrinkEntryRow]s belonging to any of [sessionIds] — feeds BAC-peak
  /// sampling (F4/#26), which needs each session's *full* entry list
  /// regardless of the day/range being sampled (a drink just before the
  /// sampled window can still contribute decayed BAC into it).
  Future<List<DrinkEntryRow>> getEntriesForSessions(
    List<String> sessionIds,
  ) async {
    if (sessionIds.isEmpty) return [];
    return (select(drinkEntries)
          ..where(
            (t) => t.partySessionId.isIn(sessionIds) & t.deletedAt.isNull(),
          ))
        .get();
  }

  /// Live [MealRow]s belonging to any of [sessionIds] — see
  /// [getEntriesForSessions].
  Future<List<MealRow>> getMealsForSessions(List<String> sessionIds) async {
    if (sessionIds.isEmpty) return [];
    return (select(meals)
          ..where(
            (t) => t.partySessionId.isIn(sessionIds) & t.deletedAt.isNull(),
          ))
        .get();
  }

  /// Reactive stream of `(consumedAt, volumeMl)` pairs for live alcoholic
  /// entries (`partySessionId IS NOT NULL`) within `[startUtc, endUtc)` —
  /// feeds the "alcoholic drinks per day" chart (F4/#26). [volumeMl] is
  /// unused by the count bucketing but kept for signature symmetry with
  /// [watchEntriesInWindow].
  Stream<List<(DateTime, int)>> watchPartySessionEntriesInWindow(
    DateTime startUtc,
    DateTime endUtc,
  ) {
    final query = select(drinkEntries)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.partySessionId.isNotNull() &
            t.consumedAt.isBiggerOrEqualValue(startUtc) &
            t.consumedAt.isSmallerThanValue(endUtc),
      );
    return query.watch().map(
          (rows) => rows.map((r) => (r.consumedAt, r.volumeMl)).toList(),
        );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'drinks_mate.db'));
    return NativeDatabase.createInBackground(file);
  });
}
