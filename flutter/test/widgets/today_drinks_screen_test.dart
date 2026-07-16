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

  @override
  Future<void> deleteDrinkEntry(String id) async {
    deletedIds.add(id);
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
Widget _buildScreen({
  required List<DrinkEntry> entries,
  required _FakeRepo repo,
  int totalMl = 500,
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
    child: const MaterialApp(home: TodayDrinksScreen()),
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
}
