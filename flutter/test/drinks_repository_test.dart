import 'package:core/core.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/optional.dart';
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

    test('unrecognised iconKey throws ArgumentError', () async {
      // Source: drink_icons.dart kDrinkIconKeys — the bundled icon allowlist;
      // createPreset must reject a key with no matching asset instead of
      // persisting it and failing to resolve at render time.
      expect(
        () => repo.createPreset(
          name: 'Bad Icon',
          beverageType: BeverageType.water,
          volumeMl: 300,
          iconKey: 'not-a-real-icon',
          iconColor: '#3b82f6',
          sortOrder: 99,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
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
          () =>
              repo.updatePreset(id: id, abvPercent: const Optional.value(0.5)),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('Value(null) abvPercent on non-alcoholic preset is a no-op', () async {
      // Source: data-model.md §DrinkPreset — abvPercent is already null on
      // non-alcoholic presets; Value(null) should be idempotent and not throw.
      final id = await _createUserPreset(repo, name: 'Still Water');

      await repo.updatePreset(id: id, abvPercent: const Optional.value(null));

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
            regularPriceMinor: const Optional.value(300),
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
          () =>
              repo.updatePreset(id: id, abvPercent: const Optional.value(null)),
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

    test('unrecognised iconKey throws ArgumentError', () async {
      // Source: drink_icons.dart kDrinkIconKeys — the bundled icon allowlist;
      // updatePreset must reject a key with no matching asset instead of
      // persisting it and failing to resolve at render time.
      final id = await _createUserPreset(repo, name: 'My Water');

      expect(
        () => repo.updatePreset(id: id, iconKey: 'not-a-real-icon'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('iconKey: null (default) leaves the existing iconKey untouched',
        () async {
      // Source: updatePreset() docstring — "Only fields with a present
      // Optional are written; omitted fields retain their current values."
      // iconKey is a plain nullable String (not Optional), so null means
      // "leave unchanged" and must not be validated against kDrinkIconKeys.
      final id = await _createUserPreset(
        repo,
        name: 'My Water',
        iconKey: 'glass',
      );

      await repo.updatePreset(id: id, name: 'Renamed Water');

      final presets = await repo.watchAllPresets().first;
      final updated = presets.firstWhere((p) => p.id == id);
      expect(updated.iconKey, 'glass');
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

    test(
        'seeded default (isUserCreated == false) cannot be deleted: throws '
        'StateError and remains in watchAllPresets()', () async {
      // Source: data-model.md §DrinkPreset "Seeded defaults" — deleting a
      // seeded default has no recovery path until a "Reset to defaults"
      // action exists to re-seed missing defaults, so this is an interim
      // restriction (not a permanent invariant). It is enforced in
      // DrinksRepository.deletePreset() itself — not just in the Manage
      // Drinks UI's `if (preset.isUserCreated)` delete-button gate — so no
      // other caller can bypass it.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final presets = await repo.watchAllPresets().first;
      final seeded = presets.firstWhere((p) => !p.isUserCreated);

      expect(
        () => repo.deletePreset(seeded.id),
        throwsA(isA<StateError>()),
      );

      // The seeded default is untouched: still present in watchAllPresets()
      // and its raw row has no deletedAt.
      final after = await repo.watchAllPresets().first;
      expect(after.any((p) => p.id == seeded.id), isTrue);

      final raw = await db.getPresetById(seeded.id);
      expect(raw!.deletedAt, isNull);
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
  // Group 7b: nextSortOrder — MAX-based, not COUNT-based
  // -------------------------------------------------------------------------

  group('DrinksRepository — nextSortOrder', () {
    test(
        'returns one greater than the current max sortOrder among live '
        'presets', () async {
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      await _createUserPreset(repo, name: 'Preset A', sortOrder: 1000);
      await _createUserPreset(repo, name: 'Preset B', sortOrder: 1001);
      await _createUserPreset(repo, name: 'Preset C', sortOrder: 1002);

      expect(await repo.nextSortOrder(), 1003);
    });

    test(
      'is not fooled by a live-preset count lower than the max sortOrder '
      'after a soft-delete (regression: preset_editor_screen.dart and '
      "log_drink_sheet.dart's create paths used to derive the next "
      'sortOrder from the live preset *count*, which collided with an '
      'existing preset once deletePreset — a soft delete — opened a gap)',
      () async {
        final db = _memDb();
        addTearDown(db.close);
        final repo = DrinksRepository(db);

        final idA =
            await _createUserPreset(repo, name: 'Preset A', sortOrder: 1000);
        final idB =
            await _createUserPreset(repo, name: 'Preset B', sortOrder: 1001);
        final idC =
            await _createUserPreset(repo, name: 'Preset C', sortOrder: 1002);

        await repo.deletePreset(idB);

        // A naive `liveCount + 1` would now return 1002 (only 2 of the 3
        // created presets are still live) — colliding with C.
        expect(await repo.nextSortOrder(), 1003);

        final idD = await _createUserPreset(
          repo,
          name: 'Preset D',
          sortOrder: await repo.nextSortOrder(),
        );

        final all = await repo.watchAllPresets().first;
        final sortOrderById = {for (final p in all) p.id: p.sortOrder};
        expect(sortOrderById[idA], 1000);
        expect(sortOrderById[idC], 1002);
        expect(sortOrderById[idD], 1003);
      },
    );
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

    test(
      'reordering a partial list does not collide with untouched presets',
      () async {
        // Regression test: reorderPresets must renumber the *entire*
        // non-deleted set (seeded defaults included), not just the ids
        // passed in — otherwise reassigning 1..N to a subset collides with
        // whichever seeded presets already occupy those sortOrder values.
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

        // Only reorder the 3 user-created presets — the 14 seeded defaults
        // are left out of orderedIds entirely.
        await repo.reorderPresets([id3, id2, id1]);

        final presets = await repo.watchAllPresets().first;
        final sortOrders = presets.map((p) => p.sortOrder).toList();

        expect(
          sortOrders.toSet().length,
          sortOrders.length,
          reason: 'Every non-deleted preset must have a unique sortOrder',
        );
        expect(sortOrders..sort(), List.generate(17, (i) => i + 1));

        final p1 = presets.firstWhere((p) => p.id == id1);
        final p2 = presets.firstWhere((p) => p.id == id2);
        final p3 = presets.firstWhere((p) => p.id == id3);
        expect(p3.sortOrder, 1);
        expect(p2.sortOrder, 2);
        expect(p1.sortOrder, 3);
      },
    );

    test('throws ArgumentError when orderedIds contains duplicates', () async {
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final id1 = await _createUserPreset(repo, name: 'Preset Alpha');

      await expectLater(
        () => repo.reorderPresets([id1, id1]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'throws StateError when orderedIds contains an unknown id',
      () async {
        final db = _memDb();
        addTearDown(db.close);
        final repo = DrinksRepository(db);

        await expectLater(
          () => repo.reorderPresets(['unknown-id-that-does-not-exist']),
          throwsA(isA<StateError>()),
        );
      },
    );
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
  // Group 9b: logDrink — name/priceMinor/currency entry-only overrides
  // -------------------------------------------------------------------------

  group('DrinksRepository — logDrink name/priceMinor/currency overrides', () {
    late AppDatabase db;
    late DrinksRepository repo;

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    Future<DrinkEntryRow> loggedRow() async {
      final rows = await db.select(db.drinkEntries).get();
      return rows.single;
    }

    test(
      'priceMinor/currency absent falls back to the preset\'s stored price',
      () async {
        final preset = await repo.createPreset(
          name: 'Priced Beer',
          beverageType: BeverageType.beer,
          volumeMl: 330,
          abvPercent: 5.0,
          regularPriceMinor: 450,
          regularCurrency: 'EUR',
          iconKey: 'beer_glass',
          iconColor: '#d97706',
          sortOrder: 99,
        );

        await repo.logDrink(preset: preset);

        final entry = await loggedRow();
        expect(entry.priceMinor, 450);
        expect(entry.currency, 'EUR');
      },
    );

    test(
      'Optional.value(null) priceMinor/currency logs this entry with no '
      'price, without touching the preset\'s stored price (S2 Advanced '
      '"Confirm" — entry-only, preset unchanged)',
      () async {
        final preset = await repo.createPreset(
          name: 'Priced Beer',
          beverageType: BeverageType.beer,
          volumeMl: 330,
          abvPercent: 5.0,
          regularPriceMinor: 450,
          regularCurrency: 'EUR',
          iconKey: 'beer_glass',
          iconColor: '#d97706',
          sortOrder: 99,
        );

        await repo.logDrink(
          preset: preset,
          priceMinor: const Optional.value(null),
          currency: const Optional.value(null),
        );

        final entry = await loggedRow();
        expect(entry.priceMinor, isNull);
        expect(entry.currency, isNull);

        // The preset's own stored price must be untouched.
        final row = await db.getPresetById(preset.id);
        expect(row!.regularPriceMinor, 450);
        expect(row.regularCurrency, 'EUR');
      },
    );

    test(
      'Optional.value with an explicit priceMinor/currency overrides the '
      "preset's stored price for this entry only",
      () async {
        final preset = await repo.createPreset(
          name: 'Priced Beer',
          beverageType: BeverageType.beer,
          volumeMl: 330,
          abvPercent: 5.0,
          regularPriceMinor: 450,
          regularCurrency: 'EUR',
          iconKey: 'beer_glass',
          iconColor: '#d97706',
          sortOrder: 99,
        );

        await repo.logDrink(
          preset: preset,
          priceMinor: const Optional.value(999),
          currency: const Optional.value('USD'),
        );

        final entry = await loggedRow();
        expect(entry.priceMinor, 999);
        expect(entry.currency, 'USD');
      },
    );

    test(
      'effective priceMinor non-null with effective currency null throws '
      'ArgumentError (data-model.md: currency required when priceMinor is '
      'set)',
      () async {
        final preset = await repo.createPreset(
          name: 'Free Water',
          beverageType: BeverageType.water,
          volumeMl: 300,
          iconKey: 'glass',
          iconColor: '#3b82f6',
          sortOrder: 99,
        );

        expect(
          () => repo.logDrink(
            preset: preset,
            priceMinor: const Optional.value(300),
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('name override is written to the logged entry', () async {
      final presetId = await _createUserPreset(repo, name: 'Original Name');
      final preset = (await repo.watchAllPresets().first)
          .firstWhere((p) => p.id == presetId);

      await repo.logDrink(preset: preset, name: 'Entry-only Name');

      final entry = await loggedRow();
      expect(entry.name, 'Entry-only Name');
    });

    test(
      'name override is NFC-normalized before persisting, matching '
      'createPreset/updatePreset (username.dart normalizeNfc doc: '
      '"visually identical inputs produce the same stored bytes")',
      () async {
        final presetId = await _createUserPreset(repo, name: 'Original Name');
        final preset = (await repo.watchAllPresets().first)
            .firstWhere((p) => p.id == presetId);

        // NFD form of 'café' — 'e' followed by a combining acute accent
        // (U+0301) instead of the precomposed 'é' (U+00E9).
        const nfdName = 'Café Latte';
        await repo.logDrink(preset: preset, name: nfdName);

        final entry = await loggedRow();
        expect(entry.name, normalizeNfc(nfdName));
        expect(entry.name, isNot(equals(nfdName)));
      },
    );

    test(
      'name override failing validatePresetName throws ArgumentError, same '
      'as createPreset/updatePreset',
      () async {
        final presetId = await _createUserPreset(repo, name: 'Original Name');
        final preset = (await repo.watchAllPresets().first)
            .firstWhere((p) => p.id == presetId);

        expect(
          () => repo.logDrink(preset: preset, name: 'ab'),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'logDrink sets presetId to the logged preset\'s id (issue #78 — feeds '
      'watchPresetUsageStats\' last-used/30-day-count aggregation behind '
      'the Recently-used/Most-used sort modes)',
      () async {
        final preset = await repo.createPreset(
          name: 'Sort Mode Preset',
          beverageType: BeverageType.water,
          volumeMl: 300,
          iconKey: 'glass',
          iconColor: '#3b82f6',
          sortOrder: 99,
        );

        await repo.logDrink(preset: preset);

        final entry = await loggedRow();
        expect(entry.presetId, preset.id);
      },
    );

    test(
      'logDrink returns a freshly generated id when none is supplied, and '
      'that id matches the written row (S2 quick-tap toast needs the id '
      'back to wire an Undo action)',
      () async {
        final preset = await repo.createPreset(
          name: 'Undo-able Drink',
          beverageType: BeverageType.water,
          volumeMl: 300,
          iconKey: 'glass',
          iconColor: '#3b82f6',
          sortOrder: 99,
        );

        final returnedId = await repo.logDrink(preset: preset);

        final entry = await loggedRow();
        expect(returnedId, entry.id);
      },
    );

    test(
      'logDrink writes under a caller-supplied id instead of generating one '
      '— S2\'s "pop before the write settles" flow needs the id known '
      'synchronously, before this future resolves',
      () async {
        final preset = await repo.createPreset(
          name: 'Caller-Id Drink',
          beverageType: BeverageType.water,
          volumeMl: 300,
          iconKey: 'glass',
          iconColor: '#3b82f6',
          sortOrder: 99,
        );

        final returnedId = await repo.logDrink(
          preset: preset,
          id: 'caller-supplied-id',
        );

        expect(returnedId, 'caller-supplied-id');
        final entry = await loggedRow();
        expect(entry.id, 'caller-supplied-id');
      },
    );
  });

  // -------------------------------------------------------------------------
  // Group 9c: watchPresetUsageStats — last-used / trailing-30-day aggregation
  // -------------------------------------------------------------------------

  group('DrinksRepository.watchPresetUsageStats', () {
    late AppDatabase db;
    late DrinksRepository repo;

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    test('empty database emits an empty map', () async {
      final stats = await repo.watchPresetUsageStats().first;
      expect(stats, isEmpty);
    });

    test(
      'lastUsedAt is the all-time max consumedAt per preset; count30d only '
      'counts entries within the trailing 30-day window ending "now" '
      '(inclusive of both ends) — Source: drinks_repository.dart '
      'watchPresetUsageStats doc comment',
      () async {
        final preset = await repo.createPreset(
          name: 'Usage Preset',
          beverageType: BeverageType.water,
          volumeMl: 300,
          iconKey: 'glass',
          iconColor: '#3b82f6',
          sortOrder: 99,
        );
        final now = DateTime.utc(2026, 7, 16, 12, 0);

        // Inside the 30-day window, and the most recent — must set both
        // lastUsedAt and count toward count30d.
        final recent = now.subtract(const Duration(days: 5));
        await repo.logDrink(preset: preset, consumedAt: recent);

        // Deliberately older than 30 days — must NOT count toward count30d,
        // and must NOT win lastUsedAt over the more recent entry above.
        final stale = now.subtract(const Duration(days: 45));
        await repo.logDrink(preset: preset, consumedAt: stale);

        final stats = await repo.watchPresetUsageStats(now: now).first;

        expect(stats.containsKey(preset.id), isTrue);
        expect(
          stats[preset.id]!.lastUsedAt!.isAtSameMomentAs(recent),
          isTrue,
          reason: 'lastUsedAt must be the all-time max consumedAt, not just '
              'the max within the 30-day count window',
        );
        expect(
          stats[preset.id]!.count30d,
          1,
          reason: 'the 45-day-old entry must not count toward count30d',
        );
      },
    );

    test(
      'a backdated entry that is still the most recent updates lastUsedAt '
      'even though it falls outside the count30d window',
      () async {
        final preset = await repo.createPreset(
          name: 'Backdated Preset',
          beverageType: BeverageType.water,
          volumeMl: 300,
          iconKey: 'glass',
          iconColor: '#3b82f6',
          sortOrder: 99,
        );
        final now = DateTime.utc(2026, 7, 16, 12, 0);
        // The ONLY entry for this preset — 40 days ago, outside the window.
        final backdated = now.subtract(const Duration(days: 40));
        await repo.logDrink(preset: preset, consumedAt: backdated);

        final stats = await repo.watchPresetUsageStats(now: now).first;

        expect(
          stats[preset.id]!.lastUsedAt!.isAtSameMomentAs(backdated),
          isTrue,
        );
        expect(stats[preset.id]!.count30d, 0);
      },
    );

    test(
      'count30d window is inclusive of both ends: consumedAt exactly at '
      'now-30d and exactly at now both count',
      () async {
        final preset = await repo.createPreset(
          name: 'Boundary Preset',
          beverageType: BeverageType.water,
          volumeMl: 300,
          iconKey: 'glass',
          iconColor: '#3b82f6',
          sortOrder: 99,
        );
        final now = DateTime.utc(2026, 7, 16, 12, 0);
        final windowStart = now.subtract(const Duration(days: 30));

        await repo.logDrink(preset: preset, consumedAt: windowStart);
        await repo.logDrink(preset: preset, consumedAt: now);

        final stats = await repo.watchPresetUsageStats(now: now).first;

        expect(stats[preset.id]!.count30d, 2);
      },
    );

    test(
      'a soft-deleted entry does not appear in usage stats at all',
      () async {
        final preset = await repo.createPreset(
          name: 'Deleted Preset',
          beverageType: BeverageType.water,
          volumeMl: 300,
          iconKey: 'glass',
          iconColor: '#3b82f6',
          sortOrder: 99,
        );
        final now = DateTime.utc(2026, 7, 16, 12, 0);
        await repo.logDrink(
          preset: preset,
          consumedAt: now.subtract(const Duration(days: 1)),
        );

        final entryId = (await db.select(db.drinkEntries).get()).single.id;
        await repo.deleteDrinkEntry(entryId);

        final stats = await repo.watchPresetUsageStats(now: now).first;

        expect(
          stats.containsKey(preset.id),
          isFalse,
          reason: 'F7 soft-delete: a deleted entry must not contribute to '
              'lastUsedAt or count30d',
        );
      },
    );

    test(
      'stats for two different presets are tracked independently — a heavy '
      'user of preset A does not pollute preset B\'s stats',
      () async {
        final presetA = await repo.createPreset(
          name: 'Preset A',
          beverageType: BeverageType.water,
          volumeMl: 300,
          iconKey: 'glass',
          iconColor: '#3b82f6',
          sortOrder: 1,
        );
        final presetB = await repo.createPreset(
          name: 'Preset B',
          beverageType: BeverageType.water,
          volumeMl: 300,
          iconKey: 'glass',
          iconColor: '#3b82f6',
          sortOrder: 2,
        );
        final now = DateTime.utc(2026, 7, 16, 12, 0);

        // Preset A: logged three times in the last week.
        for (var i = 1; i <= 3; i++) {
          await repo.logDrink(
            preset: presetA,
            consumedAt: now.subtract(Duration(days: i)),
          );
        }
        // Preset B: logged once, longer ago.
        await repo.logDrink(
          preset: presetB,
          consumedAt: now.subtract(const Duration(days: 10)),
        );

        final stats = await repo.watchPresetUsageStats(now: now).first;

        expect(stats[presetA.id]!.count30d, 3);
        expect(stats[presetB.id]!.count30d, 1);
        expect(
          stats[presetA.id]!.lastUsedAt!.isAtSameMomentAs(
                now.subtract(const Duration(days: 1)),
              ),
          isTrue,
        );
        expect(
          stats[presetB.id]!.lastUsedAt!.isAtSameMomentAs(
                now.subtract(const Duration(days: 10)),
              ),
          isTrue,
        );
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
    // Alcoholic entries must be included — every beverage type shows here.
    // Source: design/user-experience.md §S6: "A list of today's logged
    // drinks... of every beverage type — hydration and alcoholic entries
    // alike."; design/party-session.md §Logging alcohol when no session is
    // active (orphan alcoholic entries still surface in the Today log).
    // -----------------------------------------------------------------------
    test(
      'includes alcoholic entries (BeverageType.beer, isAlcoholic == true)',
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
          hasLength(1),
          reason: 'Alcoholic entries must appear in watchTodayEntries '
              'alongside hydration entries — every beverage type is shown '
              '(design/user-experience.md §S6)',
        );
        expect(entries.single.beverageType, equals(BeverageType.beer));
      },
    );

    // -----------------------------------------------------------------------
    // Session-attached alcoholic entries are still visible here — S6 only
    // gates *editability* on partySessionId (read-only rows), not list
    // membership. Source: design/user-experience.md §S6: "those rows are
    // read-only here" (i.e. they still appear, just without edit/delete).
    // -----------------------------------------------------------------------
    test(
      'includes alcoholic entries with a partySessionId set (session-attached)',
      () async {
        await db.insertDrinkEntry(
          DrinkEntriesCompanion.insert(
            id: 'session-attached-entry',
            beverageType: BeverageType.beer.stored,
            volumeMl: 250,
            partySessionId: const Value('test-session-1'),
            consumedAt: DateTime(2026, 6, 23, 9, 0).toUtc(),
            createdAt: DateTime(2026, 6, 23, 9, 0).toUtc(),
            updatedAt: DateTime(2026, 6, 23, 9, 0).toUtc(),
          ),
        );

        final entries =
            await repo.watchTodayEntries(now: now, boundaryHour: 5).first;
        expect(
          entries,
          hasLength(1),
          reason: 'watchTodayEntries visibility is not gated by '
              'partySessionId — only S6\'s read-only rendering is '
              '(design/user-experience.md §S6)',
        );
        expect(entries.single.partySessionId, equals('test-session-1'));
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
  // S6/S3 — updateDrinkEntry: name/ABV/price (issue #67 field-set alignment
  // with S9's PartySessionRepository.updateAlcoholicEntry)
  // ---------------------------------------------------------------------------

  group(
    'DrinksRepository.updateDrinkEntry — name/ABV/price (S3 exposes name; '
    'S6 does not, but the repository itself is field-agnostic — each '
    "screen's UI decides which fields it exposes)",
    () {
      late AppDatabase db;
      late DrinksRepository repo;
      late String entryId;

      const beerPreset = DrinkPreset(
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

      setUp(() async {
        db = _memDb();
        repo = DrinksRepository(db);
        entryId = await repo.logDrink(
          preset: beerPreset,
          consumedAt: DateTime.utc(2026, 7, 10, 20, 0),
        );
      });

      tearDown(() => db.close());

      Future<DrinkEntryRow> persisted() async =>
          (await db.select(db.drinkEntries).get())
              .singleWhere((e) => e.id == entryId);

      test(
        'updating abvPercent independently persists and leaves volume/name '
        'untouched',
        () async {
          await repo.updateDrinkEntry(id: entryId, abvPercent: 8.5);

          final row = await persisted();
          expect(row.abvPercent, 8.5);
          expect(row.volumeMl, beerPreset.volumeMl);
          expect(row.name, beerPreset.name);
        },
      );

      test(
        'updating name independently persists (NFC-normalized) and leaves '
        'volume/abv untouched',
        () async {
          // NFD form of 'café' — same convention as party_session_repository
          // _test.dart's equivalent NFC test.
          const nfdName = 'Cafe\u{0301} Latte';
          await repo.updateDrinkEntry(id: entryId, name: nfdName);

          final row = await persisted();
          expect(row.name, normalizeNfc(nfdName));
          expect(row.name, isNot(equals(nfdName)));
          expect(row.volumeMl, beerPreset.volumeMl);
          expect(row.abvPercent, beerPreset.abvPercent);
        },
      );

      test('rejects abvPercent <= 0', () async {
        expect(
          () => repo.updateDrinkEntry(id: entryId, abvPercent: 0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects an invalid name', () async {
        expect(
          () => repo.updateDrinkEntry(id: entryId, name: 'ab'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test(
        'setting priceMinor+currency sets a money price AND clears any '
        'pre-existing token price (data-model.md §DrinkEntry: money/tokens '
        'are mutually exclusive)',
        () async {
          // DrinksRepository.logDrink has no token-price param (tokens are
          // Party-Session-specific — PartySessionRepository.logAlcoholicDrink
          // only); write one directly via the DAO to simulate an entry that
          // was absorbed from a session and now has a lingering token price.
          final tokenEntryId = await repo.logDrink(
            preset: beerPreset,
            consumedAt: DateTime.utc(2026, 7, 10, 20, 0),
          );
          await db.updateDrinkEntryFields(
            tokenEntryId,
            const DrinkEntriesCompanion(
              priceTokens: Value(2),
              tokenValueMinor: Value(150),
              tokenValueCurrency: Value('EUR'),
            ),
          );

          await repo.updateDrinkEntry(
            id: tokenEntryId,
            priceMinor: const Optional.value(1234),
            currency: const Optional.value('EUR'),
          );

          final row = (await db.select(db.drinkEntries).get())
              .singleWhere((e) => e.id == tokenEntryId);
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
          await repo.updateDrinkEntry(
            id: entryId,
            priceMinor: const Optional.value(500),
            currency: const Optional.value('EUR'),
          );

          await repo.updateDrinkEntry(
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
        "leaves the entry's existing price completely untouched",
        () async {
          await repo.updateDrinkEntry(
            id: entryId,
            priceMinor: const Optional.value(777),
            currency: const Optional.value('USD'),
          );

          await repo.updateDrinkEntry(id: entryId, volumeMl: 350);

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
            () => repo.updateDrinkEntry(
              id: entryId,
              priceMinor: const Optional.value(500),
            ),
            throwsA(isA<ArgumentError>()),
          );
          expect(
            () => repo.updateDrinkEntry(
              id: entryId,
              currency: const Optional.value('EUR'),
            ),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      test(
        'setting priceMinor sets manualPriceOverride, matching '
        "PartySessionRepository.updateAlcoholicEntry's semantics",
        () async {
          await repo.updateDrinkEntry(
            id: entryId,
            priceMinor: const Optional.value(350),
            currency: const Optional.value('EUR'),
          );

          final row = await persisted();
          expect(row.manualPriceOverride, isTrue);
        },
      );
    },
  );

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

  // ---------------------------------------------------------------------------
  // F5 — getLatestDrinkConsumedAt (one-shot; feeds the reminder scheduler's
  // inactive-user silence check, notifications.md §Inactive-user silence)
  // ---------------------------------------------------------------------------

  group('DrinksRepository.getLatestDrinkConsumedAt', () {
    late AppDatabase db;
    late DrinksRepository repo;

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    test('returns null when no entries exist', () async {
      expect(await repo.getLatestDrinkConsumedAt(), isNull);
    });

    test(
      'returns the max consumedAt across mixed alcoholic/non-alcoholic '
      'entries — unlike the hydration-total queries, any type counts here '
      '(notifications.md §Inactive-user silence: "most recent DrinkEntry", '
      'not "most recent non-alcoholic DrinkEntry")',
      () async {
        const beerPreset = DrinkPreset(
          id: 'test-beer-preset-latest',
          name: 'Test Beer',
          beverageType: BeverageType.beer,
          volumeMl: 250,
          iconKey: 'beer_glass',
          iconColor: '#d97706',
          isUserCreated: false,
          isHidden: false,
          sortOrder: 99,
        );

        final earlier = DateTime(2026, 6, 20, 9, 0);
        final latest = DateTime(2026, 6, 23, 18, 0); // the alcoholic one

        await repo.logDrink(preset: _waterPreset, consumedAt: earlier);
        await repo.logDrink(preset: beerPreset, consumedAt: latest);

        final result = await repo.getLatestDrinkConsumedAt();
        expect(result, isNotNull);
        expect(result!.isAtSameMomentAs(latest.toUtc()), isTrue);
      },
    );

    test('ignores soft-deleted entries', () async {
      final earlier = DateTime(2026, 6, 20, 9, 0);
      final latest = DateTime(2026, 6, 23, 18, 0);

      await repo.logDrink(preset: _waterPreset, consumedAt: earlier);
      await repo.logDrink(preset: _waterPreset, consumedAt: latest);

      // Find and soft-delete the most recent entry.
      final entries = await db.select(db.drinkEntries).get();
      final latestRow = entries.firstWhere((e) => e.consumedAt.isAtSameMomentAs(
            latest.toUtc(),
          ));
      await repo.deleteDrinkEntry(latestRow.id);

      final result = await repo.getLatestDrinkConsumedAt();
      expect(
        result!.isAtSameMomentAs(earlier.toUtc()),
        isTrue,
        reason: 'The soft-deleted (later) entry must be excluded, so the '
            'earlier surviving entry is the max.',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // F5 — getTodayTotalMl (one-shot equivalent of watchTodayTotalMl)
  // ---------------------------------------------------------------------------

  group('DrinksRepository.getTodayTotalMl', () {
    late AppDatabase db;
    late DrinksRepository repo;

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    test('returns 0 for an empty database', () async {
      final now = DateTime(2026, 6, 23, 12, 0);
      expect(await repo.getTodayTotalMl(now: now, boundaryHour: 5), equals(0));
    });

    test(
      'sums non-alcoholic intake within the day window, excludes alcoholic '
      '(same filter as watchTodayTotalMl)',
      () async {
        const beerPreset = DrinkPreset(
          id: 'test-beer-preset-total',
          name: 'Test Beer',
          beverageType: BeverageType.beer,
          volumeMl: 250,
          iconKey: 'beer_glass',
          iconColor: '#d97706',
          isUserCreated: false,
          isHidden: false,
          sortOrder: 99,
        );
        final now = DateTime(2026, 6, 23, 12, 0);

        await repo.logDrink(
          preset: _waterPreset, // 300 ml, inside window
          consumedAt: DateTime(2026, 6, 23, 8, 0),
        );
        await repo.logDrink(
          preset: beerPreset, // excluded regardless of window
          consumedAt: DateTime(2026, 6, 23, 9, 0),
        );

        final total = await repo.getTodayTotalMl(now: now, boundaryHour: 5);
        expect(total, equals(300));
      },
    );

    test(
      'respects boundaryHour — same day-window semantics as watchTodayTotalMl',
      () async {
        // Same fixture as the watchTodayTotalMl boundaryHour regression test
        // above: drink at 22:00 prev-evening, now=05:30.
        final now = DateTime(2026, 6, 23, 5, 30);
        final consumedAt = DateTime(2026, 6, 22, 22, 0);

        await repo.logDrink(preset: _waterPreset, consumedAt: consumedAt);

        expect(
          await repo.getTodayTotalMl(now: now, boundaryHour: 6),
          equals(_waterPreset.volumeMl),
        );
        expect(
          await repo.getTodayTotalMl(now: now, boundaryHour: 5),
          equals(0),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // F5 — isoWeekDaysOnGoal (feeds the weekly-summary notification body)
  // ---------------------------------------------------------------------------

  group('DrinksRepository.isoWeekDaysOnGoal', () {
    late AppDatabase db;
    late DrinksRepository repo;

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    test('returns 0 for an empty database', () async {
      final now = DateTime(2026, 1, 14, 14, 0); // Wed, within Jan 12–18 week
      expect(
        await repo.isoWeekDaysOnGoal(dailyGoalMl: 2000, now: now),
        equals(0),
      );
    });

    test(
      'counts today (partial data) as part of the ISO week — unlike '
      'watch7DayDaysOnGoal, which excludes today',
      () async {
        // ISO week containing `now` (Wed 2026-01-14) is Mon 2026-01-12 –
        // Sun 2026-01-18 (isoWeekWindow). Source: DrinksRepository
        // .isoWeekDaysOnGoal docstring — "includes today".
        final now = DateTime(2026, 1, 14, 14, 0);

        // Monday: meets goal.
        await repo.logDrink(
          preset: _waterPreset, // 300 ml
          volumeMl: 2000,
          consumedAt: DateTime(2026, 1, 12, 10, 0),
        );
        // Today (Wednesday, partial data so far): also meets goal.
        await repo.logDrink(
          preset: _waterPreset,
          volumeMl: 2000,
          consumedAt: DateTime(2026, 1, 14, 9, 0),
        );
        // Tuesday: below goal.
        await repo.logDrink(
          preset: _waterPreset,
          volumeMl: 500,
          consumedAt: DateTime(2026, 1, 13, 10, 0),
        );

        final daysOnGoal = await repo.isoWeekDaysOnGoal(
          dailyGoalMl: 2000,
          now: now,
        );
        expect(
          daysOnGoal,
          equals(2),
          reason: 'Monday and today (Wednesday) meet the 2000 ml goal; '
              "Tuesday's 500 ml does not.",
        );
      },
    );

    test('excludes alcoholic intake from the daily totals', () async {
      const beerPreset = DrinkPreset(
        id: 'test-beer-preset-isoweek',
        name: 'Test Beer',
        beverageType: BeverageType.beer,
        volumeMl: 2000,
        iconKey: 'beer_glass',
        iconColor: '#d97706',
        isUserCreated: false,
        isHidden: false,
        sortOrder: 99,
      );
      final now = DateTime(2026, 1, 14, 14, 0);

      await repo.logDrink(
        preset: beerPreset,
        consumedAt: DateTime(2026, 1, 12, 10, 0),
      );

      final daysOnGoal = await repo.isoWeekDaysOnGoal(
        dailyGoalMl: 2000,
        now: now,
      );
      expect(daysOnGoal, equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // History (issue #25) — watchDailyTotalsMl / watchDrinksPerDay
  // ---------------------------------------------------------------------------
  //
  // Range fixture shared by most tests below (boundary hour 5, the Rulebook
  // default): rangeStart = Mon 2026-06-22 05:00, rangeEnd = Fri 2026-06-26
  // 05:00 — a 4 day-window range: Mon, Tue, Wed, Thu (day-window starts at
  // each day's 05:00). rangeStart is itself a day-window boundary instant,
  // as required by the [DrinksRepository.watchDailyTotalsMl] docstring.
  // Source: Parity Rulebook → "Day boundary"; design/features.md F4.

  group('DrinksRepository.watchDailyTotalsMl', () {
    late AppDatabase db;
    late DrinksRepository repo;

    final rangeStart = DateTime(2026, 6, 22, 5, 0); // Mon 05:00
    final rangeEnd = DateTime(2026, 6, 26, 5, 0); // Fri 05:00

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    test(
      'sums non-alcoholic ml per day-window across the range, zero-filling '
      'days with no entries, ordered oldest-first',
      () async {
        // Monday: two entries, 300 + 500 = 800 ml.
        await repo.logDrink(
          preset: _waterPreset,
          volumeMl: 300,
          consumedAt: DateTime(2026, 6, 22, 8, 0),
        );
        await repo.logDrink(
          preset: _waterPreset,
          volumeMl: 500,
          consumedAt: DateTime(2026, 6, 22, 20, 0),
        );
        // Wednesday: one entry, 200 ml. Tuesday and Thursday: nothing.
        await repo.logDrink(
          preset: _waterPreset,
          volumeMl: 200,
          consumedAt: DateTime(2026, 6, 24, 10, 0),
        );

        final buckets = await repo
            .watchDailyTotalsMl(rangeStart: rangeStart, rangeEnd: rangeEnd)
            .first;

        expect(buckets.length, equals(4));
        expect(
          buckets.map((b) => b.dayStart).toList(),
          equals([
            DateTime(2026, 6, 22, 5, 0), // Mon
            DateTime(2026, 6, 23, 5, 0), // Tue
            DateTime(2026, 6, 24, 5, 0), // Wed
            DateTime(2026, 6, 25, 5, 0), // Thu
          ]),
          reason: 'buckets must be ordered oldest-first, one per day-window',
        );
        expect(
          buckets.map((b) => b.value).toList(),
          equals([800, 0, 200, 0]),
          reason: 'Tue and Thu have no entries → zero-filled, not omitted',
        );
      },
    );

    test('excludes alcoholic entries from the daily totals', () async {
      const beerPreset = DrinkPreset(
        id: 'test-beer-preset-history-totals',
        name: 'Test Beer',
        beverageType: BeverageType.beer,
        volumeMl: 330,
        iconKey: 'beer_glass',
        iconColor: '#d97706',
        isUserCreated: false,
        isHidden: false,
        sortOrder: 99,
      );

      await repo.logDrink(
        preset: beerPreset,
        consumedAt: DateTime(2026, 6, 22, 20, 0),
      );

      final buckets = await repo
          .watchDailyTotalsMl(rangeStart: rangeStart, rangeEnd: rangeEnd)
          .first;

      expect(
        buckets.every((b) => b.value == 0),
        isTrue,
        reason:
            'Alcoholic entries must not contribute to hydration bucket totals '
            '(data-model.md §BeverageType: strictly disjoint flows)',
      );
    });

    test('excludes soft-deleted entries from the daily totals', () async {
      await repo.logDrink(
        preset: _waterPreset,
        volumeMl: 300,
        consumedAt: DateTime(2026, 6, 22, 8, 0),
      );

      final before = await repo
          .watchDailyTotalsMl(rangeStart: rangeStart, rangeEnd: rangeEnd)
          .first;
      expect(before.first.value, equals(300));

      final rows = await db.select(db.drinkEntries).get();
      await repo.deleteDrinkEntry(rows.single.id);

      final after = await repo
          .watchDailyTotalsMl(rangeStart: rangeStart, rangeEnd: rangeEnd)
          .first;
      expect(
        after.first.value,
        equals(0),
        reason: 'Soft-deleted entries must not appear in daily totals '
            '(F7 soft-delete)',
      );
    });

    test(
      'entry exactly at rangeStart is included; entry exactly at rangeEnd '
      'is excluded (half-open [rangeStart, rangeEnd))',
      () async {
        await repo.logDrink(
          preset: _waterPreset,
          volumeMl: 111,
          consumedAt: rangeStart,
        );
        await repo.logDrink(
          preset: _waterPreset,
          volumeMl: 222,
          consumedAt: rangeEnd,
        );

        final buckets = await repo
            .watchDailyTotalsMl(rangeStart: rangeStart, rangeEnd: rangeEnd)
            .first;

        expect(
          buckets.first.value,
          equals(111),
          reason: 'consumedAt == rangeStart must be included in the first '
              'bucket',
        );
        expect(
          buckets.fold<int>(0, (s, b) => s + b.value),
          equals(111),
          reason: 'consumedAt == rangeEnd must be excluded entirely — it '
              'falls outside every day-window in [rangeStart, rangeEnd)',
        );
      },
    );

    test(
      'boundaryHour ≠ midnight: entry logged at 02:00 local falls into the '
      'PREVIOUS day\'s bucket, not the calendar day it was logged on',
      () async {
        // dayWindow(Tue 06-23 02:00, boundary 5) shifts back to Monday's
        // day-window (02:00 < 05:00 boundary) — same rule as day_boundary.dart.
        await repo.logDrink(
          preset: _waterPreset,
          volumeMl: 400,
          consumedAt: DateTime(2026, 6, 23, 2, 0), // Tue 02:00 local
        );

        final buckets = await repo
            .watchDailyTotalsMl(
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              boundaryHour: 5,
            )
            .first;

        expect(
          buckets[0].value, // Monday's bucket
          equals(400),
          reason: 'Tue 02:00 is before the 05:00 boundary, so it belongs to '
              "Monday's day-window",
        );
        expect(
          buckets[1].value, // Tuesday's bucket
          equals(0),
          reason: 'The entry must NOT be counted under the calendar day it '
              'was logged on when boundaryHour ≠ midnight',
        );
      },
    );
  });

  group('DrinksRepository.watchDrinksPerDay', () {
    late AppDatabase db;
    late DrinksRepository repo;

    final rangeStart = DateTime(2026, 6, 22, 5, 0); // Mon 05:00
    final rangeEnd = DateTime(2026, 6, 26, 5, 0); // Fri 05:00

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    test(
      'counts non-alcoholic entries per day-window across the range, '
      'zero-filling days with no entries, ordered oldest-first',
      () async {
        // Monday: two entries. Wednesday: one entry. Tue/Thu: none.
        await repo.logDrink(
          preset: _waterPreset,
          consumedAt: DateTime(2026, 6, 22, 8, 0),
        );
        await repo.logDrink(
          preset: _waterPreset,
          consumedAt: DateTime(2026, 6, 22, 20, 0),
        );
        await repo.logDrink(
          preset: _waterPreset,
          consumedAt: DateTime(2026, 6, 24, 10, 0),
        );

        final buckets = await repo
            .watchDrinksPerDay(rangeStart: rangeStart, rangeEnd: rangeEnd)
            .first;

        expect(buckets.length, equals(4));
        expect(
          buckets.map((b) => b.value).toList(),
          equals([2, 0, 1, 0]),
          reason: 'Tue and Thu have no entries → zero-filled counts, not '
              'omitted buckets',
        );
      },
    );

    test('excludes alcoholic entries from the drink counts', () async {
      const beerPreset = DrinkPreset(
        id: 'test-beer-preset-history-counts',
        name: 'Test Beer',
        beverageType: BeverageType.beer,
        volumeMl: 330,
        iconKey: 'beer_glass',
        iconColor: '#d97706',
        isUserCreated: false,
        isHidden: false,
        sortOrder: 99,
      );

      await repo.logDrink(
        preset: beerPreset,
        consumedAt: DateTime(2026, 6, 22, 20, 0),
      );

      final buckets = await repo
          .watchDrinksPerDay(rangeStart: rangeStart, rangeEnd: rangeEnd)
          .first;

      expect(
        buckets.every((b) => b.value == 0),
        isTrue,
        reason: 'Alcoholic entries must not contribute to drink counts '
            '(issue #25 scopes History charts to hydration only)',
      );
    });

    test('excludes soft-deleted entries from the drink counts', () async {
      await repo.logDrink(
        preset: _waterPreset,
        consumedAt: DateTime(2026, 6, 22, 8, 0),
      );

      final before = await repo
          .watchDrinksPerDay(rangeStart: rangeStart, rangeEnd: rangeEnd)
          .first;
      expect(before.first.value, equals(1));

      final rows = await db.select(db.drinkEntries).get();
      await repo.deleteDrinkEntry(rows.single.id);

      final after = await repo
          .watchDrinksPerDay(rangeStart: rangeStart, rangeEnd: rangeEnd)
          .first;
      expect(
        after.first.value,
        equals(0),
        reason: 'Soft-deleted entries must not appear in drink counts '
            '(F7 soft-delete)',
      );
    });

    test(
      'entry exactly at rangeStart is included; entry exactly at rangeEnd '
      'is excluded (half-open [rangeStart, rangeEnd))',
      () async {
        await repo.logDrink(preset: _waterPreset, consumedAt: rangeStart);
        await repo.logDrink(preset: _waterPreset, consumedAt: rangeEnd);

        final buckets = await repo
            .watchDrinksPerDay(rangeStart: rangeStart, rangeEnd: rangeEnd)
            .first;

        expect(buckets.first.value, equals(1));
        expect(buckets.fold<int>(0, (s, b) => s + b.value), equals(1));
      },
    );

    test(
      'boundaryHour ≠ midnight: an entry logged at 02:00 local is counted in '
      "the PREVIOUS day's bucket",
      () async {
        await repo.logDrink(
          preset: _waterPreset,
          consumedAt: DateTime(2026, 6, 23, 2, 0), // Tue 02:00 local
        );

        final buckets = await repo
            .watchDrinksPerDay(
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              boundaryHour: 5,
            )
            .first;

        expect(buckets[0].value, equals(1)); // Monday's bucket
        expect(buckets[1].value, equals(0)); // Tuesday's bucket
      },
    );
  });

  // ---------------------------------------------------------------------------
  // History — alcohol charts + day drill-down (issue #26)
  // ---------------------------------------------------------------------------

  group('DrinksRepository.watchAlcoholicDrinksPerDay', () {
    late AppDatabase db;
    late DrinksRepository repo;

    final rangeStart = DateTime(2026, 6, 22, 5, 0); // Mon 05:00
    final rangeEnd = DateTime(2026, 6, 26, 5, 0); // Fri 05:00

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    /// Inserts a live alcoholic [DrinkEntry] directly at the DB layer with
    /// [partySessionId] set — `DrinksRepository.logDrink()` never sets this
    /// column (only `PartySessionRepository.logAlcoholicDrink()` does), so
    /// this mirrors `party_session_repository_test.dart`'s `_insertOrphanDrink`
    /// helper but with a session attached. No `PartySession` row needs to
    /// actually exist — the column has no FK constraint at the DB layer.
    Future<void> insertSessionDrink({
      required DateTime consumedAt,
      String sessionId = 'session-1',
      int volumeMl = 330,
      String id = 'session-drink-1',
    }) async {
      final now = DateTime.now().toUtc();
      await db.insertDrinkEntry(
        DrinkEntriesCompanion.insert(
          id: id,
          beverageType: BeverageType.beer.stored,
          volumeMl: volumeMl,
          abvPercent: const Value(5.0),
          partySessionId: Value(sessionId),
          consumedAt: consumedAt,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    test(
      'counts session-attached alcoholic entries, zero-filling days with '
      'none, ordered oldest-first',
      () async {
        await insertSessionDrink(
          id: 'e1',
          consumedAt: DateTime(2026, 6, 22, 20, 0),
        );
        await insertSessionDrink(
          id: 'e2',
          consumedAt: DateTime(2026, 6, 22, 21, 0),
        );
        await insertSessionDrink(
          id: 'e3',
          consumedAt: DateTime(2026, 6, 24, 20, 0),
        );

        final buckets = await repo
            .watchAlcoholicDrinksPerDay(
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            )
            .first;

        expect(buckets.length, equals(4));
        expect(
          buckets.map((b) => b.value).toList(),
          equals([2, 0, 1, 0]),
        );
      },
    );

    test(
      'excludes non-alcoholic entries but includes orphaned alcoholic '
      'entries (partySessionId == null)',
      () async {
        // Non-alcoholic, via the normal logDrink path.
        await repo.logDrink(
          preset: _waterPreset,
          consumedAt: DateTime(2026, 6, 22, 8, 0),
        );
        // Orphaned alcoholic drink — logDrink() never sets partySessionId,
        // e.g. logged from the Today tab's LogDrinkSheet outside Party Mode.
        const beerPreset = DrinkPreset(
          id: 'test-beer-preset-alcoholic-counts',
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
        await repo.logDrink(
          preset: beerPreset,
          consumedAt: DateTime(2026, 6, 22, 20, 0),
        );

        final buckets = await repo
            .watchAlcoholicDrinksPerDay(
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            )
            .first;

        expect(
          buckets.fold<int>(0, (s, b) => s + b.value),
          equals(1),
          reason: 'Orphan alcoholic entries count toward the '
              'alcoholic-drinks-per-day chart same as session-attached ones '
              '(issue #66) — only the non-alcoholic water entry is excluded',
        );
      },
    );

    test('excludes soft-deleted entries', () async {
      await insertSessionDrink(consumedAt: DateTime(2026, 6, 22, 8, 0));

      final before = await repo
          .watchAlcoholicDrinksPerDay(
              rangeStart: rangeStart, rangeEnd: rangeEnd)
          .first;
      expect(before.first.value, equals(1));

      await repo.deleteDrinkEntry('session-drink-1');

      final after = await repo
          .watchAlcoholicDrinksPerDay(
              rangeStart: rangeStart, rangeEnd: rangeEnd)
          .first;
      expect(after.first.value, equals(0));
    });

    test(
      'entry exactly at rangeStart is included; entry exactly at rangeEnd '
      'is excluded (half-open [rangeStart, rangeEnd))',
      () async {
        await insertSessionDrink(id: 'e1', consumedAt: rangeStart);
        await insertSessionDrink(id: 'e2', consumedAt: rangeEnd);

        final buckets = await repo
            .watchAlcoholicDrinksPerDay(
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            )
            .first;

        expect(buckets.fold<int>(0, (s, b) => s + b.value), equals(1));
        expect(buckets.first.value, equals(1));
      },
    );
  });

  group('DrinksRepository.watchDayEntries', () {
    late AppDatabase db;
    late DrinksRepository repo;

    final dayStart = DateTime(2026, 6, 22, 5, 0);
    final dayEnd = DateTime(2026, 6, 23, 5, 0);

    setUp(() {
      db = _memDb();
      repo = DrinksRepository(db);
    });

    tearDown(() => db.close());

    test(
      'returns both hydration and alcoholic entries within the day window, '
      'newest-first',
      () async {
        await repo.logDrink(
          preset: _waterPreset,
          consumedAt: DateTime(2026, 6, 22, 8, 0),
        );
        const beerPreset = DrinkPreset(
          id: 'test-beer-preset-day-entries',
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
        await repo.logDrink(
          preset: beerPreset,
          consumedAt: DateTime(2026, 6, 22, 20, 0),
        );

        final entries = await repo.watchDayEntries(dayStart, dayEnd).first;

        expect(entries, hasLength(2));
        // Newest-first: the 20:00 beer before the 08:00 water.
        expect(entries[0].beverageType, BeverageType.beer);
        expect(entries[1].beverageType, BeverageType.water);
      },
    );

    test('excludes entries outside the day window', () async {
      await repo.logDrink(
        preset: _waterPreset,
        consumedAt: DateTime(2026, 6, 21, 20, 0), // previous day
      );
      await repo.logDrink(
        preset: _waterPreset,
        consumedAt: DateTime(2026, 6, 23, 6, 0), // next day
      );

      final entries = await repo.watchDayEntries(dayStart, dayEnd).first;

      expect(entries, isEmpty);
    });

    test('excludes soft-deleted entries', () async {
      await repo.logDrink(
        preset: _waterPreset,
        consumedAt: DateTime(2026, 6, 22, 8, 0),
      );
      final rows = await db.select(db.drinkEntries).get();
      await repo.deleteDrinkEntry(rows.single.id);

      final entries = await repo.watchDayEntries(dayStart, dayEnd).first;

      expect(entries, isEmpty);
    });
  });
}
