// Widget tests for the Today "Log a drink" grid (issue #78).
//
// Coverage:
//  1. Grid shows at most kLogADrinkGridSize (8) preset tiles even when more
//     than 8 visible presets are provided.
//  2. Tapping a tile calls DrinksRepository.logDrink with that preset.
//  3. Changing the sort-mode dropdown calls
//     PreferencesRepository.updateDrinkSortMode with the selected mode.
//  4. Ranking: the grid order reflects rankedVisiblePresetsProvider (usage
//     stats + selected mode), not the raw visiblePresetsProvider order.
//  5. Responsive: crossAxisCount differs between a narrow and a wide test
//     surface, both below kTabletBreakpointWidth (840dp) so the Log-a-drink
//     section's own available width — not the full screen width — drives
//     the column count (today_screen.dart _gridColumnsForWidth doc comment).
//
// Harness mirrors goal_celebration_test.dart's _buildTodayScreen, plus a
// recording DrinksRepository/PreferencesRepository fake (same pattern as
// log_drink_sheet_test.dart's _FakeDrinksRepo: a real
// AppDatabase(NativeDatabase.memory()) passed to super, methods overridden
// to record instead of touching the DB).

import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/optional.dart';
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/models/user_profile.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/party_session_repository.dart';
import 'package:drinks_mate/src/repository/preferences_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/today_screen.dart';
import 'package:drinks_mate/src/services/app_info_service.dart';
import 'package:drinks_mate/src/services/goal_celebration_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeDrinksRepo extends DrinksRepository {
  _FakeDrinksRepo() : super(AppDatabase(NativeDatabase.memory()));

  final List<DrinkPreset> logDrinkCalls = [];

  @override
  Future<String> logDrink({
    required DrinkPreset preset,
    String? id,
    String? name,
    int? volumeMl,
    double? abvPercent,
    Optional<int?> priceMinor = const Optional.absent(),
    Optional<String?> currency = const Optional.absent(),
    DateTime? consumedAt,
  }) async {
    logDrinkCalls.add(preset);
    return id ?? 'fake-entry-id';
  }

  final List<String> deleteDrinkEntryCalls = [];

  @override
  Future<void> deleteDrinkEntry(String id) async {
    deleteDrinkEntryCalls.add(id);
  }
}

class _FakePreferencesRepo extends PreferencesRepository {
  _FakePreferencesRepo() : super(AppDatabase(NativeDatabase.memory()));

  final List<PresetSortMode> updateDrinkSortModeCalls = [];

  @override
  Future<void> updateDrinkSortMode(PresetSortMode mode) async {
    updateDrinkSortModeCalls.add(mode);
  }
}

/// Records logAlcoholicDrink/startSession calls instead of touching the DB —
/// mirrors party_screen_test.dart's `_FakePartySessionRepo`.
class _FakePartySessionRepo extends PartySessionRepository {
  _FakePartySessionRepo() : super(AppDatabase(NativeDatabase.memory()));

  final List<({String sessionId, String presetId})> logAlcoholicDrinkCalls = [];
  final List<DateTime?> startSessionCalls = [];

  /// Deterministic id so tests can assert on it without reading it back off
  /// a returned value threaded through several awaits.
  String nextSessionId = 'new-session-1';

  /// Tracks the most recently started fake session so [getSessionById] (used
  /// by the start-session flow to refresh its in-memory copy after the
  /// pricing prompt) can resolve it without touching the real DB.
  PartySession? _lastSession;

  @override
  Future<PartySession> startSession({
    DateTime? startedAt,
    bool useSessionPrices = false,
    String? tokenName,
    int? tokenValueMinor,
    String? tokenValueCurrency,
    DateTime? now,
  }) async {
    startSessionCalls.add(startedAt);
    final at = now ?? DateTime.now();
    final session = PartySession(
      id: nextSessionId,
      startedAt: startedAt ?? at,
      useSessionPrices: useSessionPrices,
      tokenName: tokenName,
      tokenValueMinor: tokenValueMinor,
      tokenValueCurrency: tokenValueCurrency,
      createdAt: at,
      updatedAt: at,
    );
    _lastSession = session;
    return session;
  }

