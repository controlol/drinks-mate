import 'party_session.dart';

/// One [PartySession]'s slice of a single History day (F4/#26 day
/// drill-down "session summary card").
///
/// Every metric here is clipped to the day-window, not the session's full
/// lifetime — a session spanning midnight produces one [SessionDaySummary]
/// per day it touches, each describing only that day's slice (duration
/// within the day, drinks/meals logged that day, peak BAC sampled that day).
class SessionDaySummary {
  const SessionDaySummary({
    required this.session,
    required this.duration,
    required this.totalAlcoholicDrinks,
    required this.mealsLoggedCount,
    this.peakBacGPerL,
  });

  final PartySession session;

  /// This session's active time within the day-window.
  final Duration duration;

  /// Count of alcoholic entries logged within the day-window (features.md
  /// F4: "total alcoholic drinks" — a count, matching the sibling
  /// "Alcoholic drinks per day" chart's count semantics, not a volume).
  final int totalAlcoholicDrinks;

  /// Count of meals logged within the day-window (features.md F4: "meals
  /// logged").
  final int mealsLoggedCount;

  /// Peak estimated BAC sampled within the day-window, or null when the
  /// user's profile is incomplete (birthDate missing) and no estimate could
  /// be computed.
  final double? peakBacGPerL;
}
