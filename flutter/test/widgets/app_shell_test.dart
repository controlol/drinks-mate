// Widget tests for AppShell's two lazy 12h party-session auto-end trigger
// points it owns directly (issue #94; party-session.md §Auto-end is
// computed lazily lists five trigger points total — the other three
// (drink logged, Settings opened) are covered at their own call sites:
// drinks_repository_test.dart / party_session_repository_test.dart for
// "drink logged", and today_screen_test.dart / party_screen_test.dart /
// history_screen_test.dart for "Settings opened").
//
// Coverage:
//  1. Cold start (initState, covering "Today tab open" at app launch):
//     a REAL PartySessionRepository backed by a real in-memory AppDatabase
//     is wired in, seeded with a session whose 12h mark has already passed
//     — the very first pump must retroactively end it. This is the one
//     end-to-end (real DB) test in this file; it is the discriminating one
//     because nothing else in AppShell runs before the first frame.
//  2. Tab switch: a call-counting spy PartySessionRepository (mirrors
//     today_screen_test.dart's _FakePartySessionRepo pattern) proves
//     NavigationBar.onDestinationSelected calls checkAndApplyAutoEnd() again
//     on every tab change, distinct from the one initState already made.
//     A spy (not staleness) is used here because AppShell always calls
//     checkAndApplyAutoEnd() with no `now` override (real wall clock), so a
//     session can't be made to "become stale" between two points in a test.
//  3. App resumed: the same spy proves didChangeAppLifecycleState(resumed)
//     calls the check too. AppLifecycleState.handleAppLifecycleStateChanged
//     is a no-op when dispatched with the binding's current state (starts
//     `null` in tests, so the first dispatch already changes it) — this
//     test transitions through `inactive` first to also exercise the case
//     where the state genuinely differs, matching how the OS actually
//     backgrounds/foregrounds an app.
//  4. App resumed also invalidates the day-window providers (issue #95):
//     todayTotalMlProvider, sevenDayAverageMlProvider,
//     sevenDayDaysOnGoalProvider and presetUsageStatsProvider are overridden
//     with call-counting `create` callbacks (Riverpod re-invokes `create` on
//     every ref.invalidate, distinct from a rebuild for some other reason)
//     to prove AppShell._invalidateDayWindowProviders() actually runs on
//     resume, and does NOT run on `inactive` alone or on a tab switch. The
//     fifth provider in that method, todayEntriesProvider, is only watched
//     by today_drinks_screen.dart, which AppShell never mounts — it is never
//     created in this widget tree, so ref.invalidate on it is an
//     unobservable no-op here and is intentionally left unspied.
//
// Provider override list mirrors flutter/test/widget_test.dart's
// `_appWithFakeStreams` — AppShell's IndexedStack builds Today/Party/History
// eagerly, so every Drift stream provider all three screens touch must be
// overridden to avoid opening a real on-disk AppDatabase or leaving a
// pending Drift QueryStream cleanup Timer at teardown.

import 'package:core/core.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/bac_daily_bucket.dart';
import 'package:drinks_mate/src/models/daily_bucket.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/session_day_summary.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/navigation/shell.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/party_session_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/services/app_info_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Records every checkAndApplyAutoEnd() call instead of touching a DB —
/// mirrors today_screen_test.dart's `_FakePartySessionRepo` pattern. Used by
/// the tab-switch/resumed tests, which only need to prove the call happens
/// (AppShell's `_checkAutoEnd()` has no injectable `now`, so staleness can't
/// be engineered to appear "between" two points in a single test run).
class _AutoEndSpyPartySessionRepo extends PartySessionRepository {
  _AutoEndSpyPartySessionRepo() : super(AppDatabase(NativeDatabase.memory()));

  int checkAndApplyAutoEndCalls = 0;

