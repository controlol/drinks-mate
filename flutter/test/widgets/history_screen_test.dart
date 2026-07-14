// Widget tests for F4/S3 — HistoryScreen (issue #25).
//
// Coverage:
//  1. Chart renders with known data — bar count/values match the fake
//     repository's buckets for both the hydration and drinks-per-day charts.
//  2. Empty state appears when every bucket in range is zero-valued, and does
//     NOT appear when there is data.
//  3. Range paging: tapping the back/forward chevrons re-subscribes with a
//     different range (the fake repo records rangeStart per call) and the
//     forward chevron is disabled exactly at the current/most-recent period.
//  4. Weekly/Monthly toggle switches mode and resets paging back to offset 0.
//  5. The below-goal hydration bar gets a non-BorderSide.none border (the
//     non-colour signal — Parity Rulebook: "History bar below daily goal:
//     non-colour pattern/marker in addition to colour") while an
//     at-or-above-goal bar does not.
//  6. Alcohol section (issue #26): conditional visibility driven by
//     historySessionsInRangeProvider alone (not by whether the BAC/alcoholic
//     buckets are all-zero) — including the party-only-period regression
//     case (no hydration entries, but a session in range: the alcohol
//     section must show, not the "no drinks" empty state).
//  7. Max-BAC chart: the cap HorizontalLine appears only when
//     UserPreferences.bacCapGramsPerL is set; at/above-cap bars get a
//     visible border (the non-colour signal), below-cap bars don't.
//  8. Session overlay band: both alcohol charts' rangeAnnotations carry one
//     VerticalRangeAnnotation per session in range.
//
// Provider override pattern mirrors flutter/test/widgets/today_drinks_screen_test.dart:
// a fake DrinksRepository subclass records calls without touching the DB.
// The three #26 family providers (historySessionsInRangeProvider,
// historyAlcoholicDrinksPerDayProvider, historyMaxBacPerDayProvider) are
// overridden directly with caller-supplied fake data via `_buildScreen`'s
// optional params, since they're simple family providers (no fake-repo
// subclass needed for these three).

import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/bac_daily_bucket.dart';
import 'package:drinks_mate/src/models/daily_bucket.dart';
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/history_day_screen.dart';
import 'package:drinks_mate/src/screens/history_screen.dart';
import 'package:drinks_mate/src/services/format_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repository — returns caller-configured buckets and records every
// (rangeStart, rangeEnd) it is asked to watch, so paging/mode-switch tests
// can assert on subscription behaviour without a real DB.
// ---------------------------------------------------------------------------

class _FakeRepo extends DrinksRepository {
  _FakeRepo({this.totals = const [], this.counts = const []})
      : super(AppDatabase(NativeDatabase.memory()));

  List<DailyBucket> totals;
  List<DailyBucket> counts;

  final List<DateTime> totalsRangeStarts = [];
  final List<DateTime> countsRangeStarts = [];

  @override
  Stream<List<DailyBucket>> watchDailyTotalsMl({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    int boundaryHour = 5,
    int boundaryMinute = 0,
  }) {
    totalsRangeStarts.add(rangeStart);
    return Stream.value(totals);
  }

  @override
  Stream<List<DailyBucket>> watchDrinksPerDay({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    int boundaryHour = 5,
    int boundaryMinute = 0,
  }) {
    countsRangeStarts.add(rangeStart);
    return Stream.value(counts);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserPreferences _makePrefs({int dailyGoalMl = 2000, double? bacCapGramsPerL}) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
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
    bacCapGramsPerL: bacCapGramsPerL,
    bacOnLockScreenEnabled: false,
    approachingCapNotifEnabled: false,
    soberEstimateNotifEnabled: false,
    alcoholicPresetsAlwaysVisible: true,
    installedAt: epoch,
    createdAt: epoch,
    updatedAt: epoch,
  );
}

/// A minimal live [PartySession] fixture — id is the only field the History
/// screen's session-overlay/conditional-visibility logic reads meaningfully
/// alongside [startedAt]/[endedAt].
PartySession _session({
  String id = 'session-1',
  required DateTime startedAt,
  DateTime? endedAt,
}) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  return PartySession(
    id: id,
    startedAt: startedAt,
    endedAt: endedAt,
    useSessionPrices: false,
    createdAt: epoch,
    updatedAt: epoch,
  );
}

