/// One sampled point on a BAC line chart.
class BacChartPoint {
  const BacChartPoint({required this.time, required this.gPerL});

  /// Local wall-clock time — chart tick labels are "24-hour digital local
  /// time" (party-session.md §BAC line chart), so every point here is
  /// already local.
  final DateTime time;
  final double gPerL;
}

/// A BAC line chart's plotted data — the Party tab's live session chart
/// (party-session.md §BAC line chart, `buildBacChartSeries`) and the History
/// day drill-down's static whole-lifetime chart (user-experience.md §S3
/// expand, `buildSessionLifetimeBacSeries`) share this shape.
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

  /// X-axis end. For the live Party tab chart, the projected return-to-zero
  /// time ([roundUpToNextHalfHour]); for the static History chart, the
  /// session's own `endedAt` (or `now` while still active).
  final DateTime axisEnd;

  /// Solid segment: `startedAt` → `min(now, axisEnd)`, actual/already-elapsed
  /// BAC. Always has at least one point.
  final List<BacChartPoint> actual;

  /// Dashed segment: `min(now, axisEnd)` → `axisEnd`, the projection. Empty
  /// once the session has already reached (or passed) `axisEnd` (e.g. an
  /// ended session viewed later), and always empty for the static History
  /// chart (user-experience.md §S3 expand: "no dashed projection segment").
  final List<BacChartPoint> projected;

  /// Tick spacing for the X axis ([bacChartTickInterval]).
  final Duration tickInterval;
}