  @override
  Future<void> checkAndApplyAutoEnd({DateTime? now}) async {
    checkAndApplyAutoEndCalls++;
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

/// Builds a testable [AppShell] with every Drift stream provider Today/
/// Party/History touch overridden to a static value, plus [partyRepo] wired
/// into [partySessionRepositoryProvider] — the one provider this file's
/// first three tests actually care about.
///
/// The four optional overrides let the issue #95 resume-invalidation test
/// substitute call-counting `create` callbacks for
/// [todayTotalMlProvider]/[sevenDayAverageMlProvider]/
/// [sevenDayDaysOnGoalProvider]/[presetUsageStatsProvider] while every other
/// test in this file keeps the plain static-value stubs below.
Widget _buildAppShell(
  PartySessionRepository partyRepo, {
  Override? todayTotalMlOverride,
  Override? sevenDayAverageMlOverride,
  Override? sevenDayDaysOnGoalOverride,
  Override? presetUsageStatsOverride,
}) {
  return ProviderScope(
    overrides: [
      drinksRepositoryProvider.overrideWithValue(
        DrinksRepository(AppDatabase(NativeDatabase.memory())),
      ),
      partySessionRepositoryProvider.overrideWithValue(partyRepo),
      visiblePresetsProvider.overrideWith(
        (_) => Stream.value(const <DrinkPreset>[]),
      ),
      presetUsageStatsOverride ??
          presetUsageStatsProvider.overrideWith(
            (_) => Stream.value(const <String, PresetUsageStats>{}),
          ),
      todayTotalMlOverride ??
          todayTotalMlProvider.overrideWith((_) => Stream.value(0)),
      sevenDayAverageMlOverride ??
          sevenDayAverageMlProvider.overrideWith((_) => Stream.value(0.0)),
      sevenDayDaysOnGoalOverride ??
          sevenDayDaysOnGoalProvider.overrideWith((_) => Stream.value(0)),
      userPreferencesProvider.overrideWith((_) => Stream.value(_makePrefs())),
      userProfileProvider.overrideWith((_) => Stream.value(null)),
      visibleNonAlcoholicPresetsProvider.overrideWith(
        (_) => Stream.value(const <DrinkPreset>[]),
      ),
      allPresetsProvider.overrideWith(
        (_) => Stream.value(const <DrinkPreset>[]),
      ),
      activePartySessionProvider.overrideWith((_) => Stream.value(null)),
      // _NoSessionView's "Past sessions" list (issue #86) watches these
      // unconditionally whenever activePartySessionProvider is null — since
      // [partyRepo] here is a real, working PartySessionRepository (unlike
      // widget_test.dart's `_appWithFakeStreams`, where the equivalent
      // provider chain silently errors on a real un-plugged AppDatabase()
      // and so never actually opens a Drift stream), the underlying
      // watchEndedSessions() query stream would otherwise still be open at
      // teardown and trip flutter_test's "pending timer" assertion.
      partyEndedSessionsProvider.overrideWith(
        (_) => Stream.value(const <PartySession>[]),
      ),
      partyEndedSessionSummariesProvider.overrideWith(
        (_) async => const <SessionDaySummary>[],
      ),
      historyDailyTotalsProvider.overrideWith(
        (_, __) => Stream.value(const <DailyBucket>[]),
      ),
      historyDrinksPerDayProvider.overrideWith(
        (_, __) => Stream.value(const <DailyBucket>[]),
      ),
      historyAlcoholicDrinksPerDayProvider.overrideWith(
        (_, __) => Stream.value(const <DailyBucket>[]),
      ),
      historySessionsInRangeProvider.overrideWith(
        (_, __) => Stream.value(const <PartySession>[]),
      ),
      historyMaxBacPerDayProvider.overrideWith(
        (_, __) => Future.value(const <BacDailyBucket>[]),
      ),
      appInfoServiceProvider.overrideWithValue(const FakeAppInfoService()),
    ],
    child: const MaterialApp(home: AppShell()),
  );
}

void main() {
  // AppShell's IndexedStack means every test in this file constructs at
  // least two AppDatabase instances (one for _buildAppShell's drinksRepo,
  // one for the party repo under test) — harmless in an in-memory test
  // context, but noisy without this (same convention as
  // drinks_repository_test.dart's `_memDb()`).
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets(
    'cold start (initState) retroactively ends a stale active session',
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

      expect((await db.getPartySessionById(session.id))!.endedAt, isNull);

      await tester.pumpWidget(_buildAppShell(realPartyRepo));
      // initState's unawaited check needs a microtask/Future to complete.
      await tester.pump();
      await tester.pump();

      final row = await db.getPartySessionById(session.id);
      expect(row!.endedAt, isNotNull);
      expect(row.endedAt!.isAtSameMomentAs(mark), isTrue);
      expect(row.endReason, PartySessionEndReason.autoTimeout.stored);
      expect(await db.getActiveSession(), isNull);
    },
  );

  testWidgets(
    'switching tabs via NavigationBar runs the auto-end check again, '
    'distinct from the cold-start call',
    (tester) async {
      final spy = _AutoEndSpyPartySessionRepo();

      await tester.pumpWidget(_buildAppShell(spy));
      await tester.pump();
      await tester.pump();

      expect(
        spy.checkAndApplyAutoEndCalls,
        1,
        reason: 'initState() should have run the check exactly once',
      );

      final navBar = find.byType(NavigationBar);
      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Party')),
      );
      await tester.pumpAndSettle();

      expect(
        spy.checkAndApplyAutoEndCalls,
        2,
        reason: 'NavigationBar.onDestinationSelected must run the check again, '
            'since IndexedStack keeps every tab\'s State alive and never '
            're-runs its initState after the first build',
      );

      await tester.tap(
        find.descendant(of: navBar, matching: find.text('History')),
      );
      await tester.pumpAndSettle();

      expect(spy.checkAndApplyAutoEndCalls, 3);
    },
  );

