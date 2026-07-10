import 'package:shared_preferences/shared_preferences.dart';

// Once-per-session guard for the approaching-cap notification.
//
// notifications.md / party-session.md §Notifications during a session: the
// approaching-cap notification "fires exactly once per session" — clearing
// or starting a new session resets the trigger. Mirrors
// goal_celebration_guard.dart's once-per-day pattern, keyed by session id
// instead of a date string so a *new* session (a different id) always resets
// it, with no explicit "clear" needed.
//
// The sober-estimate notification needs no such guard: it is simply
// rescheduled (or cancelled) every time the projected zero-time changes —
// see PartyNotificationService.

abstract interface class PartyNotificationGuard {
  Future<bool> shouldFireApproachingCap(String sessionId);
  Future<void> markApproachingCapFired(String sessionId);
}

/// Production implementation backed by SharedPreferences.
class SharedPrefsPartyNotificationGuard implements PartyNotificationGuard {
  static const _key = 'party_approaching_cap_fired_session_id';

  @override
  Future<bool> shouldFireApproachingCap(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) != sessionId;
  }

  @override
  Future<void> markApproachingCapFired(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, sessionId);
  }
}

/// In-memory implementation for widget tests — no SharedPreferences I/O.
class InMemoryPartyNotificationGuard implements PartyNotificationGuard {
  String? _firedSessionId;

  @override
  Future<bool> shouldFireApproachingCap(String sessionId) async =>
      _firedSessionId != sessionId;

  @override
  Future<void> markApproachingCapFired(String sessionId) async =>
      _firedSessionId = sessionId;
}
