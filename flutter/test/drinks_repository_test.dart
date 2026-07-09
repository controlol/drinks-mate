import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';

// ---------------------------------------------------------------------------
// Helper: open an in-memory database (no file I/O, safe in tests).
// ---------------------------------------------------------------------------
AppDatabase _memDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

// ---------------------------------------------------------------------------
// Helpers for creating user presets in tests.
// ---------------------------------------------------------------------------

/// Creates a simple non-alcoholic user preset with sensible defaults.
Future<String> _createUserPreset(
  DrinksRepository repo, {
  String name = 'My Water',
  BeverageType beverageType = BeverageType.water,
  int volumeMl = 300,
  double? abvPercent,
  String iconKey = 'glass',
  String iconColor = '#3b82f6',
  int sortOrder = 99,
}) async {
  final preset = await repo.createPreset(
    name: name,
    beverageType: beverageType,
    volumeMl: volumeMl,
    abvPercent: abvPercent,
    iconKey: iconKey,
    iconColor: iconColor,
    sortOrder: sortOrder,
  );
  return preset.id;
}

// A minimal non-alcoholic water preset for use with logDrink().
// Water is non-alcoholic (BeverageType.water.isAlcoholic == false) so it
// enters the hydration total, not BAC. Source: data-model.md §BeverageType.
const _waterPreset = DrinkPreset(
  id: 'test-water-preset',
  name: 'Test Water',
  beverageType: BeverageType.water,
  volumeMl: 300,
  iconKey: 'glass',
  iconColor: '#3b82f6',
  isUserCreated: false,
  isHidden: false,
  sortOrder: 99,
);

