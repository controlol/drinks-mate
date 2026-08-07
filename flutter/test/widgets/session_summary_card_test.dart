// Widget tests for SessionSummaryCard (issue #122) — the shared card used
// by both the History day drill-down (S3, `expandable: true`,
// `multiDayPosition` set) and S9 Party Session Log's ended-mode header
// (`expandable: true`, no `multiDayPosition`/`onViewFullSession`).
//
// Coverage:
//  1. The "Day N of M" multi-day pill (`multiDayPosition`): absent when
//     null; when set, renders the exact "Day N of M" text, on its own line
//     directly under the header row (above "Duration:"), visible in BOTH
//     collapsed and expanded states, with neutral (non-warning/non-success)
//     colouring — `colorScheme.surfaceContainerHighest`, not
//     `kColorWarning`/`kColorSuccess` (see today_screen.dart's `_StatusPill`
//     for the closest prior-art colour-container pattern; there is no
//     existing test of that pill's colouring to mirror, so this is a
//     straightforward from-scratch assertion).
//  2. The "View full session" button (`onViewFullSession`): absent when
//     null; absent when the card isn't expanded (whether because
//     `expandable: false`, or `expandable: true` but not yet tapped open),
//     even when set; present and tappable only when both set AND expanded.
//  3. Regression guard for issue #122 point 1: the per-meal list block was
//     removed from the expanded state entirely — a non-empty
//     `summary.meals` must never render meal text on this card (S9 now
//     shows meals in its own merged entry list instead — see
//     party_session_log_screen_test.dart).
//
// Fixture/helper conventions mirror history_day_screen_test.dart's
// self-contained `_session`/`_epoch`/`_chartSeries` builders (each widget
// test file keeps its own minimal fixtures rather than sharing a fixture
// library, matching this repo's established pattern).
import 'package:core/core.dart';
import 'package:drinks_mate/src/models/bac_chart_series.dart';
import 'package:drinks_mate/src/models/meal.dart';
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/session_day_summary.dart';
import 'package:drinks_mate/src/theme/color_tokens.dart';
import 'package:drinks_mate/src/widgets/session_lifetime_bac_chart.dart';
import 'package:drinks_mate/src/widgets/session_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
final _dayStart = DateTime.utc(2026, 6, 22, 5, 0);

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

BacChartSeries _chartSeries() {
  final start = _dayStart;
  final end = _dayStart.add(const Duration(hours: 1));
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

Widget _buildCard({
  required SessionDaySummary summary,
  bool expandable = false,
  ({int dayIndex, int totalDays})? multiDayPosition,
  VoidCallback? onViewFullSession,
  VoidCallback? onEditName,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SessionSummaryCard(
        summary: summary,
        expandable: expandable,
        multiDayPosition: multiDayPosition,
        onViewFullSession: onViewFullSession,
        onEditName: onEditName,
      ),
    ),
  );
}

