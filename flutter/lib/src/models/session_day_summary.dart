import 'party_session.dart';

/// One [PartySession]'s slice of a single History day (F4/#26 day
/// drill-down "session summary card").
///
/// Every metric here is clipped to the day-window, not the session's full
/// lifetime — a session spanning midnight produces one [SessionDaySummary]
/// per day it touches, each describing only that day's slice (duration
/// within the day, alcohol logged that day, peak BAC sampled that day).
class SessionDaySummary {
  const SessionDaySummary({
    required this.session,
    required this.duration,
    required this.totalAlcoholMl,
    this.peakBacGPerL,
  });

  final PartySession session;

  /// This session's active time within the day-window.
  final Duration duration;

  /// Sum of alcoholic [volumeMl] logged within the day-window.
  final int totalAlcoholMl;

  /// Peak estimated BAC sampled within the day-window, or null when the
  /// user's profile is incomplete (birthDate missing) and no estimate could
  /// be computed.
  final double? peakBacGPerL;
}
