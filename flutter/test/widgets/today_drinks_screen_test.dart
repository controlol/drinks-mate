// Widget tests for S6 — TodayDrinksScreen.
//
// Coverage:
//  1. Empty state shows "No drinks logged yet" text.
//  2. Entry list renders name, volume, and time for each entry.
//  3. Entries appear in reverse-chronological order (newest first).
//  4. Edit button opens the edit sheet.
//  5. Delete button shows confirmation dialog.
//  6. Confirming delete calls deleteDrinkEntry on the repository.
//
// Provider override pattern mirrors flutter/test/widgets/goal_celebration_test.dart.
// A _FakeRepo subclass records calls without touching the DB — the repository
// pattern from the task spec ("fake DrinksRepository subclass").

import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/models/optional.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/today_drinks_screen.dart';
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

UserPreferences _makePrefs() {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  return UserPreferences(
    id: kUserPreferencesId,
    username: 'tester',
    dailyGoalMl: 2000,
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
    installedAt: epoch,
    createdAt: epoch,
    updatedAt: epoch,
  );
}

/// Build a testable TodayDrinksScreen wrapped in ProviderScope with all
/// required providers overridden.
///
/// [entries] is the list the todayEntriesProvider yields.
/// [repo] is the fake repository injected for mutation calls.
/// [totalMl] drives the todayTotalMlProvider (default 500).
/// [alwaysUse24HourFormat] drives `MediaQuery.alwaysUse24HourFormat`, which
/// is what `TimeOfDay.format(context)` actually keys off (not [Locale]) —
/// see the "Time-of-day display format" Parity Rulebook row.
Widget _buildScreen({
  required List<DrinkEntry> entries,
  required _FakeRepo repo,
  int totalMl = 500,
  bool alwaysUse24HourFormat = false,
}) {
  return ProviderScope(
    overrides: [
      drinksRepositoryProvider.overrideWithValue(repo),
      todayEntriesProvider.overrideWith((_) => Stream.value(entries)),
      userPreferencesProvider.overrideWith((_) => Stream.value(_makePrefs())),
      todayTotalMlProvider.overrideWith((_) => Stream.value(totalMl)),
      // formatServiceProvider is Provider<FormatService?> — pass null to fall
      // back to the widget's '${ml} ml' fallback string.
      formatServiceProvider.overrideWithValue(null),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(alwaysUse24HourFormat: alwaysUse24HourFormat),
        child: child!,
      ),
      home: const TodayDrinksScreen(),
    ),
  );
}

