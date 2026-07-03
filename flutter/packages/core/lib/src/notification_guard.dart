/// Stateless notification suppression rules — pure Dart, no I/O.
///
/// All three checks are evaluated at scheduling time (or re-evaluated when a
/// notification fires via a platform handler). Each function takes explicit
/// parameters so callers supply live values and the guard itself has no state.
library;

/// Returns true when [now] is within the active-hours window.
///
/// The window is half-open: `[activeStartHour, activeEndHour)`.
/// e.g. start=8, end=22 → fires from 08:00 up to but not including 22:00.
///
/// Source: notifications.md §Configuration (default 08:00–22:00).
bool isInActiveHours({
  required DateTime now,
  required int activeStartHour,
  required int activeEndHour,
}) {
  assert(activeStartHour >= 0 && activeStartHour <= 23, 'start hour 0-23');
  assert(activeEndHour >= 0 && activeEndHour <= 23, 'end hour 0-23');
  final h = now.hour;
  if (activeStartHour < activeEndHour) {
    return h >= activeStartHour && h < activeEndHour;
  }
  // Overnight window (e.g. 22:00–06:00).
  return h >= activeStartHour || h < activeEndHour;
}

/// Returns true when all notifications should be suppressed because the user
/// has been inactive for ≥ 7 days.
///
/// ```
/// last_engagement = max(installedAt, latestDrinkConsumedAt ?? installedAt)
/// days_inactive   = floor((now − last_engagement) / 1 day)
/// silenced        = days_inactive >= 7
/// ```
///
/// Source: notifications.md §Inactive-user silence.
bool isInactiveUserSilenced({
  required DateTime now,
  required DateTime installedAt,
  DateTime? latestDrinkConsumedAt,
}) {
  final lastEngagement = latestDrinkConsumedAt != null
      ? (latestDrinkConsumedAt.isAfter(installedAt)
          ? latestDrinkConsumedAt
          : installedAt)
      : installedAt;
  final diffMs =
      now.millisecondsSinceEpoch - lastEngagement.millisecondsSinceEpoch;
  final daysInactive = (diffMs / Duration.millisecondsPerDay).floor();
  return daysInactive >= 7;
}

/// Returns true when less than [minIntervalMin] minutes have passed since the
/// most recent drink log — the flood-prevention guard.
///
/// Logging a drink resets the reminder timer: the next reminder fires
/// [minIntervalMin] after the most recent log, not after the
/// previously-scheduled reminder.
///
/// Callers supply [minIntervalMin] from the user's configured reminder interval
/// so no constant is hardcoded here.
///
/// Source: notifications.md §Behaviour condition 5, §Scheduling.
bool isNotificationTooSoon({
  required DateTime now,
  required DateTime? lastDrinkLoggedAt,
  required int minIntervalMin,
}) {
  if (lastDrinkLoggedAt == null) return false;
  final elapsedMin = now.difference(lastDrinkLoggedAt).inMilliseconds /
      Duration.millisecondsPerMinute;
  return elapsedMin < minIntervalMin;
}

/// Computes the next fire time at or after [from] that falls within the
/// active-hours window.
///
/// When [from] is before [activeStartHour] on the same calendar day, the
/// result is [activeStartHour] on that same day (not the next). When [from]
/// is at or past [activeEndHour], the result is [activeStartHour] on the
/// following day. Returns null if no valid slot is found within [maxDays]
/// days (safety limit).
DateTime? nextActiveSlot({
  required DateTime from,
  required int intervalMin,
  required int activeStartHour,
  required int activeEndHour,
  int maxDays = 7,
}) {
  assert(intervalMin > 0, 'interval must be positive');
  final deadline = from.add(Duration(days: maxDays));
  var candidate = from;
  while (candidate.isBefore(deadline)) {
    if (isInActiveHours(
      now: candidate,
      activeStartHour: activeStartHour,
      activeEndHour: activeEndHour,
    )) {
      return candidate;
    }
    final h = candidate.hour;
    final DateTime next;
    if (activeStartHour < activeEndHour) {
      // Standard (daytime) window: if before start → same day at start;
      // if at/past end → next day at start.
      if (h < activeStartHour) {
        next = DateTime(
          candidate.year,
          candidate.month,
          candidate.day,
          activeStartHour,
        );
      } else {
        next = DateTime(
          candidate.year,
          candidate.month,
          candidate.day + 1,
          activeStartHour,
        );
      }
    } else {
      // Overnight window (e.g. 22–06): candidate is in the daytime gap
      // [end, start) on the same day → jump to start on the same day.
      next = DateTime(
        candidate.year,
        candidate.month,
        candidate.day,
        activeStartHour,
      );
    }
    candidate = next;
  }
  return null;
}

/// Builds the list of up to [count] future notification times at [intervalMin]
/// intervals, starting at or after [from], restricted to active hours.
///
/// Used by the notification service's `scheduleRepeating` to pre-schedule a
/// rolling window of one-shot notifications (iOS 64-limit: keep count ≤ 48).
List<DateTime> buildScheduleSlots({
  required DateTime from,
  required int intervalMin,
  required int activeStartHour,
  required int activeEndHour,
  required int count,
}) {
  final slots = <DateTime>[];
  var cursor = from;
  // Advance cursor into the active window first.
  var next = nextActiveSlot(
    from: cursor,
    intervalMin: intervalMin,
    activeStartHour: activeStartHour,
    activeEndHour: activeEndHour,
  );
  while (next != null && slots.length < count) {
    slots.add(next);
    // Step intervalMin minutes forward and search for the next valid slot.
    cursor = next.add(Duration(minutes: intervalMin));
    next = nextActiveSlot(
      from: cursor,
      intervalMin: intervalMin,
      activeStartHour: activeStartHour,
      activeEndHour: activeEndHour,
    );
  }
  return slots;
}
