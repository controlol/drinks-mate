import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('rankPresetIds — manual (Parity Rulebook §Preset sort mode)', () {
    // Source: preset_ranking.dart doc comment — "manual: the user's own
    // drag-reorder order (DrinkPreset.sortOrder)".
    test('orders strictly by ascending sortOrder, ignoring input order', () {
      final ranked = rankPresetIds(
        presetIds: const ['b', 'a', 'c'],
        sortOrders: const {'a': 1, 'b': 2, 'c': 3},
        usage: const {},
        mode: PresetSortMode.manual,
      );
      expect(ranked, ['a', 'b', 'c']);
    });

    test(
        'a preset missing from sortOrders is treated as sortOrder 0 '
        '(sinks to the front)', () {
      final ranked = rankPresetIds(
        presetIds: const ['known', 'unknown'],
        sortOrders: const {'known': 1},
        usage: const {},
        mode: PresetSortMode.manual,
      );
      expect(ranked, ['unknown', 'known']);
    });
  });

  group('rankPresetIds — recentlyUsed (Parity Rulebook §Preset sort mode)', () {
    final earlier = DateTime.utc(2026, 7, 1, 8, 0);
    final later = DateTime.utc(2026, 7, 10, 8, 0);

    // Source: preset_ranking.dart doc — "recentlyUsed: most-recently-logged
    // preset first ... consumedAt basis."
    test('orders by lastUsedAt descending (most recent first)', () {
      final ranked = rankPresetIds(
        presetIds: const ['p1', 'p2', 'p3'],
        sortOrders: const {'p1': 1, 'p2': 2, 'p3': 3},
        usage: {
          'p1': PresetUsageStats(lastUsedAt: earlier),
          'p2': PresetUsageStats(lastUsedAt: later),
          'p3': const PresetUsageStats(),
        },
        mode: PresetSortMode.recentlyUsed,
      );
      // p2 (later) before p1 (earlier); p3 (never used) sinks to the bottom.
      expect(ranked, ['p2', 'p1', 'p3']);
    });

    // Source: preset_ranking.dart doc — "All three tie-break on sortOrder
    // ascending."
    test(
        'two presets with the same lastUsedAt tie-break on sortOrder '
        'ascending', () {
      final ranked = rankPresetIds(
        presetIds: const ['p1', 'p2', 'p3'],
        sortOrders: const {'p1': 5, 'p2': 1, 'p3': 99},
        usage: {
          'p1': PresetUsageStats(lastUsedAt: later),
          'p2': PresetUsageStats(lastUsedAt: later), // same instant as p1
          'p3': PresetUsageStats(lastUsedAt: earlier),
        },
        mode: PresetSortMode.recentlyUsed,
      );
      // p1/p2 tie on lastUsedAt -> lower sortOrder (p2=1) wins the tie-break.
      expect(ranked, ['p2', 'p1', 'p3']);
    });

    // Source: preset_ranking.dart doc — "Never-used presets sink to the
    // bottom of this mode ... but keep their relative sortOrder there."
    test(
        'never-used presets (null lastUsedAt) sink below used presets, '
        'ordered by sortOrder among themselves', () {
      final ranked = rankPresetIds(
        presetIds: const ['used', 'never2', 'never1'],
        sortOrders: const {'used': 99, 'never1': 1, 'never2': 2},
        usage: {
          'used': PresetUsageStats(lastUsedAt: earlier),
          'never1': const PresetUsageStats(),
          'never2': const PresetUsageStats(),
        },
        mode: PresetSortMode.recentlyUsed,
      );
      expect(ranked, ['used', 'never1', 'never2']);
    });

    // Source: preset_ranking.dart doc — a fresh install (cold start) has no
    // qualifying usage for any preset yet, so this mode must still produce a
    // stable, deterministic order (not map/iteration order).
    test(
        'cold start (all presets never used) degrades to sortOrder '
        'ascending — same order as manual mode', () {
      final presetIds = ['c', 'a', 'b'];
      final sortOrders = {'a': 1, 'b': 2, 'c': 3};
      final ranked = rankPresetIds(
        presetIds: presetIds,
        sortOrders: sortOrders,
        usage: const {}, // no usage recorded for anyone
        mode: PresetSortMode.recentlyUsed,
      );
      final manualRanked = rankPresetIds(
        presetIds: presetIds,
        sortOrders: sortOrders,
        usage: const {},
        mode: PresetSortMode.manual,
      );
      expect(ranked, ['a', 'b', 'c']);
      expect(ranked, manualRanked);
    });
  });

  group('rankPresetIds — mostUsed (Parity Rulebook §Preset sort mode)', () {
    // Source: preset_ranking.dart doc — "mostUsed: highest trailing-30-day
    // log count first ... consumedAt basis and window."
    test('orders by count30d descending', () {
      final ranked = rankPresetIds(
        presetIds: const ['p1', 'p2', 'p3'],
        sortOrders: const {'p1': 1, 'p2': 2, 'p3': 3},
        usage: const {
          'p1': PresetUsageStats(count30d: 2),
          'p2': PresetUsageStats(count30d: 10),
          'p3': PresetUsageStats(count30d: 5),
        },
        mode: PresetSortMode.mostUsed,
      );
      expect(ranked, ['p2', 'p3', 'p1']);
    });

    // Source: preset_ranking.dart doc — "All three tie-break on sortOrder
    // ascending."
    test('presets with equal count30d tie-break on sortOrder ascending', () {
      final ranked = rankPresetIds(
        presetIds: const ['p1', 'p2', 'p3'],
        sortOrders: const {'p1': 9, 'p2': 2, 'p3': 1},
        usage: const {
          'p1': PresetUsageStats(count30d: 5),
          'p2': PresetUsageStats(count30d: 5),
          'p3': PresetUsageStats(count30d: 10),
        },
        mode: PresetSortMode.mostUsed,
      );
      // p3 has the highest count -> first. p1/p2 tie at count30d=5 -> lower
      // sortOrder (p2=2) wins the tie-break over p1=9.
      expect(ranked, ['p3', 'p2', 'p1']);
    });
  });

  group(
      'rankPresetIds — a preset missing from usage behaves identically to '
      'PresetUsageStats.zero (preset_ranking.dart doc: "the correct '
      'behaviour for a preset with no rows yet, not a caller bug")', () {
    test('mostUsed mode: omitted id ranks the same as an explicit zero', () {
      final presetIds = ['known', 'omitted', 'explicit-zero'];
      final sortOrders = {'known': 1, 'omitted': 2, 'explicit-zero': 3};

      final withOmission = rankPresetIds(
        presetIds: presetIds,
        sortOrders: sortOrders,
        usage: const {'known': PresetUsageStats(count30d: 4)},
        mode: PresetSortMode.mostUsed,
      );
      final withExplicitZero = rankPresetIds(
        presetIds: presetIds,
        sortOrders: sortOrders,
        usage: const {
          'known': PresetUsageStats(count30d: 4),
          'omitted': PresetUsageStats.zero,
          'explicit-zero': PresetUsageStats.zero,
        },
        mode: PresetSortMode.mostUsed,
      );

      expect(withOmission, withExplicitZero);
      expect(withOmission, ['known', 'omitted', 'explicit-zero']);
    });

    test(
        'recentlyUsed mode: omitted id ranks the same as an explicit '
        'never-used stats object', () {
      final presetIds = ['known', 'omitted'];
      final sortOrders = {'known': 1, 'omitted': 2};
      final usedAt = DateTime.utc(2026, 7, 1);

      final withOmission = rankPresetIds(
        presetIds: presetIds,
        sortOrders: sortOrders,
        usage: {'known': PresetUsageStats(lastUsedAt: usedAt)},
        mode: PresetSortMode.recentlyUsed,
      );
      final withExplicitZero = rankPresetIds(
        presetIds: presetIds,
        sortOrders: sortOrders,
        usage: {
          'known': PresetUsageStats(lastUsedAt: usedAt),
          'omitted': PresetUsageStats.zero,
        },
        mode: PresetSortMode.recentlyUsed,
      );

      expect(withOmission, withExplicitZero);
      expect(withOmission, ['known', 'omitted']);
    });
  });

  group('PresetSortMode — stored / fromStored round-trip', () {
    // Source: preset_ranking.dart — `stored` is the canonical persisted
    // string (UserPreferences.drinkSortMode).
    test('stored strings match the documented canonical values', () {
      expect(PresetSortMode.manual.stored, 'manual');
      expect(PresetSortMode.recentlyUsed.stored, 'recentlyUsed');
      expect(PresetSortMode.mostUsed.stored, 'mostUsed');
    });

    test('fromStored round-trips every mode', () {
      for (final mode in PresetSortMode.values) {
        expect(PresetSortMode.fromStored(mode.stored), mode);
      }
    });

    // Source: preset_ranking.dart doc — "Falls back to recentlyUsed — the
    // documented default — for any unrecognised value rather than throwing."
    test('unrecognised value falls back to recentlyUsed', () {
      expect(
        PresetSortMode.fromStored('not-a-real-mode'),
        PresetSortMode.recentlyUsed,
      );
    });
  });
}