/// Seven zero-filled DailyBucket entries starting at an arbitrary Monday —
/// the fake repo ignores the requested range, so the exact dates don't need
/// to line up with "now"; only the values matter to the assertions.
List<DailyBucket> _week(List<int> values) {
  final monday = DateTime(2026, 6, 22, 5, 0);
  return [
    for (var i = 0; i < values.length; i++)
      DailyBucket(
        dayStart: DateTime(monday.year, monday.month, monday.day + i, 5, 0),
        value: values[i],
      ),
  ];
}

/// [count] zero-filled DailyBucket entries starting on the 1st of an
/// arbitrary month — used to smoke-test the Monthly range's higher bar
/// count (28-31 bars), which the 7-bar `_week` fixture never exercises.
List<DailyBucket> _month(int count, {int fillValue = 500}) {
  final first = DateTime(2026, 6, 1, 5, 0);
  return [
    for (var i = 0; i < count; i++)
      DailyBucket(
        dayStart: DateTime(first.year, first.month, first.day + i, 5, 0),
        value: fillValue,
      ),
  ];
}

/// Seven [BacDailyBucket]s aligned to the same Monday as [_week] — `null`
/// entries in [values] produce a no-session (null `maxGPerL`) bucket.
List<BacDailyBucket> _bacWeek(List<double?> values) {
  final monday = DateTime(2026, 6, 22, 5, 0);
  return [
    for (var i = 0; i < values.length; i++)
      BacDailyBucket(
        dayStart: DateTime(monday.year, monday.month, monday.day + i, 5, 0),
        maxGPerL: values[i],
      ),
  ];
}

Widget _buildScreen({
  required _FakeRepo repo,
  UserPreferences? prefs,
  List<PartySession> sessions = const [],
  List<DailyBucket> alcoholicCounts = const [],
  List<BacDailyBucket> maxBacBuckets = const [],
}) {
  return ProviderScope(
    overrides: [
      drinksRepositoryProvider.overrideWithValue(repo),
      userPreferencesProvider.overrideWith(
        (_) => Stream.value(prefs ?? _makePrefs()),
      ),
      // formatServiceProvider is Provider<FormatService?> — pass null so
      // charts fall back to their raw-value label strings (deterministic,
      // locale-independent).
      formatServiceProvider.overrideWithValue(null),
      // These #26 family providers resolve to partySessionRepositoryProvider
      // -> a real AppDatabase by default, which throws on path_provider in a
      // widget-test environment, so every test overrides them directly —
      // defaulting to empty/no-session for the pre-#26 tests, and to
      // caller-supplied fixtures for the #26 tests below.
      historySessionsInRangeProvider.overrideWith(
        (ref, key) => Stream.value(sessions),
      ),
      historyAlcoholicDrinksPerDayProvider.overrideWith(
        (ref, key) => Stream.value(alcoholicCounts),
      ),
      historyMaxBacPerDayProvider.overrideWith(
        (ref, key) => Future.value(maxBacBuckets),
      ),
      // Same rationale — the day drill-down (HistoryDayScreen) reads these
      // two on navigation; default to empty so a tap-to-drilldown test
      // doesn't need a real AppDatabase either.
      historyDayEntriesProvider.overrideWith((ref, key) => Stream.value([])),
      historyDaySessionSummariesProvider.overrideWith(
        (ref, key) => Future.value([]),
      ),
    ],
    child: const MaterialApp(home: HistoryScreen()),
  );
}