  testWidgets(
    'app foregrounded (didChangeAppLifecycleState(resumed)) runs the '
    'auto-end check',
    (tester) async {
      final spy = _AutoEndSpyPartySessionRepo();

      await tester.pumpWidget(_buildAppShell(spy));
      await tester.pump();
      await tester.pump();

      final callsAfterColdStart = spy.checkAndApplyAutoEndCalls;
      expect(callsAfterColdStart, 1);

      // Transition through a genuinely different state first —
      // handleAppLifecycleStateChanged is a no-op when the dispatched state
      // equals the binding's current one, and mirrors how the OS actually
      // backgrounds an app before resuming it.
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await tester.pump();
      expect(
        spy.checkAndApplyAutoEndCalls,
        callsAfterColdStart,
        reason: 'only AppLifecycleState.resumed should trigger the check',
      );

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pump();

      expect(spy.checkAndApplyAutoEndCalls, callsAfterColdStart + 1);
    },
  );

  testWidgets(
    'app resumed invalidates the day-window providers (issue #95), and '
    'nothing else does',
    (tester) async {
      final spy = _AutoEndSpyPartySessionRepo();
      var todayTotalMlCreateCalls = 0;
      var sevenDayAverageMlCreateCalls = 0;
      var sevenDayDaysOnGoalCreateCalls = 0;
      var presetUsageStatsCreateCalls = 0;

      void expectCreateCalls(int expected, {required String reason}) {
        expect(todayTotalMlCreateCalls, expected, reason: reason);
        expect(sevenDayAverageMlCreateCalls, expected, reason: reason);
        expect(sevenDayDaysOnGoalCreateCalls, expected, reason: reason);
        expect(presetUsageStatsCreateCalls, expected, reason: reason);
      }

      await tester.pumpWidget(
        _buildAppShell(
          spy,
          todayTotalMlOverride: todayTotalMlProvider.overrideWith((_) {
            todayTotalMlCreateCalls++;
            return Stream.value(0);
          }),
          sevenDayAverageMlOverride: sevenDayAverageMlProvider.overrideWith((
            _,
          ) {
            sevenDayAverageMlCreateCalls++;
            return Stream.value(0.0);
          }),
          sevenDayDaysOnGoalOverride: sevenDayDaysOnGoalProvider.overrideWith(
            (_) {
              sevenDayDaysOnGoalCreateCalls++;
              return Stream.value(0);
            },
          ),
          presetUsageStatsOverride: presetUsageStatsProvider.overrideWith((
            _,
          ) {
            presetUsageStatsCreateCalls++;
            return Stream.value(const <String, PresetUsageStats>{});
          }),
        ),
      );
      await tester.pump();
      await tester.pump();

      expectCreateCalls(
        1,
        reason: 'TodayScreen watches each provider once as part of the initial '
            'build',
      );

      // Tab switches only re-run checkAndApplyAutoEnd (covered above); they
      // must not also invalidate the day-window providers.
      final navBar = find.byType(NavigationBar);
      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Party')),
      );
      await tester.pumpAndSettle();
      expectCreateCalls(
        1,
        reason: 'a tab switch must not invalidate the day-window providers',
      );
      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Today')),
      );
      await tester.pumpAndSettle();

      // Transition through a genuinely different state first, mirroring the
      // auto-end resumed test above.
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await tester.pump();
      expectCreateCalls(
        1,
        reason: 'only AppLifecycleState.resumed should invalidate the '
            'day-window providers',
      );

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pump();
      await tester.pump();

      expectCreateCalls(
        2,
        reason: 'resumed must invalidate todayTotalMlProvider, '
            'sevenDayAverageMlProvider, sevenDayDaysOnGoalProvider and '
            'presetUsageStatsProvider so a stale "today"/7-day window is '
            "corrected immediately rather than waiting on each provider's "
            'own boundary Timer (issue #95)',
      );
    },
  );
}
