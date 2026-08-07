/// Drink-preset sort-mode ranking — shared by the Today "Log a drink" grid
/// and the S2 log-drink picker (features.md F14 §Sort modes; issue #78).
///
/// Three user-selectable modes rank the same preset set differently:
///  - `manual`: the user's own drag-reorder order (`DrinkPreset.sortOrder`).
///  - `recentlyUsed`: most-recently-logged preset first, `DrinkEntry
///    .consumedAt` basis (not `createdAt`) — a backdated entry ranks by when
///    the drink was actually had, not when it was typed in.
///  - `mostUsed`: highest trailing-30-day log count first, same
///    `consumedAt` basis and window.
///
/// All three tie-break on `sortOrder` ascending. This both resolves ties
/// deterministically and gives every preset with no qualifying usage yet —
/// a fresh install (cold start) or a preset that's simply never been logged
/// — a stable position instead of being shuffled by map/iteration order.
library;

/// One of the three preset sort modes (Parity Rulebook §Preset sort mode).
enum PresetSortMode {
  manual,
  recentlyUsed,
  mostUsed;

  /// Canonical string used in storage (`UserPreferences.drinkSortMode`).
  String get stored => switch (this) {
        PresetSortMode.manual => 'manual',
        PresetSortMode.recentlyUsed => 'recentlyUsed',
        PresetSortMode.mostUsed => 'mostUsed',
      };

  /// Inverse of [stored]. Falls back to [recentlyUsed] — the documented
  /// default — for any unrecognised value rather than throwing.
  static PresetSortMode fromStored(String value) => switch (value) {
        'manual' => PresetSortMode.manual,
        'mostUsed' => PresetSortMode.mostUsed,
        _ => PresetSortMode.recentlyUsed,
      };
}

/// Per-preset usage signals feeding [rankPresetIds]. Both fields are derived
/// from live (non-deleted) `DrinkEntry.consumedAt` — never `createdAt`.
class PresetUsageStats {
  const PresetUsageStats({this.lastUsedAt, this.count30d = 0});

  /// A preset that has never been logged: no last-used time, zero count.
  static const zero = PresetUsageStats();

  /// Most recent `consumedAt` across all time for this preset, or null if
  /// it has never been logged.
  final DateTime? lastUsedAt;

  /// Count of live entries for this preset with `consumedAt` in the
  /// trailing 30-day window ending "now" (inclusive of both ends).
  final int count30d;
}

/// Ranks [presetIds] for [mode], most-preferred first.
///
/// [sortOrders] and [usage] are looked up by preset id; a ranked id missing
/// from [sortOrders] is treated as `sortOrder` 0, and one missing from
/// [usage] is treated as never-used ([PresetUsageStats.zero]) — both are
/// the correct behaviour for a preset with no rows yet, not a caller bug.
List<String> rankPresetIds({
  required List<String> presetIds,
  required Map<String, int> sortOrders,
  required Map<String, PresetUsageStats> usage,
  required PresetSortMode mode,
}) {
  final ranked = [...presetIds];
  int sortOrderOf(String id) => sortOrders[id] ?? 0;
  PresetUsageStats usageOf(String id) => usage[id] ?? PresetUsageStats.zero;

  switch (mode) {
    case PresetSortMode.manual:
      ranked.sort((a, b) => sortOrderOf(a).compareTo(sortOrderOf(b)));
    case PresetSortMode.recentlyUsed:
      ranked.sort((a, b) {
        final aLast = usageOf(a).lastUsedAt;
        final bLast = usageOf(b).lastUsedAt;
        if (aLast == null && bLast == null) {
          return sortOrderOf(a).compareTo(sortOrderOf(b));
        }
        // Never-used presets sink to the bottom of this mode — they have no
        // "recently" to rank by — but keep their relative sortOrder there.
        if (aLast == null) return 1;
        if (bLast == null) return -1;
        final cmp = bLast.compareTo(aLast); // descending: most recent first
        return cmp != 0 ? cmp : sortOrderOf(a).compareTo(sortOrderOf(b));
      });
    case PresetSortMode.mostUsed:
      ranked.sort((a, b) {
        final cmp = usageOf(b).count30d.compareTo(usageOf(a).count30d);
        return cmp != 0 ? cmp : sortOrderOf(a).compareTo(sortOrderOf(b));
      });
  }
  return ranked;
}
