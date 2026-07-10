import 'package:drift/native.dart';
import 'package:drinks_mate/app.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/bac_daily_bucket.dart';
import 'package:drinks_mate/src/models/daily_bucket.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/services/app_info_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build a test app where every Drift stream query is replaced by a static
/// value. This avoids the pending-timer assertion that Flutter's test binding
/// raises when a Drift QueryStream is cancelled during widget disposal.
///
/// [drinksRepositoryProvider] is still overridden with a real in-memory DB so
/// that [logDrink] calls work without touching the file system.
///
/// [userPreferencesProvider] is overridden with a pre-onboarded snapshot so
/// [_AppGate] routes directly to [AppShell] without showing [OnboardingFlow].
Widget _appWithFakeStreams() {
  final db = AppDatabase(NativeDatabase.memory());
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final preOnboardedPrefs = UserPreferences(
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
    inactivityReminderEnabled: true,
    weeklySummaryEnabled: true,
    bacOnLockScreenEnabled: false,
    approachingCapNotifEnabled: false,
    soberEstimateNotifEnabled: false,
    installedAt: epoch,
    createdAt: epoch,
    updatedAt: epoch,
  );
  return ProviderScope(
    overrides: [
      // Repository uses an in-memory DB — no file system needed.
      drinksRepositoryProvider.overrideWithValue(DrinksRepository(db)),
      // Override the stream providers so Drift's QueryStream is never started,
      // and therefore its cleanup timer never fires mid-teardown.
      visiblePresetsProvider.overrideWith(
        (_) => Stream.value(const <DrinkPreset>[]),
      ),
      todayTotalMlProvider.overrideWith((_) => Stream.value(0)),
      sevenDayAverageMlProvider.overrideWith((_) => Stream.value(0.0)),
      sevenDayDaysOnGoalProvider.overrideWith((_) => Stream.value(0)),
      // Simulate a completed onboarding (username != null) so _AppGate routes
      // to AppShell instead of OnboardingFlow.
      userPreferencesProvider.overrideWith(
        (_) => Stream.value(preOnboardedPrefs),
      ),
      // Settings (S4) reads these too — override so its Drift/plugin-backed
      // providers never touch the real file system or a platform channel.
      userProfileProvider.overrideWith((_) => Stream.value(null)),
      visibleNonAlcoholicPresetsProvider.overrideWith(
        (_) => Stream.value(const <DrinkPreset>[]),
      ),
      allPresetsProvider.overrideWith(
        (_) => Stream.value(const <DrinkPreset>[]),
      ),
      // IndexedStack builds every tab eagerly, so PartyScreen's providers
      // resolve immediately regardless of which tab is selected — override
      // them for the same QueryStream-cleanup reason as the others above.
      activePartySessionProvider.overrideWith((_) => Stream.value(null)),
      // HistoryScreen (issue #25/#26) is also built eagerly by the
      // IndexedStack — override its family providers for the same
      // QueryStream-cleanup reason as the others above.
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
  testWidgets('app shell renders with 3-tab NavigationBar', (tester) async {
    await tester.pumpWidget(_appWithFakeStreams());
    await tester
        .pump(); // let userPreferencesProvider emit → _AppGate routes to AppShell
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
  });

  testWidgets('all 3 tab labels are visible', (tester) async {
    await tester.pumpWidget(_appWithFakeStreams());
    await tester
        .pump(); // let userPreferencesProvider emit → _AppGate routes to AppShell
    final navBar = find.byType(NavigationBar);
    for (final label in ['Today', 'Party', 'History']) {
      expect(
        find.descendant(of: navBar, matching: find.text(label)),
        findsOneWidget,
        reason: '$label tab label not found in NavigationBar',
      );
    }
  });

  testWidgets('Today screen shows progress card and Log drink button', (
    tester,
  ) async {
    await tester.pumpWidget(_appWithFakeStreams());
    await tester.pump(); // let StreamProvider emit the first value
    expect(find.text('Quick log'), findsOneWidget);
    expect(find.text('Log drink'), findsOneWidget);
  });

  testWidgets('tapping History tab switches screen', (tester) async {
    await tester.pumpWidget(_appWithFakeStreams());
    await tester
        .pump(); // let userPreferencesProvider emit → _AppGate routes to AppShell

    // Today screen is initially visible.
    expect(find.text('Quick log'), findsOneWidget);

    // Tap the History tab.
    final navBar = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: navBar, matching: find.text('History')),
    );
    await tester.pumpAndSettle();

    // History screen visible (empty state — the overridden providers above
    // emit an empty bucket list); Today content gone.
    expect(find.text('No drinks logged in this period'), findsOneWidget);
    expect(find.text('Quick log'), findsNothing);
  });

  testWidgets('tapping Party tab switches screen', (tester) async {
    await tester.pumpWidget(_appWithFakeStreams());
    await tester
        .pump(); // let userPreferencesProvider emit → _AppGate routes to AppShell

    final navBar = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: navBar, matching: find.text('Party')));
    await tester.pumpAndSettle();

    // No active session (overridden to null above) → the Party tab shows
    // the no-session explainer / start CTA (issue #22).
    expect(find.text('Start party session'), findsOneWidget);
  });

  testWidgets('gear icon navigates to Settings full-screen', (tester) async {
    await tester.pumpWidget(_appWithFakeStreams());
    await tester
        .pump(); // let userPreferencesProvider emit → _AppGate routes to AppShell

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Hydration'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
