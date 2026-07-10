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
//
// Provider override pattern mirrors flutter/test/widgets/today_drinks_screen_test.dart:
// a fake DrinksRepository subclass records calls without touching the DB.

import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/daily_bucket.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
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

UserPreferences _makePrefs({int dailyGoalMl = 2000}) {
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
    bacOnLockScreenEnabled: false,
    approachingCapNotifEnabled: false,
    soberEstimateNotifEnabled: false,
    installedAt: epoch,
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

Widget _buildScreen({required _FakeRepo repo, UserPreferences? prefs}) {
  return ProviderScope(
    overrides: [
      drinksRepositoryProvider.overrideWithValue(repo),
      userPreferencesProvider
          .overrideWith((_) => Stream.value(prefs ?? _makePrefs())),
      // formatServiceProvider is Provider<FormatService?> — pass null so
      // charts fall back to their raw-value label strings (deterministic,
      // locale-independent).
      formatServiceProvider.overrideWithValue(null),
    ],
    child: const MaterialApp(home: HistoryScreen()),
  );
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
      final repo =
          _FakeRepo(totals: _week([500, 500, 500, 500, 500, 500, 500]));

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
      final repo =
          _FakeRepo(totals: _week([500, 500, 500, 500, 500, 500, 500]));

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

  testWidgets(
    'switching to Monthly resets paging back to the current period',
    (tester) async {
      final repo =
          _FakeRepo(totals: _week([500, 500, 500, 500, 500, 500, 500]));

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
    },
  );

  testWidgets(
    'Monthly range renders a 30-bar chart without throwing',
    (tester) async {
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
      final hydrationChart =
          tester.widget<BarChart>(find.byType(BarChart).at(0));
      expect(hydrationChart.data.barGroups.length, equals(30));
    },
  );

  // -------------------------------------------------------------------------
  // 5. Non-colour below-goal signal
  // -------------------------------------------------------------------------

  testWidgets(
    'below-goal hydration bar has a non-BorderSide.none border; '
    'at-or-above-goal bar does not',
    (tester) async {
      // dailyGoalMl = 2000 (see _makePrefs). Bucket 0 (500 ml) is below goal;
      // bucket 1 (2500 ml) is at/above goal.
      final totals = _week([500, 2500, 0, 0, 0, 0, 0]);
      final repo = _FakeRepo(totals: totals);

      await tester.pumpWidget(_buildScreen(repo: repo, prefs: _makePrefs()));
      await tester.pump();
      await tester.pump();

      final hydrationChart =
          tester.widget<BarChart>(find.byType(BarChart).at(0));
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
    },
  );
}
