// Decisive widget-tree regression test for issue #95's remediation.
//
// flutter/test/repository/providers_test.dart already proves the fix
// (_todayTotalMlValueProvider) works against a bare ProviderContainer, but a
// bare container doesn't mount `_AppGate` — the only place that watches
// [reminderReschedulerProvider] in production (see app.dart) — so it can't by
// itself prove the cascade this PR review flagged is actually fixed. This
// test mounts the real [DrinksMateApp] (same helper shape as
// widget_test.dart's `_appWithFakeStreams`) so `_AppGate` is live, and drives
// the exact `AppLifecycleState.resumed` trigger `AppShell` uses (see
// widgets/app_shell_test.dart).

import 'package:core/core.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drinks_mate/app.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/bac_daily_bucket.dart';
import 'package:drinks_mate/src/models/daily_bucket.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/party_session_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/services/app_info_service.dart';
import 'package:drinks_mate/src/services/notification_service.dart';
import 'package:drinks_mate/src/services/reminder_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts [reschedule] calls instead of exercising real scheduling logic —
/// mirrors providers_test.dart's spy of the same name.
class _CountingReminderScheduler extends ReminderScheduler {
  _CountingReminderScheduler(super.notifications, super.drinks);

  int rescheduleCalls = 0;

  @override
  Future<void> reschedule({
    required UserPreferences prefs,
    DrinkPreset? defaultDrinkPreset,
    DateTime? now,
  }) async {
    rescheduleCalls++;
  }
}

/// checkAndApplyAutoEnd() is unrelated to this test but AppShell's initState
/// calls it unconditionally — stub it out so it never touches a real DB.
class _NoopPartySessionRepo extends PartySessionRepository {
  _NoopPartySessionRepo() : super(AppDatabase(NativeDatabase.memory()));

  @override
  Future<void> checkAndApplyAutoEnd({DateTime? now}) async {}
}

UserPreferences _prefs() {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  return UserPreferences(
    id: kUserPreferencesId,
    username: 'test_user',
    dailyGoalMl: 2000,
    dayBoundaryHour: 5,
    units: 'metric',
    currency: 'EUR',
    reminderEnabled: true,
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

/// Mirrors widget_test.dart's `_appWithFakeStreams` (every Drift stream
/// provider AppShell's IndexedStack eagerly touches is overridden to a
/// static value, avoiding the pending-QueryStream-timer teardown assertion),
/// plus the reminder-rescheduling overrides this test needs:
/// [reminderSchedulerProvider] (the counting spy), [defaultDrinkPresetProvider]
/// (skips the DB round-trip), and a controllable [todayTotalMlProvider] — the
/// override closure reads [totalMl] on every (re)subscription, so mutating it
/// and then triggering a resume (which invalidates [todayTotalMlProvider])
/// changes what the next subscription emits, without tearing down and
/// rebuilding the whole widget tree.
Widget _buildApp(
  _CountingReminderScheduler scheduler, {
  required int Function() totalMl,
}) {
  return ProviderScope(
    overrides: [
      drinksRepositoryProvider.overrideWithValue(
        DrinksRepository(AppDatabase(NativeDatabase.memory())),
      ),
      partySessionRepositoryProvider.overrideWithValue(
        _NoopPartySessionRepo(),
      ),
      reminderSchedulerProvider.overrideWithValue(scheduler),
      defaultDrinkPresetProvider.overrideWith((ref) async => null),
      visiblePresetsProvider.overrideWith(
        (_) => Stream.value(const <DrinkPreset>[]),
      ),
      presetUsageStatsProvider.overrideWith(
        (_) => Stream.value(const <String, PresetUsageStats>{}),
      ),
      todayTotalMlProvider.overrideWith((_) => Stream.value(totalMl())),
      sevenDayAverageMlProvider.overrideWith((_) => Stream.value(0.0)),
      sevenDayDaysOnGoalProvider.overrideWith((_) => Stream.value(0)),
      userPreferencesProvider.overrideWith((_) => Stream.value(_prefs())),
      userProfileProvider.overrideWith((_) => Stream.value(null)),
      visibleNonAlcoholicPresetsProvider.overrideWith(
        (_) => Stream.value(const <DrinkPreset>[]),
      ),
      allPresetsProvider.overrideWith(
        (_) => Stream.value(const <DrinkPreset>[]),
      ),
      activePartySessionProvider.overrideWith((_) => Stream.value(null)),
      partyEndedSessionsProvider.overrideWith(
        (_) => Stream.value(const <PartySession>[]),
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
    child: const DrinksMateApp(),
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets(
    'app resume with an unchanged today-total does not re-anchor the '
    'hydration reminder, but a resume after the total genuinely changed '
    'does (issue #95 regression — reminderReschedulerProvider is kept '
    'alive by the real _AppGate in this test, unlike app_shell_test.dart)',
    (tester) async {
      final scheduler = _CountingReminderScheduler(
        FakeNotificationService(),
        DrinksRepository(AppDatabase(NativeDatabase.memory())),
      );
      var total = 0;

      await tester.pumpWidget(_buildApp(scheduler, totalMl: () => total));
      // Let userPreferencesProvider/defaultDrinkPresetProvider/
      // todayTotalMlProvider all emit their first value and _AppGate route
      // to AppShell.
      await tester.pumpAndSettle();

      final baseline = scheduler.rescheduleCalls;
      expect(
        baseline,
        greaterThan(0),
        reason: 'cold start should reschedule at least once',
      );

      // Resume with the SAME total (0): AppShell._invalidateDayWindowProviders
      // invalidates todayTotalMlProvider so the UI recomputes "now", but the
      // resubscribed stream re-emits the same 0 ml.
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();

      expect(
        scheduler.rescheduleCalls,
        baseline,
        reason: 'an unchanged today-total must not re-anchor the hydration '
            'reminder to the resume moment (notifications.md §Scheduling '
            'reserves that for logging a drink)',
      );

      // A genuinely different total (simulating a drink logged while
      // backgrounded), then another resume, must still trigger reschedule —
      // the fix must not silently break real updates either.
      total = 500;
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();

      expect(
        scheduler.rescheduleCalls,
        greaterThan(baseline),
        reason: 'a genuinely different today-total must still trigger '
            'reschedule()',
      );
    },
  );
}