  @override
  Future<PartySession> getSessionById(String id) async {
    final session = _lastSession;
    if (session != null && session.id == id) return session;
    throw StateError('PartySession $id not found.');
  }

  @override
  Future<ResolvedDrinkPrice> resolvePrice({
    required PartySession session,
    required DrinkPreset preset,
  }) async =>
      const ResolvedDrinkPrice();

  @override
  Future<DrinkEntry> logAlcoholicDrink({
    required DrinkPreset preset,
    required String sessionId,
    String? id,
    String? name,
    int? volumeMl,
    double? abvPercent,
    DateTime? consumedAt,
    int? priceMinor,
    String? currency,
    int? priceTokens,
    int? tokenValueMinor,
    String? tokenValueCurrency,
    bool isManualPriceOverride = false,
    DateTime? now,
  }) async {
    logAlcoholicDrinkCalls.add((sessionId: sessionId, presetId: preset.id));
    final at = now ?? DateTime.now();
    return DrinkEntry(
      id: id ?? 'fake-party-entry-id',
      name: name ?? preset.name,
      beverageType: preset.beverageType,
      volumeMl: volumeMl ?? preset.volumeMl,
      abvPercent: abvPercent ?? preset.abvPercent,
      partySessionId: sessionId,
      consumedAt: consumedAt ?? at,
      createdAt: at,
      updatedAt: at,
    );
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

DrinkPreset _preset(
  String id,
  String name, {
  required int sortOrder,
  BeverageType beverageType = BeverageType.water,
}) =>
    DrinkPreset(
      id: id,
      name: name,
      beverageType: beverageType,
      volumeMl: 200,
      iconKey: 'glass',
      iconColor: '#3b82f6',
      isUserCreated: false,
      isHidden: false,
      sortOrder: sortOrder,
    );

UserPreferences _makePrefs({
  PresetSortMode drinkSortMode = PresetSortMode.recentlyUsed,
}) {
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
    drinkSortMode: drinkSortMode,
    installedAt: epoch,
    createdAt: epoch,
    updatedAt: epoch,
  );
}

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// 18+ profile (party-session.md §Starting a session gate) — used by the
/// "Start session" toast-action tests, which exercise
/// `startPartySessionFlow`'s under-18 check.
UserProfile _makeAdultProfile() => UserProfile(
      id: 'profile-1',
      gender: 'male',
      weightKg: 75,
      heightCm: 180,
      birthDate: '1996-06-01',
      createdAt: _epoch,
      updatedAt: _epoch,
    );

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _buildTodayScreen({
  required List<DrinkPreset> visiblePresets,
  required UserPreferences prefs,
  required DrinksRepository drinksRepo,
  required PreferencesRepository preferencesRepo,
  Map<String, PresetUsageStats> usage = const {},
  // party-session.md §Logging from Today (issue #85): an active session is
  // null by default — most existing tests never touch Party Session state.
  PartySession? activeSession,
  PartySessionRepository? partyRepo,
  UserProfile? profile,
}) {
  return ProviderScope(
    overrides: [
      drinksRepositoryProvider.overrideWithValue(drinksRepo),
      preferencesRepositoryProvider.overrideWithValue(preferencesRepo),
      if (partyRepo != null)
        partySessionRepositoryProvider.overrideWithValue(partyRepo),
      activePartySessionProvider.overrideWith(
        (_) => Stream.value(activeSession),
      ),
      userProfileProvider.overrideWith((_) => Stream.value(profile)),
      visiblePresetsProvider.overrideWith(
        (_) => Stream.value(visiblePresets),
      ),
      presetUsageStatsProvider.overrideWith((_) => Stream.value(usage)),
      todayTotalMlProvider.overrideWith((_) => Stream.value(0)),
      sevenDayAverageMlProvider.overrideWith((_) => Stream.value(0.0)),
      sevenDayDaysOnGoalProvider.overrideWith((_) => Stream.value(0)),
      userPreferencesProvider.overrideWith((_) => Stream.value(prefs)),
      goalCelebrationGuardProvider.overrideWithValue(
        InMemoryGoalCelebrationGuard(),
      ),
    ],
    child: const MaterialApp(home: TodayScreen()),
  );
}

/// Same overrides as [_buildTodayScreen], but returns the underlying
/// [ProviderContainer] with `userProfileProvider`/`activePartySessionProvider`
/// pre-warmed (`.future` awaited) before any pump.
///
/// Needed only by tests that exercise `_quickLog`'s `ref.read(...)` of these
/// two providers (today_screen.dart, issue #85): in the real app both are
/// already warm by the time Today is interactive, because [AppShell]'s
/// `IndexedStack` builds `PartyScreen` (which `ref.watch`es both) alongside
/// `TodayScreen` from app start (shell.dart doc comment: "keeps all three
/// screens alive"). This test pumps `TodayScreen` in isolation, so without
/// pre-warming, the very first `ref.read` on a freshly-created StreamProvider
/// observes `AsyncLoading` (valueOrNull == null) until a microtask flushes —
/// which is too late for `_quickLog`'s synchronous-looking `ref.read(...)`
/// checks and `startPartySessionFlow`'s `if (profile == null) return null;`
/// guard.
Future<ProviderContainer> _buildWarmContainer({
  required List<DrinkPreset> visiblePresets,
  required UserPreferences prefs,
  required DrinksRepository drinksRepo,
  required PreferencesRepository preferencesRepo,
  PartySession? activeSession,
  PartySessionRepository? partyRepo,
  UserProfile? profile,
}) async {
  final container = ProviderContainer(
    overrides: [
      drinksRepositoryProvider.overrideWithValue(drinksRepo),
      preferencesRepositoryProvider.overrideWithValue(preferencesRepo),
      if (partyRepo != null)
        partySessionRepositoryProvider.overrideWithValue(partyRepo),
      activePartySessionProvider.overrideWith(
        (_) => Stream.value(activeSession),
      ),
      userProfileProvider.overrideWith((_) => Stream.value(profile)),
      visiblePresetsProvider.overrideWith(
        (_) => Stream.value(visiblePresets),
      ),
      presetUsageStatsProvider.overrideWith(
        (_) => Stream.value(const <String, PresetUsageStats>{}),
      ),
      todayTotalMlProvider.overrideWith((_) => Stream.value(0)),
      sevenDayAverageMlProvider.overrideWith((_) => Stream.value(0.0)),
      sevenDayDaysOnGoalProvider.overrideWith((_) => Stream.value(0)),
      userPreferencesProvider.overrideWith((_) => Stream.value(prefs)),
      goalCelebrationGuardProvider.overrideWithValue(
        InMemoryGoalCelebrationGuard(),
      ),
    ],
  );
  await container.read(userProfileProvider.future);
  await container.read(activePartySessionProvider.future);
  return container;
}

Future<void> _pumpTodayScreen(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TodayScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Grid caps at kLogADrinkGridSize tiles
  // -------------------------------------------------------------------------

  testWidgets(
    'grid shows at most kLogADrinkGridSize preset tiles even when more '
    'visible presets are provided',
    (tester) async {
      // Source: today_screen.dart — "kLogADrinkGridSize — How many
      // top-ranked presets the grid shows (features.md F14 §Sort modes)."
      final presets = List.generate(
        kLogADrinkGridSize + 4,
        (i) => _preset('p$i', 'Preset $i', sortOrder: i),
      );
      await tester.pumpWidget(
        _buildTodayScreen(
          visiblePresets: presets,
          prefs: _makePrefs(),
          drinksRepo: _FakeDrinksRepo(),
          preferencesRepo: _FakePreferencesRepo(),
        ),
      );
      await tester.pumpAndSettle();

      // GridView.builder is lazy — with 12 presets in a bounded viewport not
      // every tile is necessarily mounted, so assert against the delegate's
      // childCount rather than counting rendered widgets.
      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.childCount, kLogADrinkGridSize);
    },
  );

