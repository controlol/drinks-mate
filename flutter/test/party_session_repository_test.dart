import 'dart:io';

import 'package:core/core.dart';
import 'package:drift/drift.dart'
    show GeneratedDatabase, Table, TableInfo, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/meal.dart';
import 'package:drinks_mate/src/models/optional.dart';
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/user_profile.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/party_session_repository.dart';
import 'package:drinks_mate/src/repository/preferences_repository.dart';

// ---------------------------------------------------------------------------
// Helper: open an in-memory database (no file I/O, safe in tests).
// Source: flutter/test/drinks_repository_test.dart / preferences_repository_test.dart
// conventions.
// ---------------------------------------------------------------------------

AppDatabase _memDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

// A minimal alcoholic (beer) preset for logAlcoholicDrink() tests.
const _beerPreset = DrinkPreset(
  id: 'test-beer-preset',
  name: 'Test Beer',
  beverageType: BeverageType.beer,
  volumeMl: 330,
  abvPercent: 5.0,
  iconKey: 'beer_glass',
  iconColor: '#d97706',
  isUserCreated: false,
  isHidden: false,
  sortOrder: 99,
);

// A non-alcoholic preset, to exercise the "must be alcoholic" rejection.
const _waterPreset = DrinkPreset(
  id: 'test-water-preset',
  name: 'Test Water',
  beverageType: BeverageType.water,
  volumeMl: 300,
  iconKey: 'glass',
  iconColor: '#3b82f6',
  isUserCreated: false,
  isHidden: false,
  sortOrder: 1,
);

// A preset that DOES carry a regular price — needed for resolvePrice tests,
// since `_beerPreset` above has no regularPriceMinor/regularCurrency and
// couldn't distinguish "returns null" from "returns the regular price" (both
// look like null on a preset with no regular price set).
const _pricedBeerPreset = DrinkPreset(
  id: 'test-priced-beer-preset',
  name: 'Priced Beer',
  beverageType: BeverageType.beer,
  volumeMl: 330,
  abvPercent: 5.0,
  regularPriceMinor: 450,
  regularCurrency: 'EUR',
  iconKey: 'beer_glass',
  iconColor: '#d97706',
  isUserCreated: false,
  isHidden: false,
  sortOrder: 99,
);

// A second priced preset, deliberately never given a session-price override
// in the resolvePrice tests below, to exercise the "useSessionPrices=true but
// no matching override row" fallback-to-regular-price case.
const _pricedWinePreset = DrinkPreset(
  id: 'test-priced-wine-preset-no-override',
  name: 'Priced Wine',
  beverageType: BeverageType.wine,
  volumeMl: 150,
  abvPercent: 12.0,
  regularPriceMinor: 200,
  regularCurrency: 'USD',
  iconKey: 'wine_glass',
  iconColor: '#7c2d12',
  isUserCreated: false,
  isHidden: false,
  sortOrder: 98,
);

// A preset used only for the token-override resolvePrice case. Its regular
// price is deliberately set to a distinct, implausible value (999 GBP) so a
// test that wrongly falls back to the regular price is caught.
const _tokenCocktailPreset = DrinkPreset(
  id: 'test-token-cocktail-preset',
  name: 'Token Cocktail',
  beverageType: BeverageType.cocktail,
  volumeMl: 200,
  abvPercent: 15.0,
  regularPriceMinor: 999,
  regularCurrency: 'GBP',
  iconKey: 'cocktail_glass',
  iconColor: '#be185d',
  isUserCreated: false,
  isHidden: false,
  sortOrder: 97,
);

/// Inserts a live, orphaned (partySessionId = null) alcoholic drink entry
/// directly at the DB layer — mirrors what `DrinksRepository.logDrink()`
/// produces when an alcoholic drink is logged with no active session
/// (data-model.md §Meal → Relationship to DrinkEntry: "An alcoholic drink
/// logged when no session is active: partySessionId = null (orphan)").
Future<String> _insertOrphanDrink(
  AppDatabase db, {
  required DateTime consumedAt,
  int volumeMl = 500,
  double abvPercent = 5.0,
  String id = 'orphan-1',
}) async {
  final now = DateTime.now().toUtc();
  await db.insertDrinkEntry(
    DrinkEntriesCompanion.insert(
      id: id,
      beverageType: BeverageType.beer.stored,
      volumeMl: volumeMl,
      abvPercent: Value(abvPercent),
      consumedAt: consumedAt,
      createdAt: now,
      updatedAt: now,
    ),
  );
  return id;
}

