// Decisive widget-tree regression test for issue #97: NotificationService
// .initialize() was never called anywhere in the app, so no notifications
// ever fired.
//
// A bare ProviderContainer reading notificationInitializerProvider would only
// prove the provider's own body runs when read directly — it doesn't prove
// _AppGate (the only place that watches it in production, see app.dart)
// actually wires it up at real app startup. This test mounts the real
// [DrinksMateApp] (same helper shape as widget_test.dart's
// `_appWithFakeStreams` / reminder_reschedule_on_resume_test.dart's
// `_buildApp`) so `_AppGate` is live, overrides [notificationServiceProvider]
// with a [FakeNotificationService], and asserts its `initialised` flag flips
// to true after startup.

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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Mirrors reminder_reschedule_on_resume_test.dart's `_buildApp` (every
/// Drift stream provider AppShell's IndexedStack eagerly touches is
/// overridden to a static value, avoiding the pending-QueryStream-timer
/// teardown assertion), plus this test's own [notificationServiceProvider]
/// override so [notificationInitializerProvider] drives a [FakeNotificationService]
/// instead of the real plugin.
Widget _buildApp(FakeNotificationService notificationService) {
  return ProviderScope(
    overrides: [
      drinksRepositoryProvider.overrideWithValue(
        DrinksRepository(AppDatabase(NativeDatabase.memory())),
      ),
      partySessionRepositoryProvider.overrideWithValue(_NoopPartySessionRepo()),
      notificationServiceProvider.overrideWithValue(notificationService),
      defaultDrinkPresetProvider.overrideWith((ref) async => null),
      visiblePresetsProvider.overrideWith(
        (_) => Stream.value(const <DrinkPreset>[]),
      ),
      presetUsageStatsProvider.overrideWith(
        (_) => Stream.value(const <String, PresetUsageStats>{}),
      ),
      todayTotalMlProvider.overrideWith((_) => Stream.value(0)),
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
    'real app startup calls NotificationService.initialize() (issue #97 '
    'regression — notificationInitializerProvider is kept alive by the real '
    '_AppGate in this test, unlike a bare ProviderContainer)',
    (tester) async {
      final notificationService = FakeNotificationService();
      expect(
        notificationService.initialised,
        isFalse,
        reason: 'sanity check: the fake starts uninitialised',
      );

      await tester.pumpWidget(_buildApp(notificationService));
      // Let userPreferencesProvider/defaultDrinkPresetProvider/
      // todayTotalMlProvider all emit their first value, _AppGate route to
      // AppShell, and the unawaited initialize() future resolve.
      await tester.pumpAndSettle();

      expect(
        notificationService.initialised,
        isTrue,
        reason: 'notificationInitializerProvider must be watched somewhere '
            'always-mounted (see _AppGate in app.dart) so the plugin is '
            'initialized before any notification can be scheduled',
      );
    },
  );
}