  // -------------------------------------------------------------------------
  // 2. Tapping a tile logs the drink
  // -------------------------------------------------------------------------

  testWidgets('tapping a preset tile calls logDrink with that preset', (
    tester,
  ) async {
    final preset = _preset('p1', 'Still Water', sortOrder: 1);
    final drinksRepo = _FakeDrinksRepo();
    await tester.pumpWidget(
      _buildTodayScreen(
        visiblePresets: [preset],
        prefs: _makePrefs(),
        drinksRepo: drinksRepo,
        preferencesRepo: _FakePreferencesRepo(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Still Water'));
    await tester.pumpAndSettle();

    expect(drinksRepo.logDrinkCalls, hasLength(1));
    expect(drinksRepo.logDrinkCalls.single.id, 'p1');
  });

  testWidgets(
    'tapping a preset tile shows a Logged toast with an Undo action that '
    'deletes the entry just logged (user-experience.md §S1: "Logged toast '
    '... with an inline Undo affordance")',
    (tester) async {
      final preset = _preset('p1', 'Still Water', sortOrder: 1);
      final drinksRepo = _FakeDrinksRepo();
      await tester.pumpWidget(
        _buildTodayScreen(
          visiblePresets: [preset],
          prefs: _makePrefs(),
          drinksRepo: drinksRepo,
          preferencesRepo: _FakePreferencesRepo(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Still Water'));
      await tester.pumpAndSettle();

      expect(find.text('Logged Still Water'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Undo'), findsOneWidget);

      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();

      expect(drinksRepo.deleteDrinkEntryCalls, ['fake-entry-id']);
    },
  );

  // -------------------------------------------------------------------------
  // 2b. Alcoholic quick-log — Party Session attach/orphan branching (issue
  // #85: today_screen.dart's _quickLog checks activePartySessionProvider
  // before logging an alcoholic preset).
  // -------------------------------------------------------------------------

  group(
      'Alcoholic quick-log — Party Session branching (party-session.md '
      '§Logging from Today)', () {
    testWidgets(
      'no active session: logs via DrinksRepository as an orphan, toast '
      'shows "Start session" (not Undo)',
      (tester) async {
        final preset = _preset(
          'p1',
          'Beer',
          sortOrder: 1,
          beverageType: BeverageType.beer,
        );
        final drinksRepo = _FakeDrinksRepo();
        final partyRepo = _FakePartySessionRepo();
        final container = await _buildWarmContainer(
          visiblePresets: [preset],
          prefs: _makePrefs(),
          drinksRepo: drinksRepo,
          preferencesRepo: _FakePreferencesRepo(),
          partyRepo: partyRepo,
          activeSession: null,
        );
        addTearDown(container.dispose);
        await _pumpTodayScreen(tester, container);

        await tester.tap(find.text('Beer'));
        await tester.pumpAndSettle();

        expect(find.text('Logged Beer'), findsOneWidget);
        // Orphan entry — logged via the plain DrinksRepository, not the
        // Party Session repository.
        expect(drinksRepo.logDrinkCalls, hasLength(1));
        expect(partyRepo.logAlcoholicDrinkCalls, isEmpty);
        // "Start session" fills the toast's one action slot instead of
        // Undo — party_session.md §Logging from Today.
        expect(find.widgetWithText(SnackBarAction, 'Undo'), findsNothing);
        expect(
          find.widgetWithText(SnackBarAction, 'Start session'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping "Start session" on the orphan toast invokes '
      'startPartySessionFlow, which starts a new Party Session',
      (tester) async {
        final preset = _preset(
          'p1',
          'Beer',
          sortOrder: 1,
          beverageType: BeverageType.beer,
        );
        final drinksRepo = _FakeDrinksRepo();
        final partyRepo = _FakePartySessionRepo();
        final container = await _buildWarmContainer(
          visiblePresets: [preset],
          prefs: _makePrefs(),
          drinksRepo: drinksRepo,
          preferencesRepo: _FakePreferencesRepo(),
          partyRepo: partyRepo,
          activeSession: null,
          // 18+ with a birthDate already set — startPartySessionFlow skips
          // straight to repo.startSession() (party_session_flows.dart).
          profile: _makeAdultProfile(),
        );
        addTearDown(container.dispose);
        await _pumpTodayScreen(tester, container);

        await tester.tap(find.text('Beer'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(SnackBarAction, 'Start session'));
        await tester.pumpAndSettle();

        // Post-start pricing prompt (party-session.md §Starting a session);
        // skip it to complete the flow.
        expect(find.text('Set up party prices?'), findsOneWidget);
        await tester.tap(find.text('Skip — use regular prices'));
        await tester.pumpAndSettle();

        expect(partyRepo.startSessionCalls, hasLength(1));
      },
    );

    testWidgets(
      'active session: attaches via PartySessionRepository.logAlcoholicDrink '
      '(partySessionId set), toast shows the ordinary Undo action (not '
      '"Start session")',
      (tester) async {
        final preset = _preset(
          'p1',
          'Beer',
          sortOrder: 1,
          beverageType: BeverageType.beer,
        );
        final drinksRepo = _FakeDrinksRepo();
        final partyRepo = _FakePartySessionRepo();
        final session = PartySession(
          id: 'active-session-1',
          startedAt: _epoch,
          useSessionPrices: false,
          createdAt: _epoch,
          updatedAt: _epoch,
        );
        final container = await _buildWarmContainer(
          visiblePresets: [preset],
          prefs: _makePrefs(),
          drinksRepo: drinksRepo,
          preferencesRepo: _FakePreferencesRepo(),
          partyRepo: partyRepo,
          activeSession: session,
        );
        addTearDown(container.dispose);
        await _pumpTodayScreen(tester, container);

        await tester.tap(find.text('Beer'));
        await tester.pumpAndSettle();

        expect(find.text('Logged Beer'), findsOneWidget);
        expect(drinksRepo.logDrinkCalls, isEmpty);
        expect(partyRepo.logAlcoholicDrinkCalls, [
          (sessionId: 'active-session-1', presetId: 'p1'),
        ]);
        // Attached to an active session — the ordinary Undo action shows,
        // not "Start session" (issue #85: this now includes alcoholic
        // entries attached to an active session, which previously got no
        // action at all).
        expect(
          find.widgetWithText(SnackBarAction, 'Start session'),
          findsNothing,
        );
        expect(find.widgetWithText(SnackBarAction, 'Undo'), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 3. Sort-mode dropdown writes the new mode
  // -------------------------------------------------------------------------

  testWidgets(
    'changing the sort-mode dropdown calls updateDrinkSortMode with the '
    'selected mode',
    (tester) async {
      final preset = _preset('p1', 'Still Water', sortOrder: 1);
      final preferencesRepo = _FakePreferencesRepo();
      await tester.pumpWidget(
        _buildTodayScreen(
          visiblePresets: [preset],
          prefs: _makePrefs(), // default: recentlyUsed
          drinksRepo: _FakeDrinksRepo(),
          preferencesRepo: preferencesRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<PresetSortMode>));
      await tester.pumpAndSettle();
      // The dropdown's closed button already renders the current selection's
      // text ("Recently used"), and DropdownButton pre-builds every item off
      // stage for layout purposes — use `.last` to hit the open overlay's
      // menu item, not an off-stage duplicate.
      await tester.tap(find.text('Most used').last);
      await tester.pumpAndSettle();

      expect(preferencesRepo.updateDrinkSortModeCalls, [
        PresetSortMode.mostUsed,
      ]);
    },
  );

  // -------------------------------------------------------------------------
  // 4. Ranking actually changes tile order
  // -------------------------------------------------------------------------

  testWidgets(
    'grid order reflects rankedVisiblePresetsProvider (mostUsed mode), not '
    'the raw visiblePresetsProvider order',
    (tester) async {
      // Bravo has the lowest sortOrder priority (sortOrder 2) but the
      // highest usage count, so mostUsed mode must rank it before Alpha
      // (sortOrder 1) despite Alpha coming first in visiblePresetsProvider.
      final alpha = _preset('alpha', 'Alpha', sortOrder: 1);
      final bravo = _preset('bravo', 'Bravo', sortOrder: 2);
      final charlie = _preset('charlie', 'Charlie', sortOrder: 3);

      await tester.pumpWidget(
        _buildTodayScreen(
          visiblePresets: [alpha, bravo, charlie],
          prefs: _makePrefs(drinkSortMode: PresetSortMode.mostUsed),
          drinksRepo: _FakeDrinksRepo(),
          preferencesRepo: _FakePreferencesRepo(),
          usage: const {'bravo': PresetUsageStats(count30d: 10)},
        ),
      );
      await tester.pumpAndSettle();

      final bravoX = tester.getTopLeft(find.text('Bravo')).dx;
      final alphaX = tester.getTopLeft(find.text('Alpha')).dx;
      expect(
        bravoX,
        lessThan(alphaX),
        reason: 'Bravo (count30d=10) must rank before Alpha (count30d=0) '
            'under mostUsed mode, even though Alpha has the lower sortOrder',
      );
    },
  );

  // -------------------------------------------------------------------------
  // 5. Responsive column count
  // -------------------------------------------------------------------------

  testWidgets(
    'grid crossAxisCount differs between a narrow and a wide test surface, '
    'both below kTabletBreakpointWidth so the section (not full screen) '
    'width drives it',
    (tester) async {
      final preset = _preset('p1', 'Still Water', sortOrder: 1);
      final drinksRepo = _FakeDrinksRepo();
      final preferencesRepo = _FakePreferencesRepo();

      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Narrow, stacked layout (< kTabletBreakpointWidth): section spans the
      // full 400dp screen width; minus the 16dp horizontal padding on each
      // side, _gridColumnsForWidth(~368) → 2 columns.
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(
        _buildTodayScreen(
          visiblePresets: [preset],
          prefs: _makePrefs(),
          drinksRepo: drinksRepo,
          preferencesRepo: preferencesRepo,
        ),
      );
      await tester.pumpAndSettle();
      final narrowDelegate = tester
          .widget<GridView>(find.byType(GridView))
          .gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(narrowDelegate.crossAxisCount, 2);

      // Wider, still stacked (800 < 840): section spans the full 800dp
      // screen width; minus padding, _gridColumnsForWidth(~768) → 3 columns.
      tester.view.physicalSize = const Size(800, 800);
      await tester.pumpWidget(
        _buildTodayScreen(
          visiblePresets: [preset],
          prefs: _makePrefs(),
          drinksRepo: drinksRepo,
          preferencesRepo: preferencesRepo,
        ),
      );
      await tester.pumpAndSettle();
      final wideDelegate = tester
          .widget<GridView>(find.byType(GridView))
          .gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(wideDelegate.crossAxisCount, 3);
    },
  );

  // ---------------------------------------------------------------------------
  // "Settings opened" auto-end trigger point (issue #94)
  //
  // party-session.md §Auto-end is computed lazily lists "Settings opened" as
  // one of the five trigger points; today_screen.dart's `_settingsButton`
  // calls PartySessionRepository.checkAndApplyAutoEnd() immediately before
  // pushing SettingsScreen. Unlike the other tests in this file, this one
  // wires a REAL PartySessionRepository (backed by a real in-memory
  // AppDatabase) into partySessionRepositoryProvider instead of a fake, so
  // the retroactive end is asserted against actual DB state — proving the
  // gear icon's onPressed really runs the check, not just that the method
  // exists on the repository (already covered by
  // party_session_repository_test.dart's "lazy 12h auto-end" group).
  // ---------------------------------------------------------------------------

  group('TodayScreen — Settings-opened auto-end trigger', () {
    testWidgets(
      'tapping the settings gear retroactively ends a session whose 12h '
      'mark has already passed',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final realPartyRepo = PartySessionRepository(db);

        // Source: party-session.md §Ending a session — "12 hours after
        // startedAt if no alcoholic drinks were logged"; endedAt is the mark,
        // not "now". Truncated to whole-second precision — Drift's default
        // DateTime column stores a unix-seconds INTEGER, so a raw
        // DateTime.now() would never round-trip byte-for-byte.
        final nowSeconds =
            DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 * 1000;
        final startedAt = DateTime.fromMillisecondsSinceEpoch(
          nowSeconds,
          isUtc: true,
        ).subtract(const Duration(hours: 20));
        final session = await realPartyRepo.startSession(
          now: startedAt,
          startedAt: startedAt,
        );
        final mark = startedAt.add(const Duration(hours: 12));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              drinksRepositoryProvider.overrideWithValue(
                _FakeDrinksRepo(),
              ),
              preferencesRepositoryProvider.overrideWithValue(
                _FakePreferencesRepo(),
              ),
              partySessionRepositoryProvider.overrideWithValue(
                realPartyRepo,
              ),
              activePartySessionProvider.overrideWith(
                (_) => Stream.value(null),
              ),
              userProfileProvider.overrideWith((_) => Stream.value(null)),
              visiblePresetsProvider.overrideWith(
                (_) => Stream.value(const <DrinkPreset>[]),
              ),
              // SettingsScreen (pushed after the gear tap) watches this
              // directly — without an override it hits _FakeDrinksRepo's own
              // real (if otherwise-unused) Drift stream, which leaves a
              // pending cleanup Timer when the route is popped mid-test.
              visibleNonAlcoholicPresetsProvider.overrideWith(
                (_) => Stream.value(const <DrinkPreset>[]),
              ),
              presetUsageStatsProvider.overrideWith(
                (_) => Stream.value(const <String, PresetUsageStats>{}),
              ),
              todayTotalMlProvider.overrideWith((_) => Stream.value(0)),
              sevenDayAverageMlProvider.overrideWith(
                (_) => Stream.value(0.0),
              ),
              sevenDayDaysOnGoalProvider.overrideWith(
                (_) => Stream.value(0),
              ),
              userPreferencesProvider.overrideWith(
                (_) => Stream.value(_makePrefs()),
              ),
              goalCelebrationGuardProvider.overrideWithValue(
                InMemoryGoalCelebrationGuard(),
              ),
              appInfoServiceProvider.overrideWithValue(
                const FakeAppInfoService(),
              ),
            ],
            child: const MaterialApp(home: TodayScreen()),
          ),
        );
        await tester.pump();

        expect((await db.getPartySessionById(session.id))!.endedAt, isNull);

        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();

        final row = await db.getPartySessionById(session.id);
        expect(row!.endedAt, isNotNull);
        expect(row.endedAt!.isAtSameMomentAs(mark), isTrue);
        expect(row.endReason, PartySessionEndReason.autoTimeout.stored);
        expect(await db.getActiveSession(), isNull);
      },
    );
  });
}
