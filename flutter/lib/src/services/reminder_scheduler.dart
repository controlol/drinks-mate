import 'package:core/core.dart';

import '../models/beverage_type.dart';
import '../models/drink_preset.dart';
import '../models/user_preferences.dart';
import '../repository/drinks_repository.dart';
import 'notification_service.dart';
import 'reminder_copy.dart';

/// Notification id for the repeating hydration-reminder batch (F5).
///
/// Batch slot ids are `kHydrationReminderNotificationId * 1000 + index`
/// (see [NotificationService.scheduleRepeating]).
const int kHydrationReminderNotificationId = 100;

/// Notification id for the once-daily inactivity reminder (F5).
const int kInactivityReminderNotificationId = 200;

/// Notification id for the once-weekly summary (F5).
const int kWeeklySummaryNotificationId = 300;

/// Default drink volume (ml) used when no default-drink preset resolves —
/// mirrors the seeded "Glass of water" preset (data-model.md
/// §UserPreferences: "fall back to seeded 'Glass of water' or hardcoded
/// 200 ml water").
const int kFallbackDefaultDrinkVolumeMl = 200;

/// Schedules/cancels the three hydration-related reminder types (F5):
/// the interval-based hydration reminder, the once-daily inactivity
/// reminder, and the once-weekly summary.
///
/// All content is computed **at schedule time** — notifications.md's
/// "recompute at delivery time when possible" is a native-platform callback
/// concern (see [NotificationService]'s `payload` docs) that phase 1 does not
/// implement. Callers must call [reschedule] again whenever anything that
/// feeds these computations changes: preferences (toggles, active hours,
/// interval, default drink), a drink being logged/edited/deleted, or a day
/// boundary rollover — see `providers.dart`'s `reminderReschedulerProvider`.
class ReminderScheduler {
  ReminderScheduler(this._notifications, this._drinks);

  final NotificationService _notifications;
  final DrinksRepository _drinks;

  /// Recomputes and re-schedules (or cancels) all three reminder types from
  /// the current preferences and drink-log state.
  Future<void> reschedule({
    required UserPreferences prefs,
    DrinkPreset? defaultDrinkPreset,
    DateTime? now,
  }) async {
    // Scheduling calls depend on the plugin/channels being set up first
    // (issue #97) — initialize() is idempotent, so this is a no-op once
    // startup's own call (see `notificationInitializerProvider`) completes.
    await _notifications.initialize();
    final nowLocal = (now ?? DateTime.now()).toLocal();
    final latestDrinkAtUtc = await _drinks.getLatestDrinkConsumedAt();
    final latestDrinkAtLocal = latestDrinkAtUtc?.toLocal();

    // Universal rule — applies to every notification type below
    // (notifications.md §Inactive-user silence).
    final silenced = isInactiveUserSilenced(
      now: nowLocal,
      installedAt: prefs.installedAt.toLocal(),
      latestDrinkConsumedAt: latestDrinkAtLocal,
    );

    final dayStart = dayWindow(
      now: nowLocal,
      boundaryHour: prefs.dayBoundaryHour,
    ).$1;
    final hasLoggedToday =
        latestDrinkAtLocal != null && !latestDrinkAtLocal.isBefore(dayStart);

    await _rescheduleHydration(
      prefs,
      defaultDrinkPreset,
      nowLocal,
      silenced,
      latestDrinkAtLocal,
    );
    await _rescheduleInactivity(prefs, nowLocal, silenced, hasLoggedToday);
    await _rescheduleWeeklySummary(prefs, nowLocal, silenced);
  }

  // ---------------------------------------------------------------------------
  // Hydration reminder
  // ---------------------------------------------------------------------------

