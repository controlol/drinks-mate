import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
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

    test('still includes a hidden alcoholic preset', () async {
      // watchAlcoholicPresets() includes hidden — source: repo docstring.
      final db = _memDb();
      addTearDown(db.close);
      final repo = DrinksRepository(db);

      final alcoholic = await repo.watchAlcoholicPresets().first;
      final targetId = alcoholic.first.id;

      await repo.hidePreset(targetId);
      final afterHide = await repo.watchAlcoholicPresets().first;

      expect(afterHide.length, 4);
      expect(afterHide.any((p) => p.id == targetId), isTrue);
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
        iconKey: 'glass',
        iconColor: '#d97706',
        sortOrder: 99,
      );

      expect(preset.isUserCreated, isTrue);
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
      'seeded default (isUserCreated == false) can be soft-deleted',
      () async {
        // Source: data-model.md §DrinkPreset line 58: "The user can edit, hide,
        // or delete them — there is no special protection." Seeded defaults
        // re-seed via INSERT OR IGNORE on next open (reset-to-defaults mechanic).
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
      },
    );

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
}
