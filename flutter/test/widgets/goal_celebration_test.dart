import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/today_screen.dart';
import 'package:drinks_mate/src/services/goal_celebration_guard.dart';
import 'package:drinks_mate/src/widgets/goal_celebration_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserPreferences _makePrefs({int dailyGoalMl = 2000, int dayBoundaryHour = 5}) {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  return UserPreferences(
    id: kUserPreferencesId,
    username: 'tester',
    dailyGoalMl: dailyGoalMl,
    dayBoundaryHour: dayBoundaryHour,
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

// Wraps TodayScreen with the providers needed for integration tests.
Widget _buildTodayScreen({
  required UserPreferences prefs,
  required Stream<int> totalMlStream,
  required GoalCelebrationGuard guard,
}) {
  final db = AppDatabase(NativeDatabase.memory());
  return ProviderScope(
    overrides: [
      drinksRepositoryProvider.overrideWithValue(DrinksRepository(db)),
      visiblePresetsProvider.overrideWith(
        (_) => Stream.value(const <DrinkPreset>[]),
      ),
      todayTotalMlProvider.overrideWith((_) => totalMlStream),
      sevenDayAverageMlProvider.overrideWith((_) => Stream.value(0.0)),
      sevenDayDaysOnGoalProvider.overrideWith((_) => Stream.value(0)),
      userPreferencesProvider.overrideWith((_) => Stream.value(prefs)),
      goalCelebrationGuardProvider.overrideWithValue(guard),
    ],
    child: const MaterialApp(home: TodayScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // GoalCelebrationOverlay unit tests
  // -------------------------------------------------------------------------

  group('GoalCelebrationOverlay', () {
    testWidgets('shows "Goal reached!" text', (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoalCelebrationOverlay(onDismissed: () => dismissed = true),
          ),
        ),
      );
      // One frame to build; avoid pumpAndSettle — confetti animation loops.
      await tester.pump();

      expect(find.text('Goal reached!'), findsOneWidget);
      expect(dismissed, isFalse);
    });

    testWidgets('tapping dismisses the overlay', (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoalCelebrationOverlay(onDismissed: () => dismissed = true),
          ),
        ),
      );
      await tester.pump();

      await tester.tapAt(const Offset(200, 100));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('auto-dismisses after ~10 s', (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoalCelebrationOverlay(onDismissed: () => dismissed = true),
          ),
        ),
      );
      await tester.pump();
      expect(dismissed, isFalse);

      // Still short of the 10-second auto-dismiss timer.
      await tester.pump(const Duration(seconds: 5));
      expect(dismissed, isFalse);

      // Advance past the 10-second auto-dismiss timer.
      await tester.pump(const Duration(seconds: 6));

      expect(dismissed, isTrue);
    });

    testWidgets('reduce-motion path: shows card without crash', (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: GoalCelebrationOverlay(onDismissed: () => dismissed = true),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Goal reached!'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tapAt(const Offset(200, 100));
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('reduce-motion: auto-dismisses after ~10 s', (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: GoalCelebrationOverlay(onDismissed: () => dismissed = true),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(dismissed, isFalse);

      await tester.pump(const Duration(seconds: 11));
      expect(dismissed, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Today screen integration — celebration trigger logic
  // -------------------------------------------------------------------------

  group('TodayScreen goal celebration', () {
    testWidgets('crossing goal fires celebration (fresh guard)', (
      tester,
    ) async {
      final guard = InMemoryGoalCelebrationGuard();
      final prefs = _makePrefs(dailyGoalMl: 2000);
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(
        _buildTodayScreen(
          prefs: prefs,
          totalMlStream: controller.stream,
          guard: guard,
        ),
      );

      // Emit below goal — no celebration yet.
      controller.add(0);
      await tester.pump();
      expect(find.byType(GoalCelebrationOverlay), findsNothing);

      // Cross the goal upward.
      controller.add(2100);
      // Three pumps: stream delivers value → listen callback → async guard
      // check resolves → setState → rebuild.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(GoalCelebrationOverlay), findsOneWidget);
      expect(find.text('Goal reached!'), findsOneWidget);

      await controller.close();
    });

    testWidgets('second crossing same day does not re-trigger', (tester) async {
      final guard = InMemoryGoalCelebrationGuard();
      final prefs = _makePrefs(dailyGoalMl: 2000, dayBoundaryHour: 5);
      final controller = StreamController<int>.broadcast();

      // Pre-mark the guard for the current day window.
      final now = DateTime.now();
      final dayStart = dayWindow(
        now: now,
        boundaryHour: prefs.dayBoundaryHour,
      ).$1;
      await guard.markShownForDay(dayStart);

      await tester.pumpWidget(
        _buildTodayScreen(
          prefs: prefs,
          totalMlStream: controller.stream,
          guard: guard,
        ),
      );

      // Drop below goal then re-cross.
      controller.add(1500);
      await tester.pump();
      controller.add(2200);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(GoalCelebrationOverlay), findsNothing);

      await controller.close();
    });

    testWidgets('crossing goal next day shows celebration again', (
      tester,
    ) async {
      final guard = InMemoryGoalCelebrationGuard();
      final prefs = _makePrefs(dailyGoalMl: 2000, dayBoundaryHour: 5);
      final controller = StreamController<int>.broadcast();

      // Pre-mark with a clearly past date — simulates a previous day's window.
      await guard.markShownForDay(DateTime(2020, 1, 1));

      await tester.pumpWidget(
        _buildTodayScreen(
          prefs: prefs,
          totalMlStream: controller.stream,
          guard: guard,
        ),
      );

      controller.add(0);
      await tester.pump();
      controller.add(2100);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(GoalCelebrationOverlay), findsOneWidget);
      expect(find.text('Goal reached!'), findsOneWidget);

      await controller.close();
    });

    testWidgets('tapping celebration dismisses it', (tester) async {
      final guard = InMemoryGoalCelebrationGuard();
      final prefs = _makePrefs(dailyGoalMl: 2000);
      final controller = StreamController<int>.broadcast();

      await tester.pumpWidget(
        _buildTodayScreen(
          prefs: prefs,
          totalMlStream: controller.stream,
          guard: guard,
        ),
      );

      controller.add(0);
      await tester.pump();
      controller.add(2100);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(GoalCelebrationOverlay), findsOneWidget);

      await tester.tapAt(const Offset(200, 100));
      await tester.pump();

      expect(find.byType(GoalCelebrationOverlay), findsNothing);

      await controller.close();
    });
  });
}
