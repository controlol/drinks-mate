import 'package:core/core.dart';

import '../models/drink_entry.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import 'bac_estimator.dart';

/// One sampled point on the Party tab's BAC line chart.
class BacChartPoint {
  const BacChartPoint({required this.time, required this.gPerL});

  /// Local wall-clock time — chart tick labels are "24-hour digital local
  /// time" (party-session.md §BAC line chart), so every point here is
  /// already local.
  final DateTime time;
  final double gPerL;
}

/// The Party tab's BAC line chart data (party-session.md §BAC line chart),
/// built once per rebuild from the session's live entries/meals.
class BacChartSeries {
  const BacChartSeries({
    required this.axisStart,
    required this.axisEnd,
    required this.actual,
    required this.projected,
    required this.tickInterval,
  });

  /// X-axis start — the session's `startedAt`, local.
  final DateTime axisStart;

  /// X-axis end — the projected return-to-zero time, rounded up to the next
  /// 30 minutes ([roundUpToNextHalfHour]).
  final DateTime axisEnd;

  /// Solid segment: `startedAt` → `min(now, axisEnd)`, actual/already-elapsed
  /// BAC. Always has at least one point.
  final List<BacChartPoint> actual;

  /// Dashed segment: `min(now, axisEnd)` → `axisEnd`, the projection. Empty
  /// once the session has already reached (or passed) `axisEnd` (e.g. an
  /// ended session viewed later).
  final List<BacChartPoint> projected;

  /// Tick spacing for the X axis ([bacChartTickInterval]).
  final Duration tickInterval;
}

/// Builds [BacChartSeries] for the Party tab's active-session view.
///
/// Returns `null` before the first alcoholic drink is logged — the spec's
/// own empty state ("chart only appears once the first alcoholic drink is
/// logged") is the caller's responsibility, not this function's.
///
/// [alcoholicEntries] and [meals] must be [profile]'s live session data,
/// same inputs as [estimateSessionBac]/[projectedSoberTime].
BacChartSeries? buildBacChartSeries({
  required UserProfile profile,
  required DateTime sessionStartedAt,
  required List<DrinkEntry> alcoholicEntries,
  required List<Meal> meals,
  required DateTime now,
  Duration sampleInterval = const Duration(minutes: 5),
}) {
  if (alcoholicEntries.isEmpty) return null;

  final soberTime = projectedSoberTime(
    profile: profile,
    alcoholicEntries: alcoholicEntries,
    meals: meals,
  );
  if (soberTime == null) return null;

  final axisStart = sessionStartedAt.toLocal();
  final axisEnd = roundUpToNextHalfHour(soberTime.toLocal());
  final nowLocal = now.toLocal();
  final actualEnd = nowLocal.isBefore(axisEnd) ? nowLocal : axisEnd;

  final actual = _samplePoints(
    from: axisStart,
    to: actualEnd,
    interval: sampleInterval,
    profile: profile,
    entries: alcoholicEntries,
    meals: meals,
  );

  final projected = actualEnd.isBefore(axisEnd)
      ? _samplePoints(
          from: actualEnd,
          to: axisEnd,
          interval: sampleInterval,
          profile: profile,
          entries: alcoholicEntries,
          meals: meals,
        )
      : const <BacChartPoint>[];

  return BacChartSeries(
    axisStart: axisStart,
    axisEnd: axisEnd,
    actual: actual,
    projected: projected,
    tickInterval: bacChartTickInterval(axisEnd.difference(axisStart)),
  );
}

List<BacChartPoint> _samplePoints({
  required DateTime from,
  required DateTime to,
  required Duration interval,
  required UserProfile profile,
  required List<DrinkEntry> entries,
  required List<Meal> meals,
}) {
  final points = <BacChartPoint>[];
  var t = from;
  while (t.isBefore(to)) {
    points.add(
        BacChartPoint(time: t, gPerL: _gPerLAt(t, profile, entries, meals)));
    t = t.add(interval);
  }
  points.add(
      BacChartPoint(time: to, gPerL: _gPerLAt(to, profile, entries, meals)));
  return points;
}

/// Samples the estimated BAC at instant [t], counting only entries already
/// consumed by [t] — this must hold for both the actual and projected
/// segments. An entry's `consumedAt` is not guaranteed to be `<= now`: S9's
/// edit affordance allows setting a future `consumedAt` (e.g. correcting a
/// mis-picked time), and [estimateSessionBac] clamps a negative
/// `hoursSince` to 0 rather than excluding the entry, so an unfiltered call
/// would let a not-yet-"consumed" entry inflate an earlier sample at its
/// full undecayed value (mirrors history_bac_service.dart's `_sampleAt`).
double _gPerLAt(
  DateTime t,
  UserProfile profile,
  List<DrinkEntry> entries,
  List<Meal> meals,
) {
  final consumedByT = entries.where((e) => !e.consumedAt.isAfter(t)).toList();
  return estimateSessionBac(
    profile: profile,
    alcoholicEntries: consumedByT,
    meals: meals,
    at: t,
  ).gPerL;
}