/// Create a minimal DrinkEntry suitable for widget tests.
DrinkEntry _entry({
  required String id,
  required String name,
  int volumeMl = 300,
  required DateTime consumedAt,
}) {
  final now = DateTime.utc(2026, 6, 23, 12, 0);
  return DrinkEntry(
    id: id,
    name: name,
    beverageType: BeverageType.water,
    volumeMl: volumeMl,
    consumedAt: consumedAt.toUtc(),
    createdAt: now,
    updatedAt: now,
    iconKey: 'glass',
    iconColor: '#3b82f6',
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. Empty state
  // -------------------------------------------------------------------------

  testWidgets('empty state shows "No drinks logged yet" text', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_buildScreen(entries: [], repo: repo));
    await tester.pump(); // let the StreamProvider deliver []

    // Source: today_drinks_screen.dart _EmptyState widget text
    expect(find.text('No drinks logged yet'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. List renders entries with name, volume, and time
  // -------------------------------------------------------------------------

  testWidgets('list renders entry name, volume, and time', (tester) async {
    final repo = _FakeRepo();
    // consumedAt = 09:30 UTC — widget displays local time; use UTC for a
    // deterministic display string that avoids timezone offsets in CI.
    final consumedAt = DateTime.utc(2026, 6, 23, 9, 30);
    final entries = [
      _entry(
          id: 'e1',
          name: 'Morning Water',
          volumeMl: 350,
          consumedAt: consumedAt),
    ];

    await tester.pumpWidget(_buildScreen(entries: entries, repo: repo));
    await tester.pump();

    // Name visible in the list tile title.
    expect(find.text('Morning Water'), findsOneWidget);

    // Volume fallback: '${volumeMl} ml' (fmt is null → widget fallback).
    // Source: today_drinks_screen.dart _EntryRow:
    //   fmt?.formatVolume(entry.volumeMl.toDouble()) ?? '${entry.volumeMl} ml'
    // fmt is null → fallback: '${entry.volumeMl} ml' = '350 ml'
    // Source: today_drinks_screen.dart _EntryRow subtitle build
    expect(find.textContaining('350 ml'), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 2b. Entry time label honours the device's 12h/24h preference
  //     (Parity Rulebook: "Time-of-day display format", issue #46)
  // -------------------------------------------------------------------------

  testWidgets('entry time renders 12h AM/PM when alwaysUse24HourFormat=false',
      (tester) async {
    final repo = _FakeRepo();
    // consumedAt = 09:30 UTC — widget displays local time; use UTC for a
    // deterministic display string that avoids timezone offsets in CI.
    final consumedAt = DateTime.utc(2026, 6, 23, 9, 30);
    final entries = [
      _entry(id: 'e1', name: 'Morning Water', consumedAt: consumedAt),
    ];

    await tester.pumpWidget(_buildScreen(
      entries: entries,
      repo: repo,
      alwaysUse24HourFormat: false,
    ));
    await tester.pump();

    expect(find.textContaining('9:30 AM'), findsWidgets);
  });

  testWidgets('entry time renders 24h when alwaysUse24HourFormat=true',
      (tester) async {
    final repo = _FakeRepo();
    final consumedAt = DateTime.utc(2026, 6, 23, 9, 30);
    final entries = [
      _entry(id: 'e1', name: 'Morning Water', consumedAt: consumedAt),
    ];

    await tester.pumpWidget(_buildScreen(
      entries: entries,
      repo: repo,
      alwaysUse24HourFormat: true,
    ));
    await tester.pump();

    expect(find.textContaining('09:30'), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 3. Entries appear in the order provided (reverse-chronological)
  //    The widget renders in list order; the repository guarantees DESC order.
  //    We pass a pre-ordered list and assert index 0 appears above index 1.
  // -------------------------------------------------------------------------

  testWidgets('entries appear in reverse-chronological order (newest first)',
      (tester) async {
    final repo = _FakeRepo();
    final newer = DateTime.utc(2026, 6, 23, 11, 0);
    final older = DateTime.utc(2026, 6, 23, 8, 0);

    // Pass newest-first as the repository would deliver.
    final entries = [
      _entry(
          id: 'e-new', name: 'Newer Drink', volumeMl: 200, consumedAt: newer),
      _entry(
          id: 'e-old', name: 'Older Drink', volumeMl: 150, consumedAt: older),
    ];

    await tester.pumpWidget(_buildScreen(entries: entries, repo: repo));
    await tester.pump();

    expect(find.text('Newer Drink'), findsOneWidget);
    expect(find.text('Older Drink'), findsOneWidget);

    // Newer entry must be rendered above the older one.
    final newerY = tester.getTopLeft(find.text('Newer Drink')).dy;
    final olderY = tester.getTopLeft(find.text('Older Drink')).dy;
    expect(
      newerY,
      lessThan(olderY),
      reason: 'Newer entry must appear above older entry — the widget renders '
          'entries in the order supplied (DESC order from repo)',
    );
  });

  // -------------------------------------------------------------------------
  // 4. Edit button opens the edit sheet
  // -------------------------------------------------------------------------

  testWidgets('tapping edit button opens the edit sheet', (tester) async {
    final repo = _FakeRepo();
    final entries = [
      _entry(
        id: 'e1',
        name: 'Edit Me',
        consumedAt: DateTime.utc(2026, 6, 23, 9, 0),
      ),
    ];

    await tester.pumpWidget(_buildScreen(entries: entries, repo: repo));
    await tester.pump();

    // One entry → one edit button (tooltip 'Edit').
    expect(find.byTooltip('Edit'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    // The edit sheet shows 'Edit drink' as its title.
    // Source: today_drinks_screen.dart _EditEntrySheetState.build
    expect(find.text('Edit drink'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4b. Edit sheet's time button honours the device's 12h/24h preference
  //     (Parity Rulebook: "Time-of-day display format", issue #46) — this
  //     also verifies MediaQuery reaches the modal bottom sheet route.
  // -------------------------------------------------------------------------

  testWidgets(
      'edit sheet time button renders 12h AM/PM when alwaysUse24HourFormat=false',
      (tester) async {
    final repo = _FakeRepo();
    final entries = [
      _entry(
        id: 'e1',
        name: 'Edit Me',
        consumedAt: DateTime.utc(2026, 6, 23, 9, 30),
      ),
    ];

    await tester.pumpWidget(_buildScreen(
      entries: entries,
      repo: repo,
      alwaysUse24HourFormat: false,
    ));
    await tester.pump();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, '9:30 AM'), findsOneWidget);
  });

  testWidgets(
      'edit sheet time button renders 24h when alwaysUse24HourFormat=true',
      (tester) async {
    final repo = _FakeRepo();
    final entries = [
      _entry(
        id: 'e1',
        name: 'Edit Me',
        consumedAt: DateTime.utc(2026, 6, 23, 9, 30),
      ),
    ];

    await tester.pumpWidget(_buildScreen(
      entries: entries,
      repo: repo,
      alwaysUse24HourFormat: true,
    ));
    await tester.pump();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, '09:30'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Delete button shows confirmation dialog
  // -------------------------------------------------------------------------

  testWidgets('tapping delete button shows confirmation dialog',
      (tester) async {
    final repo = _FakeRepo();
    final entries = [
      _entry(
        id: 'e1',
        name: 'Delete Me',
        consumedAt: DateTime.utc(2026, 6, 23, 9, 0),
      ),
    ];

    await tester.pumpWidget(_buildScreen(entries: entries, repo: repo));
    await tester.pump();

    expect(find.byTooltip('Delete'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    // The dialog asks "Delete entry?" — source: today_drinks_screen.dart
    // _EntryRow._confirmDelete AlertDialog title.
    expect(find.text('Delete entry?'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Confirming delete calls deleteDrinkEntry on the repository
  // -------------------------------------------------------------------------

  testWidgets('confirming delete dialog calls deleteDrinkEntry with entry id',
      (tester) async {
    final repo = _FakeRepo();
    const entryId = 'e-to-delete';
    final entries = [
      _entry(
        id: entryId,
        name: 'Deletable Drink',
        consumedAt: DateTime.utc(2026, 6, 23, 9, 0),
      ),
    ];

    await tester.pumpWidget(_buildScreen(entries: entries, repo: repo));
    await tester.pump();

    // Open the confirmation dialog.
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete entry?'), findsOneWidget);

    // Confirm deletion via the FilledButton labelled 'Delete'.
    // Source: today_drinks_screen.dart _EntryRow._confirmDelete AlertDialog.
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      repo.deletedIds,
      contains(entryId),
      reason:
          'deleteDrinkEntry must be called with the entry id after the user '
          'confirms deletion (S6 spec: soft-delete)',
    );
  });

  // -------------------------------------------------------------------------
  // 7. Session-attached alcoholic entries are read-only (no Edit/Delete)
  //
  // Source: design/user-experience.md §S6: "Tapping a row opens an
  // edit/delete affordance for that entry, for every entry except an
  // alcoholic drink attached to a Party Session (partySessionId set) — those
  // rows are read-only here." A normal (non-session-attached) entry, and an
  // orphan alcoholic entry (isAlcoholic but no partySessionId), must still
  // show both actions — the read-only rule keys off partySessionId, not off
  // beverageType.isAlcoholic alone.
  // -------------------------------------------------------------------------

  testWidgets(
    'session-attached alcoholic entry has no Edit/Delete tooltips, while a '
    'normal entry and an orphan alcoholic entry in the same list still do',
    (tester) async {
      final repo = _FakeRepo();
      final now = DateTime.utc(2026, 6, 23, 12, 0);

      // Alcoholic entry attached to a Party Session — must render read-only.
      final sessionAttached = DrinkEntry(
        id: 'e-session',
        name: 'Session Beer',
        beverageType: BeverageType.beer, // isAlcoholic == true
        volumeMl: 330,
        consumedAt: DateTime.utc(2026, 6, 23, 10, 0),
        createdAt: now,
        updatedAt: now,
        iconKey: 'beer_glass',
        iconColor: '#d97706',
        partySessionId: 'test-session-1',
      );

      // Ordinary hydration entry — must remain fully editable/deletable.
      final normal = _entry(
        id: 'e-normal',
        name: 'Plain Water',
        consumedAt: DateTime.utc(2026, 6, 23, 9, 0),
      );

      // Orphan alcoholic entry — alcoholic but NOT session-attached
      // (partySessionId == null). This is the discriminating case: the S6
      // read-only rule keys off partySessionId, not off isAlcoholic alone
      // (design/user-experience.md §S6 / design/party-session.md §Logging
      // alcohol when no session is active — orphan alcoholic entries are
      // fully editable here). Without this case a regression that made
      // _isSessionAttached depend only on beverageType.isAlcoholic would
      // still pass the two-entry version of this test.
      final orphanAlcoholic = DrinkEntry(
        id: 'e-orphan',
        name: 'Orphan Beer',
        beverageType: BeverageType.beer,
        volumeMl: 330,
        consumedAt: DateTime.utc(2026, 6, 23, 8, 0),
        createdAt: now,
        updatedAt: now,
        iconKey: 'beer_glass',
        iconColor: '#d97706',
        // partySessionId intentionally omitted (null) — orphan.
      );

      await tester.pumpWidget(
        _buildScreen(
          entries: [sessionAttached, normal, orphanAlcoholic],
          repo: repo,
        ),
      );
      await tester.pump();

      // All three rows render.
      expect(find.text('Session Beer'), findsOneWidget);
      expect(find.text('Plain Water'), findsOneWidget);
      expect(find.text('Orphan Beer'), findsOneWidget);

      // Exactly two Edit and two Delete tooltips exist — one pair each for
      // the normal entry and the orphan alcoholic entry; none for the
      // session-attached alcoholic entry, which renders read-only.
      expect(find.byTooltip('Edit'), findsNWidgets(2));
      expect(find.byTooltip('Delete'), findsNWidgets(2));
    },
  );

  // -------------------------------------------------------------------------
  // 8. ABV and price fields (aligning S6 with S9's field set, minus name)
  // -------------------------------------------------------------------------

  testWidgets(
    'edit sheet shows 2 fields (volume, price) for a non-alcoholic entry — '
    'no ABV field',
    (tester) async {
      final repo = _FakeRepo();
      final entries = [
        _entry(
            id: 'e1',
            name: 'Water',
            consumedAt: DateTime.utc(2026, 6, 23, 9, 0)),
      ];

      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen(entries: entries, repo: repo));
      await tester.pump();
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('ABV (%)'), findsNothing);
    },
  );

  testWidgets(
    'edit sheet shows 3 fields (volume, ABV, price) for an orphan alcoholic '
    'entry, pre-filled from the entry; saving calls updateDrinkEntry with '
    'the edited values',
    (tester) async {
      final repo = _FakeRepo();
      final now = DateTime.utc(2026, 6, 23, 12, 0);
      final entry = DrinkEntry(
        id: 'e-beer',
        name: 'Orphan Beer',
        beverageType: BeverageType.beer,
        volumeMl: 330,
        abvPercent: 5.0,
        priceMinor: 450,
        currency: 'EUR',
        consumedAt: DateTime.utc(2026, 6, 23, 20, 0),
        createdAt: now,
        updatedAt: now,
        iconKey: 'beer_glass',
        iconColor: '#d97706',
      );

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildScreen(entries: [entry], repo: repo));
      await tester.pump();
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));
      // Declaration order in EntryEditSheet.build: volume, abv, price.
      expect(
          tester.widget<TextField>(textFields.at(0)).controller!.text, '330');
      expect(
          tester.widget<TextField>(textFields.at(1)).controller!.text, '5.0');
      expect(
          tester.widget<TextField>(textFields.at(2)).controller!.text, '4.50');

      await tester.enterText(textFields.at(0), '500');
      await tester.enterText(textFields.at(1), '8.0');
      await tester.enterText(textFields.at(2), '6.00');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repo.updateDrinkEntryCalls, hasLength(1));
      final call = repo.updateDrinkEntryCalls.single;
      expect(call.id, 'e-beer');
      expect(call.name, isNull, reason: 'S6 does not edit name');
      expect(call.volumeMl, 500);
      expect(call.abvPercent, 8.0);
      expect(call.priceMinor, const Optional.value(600));
      expect(call.currency, const Optional.value('EUR'));
    },
  );
}
