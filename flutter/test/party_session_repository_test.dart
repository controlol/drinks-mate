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
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/user_profile.dart';
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

void main() {
  // ---------------------------------------------------------------------------
  // 1. Schema migration
  // ---------------------------------------------------------------------------

  group('AppDatabase — schema v4 (fresh onCreate)', () {
    test('schemaVersion is 4 (app_database.dart)', () async {
      final db = _memDb();
      addTearDown(db.close);
      expect(db.schemaVersion, 4);
    });

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

        expect(upgraded.schemaVersion, 4);

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
}
