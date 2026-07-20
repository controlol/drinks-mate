import 'package:core/core.dart';

import '../models/bac_chart_series.dart';
import '../models/drink_entry.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import 'bac_estimator.dart';

export '../models/bac_chart_series.dart';

/// Default X-axis window shown before the first alcoholic drink is logged
/// (party-session.md §BAC line chart → Empty state; Parity Rulebook "BAC
/// chart empty-state window").
const Duration bacChartEmptyStateWindow = Duration(hours: 3);

/// Builds [BacChartSeries] for the Party tab's active-session view.
///
/// Before the first alcoholic drink is logged, returns a flat `0.00 g/L`
/// line across `sessionStartedAt` to `sessionStartedAt + 3h` with no
/// projected segment (party-session.md §BAC line chart → Empty state) —
/// this reserves the chart's footprint from the moment the session starts
/// so logging the first drink doesn't cause a layout jump.
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
  if (alcoholicEntries.isEmpty) {
    final axisStart = sessionStartedAt.toLocal();
    final axisEnd = axisStart.add(bacChartEmptyStateWindow);
    return BacChartSeries(
      axisStart: axisStart,
      axisEnd: axisEnd,
      actual: [
        BacChartPoint(time: axisStart, gPerL: 0),
        BacChartPoint(time: axisEnd, gPerL: 0),
      ],
      projected: const [],
      tickInterval: bacChartTickInterval(bacChartEmptyStateWindow),
    );
  }

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
      BacChartPoint(time: t, gPerL: _gPerLAt(t, profile, entries, meals)),
    );
    t = t.add(interval);
  }
  points.add(
    BacChartPoint(time: to, gPerL: _gPerLAt(to, profile, entries, meals)),
  );
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
