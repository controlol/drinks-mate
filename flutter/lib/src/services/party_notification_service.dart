import 'package:core/core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/party_session.dart';
import '../models/user_preferences.dart';
import 'bac_estimator.dart';
import 'notification_service.dart';
import 'party_notification_guard.dart';

/// Notification id for the approaching-cap alert (issue #24).
///
/// One-shot per session; the once-per-session rule is enforced by
/// [PartyNotificationGuard], not by this id alone.
const int kApproachingCapNotificationId = 400;

/// Notification id for the sober-estimate alert (issue #24).
///
/// One-shot, but rescheduled (same id replaces the pending occurrence)
/// whenever the projected zero-time changes.
const int kSoberEstimateNotificationId = 500;

/// Schedules/cancels Party Mode's two session-scoped notification types
/// (notifications.md §Party Mode notifications; party-session.md
/// §Notifications during a session):
///
/// - **Approaching cap** — fires once, the first time estimated BAC reaches
///   80% of the personal cap this session.
/// - **Sober estimate** — a single notification at the projected time BAC
///   returns to 0 g/L; rescheduled whenever a new drink/meal changes that
///   projection.
///
/// Neither fires outside an active session, nor when
/// `UserPreferences.reminderEnabled` (the master toggle) is off, nor when
/// their own toggle is off — cancelled in all three cases. Call [sync]
/// whenever the active session, its BAC inputs, or preferences change — see
/// `providers.dart`'s `partyNotificationSyncProvider`.
class PartyNotificationService {
  PartyNotificationService(this._notifications, this._guard);

  final NotificationService _notifications;
  final PartyNotificationGuard _guard;

  /// Recomputes and re-schedules (or cancels) both Party Mode notification
  /// types from the current session/preferences/BAC state.
  ///
  /// [session] is the active session, or `null` when none is active (either
  /// never started, or just ended — manually or via auto-timeout). [estimate]
  /// and [capGPerL] feed the approaching-cap check; [projectedSoberTime] is
  /// the session-wide projected return-to-zero time (`null` before the first
  /// alcoholic drink is logged). [now] defaults to [DateTime.now] and exists
  /// so callers/tests can pin it.
  Future<void> sync({
    required PartySession? session,
    required UserPreferences prefs,
    BacEstimate estimate = BacEstimate.zero,
    double? capGPerL,
    DateTime? projectedSoberTime,
    DateTime? now,
  }) async {
    // notifications.md §Configuration: "Reminders enabled — master on/off
    // toggle. When off, no notifications of any type fire." — applies here
    // too, not just the hydration-family types.
    if (session == null || !session.isActive || !prefs.reminderEnabled) {
      await _notifications.cancel(kApproachingCapNotificationId);
      await _notifications.cancel(kSoberEstimateNotificationId);
      return;
    }

    final nowLocal = (now ?? DateTime.now());
    final visibility = prefs.bacOnLockScreenEnabled
        ? NotificationVisibility.public
        : NotificationVisibility.private;

    await _syncApproachingCap(
      session: session,
      prefs: prefs,
      estimate: estimate,
      capGPerL: capGPerL,
      now: nowLocal,
      visibility: visibility,
    );
    await _syncSoberEstimate(
      prefs: prefs,
      projectedSoberTime: projectedSoberTime,
      now: nowLocal,
      visibility: visibility,
    );
  }

  Future<void> _syncApproachingCap({
    required PartySession session,
    required UserPreferences prefs,
    required BacEstimate estimate,
    required double? capGPerL,
    required DateTime now,
    required NotificationVisibility visibility,
  }) async {
    if (!prefs.approachingCapNotifEnabled || capGPerL == null) {
      await _notifications.cancel(kApproachingCapNotificationId);
      return;
    }

    final approaching = isApproachingCap(
      bacGPerL: estimate.gPerL,
      capGPerL: capGPerL,
    );
    if (!approaching) return;
    if (!await _guard.shouldFireApproachingCap(session.id)) return;

    // No "fire now" primitive exists on NotificationService (issue #19's
    // interface only schedules future times) — scheduling 1s out is the
    // pragmatic one-shot "immediate" notification within that constraint.
    await _notifications.scheduleOnce(
      id: kApproachingCapNotificationId,
      title: 'Drinks Mate',
      body: "You've reached 80% of your personal BAC cap "
          '(${capGPerL.toStringAsFixed(2)} g/L).',
      channelId: kPartyModeChannelId,
      scheduledTime: now.add(const Duration(seconds: 1)),
      payload: 'approaching_cap',
      visibility: visibility,
    );
    await _guard.markApproachingCapFired(session.id);
  }

  Future<void> _syncSoberEstimate({
    required UserPreferences prefs,
    required DateTime? projectedSoberTime,
    required DateTime now,
    required NotificationVisibility visibility,
  }) async {
    // A past/now projection means the real sober moment already happened
    // (and, if the OS was alive to see it, already fired) — most likely
    // because the app was reopened well after BAC hit 0. Re-scheduling it
    // would risk an immediate, spurious "back to 0" notification on reopen,
    // so treat it the same as "nothing to schedule".
    if (!prefs.soberEstimateNotifEnabled ||
        projectedSoberTime == null ||
        !projectedSoberTime.isAfter(now)) {
      await _notifications.cancel(kSoberEstimateNotificationId);
      return;
    }

    await _notifications.scheduleOnce(
      id: kSoberEstimateNotificationId,
      title: 'Drinks Mate',
      body: 'Estimated BAC is back to 0 — remember this is an estimate.',
      channelId: kPartyModeChannelId,
      scheduledTime: projectedSoberTime,
      payload: 'sober_estimate',
      visibility: visibility,
    );
  }
}