  Future<void> _rescheduleHydration(
    UserPreferences prefs,
    DrinkPreset? defaultDrinkPreset,
    DateTime nowLocal,
    bool silenced,
    DateTime? latestDrinkAtLocal,
  ) async {
    if (!prefs.reminderEnabled || silenced) {
      await _notifications.cancelRepeating(kHydrationReminderNotificationId);
      return;
    }

    final todayIntakeMl = await _drinks.getTodayTotalMl(
      now: nowLocal,
      boundaryHour: prefs.dayBoundaryHour,
    );
    if (todayIntakeMl >= prefs.dailyGoalMl) {
      // Condition 4 (notifications.md §Behaviour): goal already met today —
      // cancel remaining same-day reminders. The next day's first reminder
      // is scheduled normally on the next reschedule() after rollover.
      await _notifications.cancelRepeating(kHydrationReminderNotificationId);
      return;
    }

    final dayStart = dayWindow(
      now: nowLocal,
      boundaryHour: prefs.dayBoundaryHour,
    ).$1;
    final activeStart = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day,
      prefs.reminderStartHour,
    );
    final activeEnd = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day,
      prefs.reminderEndHour,
    );

    final defaultVolumeMl =
        (defaultDrinkPreset?.volumeMl ?? kFallbackDefaultDrinkVolumeMl)
            .toDouble();
    final glasses = recommendedReminderVolumeGlasses(
      goalMl: prefs.dailyGoalMl.toDouble(),
      activeStart: activeStart,
      activeEnd: activeEnd,
      now: nowLocal,
      actualIntakeMl: todayIntakeMl.toDouble(),
      defaultDrinkVolumeMl: defaultVolumeMl,
    );

    // Phase-1 approximation (not a Parity Rulebook rule): without a native
    // delivery-time callback we cannot know, per scheduled slot, whether that
    // specific previous reminder was acted on. We treat "no log since one
    // interval before now" as the off-pace ("missed a timer") signal, and
    // "within the first interval of today's active window" as "no previous
    // reminder exists yet today" (on-pace) — the two named conditions from
    // notifications.md §Notification types → Hydration reminder.
    final missedPrevious = _missedPreviousHydrationReminder(
      now: nowLocal,
      lastDrinkLoggedAt: latestDrinkAtLocal,
      activeWindowStartToday: activeStart,
      intervalMin: prefs.reminderIntervalMin,
    );

    final beverageType = defaultDrinkPreset?.beverageType ?? BeverageType.water;
    final body = hydrationReminderBody(
      glasses: glasses,
      beverageType: beverageType,
      missedPrevious: missedPrevious,
    );

    // Logging a drink resets the reminder timer (notifications.md
    // §Scheduling): the next reminder fires `interval` after the most recent
    // log, not after the previously-scheduled reminder. Clamp to `now` so a
    // stale log from days ago never produces a start time in the past.
    final earliestNext = latestDrinkAtLocal != null
        ? latestDrinkAtLocal.add(Duration(minutes: prefs.reminderIntervalMin))
        : nowLocal;
    final startTime = earliestNext.isAfter(nowLocal) ? earliestNext : nowLocal;

    // Quick-log action label (notifications.md §Notification quick-log
    // action: "Log {default_drink}" e.g. "Log water · 200 ml" — the beverage
    // noun, not the preset's display name, per the Rulebook's "Glass-count
    // copy formatting" row). Tapping the button is not yet wired to actually
    // log a drink — see kLogDrinkActionId's doc.
    final quickLogLabel = defaultDrinkPreset == null
        ? 'Log a drink'
        : 'Log ${beverageNoun(defaultDrinkPreset.beverageType)} · '
            '${defaultDrinkPreset.volumeMl} ml';

    await _notifications.scheduleRepeating(
      id: kHydrationReminderNotificationId,
      title: 'Drinks Mate',
      body: body,
      channelId: kHydrationChannelId,
      startTime: startTime,
      intervalMin: prefs.reminderIntervalMin,
      activeStartHour: prefs.reminderStartHour,
      activeEndHour: prefs.reminderEndHour,
      payload: 'hydration_reminder',
      quickLogActionLabel: quickLogLabel,
    );
  }

  bool _missedPreviousHydrationReminder({
    required DateTime now,
    required DateTime? lastDrinkLoggedAt,
    required DateTime activeWindowStartToday,
    required int intervalMin,
  }) {
    final noPreviousReminderYet =
        now.difference(activeWindowStartToday).inMinutes < intervalMin;
    if (noPreviousReminderYet) return false;
    if (lastDrinkLoggedAt == null) return true;
    return now.difference(lastDrinkLoggedAt).inMinutes >= intervalMin;
  }

  // ---------------------------------------------------------------------------
  // Inactivity reminder
  // ---------------------------------------------------------------------------

  Future<void> _rescheduleInactivity(
    UserPreferences prefs,
    DateTime nowLocal,
    bool silenced,
    bool hasLoggedToday,
  ) async {
    // hasLoggedToday: anti-spam rule — a drink logged today suppresses the
    // inactivity reminder for the day (notifications.md §Anti-spam principles).
    if (!prefs.inactivityReminderEnabled || silenced || hasLoggedToday) {
      await _notifications.cancel(kInactivityReminderNotificationId);
      return;
    }

    final targetHour = _snapNoonToActiveHoursStart(
      startHour: prefs.reminderStartHour,
      endHour: prefs.reminderEndHour,
    );
    // Anchor on the day-boundary-aligned "today" (matching the `dayStart`
    // used for `hasLoggedToday` above), not nowLocal's raw calendar date —
    // otherwise a pre-boundary reschedule() call (e.g. 02:00 with the
    // default 05:00 boundary) would fire on the wrong logical day.
    final dayStart = dayWindow(
      now: nowLocal,
      boundaryHour: prefs.dayBoundaryHour,
    ).$1;
    var fireTime = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day,
      targetHour,
    );
    if (!fireTime.isAfter(nowLocal)) {
      fireTime = fireTime.add(const Duration(days: 1));
    }

    await _notifications.scheduleOnce(
      id: kInactivityReminderNotificationId,
      title: 'Drinks Mate',
      body: inactivityReminderBody(),
      channelId: kHydrationChannelId,
      scheduledTime: fireTime,
      payload: 'inactivity_reminder',
    );
  }

  // ---------------------------------------------------------------------------
  // Weekly summary
  // ---------------------------------------------------------------------------

  Future<void> _rescheduleWeeklySummary(
    UserPreferences prefs,
    DateTime nowLocal,
    bool silenced,
  ) async {
    if (!prefs.weeklySummaryEnabled || silenced) {
      await _notifications.cancel(kWeeklySummaryNotificationId);
      return;
    }

    final targetHour = _snapHourToActiveWindow(
      targetHour: 20,
      startHour: prefs.reminderStartHour,
      endHour: prefs.reminderEndHour,
    );
    final fireTime = _nextSunday(nowLocal, targetHour);

    // Computed at schedule time from the ISO week the notification will
    // report on; kept fresh because reschedule() re-runs on every relevant
    // change (see class doc).
    final daysAtGoal = await _drinks.isoWeekDaysOnGoal(
      dailyGoalMl: prefs.dailyGoalMl,
      boundaryHour: prefs.dayBoundaryHour,
      now: fireTime,
    );

    await _notifications.scheduleOnce(
      id: kWeeklySummaryNotificationId,
      title: 'Drinks Mate',
      body: weeklySummaryBody(daysAtGoal),
      channelId: kWeeklySummaryChannelId,
      scheduledTime: fireTime,
      payload: 'weekly_summary',
    );
  }

  DateTime _nextSunday(DateTime nowLocal, int hour) {
    final daysUntilSunday = (DateTime.sunday - nowLocal.weekday) % 7;
    var candidate = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day + daysUntilSunday,
      hour,
    );
    if (!candidate.isAfter(nowLocal)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  // ---------------------------------------------------------------------------
  // Snap-into-active-hours helpers
  // ---------------------------------------------------------------------------

  /// Snaps noon to the active-hours **start** whenever noon itself falls
  /// outside `[startHour, endHour)` — unconditionally, regardless of which
  /// side of the window it falls on.
  ///
  /// Source: notifications.md §Notification types → Inactivity reminder:
  /// "snapped to the configured active-hours start if noon is outside active
  /// hours" (the doc names only "start", not "the nearer edge").
  int _snapNoonToActiveHoursStart({
    required int startHour,
    required int endHour,
  }) {
    const noon = 12;
    final inWindow = startHour < endHour
        ? noon >= startHour && noon < endHour
        : noon >= startHour || noon < endHour;
    return inWindow ? noon : startHour;
  }

  /// Snaps a fixed clock hour into `[startHour, endHour)` if it falls outside,
  /// moving to whichever bound it crossed.
  ///
  /// Source: notifications.md §Notification types → Weekly summary: "snapped
  /// into the user's active hours if 20:00 falls outside (e.g. fires at the
  /// active-hours end if active hours close before 20:00)".
  int _snapHourToActiveWindow({
    required int targetHour,
    required int startHour,
    required int endHour,
  }) {
    if (startHour < endHour) {
      if (targetHour < startHour) return startHour;
      if (targetHour >= endHour) return endHour;
      return targetHour;
    }
    // Overnight window (e.g. 22–06): only the daytime gap [end, start) is
    // outside active hours.
    if (targetHour >= endHour && targetHour < startHour) return startHour;
    return targetHour;
  }
}
