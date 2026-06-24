// Regression test: DrinksRepository.watchTodayTotalMl respects boundaryHour.
//
// Bug that was fixed: todayTotalMlProvider called dayWindow() without a
// boundaryHour, always defaulting to 05:00. The _ProgressCard widget computed
// expectedMl using prefs.dayBoundaryHour. When dayBoundaryHour != 5 the two
// computations covered *different* time windows.
//
// This test proves the fix by inserting a drink that falls:
//   - INSIDE  the [06-22 06:00, 06-23 06:00) window (boundaryHour = 6)
//   - OUTSIDE the [06-23 05:00, 06-24 05:00) window (boundaryHour = 5)
// and asserting that watchTodayTotalMl counts / ignores it accordingly.
//
// Window arithmetic (verified against dayWindow() in core/lib/src/day_boundary.dart):
//   now = 2026-06-23 05:30 local
//   dayWindow(now, boundaryHour: 6): now < 06:00 boundary →
//       window = [2026-06-22 06:00, 2026-06-23 06:00)
//   dayWindow(now, boundaryHour: 5): now >= 05:00 boundary →
//       window = [2026-06-23 05:00, 2026-06-24 05:00)
//
//   consumedAt = 2026-06-22 22:00 local
//     → inside  [06-22 06:00, 06-23 06:00) ✓
//     → outside [06-23 05:00, 06-24 05:00) ✓ (before window start)

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
// flutter_test re-exports package:test in full; it is the only test
// dev_dependency available in this Flutter package (no standalone test dep).
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';

// ---------------------------------------------------------------------------
// Helper: open an in-memory database (no file I/O, safe in tests).
// ---------------------------------------------------------------------------
AppDatabase _memDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
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
      'boundary=5 when now=05:30 next morning',
      () async {
        // Observation point (local time): 2026-06-23 05:30
        // dayWindow(boundary=6): now < 06:00 → [06-22 06:00, 06-23 06:00)
        // dayWindow(boundary=5): now >= 05:00 → [06-23 05:00, 06-24 05:00)
        // Source: core/lib/src/day_boundary.dart
        final now = DateTime(2026, 6, 23, 5, 30); // local, 05:30

        // Drink at 22:00 the previous evening (local time).
        // Inside  [06-22 06:00, 06-23 06:00) → counted when boundary=6.
        // Outside [06-23 05:00, 06-24 05:00) → NOT counted when boundary=5.
        final consumedAt = DateTime(2026, 6, 22, 22, 0); // local, 22:00

        await repo.logDrink(
          preset: _waterPreset,
          consumedAt: consumedAt,
        );

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
      },
    );

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
      'consumed inside the time window',
      () async {
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
      },
    );

    // -----------------------------------------------------------------------
    // Empty database emits 0 immediately (stream contract).
    // -----------------------------------------------------------------------
    test(
      'empty database emits 0 for watchTodayTotalMl',
      () async {
        final now = DateTime(2026, 6, 23, 12, 0);
        final total =
            await repo.watchTodayTotalMl(now: now, boundaryHour: 5).first;
        expect(total, equals(0));
      },
    );

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
}
