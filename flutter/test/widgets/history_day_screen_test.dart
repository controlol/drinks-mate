// Widget tests for HistoryDayScreen (F4/S3 day drill-down, issue #26; edit/
// delete added for #67).
//
// Coverage:
//  1. Entry list renders in the order the (fake) provider supplies —
//     name/volume/time text per entry.
//  2. Empty state ("No drinks logged this day") appears when there are no
//     entries for the day, and the entry-list Semantics container does not.
//  3. Session summary card: duration / alcohol volume / peak BAC text, one
//     card per SessionDaySummary, and the peak-BAC line is omitted when
//     peakBacGPerL is null (incomplete profile).
//  4. Hydration header total excludes alcoholic entries (data-model.md
//     §BeverageType: disjoint flows) and shows the daily goal alongside it.
//  5. Edit/delete affordances (#67): edit button opens the edit sheet,
//     delete button shows a confirmation dialog whose confirm calls
//     deleteDrinkEntry with the entry id, and a Party-Session-attached
//     alcoholic entry (partySessionId set) has neither — mirroring S6's
//     read-only rule (design/user-experience.md §S3/§S6).
//  8. Expand-on-tap (issue #105, design/user-experience.md §S3 "The day's
//     Party Session summary is tappable, and expands in place"): the History
//     day drill-down passes `expandable: true`, so tapping a card reveals
//     Started/Ended time, "Total consumed alcohol in grams", and a
//     SessionLifetimeBacChart, IN THAT VERTICAL ORDER (asserted via
//     getTopLeft().dy, not just presence — a reorder should fail this) —
//     issue #122 removed the per-meal list from this card entirely, so this
//     also asserts meal text's ABSENCE even when `summary.meals` is
//     non-empty; tapping again collapses back to exactly the original field
//     set. The expand/collapse icon (expand_more/expand_less) flips with
//     state.
//  9. The multi-day acceptance criterion at the widget level: two
//     SessionDaySummary fixtures for the "same" session (identical id/
//     startedAt/endedAt/lifetimeBacChart) but different day-clipped grams —
//     expanding either card shows identical Started/Ended text and a chart
//     on both, but its own day-specific grams (meals are no longer
//     rendered on this card at all — see point 8).
//  10. issue #122: the "Day N of M" multi-day pill and "View full session"
//      button, as wired through this screen's real call site
//      (`sessionMultiDayPosition`/`Navigator.push`) — unit-level coverage of
//      the pill's/button's own rendering rules lives in
//      session_summary_card_test.dart; this file only checks the two real
//      production wirings flow through correctly end-to-end.
//  11. Swipe-to-change-day (#128, design/user-experience.md §S3 "Swipe to
//      change day"): a decisive left/right swipe (past the velocity OR
//      distance commit threshold) navigates to the next/previous day —
//      AppBar title and the day's content (entries/session summaries) both
//      update; a swipe that clears neither threshold is a no-op; swiping
//      forward past "today" or backward past historyEarliestDayBoundProvider
//      is blocked (no day change); a dataless adjacent day still renders the
//      empty state rather than being skipped; and a multi-day Party Session
//      summary card shows the correct per-day "Day N of M" pill/grams on
//      each day as the user swipes between them.
//
// Provider override pattern mirrors history_screen_test.dart: the two #26
// day-drilldown family providers (historyDayEntriesProvider,
// historyDaySessionSummariesProvider) are overridden directly with
// caller-supplied fake data. Edit/delete tests additionally override
// drinksRepositoryProvider with a _FakeRepo (pattern mirrors
// today_drinks_screen_test.dart's _FakeRepo) — no real DB needed. Point 10's
// navigation test additionally overrides the handful of providers the
// pushed PartySessionLogScreen itself reads (activePartySessionProvider,
// partySessionEntriesProvider, partySessionMealsProvider,
// partySessionSummaryProvider, nowTickerProvider) — unconditionally, in
// every test in this file, since they cost nothing when unused (lazy
// Riverpod providers) and keep _buildScreen a single shared helper.
//
// Point 11's tests need genuinely DIFFERENT data per day (to prove a swipe
// actually navigated), unlike every other test above (which ignore the
// family `key` and return the same fixture regardless of which day is
// requested) — those tests pass `entriesByKey`/`summariesByKey` maps keyed
// by `HistoryDayKey` instead of the flat `entries`/`summaries` lists.
// IMPORTANT: `core`'s `pagedDayWindow` (which the screen calls on every
// swipe) always constructs its start/end via the non-UTC `DateTime(...)`
// constructor, regardless of the "now" instant's own UTC-ness — so the
// adjacent-day keys below (`_dayBeforeKey`/`_dayAfterKey`) are built with
// `DateTime(...)`, NOT `DateTime.utc(...)` like `_dayStart`/`_dayEnd`
// themselves, since Dart's `DateTime.==` (and therefore this record-typed
// map's key lookup) compares the `isUtc` flag as well as the instant.

import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/bac_chart_series.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/models/meal.dart';
import 'package:drinks_mate/src/models/optional.dart';
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/session_day_summary.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/history_day_screen.dart';
import 'package:drinks_mate/src/screens/party_session_log_screen.dart';
import 'package:drinks_mate/src/services/format_service.dart';
import 'package:drinks_mate/src/widgets/session_lifetime_bac_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Fake repository — records delete calls; never touches the real DB.
// ---------------------------------------------------------------------------

class _FakeRepo extends DrinksRepository {
  _FakeRepo() : super(AppDatabase(NativeDatabase.memory()));

  final List<String> deletedIds = [];
  final List<
      ({
        String id,
        int? volumeMl,
        String? name,
        double? abvPercent,
        Optional<int?> priceMinor,
        Optional<String?> currency,
        DateTime? consumedAt,
      })> updateDrinkEntryCalls = [];

  @override
  Future<void> deleteDrinkEntry(String id) async {
    deletedIds.add(id);
  }