/// Enlarges the test surface so all 4 chart cards (hydration, drinks,
/// alcoholic-drinks-per-day, max-BAC) fit without scrolling — the History
/// body's `ListView(children: [...])` still lazily mounts children through a
/// sliver, so cards below the fold (the alcohol section's, 3rd/4th in the
/// list) would otherwise be absent from the tree at the default 800×600 test
/// surface size. Call before `pumpWidget`; the physical size resets
/// automatically via `addTearDown`.
void _growSurfaceForAlcoholSection(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Chart renders with known data
  // -------------------------------------------------------------------------

  testWidgets(
    'both charts render with bar count/values matching the fake buckets',
    (tester) async {
      final totals = _week([500, 1000, 1500, 2000, 2500, 0, 1800]);
      final counts = _week([1, 2, 3, 4, 5, 0, 3]);
      final repo = _FakeRepo(totals: totals, counts: counts);

      await tester.pumpWidget(_buildScreen(repo: repo));
      await tester.pump();
      await tester.pump();

      // Source: history_screen.dart _HistoryBody.build — hydration chart is
      // the first _ChartCard in the ListView, drinks-per-day is the second.
      final barCharts = find.byType(BarChart);
      expect(barCharts, findsNWidgets(2));

      final hydrationChart = tester.widget<BarChart>(barCharts.at(0));
      expect(hydrationChart.data.barGroups.length, equals(totals.length));
      for (var i = 0; i < totals.length; i++) {
        expect(
          hydrationChart.data.barGroups[i].barRods.single.toY,
          equals(totals[i].value.toDouble()),
        );
      }

      final drinksChart = tester.widget<BarChart>(barCharts.at(1));
      expect(drinksChart.data.barGroups.length, equals(counts.length));
      for (var i = 0; i < counts.length; i++) {
        expect(
          drinksChart.data.barGroups[i].barRods.single.toY,
          equals(counts[i].value.toDouble()),
        );
      }
    },
  );

  // -------------------------------------------------------------------------
  // 2. Empty state
  // -------------------------------------------------------------------------

  testWidgets(
    'empty state appears when every hydration bucket is zero-valued',
    (tester) async {
      final repo = _FakeRepo(totals: _week([0, 0, 0, 0, 0, 0, 0]));

      await tester.pumpWidget(_buildScreen(repo: repo));
      await tester.pump();
      await tester.pump();

      // Source: history_screen.dart _EmptyState text.
      expect(find.text('No drinks logged in this period'), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
    },
  );

  testWidgets(
    'empty state does NOT appear when at least one hydration bucket has data',
    (tester) async {
      final repo = _FakeRepo(
        totals: _week([0, 0, 500, 0, 0, 0, 0]),
        counts: _week([0, 0, 1, 0, 0, 0, 0]),
      );

      await tester.pumpWidget(_buildScreen(repo: repo));
      await tester.pump();
      await tester.pump();

      expect(find.text('No drinks logged in this period'), findsNothing);
      expect(find.byType(BarChart), findsNWidgets(2));
    },
  );

  // -------------------------------------------------------------------------
  // 3. Range paging
  // -------------------------------------------------------------------------

  testWidgets(
    'tapping the back chevron re-subscribes with a range exactly 7 days '
    'earlier (weekly mode) and enables the forward chevron',
    (tester) async {
      final repo = _FakeRepo(
        totals: _week([500, 500, 500, 500, 500, 500, 500]),
      );

      await tester.pumpWidget(_buildScreen(repo: repo));
      await tester.pump();
      await tester.pump();

      expect(repo.totalsRangeStarts, hasLength(1));
      final initialRangeStart = repo.totalsRangeStarts.single;

      // Forward chevron must be disabled at the current (offset 0) period.
      final forwardButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(
        forwardButton.onPressed,
        isNull,
        reason: 'Paging forward past the current period must be disabled',
      );

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
      await tester.pump();
      await tester.pump();

      expect(
        repo.totalsRangeStarts.last,
        equals(initialRangeStart.subtract(const Duration(days: 7))),
        reason:
            'Weekly paging back one step must move rangeStart exactly 7 days '
            'earlier',
      );

      // Forward chevron must now be enabled (we're one period back).
      final forwardButtonAfter = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(forwardButtonAfter.onPressed, isNotNull);
    },
  );

  testWidgets(
    'tapping forward after paging back returns to the original (offset 0) '
    'period',
    (tester) async {
      final repo = _FakeRepo(
        totals: _week([500, 500, 500, 500, 500, 500, 500]),
      );

      await tester.pumpWidget(_buildScreen(repo: repo));
      await tester.pump();
      await tester.pump();
      final initialRangeStart = repo.totalsRangeStarts.single;

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
      await tester.pump();
      await tester.pump();
      expect(
        repo.totalsRangeStarts.last,
        equals(initialRangeStart.subtract(const Duration(days: 7))),
      );

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
      await tester.pump();
      await tester.pump();

      // historyDailyTotalsProvider is a non-autoDispose `.family` provider,
      // so re-requesting the offset-0 key it already served once may reuse
      // the cached subscription instead of calling the repo again — the
      // forward-chevron's disabled state is the reliable proxy for "we're
      // back at the current period" (see chevron assertion below), not
      // another recorded repo call.
      final forwardButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      expect(
        forwardButton.onPressed,
        isNull,
        reason: 'Back at the current period, forward must be disabled again',
      );
    },
  );

  // -------------------------------------------------------------------------
  // 4. Weekly/Monthly toggle
  // -------------------------------------------------------------------------

  testWidgets('switching to Monthly resets paging back to the current period', (
    tester,
  ) async {
    final repo = _FakeRepo(totals: _week([500, 500, 500, 500, 500, 500, 500]));

    await tester.pumpWidget(_buildScreen(repo: repo));
    await tester.pump();
    await tester.pump();

    // Page back once (weekly offset 1) — forward chevron becomes enabled.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNotNull,
    );

    // Switch to Monthly via the SegmentedButton.
    await tester.tap(find.text('Monthly'));
    await tester.pump();
    await tester.pump();

    // Offset must have reset to 0 — forward chevron disabled again.
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
      reason: 'Switching range mode must reset paging to the current '
          'period (history_screen.dart _setMode)',
    );
  });

  testWidgets('Monthly range renders a 30-bar chart without throwing', (
    tester,
  ) async {
    final totals = _month(30);
    final counts = _month(30, fillValue: 2);
    final repo = _FakeRepo(totals: totals, counts: counts);

    await tester.pumpWidget(_buildScreen(repo: repo));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Monthly'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    final hydrationChart = tester.widget<BarChart>(find.byType(BarChart).at(0));
    expect(hydrationChart.data.barGroups.length, equals(30));
  });

  // -------------------------------------------------------------------------
  // 5. Non-colour below-goal signal
  // -------------------------------------------------------------------------

  testWidgets(
      'below-goal hydration bar has a non-BorderSide.none border; '
      'at-or-above-goal bar does not', (tester) async {
    // dailyGoalMl = 2000 (see _makePrefs). Bucket 0 (500 ml) is below goal;
    // bucket 1 (2500 ml) is at/above goal.
    final totals = _week([500, 2500, 0, 0, 0, 0, 0]);
    final repo = _FakeRepo(totals: totals);

    await tester.pumpWidget(_buildScreen(repo: repo, prefs: _makePrefs()));
    await tester.pump();
    await tester.pump();

    final hydrationChart = tester.widget<BarChart>(find.byType(BarChart).at(0));
    final belowGoalRod = hydrationChart.data.barGroups[0].barRods.single;
    final atGoalRod = hydrationChart.data.barGroups[1].barRods.single;

    // Source: history_screen.dart _HydrationChart._barGroup — Parity
    // Rulebook §Non-colour-signal rules: "History bar below daily goal:
    // Non-colour pattern/marker in addition to colour".
    expect(
      belowGoalRod.borderSide,
      isNot(equals(BorderSide.none)),
      reason: 'Below-goal bars must carry a visible border as the '
          'non-colour signal',
    );
    expect(
      atGoalRod.borderSide,
      equals(BorderSide.none),
      reason: 'At/above-goal bars must not carry the below-goal border',
    );
  });

  // -------------------------------------------------------------------------
  // 6. Alcohol section conditional visibility (issue #26)
  // -------------------------------------------------------------------------

  testWidgets(
    'alcohol section is NOT shown when there is no session in range, even '
    'if the (fake) alcoholic/BAC buckets carry data',
    (tester) async {
      final repo = _FakeRepo(totals: _week([500, 0, 0, 0, 0, 0, 0]));

      await tester.pumpWidget(
        _buildScreen(
          repo: repo,
          sessions: const [], // no sessions — the discriminator.
          alcoholicCounts: _week([3, 0, 0, 0, 0, 0, 0]),
          maxBacBuckets: _bacWeek([0.2, null, null, null, null, null, null]),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Alcoholic drinks per day'), findsNothing);
      expect(find.text('Max estimated BAC per day'), findsNothing);
      expect(
        find.byType(BarChart),
        findsNWidgets(2),
        reason: 'Only the hydration + drinks-per-day charts render — '
            'visibility is driven by historySessionsInRangeProvider, not by '
            'whether the alcohol buckets are non-zero',
      );
    },
  );

  testWidgets(
    'alcohol section IS shown when a session is in range, even with an '
    'otherwise all-zero (party-only) period — the regression case: must '
    'not fall into the "No drinks logged" empty state',
    (tester) async {
      _growSurfaceForAlcoholSection(tester);
      final repo = _FakeRepo(
        totals: _week([0, 0, 0, 0, 0, 0, 0]), // no hydration logged at all
        counts: _week([0, 0, 0, 0, 0, 0, 0]),
      );
      final session = _session(
        startedAt: DateTime(2026, 6, 22, 20, 0),
        endedAt: DateTime(2026, 6, 22, 22, 0),
      );

      await tester.pumpWidget(
        _buildScreen(
          repo: repo,
          sessions: [session],
          alcoholicCounts: _week([2, 0, 0, 0, 0, 0, 0]),
          maxBacBuckets: _bacWeek([0.2, null, null, null, null, null, null]),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('No drinks logged in this period'),
        findsNothing,
        reason: 'features.md F4: a party-only period must show the alcohol '
            'section, not the hydration empty state',
      );
      // The alcohol section's cards are 3rd/4th in the ListView — scroll
      // them into the viewport before asserting they exist (the underlying
      // sliver only lazily mounts children near the viewport + cache
      // extent).
      expect(find.text('Alcoholic drinks per day'), findsOneWidget);
      expect(find.text('Max estimated BAC per day'), findsOneWidget);
      expect(find.byType(BarChart), findsNWidgets(4));
    },
  );

  testWidgets(
    'alcoholic-drinks-per-day and max-BAC charts render bar values matching '
    'the fake buckets',
    (tester) async {
      _growSurfaceForAlcoholSection(tester);
      final repo = _FakeRepo(totals: _week([500, 0, 0, 0, 0, 0, 0]));
      final session = _session(startedAt: DateTime(2026, 6, 22, 20, 0));
      final alcoholicCounts = _week([2, 0, 1, 0, 0, 0, 0]);
      final maxBacBuckets = _bacWeek([0.2, null, 0.0, null, null, null, null]);

      await tester.pumpWidget(
        _buildScreen(
          repo: repo,
          sessions: [session],
          alcoholicCounts: alcoholicCounts,
          maxBacBuckets: maxBacBuckets,
        ),
      );
      await tester.pump();
      await tester.pump();

      final alcoholicChart = tester.widget<BarChart>(
        find.byType(BarChart).at(2),
      );
      expect(alcoholicChart.data.barGroups.length, equals(7));
      for (var i = 0; i < alcoholicCounts.length; i++) {
        expect(
          alcoholicChart.data.barGroups[i].barRods.single.toY,
          equals(alcoholicCounts[i].value.toDouble()),
        );
      }

      final maxBacChart = tester.widget<BarChart>(find.byType(BarChart).at(3));
      expect(maxBacChart.data.barGroups.length, equals(7));
      for (var i = 0; i < maxBacBuckets.length; i++) {
        expect(
          maxBacChart.data.barGroups[i].barRods.single.toY,
          equals(maxBacBuckets[i].maxGPerL ?? 0),
        );
      }
    },
  );

  // -------------------------------------------------------------------------
  // 7. Max-BAC chart: cap reference line + above/below-cap border
  // -------------------------------------------------------------------------

  testWidgets('cap HorizontalLine is present when bacCapGramsPerL is set', (
    tester,
  ) async {
    _growSurfaceForAlcoholSection(tester);
    final session = _session(startedAt: DateTime(2026, 6, 22, 20, 0));
    final maxBacBuckets = _bacWeek([0.2, null, null, null, null, null, null]);
    final repo = _FakeRepo(totals: _week([0, 0, 0, 0, 0, 0, 0]));

    await tester.pumpWidget(
      _buildScreen(
        repo: repo,
        prefs: _makePrefs(bacCapGramsPerL: 0.5),
        sessions: [session],
        maxBacBuckets: maxBacBuckets,
      ),
    );
    await tester.pump();
    await tester.pump();

    final withCap = tester.widget<BarChart>(find.byType(BarChart).at(3));
    expect(withCap.data.extraLinesData.horizontalLines, hasLength(1));
  });

  testWidgets('cap HorizontalLine is absent when bacCapGramsPerL is null', (
    tester,
  ) async {
    _growSurfaceForAlcoholSection(tester);
    final session = _session(startedAt: DateTime(2026, 6, 22, 20, 0));
    final maxBacBuckets = _bacWeek([0.2, null, null, null, null, null, null]);
    final repo = _FakeRepo(totals: _week([0, 0, 0, 0, 0, 0, 0]));

    await tester.pumpWidget(
      _buildScreen(
        repo: repo,
        prefs: _makePrefs(),
        sessions: [session],
        maxBacBuckets: maxBacBuckets,
      ),
    );
    await tester.pump();
    await tester.pump();

    final withoutCap = tester.widget<BarChart>(find.byType(BarChart).at(3));
    expect(withoutCap.data.extraLinesData.horizontalLines, isEmpty);
  });

  testWidgets(
    'at/above-cap bar has a non-BorderSide.none border; below-cap bar does '
    'not; no-session (null) bar is transparent with no border',
    (tester) async {
      _growSurfaceForAlcoholSection(tester);
      final session = _session(startedAt: DateTime(2026, 6, 22, 20, 0));
      // cap = 0.3: bucket 0 (0.5) is above cap, bucket 1 (0.1) is below,
      // bucket 2 (null) has no session at all.
      final maxBacBuckets = _bacWeek([0.5, 0.1, null, null, null, null, null]);
      final repo = _FakeRepo(totals: _week([0, 0, 0, 0, 0, 0, 0]));

      await tester.pumpWidget(
        _buildScreen(
          repo: repo,
          prefs: _makePrefs(bacCapGramsPerL: 0.3),
          sessions: [session],
          maxBacBuckets: maxBacBuckets,
        ),
      );
      await tester.pump();
      await tester.pump();

      final maxBacChart = tester.widget<BarChart>(find.byType(BarChart).at(3));
      final aboveCapRod = maxBacChart.data.barGroups[0].barRods.single;
      final belowCapRod = maxBacChart.data.barGroups[1].barRods.single;
      final noSessionRod = maxBacChart.data.barGroups[2].barRods.single;

      // Source: history_screen.dart _MaxBacChart._bacBarGroup — mirrors the
      // hydration chart's below-goal border (Parity Rulebook
      // §Non-colour-signal rules), using isApproachingCap's inclusive (>=)
      // boundary (core/bac.dart).
      expect(
        aboveCapRod.borderSide,
        isNot(equals(BorderSide.none)),
        reason: 'At/above-cap bars must carry a visible border as the '
            'non-colour signal',
      );
      expect(belowCapRod.borderSide, equals(BorderSide.none));
      expect(
        noSessionRod.color,
        equals(Colors.transparent),
        reason: 'No-session days get a transparent (not omitted) rod so the '
            'day stays tappable for the drill-down',
      );
      expect(noSessionRod.borderSide, equals(BorderSide.none));
    },
  );

  testWidgets(
    'tapping a session-touched but fully-decayed (0.0) BAC bar mid-column '
    'opens the day drill-down, not just an ~8px strip at the zero baseline '
    "(fl_chart 0.68.0's BarChartPainter.handleTouch only hit-tests a rod's "
    'own rendered pixel bounds by default)',
    (tester) async {
      _growSurfaceForAlcoholSection(tester);
      final session = _session(startedAt: DateTime(2026, 6, 22, 20, 0));
      // Bucket 2 (Wednesday): the session touched it (band present) but its
      // sampled BAC fully decayed to 0.0 — a real zero-height bar, distinct
      // from the null/no-session case.
      final maxBacBuckets = _bacWeek([0.5, 0.3, 0.0, null, null, null, null]);
      final repo = _FakeRepo(totals: _week([0, 0, 0, 0, 0, 0, 0]));

      await tester.pumpWidget(
        _buildScreen(
          repo: repo,
          sessions: [session],
          maxBacBuckets: maxBacBuckets,
        ),
      );
      await tester.pump();
      await tester.pump();

      final chartFinder = find.byType(BarChart).at(3);
      final topLeft = tester.getTopLeft(chartFinder);
      final size = tester.getSize(chartFinder);

      // Source: history_screen.dart _MaxBacChart's leftTitles reservedSize
      // (40) plus fl_chart's spaceAround column formula (groupsX[i] =
      // (i + 0.5) * plotWidth / bucketCount — see fl_chart's
      // BarChartDataExtension.calculateGroupsX).
      const leftReservedSize = 40.0;
      const bucketCount = 7;
      final plotWidth = size.width - leftReservedSize;
      final columnCenterX =
          leftReservedSize + (2 + 0.5) * plotWidth / bucketCount;
      // Mid-height of the chart — well above the zero baseline, which was
      // the only tappable area before this fix.
      final midHeightY = size.height * 0.3;

      await tester.tapAt(topLeft + Offset(columnCenterX, midHeightY));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryDayScreen), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // 8. Session overlay band
  // -------------------------------------------------------------------------

  testWidgets(
    'both alcohol charts carry one VerticalRangeAnnotation per session in '
    'range',
    (tester) async {
      _growSurfaceForAlcoholSection(tester);
      final sessionA = _session(
        id: 'sA',
        startedAt: DateTime(2026, 6, 22, 20, 0),
        endedAt: DateTime(2026, 6, 22, 22, 0),
      );
      final sessionB = _session(
        id: 'sB',
        startedAt: DateTime(2026, 6, 24, 20, 0),
        endedAt: DateTime(2026, 6, 24, 22, 0),
      );
      final repo = _FakeRepo(totals: _week([0, 0, 0, 0, 0, 0, 0]));

      await tester.pumpWidget(
        _buildScreen(
          repo: repo,
          sessions: [sessionA, sessionB],
          alcoholicCounts: _week([1, 0, 1, 0, 0, 0, 0]),
          maxBacBuckets: _bacWeek([0.1, null, 0.1, null, null, null, null]),
        ),
      );
      await tester.pump();
      await tester.pump();

      final alcoholicChart = tester.widget<BarChart>(
        find.byType(BarChart).at(2),
      );
      final maxBacChart = tester.widget<BarChart>(find.byType(BarChart).at(3));

      expect(
        alcoholicChart.data.rangeAnnotations.verticalRangeAnnotations,
        hasLength(2),
      );
      expect(
        maxBacChart.data.rangeAnnotations.verticalRangeAnnotations,
        hasLength(2),
      );
    },
  );

  testWidgets(
    'a session spanning two consecutive days gets one band covering both '
    "day indices (x1/x2 span Monday's and Tuesday's bar positions)",
    (tester) async {
      _growSurfaceForAlcoholSection(tester);
      // Monday 22:00 -> Tuesday 08:00 — the 05:00 day-boundary (_makePrefs's
      // dayBoundaryHour) falls inside this window, so it genuinely spans
      // Monday's AND Tuesday's day-windows, not just calendar midnight.
      final session = _session(
        startedAt: DateTime(2026, 6, 22, 22, 0),
        endedAt: DateTime(2026, 6, 23, 8, 0),
      );
      final repo = _FakeRepo(totals: _week([0, 0, 0, 0, 0, 0, 0]));

      await tester.pumpWidget(
        _buildScreen(
          repo: repo,
          sessions: [session],
          maxBacBuckets: _bacWeek([0.1, 0.1, null, null, null, null, null]),
        ),
      );
      await tester.pump();
      await tester.pump();

      final maxBacChart = tester.widget<BarChart>(find.byType(BarChart).at(3));
      final annotations =
          maxBacChart.data.rangeAnnotations.verticalRangeAnnotations;

      expect(annotations, hasLength(1));
      // Day index 0 (Monday) through day index 1 (Tuesday) — see
      // sessionOverlayAnnotations()'s `firstIndex`/`lastIndex` +/- 0.5
      // padding around each touched bar's x position.
      expect(annotations.single.x1, -0.5);
      expect(annotations.single.x2, 1.5);
    },
  );
}
