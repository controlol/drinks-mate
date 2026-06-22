/// Day-window bucketing.
///
/// Source: Parity Rulebook → "Day boundary".
/// Default: 05:00 local. A drink's "day" = the window [boundary, next boundary)
/// whose local-time range contains its consumedAt.
library;

/// Returns the [start, end) day window (local time) that contains [now].
///
/// [now] must be a local DateTime (e.g. DateTime.now()).
/// [boundaryHour] and [boundaryMinute] specify the configurable day boundary
/// (default 5, 0 for 05:00).
///
/// Uses explicit DateTime construction rather than Duration arithmetic so that
/// DST transitions and month-end rollovers are handled correctly by the
/// platform's calendar arithmetic.
(DateTime start, DateTime end) dayWindow({
  required DateTime now,
  int boundaryHour = 5,
  int boundaryMinute = 0,
}) {
  final todayBoundary = DateTime(
    now.year,
    now.month,
    now.day,
    boundaryHour,
    boundaryMinute,
  );

  if (now.isBefore(todayBoundary)) {
    // now is before today's boundary → window started at yesterday's boundary
    final start = DateTime(
      now.year,
      now.month,
      now.day - 1,
      boundaryHour,
      boundaryMinute,
    );
    return (start, todayBoundary);
  } else {
    final end = DateTime(
      now.year,
      now.month,
      now.day + 1,
      boundaryHour,
      boundaryMinute,
    );
    return (todayBoundary, end);
  }
}
