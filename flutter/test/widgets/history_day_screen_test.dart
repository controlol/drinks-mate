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
//
// Provider override pattern mirrors history_screen_test.dart: the two #26
// day-drilldown family providers (historyDayEntriesProvider,
// historyDaySessionSummariesProvider) are overridden directly with
// caller-supplied fake data. Edit/delete tests additionally override
// drinksRepositoryProvider with a _FakeRepo (pattern mirrors
// today_drinks_screen_test.dart's _FakeRepo) — no real DB needed.

import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/models/optional.dart';
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/session_day_summary.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/history_day_screen.dart';
import 'package:drinks_mate/src/services/format_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  UserPreferences? prefs,
  bool alwaysUse24HourFormat = false,
  _FakeRepo? repo,
}) {
  return ProviderScope(
    overrides: [
      userPreferencesProvider.overrideWith(
        (_) => Stream.value(prefs ?? _makePrefs()),
      ),
      // Deterministic, locale-independent raw-value fallback strings.
      formatServiceProvider.overrideWithValue(null),
      historyDayEntriesProvider.overrideWith(
        (ref, key) => Stream.value(entries),
      ),
      historyDaySessionSummariesProvider.overrideWith(
        (ref, key) => Future.value(summaries),
      ),
      if (repo != null) drinksRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(alwaysUse24HourFormat: alwaysUse24HourFormat),
        child: child!,
      ),
      home: HistoryDayScreen(dayStart: _dayStart, dayEnd: _dayEnd),
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

  testWidgets('tapping edit button opens the edit sheet', (tester) async {
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

    expect(find.byTooltip('Edit'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    // Source: history_day_screen.dart _EditEntrySheetState.build (mirrors
    // today_drinks_screen.dart's _EditEntrySheet).
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
    'session-attached alcoholic entry has no Edit/Delete tooltips, while a '
    'normal entry and an orphan alcoholic entry in the same day still do',
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

      // Exactly two Edit and two Delete tooltips — one pair each for the
      // normal entry and the orphan alcoholic entry; none for the
      // session-attached alcoholic entry, which renders read-only.
      expect(find.byTooltip('Edit'), findsNWidgets(2));
      expect(find.byTooltip('Delete'), findsNWidgets(2));
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
      await tester.tap(find.byTooltip('Edit'));
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
      await tester.tap(find.byTooltip('Edit'));
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
}