  @override
  Future<void> updateDrinkEntry({
    required String id,
    int? volumeMl,
    DateTime? consumedAt,
    String? name,
    double? abvPercent,
    Optional<int?> priceMinor = const Optional.absent(),
    Optional<String?> currency = const Optional.absent(),
  }) async {
    updateDrinkEntryCalls.add((
      id: id,
      volumeMl: volumeMl,
      name: name,
      abvPercent: abvPercent,
      priceMinor: priceMinor,
      currency: currency,
      consumedAt: consumedAt,
    ));
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _dayStart = DateTime.utc(2026, 6, 22, 5, 0);
final _dayEnd = DateTime.utc(2026, 6, 23, 5, 0);
final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

// ---------------------------------------------------------------------------
// Section 11 (swipe-to-change-day) HistoryDayKey fixtures — see the
// IMPORTANT note in the file-level comment above re: DateTime(...) vs
// DateTime.utc(...) construction.
// ---------------------------------------------------------------------------

final HistoryDayKey _dayKey = (dayStart: _dayStart, dayEnd: _dayEnd);
final HistoryDayKey _dayBeforeKey = (
  dayStart: DateTime(2026, 6, 21, 5, 0),
  dayEnd: DateTime(2026, 6, 22, 5, 0),
);
final HistoryDayKey _dayAfterKey = (
  dayStart: DateTime(2026, 6, 23, 5, 0),
  dayEnd: DateTime(2026, 6, 24, 5, 0),
);

UserPreferences _makePrefs({int dailyGoalMl = 2000}) {
  return UserPreferences(
    id: kUserPreferencesId,
    username: 'tester',
    dailyGoalMl: dailyGoalMl,
    dayBoundaryHour: 5,
    units: 'metric',
    currency: 'EUR',
    reminderEnabled: false,
    reminderStartHour: 8,
    reminderEndHour: 22,
    reminderIntervalMin: 90,
    inactivityReminderEnabled: false,
    weeklySummaryEnabled: false,
    bacOnLockScreenEnabled: false,
    approachingCapNotifEnabled: false,
    soberEstimateNotifEnabled: false,
    alcoholicPresetsAlwaysVisible: true,
    installedAt: _epoch,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

DrinkEntry _entry({
  required String id,
  required BeverageType beverageType,
  required int volumeMl,
  required DateTime consumedAt,
  String? name,
  String? partySessionId,
  double? abvPercent,
}) {
  return DrinkEntry(
    id: id,
    name: name,
    beverageType: beverageType,
    volumeMl: volumeMl,
    partySessionId: partySessionId,
    abvPercent: abvPercent,
    consumedAt: consumedAt,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

PartySession _session({String id = 's1', DateTime? endedAt}) {
  return PartySession(
    id: id,
    startedAt: _dayStart,
    endedAt: endedAt,
    useSessionPrices: false,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

Meal _meal({
  required String id,
  required String partySessionId,
  required DateTime eatenAt,
  MealSize size = MealSize.medium,
}) {
  return Meal(
    id: id,
    partySessionId: partySessionId,
    size: size,
    eatenAt: eatenAt,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

/// A minimal, deterministic [BacChartSeries] fixture — issue #105's expand
/// card only needs to assert a [SessionLifetimeBacChart] renders, not poke
/// inside fl_chart internals (per this task's brief).
BacChartSeries _chartSeries({DateTime? axisStart, DateTime? axisEnd}) {
  final start = axisStart ?? _dayStart;
  final end = axisEnd ?? _dayStart.add(const Duration(hours: 1));
  return BacChartSeries(
    axisStart: start,
    axisEnd: end,
    actual: [
      BacChartPoint(time: start, gPerL: 0.2),
      BacChartPoint(time: end, gPerL: 0.05),
    ],
    projected: const [],
    tickInterval: const Duration(minutes: 30),
  );
}

/// Build a testable HistoryDayScreen wrapped in ProviderScope with all
/// required providers overridden.
///
/// [alwaysUse24HourFormat] drives `MediaQuery.alwaysUse24HourFormat`, which
/// is what `TimeOfDay.format(context)` actually keys off (not [Locale]) —
/// see the "Time-of-day display format" Parity Rulebook row. Mirrors
/// today_drinks_screen_test.dart's `_buildScreen` helper.
Widget _buildScreen({
  List<DrinkEntry> entries = const [],
  List<SessionDaySummary> summaries = const [],
  // Section 11 (swipe-to-change-day) only: per-day data, keyed by
  // HistoryDayKey. When null, falls back to the flat entries/summaries
  // lists above (ignoring which day is requested), matching every
  // pre-#128 test's behavior.
  Map<HistoryDayKey, List<DrinkEntry>>? entriesByKey,
  Map<HistoryDayKey, List<SessionDaySummary>>? summariesByKey,
  UserPreferences? prefs,
  bool alwaysUse24HourFormat = false,
  _FakeRepo? repo,
  DateTime? earliestBound,
  // Section 11 only: overrides the day initially shown — defaults to the
  // fixed _dayStart/_dayEnd fixture every other test in this file uses.
  DateTime? screenDayStart,
  DateTime? screenDayEnd,
}) {
  return ProviderScope(
    overrides: [
      userPreferencesProvider.overrideWith(
        (_) => Stream.value(prefs ?? _makePrefs()),
      ),
      // Deterministic, locale-independent raw-value fallback strings.
      formatServiceProvider.overrideWithValue(null),
      historyDayEntriesProvider.overrideWith(
        (ref, key) => Stream.value(
            entriesByKey != null ? (entriesByKey[key] ?? []) : entries),
      ),
      historyDaySessionSummariesProvider.overrideWith(
        (ref, key) => Future.value(
          summariesByKey != null ? (summariesByKey[key] ?? []) : summaries,
        ),
      ),
      // Overridden directly (rather than left to fall through to the real
      // AppDatabase-backed repositories it composes) so tests never touch a
      // real database — defaults to _epoch, an unconstrained backward bound.
      historyEarliestDayBoundProvider.overrideWith(
        (ref) => Future.value(earliestBound ?? _epoch),
      ),
      if (repo != null) drinksRepositoryProvider.overrideWithValue(repo),
      // Only exercised by the "View full session" navigation test (point
      // 10), which pushes a real PartySessionLogScreen — overridden
      // unconditionally here (rather than only in that one test) since
      // these are lazy Riverpod providers with no cost when never read, and
      // it keeps every test sharing one _buildScreen helper.
      activePartySessionProvider.overrideWith((_) => Stream.value(null)),
      partySessionEntriesProvider.overrideWith(
        (ref, id) => Stream.value(const <DrinkEntry>[]),
      ),
      partySessionMealsProvider.overrideWith(
        (ref, id) => Stream.value(const <Meal>[]),
      ),
      partySessionSummaryProvider.overrideWith(
        (ref, id) async => summaries.firstWhere((s) => s.session.id == id),
      ),
      nowTickerProvider.overrideWith((_) => Stream.value(DateTime.now())),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(alwaysUse24HourFormat: alwaysUse24HourFormat),
        child: child!,
      ),
      home: HistoryDayScreen(
        dayStart: screenDayStart ?? _dayStart,
        dayEnd: screenDayEnd ?? _dayEnd,
      ),
    ),
  );
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Entry list rendering
  // -------------------------------------------------------------------------

  testWidgets('renders one tile per entry with name, volume, and time text', (
    tester,
  ) async {
    final entries = [
      _entry(
        id: 'e1',
        beverageType: BeverageType.beer,
        volumeMl: 330,
        consumedAt: DateTime.utc(2026, 6, 22, 20, 30),
        name: 'Lager',
      ),
      _entry(
        id: 'e2',
        beverageType: BeverageType.water,
        volumeMl: 250,
        consumedAt: DateTime.utc(2026, 6, 22, 8, 0),
        name: 'Water',
      ),
    ];

    await tester.pumpWidget(_buildScreen(entries: entries));
    await tester.pump();
    await tester.pump();

    expect(find.text('Lager'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    // Times shown in local time — entries are UTC here and the test
    // environment is UTC by default, so 20:30/08:00 local == UTC. The
    // default MediaQuery in this harness is 12h (alwaysUse24HourFormat:
    // false), so TimeOfDay.format(context) renders AM/PM strings, not
    // "HH:mm" — Source: Parity Rulebook "Time-of-day display format"
    // (issue #46). Match the full subtitle text (not a bare "330 ml"/
    // "250 ml" substring), since the hydration header above also renders a
    // bare volume value that can coincidentally match one of these.
    expect(find.text('330 ml · 8:30 PM'), findsOneWidget);
    expect(find.text('250 ml · 8:00 AM'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  // -------------------------------------------------------------------------
  // 1a. Alcoholic entry's row subtitle includes its ABV (EntryRow — shared
  //     across S6/S3/S9, entry_row.dart)
  // -------------------------------------------------------------------------

  testWidgets('alcoholic entry row subtitle includes "% ABV"', (tester) async {
    final entries = [
      _entry(
        id: 'e1',
        beverageType: BeverageType.beer,
        volumeMl: 330,
        consumedAt: DateTime.utc(2026, 6, 22, 20, 30),
        name: 'Lager',
        abvPercent: 5.0,
      ),
    ];

    await tester.pumpWidget(_buildScreen(entries: entries));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('5.0% ABV'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 1b. Entry time label honours the device's 12h/24h preference
  //     (Parity Rulebook: "Time-of-day display format", issue #46) — this
  //     was the second of the two call sites fixed alongside S6.
  // -------------------------------------------------------------------------

  testWidgets(
    'entry time renders 12h AM/PM when alwaysUse24HourFormat=false',
    (tester) async {
      final entries = [
        _entry(
          id: 'e1',
          beverageType: BeverageType.water,
          volumeMl: 250,
          consumedAt: DateTime.utc(2026, 6, 22, 9, 30),
          name: 'Water',
        ),
      ];

      await tester.pumpWidget(
        _buildScreen(entries: entries, alwaysUse24HourFormat: false),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('9:30 AM'), findsWidgets);
    },
  );

  testWidgets(
    'entry time renders 24h when alwaysUse24HourFormat=true',
    (tester) async {
      final entries = [
        _entry(
          id: 'e1',
          beverageType: BeverageType.water,
          volumeMl: 250,
          consumedAt: DateTime.utc(2026, 6, 22, 9, 30),
          name: 'Water',
        ),
      ];

      await tester.pumpWidget(
        _buildScreen(entries: entries, alwaysUse24HourFormat: true),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('09:30'), findsWidgets);
    },
  );

  testWidgets(
      'entry order follows the provider (newest-first, per '
      'watchDayEntries\' contract) rather than being re-sorted by the screen', (
    tester,
  ) async {
    final entries = [
      _entry(
        id: 'newest',
        beverageType: BeverageType.beer,
        volumeMl: 330,
        consumedAt: DateTime.utc(2026, 6, 22, 20, 0),
        name: 'Newest',
      ),
      _entry(
        id: 'oldest',
        beverageType: BeverageType.water,
        volumeMl: 250,
        consumedAt: DateTime.utc(2026, 6, 22, 8, 0),
        name: 'Oldest',
      ),
    ];

    await tester.pumpWidget(_buildScreen(entries: entries));
    await tester.pump();
    await tester.pump();

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((tiles[0].title as Text).data, 'Newest');
    expect((tiles[1].title as Text).data, 'Oldest');
  });

  // -------------------------------------------------------------------------
  // 2. Empty state
  // -------------------------------------------------------------------------

  testWidgets(
    'shows the empty state and no ListTiles when there are no entries',
    (tester) async {
      await tester.pumpWidget(_buildScreen(entries: const []));
      await tester.pump();
      await tester.pump();

      expect(find.text('No drinks logged this day'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    },
  );

  testWidgets('does NOT show the empty state when at least one entry exists', (
    tester,
  ) async {
    final entries = [
      _entry(
        id: 'e1',
        beverageType: BeverageType.water,
        volumeMl: 300,
        consumedAt: DateTime.utc(2026, 6, 22, 9, 0),
        name: 'Water',
      ),
    ];

    await tester.pumpWidget(_buildScreen(entries: entries));
    await tester.pump();
    await tester.pump();

    expect(find.text('No drinks logged this day'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 3. Session summary card
  // -------------------------------------------------------------------------

  testWidgets(
    'session summary card shows duration, alcoholic drinks, meals logged, '
    'and peak BAC',
    (tester) async {
      final summary = SessionDaySummary(
        session: _session(),
        duration: const Duration(hours: 3, minutes: 15),
        totalAlcoholicDrinks: 3,
        mealsLoggedCount: 1,
        peakBacGPerL: 0.234,
      );

      await tester.pumpWidget(_buildScreen(summaries: [summary]));
      await tester.pump();
      await tester.pump();

      expect(find.text('Party session'), findsOneWidget);
      expect(find.text('Duration: 3h 15m'), findsOneWidget);
      expect(find.text('Alcoholic drinks: 3'), findsOneWidget);
      expect(find.text('Meals logged: 1'), findsOneWidget);
      expect(
        find.text('Peak estimated BAC: 0.23 g/L (≈ 5.08 mmol/L) — estimate'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
      'peak BAC line is omitted when peakBacGPerL is null (incomplete '
      'profile), but duration/drinks/meals still show', (tester) async {
    final summary = SessionDaySummary(
      session: _session(),
      duration: const Duration(hours: 1),
      totalAlcoholicDrinks: 2,
      mealsLoggedCount: 0,
    );

    await tester.pumpWidget(_buildScreen(summaries: [summary]));
    await tester.pump();
    await tester.pump();

    expect(find.text('Duration: 1h 0m'), findsOneWidget);
    expect(find.text('Alcoholic drinks: 2'), findsOneWidget);
    expect(find.text('Meals logged: 0'), findsOneWidget);
    expect(find.textContaining('Peak estimated BAC'), findsNothing);
  });

  testWidgets(
    'renders one summary card per session (multiple sessions overlapping '
    'the same day)',
    (tester) async {
      final summaries = [
        SessionDaySummary(
          session: _session(id: 's1'),
          duration: const Duration(hours: 1),
          totalAlcoholicDrinks: 2,
          mealsLoggedCount: 0,
          peakBacGPerL: 0.1,
        ),
        SessionDaySummary(
          session: _session(id: 's2'),
          duration: const Duration(hours: 2),
          totalAlcoholicDrinks: 4,
          mealsLoggedCount: 1,
          peakBacGPerL: 0.2,
        ),
      ];

      await tester.pumpWidget(_buildScreen(summaries: summaries));
      await tester.pump();
      await tester.pump();

      expect(find.text('Party session'), findsNWidgets(2));
      expect(find.text('Duration: 1h 0m'), findsOneWidget);
      expect(find.text('Duration: 2h 0m'), findsOneWidget);
    },
  );

  testWidgets('no session summary card when there are no sessions that day', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pump();
    await tester.pump();

    expect(find.text('Party session'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 4. Hydration header — excludes alcoholic entries, shows the goal
  // -------------------------------------------------------------------------

  testWidgets(
    'hydration header sums only non-alcoholic entries and shows the goal',
    (tester) async {
      final entries = [
        _entry(
          id: 'water',
          beverageType: BeverageType.water,
          volumeMl: 300,
          consumedAt: DateTime.utc(2026, 6, 22, 8, 0),
        ),
        _entry(
          id: 'tea',
          beverageType: BeverageType.tea,
          volumeMl: 200,
          consumedAt: DateTime.utc(2026, 6, 22, 9, 0),
        ),
        _entry(
          id: 'beer',
          beverageType: BeverageType.beer,
          volumeMl: 330,
          consumedAt: DateTime.utc(2026, 6, 22, 20, 0),
          partySessionId: 's1',
        ),
      ];

      await tester.pumpWidget(
        _buildScreen(entries: entries, prefs: _makePrefs(dailyGoalMl: 2500)),
      );
      await tester.pump();
      await tester.pump();

      // 300 + 200 = 500 ml hydration; the 330 ml beer must be excluded
      // (data-model.md §BeverageType: "the two flows are strictly disjoint").
      expect(find.text('500 ml'), findsOneWidget);
      expect(find.text('/ 2500 ml hydration goal'), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // 5. Edit/delete affordances (#67)
  // -------------------------------------------------------------------------

  testWidgets('tapping a row opens the edit sheet', (tester) async {
    final entries = [
      _entry(
        id: 'e1',
        beverageType: BeverageType.water,
        volumeMl: 300,
        consumedAt: DateTime.utc(2026, 6, 22, 9, 0),
        name: 'Edit Me',
      ),
    ];

    await tester.pumpWidget(
      _buildScreen(entries: entries, repo: _FakeRepo()),
    );
    await tester.pump();
    await tester.pump();

    // There is no separate Edit button — tapping the row itself opens the
    // edit sheet (EntryRow.onTap).
    expect(find.byTooltip('Edit'), findsNothing);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    // Source: entry_edit_sheet.dart _EntryEditSheetState.build.
    expect(find.text('Edit drink'), findsOneWidget);
  });

  testWidgets('tapping delete button shows a confirmation dialog',
      (tester) async {
    final entries = [
      _entry(
        id: 'e1',
        beverageType: BeverageType.water,
        volumeMl: 300,
        consumedAt: DateTime.utc(2026, 6, 22, 9, 0),
        name: 'Delete Me',
      ),
    ];

    await tester.pumpWidget(
      _buildScreen(entries: entries, repo: _FakeRepo()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Delete'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete entry?'), findsOneWidget);
  });

  testWidgets(
      'confirming the delete dialog calls deleteDrinkEntry with the entry id',
      (tester) async {
    final repo = _FakeRepo();
    const entryId = 'e-to-delete';
    final entries = [
      _entry(
        id: entryId,
        beverageType: BeverageType.water,
        volumeMl: 300,
        consumedAt: DateTime.utc(2026, 6, 22, 9, 0),
        name: 'Deletable Drink',
      ),
    ];

    await tester.pumpWidget(_buildScreen(entries: entries, repo: repo));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete entry?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      repo.deletedIds,
      contains(entryId),
      reason:
          'deleteDrinkEntry must be called with the entry id after the user '
          'confirms deletion (S3 spec: soft-delete, mirroring S6)',
    );
  });

  // -------------------------------------------------------------------------
  // 5b. Session-attached alcoholic entries are read-only (no Edit/Delete)
  //
  // Source: design/user-experience.md §S3: an alcoholic drink attached to a
  // Party Session (partySessionId set) is read-only in the day drill-down —
  // edit or delete it from S9 Party Session Log instead. A normal entry and
  // an orphan alcoholic entry (isAlcoholic but no partySessionId) must still
  // show both actions — the rule keys off partySessionId, not off
  // beverageType.isAlcoholic alone. Mirrors
  // today_drinks_screen_test.dart's equivalent S6 case.
  // -------------------------------------------------------------------------

  testWidgets(
    'session-attached alcoholic entry is not tappable and has no Delete '
    'button, while a normal entry and an orphan alcoholic entry in the same '
    'day still are',
    (tester) async {
      final sessionAttached = _entry(
        id: 'e-session',
        beverageType: BeverageType.beer, // isAlcoholic == true
        volumeMl: 330,
        consumedAt: DateTime.utc(2026, 6, 22, 20, 0),
        name: 'Session Beer',
        partySessionId: 'test-session-1',
      );

      final normal = _entry(
        id: 'e-normal',
        beverageType: BeverageType.water,
        volumeMl: 300,
        consumedAt: DateTime.utc(2026, 6, 22, 9, 0),
        name: 'Plain Water',
      );

      // Orphan alcoholic entry — alcoholic but NOT session-attached
      // (partySessionId == null); must remain fully editable/deletable.
      final orphanAlcoholic = _entry(
        id: 'e-orphan',
        beverageType: BeverageType.beer,
        volumeMl: 330,
        consumedAt: DateTime.utc(2026, 6, 22, 18, 0),
        name: 'Orphan Beer',
      );

      await tester.pumpWidget(
        _buildScreen(
          entries: [sessionAttached, normal, orphanAlcoholic],
          repo: _FakeRepo(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Session Beer'), findsOneWidget);
      expect(find.text('Plain Water'), findsOneWidget);
      expect(find.text('Orphan Beer'), findsOneWidget);

      // Exactly two Delete buttons — one each for the normal entry and the
      // orphan alcoholic entry; none for the session-attached alcoholic
      // entry, which renders read-only.
      expect(find.byTooltip('Delete'), findsNWidgets(2));

      // The session-attached row has no tap target (read-only); the other
      // two do (tapping opens the edit sheet directly).
      ListTile tileFor(String title) =>
          tester.widget<ListTile>(find.widgetWithText(ListTile, title));
      expect(tileFor('Session Beer').onTap, isNull);
      expect(tileFor('Plain Water').onTap, isNotNull);
      expect(tileFor('Orphan Beer').onTap, isNotNull);
    },
  );

  // -------------------------------------------------------------------------
  // 6. Name, ABV, and price fields — S3 is the only screen that additionally
  //    exposes name (design/user-experience.md §S3), unlike S6/S9.
  // -------------------------------------------------------------------------

  testWidgets(
    'edit sheet shows name+volume+price (3 fields, no ABV) for a '
    'non-alcoholic entry',
    (tester) async {
      final repo = _FakeRepo();
      final entries = [
        _entry(
          id: 'e1',
          beverageType: BeverageType.water,
          volumeMl: 300,
          consumedAt: DateTime.utc(2026, 6, 22, 9, 0),
          name: 'Water',
        ),
      ];

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen(entries: entries, repo: repo));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('ABV (%)'), findsNothing);
    },
  );

  testWidgets(
    'edit sheet shows name+volume+ABV+price (4 fields) for an orphan '
    'alcoholic entry, pre-filled from the entry; saving calls '
    'updateDrinkEntry with the edited values, including name',
    (tester) async {
      final repo = _FakeRepo();
      final entry = DrinkEntry(
        id: 'e-beer',
        name: 'Original Beer',
        beverageType: BeverageType.beer,
        volumeMl: 330,
        abvPercent: 5.0,
        priceMinor: 450,
        currency: 'EUR',
        consumedAt: DateTime.utc(2026, 6, 22, 20, 0),
        createdAt: _epoch,
        updatedAt: _epoch,
      );

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen(entries: [entry], repo: repo));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(4));
      // Declaration order in EntryEditSheet.build: name, volume, abv, price.
      expect(tester.widget<TextField>(textFields.at(0)).controller!.text,
          'Original Beer');
      expect(
          tester.widget<TextField>(textFields.at(1)).controller!.text, '330');
      expect(
          tester.widget<TextField>(textFields.at(2)).controller!.text, '5.0');
      expect(
          tester.widget<TextField>(textFields.at(3)).controller!.text, '4.50');

      // The time button must show the date, not just the time-of-day — S3
      // (unlike S6) lets an entry move to a different day entirely, since
      // it's the historical-correction surface (EntryEditSheet's
      // DateEditPicker.free()).
      expect(find.textContaining('2026-06-22'), findsOneWidget);

      await tester.enterText(textFields.at(0), 'Edited Beer');
      await tester.enterText(textFields.at(1), '500');
      await tester.enterText(textFields.at(2), '8.0');
      await tester.enterText(textFields.at(3), '6.00');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repo.updateDrinkEntryCalls, hasLength(1));
      final call = repo.updateDrinkEntryCalls.single;
      expect(call.id, 'e-beer');
      expect(call.name, 'Edited Beer');
      expect(call.volumeMl, 500);
      expect(call.abvPercent, 8.0);
      expect(call.priceMinor, const Optional.value(600));
      expect(call.currency, const Optional.value('EUR'));
    },
  );

  // -------------------------------------------------------------------------
  // 7. Touch-gating regression (PR #91 fix): a stored abvPercent of 0 or a
  //    null name are legal stored values (accepted at preset-creation/log
  //    time — engineering/decisions/design-system.md's ABV rule only rejects
  //    null/negative; data-model.md's username/name rule only rejects an
  //    absent name at creation) but previously could never round-trip
  //    through this sheet again for ANY field, since ABV/name were always
  //    re-validated/resent even when untouched, and this sheet's own
  //    stricter ">0"/"non-empty" save-validation rejected them.
  // -------------------------------------------------------------------------

  testWidgets(
    'editing only volume on an alcoholic entry with stored abvPercent 0 '
    'succeeds and does not resend abvPercent (untouched field sent as '
    'null, not re-validated/resent)',
    (tester) async {
      final repo = _FakeRepo();
      final entry = _entry(
        id: 'e-zero-abv',
        beverageType: BeverageType.beer,
        volumeMl: 330,
        consumedAt: DateTime.utc(2026, 6, 22, 20, 0),
        name: 'Zero-ABV Beer',
        abvPercent: 0,
      );

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen(entries: [entry], repo: repo));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Declaration order in EntryEditSheet.build: name, volume, abv, price.
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(4));
      expect(
        tester.widget<TextField>(textFields.at(2)).controller!.text,
        '0.0',
      );

      // Touch only volume — ABV/name are left exactly as pre-filled.
      await tester.enterText(textFields.at(1), '500');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repo.updateDrinkEntryCalls, hasLength(1));
      final call = repo.updateDrinkEntryCalls.single;
      expect(call.id, 'e-zero-abv');
      expect(call.volumeMl, 500);
      // Untouched — must be sent as null ("no change"), not resent as 0
      // (which would pass) or rejected by the sheet's own ">0" validation
      // (the bug this test guards against: previously this entry could
      // never be saved through this sheet at all).
      expect(call.abvPercent, isNull);
      expect(call.name, isNull);
    },
  );

  testWidgets(
    'editing only volume on an entry with a null name (S3, showName: '
    'true) succeeds and does not resend name (untouched field sent as '
    'null, not re-validated/resent as empty string)',
    (tester) async {
      final repo = _FakeRepo();
      final entry = _entry(
        id: 'e-no-name',
        beverageType: BeverageType.water,
        volumeMl: 250,
        consumedAt: DateTime.utc(2026, 6, 22, 9, 0),
      );

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen(entries: [entry], repo: repo));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Non-alcoholic: 3 fields (name, volume, price) — no ABV.
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));
      expect(tester.widget<TextField>(textFields.at(0)).controller!.text, '');

      // Touch only volume — name is left exactly as pre-filled (empty).
      await tester.enterText(textFields.at(1), '400');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repo.updateDrinkEntryCalls, hasLength(1));
      final call = repo.updateDrinkEntryCalls.single;
      expect(call.id, 'e-no-name');
      expect(call.volumeMl, 400);
      // Untouched — must be sent as null ("no change"), not resent as ''
      // (which would be rejected by the sheet's own "Name is required"
      // validation — the bug this test guards against).
      expect(call.name, isNull);
    },
  );

  // -------------------------------------------------------------------------
  // 8. Expand-on-tap (issue #105, design/user-experience.md §S3 "The day's
  //    Party Session summary is tappable, and expands in place").
  //    HistoryDayScreen passes `expandable: true` to SessionSummaryCard.
  // -------------------------------------------------------------------------

  testWidgets(
    'tapping the card reveals Started/Ended time, total consumed alcohol in '
    'grams, and a BAC chart (NOT a meals list — issue #122 removed it from '
    'this card entirely, even though summary.meals is non-empty here); '
    'tapping again collapses back to exactly the original fields',
    (tester) async {
      // asOf 2h after the meal, so relativeTimeAgo deterministically reads
      // "2 h ago" rather than depending on DateTime.now() — kept even though
      // no meal text renders on this card, since asOf/meals are still part
      // of the SessionDaySummary this screen receives.
      final asOf = _dayStart.add(const Duration(hours: 5));
      final summary = SessionDaySummary(
        session: _session(
          id: 's1',
          endedAt: _dayStart.add(const Duration(hours: 3, minutes: 15)),
        ),
        duration: const Duration(hours: 3, minutes: 15),
        totalAlcoholicDrinks: 3,
        mealsLoggedCount: 1,
        peakBacGPerL: 0.234,
        totalAlcoholGrams: 42.7,
        meals: [
          _meal(
            id: 'm1',
            partySessionId: 's1',
            eatenAt: asOf.subtract(const Duration(hours: 2)),
            size: MealSize.medium,
          ),
        ],
        lifetimeBacChart: _chartSeries(),
        asOf: asOf,
      );

      await tester.pumpWidget(_buildScreen(summaries: [summary]));
      await tester.pump();
      await tester.pump();

      // Collapsed: only the fields already covered by section 3 above.
      expect(find.text('Duration: 3h 15m'), findsOneWidget);
      expect(find.textContaining('Started:'), findsNothing);
      expect(find.textContaining('Ended:'), findsNothing);
      expect(find.textContaining('Total consumed alcohol'), findsNothing);
      expect(find.textContaining('Medium meal'), findsNothing);
      expect(find.byType(SessionLifetimeBacChart), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      // Expanded: Started/Ended after Duration, grams after peak BAC, then
      // the chart — no meals list at any point (issue #122).
      expect(find.text('Started: 5:00 AM'), findsOneWidget);
      expect(find.text('Ended: 8:15 AM'), findsOneWidget);
      expect(find.text('Total consumed alcohol: 43 g'), findsOneWidget);
      expect(find.byType(SessionLifetimeBacChart), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
      // Regression guard: the per-meal list block was removed entirely, even
      // though this summary's `meals` list is non-empty.
      expect(find.textContaining('Medium meal'), findsNothing);

      // Vertical order matters — the spec pins it explicitly ("IN THIS
      // ORDER" per the issue brief / design/user-experience.md §S3). A
      // presence-only check would pass even if a refactor silently
      // reordered these fields, so assert relative Y position too.
      double dy(Finder f) => tester.getTopLeft(f).dy;
      expect(
        dy(find.text('Started: 5:00 AM')),
        lessThan(dy(find.text('Alcoholic drinks: 3'))),
        reason: 'Started/Ended come right after Duration, before the '
            'always-present drinks/meals-count lines',
      );
      expect(
        dy(find.text('Started: 5:00 AM')),
        lessThan(dy(find.text('Ended: 8:15 AM'))),
      );
      expect(
        dy(find.textContaining('Peak estimated BAC')),
        lessThan(dy(find.text('Total consumed alcohol: 43 g'))),
        reason: 'grams line comes after the peak-BAC line',
      );
      expect(
        dy(find.text('Total consumed alcohol: 43 g')),
        lessThan(dy(find.byType(SessionLifetimeBacChart))),
        reason: 'the chart is rendered last, at the bottom, right after the '
            'grams line',
      );

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pump();

      // Collapses back to exactly the original (pre-expand) field set.
      expect(find.text('Duration: 3h 15m'), findsOneWidget);
      expect(find.textContaining('Started:'), findsNothing);
      expect(find.textContaining('Ended:'), findsNothing);
      expect(find.textContaining('Total consumed alcohol'), findsNothing);
      expect(find.textContaining('Medium meal'), findsNothing);
      expect(find.byType(SessionLifetimeBacChart), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);
    },
  );

  testWidgets(
    'a still-active session (endedAt == null) shows "Ended: Ongoing" when '
    'expanded',
    (tester) async {
      final summary = SessionDaySummary(
        session: _session(id: 's1'), // endedAt: null
        duration: const Duration(hours: 1),
        totalAlcoholicDrinks: 1,
        mealsLoggedCount: 0,
        peakBacGPerL: 0.1,
        lifetimeBacChart: _chartSeries(),
        asOf: _dayStart,
      );

      await tester.pumpWidget(_buildScreen(summaries: [summary]));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      expect(find.text('Started: 5:00 AM'), findsOneWidget);
      expect(find.text('Ended: Ongoing'), findsOneWidget);
    },
  );

  testWidgets(
    'no meals logged that day -> grams/chart still show (there is no meals '
    'list on this card at all, with or without meals — see section 8)',
    (tester) async {
      final summary = SessionDaySummary(
        session: _session(
          id: 's1',
          endedAt: _dayStart.add(const Duration(hours: 1)),
        ),
        duration: const Duration(hours: 1),
        totalAlcoholicDrinks: 1,
        mealsLoggedCount: 0,
        peakBacGPerL: 0.1,
        totalAlcoholGrams: 12,
        meals: const [],
        lifetimeBacChart: _chartSeries(),
        asOf: _dayStart,
      );

      await tester.pumpWidget(_buildScreen(summaries: [summary]));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      expect(find.text('Total consumed alcohol: 12 g'), findsOneWidget);
      expect(find.byType(SessionLifetimeBacChart), findsOneWidget);
    },
  );

  testWidgets(
    'peakBacGPerL null (incomplete profile) -> lifetimeBacChart is also '
    'absent when expanded, no chart widget rendered',
    (tester) async {
      final summary = SessionDaySummary(
        session: _session(
          id: 's1',
          endedAt: _dayStart.add(const Duration(hours: 1)),
        ),
        duration: const Duration(hours: 1),
        totalAlcoholicDrinks: 1,
        mealsLoggedCount: 0,
        // peakBacGPerL, lifetimeBacChart both left null/default.
        totalAlcoholGrams: 12,
        asOf: _dayStart,
      );

      await tester.pumpWidget(_buildScreen(summaries: [summary]));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      expect(find.text('Total consumed alcohol: 12 g'), findsOneWidget);
      expect(find.byType(SessionLifetimeBacChart), findsNothing);
    },
  );

  // -------------------------------------------------------------------------
  // 9. Multi-day acceptance criterion (design/user-experience.md §S3: "For a
  //    multi-day session these are identical on every day card it touches").
  // -------------------------------------------------------------------------

  testWidgets(
    'two SessionDaySummary cards for the same multi-day session show '
    'day-specific grams but identical Started/Ended text and a chart on '
    'both, once both are expanded (meals no longer render on this card at '
    'all — issue #122)',
    (tester) async {
      final session = _session(
        id: 's1',
        endedAt: _dayStart.add(const Duration(hours: 10)),
      );
      final sharedChart = _chartSeries(
        axisStart: _dayStart,
        axisEnd: _dayStart.add(const Duration(hours: 10)),
      );
      final asOf = _dayStart.add(const Duration(hours: 12));

      final day1Summary = SessionDaySummary(
        session: session,
        duration: const Duration(hours: 2),
        totalAlcoholicDrinks: 1,
        mealsLoggedCount: 1,
        peakBacGPerL: 0.1,
        totalAlcoholGrams: 10,
        meals: [
          _meal(
            id: 'm-day1',
            partySessionId: 's1',
            eatenAt: asOf.subtract(const Duration(hours: 3)),
            size: MealSize.small,
          ),
        ],
        lifetimeBacChart: sharedChart,
        asOf: asOf,
      );
      final day2Summary = SessionDaySummary(
        session: session,
        duration: const Duration(hours: 8),
        totalAlcoholicDrinks: 2,
        mealsLoggedCount: 0,
        peakBacGPerL: 0.05,
        totalAlcoholGrams: 25,
        meals: const [],
        lifetimeBacChart: sharedChart,
        asOf: asOf,
      );

      await tester.pumpWidget(
        _buildScreen(summaries: [day1Summary, day2Summary]),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Party session'), findsNWidgets(2));
      expect(find.byIcon(Icons.expand_more), findsNWidgets(2));

      // Expand both cards.
      await tester.tap(find.byIcon(Icons.expand_more).at(0));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.expand_more).at(0));
      await tester.pump();

      // Started/Ended are facts about the whole session, not day-clipped —
      // identical text on both expanded cards.
      expect(find.text('Started: 5:00 AM'), findsNWidgets(2));
      expect(find.text('Ended: 3:00 PM'), findsNWidgets(2));

      // Both cards render a chart (the shared, non-day-clipped series).
      expect(find.byType(SessionLifetimeBacChart), findsNWidgets(2));

      // Grams differ per day.
      expect(find.text('Total consumed alcohol: 10 g'), findsOneWidget);
      expect(find.text('Total consumed alcohol: 25 g'), findsOneWidget);

      // Meals no longer render on this card at all (issue #122), even
      // though day1Summary's own `meals` list is non-empty.
      expect(find.textContaining('Small meal'), findsNothing);
    },
  );

  // -------------------------------------------------------------------------
  // 10. issue #122 — "Day N of M" pill and "View full session" button, as
  //     wired through this screen's real call site. Per-rendering-rule
  //     coverage of the pill/button themselves lives in
  //     session_summary_card_test.dart; these two tests only check that
  //     HistoryDayScreen's own `sessionMultiDayPosition`/`Navigator.push`
  //     wiring actually flows through correctly end-to-end.
  // -------------------------------------------------------------------------

  testWidgets(
    'a 2-day session\'s card, viewed on its first day, shows the "Day 1 of '
    '2" pill (real sessionMultiDayPosition output flowing through the '
    'screen, not a hand-supplied multiDayPosition)',
    (tester) async {
      // Explicit endedAt (not still-active) — sessionMultiDayPosition's
      // `now` parameter is HistoryDayScreen's own uncontrollable
      // `DateTime.now()` call site, so an ended session keeps this test's
      // day-window count deterministic regardless of wall-clock time.
      final session = _session(
        id: 's-multiday',
        endedAt: _dayStart.add(const Duration(days: 1, hours: 3)),
      );
      final summary = SessionDaySummary(
        session: session,
        duration: const Duration(hours: 3),
        totalAlcoholicDrinks: 1,
        mealsLoggedCount: 0,
        peakBacGPerL: 0.1,
      );

      await tester.pumpWidget(_buildScreen(summaries: [summary]));
      await tester.pump();
      await tester.pump();

      expect(find.text('Day 1 of 2'), findsOneWidget);
    },
  );

  testWidgets(
    'a single-day session\'s card shows no "Day N of M" pill '
    '(sessionMultiDayPosition returns null)',
    (tester) async {
      final summary = SessionDaySummary(
        session: _session(
          id: 's1',
          endedAt: _dayStart.add(const Duration(hours: 3)),
        ),
        duration: const Duration(hours: 3),
        totalAlcoholicDrinks: 1,
        mealsLoggedCount: 0,
        peakBacGPerL: 0.1,
      );

      await tester.pumpWidget(_buildScreen(summaries: [summary]));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining(RegExp(r'^Day \d+ of \d+$')), findsNothing);
    },
  );

  testWidgets(
    'tapping "View full session" (visible once expanded) navigates to '
    'PartySessionLogScreen for the tapped card\'s session id',
    (tester) async {
      final summary = SessionDaySummary(
        session: _session(
          id: 's-nav',
          endedAt: _dayStart.add(const Duration(hours: 2)),
        ),
        duration: const Duration(hours: 2),
        totalAlcoholicDrinks: 1,
        mealsLoggedCount: 0,
        peakBacGPerL: 0.1,
        totalAlcoholGrams: 10,
        lifetimeBacChart: _chartSeries(),
        asOf: _dayStart.add(const Duration(hours: 2)),
      );

      await tester.pumpWidget(_buildScreen(summaries: [summary]));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PartySessionLogScreen), findsNothing);

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      final buttonFinder =
          find.widgetWithText(OutlinedButton, 'View full session');
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.pump();

      final pushed = tester.widget<PartySessionLogScreen>(
        find.byType(PartySessionLogScreen),
      );
      expect(pushed.sessionId, 's-nav');
    },
  );

  // -------------------------------------------------------------------------
  // 11. Swipe-to-change-day (#128, design/user-experience.md §S3 "Swipe to
  //     change day")
  // -------------------------------------------------------------------------

  group('11. swipe-to-change-day (#128)', () {
    // Decisive swipes: well past both the velocity (250 px/s) and distance
    // (60 logical px) commit thresholds — 300 px over 100 ms = 3000 px/s.
    Future<void> swipeLeft(WidgetTester tester) => tester.timedDrag(
          find.byType(Scaffold),
          const Offset(-300, 0),
          const Duration(milliseconds: 100),
        );
    Future<void> swipeRight(WidgetTester tester) => tester.timedDrag(
          find.byType(Scaffold),
          const Offset(300, 0),
          const Duration(milliseconds: 100),
        );

    testWidgets(
      'a decisive left swipe navigates to the next day: AppBar title and '
      'content both update to the next day\'s data',
      (tester) async {
        final today = _entry(
          id: 'today',
          beverageType: BeverageType.water,
          volumeMl: 300,
          consumedAt: _dayStart.add(const Duration(hours: 3)),
          name: 'Today Drink',
        );
        final tomorrow = _entry(
          id: 'tomorrow',
          beverageType: BeverageType.water,
          volumeMl: 250,
          consumedAt: _dayAfterKey.dayStart.add(const Duration(hours: 3)),
          name: 'Tomorrow Drink',
        );

        await tester.pumpWidget(
          _buildScreen(
            entriesByKey: {
              _dayKey: [today],
              _dayAfterKey: [tomorrow],
            },
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Monday, Jun 22'), findsOneWidget);
        expect(find.text('Today Drink'), findsOneWidget);
        expect(find.text('Tomorrow Drink'), findsNothing);

        await swipeLeft(tester);
        await tester.pumpAndSettle();

        expect(find.text('Tuesday, Jun 23'), findsOneWidget);
        expect(find.text('Tomorrow Drink'), findsOneWidget);
        expect(find.text('Today Drink'), findsNothing);
      },
    );

    testWidgets(
      'a decisive right swipe navigates to the previous day, symmetric to '
      'the left-swipe case above',
      (tester) async {
        final today = _entry(
          id: 'today',
          beverageType: BeverageType.water,
          volumeMl: 300,
          consumedAt: _dayStart.add(const Duration(hours: 3)),
          name: 'Today Drink',
        );
        final yesterday = _entry(
          id: 'yesterday',
          beverageType: BeverageType.water,
          volumeMl: 250,
          consumedAt: _dayBeforeKey.dayStart.add(const Duration(hours: 3)),
          name: 'Yesterday Drink',
        );

        await tester.pumpWidget(
          _buildScreen(
            entriesByKey: {
              _dayKey: [today],
              _dayBeforeKey: [yesterday],
            },
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Monday, Jun 22'), findsOneWidget);
        expect(find.text('Today Drink'), findsOneWidget);

        await swipeRight(tester);
        await tester.pumpAndSettle();

        expect(find.text('Sunday, Jun 21'), findsOneWidget);
        expect(find.text('Yesterday Drink'), findsOneWidget);
        expect(find.text('Today Drink'), findsNothing);
      },
    );

    testWidgets(
      'a swipe that clears neither the velocity nor the distance commit '
      'threshold is a no-op: AppBar title and content are unchanged',
      (tester) async {
        final today = _entry(
          id: 'today',
          beverageType: BeverageType.water,
          volumeMl: 300,
          consumedAt: _dayStart.add(const Duration(hours: 3)),
          name: 'Stays Put',
        );

        await tester.pumpWidget(_buildScreen(entries: [today]));
        await tester.pump();
        await tester.pump();

        expect(find.text('Monday, Jun 22'), findsOneWidget);

        // 20 px over 500 ms = 40 px/s: both distance (< 60 px) and velocity
        // (< 250 px/s) stay under the commit thresholds.
        await tester.timedDrag(
          find.byType(Scaffold),
          const Offset(-20, 0),
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();

        expect(find.text('Monday, Jun 22'), findsOneWidget);
        expect(find.text('Stays Put'), findsOneWidget);
      },
    );

    testWidgets(
      'forward bound: cannot swipe left past "today" — a decisive left '
      'swipe from today\'s own day-window is a no-op',
      (tester) async {
        // The screen calls DateTime.now() directly for the forward bound —
        // resolve "today's" own day-window the same way (core's dayWindow)
        // so this test's fixture day IS today, and assert the exact
        // resulting title text via the same DateFormat the screen uses.
        final today = dayWindow(now: DateTime.now(), boundaryHour: 5);
        final todayLabel = DateFormat('EEEE, MMM d').format(today.$1);
        final marker = _entry(
          id: 'today-marker',
          beverageType: BeverageType.water,
          volumeMl: 300,
          consumedAt: today.$1.add(const Duration(hours: 1)),
          name: 'Today Marker',
        );

        await tester.pumpWidget(
          _buildScreen(
            entries: [marker],
            screenDayStart: today.$1,
            screenDayEnd: today.$2,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text(todayLabel), findsOneWidget);

        await swipeLeft(tester);
        await tester.pumpAndSettle();

        expect(
          find.text(todayLabel),
          findsOneWidget,
          reason: 'swiping forward past today must be blocked (no-op)',
        );
        expect(find.text('Today Marker'), findsOneWidget);
      },
    );

    testWidgets(
      'backward bound: cannot swipe right past historyEarliestDayBoundProvider '
      '— blocked exactly at the earliest allowed day',
      (tester) async {
        final marker = _entry(
          id: 'earliest-marker',
          beverageType: BeverageType.water,
          volumeMl: 300,
          consumedAt: _dayStart.add(const Duration(hours: 1)),
          name: 'Earliest Marker',
        );

        await tester.pumpWidget(
          _buildScreen(
            entries: [marker],
            // The earliest bound IS the currently-shown day — one more
            // backward step must be refused.
            earliestBound: _dayStart,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Monday, Jun 22'), findsOneWidget);

        await swipeRight(tester);
        await tester.pumpAndSettle();

        expect(
          find.text('Monday, Jun 22'),
          findsOneWidget,
          reason: 'swiping backward past the earliest bound must be blocked '
              '(no-op)',
        );
        expect(find.text('Earliest Marker'), findsOneWidget);
      },
    );

    testWidgets(
      'a dataless adjacent day still renders the empty state after '
      'swiping to it, rather than being skipped',
      (tester) async {
        final today = _entry(
          id: 'today',
          beverageType: BeverageType.water,
          volumeMl: 300,
          consumedAt: _dayStart.add(const Duration(hours: 3)),
          name: 'Only Today',
        );

        await tester.pumpWidget(
          _buildScreen(
            entriesByKey: {
              _dayKey: [today],
              // _dayAfterKey deliberately omitted -> falls back to [].
            },
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Only Today'), findsOneWidget);
        expect(find.text('No drinks logged this day'), findsNothing);

        await swipeLeft(tester);
        await tester.pumpAndSettle();

        expect(find.text('Tuesday, Jun 23'), findsOneWidget);
        expect(find.text('Only Today'), findsNothing);
        expect(find.text('No drinks logged this day'), findsOneWidget);
      },
    );

    testWidgets(
      'a multi-day Party Session summary card shows the correct per-day '
      '"Day N of M" pill and grams on each day as the user swipes between '
      'them (mirrors the existing "Day 1 of 2" pill fixture in section 10)',
      (tester) async {
        // A 2-day session spanning _dayKey and _dayAfterKey, exactly like
        // section 10's "Day 1 of 2" fixture.
        final session = _session(
          id: 's-multiday',
          endedAt: _dayStart.add(const Duration(days: 1, hours: 3)),
        );
        final day0Summary = SessionDaySummary(
          session: session,
          duration: const Duration(hours: 3),
          totalAlcoholicDrinks: 1,
          mealsLoggedCount: 0,
          peakBacGPerL: 0.1,
          totalAlcoholGrams: 10,
        );
        final dayAfterSummary = SessionDaySummary(
          session: session,
          duration: const Duration(hours: 8),
          totalAlcoholicDrinks: 2,
          mealsLoggedCount: 0,
          peakBacGPerL: 0.05,
          totalAlcoholGrams: 25,
        );

        await tester.pumpWidget(
          _buildScreen(
            summariesByKey: {
              _dayKey: [day0Summary],
              _dayAfterKey: [dayAfterSummary],
            },
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Day 1 of 2'), findsOneWidget);
        expect(find.text('Duration: 3h 0m'), findsOneWidget);

        await swipeLeft(tester);
        await tester.pumpAndSettle();

        expect(find.text('Tuesday, Jun 23'), findsOneWidget);
        expect(find.text('Day 2 of 2'), findsOneWidget);
        expect(find.text('Duration: 8h 0m'), findsOneWidget);
        expect(find.text('Day 1 of 2'), findsNothing);
      },
    );
  });
}