/// Seeds a [UserProfile] via [PreferencesRepository] (mirrors
/// preferences_repository_test.dart's `upsertProfile` usage).
Future<void> _seedProfile(
  AppDatabase db, {
  String gender = 'male',
  double? weightKg = 75.0,
  double? heightCm = 180.0,
  String? birthDate = '1996-07-01',
}) async {
  final now = DateTime.now().toUtc();
  await PreferencesRepository(db).upsertProfile(
    UserProfile(
      id: 'test-profile',
      gender: gender,
      weightKg: weightKg,
      heightCm: heightCm,
      birthDate: birthDate,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

/// Inserts a live [DrinkPresetRow] mirroring [preset]'s fields — needed by
/// the retroactive-sweep tests below (issue #87) whose "no override"/
/// "useSessionPrices off" sweep cases read the preset's regular price back
/// out of the DB via `AppDatabase.getPresetById`
/// ([PartySessionRepository]'s private `_resolveSweptPrice`), unlike
/// [PartySessionRepository.logAlcoholicDrink] which only ever needs the
/// in-memory [DrinkPreset] passed to it.
Future<void> _insertPresetRow(AppDatabase db, DrinkPreset preset) async {
  final now = DateTime.now().toUtc();
  await db.insertPreset(
    DrinkPresetsCompanion.insert(
      id: preset.id,
      name: preset.name,
      beverageType: preset.beverageType.stored,
      volumeMl: preset.volumeMl,
      abvPercent: Value(preset.abvPercent),
      regularPriceMinor: Value(preset.regularPriceMinor),
      regularCurrency: Value(preset.regularCurrency),
      iconKey: preset.iconKey,
      iconColor: preset.iconColor,
      isUserCreated: preset.isUserCreated,
      sortOrder: preset.sortOrder,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

/// Inserts a live or soft-deleted [DrinkEntryRow] directly at the DB layer,
/// with full control over every field the retroactive sweep (issue #87)
/// keys off — [partySessionId], [presetId], [manualPriceOverride],
/// [deletedAt] — that [PartySessionRepository.logAlcoholicDrink]'s narrower
/// parameter set can't produce (e.g. an entry belonging to a session that
/// was never actually started, to prove the sweep only touches [sessionId]).
Future<void> _insertRawEntry(
  AppDatabase db, {
  required String id,
  required String partySessionId,
  required String presetId,
  int? priceMinor,
  String? currency,
  bool manualPriceOverride = false,
  DateTime? deletedAt,
  required DateTime consumedAt,
  required DateTime updatedAt,
}) async {
  await db.insertDrinkEntry(
    DrinkEntriesCompanion.insert(
      id: id,
      beverageType: BeverageType.beer.stored,
      volumeMl: 330,
      abvPercent: const Value(5.0),
      priceMinor: Value(priceMinor),
      currency: Value(currency),
      partySessionId: Value(partySessionId),
      presetId: Value(presetId),
      manualPriceOverride: Value(manualPriceOverride),
      deletedAt: Value(deletedAt),
      consumedAt: consumedAt,
      createdAt: consumedAt,
      updatedAt: updatedAt,
    ),
  );
}

/// One-shot read of a single [DrinkEntryRow] by [id] — mirrors the
/// `db.select(db.drinkEntries).get()` + `singleWhere` pattern already used
/// throughout this file (e.g. the migration tests above).
Future<DrinkEntryRow> _getEntry(AppDatabase db, String id) async =>
    (await db.select(db.drinkEntries).get()).singleWhere((e) => e.id == id);

/// A bare-bones [GeneratedDatabase] used only to hand-write a genuine v3
/// schema via raw SQL for the upgrade test below. `allTables` is empty
/// because we never issue typed queries against it — only `customStatement`.
class _LegacyDb extends GeneratedDatabase {
  _LegacyDb(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
}

/// Same purpose as [_LegacyDb], but for hand-writing a genuine v5 schema
/// (issue #78's "if (from < 6)" upgrade test below) — the v5 shape already
/// has every v4 table/column plus `alcoholic_presets_always_visible`, but
/// neither `drink_entries.preset_id` nor `user_preferences.drink_sort_mode`.
class _LegacyDbV5 extends GeneratedDatabase {
  _LegacyDbV5(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
}

/// Same purpose as [_LegacyDb]/[_LegacyDbV5], but for hand-writing a genuine
/// v6 schema (issue #87's "if (from < 7)" upgrade test below) — the v6 shape
/// already has `drink_entries.preset_id` and
/// `user_preferences.drink_sort_mode`, but no `manual_price_override` yet.
class _LegacyDbV6 extends GeneratedDatabase {
  _LegacyDbV6(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
}

void main() {
  // ---------------------------------------------------------------------------
  // 1. Schema migration
  // ---------------------------------------------------------------------------

  group('AppDatabase — schema v5 (fresh onCreate)', () {
    test('schemaVersion is 7 (app_database.dart)', () async {
      final db = _memDb();
      addTearDown(db.close);
      expect(db.schemaVersion, 7);
    });

    test(
      'default preferences row has alcoholicPresetsAlwaysVisible = true '
      '(v5 default)',
      () async {
        final db = _memDb();
        addTearDown(db.close);
        final prefs = await PreferencesRepository(db).getPreferences();
        expect(prefs.alcoholicPresetsAlwaysVisible, isTrue);
      },
    );

    test(
      'PartySessions / PartySessionPrices / Meals tables exist and '
      'DrinkEntries gained the 4 new columns — round-trips without error',
      () async {
        // Source: app_database.dart schema v4 doc comment — "PartySessions +
        // PartySessionPrices + Meals tables; DrinkEntries gains
        // partySessionId/priceTokens/tokenValueMinor/tokenValueCurrency
        // columns."
        final db = _memDb();
        addTearDown(db.close);
        final now = DateTime.utc(2026, 7, 10, 12, 0);

        await db.insertPartySession(
          PartySessionsCompanion.insert(
            id: 's1',
            startedAt: now,
            useSessionPrices: true,
            tokenName: const Value('Token'),
            tokenValueMinor: const Value(150),
            tokenValueCurrency: const Value('EUR'),
            createdAt: now,
            updatedAt: now,
          ),
        );
        final session = await db.getPartySessionById('s1');
        expect(session, isNotNull);
        expect(session!.tokenName, 'Token');
        expect(session.tokenValueMinor, 150);
        expect(session.tokenValueCurrency, 'EUR');

        await db.insertMeal(
          MealsCompanion.insert(
            id: 'm1',
            partySessionId: 's1',
            size: 'medium',
            eatenAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final meals = await db.watchSessionMeals('s1').first;
        expect(meals.single.size, 'medium');

        await db.insertSessionPrice(
          PartySessionPricesCompanion.insert(
            id: 'pp1',
            partySessionId: 's1',
            drinkPresetId: 'preset-x',
            priceTokens: const Value(3),
            createdAt: now,
            updatedAt: now,
          ),
        );
        final prices = await db.getSessionPrices('s1');
        expect(prices.single.priceTokens, 3);

        await db.insertDrinkEntry(
          DrinkEntriesCompanion.insert(
            id: 'e1',
            beverageType: 'beer',
            volumeMl: 330,
            abvPercent: const Value(5.0),
            partySessionId: const Value('s1'),
            priceTokens: const Value(2),
            tokenValueMinor: const Value(150),
            tokenValueCurrency: const Value('EUR'),
            consumedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final entries = await db.watchSessionEntries('s1').first;
        expect(entries.single.partySessionId, 's1');
        expect(entries.single.priceTokens, 2);
        expect(entries.single.tokenValueMinor, 150);
        expect(entries.single.tokenValueCurrency, 'EUR');
      },
    );
  });

  group('AppDatabase — v3 → v4 upgrade (onUpgrade "if (from < 4)" block)', () {
    test(
      'upgrading a hand-built v3 schema creates the v4 tables/columns and '
      'preserves the pre-existing DrinkEntries row',
      () async {
        // onCreate() always calls m.createAll() — it never touches the
        // `if (from < 4)` onUpgrade block, so a fresh-onCreate test alone
        // cannot catch a forgotten createTable()/addColumn() call in that
        // block. This test hand-builds a genuine v3 schema (raw SQL, no
        // drift_dev "old_schemas" tooling configured in this repo) and lets
        // the real AppDatabase upgrade it, so the addColumn/createTable
        // calls in app_database.dart's onUpgrade actually execute.
        //
        // Column names/types are taken directly from the generated
        // $DrinkEntriesTable / $DrinkPresetsTable / etc. in app_database.g.dart
        // (verified by reading the generated file), minus the 4 columns
        // added in v4. DateTime → INTEGER epoch-seconds and bool → INTEGER
        // 0/1 confirmed empirically (no build.yaml sets
        // storeDateTimeAsText), not assumed.
        final tempDir = await Directory.systemTemp.createTemp(
          'party_session_migration_test',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final dbFile = File(p.join(tempDir.path, 'legacy.sqlite'));

        final legacy = _LegacyDb(NativeDatabase(dbFile));
        await legacy.customStatement('''
          CREATE TABLE drink_presets (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            beverage_type TEXT NOT NULL,
            volume_ml INTEGER NOT NULL,
            abv_percent REAL,
            regular_price_minor INTEGER,
            regular_currency TEXT,
            icon_key TEXT NOT NULL,
            icon_color TEXT NOT NULL,
            is_user_created INTEGER NOT NULL,
            is_hidden INTEGER NOT NULL,
            sort_order INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');
        // v3 shape: no party_session_id / price_tokens / token_value_minor /
        // token_value_currency columns — those are the v4 additions under test.
        await legacy.customStatement('''
          CREATE TABLE drink_entries (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT,
            beverage_type TEXT NOT NULL,
            volume_ml INTEGER NOT NULL,
            abv_percent REAL,
            price_minor INTEGER,
            currency TEXT,
            icon_key TEXT,
            icon_color TEXT,
            consumed_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');
        await legacy.customStatement('''
          CREATE TABLE user_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            gender TEXT,
            weight_kg REAL,
            height_cm REAL,
            birth_date TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');
        await legacy.customStatement('''
          CREATE TABLE user_preferences (
            id TEXT NOT NULL PRIMARY KEY,
            username TEXT,
            daily_goal_ml INTEGER NOT NULL,
            day_boundary_hour INTEGER NOT NULL,
            units TEXT NOT NULL,
            currency TEXT NOT NULL,
            reminder_enabled INTEGER NOT NULL,
            reminder_start_hour INTEGER NOT NULL,
            reminder_end_hour INTEGER NOT NULL,
            reminder_interval_min INTEGER NOT NULL,
            inactivity_reminder_enabled INTEGER NOT NULL,
            weekly_summary_enabled INTEGER NOT NULL,
            default_drink_preset_id TEXT,
            bac_cap_grams_per_l REAL,
            bac_on_lock_screen_enabled INTEGER NOT NULL,
            approaching_cap_notif_enabled INTEGER NOT NULL,
            sober_estimate_notif_enabled INTEGER NOT NULL,
            installed_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');

        final legacyEpoch =
            DateTime.utc(2026, 1, 1, 12).millisecondsSinceEpoch ~/ 1000;
        await legacy.customStatement('''
          INSERT INTO drink_entries (id, name, beverage_type, volume_ml,
            abv_percent, price_minor, currency, icon_key, icon_color,
            consumed_at, created_at, updated_at, deleted_at)
          VALUES ('legacy-1', 'Legacy Water', 'water', 300, NULL, NULL, NULL,
            'glass', '#3b82f6', $legacyEpoch, $legacyEpoch, $legacyEpoch, NULL);
        ''');
        // Mark this file as schema v3 so reopening with schemaVersion 4
        // triggers the real onUpgrade(from: 3, to: 4) path.
        await legacy.customStatement('PRAGMA user_version = 3;');
        await legacy.close();

        final upgraded = AppDatabase(NativeDatabase(dbFile));
        addTearDown(upgraded.close);

        // This test opens the *real* AppDatabase (currently schema v7), so a
        // hand-built v3 file cascades through the "if (from < 4)", "if (from
        // < 5)", "if (from < 6)", and "if (from < 7)" onUpgrade blocks in one
        // open — verified below.
        expect(upgraded.schemaVersion, 7);

        final entries = await upgraded.select(upgraded.drinkEntries).get();
        final legacyEntry = entries.singleWhere((e) => e.id == 'legacy-1');
        expect(legacyEntry.name, 'Legacy Water',
            reason: 'pre-existing data must survive the upgrade');
        // New columns exist (ALTER TABLE ADD COLUMN) and are null for the
        // pre-existing row.
        expect(legacyEntry.partySessionId, isNull);
        expect(legacyEntry.priceTokens, isNull);
        expect(legacyEntry.tokenValueMinor, isNull);
        expect(legacyEntry.tokenValueCurrency, isNull);

        // New tables are live and usable through the repository.
        final repo = PartySessionRepository(upgraded);
        final session = await repo.startSession(now: DateTime.utc(2026, 7, 10));
        expect(session.id, isNotEmpty);
        expect(await upgraded.getActiveSession(), isNotNull);

        // v5's addColumn ran too: the hand-built v3 user_preferences table
        // (no alcoholic_presets_always_visible column) gained it via ALTER
        // TABLE, and the beforeOpen seed populated the default row.
        final prefs = await PreferencesRepository(upgraded).getPreferences();
        expect(prefs.alcoholicPresetsAlwaysVisible, isTrue);
      },
    );
  });

  group('AppDatabase — v5 → v6 upgrade (onUpgrade "if (from < 6)" block)', () {
    test(
      'upgrading a hand-built v5 schema adds drink_entries.preset_id and '
      'user_preferences.drink_sort_mode, with correct defaults, and '
      'preserves pre-existing rows',
      () async {
        // Source: app_database.dart schema v6 doc comment — "DrinkEntries
        // gains presetId (nullable, no FK); UserPreferences gains
        // drinkSortMode (default 'recentlyUsed')". Column shapes below are
        // the v5 schema (v2 drink_presets + v4 party/meal tables/columns +
        // v5's alcoholic_presets_always_visible), taken from the table
        // sources under lib/src/db/tables/, minus the two v6 additions under
        // test here — mirrors the v3→v4 upgrade test's approach above.
        final tempDir = await Directory.systemTemp.createTemp(
          'party_session_migration_v6_test',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final dbFile = File(p.join(tempDir.path, 'legacy_v5.sqlite'));

        final legacy = _LegacyDbV5(NativeDatabase(dbFile));
        await legacy.customStatement('''
          CREATE TABLE drink_presets (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            beverage_type TEXT NOT NULL,
            volume_ml INTEGER NOT NULL,
            abv_percent REAL,
            regular_price_minor INTEGER,
            regular_currency TEXT,
            icon_key TEXT NOT NULL,
            icon_color TEXT NOT NULL,
            is_user_created INTEGER NOT NULL,
            is_hidden INTEGER NOT NULL,
            sort_order INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');
        // v5 shape: has the v4 party/token columns, but no preset_id yet
        // (the v6 addition under test).
        await legacy.customStatement('''
          CREATE TABLE drink_entries (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT,
            beverage_type TEXT NOT NULL,
            volume_ml INTEGER NOT NULL,
            abv_percent REAL,
            price_minor INTEGER,
            currency TEXT,
            price_tokens INTEGER,
            token_value_minor INTEGER,
            token_value_currency TEXT,
            icon_key TEXT,
            icon_color TEXT,
            party_session_id TEXT,
            consumed_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');
        await legacy.customStatement('''
          CREATE TABLE user_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            gender TEXT,
            weight_kg REAL,
            height_cm REAL,
            birth_date TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');
        // v5 shape: has alcoholic_presets_always_visible, but no
        // drink_sort_mode yet (the other v6 addition under test).
        await legacy.customStatement('''
          CREATE TABLE user_preferences (
            id TEXT NOT NULL PRIMARY KEY,
            username TEXT,
            daily_goal_ml INTEGER NOT NULL,
            day_boundary_hour INTEGER NOT NULL,
            units TEXT NOT NULL,
            currency TEXT NOT NULL,
            reminder_enabled INTEGER NOT NULL,
            reminder_start_hour INTEGER NOT NULL,
            reminder_end_hour INTEGER NOT NULL,
            reminder_interval_min INTEGER NOT NULL,
            inactivity_reminder_enabled INTEGER NOT NULL,
            weekly_summary_enabled INTEGER NOT NULL,
            default_drink_preset_id TEXT,
            bac_cap_grams_per_l REAL,
            bac_on_lock_screen_enabled INTEGER NOT NULL,
            approaching_cap_notif_enabled INTEGER NOT NULL,
            sober_estimate_notif_enabled INTEGER NOT NULL,
            alcoholic_presets_always_visible INTEGER NOT NULL,
            installed_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');
        await legacy.customStatement('''
          CREATE TABLE party_sessions (
            id TEXT NOT NULL PRIMARY KEY,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            end_reason TEXT,
            use_session_prices INTEGER NOT NULL,
            token_name TEXT,
            token_value_minor INTEGER,
            token_value_currency TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');
        await legacy.customStatement('''
          CREATE TABLE party_session_prices (
            id TEXT NOT NULL PRIMARY KEY,
            party_session_id TEXT NOT NULL,
            drink_preset_id TEXT NOT NULL,
            price_minor INTEGER,
            currency TEXT,
            price_tokens INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');
        await legacy.customStatement('''
          CREATE TABLE meals (
            id TEXT NOT NULL PRIMARY KEY,
            party_session_id TEXT NOT NULL,
            size TEXT NOT NULL,
            eaten_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');

        final legacyEpoch =
            DateTime.utc(2026, 1, 1, 12).millisecondsSinceEpoch ~/ 1000;
        await legacy.customStatement('''
          INSERT INTO drink_entries (id, name, beverage_type, volume_ml,
            abv_percent, price_minor, currency, price_tokens,
            token_value_minor, token_value_currency, icon_key, icon_color,
            party_session_id, consumed_at, created_at, updated_at, deleted_at)
          VALUES ('legacy-entry-1', 'Legacy Beer', 'beer', 330,
            5.0, NULL, NULL, NULL,
            NULL, NULL, 'beer_glass', '#d97706',
            NULL, $legacyEpoch, $legacyEpoch, $legacyEpoch, NULL);
        ''');
        // A hand-inserted UserPreferences singleton (id = kUserPreferencesId)
        // with a deliberately non-default currency/alcoholicPresetsAlwaysVisible
        // so the post-upgrade assertions below can tell "this exact row
        // survived" apart from "beforeOpen re-seeded a fresh default row".
        final installedAtMs = DateTime.utc(2025, 6, 1).millisecondsSinceEpoch;
        await legacy.customStatement('''
          INSERT INTO user_preferences (id, username, daily_goal_ml,
            day_boundary_hour, units, currency, reminder_enabled,
            reminder_start_hour, reminder_end_hour, reminder_interval_min,
            inactivity_reminder_enabled, weekly_summary_enabled,
            default_drink_preset_id, bac_cap_grams_per_l,
            bac_on_lock_screen_enabled, approaching_cap_notif_enabled,
            sober_estimate_notif_enabled, alcoholic_presets_always_visible,
            installed_at, created_at, updated_at)
          VALUES ('$kUserPreferencesId', 'legacyuser', 2500, 5, 'metric',
            'USD', 1, 8, 22, 90, 1, 1, NULL, NULL, 1, 0, 0, 0,
            $installedAtMs, $legacyEpoch, $legacyEpoch);
        ''');
        // Mark this file as schema v5 so reopening with schemaVersion 6
        // triggers only the real onUpgrade(from: 5, to: 6) "if (from < 6)"
        // block (the v2-v5 blocks are no-ops since `from` is already 5).
        await legacy.customStatement('PRAGMA user_version = 5;');
        await legacy.close();

        final upgraded = AppDatabase(NativeDatabase(dbFile));
        addTearDown(upgraded.close);

        // The running AppDatabase is always at the current schema version
        // (7) after upgrade — this v5→v6 test only exercises the "if (from
        // < 6)" block in isolation (see PRAGMA user_version = 5 above); the
        // subsequent "if (from < 7)" block still runs since `from` is still
        // < 7, adding manual_price_override too.
        expect(upgraded.schemaVersion, 7);

        // drink_entries.preset_id exists (ALTER TABLE ADD COLUMN) and is
        // null for the pre-existing row — its other snapshot fields survive
        // untouched.
        final entries = await upgraded.select(upgraded.drinkEntries).get();
        final legacyEntry =
            entries.singleWhere((e) => e.id == 'legacy-entry-1');
        expect(legacyEntry.name, 'Legacy Beer',
            reason: 'pre-existing data must survive the upgrade');
        expect(legacyEntry.presetId, isNull);

        // The new column is live and usable via the repository.
        final drinksRepo = DrinksRepository(upgraded);
        const preset = DrinkPreset(
          id: 'preset-for-v6-test',
          name: 'V6 Test Beer',
          beverageType: BeverageType.beer,
          volumeMl: 330,
          abvPercent: 5.0,
          iconKey: 'beer_glass',
          iconColor: '#d97706',
          isUserCreated: false,
          isHidden: false,
          sortOrder: 1,
        );
        await drinksRepo.logDrink(preset: preset);
        final newEntry = (await upgraded.select(upgraded.drinkEntries).get())
            .singleWhere((e) => e.id != 'legacy-entry-1');
        expect(newEntry.presetId, preset.id);

        // user_preferences.drink_sort_mode exists (ALTER TABLE ADD COLUMN
        // ... DEFAULT) and the pre-existing row's OTHER fields (currency,
        // alcoholicPresetsAlwaysVisible) are untouched — proving this is the
        // hand-inserted row, not a beforeOpen reseed (INSERT OR IGNORE is a
        // no-op for an existing primary key).
        final prefs = await PreferencesRepository(upgraded).getPreferences();
        expect(prefs.currency, 'USD',
            reason: 'pre-existing preferences row must survive the upgrade');
        expect(prefs.alcoholicPresetsAlwaysVisible, isFalse,
            reason: 'the hand-inserted value (false) must not be reset to '
                'the seed default (true)');
        expect(
          prefs.drinkSortMode,
          PresetSortMode.recentlyUsed,
          reason: "app_database.dart's drinkSortMode column default is "
              "'recentlyUsed' — ALTER TABLE ADD COLUMN ... DEFAULT populates "
              'this value for every pre-existing row.',
        );
      },
    );
  });

  group('AppDatabase — v6 → v7 upgrade (onUpgrade "if (from < 7)" block)', () {
    test(
      'upgrading a hand-built v6 schema adds '
      'drink_entries.manual_price_override with default false, and '
      'preserves pre-existing rows',
      () async {
        // Source: app_database.dart schema v7 doc comment / onUpgrade "if
        // (from < 7)" block — "DrinkEntries gains manualPriceOverride
        // (boolean, default false)" (issue #87). Column shapes below are the
        // v6 schema (v5 shape + drink_entries.preset_id +
        // user_preferences.drink_sort_mode), minus the one v7 addition under
        // test — mirrors the v3→v4/v5→v6 upgrade tests' approach above.
        final tempDir = await Directory.systemTemp.createTemp(
          'party_session_migration_v7_test',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final dbFile = File(p.join(tempDir.path, 'legacy_v6.sqlite'));

        final legacy = _LegacyDbV6(NativeDatabase(dbFile));
        await legacy.customStatement('''
          CREATE TABLE drink_presets (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            beverage_type TEXT NOT NULL,
            volume_ml INTEGER NOT NULL,
            abv_percent REAL,
            regular_price_minor INTEGER,
            regular_currency TEXT,
            icon_key TEXT NOT NULL,
            icon_color TEXT NOT NULL,
            is_user_created INTEGER NOT NULL,
            is_hidden INTEGER NOT NULL,
            sort_order INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');
        // v6 shape: has preset_id (v6's own addition), but no
        // manual_price_override yet (the v7 addition under test).
        await legacy.customStatement('''
          CREATE TABLE drink_entries (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT,
            beverage_type TEXT NOT NULL,
            volume_ml INTEGER NOT NULL,
            abv_percent REAL,
            price_minor INTEGER,
            currency TEXT,
            price_tokens INTEGER,
            token_value_minor INTEGER,
            token_value_currency TEXT,
            icon_key TEXT,
            icon_color TEXT,
            party_session_id TEXT,
            preset_id TEXT,
            consumed_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');
        await legacy.customStatement('''
          CREATE TABLE user_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            gender TEXT,
            weight_kg REAL,
            height_cm REAL,
            birth_date TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');
        // v6 shape: has both alcoholic_presets_always_visible (v5) and
        // drink_sort_mode (v6's own addition).
        await legacy.customStatement('''
          CREATE TABLE user_preferences (
            id TEXT NOT NULL PRIMARY KEY,
            username TEXT,
            daily_goal_ml INTEGER NOT NULL,
            day_boundary_hour INTEGER NOT NULL,
            units TEXT NOT NULL,
            currency TEXT NOT NULL,
            reminder_enabled INTEGER NOT NULL,
            reminder_start_hour INTEGER NOT NULL,
            reminder_end_hour INTEGER NOT NULL,
            reminder_interval_min INTEGER NOT NULL,
            inactivity_reminder_enabled INTEGER NOT NULL,
            weekly_summary_enabled INTEGER NOT NULL,
            default_drink_preset_id TEXT,
            bac_cap_grams_per_l REAL,
            bac_on_lock_screen_enabled INTEGER NOT NULL,
            approaching_cap_notif_enabled INTEGER NOT NULL,
            sober_estimate_notif_enabled INTEGER NOT NULL,
            alcoholic_presets_always_visible INTEGER NOT NULL,
            drink_sort_mode TEXT NOT NULL DEFAULT 'recentlyUsed',
            installed_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');
        await legacy.customStatement('''
          CREATE TABLE party_sessions (
            id TEXT NOT NULL PRIMARY KEY,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            end_reason TEXT,
            use_session_prices INTEGER NOT NULL,
            token_name TEXT,
            token_value_minor INTEGER,
            token_value_currency TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');
        await legacy.customStatement('''
          CREATE TABLE party_session_prices (
            id TEXT NOT NULL PRIMARY KEY,
            party_session_id TEXT NOT NULL,
            drink_preset_id TEXT NOT NULL,
            price_minor INTEGER,
            currency TEXT,
            price_tokens INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');
        await legacy.customStatement('''
          CREATE TABLE meals (
            id TEXT NOT NULL PRIMARY KEY,
            party_session_id TEXT NOT NULL,
            size TEXT NOT NULL,
            eaten_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');

        final legacyEpoch =
            DateTime.utc(2026, 1, 1, 12).millisecondsSinceEpoch ~/ 1000;
        await legacy.customStatement('''
          INSERT INTO drink_entries (id, name, beverage_type, volume_ml,
            abv_percent, price_minor, currency, price_tokens,
            token_value_minor, token_value_currency, icon_key, icon_color,
            party_session_id, preset_id, consumed_at, created_at, updated_at,
            deleted_at)
          VALUES ('legacy-entry-v6', 'Legacy V6 Beer', 'beer', 330,
            5.0, 450, 'EUR', NULL,
            NULL, NULL, 'beer_glass', '#d97706',
            NULL, 'some-preset-id', $legacyEpoch, $legacyEpoch, $legacyEpoch,
            NULL);
        ''');
        // Mark this file as schema v6 so reopening with schemaVersion 7
        // triggers only the real onUpgrade(from: 6, to: 7) "if (from < 7)"
        // block (the v2-v6 blocks are no-ops since `from` is already 6).
        await legacy.customStatement('PRAGMA user_version = 6;');
        await legacy.close();

        final upgraded = AppDatabase(NativeDatabase(dbFile));
        addTearDown(upgraded.close);

        expect(upgraded.schemaVersion, 7);

        // drink_entries.manual_price_override exists (ALTER TABLE ADD
        // COLUMN ... DEFAULT) and is false for the pre-existing row — its
        // other snapshot fields (including the v6-added preset_id) survive
        // untouched.
        final entries = await upgraded.select(upgraded.drinkEntries).get();
        final legacyEntry =
            entries.singleWhere((e) => e.id == 'legacy-entry-v6');
        expect(legacyEntry.name, 'Legacy V6 Beer',
            reason: 'pre-existing data must survive the upgrade');
        expect(legacyEntry.presetId, 'some-preset-id');
        expect(legacyEntry.priceMinor, 450);
        expect(legacyEntry.currency, 'EUR');
        expect(
          legacyEntry.manualPriceOverride,
          isFalse,
          reason: "app_database.dart's manualPriceOverride column default "
              'is false — ALTER TABLE ADD COLUMN ... DEFAULT populates this '
              'value for every pre-existing row.',
        );

        // The new column is live and usable via the repository — a fresh
        // entry logged with a one-off price override persists
        // manualPriceOverride = true. Seed a profile first: startSession()
        // runs orphan absorption, and the hand-inserted legacy row above
        // (partySessionId NULL) is itself an orphan.
        await _seedProfile(upgraded);
        final partyRepo = PartySessionRepository(upgraded);
        final session = await partyRepo.startSession(
          now: DateTime.utc(2026, 7, 10),
        );
        final entry = await partyRepo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: session.id,
          priceMinor: 300,
          currency: 'EUR',
          isManualPriceOverride: true,
        );
        final newRow = (await upgraded.select(upgraded.drinkEntries).get())
            .singleWhere((e) => e.id == entry.id);
        expect(newRow.manualPriceOverride, isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // 2. Single-active-session enforcement
  // ---------------------------------------------------------------------------

  group('PartySessionRepository.startSession — single active session', () {
    late AppDatabase db;
    late PartySessionRepository repo;

    setUp(() {
      db = _memDb();
      repo = PartySessionRepository(db);
    });

    tearDown(() => db.close());

    test('succeeds when no session is active', () async {
      final session = await repo.startSession(
        now: DateTime.utc(2026, 7, 10, 20, 0),
      );
      expect(session.isActive, isTrue);
      expect(session.endedAt, isNull);
    });

    test(
      'throws StateError when called again while a session is still active',
      () async {
        // Source: data-model.md §PartySession — "There is at most one active
        // session (endedAt IS NULL) at any time."
        final now = DateTime.utc(2026, 7, 10, 20, 0);
        await repo.startSession(now: now);

        expect(
          () => repo.startSession(now: now.add(const Duration(minutes: 5))),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('tokenName is NFC-normalised before storing', () async {
      // Parity Rulebook §Username normalisation: "visually identical inputs
      // produce the same stored bytes." tokenName shares the username
      // whitelist (data-model.md §PartySession), so the same rule applies —
      // mirrors DrinksRepository.createPreset's normalizeNfc(name) call.
      const nfd = 'Tóken'; // "Tóken" as NFD (combining acute accent).
      final session = await repo.startSession(
        tokenName: nfd,
        now: DateTime.utc(2026, 7, 10, 20, 0),
      );
      expect(session.tokenName, 'Tóken'); // NFC form.
    });

    test('rejects an invalid tokenName', () async {
      expect(
        () => repo.startSession(tokenName: ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Lazy 12h auto-end
  // ---------------------------------------------------------------------------

  group('PartySessionRepository — lazy 12h auto-end', () {
    late AppDatabase db;
    late PartySessionRepository repo;

    setUp(() {
      db = _memDb();
      repo = PartySessionRepository(db);
    });

    tearDown(() => db.close());

    test('no active session — checkAndApplyAutoEnd is a no-op', () async {
      await repo.checkAndApplyAutoEnd(now: DateTime.utc(2026, 7, 10));
      expect(await db.getActiveSession(), isNull);
    });

    test(
      'no alcoholic drinks logged, now < startedAt + 12h — stays active',
      () async {
        final startedAt = DateTime.utc(2026, 7, 10, 20, 0);
        await repo.startSession(now: startedAt, startedAt: startedAt);

        await repo.checkAndApplyAutoEnd(
          now: startedAt.add(const Duration(hours: 11, minutes: 59)),
        );

        final active = await db.getActiveSession();
        expect(active, isNotNull);
        expect(active!.endedAt, isNull);
      },
    );

    test(
      'no alcoholic drinks logged, now >= startedAt + 12h — auto-ends at '
      'startedAt + 12h (not "now")',
      () async {
        // Source: data-model.md §PartySession → Auto-end semantics: "endedAt
        // is set to the correct 12-hour mark, not to the time the app
        // happened to notice."
        final startedAt = DateTime.utc(2026, 7, 10, 20, 0);
        await repo.startSession(now: startedAt, startedAt: startedAt);
        final mark = startedAt.add(const Duration(hours: 12));

        // "now" is deliberately far past the mark to prove endedAt tracks
        // the mark, not the discovery time.
        await repo.checkAndApplyAutoEnd(
          now: mark.add(const Duration(days: 3)),
        );

        final session = await db.getPartySessionById(
          (await db.select(db.partySessions).get()).single.id,
        );
        // Drift may return endedAt without the `isUtc` flag set even though
        // it represents the same instant — DateTime.== treats those as
        // unequal, so compare instants explicitly (same convention as
        // drinks_repository_test.dart's `isAtSameMomentAs`).
        expect(session!.endedAt!.isAtSameMomentAs(mark), isTrue);
        expect(session.endReason, PartySessionEndReason.autoTimeout.stored);
      },
    );

    test(
      'now == startedAt + 12h exactly — still auto-ends (boundary is >=, '
      'not strictly >)',
      () async {
        // Source: PartySessionRepository.checkAndApplyAutoEnd() —
        // `if (!nowUtc.isBefore(autoEndAt))`, i.e. `now >= autoEndAt` ends
        // the session, including the exact instant.
        final startedAt = DateTime.utc(2026, 7, 10, 20, 0);
        await repo.startSession(now: startedAt, startedAt: startedAt);
        final mark = startedAt.add(const Duration(hours: 12));

        await repo.checkAndApplyAutoEnd(now: mark);

        final session = await db.getPartySessionById(
          (await db.select(db.partySessions).get()).single.id,
        );
        expect(session!.endedAt, isNotNull);
        expect(session.endReason, PartySessionEndReason.autoTimeout.stored);
      },
    );

    test(
      'alcoholic drink logged at T inside the session, now >= T + 12h — '
      'auto-ends at T + 12h',
      () async {
        // Source: party-session.md §Ending a session: "12 hours after the
        // most recently logged alcoholic drink."
        final startedAt = DateTime.utc(2026, 7, 10, 12, 0);
        final session = await repo.startSession(
          now: startedAt,
          startedAt: startedAt,
        );
        final drinkAt = startedAt.add(const Duration(hours: 3));
        await repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: session.id,
          consumedAt: drinkAt,
          now: drinkAt,
        );
        final mark = drinkAt.add(const Duration(hours: 12));

        await repo.checkAndApplyAutoEnd(
          now: mark.add(const Duration(days: 1)),
        );

        final row = await db.getPartySessionById(session.id);
        expect(row!.endedAt!.isAtSameMomentAs(mark), isTrue);
        expect(
          row.endedAt!
              .isAtSameMomentAs(startedAt.add(const Duration(hours: 12))),
          isFalse,
          reason:
              'the mark must be measured from the last alcoholic drink, not startedAt',
        );
      },
    );

    test(
      'startSession() lazily auto-ends a stale previous session, then '
      'starts the new one without StateError',
      () async {
        final firstStart = DateTime.utc(2026, 7, 10, 8, 0);
        final firstSession = await repo.startSession(
          now: firstStart,
          startedAt: firstStart,
        );

        // 13h later — the first session should have auto-ended 1h ago.
        final secondStart = firstStart.add(const Duration(hours: 13));
        final secondSession = await repo.startSession(
          now: secondStart,
          startedAt: secondStart,
        );

        expect(secondSession.id, isNot(firstSession.id));
        final firstRow = await db.getPartySessionById(firstSession.id);
        expect(
          firstRow!.endedAt!.isAtSameMomentAs(
            firstStart.add(const Duration(hours: 12)),
          ),
          isTrue,
        );
        expect(firstRow.endReason, PartySessionEndReason.autoTimeout.stored);

        final active = await db.getActiveSession();
        expect(active!.id, secondSession.id);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // 4. Orphan absorption
  // ---------------------------------------------------------------------------

  group('PartySessionRepository — orphan absorption', () {
    // Worked example (design/party-session.md §Worked example): 75 kg,
    // 180 cm, 30-year-old male, two 250 ml 5% ABV beers "at the same time" —
    // modelled here as one 500 ml 5% orphan drink (same total alcohol dose)
    // so a *single* orphan's independently-computed BAC_initial matches the
    // worked example's combined figure.
    //
    // NOTE: flutter/packages/core/test/bac_test.dart already flags a spec
    // discrepancy — the doc's stated TBW (43.93 L) does not match its own
    // Watson coefficients, which evaluate to TBW ≈ 44.14 L → BAC ≈ 0.360 g/L
    // (not the doc's stated 0.362 g/L). These tests compute the expected
    // values via `core`'s own functions (the authoritative, formula-correct
    // source), not the doc's arithmetic, consistent with bac_test.dart.
    const birthDate = '1996-07-01';
    final consumedAt = DateTime.utc(2026, 7, 1, 12, 0);

    // Mirrors PartySessionRepository.orphanAbsorption()'s own computation
    // exactly (alcoholGrams → watsonTbwLitres → bacInitialWatson → /β),
    // so the boundary assertions below are checked against the same
    // Parity-Rulebook formula the repository is built from, not a
    // hand-derived or implementation-output value.
    final ageYears = ageYearsFromBirthDate(
      birthDate: DateTime.parse(birthDate),
      today: consumedAt.toLocal(),
    );
    final grams = alcoholGrams(volumeMl: 500, abvPercent: 5.0);
    final tbw = watsonTbwLitres(
      gender: Gender.male,
      ageYears: ageYears,
      heightCm: 180.0,
      weightKg: 75.0,
    );
    final bacInitial = bacInitialWatson(alcoholGrams: grams, tbwLitres: tbw);
    final hoursToZero = bacInitial / eliminationBetaGPerLPerHour;
    final tZero = consumedAt.add(
      Duration(
          microseconds: (hoursToZero * Duration.microsecondsPerHour).round()),
    );

    test('sanity: matches the (formula-correct) worked example', () {
      expect(bacInitial, closeTo(0.360, 0.001));
      expect(hoursToZero, closeTo(2.4, 0.01));
    });

    test(
      'orphan whose t_zero is AFTER the new session startedAt is absorbed '
      '(startedAt = t_zero − 1µs)',
      () async {
        final db = _memDb();
        addTearDown(db.close);
        await _seedProfile(db, birthDate: birthDate);
        final orphanId = await _insertOrphanDrink(db, consumedAt: consumedAt);
        final repo = PartySessionRepository(db);

        final startedAt = tZero.subtract(const Duration(microseconds: 1));
        final session = await repo.startSession(
          startedAt: startedAt,
          now: startedAt,
        );

        final entries = await db.select(db.drinkEntries).get();
        final orphan = entries.singleWhere((e) => e.id == orphanId);
        expect(
          orphan.partySessionId,
          session.id,
          reason: 't_zero > startedAt → absorbed (party-session.md §Absorbing '
              'orphan drinks)',
        );
      },
    );

    test(
      'orphan whose t_zero equals the new session startedAt stays orphan '
      '(strict > comparison, not >=)',
      () async {
        final db = _memDb();
        addTearDown(db.close);
        await _seedProfile(db, birthDate: birthDate);
        final orphanId = await _insertOrphanDrink(db, consumedAt: consumedAt);
        final repo = PartySessionRepository(db);

        final session = await repo.startSession(startedAt: tZero, now: tZero);

        final entries = await db.select(db.drinkEntries).get();
        final orphan = entries.singleWhere((e) => e.id == orphanId);
        expect(orphan.partySessionId, isNull);
        // Sanity: the session itself still starts fine, it just has no
        // absorbed drinks.
        expect(session.isActive, isTrue);
      },
    );

    test(
      'orphan whose t_zero is BEFORE the new session startedAt stays orphan '
      '(startedAt = t_zero + 1µs)',
      () async {
        final db = _memDb();
        addTearDown(db.close);
        await _seedProfile(db, birthDate: birthDate);
        final orphanId = await _insertOrphanDrink(db, consumedAt: consumedAt);
        final repo = PartySessionRepository(db);

        final startedAt = tZero.add(const Duration(microseconds: 1));
        await repo.startSession(startedAt: startedAt, now: startedAt);

        final entries = await db.select(db.drinkEntries).get();
        final orphan = entries.singleWhere((e) => e.id == orphanId);
        expect(orphan.partySessionId, isNull);
      },
    );

    test(
      'multiple orphans, mixed: only the still-active one is absorbed — '
      'absorption happens automatically via startSession() (no opt-out); '
      'see the standalone orphanAbsorption() test below for the return-value '
      'count assertion',
      () async {
        final db = _memDb();
        addTearDown(db.close);
        await _seedProfile(db, birthDate: birthDate);
        final repo = PartySessionRepository(db);

        // Still active at sessionStart: logged just now.
        final freshId = await _insertOrphanDrink(
          db,
          id: 'orphan-fresh',
          consumedAt: consumedAt,
        );
        // Fully decayed long before sessionStart (30 days earlier).
        final staleId = await _insertOrphanDrink(
          db,
          id: 'orphan-stale',
          consumedAt: consumedAt.subtract(const Duration(days: 30)),
        );

        final startedAt = tZero.subtract(const Duration(microseconds: 1));
        final session = await repo.startSession(
          startedAt: startedAt,
          now: startedAt,
        );

        final entries = await db.select(db.drinkEntries).get();
        final fresh = entries.singleWhere((e) => e.id == freshId);
        final stale = entries.singleWhere((e) => e.id == staleId);
        expect(fresh.partySessionId, session.id);
        expect(stale.partySessionId, isNull);
      },
    );

    test(
      'orphanAbsorption() return value counts exactly the absorbed orphans',
      () async {
        final db = _memDb();
        addTearDown(db.close);
        await _seedProfile(db, birthDate: birthDate);
        await _insertOrphanDrink(db,
            id: 'orphan-fresh', consumedAt: consumedAt);
        await _insertOrphanDrink(
          db,
          id: 'orphan-stale',
          consumedAt: consumedAt.subtract(const Duration(days: 30)),
        );
        final repo = PartySessionRepository(db);

        final startedAt = tZero.subtract(const Duration(microseconds: 1));
        final absorbedCount = await repo.orphanAbsorption(
          newSessionId: 'standalone-session-id',
          startedAt: startedAt,
          now: startedAt,
        );

        expect(absorbedCount, 1);
      },
    );

    test(
      'missing UserProfile throws StateError (standalone orphanAbsorption())',
      () async {
        final db = _memDb();
        addTearDown(db.close);
        // At least one orphan must exist — orphanAbsorption() short-circuits
        // to 0 (no throw) when there are no orphans at all, since the
        // profile is only read once orphans are found.
        await _insertOrphanDrink(db, consumedAt: consumedAt);
        final repo = PartySessionRepository(db);

        expect(
          () => repo.orphanAbsorption(
            newSessionId: 'session-x',
            startedAt: consumedAt,
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'UserProfile with null birthDate throws StateError '
      '(standalone orphanAbsorption())',
      () async {
        final db = _memDb();
        addTearDown(db.close);
        await _seedProfile(db, birthDate: null);
        await _insertOrphanDrink(db, consumedAt: consumedAt);
        final repo = PartySessionRepository(db);

        expect(
          () => repo.orphanAbsorption(
            newSessionId: 'session-x',
            startedAt: consumedAt,
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('Widmark fallback path (no heightCm) absorbs correctly', () async {
      // Source: party-session.md §Required user inputs — "When height is
      // missing, it falls back to Widmark."
      final db = _memDb();
      addTearDown(db.close);
      await _seedProfile(db, birthDate: birthDate, heightCm: null);
      final orphanId = await _insertOrphanDrink(db, consumedAt: consumedAt);
      final repo = PartySessionRepository(db);

      final widmarkGrams = alcoholGrams(volumeMl: 500, abvPercent: 5.0);
      final widmarkBacInitial = bacInitialWidmark(
        alcoholGrams: widmarkGrams,
        weightKg: 75.0,
        r: widmarkR(Gender.male),
      );
      final widmarkHoursToZero =
          widmarkBacInitial / eliminationBetaGPerLPerHour;
      final widmarkTZero = consumedAt.add(
        Duration(
          microseconds:
              (widmarkHoursToZero * Duration.microsecondsPerHour).round(),
        ),
      );

      final startedAt = widmarkTZero.subtract(const Duration(microseconds: 1));
      final session = await repo.startSession(
        startedAt: startedAt,
        now: startedAt,
      );

      final entries = await db.select(db.drinkEntries).get();
      final orphan = entries.singleWhere((e) => e.id == orphanId);
      expect(orphan.partySessionId, session.id);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Meal insertion
  // ---------------------------------------------------------------------------

  group('PartySessionRepository — addMeal / watchSessionMeals', () {
    late AppDatabase db;
    late PartySessionRepository repo;

    setUp(() {
      db = _memDb();
      repo = PartySessionRepository(db);
    });

    tearDown(() => db.close());

    test(
      'addMeal persists size/eatenAt; watchSessionMeals streams back a Meal '
      '(pure-Dart model, not a Drift row)',
      () async {
        final startedAt = DateTime.utc(2026, 7, 10, 20, 0);
        final session = await repo.startSession(
          now: startedAt,
          startedAt: startedAt,
        );
        final eatenAt = startedAt.add(const Duration(hours: 1));

        final meal = await repo.addMeal(
          sessionId: session.id,
          size: MealSize.medium,
          eatenAt: eatenAt,
          now: eatenAt,
        );

        expect(meal.size, MealSize.medium);
        expect(meal.eatenAt, eatenAt);
        expect(meal.partySessionId, session.id);

        final streamed = await repo.watchSessionMeals(session.id).first;
        expect(streamed, hasLength(1));
        expect(streamed.single.size, MealSize.medium);
        // Drift may return eatenAt without the `isUtc` flag set even though
        // it represents the same instant — compare instants explicitly.
        expect(streamed.single.eatenAt.isAtSameMomentAs(eatenAt), isTrue);
        // pure-Dart Meal model, not a Drift MealRow — a regression that
        // returned the raw row would still satisfy isA<Object>(), so assert
        // the concrete domain type.
        expect(streamed.single, isA<Meal>());
      },
    );
  });

  group(
    'PartySessionRepository.updateMeal (party-session.md §Party tab during '
    'a session: meal indicator "edit the last one")',
    () {
      late AppDatabase db;
      late PartySessionRepository repo;

      setUp(() {
        db = _memDb();
        repo = PartySessionRepository(db);
      });

      tearDown(() => db.close());

      test(
        "updates the meal's size and leaves eatenAt untouched",
        () async {
          final startedAt = DateTime.utc(2026, 7, 10, 20, 0);
          final session = await repo.startSession(
            now: startedAt,
            startedAt: startedAt,
          );
          final eatenAt = startedAt.add(const Duration(hours: 1));
          final meal = await repo.addMeal(
            sessionId: session.id,
            size: MealSize.small,
            eatenAt: eatenAt,
            now: eatenAt,
          );

          await repo.updateMeal(id: meal.id, size: MealSize.large);

          final streamed = await repo.watchSessionMeals(session.id).first;
          expect(streamed.single.size, MealSize.large);
          expect(
            streamed.single.eatenAt.isAtSameMomentAs(eatenAt),
            isTrue,
            reason: 'updateMeal doc: "Leaves Meal.eatenAt untouched — '
                'editing corrects a mis-picked size, not when the meal '
                'happened."',
          );
        },
      );

      test('throws StateError for an unknown meal id', () async {
        expect(
          () => repo.updateMeal(id: 'no-such-meal', size: MealSize.medium),
          throwsA(isA<StateError>()),
        );
      });
    },
  );

  // ---------------------------------------------------------------------------
  // 6. logAlcoholicDrink
  // ---------------------------------------------------------------------------

  group('PartySessionRepository.logAlcoholicDrink', () {
    late AppDatabase db;
    late PartySessionRepository repo;
    late String sessionId;

    setUp(() async {
      db = _memDb();
      repo = PartySessionRepository(db);
      final startedAt = DateTime.utc(2026, 7, 10, 20, 0);
      final session = await repo.startSession(
        now: startedAt,
        startedAt: startedAt,
      );
      sessionId = session.id;
    });

    tearDown(() => db.close());

    test('snapshots preset fields and sets partySessionId', () async {
      final entry = await repo.logAlcoholicDrink(
        preset: _beerPreset,
        sessionId: sessionId,
      );

      expect(entry.name, _beerPreset.name);
      expect(entry.beverageType, _beerPreset.beverageType);
      expect(entry.volumeMl, _beerPreset.volumeMl);
      expect(entry.abvPercent, _beerPreset.abvPercent);
      expect(entry.iconKey, _beerPreset.iconKey);
      expect(entry.iconColor, _beerPreset.iconColor);
      expect(entry.partySessionId, sessionId);
    });

    test(
      'sets presetId to the logged preset\'s id (issue #78 — feeds the '
      'preset-usage aggregation behind Recently-used/Most-used sort modes)',
      () async {
        final entry = await repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: sessionId,
        );

        expect(entry.presetId, _beerPreset.id);

        final row = await db.getPartySessionById(sessionId);
        expect(row, isNotNull); // sanity: session itself is unaffected
        final persisted = (await db.select(db.drinkEntries).get()).singleWhere(
          (e) => e.id == entry.id,
        );
        expect(persisted.presetId, _beerPreset.id);
      },
    );

    test('ABV override replaces the preset default', () async {
      // Source: party-session.md §Logging an alcoholic drink — "ABV override
      // — the user can override the ABV for any entry."
      final entry = await repo.logAlcoholicDrink(
        preset: _beerPreset,
        sessionId: sessionId,
        abvPercent: 8.0,
      );

      expect(entry.abvPercent, 8.0);
      expect(entry.abvPercent, isNot(_beerPreset.abvPercent));
    });

    test(
      'an explicit id is honored on both the returned and persisted '
      'DrinkEntry (mirrors DrinksRepository.logDrink\'s id param — issue '
      '#85: lets a caller generate the id up front, e.g. so a popped '
      'LoggedDrinkResult is available before the write settles)',
      () async {
        final entry = await repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: sessionId,
          id: 'caller-provided-id',
        );

        expect(entry.id, 'caller-provided-id');
        final persisted = (await db.select(db.drinkEntries).get()).singleWhere(
          (e) => e.id == 'caller-provided-id',
        );
        expect(persisted.id, 'caller-provided-id');
      },
    );

    test(
      'omitting id still generates a fresh uuid (regression: id must stay '
      'optional)',
      () async {
        final entry = await repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: sessionId,
        );

        expect(entry.id, isNotEmpty);
        expect(entry.id, isNot('caller-provided-id'));
      },
    );

    test(
      'a name override replaces the preset\'s name on the logged/persisted '
      'entry (party-session.md §Logging an alcoholic drink (during a '
      'session) — a one-off, this-entry-only override, same shape as '
      'DrinksRepository.logDrink\'s name param; see '
      'drinks_repository_test.dart "logDrink name/priceMinor/currency '
      'overrides" group for the pattern this mirrors)',
      () async {
        final entry = await repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: sessionId,
          name: 'Entry-only Name',
        );

        expect(entry.name, 'Entry-only Name');
        final persisted = (await db.select(db.drinkEntries).get()).singleWhere(
          (e) => e.id == entry.id,
        );
        expect(persisted.name, 'Entry-only Name');
      },
    );

    test(
      'name override is NFC-normalized before persisting (same convention '
      'as DrinksRepository.logDrink\'s name override — username.dart '
      'normalizeNfc doc: "visually identical inputs produce the same '
      'stored bytes")',
      () async {
        // NFD form of 'café' — 'e' followed by a combining acute accent
        // (U+0301) instead of the precomposed 'é' (U+00E9). Written via
        // explicit \u{} escapes (not a literal combining-mark character) so
        // the source bytes can't get silently re-normalized to NFC by an
        // editor/tool round-trip.
        const nfdName = 'Cafe\u{0301} Latte';
        final entry = await repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: sessionId,
          name: nfdName,
        );

        expect(entry.name, normalizeNfc(nfdName));
        expect(entry.name, isNot(equals(nfdName)));
      },
    );

    test(
      'omitting name still defaults to preset.name (regression)',
      () async {
        final entry = await repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: sessionId,
        );

        expect(entry.name, _beerPreset.name);
      },
    );

    test(
      'an invalid name throws ArgumentError, same as '
      'DrinksRepository.logDrink\'s name override (validatePresetName)',
      () async {
        expect(
          () => repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: sessionId,
            name: 'ab', // < 3 runes — validatePresetName's structural error.
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('rejects a non-alcoholic preset', () async {
      expect(
        () =>
            repo.logAlcoholicDrink(preset: _waterPreset, sessionId: sessionId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects priceMinor + priceTokens both set', () async {
      expect(
        () => repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: sessionId,
          priceMinor: 300,
          currency: 'EUR',
          priceTokens: 2,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects priceMinor set without currency', () async {
      expect(
        () => repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: sessionId,
          priceMinor: 300,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects tokenValueMinor set without priceTokens', () async {
      expect(
        () => repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: sessionId,
          tokenValueMinor: 150,
          tokenValueCurrency: 'EUR',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects tokenValueMinor set without tokenValueCurrency', () async {
      expect(
        () => repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: sessionId,
          priceTokens: 2,
          tokenValueMinor: 150,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects currency set without priceMinor', () async {
      // data-model.md §DrinkEntry: currency is "Required when priceMinor is
      // set; null otherwise" — the reverse direction must be rejected too.
      expect(
        () => repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: sessionId,
          currency: 'EUR',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects tokenValueCurrency set without tokenValueMinor', () async {
      // data-model.md §DrinkEntry: tokenValueCurrency is "Null when
      // priceTokens is null" — also enforced when priceTokens is set but
      // tokenValueMinor itself is left null.
      expect(
        () => repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: sessionId,
          priceTokens: 2,
          tokenValueCurrency: 'EUR',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 6b. updateAlcoholicEntry (issue #86 — S9's active-mode edit affordance)
  // ---------------------------------------------------------------------------

  group(
    'PartySessionRepository.updateAlcoholicEntry (user-experience.md §S9: '
    '"Editable fields are volume, name, ABV, price, and time")',
    () {
      late AppDatabase db;
      late PartySessionRepository repo;
      late String sessionId;
      late String entryId;

      setUp(() async {
        db = _memDb();
        repo = PartySessionRepository(db);
        final startedAt = DateTime.utc(2026, 7, 10, 20, 0);
        final session = await repo.startSession(
          now: startedAt,
          startedAt: startedAt,
        );
        sessionId = session.id;
        final entry = await repo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: sessionId,
          consumedAt: startedAt,
          now: startedAt,
        );
        entryId = entry.id;
      });

      tearDown(() => db.close());

      Future<DrinkEntryRow> persisted() async =>
          (await db.select(db.drinkEntries).get())
              .singleWhere((e) => e.id == entryId);

      test(
        'updating volumeMl independently persists and leaves name/abv/'
        'consumedAt untouched',
        () async {
          await repo.updateAlcoholicEntry(id: entryId, volumeMl: 500);

          final row = await persisted();
          expect(row.volumeMl, 500);
          expect(row.name, _beerPreset.name);
          expect(row.abvPercent, _beerPreset.abvPercent);
          expect(
            row.consumedAt.isAtSameMomentAs(DateTime.utc(2026, 7, 10, 20, 0)),
            isTrue,
          );
        },
      );

      test(
        'updating name independently persists (NFC-normalized) and leaves '
        'volume/abv/consumedAt untouched',
        () async {
          // NFD form of 'café' — same convention as logAlcoholicDrink's own
          // NFC test above (\u{} escape, not a literal combining character).
          const nfdName = 'Cafe\u{0301} Latte';
          await repo.updateAlcoholicEntry(id: entryId, name: nfdName);

          final row = await persisted();
          expect(row.name, normalizeNfc(nfdName));
          expect(row.name, isNot(equals(nfdName)));
          expect(row.volumeMl, _beerPreset.volumeMl);
          expect(row.abvPercent, _beerPreset.abvPercent);
        },
      );

      test(
        'updating abvPercent independently persists and leaves volume/name/'
        'consumedAt untouched',
        () async {
          await repo.updateAlcoholicEntry(id: entryId, abvPercent: 8.5);

          final row = await persisted();
          expect(row.abvPercent, 8.5);
          expect(row.volumeMl, _beerPreset.volumeMl);
          expect(row.name, _beerPreset.name);
        },
      );

      test(
        'updating consumedAt independently persists and leaves volume/name/'
        'abv untouched',
        () async {
          final newConsumedAt = DateTime.utc(2026, 7, 10, 21, 30);
          await repo.updateAlcoholicEntry(
            id: entryId,
            consumedAt: newConsumedAt,
          );

          final row = await persisted();
          expect(row.consumedAt.isAtSameMomentAs(newConsumedAt), isTrue);
          expect(row.volumeMl, _beerPreset.volumeMl);
          expect(row.name, _beerPreset.name);
          expect(row.abvPercent, _beerPreset.abvPercent);
        },
      );

      test('rejects volumeMl < 1', () async {
        expect(
          () => repo.updateAlcoholicEntry(id: entryId, volumeMl: 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects abvPercent <= 0', () async {
        expect(
          () => repo.updateAlcoholicEntry(id: entryId, abvPercent: 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects an invalid name', () async {
        expect(
          () => repo.updateAlcoholicEntry(id: entryId, name: 'ab'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
        'setting priceMinor+currency sets a money price AND clears any '
        'pre-existing token price (data-model.md §DrinkEntry: money/tokens '
        'are mutually exclusive)',
        () async {
          final tokenEntry = await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: sessionId,
            priceTokens: 2,
            tokenValueMinor: 150,
            tokenValueCurrency: 'EUR',
          );

          await repo.updateAlcoholicEntry(
            id: tokenEntry.id,
            priceMinor: const Optional.value(1234),
            currency: const Optional.value('EUR'),
          );

          final row = (await db.select(db.drinkEntries).get())
              .singleWhere((e) => e.id == tokenEntry.id);
          expect(row.priceMinor, 1234);
          expect(row.currency, 'EUR');
          expect(row.priceTokens, isNull);
          expect(row.tokenValueMinor, isNull);
          expect(row.tokenValueCurrency, isNull);
        },
      );

      test(
        'priceMinor: Optional.value(null), currency: Optional.value(null) '
        'clears the price entirely',
        () async {
          await repo.updateAlcoholicEntry(
            id: entryId,
            priceMinor: const Optional.value(500),
            currency: const Optional.value('EUR'),
          );

          await repo.updateAlcoholicEntry(
            id: entryId,
            priceMinor: const Optional.value(null),
            currency: const Optional.value(null),
          );

          final row = await persisted();
          expect(row.priceMinor, isNull);
          expect(row.currency, isNull);
        },
      );

      test(
        'leaving priceMinor/currency at Optional.absent() (the default) '
        'leaves the entry\'s existing price completely untouched',
        () async {
          await repo.updateAlcoholicEntry(
            id: entryId,
            priceMinor: const Optional.value(777),
            currency: const Optional.value('USD'),
          );

          // Unrelated edit, price args left at their Optional.absent()
          // default.
          await repo.updateAlcoholicEntry(id: entryId, volumeMl: 350);

          final row = await persisted();
          expect(row.priceMinor, 777);
          expect(row.currency, 'USD');
          expect(row.volumeMl, 350);
        },
      );

      test(
        'throws ArgumentError if priceMinor.isPresent != currency.isPresent',
        () async {
          expect(
            () => repo.updateAlcoholicEntry(
              id: entryId,
              priceMinor: const Optional.value(500),
            ),
            throwsA(isA<ArgumentError>()),
          );
          expect(
            () => repo.updateAlcoholicEntry(
              id: entryId,
              currency: const Optional.value('EUR'),
            ),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      test(
        'throws ArgumentError when a present priceMinor/currency Optional '
        'pair has only one side null',
        () async {
          expect(
            () => repo.updateAlcoholicEntry(
              id: entryId,
              priceMinor: const Optional.value(500),
              currency: const Optional.value(null),
            ),
            throwsA(isA<ArgumentError>()),
          );
          expect(
            () => repo.updateAlcoholicEntry(
              id: entryId,
              priceMinor: const Optional.value(null),
              currency: const Optional.value('EUR'),
            ),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      test('throws StateError for an unknown entry id', () async {
        expect(
          () => repo.updateAlcoholicEntry(id: 'no-such-entry', volumeMl: 500),
          throwsA(isA<StateError>()),
        );
      });
    },
  );

  // ---------------------------------------------------------------------------
  // 7. setSessionPrices
  // ---------------------------------------------------------------------------

  group('PartySessionRepository.setSessionPrices', () {
    late AppDatabase db;
    late PartySessionRepository repo;
    late String sessionId;

    setUp(() async {
      db = _memDb();
      repo = PartySessionRepository(db);
      final startedAt = DateTime.utc(2026, 7, 10, 20, 0);
      final session = await repo.startSession(
        now: startedAt,
        startedAt: startedAt,
      );
      sessionId = session.id;
    });

    tearDown(() => db.close());

    test(
      'inserting then updating the same drinkPresetId updates the existing '
      'row rather than duplicating it',
      () async {
        // Source: data-model.md §PartySessionPrice — "at most one live
        // PartySessionPrice per (partySessionId, drinkPresetId) pair."
        await repo.setSessionPrices(
          sessionId: sessionId,
          prices: const [
            PartySessionPriceInput(
              drinkPresetId: 'preset-a',
              priceMinor: 300,
              currency: 'EUR',
            ),
          ],
        );
        final afterInsert = await repo.getSessionPrices(sessionId);
        expect(afterInsert, hasLength(1));
        final firstRowId = afterInsert.single.id;

        await repo.setSessionPrices(
          sessionId: sessionId,
          prices: const [
            PartySessionPriceInput(
              drinkPresetId: 'preset-a',
              priceMinor: 500,
              currency: 'EUR',
            ),
          ],
        );
        final afterUpdate = await repo.getSessionPrices(sessionId);

        expect(afterUpdate, hasLength(1), reason: 'must update, not duplicate');
        expect(afterUpdate.single.id, firstRowId);
        expect(afterUpdate.single.priceMinor, 500);
      },
    );

    test('rejects priceMinor + priceTokens both set', () async {
      expect(
        () => repo.setSessionPrices(
          sessionId: sessionId,
          prices: const [
            PartySessionPriceInput(
              drinkPresetId: 'preset-a',
              priceMinor: 300,
              currency: 'EUR',
              priceTokens: 2,
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects priceMinor set without currency', () async {
      expect(
        () => repo.setSessionPrices(
          sessionId: sessionId,
          prices: const [
            PartySessionPriceInput(drinkPresetId: 'preset-a', priceMinor: 300),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects currency set without priceMinor', () async {
      // data-model.md §PartySessionPrice: currency is "Required when
      // priceMinor is set; null otherwise" — reverse direction too.
      expect(
        () => repo.setSessionPrices(
          sessionId: sessionId,
          prices: const [
            PartySessionPriceInput(drinkPresetId: 'preset-a', currency: 'EUR'),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group(
    'PartySessionRepository.setSessionPrices — retroactive sweep (issue #87)',
    () {
      // Source for every expected value below: party-session.md §Editing
      // prices during a session (lines ~293-302) — "Edits are saved
      // immediately and apply to subsequent log actions in this session,
      // and retroactively to every drink already logged in this session
      // from that preset — its priceMinor/priceTokens/currency snapshot is
      // rewritten to match what a fresh log action would resolve to right
      // now (falling back to the regular price when 'no override' is
      // picked, or when the 'use session prices' toggle is off)." and its
      // "Exception:" sentence for the manual-override cases.
      late AppDatabase db;
      late PartySessionRepository repo;

      final startedAt = DateTime.utc(2026, 7, 10, 20, 0);
      final loggedAt = DateTime.utc(2026, 7, 10, 20, 5);
      final sweptAt = DateTime.utc(2026, 7, 10, 21, 0);

      setUp(() {
        db = _memDb();
        repo = PartySessionRepository(db);
      });

      tearDown(() => db.close());

      test(
        'money override sweeps a matching token-priced entry to the money '
        'price and clears the token fields',
        () async {
          final session = await repo.startSession(
            now: startedAt,
            startedAt: startedAt,
            useSessionPrices: true,
          );
          final entry = await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: session.id,
            priceTokens: 3,
            tokenValueMinor: 100,
            tokenValueCurrency: 'EUR',
            now: loggedAt,
          );

          await repo.setSessionPrices(
            sessionId: session.id,
            prices: const [
              PartySessionPriceInput(
                drinkPresetId: 'test-beer-preset',
                priceMinor: 550,
                currency: 'USD',
              ),
            ],
            now: sweptAt,
          );

          final swept = await _getEntry(db, entry.id);
          expect(swept.priceMinor, 550);
          expect(swept.currency, 'USD');
          expect(swept.priceTokens, isNull,
              reason: 'money and tokens stay mutually exclusive');
          expect(swept.tokenValueMinor, isNull);
          expect(swept.tokenValueCurrency, isNull);
          expect(swept.updatedAt.isAtSameMomentAs(sweptAt), isTrue);
        },
      );

      test(
        "token override sweeps a matching money-priced entry to the "
        "override's priceTokens, with tokenValueMinor/tokenValueCurrency "
        'taken from the SESSION (not the override input, which carries '
        'none), and clears the money fields',
        () async {
          final session = await repo.startSession(
            now: startedAt,
            startedAt: startedAt,
            useSessionPrices: true,
            // Deliberately distinct from every money value in this test
            // (300 / 550) so a bug that copies the wrong number is caught.
            // tokenValueCurrency is also deliberately distinct from the
            // entry's own pre-existing currency ('USD' vs 'EUR' below) so a
            // bug that copies the entry's stale currency instead of the
            // session's is caught too — not just tokenValueMinor.
            tokenValueMinor: 150,
            tokenValueCurrency: 'USD',
          );
          final entry = await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: session.id,
            priceMinor: 300,
            currency: 'EUR',
            now: loggedAt,
          );

          await repo.setSessionPrices(
            sessionId: session.id,
            prices: const [
              PartySessionPriceInput(
                drinkPresetId: 'test-beer-preset',
                priceTokens: 4,
              ),
            ],
            now: sweptAt,
          );

          final swept = await _getEntry(db, entry.id);
          expect(swept.priceTokens, 4);
          expect(swept.tokenValueMinor, 150,
              reason: 'must come from the session, not the override input');
          expect(swept.tokenValueCurrency, 'USD',
              reason: "must come from the session, not the entry's own "
                  "pre-existing currency ('EUR')");
          expect(swept.priceMinor, isNull);
          expect(swept.currency, isNull);
          expect(swept.updatedAt.isAtSameMomentAs(sweptAt), isTrue);
        },
      );

      test(
        'the sweep touches EVERY matching non-overridden entry for the '
        'preset, not just the first one it finds — logs two normal entries '
        'from the same preset and confirms both are swept in a single '
        'setSessionPrices call',
        () async {
          final session = await repo.startSession(
            now: startedAt,
            startedAt: startedAt,
            useSessionPrices: true,
          );
          final first = await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: session.id,
            priceMinor: 300,
            currency: 'EUR',
            now: loggedAt,
          );
          final second = await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: session.id,
            priceMinor: 300,
            currency: 'EUR',
            now: loggedAt,
          );

          await repo.setSessionPrices(
            sessionId: session.id,
            prices: const [
              PartySessionPriceInput(
                drinkPresetId: 'test-beer-preset',
                priceMinor: 700,
                currency: 'USD',
              ),
            ],
            now: sweptAt,
          );

          for (final id in [first.id, second.id]) {
            final swept = await _getEntry(db, id);
            expect(swept.priceMinor, 700, reason: 'entry $id must be swept');
            expect(swept.currency, 'USD');
            expect(swept.updatedAt.isAtSameMomentAs(sweptAt), isTrue);
          }
        },
      );

      test(
        '"no override" (priceMinor and priceTokens both null) sweeps a '
        "matching token-priced entry back to the PRESET's regular price and "
        'clears the token fields — requires a real DrinkPreset row since the '
        'sweep looks the preset up by id',
        () async {
          await _insertPresetRow(db, _pricedBeerPreset);
          final session = await repo.startSession(
            now: startedAt,
            startedAt: startedAt,
            useSessionPrices: true,
            tokenValueMinor: 150,
            tokenValueCurrency: 'EUR',
          );
          final entry = await repo.logAlcoholicDrink(
            preset: _pricedBeerPreset,
            sessionId: session.id,
            priceTokens: 5,
            tokenValueMinor: 150,
            tokenValueCurrency: 'EUR',
            now: loggedAt,
          );

          await repo.setSessionPrices(
            sessionId: session.id,
            prices: const [
              PartySessionPriceInput(drinkPresetId: 'test-priced-beer-preset'),
            ],
            now: sweptAt,
          );

          final swept = await _getEntry(db, entry.id);
          expect(swept.priceMinor, 450, reason: "the preset's regular price");
          expect(swept.currency, 'EUR');
          expect(swept.priceTokens, isNull);
          expect(swept.tokenValueMinor, isNull);
          expect(swept.tokenValueCurrency, isNull);
          expect(swept.updatedAt.isAtSameMomentAs(sweptAt), isTrue);
        },
      );

      test(
        'when the touched preset has no matching DrinkPreset row, the sweep '
        'is a graceful no-op for that preset (does not throw) — this is '
        'exactly the shape of the pre-existing setSessionPrices tests above '
        "that use unseeded preset ids like 'preset-a'",
        () async {
          final session = await repo.startSession(
            now: startedAt,
            startedAt: startedAt,
            useSessionPrices: true,
          );
          final entry = await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: session.id,
            priceMinor: 300,
            currency: 'EUR',
            now: loggedAt,
          );

          await expectLater(
            repo.setSessionPrices(
              sessionId: session.id,
              prices: const [
                PartySessionPriceInput(drinkPresetId: 'no-such-preset-row'),
              ],
              now: sweptAt,
            ),
            completes,
          );

          final unchanged = await _getEntry(db, entry.id);
          expect(unchanged.priceMinor, 300);
          expect(unchanged.currency, 'EUR');
        },
      );

      test(
        "useSessionPrices=false always sweeps to the PRESET's regular "
        'price, even though the just-written override carries a different '
        'value — mirrors what resolvePrice would produce for a fresh log '
        'right now',
        () async {
          await _insertPresetRow(db, _pricedBeerPreset);
          final session = await repo.startSession(
            now: startedAt,
            startedAt: startedAt,
            useSessionPrices: false,
          );
          final entry = await repo.logAlcoholicDrink(
            preset: _pricedBeerPreset,
            sessionId: session.id,
            priceMinor: 450,
            currency: 'EUR',
            now: loggedAt,
          );

          await repo.setSessionPrices(
            sessionId: session.id,
            prices: const [
              PartySessionPriceInput(
                drinkPresetId: 'test-priced-beer-preset',
                priceMinor: 999,
                currency: 'USD',
              ),
            ],
            now: sweptAt,
          );

          final swept = await _getEntry(db, entry.id);
          expect(swept.priceMinor, 450,
              reason: 'must be the regular price, not the override (999)');
          expect(swept.currency, 'EUR');
          expect(swept.updatedAt.isAtSameMomentAs(sweptAt), isTrue);
        },
      );

      test(
        'an entry logged with a one-off manual price override '
        '(logAlcoholicDrink(isManualPriceOverride: true)) is exempt from '
        'the sweep, while a normally-logged sibling entry for the same '
        'preset is swept',
        () async {
          final session = await repo.startSession(
            now: startedAt,
            startedAt: startedAt,
            useSessionPrices: true,
          );
          final overridden = await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: session.id,
            priceMinor: 300,
            currency: 'EUR',
            isManualPriceOverride: true,
            now: loggedAt,
          );
          final normal = await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: session.id,
            priceMinor: 300,
            currency: 'EUR',
            now: loggedAt,
          );

          await repo.setSessionPrices(
            sessionId: session.id,
            prices: const [
              PartySessionPriceInput(
                drinkPresetId: 'test-beer-preset',
                priceMinor: 700,
                currency: 'USD',
              ),
            ],
            now: sweptAt,
          );

          final untouched = await _getEntry(db, overridden.id);
          expect(untouched.priceMinor, 300);
          expect(untouched.currency, 'EUR');
          expect(untouched.updatedAt.isAtSameMomentAs(loggedAt), isTrue,
              reason: 'the sweep must never touch this row');

          final swept = await _getEntry(db, normal.id);
          expect(swept.priceMinor, 700);
          expect(swept.currency, 'USD');
          expect(swept.updatedAt.isAtSameMomentAs(sweptAt), isTrue);
        },
      );

      test(
        'updateAlcoholicEntry SETTING priceMinor sets manualPriceOverride, '
        'exempting the entry from a later sweep',
        () async {
          final session = await repo.startSession(
            now: startedAt,
            startedAt: startedAt,
            useSessionPrices: true,
          );
          final entry = await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: session.id,
            priceMinor: 300,
            currency: 'EUR',
            now: loggedAt,
          );
          final editedAt = DateTime.utc(2026, 7, 10, 20, 30);
          await repo.updateAlcoholicEntry(
            id: entry.id,
            priceMinor: const Optional.value(350),
            currency: const Optional.value('EUR'),
            now: editedAt,
          );

          await repo.setSessionPrices(
            sessionId: session.id,
            prices: const [
              PartySessionPriceInput(
                drinkPresetId: 'test-beer-preset',
                priceMinor: 700,
                currency: 'USD',
              ),
            ],
            now: sweptAt,
          );

          final unchanged = await _getEntry(db, entry.id);
          expect(unchanged.priceMinor, 350);
          expect(unchanged.currency, 'EUR');
          expect(unchanged.manualPriceOverride, isTrue);
          expect(unchanged.updatedAt.isAtSameMomentAs(editedAt), isTrue,
              reason: 'the sweep must never touch this row');
        },
      );

      test(
        'updateAlcoholicEntry CLEARING priceMinor to null also sets '
        'manualPriceOverride, exempting the entry from a later sweep',
        () async {
          final session = await repo.startSession(
            now: startedAt,
            startedAt: startedAt,
            useSessionPrices: true,
          );
          final entry = await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: session.id,
            priceMinor: 300,
            currency: 'EUR',
            now: loggedAt,
          );
          final editedAt = DateTime.utc(2026, 7, 10, 20, 30);
          await repo.updateAlcoholicEntry(
            id: entry.id,
            priceMinor: const Optional.value(null),
            currency: const Optional.value(null),
            now: editedAt,
          );

          await repo.setSessionPrices(
            sessionId: session.id,
            prices: const [
              PartySessionPriceInput(
                drinkPresetId: 'test-beer-preset',
                priceMinor: 700,
                currency: 'USD',
              ),
            ],
            now: sweptAt,
          );

          final unchanged = await _getEntry(db, entry.id);
          expect(unchanged.priceMinor, isNull);
          expect(unchanged.currency, isNull);
          expect(unchanged.manualPriceOverride, isTrue);
          expect(unchanged.updatedAt.isAtSameMomentAs(editedAt), isTrue,
              reason: 'the sweep must never touch this row');
        },
      );

      test(
        'the sweep only touches live, session-and-preset-matching entries: '
        'an entry in a different session, an entry for a different preset, '
        'and a soft-deleted entry are all left untouched, while the one '
        'matching live entry is swept — proves both the sweep ran and that '
        'it skipped precisely those rows',
        () async {
          final session = await repo.startSession(
            now: startedAt,
            startedAt: startedAt,
            useSessionPrices: true,
          );
          final matching = await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: session.id,
            priceMinor: 300,
            currency: 'EUR',
            now: loggedAt,
          );

          await _insertRawEntry(
            db,
            id: 'other-session-entry',
            partySessionId: 'some-other-session',
            presetId: 'test-beer-preset',
            priceMinor: 300,
            currency: 'EUR',
            consumedAt: loggedAt,
            updatedAt: loggedAt,
          );
          await _insertRawEntry(
            db,
            id: 'other-preset-entry',
            partySessionId: session.id,
            presetId: 'some-other-preset',
            priceMinor: 300,
            currency: 'EUR',
            consumedAt: loggedAt,
            updatedAt: loggedAt,
          );
          await _insertRawEntry(
            db,
            id: 'soft-deleted-entry',
            partySessionId: session.id,
            presetId: 'test-beer-preset',
            priceMinor: 300,
            currency: 'EUR',
            deletedAt: loggedAt,
            consumedAt: loggedAt,
            updatedAt: loggedAt,
          );

          await repo.setSessionPrices(
            sessionId: session.id,
            prices: const [
              PartySessionPriceInput(
                drinkPresetId: 'test-beer-preset',
                priceMinor: 700,
                currency: 'USD',
              ),
            ],
            now: sweptAt,
          );

          final sweptEntry = await _getEntry(db, matching.id);
          expect(sweptEntry.priceMinor, 700);
          expect(sweptEntry.currency, 'USD');
          expect(sweptEntry.updatedAt.isAtSameMomentAs(sweptAt), isTrue);

          final otherSession = await _getEntry(db, 'other-session-entry');
          expect(otherSession.priceMinor, 300);
          expect(otherSession.currency, 'EUR');
          expect(otherSession.updatedAt.isAtSameMomentAs(loggedAt), isTrue);

          final otherPreset = await _getEntry(db, 'other-preset-entry');
          expect(otherPreset.priceMinor, 300);
          expect(otherPreset.currency, 'EUR');
          expect(otherPreset.updatedAt.isAtSameMomentAs(loggedAt), isTrue);

          final softDeleted = await _getEntry(db, 'soft-deleted-entry');
          expect(softDeleted.priceMinor, 300);
          expect(softDeleted.currency, 'EUR');
          expect(softDeleted.updatedAt.isAtSameMomentAs(loggedAt), isTrue);
        },
      );
    },
  );

  // ---------------------------------------------------------------------------
  // 8. endSession
  // ---------------------------------------------------------------------------

  group('PartySessionRepository.endSession', () {
    late AppDatabase db;
    late PartySessionRepository repo;

    setUp(() {
      db = _memDb();
      repo = PartySessionRepository(db);
    });

    tearDown(() => db.close());

    test('manual end sets endedAt/endReason correctly', () async {
      final startedAt = DateTime.utc(2026, 7, 10, 20, 0);
      final session = await repo.startSession(
        now: startedAt,
        startedAt: startedAt,
      );
      final endAt = startedAt.add(const Duration(hours: 2));

      await repo.endSession(
        session.id,
        PartySessionEndReason.manual,
        now: endAt,
      );

      final row = await db.getPartySessionById(session.id);
      expect(row!.endedAt!.isAtSameMomentAs(endAt), isTrue);
      expect(row.endReason, PartySessionEndReason.manual.stored);
    });

    test('unknown session id throws StateError', () async {
      expect(
        () => repo.endSession('does-not-exist', PartySessionEndReason.manual),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 9. resolvePrice
  // ---------------------------------------------------------------------------

  group('PartySessionRepository.resolvePrice', () {
    late AppDatabase db;
    late PartySessionRepository repo;
    late String sessionId;
    final startedAt = DateTime.utc(2026, 7, 10, 20, 0);

    setUp(() async {
      db = _memDb();
      repo = PartySessionRepository(db);
      final session = await repo.startSession(
        now: startedAt,
        startedAt: startedAt,
      );
      sessionId = session.id;

      // Live money override for `_pricedBeerPreset`, deliberately DIFFERENT
      // from its regular price (300 vs 450) so a test asserting the wrong
      // one would fail.
      await repo.setSessionPrices(
        sessionId: sessionId,
        prices: const [
          PartySessionPriceInput(
            drinkPresetId: 'test-priced-beer-preset',
            priceMinor: 300,
            currency: 'EUR',
          ),
          PartySessionPriceInput(
            drinkPresetId: 'test-token-cocktail-preset',
            priceTokens: 2,
          ),
        ],
      );
    });

    tearDown(() => db.close());

    test(
      'useSessionPrices=false returns the regular price even though a live '
      'override exists (party-session.md §Toggle: use session prices — '
      '"Off: drinks log at their regular price even though overrides '
      'exist") — this is the "toggle off mid-session" case',
      () async {
        final sessionPricesOff = PartySession(
          id: sessionId,
          startedAt: startedAt,
          useSessionPrices: false,
          createdAt: startedAt,
          updatedAt: startedAt,
        );

        final resolved = await repo.resolvePrice(
          session: sessionPricesOff,
          preset: _pricedBeerPreset,
        );

        expect(resolved.priceMinor, 450, reason: 'must be the regular price');
        expect(resolved.currency, 'EUR');
        expect(resolved.priceTokens, isNull);
      },
    );

    test(
      'useSessionPrices=true with a matching money override returns the '
      'override, not the regular price (data-model.md §PartySessionPrice — '
      '"Snapshot at log time") — same override row as the off-case above, '
      'proving the toggle is the discriminator',
      () async {
        final sessionPricesOn = PartySession(
          id: sessionId,
          startedAt: startedAt,
          useSessionPrices: true,
          createdAt: startedAt,
          updatedAt: startedAt,
        );

        final resolved = await repo.resolvePrice(
          session: sessionPricesOn,
          preset: _pricedBeerPreset,
        );

        expect(resolved.priceMinor, 300, reason: 'must be the override');
        expect(resolved.currency, 'EUR');
        expect(resolved.priceTokens, isNull);
      },
    );

    test(
      'useSessionPrices=true with a matching token override returns '
      'priceTokens from the override, and tokenValueMinor/tokenValueCurrency '
      'from the SESSION, not the override — party-session.md §Toggle: use '
      'session prices: "tokens don\'t carry their own value, the session '
      'does"',
      () async {
        final sessionWithTokenValue = PartySession(
          id: sessionId,
          startedAt: startedAt,
          useSessionPrices: true,
          tokenValueMinor: 150,
          tokenValueCurrency: 'USD',
          createdAt: startedAt,
          updatedAt: startedAt,
        );

        final resolved = await repo.resolvePrice(
          session: sessionWithTokenValue,
          preset: _tokenCocktailPreset,
        );

        expect(resolved.priceTokens, 2);
        expect(resolved.tokenValueMinor, 150);
        expect(resolved.tokenValueCurrency, 'USD');
        expect(resolved.priceMinor, isNull);
        expect(resolved.currency, isNull);
      },
    );

    test(
      'useSessionPrices=true with no matching override row falls back to '
      'the regular price (data-model.md §PartySessionPrice → Snapshot at '
      'log time: "falling back to the preset\'s regularPrice* otherwise")',
      () async {
        final sessionPricesOn = PartySession(
          id: sessionId,
          startedAt: startedAt,
          useSessionPrices: true,
          createdAt: startedAt,
          updatedAt: startedAt,
        );

        final resolved = await repo.resolvePrice(
          session: sessionPricesOn,
          preset: _pricedWinePreset,
        );

        expect(resolved.priceMinor, 200);
        expect(resolved.currency, 'USD');
        expect(resolved.priceTokens, isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // 10. getLastSessionPricing
  // ---------------------------------------------------------------------------

  group('PartySessionRepository.getLastSessionPricing', () {
    late AppDatabase db;
    late PartySessionRepository repo;

    setUp(() {
      db = _memDb();
      repo = PartySessionRepository(db);
    });

    tearDown(() => db.close());

    test('returns null when there is no previously-ended session', () async {
      final result = await repo.getLastSessionPricing();
      expect(result, isNull);
    });

    test(
      'returns null when the most recent ended session has zero price '
      'overrides AND no tokenName (party-session.md §Starting a session — '
      'pricing prompt)',
      () async {
        final startedAt = DateTime.utc(2026, 7, 10, 18, 0);
        final session = await repo.startSession(
          now: startedAt,
          startedAt: startedAt,
        );
        await repo.endSession(
          session.id,
          PartySessionEndReason.manual,
          now: startedAt.add(const Duration(hours: 1)),
        );

        final result = await repo.getLastSessionPricing();
        expect(result, isNull);
      },
    );

    test(
      'does NOT return null when the most recent ended session has a '
      'tokenName but zero price overrides — the null rule is an AND of '
      '"no overrides" and "no tokenName", not an OR',
      () async {
        final startedAt = DateTime.utc(2026, 7, 10, 18, 0);
        final session = await repo.startSession(
          now: startedAt,
          startedAt: startedAt,
        );
        await repo.updateTokenConfig(
          sessionId: session.id,
          tokenName: 'Chip',
          now: startedAt,
        );
        await repo.endSession(
          session.id,
          PartySessionEndReason.manual,
          now: startedAt.add(const Duration(hours: 1)),
        );

        final result = await repo.getLastSessionPricing();
        expect(result, isNotNull);
        expect(result!.prices, isEmpty);
        expect(result.tokenName, 'Chip');
      },
    );

    test(
      'returns the price overrides and token config from the most recently '
      'ended session (party-session.md §Starting a session — pricing '
      'prompt: "Choosing yes copies the most recently ended session\'s '
      'PartySessionPrice rows... including currency / tokens")',
      () async {
        final startedAt = DateTime.utc(2026, 7, 10, 18, 0);
        final session = await repo.startSession(
          now: startedAt,
          startedAt: startedAt,
        );
        await repo.setSessionPrices(
          sessionId: session.id,
          prices: const [
            PartySessionPriceInput(
              drinkPresetId: 'preset-a',
              priceMinor: 100,
              currency: 'EUR',
            ),
          ],
        );
        await repo.updateTokenConfig(
          sessionId: session.id,
          tokenName: 'Token',
          tokenValueMinor: 150,
          tokenValueCurrency: 'EUR',
          now: startedAt,
        );
        await repo.endSession(
          session.id,
          PartySessionEndReason.manual,
          now: startedAt.add(const Duration(hours: 2)),
        );

        final result = await repo.getLastSessionPricing();

        expect(result, isNotNull);
        expect(result!.prices, hasLength(1));
        expect(result.prices.single.drinkPresetId, 'preset-a');
        expect(result.prices.single.priceMinor, 100);
        expect(result.prices.single.currency, 'EUR');
        expect(result.tokenName, 'Token');
        expect(result.tokenValueMinor, 150);
        expect(result.tokenValueCurrency, 'EUR');
      },
    );

    test(
      '"most recently ended" is determined by endedAt, not startedAt: a '
      'session that started earlier but ended LATER wins over one that '
      'started later but ended earlier',
      () async {
        // Session A: starts first, but is ended LAST.
        final aStart = DateTime.utc(2026, 6, 1, 10, 0);
        final aEnd = DateTime.utc(2026, 6, 10, 10, 0);
        // Session B: starts AFTER A (more "recent" by startedAt), but is
        // ended BEFORE A finally ends.
        final bStart = DateTime.utc(2026, 6, 5, 10, 0);
        final bEnd = DateTime.utc(2026, 6, 6, 10, 0);

        final sessionA = await repo.startSession(
          now: aStart,
          startedAt: aStart,
        );
        await repo.setSessionPrices(
          sessionId: sessionA.id,
          prices: const [
            PartySessionPriceInput(
              drinkPresetId: 'preset-a',
              priceMinor: 100,
              currency: 'EUR',
            ),
          ],
        );
        await repo.endSession(
          sessionA.id,
          PartySessionEndReason.manual,
          now: aEnd,
        );

        final sessionB = await repo.startSession(
          now: bStart,
          startedAt: bStart,
        );
        await repo.updateTokenConfig(
          sessionId: sessionB.id,
          tokenName: 'ChipFromB',
          now: bStart,
        );
        await repo.endSession(
          sessionB.id,
          PartySessionEndReason.manual,
          now: bEnd,
        );

        final result = await repo.getLastSessionPricing();

        // If ordering were (wrongly) by startedAt, this would return B's
        // data (tokenName 'ChipFromB', no prices). Asserting A's data
        // proves endedAt is the actual ordering key.
        expect(result, isNotNull);
        expect(result!.prices, hasLength(1));
        expect(result.prices.single.drinkPresetId, 'preset-a');
        expect(result.tokenName, isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // 11. setUseSessionPrices
  // ---------------------------------------------------------------------------

  group('PartySessionRepository.setUseSessionPrices', () {
    late AppDatabase db;
    late PartySessionRepository repo;

    setUp(() {
      db = _memDb();
      repo = PartySessionRepository(db);
    });

    tearDown(() => db.close());

    test(
      'flips useSessionPrices live, mid-session (party-session.md §Toggle: '
      'use session prices)',
      () async {
        final startedAt = DateTime.utc(2026, 7, 10, 20, 0);
        final session = await repo.startSession(
          now: startedAt,
          startedAt: startedAt,
          useSessionPrices: false,
        );
        expect(session.useSessionPrices, isFalse);

        await repo.setUseSessionPrices(
          session.id,
          true,
          now: startedAt.add(const Duration(minutes: 5)),
        );

        final row = await db.getPartySessionById(session.id);
        expect(row!.useSessionPrices, isTrue);
      },
    );

    test('unknown session id throws StateError', () async {
      expect(
        () => repo.setUseSessionPrices('does-not-exist', true),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 11b. getSessionById
  // ---------------------------------------------------------------------------

  group('PartySessionRepository.getSessionById', () {
    late AppDatabase db;
    late PartySessionRepository repo;

    setUp(() {
      db = _memDb();
      repo = PartySessionRepository(db);
    });

    tearDown(() => db.close());

    test(
      'reflects writes made after startSession — the UI start-flow relies '
      'on this to pick up useSessionPrices/token config set by the pricing '
      'prompt right after the session was created, instead of resolving '
      'prices against a stale in-memory PartySession',
      () async {
        final startedAt = DateTime.utc(2026, 7, 10, 20, 0);
        final session = await repo.startSession(
          now: startedAt,
          startedAt: startedAt,
        );
        expect(session.useSessionPrices, isFalse);

        await repo.setUseSessionPrices(session.id, true);
        await repo.updateTokenConfig(
          sessionId: session.id,
          tokenName: 'Munt',
          tokenValueMinor: 100,
          tokenValueCurrency: 'EUR',
        );

        final refreshed = await repo.getSessionById(session.id);
        expect(refreshed.useSessionPrices, isTrue);
        expect(refreshed.tokenName, 'Munt');
        expect(refreshed.tokenValueMinor, 100);
        expect(refreshed.tokenValueCurrency, 'EUR');
      },
    );

    test('unknown session id throws StateError', () async {
      expect(
        () => repo.getSessionById('does-not-exist'),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 12. updateTokenConfig
  // ---------------------------------------------------------------------------

  group('PartySessionRepository.updateTokenConfig', () {
    late AppDatabase db;
    late PartySessionRepository repo;
    late String sessionId;

    setUp(() async {
      db = _memDb();
      repo = PartySessionRepository(db);
      final startedAt = DateTime.utc(2026, 7, 10, 20, 0);
      final session = await repo.startSession(
        now: startedAt,
        startedAt: startedAt,
      );
      sessionId = session.id;
    });

    tearDown(() => db.close());

    test(
      'updates tokenName/tokenValueMinor/tokenValueCurrency on the session '
      'row (party-session.md §Money vs tokens: configurable "any time '
      'during the session")',
      () async {
        await repo.updateTokenConfig(
          sessionId: sessionId,
          tokenName: 'Chip',
          tokenValueMinor: 150,
          tokenValueCurrency: 'EUR',
        );

        final row = await db.getPartySessionById(sessionId);
        expect(row!.tokenName, 'Chip');
        expect(row.tokenValueMinor, 150);
        expect(row.tokenValueCurrency, 'EUR');
      },
    );

    test('rejects tokenValueMinor set without tokenValueCurrency', () async {
      expect(
        () => repo.updateTokenConfig(
          sessionId: sessionId,
          tokenValueMinor: 150,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects tokenValueCurrency set without tokenValueMinor', () async {
      expect(
        () => repo.updateTokenConfig(
          sessionId: sessionId,
          tokenValueCurrency: 'EUR',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'rejects a tokenName over 30 characters (Parity Rulebook §Username '
      'length — validateUsername max length applies regardless of '
      'minLength)',
      () async {
        final tooLong = 'a' * 31;
        expect(
          () =>
              repo.updateTokenConfig(sessionId: sessionId, tokenName: tooLong),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('unknown session id throws StateError', () async {
      expect(
        () => repo.updateTokenConfig(
          sessionId: 'does-not-exist',
          tokenName: 'Chip',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 6. History — watchSessionsInRange / getEntriesForSessions /
  //    getMealsForSessions (issue #26)
  // ---------------------------------------------------------------------------

  group(
    'PartySessionRepository.watchEndedSessions (user-experience.md §S7 → '
    'No active session — subsequent visits: the past-sessions list)',
    () {
      late AppDatabase db;
      late PartySessionRepository repo;

      setUp(() {
        db = _memDb();
        repo = PartySessionRepository(db);
      });

      tearDown(() => db.close());

      test(
        'excludes the currently-active session (endedAt IS NULL)',
        () async {
          await repo.startSession(
            startedAt: DateTime.utc(2026, 7, 10, 20, 0),
            now: DateTime.utc(2026, 7, 10, 20, 0),
          );

          expect(await repo.watchEndedSessions().first, isEmpty);
        },
      );

      test('returns a session once it has ended', () async {
        final session = await repo.startSession(
          startedAt: DateTime.utc(2026, 7, 10, 20, 0),
          now: DateTime.utc(2026, 7, 10, 20, 0),
        );
        await repo.endSession(
          session.id,
          PartySessionEndReason.manual,
          now: DateTime.utc(2026, 7, 10, 22, 0),
        );

        final ended = await repo.watchEndedSessions().first;
        expect(ended.map((s) => s.id).toList(), [session.id]);
      });

      test('orders multiple ended sessions newest-ended-first', () async {
        final first = await repo.startSession(
          startedAt: DateTime.utc(2026, 7, 10, 20, 0),
          now: DateTime.utc(2026, 7, 10, 20, 0),
        );
        await repo.endSession(
          first.id,
          PartySessionEndReason.manual,
          now: DateTime.utc(2026, 7, 10, 21, 0),
        );

        final second = await repo.startSession(
          startedAt: DateTime.utc(2026, 7, 11, 20, 0),
          now: DateTime.utc(2026, 7, 11, 20, 0),
        );
        await repo.endSession(
          second.id,
          PartySessionEndReason.manual,
          now: DateTime.utc(2026, 7, 11, 22, 0),
        );

        final ended = await repo.watchEndedSessions().first;
        expect(ended.map((s) => s.id).toList(), [second.id, first.id]);
      });

      test(
        'excludes a soft-deleted ended session (F7 soft-delete)',
        () async {
          final session = await repo.startSession(
            startedAt: DateTime.utc(2026, 7, 10, 20, 0),
            now: DateTime.utc(2026, 7, 10, 20, 0),
          );
          await repo.endSession(
            session.id,
            PartySessionEndReason.manual,
            now: DateTime.utc(2026, 7, 10, 22, 0),
          );

          // No repository method soft-deletes a PartySession yet — write
          // deletedAt directly at the DB layer to exercise the query's own
          // filter.
          await (db.update(db.partySessions)
                ..where((t) => t.id.equals(session.id)))
              .write(
            PartySessionsCompanion(
              deletedAt: Value(DateTime.utc(2026, 7, 10, 23, 0)),
            ),
          );

          expect(await repo.watchEndedSessions().first, isEmpty);
        },
      );
    },
  );

  group('PartySessionRepository — History range/entries (issue #26)', () {
    late AppDatabase db;
    late PartySessionRepository repo;

    setUp(() {
      db = _memDb();
      repo = PartySessionRepository(db);
    });

    tearDown(() => db.close());

    group('watchSessionsInRange', () {
      test(
        'returns a session fully inside the range, ordered by startedAt',
        () async {
          final earlier = await repo.startSession(
            startedAt: DateTime.utc(2026, 7, 10, 20, 0),
            now: DateTime.utc(2026, 7, 10, 20, 0),
          );
          await repo.endSession(
            earlier.id,
            PartySessionEndReason.manual,
            now: DateTime.utc(2026, 7, 10, 22, 0),
          );

          final sessions = await repo
              .watchSessionsInRange(
                DateTime.utc(2026, 7, 10, 5, 0),
                DateTime.utc(2026, 7, 11, 5, 0),
              )
              .first;

          expect(sessions.map((s) => s.id).toList(), [earlier.id]);
        },
      );

      test(
        'includes a session that only partially overlaps the range '
        '(starts before rangeStart, ends inside it)',
        () async {
          final session = await repo.startSession(
            startedAt: DateTime.utc(2026, 7, 10, 2, 0), // before the range
            now: DateTime.utc(2026, 7, 10, 2, 0),
          );
          await repo.endSession(
            session.id,
            PartySessionEndReason.manual,
            now: DateTime.utc(2026, 7, 10, 8, 0), // inside the range
          );

          final sessions = await repo
              .watchSessionsInRange(
                DateTime.utc(2026, 7, 10, 5, 0),
                DateTime.utc(2026, 7, 11, 5, 0),
              )
              .first;

          expect(sessions.map((s) => s.id).toList(), [session.id]);
        },
      );

      test(
        'an active (endedAt IS NULL) session is treated as open-ended — '
        'included whenever startedAt < rangeEnd',
        () async {
          final active = await repo.startSession(
            startedAt: DateTime.utc(2026, 7, 1, 20, 0),
            now: DateTime.utc(2026, 7, 1, 20, 0),
          );

          // A range far in the future — the still-active session must still
          // be returned since it has no defined end.
          final sessions = await repo
              .watchSessionsInRange(
                DateTime.utc(2026, 8, 1, 5, 0),
                DateTime.utc(2026, 8, 2, 5, 0),
              )
              .first;

          expect(sessions.map((s) => s.id).toList(), [active.id]);
        },
      );

      test(
        'excludes a session that ended before rangeStart',
        () async {
          final past = await repo.startSession(
            startedAt: DateTime.utc(2026, 6, 1, 20, 0),
            now: DateTime.utc(2026, 6, 1, 20, 0),
          );
          await repo.endSession(
            past.id,
            PartySessionEndReason.manual,
            now: DateTime.utc(2026, 6, 1, 22, 0),
          );

          final sessions = await repo
              .watchSessionsInRange(
                DateTime.utc(2026, 7, 10, 5, 0),
                DateTime.utc(2026, 7, 11, 5, 0),
              )
              .first;

          expect(sessions, isEmpty);
        },
      );

      test(
        'excludes a session that starts at/after rangeEnd '
        '(half-open [rangeStart, rangeEnd))',
        () async {
          await repo.startSession(
            startedAt: DateTime.utc(2026, 7, 11, 5, 0), // == rangeEnd
            now: DateTime.utc(2026, 7, 11, 5, 0),
          );

          final sessions = await repo
              .watchSessionsInRange(
                DateTime.utc(2026, 7, 10, 5, 0),
                DateTime.utc(2026, 7, 11, 5, 0),
              )
              .first;

          expect(sessions, isEmpty);
        },
      );

      test('orders multiple overlapping sessions by startedAt', () async {
        final later = await repo.startSession(
          startedAt: DateTime.utc(2026, 7, 10, 20, 0),
          now: DateTime.utc(2026, 7, 10, 20, 0),
        );
        await repo.endSession(
          later.id,
          PartySessionEndReason.manual,
          now: DateTime.utc(2026, 7, 10, 21, 0),
        );
        // Start a second, earlier-starting session — auto-end the first
        // isn't relevant here since it's already manually ended.
        final earlier = await repo.startSession(
          startedAt: DateTime.utc(2026, 7, 10, 8, 0),
          now: DateTime.utc(2026, 7, 10, 22, 0),
        );
        await repo.endSession(
          earlier.id,
          PartySessionEndReason.manual,
          now: DateTime.utc(2026, 7, 10, 23, 0),
        );

        final sessions = await repo
            .watchSessionsInRange(
              DateTime.utc(2026, 7, 10, 5, 0),
              DateTime.utc(2026, 7, 11, 5, 0),
            )
            .first;

        expect(sessions.map((s) => s.id).toList(), [earlier.id, later.id]);
      });
    });

    group('getEntriesForSessions / getMealsForSessions', () {
      test('empty sessionIds list returns an empty list (no query)', () async {
        expect(await repo.getEntriesForSessions(const []), isEmpty);
        expect(await repo.getMealsForSessions(const []), isEmpty);
      });

      test(
        'returns only entries/meals belonging to the requested session ids',
        () async {
          final sessionA = await repo.startSession(
            startedAt: DateTime.utc(2026, 7, 10, 20, 0),
            now: DateTime.utc(2026, 7, 10, 20, 0),
          );
          await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: sessionA.id,
            consumedAt: DateTime.utc(2026, 7, 10, 20, 5),
            now: DateTime.utc(2026, 7, 10, 20, 5),
          );
          await repo.addMeal(
            sessionId: sessionA.id,
            size: MealSize.medium,
            eatenAt: DateTime.utc(2026, 7, 10, 19, 0),
            now: DateTime.utc(2026, 7, 10, 19, 0),
          );
          await repo.endSession(
            sessionA.id,
            PartySessionEndReason.manual,
            now: DateTime.utc(2026, 7, 10, 21, 0),
          );

          final sessionB = await repo.startSession(
            startedAt: DateTime.utc(2026, 7, 11, 20, 0),
            now: DateTime.utc(2026, 7, 11, 20, 0),
          );
          await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: sessionB.id,
            consumedAt: DateTime.utc(2026, 7, 11, 20, 5),
            now: DateTime.utc(2026, 7, 11, 20, 5),
          );
          await repo.addMeal(
            sessionId: sessionB.id,
            size: MealSize.large,
            eatenAt: DateTime.utc(2026, 7, 11, 19, 0),
            now: DateTime.utc(2026, 7, 11, 19, 0),
          );

          final entries = await repo.getEntriesForSessions([sessionA.id]);
          expect(entries, hasLength(1));
          expect(entries.single.partySessionId, sessionA.id);

          final meals = await repo.getMealsForSessions([sessionA.id]);
          expect(meals, hasLength(1));
          expect(meals.single.partySessionId, sessionA.id);
          expect(meals.single.size, MealSize.medium);

          // Requesting both ids returns both sessions' rows.
          final bothEntries = await repo.getEntriesForSessions(
            [sessionA.id, sessionB.id],
          );
          expect(bothEntries, hasLength(2));
        },
      );

      test(
        'excludes a soft-deleted entry from getEntriesForSessions',
        () async {
          final session = await repo.startSession(
            startedAt: DateTime.utc(2026, 7, 10, 20, 0),
            now: DateTime.utc(2026, 7, 10, 20, 0),
          );
          final entry = await repo.logAlcoholicDrink(
            preset: _beerPreset,
            sessionId: session.id,
            consumedAt: DateTime.utc(2026, 7, 10, 20, 5),
            now: DateTime.utc(2026, 7, 10, 20, 5),
          );

          final before = await repo.getEntriesForSessions([session.id]);
          expect(before, hasLength(1));

          await DrinksRepository(db).deleteDrinkEntry(entry.id);

          final after = await repo.getEntriesForSessions([session.id]);
          expect(
            after,
            isEmpty,
            reason: 'getEntriesForSessions must exclude soft-deleted rows '
                '(F7 soft-delete)',
          );
        },
      );
    });
  });
}
