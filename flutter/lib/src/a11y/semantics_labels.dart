// Shared accessibility-label key strings for every interactive element.
//
// Each label maps one-to-one to a Semantics widget's `label:` argument or a
// widget's `semanticsLabel:` parameter, so the spoken VoiceOver/TalkBack
// experience is defined in one place (design-system.md §Accessibility; C5).
//
// Non-colour state signals (Parity Rulebook §Non-colour-signal rules):
// Drinks Mate never uses colour as the sole indicator of state. Every
// colour-encoded state ships with a paired non-colour signal:
//   - Status pill: text label ("On pace" / "Behind" / "Ahead") alongside colour.
//   - Goal met: icon + "Goal reached" text alongside colour change.
//   - History bars below daily goal: a non-colour pattern/marker in addition
//     to the colour difference (C3, designer-brief §Colour).
//   - Behind-pace amber vs honey CTA: must be distinguishable by label/icon
//     since both are warm hues (designer-brief §Colour).
//   - Pace tick on progress bar: non-fill-colour treatment, visible against
//     both the on-pace fill and the behind-pace fill (designer-brief §Layout).
// This comment intentionally appears here — the a11y module is the canonical
// location for this design-system rule so contributors encounter it when
// adding new colour-dependent states.
abstract final class SemanticsLabels {
  SemanticsLabels._();

  // ---------------------------------------------------------------------------
  // Today screen (S1)
  // ---------------------------------------------------------------------------

  static const String logDrinkButton = 'Log drink';
  static const String progressCard =
      "Today's hydration progress — tap to view drink log";
  static const String statusPill = 'Hydration status';
  static const String sevenDayAverage = '7-day daily average intake';
  static const String daysOnGoal = 'Days on goal in the last 7 days';

  // Prefix for quick-log preset tiles — append the preset display name.
  // Example: '${SemanticsLabels.quickLogPrefix}Still water'
  static const String quickLogPrefix = 'Quick log: ';
  static const String sortModeSelector = 'Sort drinks by';
  static const String createPresetEntry = 'Create new preset';

  // ---------------------------------------------------------------------------
  // Today drinks log screen (S6)
  // ---------------------------------------------------------------------------

  static const String deleteEntryButton = 'Delete drink entry';
  static const String emptyDrinkLog = 'No drinks logged yet today';
  static const String logFirstDrinkButton = 'Log a drink';

  // ---------------------------------------------------------------------------
  // Party screen (S7)
  // ---------------------------------------------------------------------------

  static const String bacValue =
      'Estimated blood alcohol concentration — this is an estimate only';
  static const String startPartySession = 'Start party session';
  static const String endPartySession = 'End party session';
  static const String logAlcoholButton = 'Log alcohol';
  static const String approachingCapBanner = 'Approaching your personal cap';
  static const String bmiWarningBanner = 'BAC accuracy notice';
  static const String under18Gate = 'Party Mode is for adults 18 and over';
  static const String bacDisclaimer =
      'BAC is an estimate. Never use it to determine fitness to drive.';
  static const String useSessionPricesToggle = 'Use session prices';
  static const String managePricesButton = 'Manage prices';
  static const String sessionTotalsStrip = 'Session spending totals';
  static const String bacLineChart =
      'Estimated blood alcohol concentration over time chart — this is an '
      'estimate only';
  static const String drinksCountLine =
      'Drinks logged this session — tap to open the session log';
  static const String mealIndicator = 'Meal logged this session';
  static const String pastSessionsList = 'Past party sessions';
  static const String deleteSessionButton = 'Delete party session';
  static const String editSessionNameButton = 'Edit session name';

  // ---------------------------------------------------------------------------
  // Party Session Log screen (S9)
  // ---------------------------------------------------------------------------

  static const String partySessionEntryList = "This session's alcoholic drinks";
  static const String partySessionEmptyState =
      'No alcoholic drinks logged in this session yet';

  // ---------------------------------------------------------------------------
  // History screen (S3)
  // ---------------------------------------------------------------------------

  static const String historyRangeModeSelector = 'Weekly or monthly range';
  static const String historyPageBack = 'Previous period';
  static const String historyPageForward = 'Next period';
  static const String historyEmptyState = 'No drinks logged in this period';

  // Prefix — append the below-goal-day count summary, e.g.
  // '${SemanticsLabels.historyHydrationChartPrefix}2 of 7 days below goal'.
  static const String historyHydrationChartPrefix = 'Hydration per day chart. ';
  static const String historyDrinksChartPrefix = 'Drinks per day chart. ';
  static const String historyAlcoholicDrinksChartPrefix =
      'Alcoholic drinks per day chart. ';
  static const String historyMaxBacChartPrefix =
      'Maximum estimated BAC per day chart — this is an estimate only. ';
  static const String historySessionSummaryCard = 'Party session summary';
  static const String historyDayEntryList = 'Drinks logged this day';
  static const String historyDayEmptyState = 'No drinks logged this day';

  // ---------------------------------------------------------------------------
  // Navigation & global chrome
  // ---------------------------------------------------------------------------

  static const String settingsButton = 'Open settings';
  static const String todayTab = 'Today';
  static const String partyTab = 'Party';
  static const String historyTab = 'History';

  // ---------------------------------------------------------------------------
  // Drink icon
  // ---------------------------------------------------------------------------

  // TintedIcon uses this prefix + preset name when no explicit label is given.
  static const String drinkIconPrefix = 'Drink icon: ';
}
