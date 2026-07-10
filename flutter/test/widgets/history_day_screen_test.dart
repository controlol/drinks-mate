// Widget tests for HistoryDayScreen (F4/S3 day drill-down, issue #26).
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
//
// Provider override pattern mirrors history_screen_test.dart: the two #26
// day-drilldown family providers (historyDayEntriesProvider,
// historyDaySessionSummariesProvider) are overridden directly with
// caller-supplied fake data — no fake-repo subclass or real DB needed.

import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/session_day_summary.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/history_day_screen.dart';
import 'package:drinks_mate/src/services/format_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _dayStart = DateTime.utc(2026, 6, 22, 5, 0);
final _dayEnd = DateTime.utc(2026, 6, 23, 5, 0);
final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

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
}) {
  return DrinkEntry(
    id: id,
    name: name,
    beverageType: beverageType,
    volumeMl: volumeMl,
    partySessionId: partySessionId,
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

Widget _buildScreen({
  List<DrinkEntry> entries = const [],
  List<SessionDaySummary> summaries = const [],
  UserPreferences? prefs,
}) {
  return ProviderScope(
    overrides: [
      userPreferencesProvider
          .overrideWith((_) => Stream.value(prefs ?? _makePrefs())),
      // Deterministic, locale-independent raw-value fallback strings.
      formatServiceProvider.overrideWithValue(null),
      historyDayEntriesProvider
          .overrideWith((ref, key) => Stream.value(entries)),
      historyDaySessionSummariesProvider
          .overrideWith((ref, key) => Future.value(summaries)),
    ],
    child: MaterialApp(
      home: HistoryDayScreen(dayStart: _dayStart, dayEnd: _dayEnd),
    ),
  );
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Entry list rendering
  // -------------------------------------------------------------------------

  testWidgets(
    'renders one tile per entry with name, volume, and time text',
    (tester) async {
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
      // environment is UTC by default, so 20:30/08:00 local == UTC. Match
      // the full subtitle text (not a bare "330 ml"/"250 ml" substring),
      // since the hydration header above also renders a bare volume value
      // that can coincidentally match one of these.
      expect(find.text('330 ml · 20:30'), findsOneWidget);
      expect(find.text('250 ml · 08:00'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(2));
    },
  );

  testWidgets(
    'entry order follows the provider (newest-first, per '
    'watchDayEntries\' contract) rather than being re-sorted by the screen',
    (tester) async {
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
    },
  );

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

  testWidgets(
    'does NOT show the empty state when at least one entry exists',
    (tester) async {
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
    },
  );

  // -------------------------------------------------------------------------
  // 3. Session summary card
  // -------------------------------------------------------------------------

  testWidgets(
    'session summary card shows duration, alcohol volume, and peak BAC',
    (tester) async {
      final summary = SessionDaySummary(
        session: _session(),
        duration: const Duration(hours: 3, minutes: 15),
        totalAlcoholMl: 660,
        peakBacGPerL: 0.234,
      );

      await tester.pumpWidget(_buildScreen(summaries: [summary]));
      await tester.pump();
      await tester.pump();

      expect(find.text('Party session'), findsOneWidget);
      expect(find.text('Duration: 3h 15m'), findsOneWidget);
      expect(find.text('Alcohol logged: 660 ml'), findsOneWidget);
      expect(
        find.text('Peak estimated BAC: 0.23 g/L (≈ 5.08 mmol/L) — estimate'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'peak BAC line is omitted when peakBacGPerL is null (incomplete '
    'profile), but duration/volume still show',
    (tester) async {
      final summary = SessionDaySummary(
        session: _session(),
        duration: const Duration(hours: 1),
        totalAlcoholMl: 330,
      );

      await tester.pumpWidget(_buildScreen(summaries: [summary]));
      await tester.pump();
      await tester.pump();

      expect(find.text('Duration: 1h 0m'), findsOneWidget);
      expect(find.text('Alcohol logged: 330 ml'), findsOneWidget);
      expect(find.textContaining('Peak estimated BAC'), findsNothing);
    },
  );

  testWidgets(
    'renders one summary card per session (multiple sessions overlapping '
    'the same day)',
    (tester) async {
      final summaries = [
        SessionDaySummary(
          session: _session(id: 's1'),
          duration: const Duration(hours: 1),
          totalAlcoholMl: 330,
          peakBacGPerL: 0.1,
        ),
        SessionDaySummary(
          session: _session(id: 's2'),
          duration: const Duration(hours: 2),
          totalAlcoholMl: 500,
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

  testWidgets('no session summary card when there are no sessions that day',
      (tester) async {
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
}