void main() {
  final baseSummary = SessionDaySummary(
    session: _session(endedAt: _dayStart.add(const Duration(hours: 3))),
    duration: const Duration(hours: 3),
    totalAlcoholicDrinks: 2,
    mealsLoggedCount: 1,
    peakBacGPerL: 0.2,
    totalAlcoholGrams: 20,
    lifetimeBacChart: _chartSeries(),
    asOf: _dayStart.add(const Duration(hours: 3)),
  );

  // ---------------------------------------------------------------------
  // 1. Multi-day pill
  // ---------------------------------------------------------------------

  group('multiDayPosition pill', () {
    testWidgets(
      'multiDayPosition == null -> no "Day N of M" pill renders',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(summary: baseSummary, multiDayPosition: null),
        );
        await tester.pump();

        expect(find.textContaining(RegExp(r'^Day \d+ of \d+$')), findsNothing);
      },
    );

    testWidgets(
      'multiDayPosition set -> renders exact "Day N of M" text, collapsed',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(
            summary: baseSummary,
            multiDayPosition: (dayIndex: 2, totalDays: 3),
          ),
        );
        await tester.pump();

        expect(find.text('Day 2 of 3'), findsOneWidget);
      },
    );

    testWidgets(
      'pill uses neutral colorScheme.surfaceContainerHighest colouring, not '
      'kColorWarning/kColorSuccess',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(
            summary: baseSummary,
            multiDayPosition: (dayIndex: 1, totalDays: 2),
          ),
        );
        await tester.pump();

        final pillContainer = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Day 1 of 2'),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = pillContainer.decoration! as BoxDecoration;
        final colorScheme =
            Theme.of(tester.element(find.text('Day 1 of 2'))).colorScheme;

        expect(decoration.color, colorScheme.surfaceContainerHighest);
        expect(decoration.color, isNot(kColorWarning));
        expect(decoration.color, isNot(kColorSuccess));
        expect(
          (decoration.borderRadius! as BorderRadius),
          BorderRadius.circular(20),
        );
      },
    );

    testWidgets(
      'pill renders on its own line above "Duration:", both collapsed and '
      'expanded, and remains visible (not duplicated) once expanded',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(
            summary: baseSummary,
            expandable: true,
            multiDayPosition: (dayIndex: 1, totalDays: 2),
          ),
        );
        await tester.pump();

        expect(find.text('Day 1 of 2'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Day 1 of 2')).dy,
          lessThan(tester.getTopLeft(find.text('Duration: 3h 0m')).dy),
        );

        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pump();

        // Still exactly one pill after expanding — not re-rendered/duplicated.
        expect(find.text('Day 1 of 2'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Day 1 of 2')).dy,
          lessThan(tester.getTopLeft(find.text('Duration: 3h 0m')).dy),
        );
      },
    );
  });

  // ---------------------------------------------------------------------
  // 2. "View full session" button
  // ---------------------------------------------------------------------

  group('onViewFullSession button', () {
    testWidgets(
      'absent when onViewFullSession is null, even when expanded',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(summary: baseSummary, expandable: true),
        );
        await tester.pump();
        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pump();

        expect(find.text('View full session'), findsNothing);
      },
    );

    testWidgets(
      'absent when expandable is false, even when onViewFullSession is set',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          _buildCard(
            summary: baseSummary,
            onViewFullSession: () => tapped = true,
          ),
        );
        await tester.pump();

        expect(find.text('View full session'), findsNothing);
        expect(tapped, isFalse);
      },
    );

    testWidgets(
      'absent while collapsed, even when expandable and onViewFullSession '
      'are both set',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(
            summary: baseSummary,
            expandable: true,
            onViewFullSession: () {},
          ),
        );
        await tester.pump();

        expect(find.text('View full session'), findsNothing);
      },
    );

    testWidgets(
      'present when expanded and onViewFullSession is set; tapping it '
      'invokes the callback',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          _buildCard(
            summary: baseSummary,
            expandable: true,
            onViewFullSession: () => tapped = true,
          ),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pump();

        final buttonFinder =
            find.widgetWithText(OutlinedButton, 'View full session');
        expect(buttonFinder, findsOneWidget);

        await tester.tap(buttonFinder);
        await tester.pump();

        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'button renders after the BAC chart (bottom of expanded content)',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(
            summary: baseSummary,
            expandable: true,
            onViewFullSession: () {},
          ),
        );
        await tester.pump();
        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pump();

        final chartDy =
            tester.getTopLeft(find.byType(SessionLifetimeBacChart)).dy;
        final buttonDy = tester
            .getTopLeft(
                find.widgetWithText(OutlinedButton, 'View full session'))
            .dy;
        expect(chartDy, lessThan(buttonDy));
      },
    );
  });

  // ---------------------------------------------------------------------
  // 3. Meals list removed (issue #122 point 1) — regression guard.
  // ---------------------------------------------------------------------

  group('meals list no longer renders on this card (issue #122)', () {
    testWidgets(
      'a non-empty summary.meals never renders meal text, even expanded',
      (tester) async {
        final summaryWithMeals = SessionDaySummary(
          session: _session(endedAt: _dayStart.add(const Duration(hours: 3))),
          duration: const Duration(hours: 3),
          totalAlcoholicDrinks: 2,
          mealsLoggedCount: 1,
          peakBacGPerL: 0.2,
          totalAlcoholGrams: 20,
          meals: [
            _meal(
              id: 'm1',
              partySessionId: 's1',
              eatenAt: _dayStart.add(const Duration(hours: 1)),
              size: MealSize.medium,
            ),
          ],
          lifetimeBacChart: _chartSeries(),
          asOf: _dayStart.add(const Duration(hours: 3)),
        );

        await tester.pumpWidget(
          _buildCard(summary: summaryWithMeals, expandable: true),
        );
        await tester.pump();
        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pump();

        expect(find.textContaining('Medium meal'), findsNothing);
        // The grams line and chart still show — only the meals list itself
        // was removed.
        expect(find.text('Total consumed alcohol: 20 g'), findsOneWidget);
        expect(find.byType(SessionLifetimeBacChart), findsOneWidget);
      },
    );
  });
}
