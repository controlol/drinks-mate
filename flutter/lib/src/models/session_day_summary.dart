import 'bac_chart_series.dart';
import 'meal.dart';
import 'party_session.dart';

/// One [PartySession]'s slice of a single History day (F4/#26 day
/// drill-down "session summary card").
///
/// Every metric here is clipped to the day-window, not the session's full
/// lifetime — a session spanning midnight produces one [SessionDaySummary]
/// per day it touches, each describing only that day's slice (duration
/// within the day, drinks/meals logged that day, peak BAC sampled that day).
/// The exceptions are [session]'s own `startedAt`/`endedAt` and
/// [lifetimeBacChart], which describe the whole session and are identical
/// on every day card a multi-day session touches (user-experience.md §S3
/// expand).
class SessionDaySummary {
  const SessionDaySummary({
    required this.session,
    required this.duration,
    required this.totalAlcoholicDrinks,
    required this.mealsLoggedCount,
    this.peakBacGPerL,
    this.totalAlcoholGrams = 0,
    this.meals = const [],
    this.lifetimeBacChart,
    this.asOf,
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

  /// Total grams of alcohol consumed within the day-window (History day
  /// drill-down's expanded card, user-experience.md §S3 expand: "total
  /// consumed alcohol in grams" — day-clipped, same scope as
  /// [totalAlcoholicDrinks]).
  final double totalAlcoholGrams;

  /// The meals logged within the day-window, same scope as
  /// [mealsLoggedCount] (`mealsLoggedCount == meals.length`). Not rendered
  /// by [SessionSummaryCard] (the expanded card shows only the
  /// [mealsLoggedCount] count — user-experience.md §S3 expand); kept here
  /// as the day-scoped meal list for any other caller that needs it.
  final List<Meal> meals;

  /// The session's whole-lifetime static BAC chart — never day-clipped
  /// (user-experience.md §S3 expand: "not day-clipped ... renders
  /// identically on every day card"). Null when [peakBacGPerL] is also null
  /// (incomplete profile, no estimate possible).
  final BacChartSeries? lifetimeBacChart;

  /// The instant this snapshot was taken, e.g. for callers computing
  /// relative "N ago" times against [meals] elsewhere. Null when the caller
  /// doesn't need it.
  final DateTime? asOf;
}
