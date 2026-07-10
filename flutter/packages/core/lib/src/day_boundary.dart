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

/// Returns the `[start, end)` ISO-week window (Monday–Sunday, local time)
/// that contains [now].
///
/// The window is built from 7 consecutive [dayWindow]s: Monday's day-window
/// start through Sunday's day-window end (i.e. the following Monday's
/// day-window start). Because [dayWindow] shifts a pre-boundary instant back
/// to the previous calendar day, a Sunday firing time just after midnight but
/// before [boundaryHour] still resolves to Saturday's day-window and thus the
/// *previous* ISO week — consistent with "today" meaning the day-window, not
/// the calendar date.
///
/// Source: Parity Rulebook → "Weekly summary" (ISO week, Mon–Sun);
/// notifications.md §Notification types → Weekly summary.
(DateTime start, DateTime end) isoWeekWindow({
  required DateTime now,
  int boundaryHour = 5,
  int boundaryMinute = 0,
}) {
  final todayStart = dayWindow(
    now: now,
    boundaryHour: boundaryHour,
    boundaryMinute: boundaryMinute,
  ).$1;
  // DateTime.weekday: Monday = 1 .. Sunday = 7.
  final mondayStart = DateTime(
    todayStart.year,
    todayStart.month,
    todayStart.day - (todayStart.weekday - 1),
    boundaryHour,
    boundaryMinute,
  );
  final nextMondayStart = DateTime(
    mondayStart.year,
    mondayStart.month,
    mondayStart.day + 7,
    boundaryHour,
    boundaryMinute,
  );
  return (mondayStart, nextMondayStart);
}

/// Returns the `[start, end)` calendar-month window (local time) that
/// contains [now].
///
/// The window runs from the 1st of the month's day-window start through the
/// 1st of the following month's day-window start, mirroring [isoWeekWindow]'s
/// construction: a pre-boundary instant on the 1st still resolves to the
/// previous month's window, consistent with "day" meaning the day-window,
/// not the calendar date.
///
/// Source: Parity Rulebook → "Day boundary"; design/features.md F4 — History
/// monthly range.
(DateTime start, DateTime end) monthWindow({
  required DateTime now,
  int boundaryHour = 5,
  int boundaryMinute = 0,
}) {
  final todayStart = dayWindow(
    now: now,
    boundaryHour: boundaryHour,
    boundaryMinute: boundaryMinute,
  ).$1;
  final monthStart = DateTime(
    todayStart.year,
    todayStart.month,
    1,
    boundaryHour,
    boundaryMinute,
  );
  final nextMonthStart = DateTime(
    todayStart.year,
    todayStart.month + 1,
    1,
    boundaryHour,
    boundaryMinute,
  );
  return (monthStart, nextMonthStart);
}

/// Returns the `[start, end)` ISO-week window [offset] whole weeks before the
/// week containing [now] (`offset = 0` → the current week, `offset = 1` →
/// last week, etc.) — feeds the History screen's weekly paging (F4).
(DateTime start, DateTime end) pagedIsoWeekWindow({
  required DateTime now,
  required int offset,
  int boundaryHour = 5,
  int boundaryMinute = 0,
}) {
  final current = isoWeekWindow(
    now: now,
    boundaryHour: boundaryHour,
    boundaryMinute: boundaryMinute,
  );
  final start = DateTime(
    current.$1.year,
    current.$1.month,
    current.$1.day - 7 * offset,
    boundaryHour,
    boundaryMinute,
  );
  final end = DateTime(
    current.$2.year,
    current.$2.month,
    current.$2.day - 7 * offset,
    boundaryHour,
    boundaryMinute,
  );
  return (start, end);
}

/// Returns the `[start, end)` calendar-month window [offset] whole months
/// before the month containing [now] (`offset = 0` → the current month,
/// `offset = 1` → last month, etc.) — feeds the History screen's monthly
/// paging (F4).
(DateTime start, DateTime end) pagedMonthWindow({
  required DateTime now,
  required int offset,
  int boundaryHour = 5,
  int boundaryMinute = 0,
}) {
  final current = monthWindow(
    now: now,
    boundaryHour: boundaryHour,
    boundaryMinute: boundaryMinute,
  );
  final start = DateTime(
    current.$1.year,
    current.$1.month - offset,
    1,
    boundaryHour,
    boundaryMinute,
  );
  final end = DateTime(
    current.$1.year,
    current.$1.month - offset + 1,
    1,
    boundaryHour,
    boundaryMinute,
  );
  return (start, end);
}