void main() {
  // -------------------------------------------------------------------------
  // Group 1: watchAllPresets — includes hidden, excludes deleted
  // -------------------------------------------------------------------------

  group('DrinksRepository — watchAllPresets', () {
    test(
      'emits all 14 seeded presets initially (none hidden or deleted)',
      () async {
        // Source: app_database.dart seed — 10 non-alcoholic + 4 alcoholic (F14).
        final db = _memDb();
        addTearDown(db.close);
        final repo = DrinksRepository(db);

        final presets = await repo.watchAllPresets().first;

        expect(presets.length, 14);
      },
    );

    test('still includes a hidden preset', () async {
      // watchAllPresets() includes hidden — only excludes deleted.
      // Source: DrinksRepository.watchAllPresets() docstring.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final allBefore = await repo.watchAllPresets().first;
      final targetId = allBefore.first.id;

      await repo.hidePreset(targetId);
      final allAfter = await repo.watchAllPresets().first;

      expect(allAfter.length, 14);
      expect(allAfter.any((p) => p.id == targetId), isTrue);
    });

    test('excludes a user-created preset after deletePreset()', () async {
      // Soft-delete removes from watchAllPresets().
      // Source: DrinksRepository.deletePreset() docstring; data-model §Soft-delete.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final id = await _createUserPreset(repo);

      // Verify it was added.
      final before = await repo.watchAllPresets().first;
      expect(before.length, 15);

      await repo.deletePreset(id);

      final after = await repo.watchAllPresets().first;
      expect(after.length, 14);
      expect(after.any((p) => p.id == id), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Group 2: watchAlcoholicPresets — returns alcoholic presets
  // -------------------------------------------------------------------------

  group('DrinksRepository — watchAlcoholicPresets', () {
    test(
      'returns exactly 4 seeded alcoholic presets (beer ×2, wine, spirit)',
      () async {
        // Source: app_database.dart seed — 4 alcoholic presets seeded (F14).
        final db = _memDb();
        addTearDown(db.close);
        final repo = DrinksRepository(db);

        final presets = await repo.watchAlcoholicPresets().first;

        expect(presets.length, 4);
        expect(presets.every((p) => p.beverageType.isAlcoholic), isTrue);
      },
    );

    test('excludes a hidden alcoholic preset', () async {
      // party-session.md §Price overrides: "One row per DrinkPreset (excluding
      // hidden ones)" — hidden presets must not appear in the Party Mode picker.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final alcoholic = await repo.watchAlcoholicPresets().first;
      final targetId = alcoholic.first.id;

      await repo.hidePreset(targetId);
      final afterHide = await repo.watchAlcoholicPresets().first;

      expect(afterHide.length, 3);
      expect(afterHide.any((p) => p.id == targetId), isFalse);
    });

    test('does NOT include non-alcoholic presets', () async {
      // Source: data-model.md §BeverageType — alcoholic/non-alcoholic disjoint.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final presets = await repo.watchAlcoholicPresets().first;

      expect(presets.any((p) => !p.beverageType.isAlcoholic), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Group 3: watchVisiblePresets — excludes hidden and deleted
  // -------------------------------------------------------------------------

  group('DrinksRepository — watchVisiblePresets', () {
    test('returns all 14 seeded presets initially (none hidden)', () async {
      // All 14 seed presets have isHidden=false (default) and deletedAt=null.
      // Source: app_database.dart seed; Parity Rulebook F14.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final presets = await repo.watchVisiblePresets().first;

      expect(presets.length, 14);
    });

    test('excludes a preset after hidePreset()', () async {
      // Source: DrinksRepository.watchVisiblePresets() — "non-hidden, non-deleted".
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final allVisible = await repo.watchVisiblePresets().first;
      final targetId = allVisible.first.id;

      await repo.hidePreset(targetId);
      final afterHide = await repo.watchVisiblePresets().first;

      expect(afterHide.length, 13);
      expect(afterHide.any((p) => p.id == targetId), isFalse);
    });

    test('re-includes a preset after unhidePreset()', () async {
      // Source: DrinksRepository.unhidePreset() — restores to visible list.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final allVisible = await repo.watchVisiblePresets().first;
      final targetId = allVisible.first.id;

      await repo.hidePreset(targetId);
      await repo.unhidePreset(targetId);
      final afterUnhide = await repo.watchVisiblePresets().first;

      expect(afterUnhide.length, 14);
      expect(afterUnhide.any((p) => p.id == targetId), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Group 4: createPreset — validation and persistence
  // -------------------------------------------------------------------------

  group('DrinksRepository — createPreset', () {
    late AppDatabase db;
    late DrinksRepository repo;

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    test(
      'valid name (6 chars) creates and returns preset with correct fields',
      () async {
        // Source: Parity Rulebook §DrinkPreset — "3–30 characters".
        final preset = await repo.createPreset(
          name: 'My IPA',
          beverageType: BeverageType.beer,
          volumeMl: 330,
          abvPercent: 5.0,
          iconKey: 'beer_glass',
          iconColor: '#d97706',
          sortOrder: 99,
        );

        expect(preset.name, 'My IPA');
        expect(preset.beverageType, BeverageType.beer);
        expect(preset.volumeMl, 330);
        expect(preset.abvPercent, 5.0);
        expect(preset.iconKey, 'beer_glass');
        expect(preset.iconColor, '#d97706');
        expect(preset.isUserCreated, isTrue);
        expect(preset.isHidden, isFalse);
        expect(preset.id, isNotEmpty);
      },
    );

    test('name too short (2 chars) throws ArgumentError', () async {
      // Source: Parity Rulebook §DrinkPreset — "Must be 3–30 characters".
      expect(
        () => repo.createPreset(
          name: 'ab',
          beverageType: BeverageType.water,
          volumeMl: 200,
          iconKey: 'glass',
          iconColor: '#3b82f6',
          sortOrder: 99,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('name with invalid chars ("My@Beer") throws ArgumentError', () async {
      // Source: Parity Rulebook §DrinkPreset — "@ is not an allowed character".
      expect(
        () => repo.createPreset(
          name: 'My@Beer',
          beverageType: BeverageType.beer,
          volumeMl: 330,
          iconKey: 'beer_glass',
          iconColor: '#d97706',
          sortOrder: 99,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('name with spaces ("My Favourite IPA") is valid', () async {
      // Source: Parity Rulebook §DrinkPreset — "ASCII space is allowed between words".
      final preset = await repo.createPreset(
        name: 'My Favourite IPA',
        beverageType: BeverageType.beer,
        volumeMl: 330,
        abvPercent: 5.0,
        iconKey: 'beer_glass',
        iconColor: '#d97706',
        sortOrder: 99,
      );

      expect(preset.name, 'My Favourite IPA');
      expect(preset.isUserCreated, isTrue);
    });

    test('created preset has isUserCreated == true', () async {
      // Source: DrinksRepository.createPreset() — always sets isUserCreated: true.
      final preset = await repo.createPreset(
        name: 'User Brew',
        beverageType: BeverageType.beer,
        volumeMl: 250,
        abvPercent: 4.5,
        iconKey: 'glass',
        iconColor: '#d97706',
        sortOrder: 99,
      );

      expect(preset.isUserCreated, isTrue);
    });

    test('volumeMl <= 0 throws ArgumentError', () async {
      // Source: data-model.md §DrinkPreset — "volumeMl: Required, must be > 0."
      expect(
        () => repo.createPreset(
          name: 'Zero Vol',
          beverageType: BeverageType.water,
          volumeMl: 0,
          iconKey: 'glass',
          iconColor: '#3b82f6',
          sortOrder: 99,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('alcoholic type without abvPercent throws ArgumentError', () async {
      // Source: data-model.md §DrinkPreset — "abvPercent: Required when
      // beverageType is alcoholic; null otherwise." Null abv → 0 g alcohol in
      // BAC formula (silent parity failure).
      expect(
        () => repo.createPreset(
          name: 'Mystery Beer',
          beverageType: BeverageType.beer,
          volumeMl: 330,
          iconKey: 'beer_glass',
          iconColor: '#d97706',
          sortOrder: 99,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'non-alcoholic type with non-null abvPercent throws ArgumentError',
      () async {
        // Source: data-model.md §DrinkPreset — "abvPercent: null otherwise."
        // Storing a non-null abvPercent on a non-alcoholic preset violates
        // the data-model invariant — any code reading the field without an
        // isAlcoholic guard would see a stale value.
        expect(
          () => repo.createPreset(
            name: 'Spiked Water',
            beverageType: BeverageType.water,
            volumeMl: 300,
            abvPercent: 5.0,
            iconKey: 'glass',
            iconColor: '#3b82f6',
            sortOrder: 99,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'regularPriceMinor set without regularCurrency throws ArgumentError',
      () async {
        // Source: data-model.md §DrinkPreset — "regularCurrency: Required when
        // regularPriceMinor is set; null otherwise."
        expect(
          () => repo.createPreset(
            name: 'Priced Beer',
            beverageType: BeverageType.beer,
            volumeMl: 330,
            abvPercent: 5.0,
            regularPriceMinor: 300,
            iconKey: 'beer_glass',
            iconColor: '#d97706',
            sortOrder: 99,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Group 5: updatePreset — partial update + name validation
  // -------------------------------------------------------------------------

  group('DrinksRepository — updatePreset', () {
    late AppDatabase db;
    late DrinksRepository repo;

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    test(
      'update name only: name changes, volumeMl/abvPercent/iconKey preserved',
      () async {
        // This is the critical "Value.absent() footgun" test.
        // Source: DrinksRepository.updatePreset() — "Only the fields wrapped in a
        // non-absent Value are written".
        // Use non-null abvPercent so we can detect if it was zeroed.
        final id = await _createUserPreset(
          repo,
          name: 'Original Name',
          beverageType: BeverageType.beer,
          volumeMl: 400,
          abvPercent: 6.5,
          iconKey: 'beer_glass',
          iconColor: '#d97706',
        );

        await repo.updatePreset(id: id, name: 'Renamed Beer');

        final presets = await repo.watchAllPresets().first;
        final updated = presets.firstWhere((p) => p.id == id);

        expect(updated.name, 'Renamed Beer');
        // Preserved fields must be unchanged — any null here means Value.absent() bug.
        expect(updated.volumeMl, 400);
        expect(updated.abvPercent, 6.5);
        expect(updated.iconKey, 'beer_glass');
      },
    );

    test(
      'update with invalid name throws ArgumentError, row unchanged',
      () async {
        // Source: Parity Rulebook §DrinkPreset — name validation enforced on update.
        final id = await _createUserPreset(repo, name: 'Good Name');

        expect(
          () => repo.updatePreset(id: id, name: 'X@'),
          throwsA(isA<ArgumentError>()),
        );

        final presets = await repo.watchAllPresets().first;
        final unchanged = presets.firstWhere((p) => p.id == id);
        expect(unchanged.name, 'Good Name');
      },
    );

    test('update volumeMl only: volumeMl changes, name preserved', () async {
      // Source: DrinksRepository.updatePreset() — partial update semantics.
      final id = await _createUserPreset(
        repo,
        name: 'Preserved Name',
        volumeMl: 250,
      );

      await repo.updatePreset(id: id, volumeMl: 500);

      final presets = await repo.watchAllPresets().first;
      final updated = presets.firstWhere((p) => p.id == id);

      expect(updated.volumeMl, 500);
      expect(updated.name, 'Preserved Name');
    });

    test('non-existent id throws StateError', () async {
      // Source: DrinksRepository.updatePreset() — mirrors deletePreset()
      // StateError contract; silently swallowing a missed update would hide
      // stale-ID bugs (e.g. concurrent delete then update).
      expect(
        () => repo.updatePreset(id: 'does-not-exist', name: 'Ghost Update'),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'Value(non-null) abvPercent on non-alcoholic preset throws ArgumentError',
      () async {
        // Source: data-model.md §DrinkPreset — "abvPercent: null otherwise."
        // Setting a non-null abvPercent on a non-alcoholic preset violates the
        // data-model invariant; any code reading the field without isAlcoholic
        // guard would see a stale value.
        final id = await _createUserPreset(repo, name: 'Green Tea');

        expect(
          () => repo.updatePreset(id: id, abvPercent: const Value(0.5)),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('Value(null) abvPercent on non-alcoholic preset is a no-op', () async {
      // Source: data-model.md §DrinkPreset — abvPercent is already null on
      // non-alcoholic presets; Value(null) should be idempotent and not throw.
      final id = await _createUserPreset(repo, name: 'Still Water');

      await repo.updatePreset(id: id, abvPercent: const Value(null));

      final presets = await repo.watchAllPresets().first;
      final updated = presets.firstWhere((p) => p.id == id);
      expect(updated.abvPercent, isNull);
    });

    test(
      'regularPriceMinor set without regularCurrency on update throws ArgumentError',
      () async {
        // Source: data-model.md §DrinkPreset — "regularCurrency: Required when
        // regularPriceMinor is set; null otherwise."
        final id = await _createUserPreset(repo, name: 'My Water');

        expect(
          () => repo.updatePreset(
            id: id,
            regularPriceMinor: const Value(300),
            // regularCurrency absent — effective currency = null on existing row
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('updatePreset volumeMl <= 0 throws ArgumentError', () async {
      // Source: data-model.md §DrinkPreset — "volumeMl: Required, must be > 0."
      final id = await _createUserPreset(repo, name: 'My Water');

      expect(
        () => repo.updatePreset(id: id, volumeMl: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repo.updatePreset(id: id, volumeMl: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'Value(null) abvPercent on an alcoholic preset throws ArgumentError',
      () async {
        // Source: data-model.md §DrinkPreset — "abvPercent: Required when
        // beverageType is alcoholic." Clearing it via Value(null) must be
        // rejected; the BAC formula would silently produce 0 g otherwise.
        final id = await _createUserPreset(
          repo,
          name: 'My Beer',
          beverageType: BeverageType.beer,
          abvPercent: 5.0,
        );

        expect(
          () => repo.updatePreset(id: id, abvPercent: const Value(null)),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('NFC normalisation: NFD name is stored as NFC', () async {
      // Source: username.dart §normalizeNfc — "Apply before persisting any
      // value validated by validatePresetName, so visually identical inputs
      // produce the same stored bytes."
      // "Café" NFD = "Cafe" + combining acute (U+0301)
      const nfdName = 'Café Water'; // 11 chars in NFD form
      final id = await _createUserPreset(repo, name: nfdName);

      final presets = await repo.watchAllPresets().first;
      final stored = presets.firstWhere((p) => p.id == id).name;

      // NFC form: é is a single code point (U+00E9)
      expect(stored, equals('Café Water'));
      expect(stored, isNot(equals(nfdName)));
    });
  });

  // -------------------------------------------------------------------------
  // Group 6: hidePreset / unhidePreset
  // -------------------------------------------------------------------------

  group('DrinksRepository — hidePreset / unhidePreset', () {
    test('hidePreset sets isHidden == true', () async {
      // Source: DrinksRepository.hidePreset() docstring.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final id = await _createUserPreset(repo);

      await repo.hidePreset(id);

      final presets = await repo.watchAllPresets().first;
      final hidden = presets.firstWhere((p) => p.id == id);
      expect(hidden.isHidden, isTrue);
    });

    test('unhidePreset after hide sets isHidden == false', () async {
      // Source: DrinksRepository.unhidePreset() docstring.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final id = await _createUserPreset(repo);

      await repo.hidePreset(id);
      await repo.unhidePreset(id);

      final presets = await repo.watchAllPresets().first;
      final restored = presets.firstWhere((p) => p.id == id);
      expect(restored.isHidden, isFalse);
    });

    test('hidePreset non-existent id throws StateError', () async {
      // Source: DrinksRepository.hidePreset() docstring — "Throws StateError if
      // id does not exist." Consistent with deletePreset / updatePreset contract.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      expect(
        () => repo.hidePreset('unknown-id-that-does-not-exist'),
        throwsA(isA<StateError>()),
      );
    });

    test('unhidePreset non-existent id throws StateError', () async {
      // Source: DrinksRepository.unhidePreset() docstring — "Throws StateError if
      // id does not exist." Consistent with deletePreset / updatePreset contract.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      expect(
        () => repo.unhidePreset('unknown-id-that-does-not-exist'),
        throwsA(isA<StateError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Group 7: deletePreset — soft-delete semantics
  // -------------------------------------------------------------------------

  group('DrinksRepository — deletePreset', () {
    test(
      'user-created preset: succeeds and disappears from watchAllPresets()',
      () async {
        // Source: DrinksRepository.deletePreset() — soft-delete; data-model §Soft-delete.
        final db = _memDb();
        addTearDown(db.close);
        final repo = DrinksRepository(db);

        final id = await _createUserPreset(repo);

        await repo.deletePreset(id);

        // deletedAt is set — verify by absence from watchAllPresets (which filters it out).
        final after = await repo.watchAllPresets().first;
        expect(after.any((p) => p.id == id), isFalse);

        // Verify deletedAt is non-null by reading the raw row.
        final raw = await db.getPresetById(id);
        expect(raw, isNotNull);
        expect(raw!.deletedAt, isNotNull);
      },
    );

    test('seeded default (isUserCreated == false) can be soft-deleted',
        () async {
      // Source: data-model.md §DrinkPreset line 58: "The user can edit, hide,
      // or delete them — there is no special protection." A future reset-to-
      // defaults must use INSERT OR REPLACE (not INSERT OR IGNORE) because soft-
      // deleted rows still exist in the table and OR IGNORE would skip them.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final presets = await repo.watchAllPresets().first;
      final seeded = presets.firstWhere((p) => !p.isUserCreated);

      await repo.deletePreset(seeded.id);

      final after = await repo.watchAllPresets().first;
      expect(after.any((p) => p.id == seeded.id), isFalse);

      // Verify deletedAt is non-null in raw row.
      final raw = await db.getPresetById(seeded.id);
      expect(raw!.deletedAt, isNotNull);
    });

    test('non-existent id throws StateError', () async {
      // Source: DrinksRepository.deletePreset() — "Throws StateError if the
      // preset does not exist."
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      expect(
        () => repo.deletePreset('unknown-id-that-does-not-exist'),
        throwsA(isA<StateError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Group 8: reorderPresets — single-transaction bulk update
  // -------------------------------------------------------------------------

  group('DrinksRepository — reorderPresets', () {
    test('reverses sort order of 3 user-created presets', () async {
      // Source: DrinksRepository.reorderPresets() — "Index 0 receives sortOrder 1."
      // app_database.dart: reorderPresets writes sortOrder = i + 1.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final id1 = await _createUserPreset(
        repo,
        name: 'Preset Alpha',
        sortOrder: 100,
      );
      final id2 = await _createUserPreset(
        repo,
        name: 'Preset Beta',
        sortOrder: 101,
      );
      final id3 = await _createUserPreset(
        repo,
        name: 'Preset Gamma',
        sortOrder: 102,
      );

      // Reverse the order: Gamma→1, Beta→2, Alpha→3.
      await repo.reorderPresets([id3, id2, id1]);

      final presets = await repo.watchAllPresets().first;
      final p1 = presets.firstWhere((p) => p.id == id1);
      final p2 = presets.firstWhere((p) => p.id == id2);
      final p3 = presets.firstWhere((p) => p.id == id3);

      expect(p3.sortOrder, 1);
      expect(p2.sortOrder, 2);
      expect(p1.sortOrder, 3);
    });
  });

  // -------------------------------------------------------------------------
  // Group 9: Snapshot immutability
  // -------------------------------------------------------------------------

  group('DrinksRepository — snapshot immutability', () {
    test(
      'logged DrinkEntry retains snapshotted name/volumeMl after preset update',
      () async {
        // Source: data-model.md §Snapshot semantics — "All preset values are
        // snapshotted at log time." DrinkEntry rows are never touched by updatePreset.
        final db = _memDb();
        addTearDown(db.close);
        final repo = DrinksRepository(db);

        // Create a preset with known name and volume.
        final preset = await repo.createPreset(
          name: 'Original Brew',
          beverageType: BeverageType.beer,
          volumeMl: 330,
          abvPercent: 5.0,
          iconKey: 'beer_glass',
          iconColor: '#d97706',
          sortOrder: 99,
        );

        // Log a drink from that preset — snapshot is taken at this point.
        await repo.logDrink(preset: preset);

        // Update the preset: change name and volumeMl.
        await repo.updatePreset(
          id: preset.id,
          name: 'Renamed Brew',
          volumeMl: 500,
        );

        // Read the logged entry directly from the DB (no public reader needed).
        // The entry must retain the pre-update snapshot values.
        final entries = await db.select(db.drinkEntries).get();
        expect(entries.length, 1);

        final entry = entries.single;
        // Snapshot name must equal the value at log time, not the updated preset name.
        expect(entry.name, 'Original Brew');
        // Snapshot volumeMl must equal the preset's volume at log time.
        expect(entry.volumeMl, 330);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Group 10: watchTodayTotalMl — boundary hour parameter
  // -------------------------------------------------------------------------

  group('DrinksRepository.watchTodayTotalMl — boundaryHour parameter', () {
    late AppDatabase db;
    late DrinksRepository repo;

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    // -----------------------------------------------------------------------
    // Core regression test: the boundary hour MUST change the counted window.
    // -----------------------------------------------------------------------
    test(
        'drink at 22:00 prev-evening is counted with boundary=6 but NOT with '
        'boundary=5 when now=05:30 next morning', () async {
      // Observation point (local time): 2026-06-23 05:30
      // dayWindow(boundary=6): now < 06:00 → [06-22 06:00, 06-23 06:00)
      // dayWindow(boundary=5): now >= 05:00 → [06-23 05:00, 06-24 05:00)
      // Source: core/lib/src/day_boundary.dart
      final now = DateTime(2026, 6, 23, 5, 30); // local, 05:30

      // Drink at 22:00 the previous evening (local time).
      // Inside  [06-22 06:00, 06-23 06:00) → counted when boundary=6.
      // Outside [06-23 05:00, 06-24 05:00) → NOT counted when boundary=5.
      final consumedAt = DateTime(2026, 6, 22, 22, 0); // local, 22:00

      await repo.logDrink(preset: _waterPreset, consumedAt: consumedAt);

      // boundary=6: the drink falls inside the current day window.
      final totalBoundary6 =
          await repo.watchTodayTotalMl(now: now, boundaryHour: 6).first;
      expect(
        totalBoundary6,
        equals(_waterPreset.volumeMl), // 300 ml — drink IS counted
        reason:
            'consumedAt 2026-06-22 22:00 is within [06-22 06:00, 06-23 06:00) '
            "when boundaryHour=6 (dayWindow starts at yesterday's boundary)",
      );

      // boundary=5 (the former default that caused the bug): the drink is
      // before the window start of 2026-06-23 05:00, so it must NOT appear.
      final totalBoundary5 =
          await repo.watchTodayTotalMl(now: now, boundaryHour: 5).first;
      expect(
        totalBoundary5,
        equals(0), // drink is NOT counted
        reason:
            'consumedAt 2026-06-22 22:00 is before window start [06-23 05:00, ...) '
            'when boundaryHour=5; the bug would return 300 here if '
            'boundaryHour were silently ignored',
      );
    });

    // -----------------------------------------------------------------------
    // Symmetry / sanity: a drink clearly inside the default window IS counted.
    // -----------------------------------------------------------------------
    test(
      'drink clearly inside the default 05:00 window is counted with boundary=5',
      () async {
        // now = 2026-06-23 12:00 (midday)
        // dayWindow(boundary=5): [2026-06-23 05:00, 2026-06-24 05:00)
        final now = DateTime(2026, 6, 23, 12, 0);

        // consumedAt = 2026-06-23 09:00 — well inside the window.
        final consumedAt = DateTime(2026, 6, 23, 9, 0);

        await repo.logDrink(preset: _waterPreset, consumedAt: consumedAt);

        final total =
            await repo.watchTodayTotalMl(now: now, boundaryHour: 5).first;
        expect(
          total,
          equals(_waterPreset.volumeMl),
          reason: '09:00 drink is within [05:00, next 05:00) when boundary=5',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Alcoholic beverages must never contribute to the hydration total.
    // Source: data-model.md §BeverageType: "strictly disjoint flows."
    // -----------------------------------------------------------------------
    test(
        'alcoholic drink (beer) is excluded from watchTodayTotalMl even when '
        'consumed inside the time window', () async {
      const beerPreset = DrinkPreset(
        id: 'test-beer-preset',
        name: 'Test Beer',
        beverageType: BeverageType.beer, // isAlcoholic == true
        volumeMl: 250,
        iconKey: 'beer_glass',
        iconColor: '#d97706',
        isUserCreated: false,
        isHidden: false,
        sortOrder: 99,
      );

      final now = DateTime(2026, 6, 23, 12, 0);
      final consumedAt = DateTime(2026, 6, 23, 9, 0); // inside window

      await repo.logDrink(preset: beerPreset, consumedAt: consumedAt);

      final total =
          await repo.watchTodayTotalMl(now: now, boundaryHour: 5).first;
      expect(
        total,
        equals(0),
        reason:
            'Alcoholic beverages must not contribute to the hydration total '
            '(data-model.md §BeverageType)',
      );
    });

    // -----------------------------------------------------------------------
    // Empty database emits 0 immediately (stream contract).
    // -----------------------------------------------------------------------
    test('empty database emits 0 for watchTodayTotalMl', () async {
      final now = DateTime(2026, 6, 23, 12, 0);
      final total =
          await repo.watchTodayTotalMl(now: now, boundaryHour: 5).first;
      expect(total, equals(0));
    });

    // -----------------------------------------------------------------------
    // Multiple drinks: total is the sum of all non-alcoholic volumes in window.
    // -----------------------------------------------------------------------
    test(
      'multiple non-alcoholic drinks inside the window are summed correctly',
      () async {
        final now = DateTime(2026, 6, 23, 12, 0);

        // Two drinks, both inside the window [06-23 05:00, 06-24 05:00).
        await repo.logDrink(
          preset: _waterPreset, // 300 ml
          consumedAt: DateTime(2026, 6, 23, 8, 0),
        );
        await repo.logDrink(
          preset: _waterPreset, // 300 ml
          consumedAt: DateTime(2026, 6, 23, 10, 0),
        );

        final total =
            await repo.watchTodayTotalMl(now: now, boundaryHour: 5).first;
        expect(
          total,
          equals(600), // 300 + 300
          reason: 'Two 300 ml water drinks sum to 600 ml',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // S6 — watchTodayEntries
  // ---------------------------------------------------------------------------

  group('DrinksRepository.watchTodayEntries', () {
    late AppDatabase db;
    late DrinksRepository repo;

    // Fixed observation point inside the default 05:00 window:
    // dayWindow(now=2026-06-23 12:00, boundary=5) = [2026-06-23 05:00, 2026-06-24 05:00)
    final now = DateTime(2026, 6, 23, 12, 0);

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    // -----------------------------------------------------------------------
    // Reverse-chronological order — newest first
    // Source: S6 spec "ordered by consumedAt DESC (newest first)"
    // -----------------------------------------------------------------------
    test(
      'returns entries in reverse-chronological order (newest first)',
      () async {
        final earlier = DateTime(2026, 6, 23, 8, 0);
        final later = DateTime(2026, 6, 23, 10, 0);

        await repo.logDrink(preset: _waterPreset, consumedAt: earlier);
        await repo.logDrink(preset: _waterPreset, consumedAt: later);

        final entries =
            await repo.watchTodayEntries(now: now, boundaryHour: 5).first;

        expect(entries.length, equals(2));
        // Newest entry must appear first (index 0).
        expect(
          entries[0].consumedAt.isAfter(entries[1].consumedAt),
          isTrue,
          reason: 'watchTodayEntries must return entries DESC by consumedAt '
              '(S6 spec: newest first)',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Soft-deleted entries must be excluded
    // Source: data-model.md §F7 soft-delete; "Soft-deleted entries are excluded"
    // -----------------------------------------------------------------------
    test('excludes soft-deleted entries', () async {
      await repo.logDrink(
        preset: _waterPreset,
        consumedAt: DateTime(2026, 6, 23, 9, 0),
      );

      // Read the entry back to get its id (logDrink does not return id).
      final before =
          await repo.watchTodayEntries(now: now, boundaryHour: 5).first;
      expect(before.length, equals(1));
      final id = before.single.id;

      // Soft-delete it (F7 — sets deletedAt, row never hard-deleted).
      await repo.deleteDrinkEntry(id);

      final after =
          await repo.watchTodayEntries(now: now, boundaryHour: 5).first;
      expect(
        after,
        isEmpty,
        reason: 'Soft-deleted entry must not appear in watchTodayEntries '
            '(data-model.md §F7 soft-delete)',
      );
    });

    // -----------------------------------------------------------------------
    // Alcoholic entries must be excluded (disjoint flows)
    // Source: data-model.md §BeverageType: "strictly disjoint flows"
    // S6 spec: "non-alcoholic only (same BeverageType filter as watchTodayTotalMl)"
    // -----------------------------------------------------------------------
    test(
      'excludes alcoholic entries (BeverageType.beer, isAlcoholic == true)',
      () async {
        const beerPreset = DrinkPreset(
          id: 'test-beer-preset-s6',
          name: 'Test Beer',
          beverageType: BeverageType.beer, // isAlcoholic == true
          volumeMl: 250,
          iconKey: 'beer_glass',
          iconColor: '#d97706',
          isUserCreated: false,
          isHidden: false,
          sortOrder: 99,
        );

        await repo.logDrink(
          preset: beerPreset,
          consumedAt: DateTime(2026, 6, 23, 9, 0),
        );

        final entries =
            await repo.watchTodayEntries(now: now, boundaryHour: 5).first;
        expect(
          entries,
          isEmpty,
          reason: 'Alcoholic entries must never appear in watchTodayEntries — '
              'the two flows are strictly disjoint (data-model.md §BeverageType)',
        );
      },
    );

    // -----------------------------------------------------------------------
    // dayBoundaryHour is respected (same semantics as watchTodayTotalMl)
    // Window arithmetic (same as the regression at the top of this file):
    //   now = 2026-06-23 05:30, boundary=6 → [06-22 06:00, 06-23 06:00)
    //   consumedAt = 2026-06-22 22:00  → inside boundary=6, outside boundary=5
    // -----------------------------------------------------------------------
    test(
        'respects dayBoundaryHour: drink at 22:00 prev-evening counted with '
        'boundary=6 but not with boundary=5 when now=05:30', () async {
      final nowBoundary = DateTime(2026, 6, 23, 5, 30);
      final consumedAt = DateTime(2026, 6, 22, 22, 0);

      await repo.logDrink(preset: _waterPreset, consumedAt: consumedAt);

      final withBoundary6 =
          await repo.watchTodayEntries(now: nowBoundary, boundaryHour: 6).first;
      expect(
        withBoundary6.length,
        equals(1),
        reason:
            'consumedAt 2026-06-22 22:00 falls inside [06-22 06:00, 06-23 06:00) '
            'when boundaryHour=6',
      );

      final withBoundary5 =
          await repo.watchTodayEntries(now: nowBoundary, boundaryHour: 5).first;
      expect(
        withBoundary5,
        isEmpty,
        reason:
            'consumedAt 2026-06-22 22:00 is before window start [06-23 05:00, ...) '
            'when boundaryHour=5',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // S6 — updateDrinkEntry
  // ---------------------------------------------------------------------------

  group('DrinksRepository.updateDrinkEntry', () {
    late AppDatabase db;
    late DrinksRepository repo;

    final now = DateTime(2026, 6, 23, 12, 0);

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    // Helper: log a water drink and return its entry.
    Future<DrinkEntry> logAndRead() async {
      await repo.logDrink(
        preset: _waterPreset,
        consumedAt: DateTime(2026, 6, 23, 9, 0),
      );
      return (await repo.watchTodayEntries(now: now, boundaryHour: 5).first)
          .single;
    }

    // -----------------------------------------------------------------------
    // Updating volumeMl only — snapshot fields unchanged
    // Source: data-model.md §Snapshot semantics: only volumeMl and consumedAt
    // are user-editable after log time.
    // -----------------------------------------------------------------------
    test(
      'updateDrinkEntry changes volumeMl and leaves snapshot fields unchanged',
      () async {
        final entry = await logAndRead();

        await repo.updateDrinkEntry(id: entry.id, volumeMl: 450);

        final updated =
            (await repo.watchTodayEntries(now: now, boundaryHour: 5).first)
                .single;

        // The mutable field must be updated.
        expect(updated.volumeMl, equals(450));
        // Snapshot fields must remain unchanged (log immutability).
        expect(
          updated.name,
          equals(_waterPreset.name),
          reason: 'name is a snapshot field and must not change',
        );
        expect(
          updated.beverageType,
          equals(_waterPreset.beverageType),
          reason: 'beverageType is a snapshot field and must not change',
        );
        expect(
          updated.iconKey,
          equals(_waterPreset.iconKey),
          reason: 'iconKey is a snapshot field and must not change',
        );
        expect(
          updated.iconColor,
          equals(_waterPreset.iconColor),
          reason: 'iconColor is a snapshot field and must not change',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Updating consumedAt only — volume unchanged
    // New time must remain within the same day window so the entry stays visible.
    // -----------------------------------------------------------------------
    test(
      'updateDrinkEntry changes consumedAt and leaves volumeMl unchanged',
      () async {
        final entry = await logAndRead();
        // New time within the same window [06-23 05:00, 06-24 05:00).
        final newConsumedAt = DateTime(2026, 6, 23, 11, 30);

        await repo.updateDrinkEntry(id: entry.id, consumedAt: newConsumedAt);

        final updated =
            (await repo.watchTodayEntries(now: now, boundaryHour: 5).first)
                .single;

        // Volume unchanged.
        expect(updated.volumeMl, equals(_waterPreset.volumeMl));
        // consumedAt updated. Compare as UTC instants (Drift stores UTC).
        expect(
          updated.consumedAt.isAtSameMomentAs(newConsumedAt.toUtc()),
          isTrue,
          reason: 'consumedAt must be updated to the new value',
        );
      },
    );

    // -----------------------------------------------------------------------
    // volumeMl < 1 must throw an AssertionError
    // Source: S6 spec "volumeMl must be ≥ 1 ml"
    // ArgumentError is thrown in all build modes (not stripped like assert).
    // -----------------------------------------------------------------------
    test(
      'updateDrinkEntry throws ArgumentError when volumeMl < 1 (volumeMl=0)',
      () {
        expect(
          () => repo.updateDrinkEntry(id: 'any-id', volumeMl: 0),
          throwsArgumentError,
          reason:
              'volumeMl must be ≥ 1 ml (S6 spec); 0 must throw ArgumentError',
        );
      },
    );

    test('updateDrinkEntry throws ArgumentError when volumeMl is negative', () {
      expect(
        () => repo.updateDrinkEntry(id: 'any-id', volumeMl: -10),
        throwsArgumentError,
        reason: 'volumeMl must be ≥ 1 ml (S6 spec); negative value must throw '
            'ArgumentError',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // S6 — deleteDrinkEntry
  // ---------------------------------------------------------------------------

  group('DrinksRepository.deleteDrinkEntry', () {
    late AppDatabase db;
    late DrinksRepository repo;

    final now = DateTime(2026, 6, 23, 12, 0);

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    // -----------------------------------------------------------------------
    // Soft-delete sets deletedAt and entry disappears from watchTodayEntries
    // Source: data-model.md §F7 soft-delete; S6 spec: "sets deletedAt = now"
    // "Row never hard-deleted"
    // -----------------------------------------------------------------------
    test(
        'deleteDrinkEntry sets deletedAt and entry disappears from '
        'watchTodayEntries', () async {
      await repo.logDrink(
        preset: _waterPreset,
        consumedAt: DateTime(2026, 6, 23, 9, 0),
      );

      final before =
          await repo.watchTodayEntries(now: now, boundaryHour: 5).first;
      expect(before.length, equals(1));

      await repo.deleteDrinkEntry(before.single.id);

      final after =
          await repo.watchTodayEntries(now: now, boundaryHour: 5).first;
      expect(
        after,
        isEmpty,
        reason:
            'Entry must disappear from watchTodayEntries after deleteDrinkEntry '
            '(F7 soft-delete: deletedAt is set, row never hard-deleted)',
      );
    });
  });
}
