import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../models/drink_entry.dart';
import '../models/drink_preset.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';
import '../services/goal_celebration_guard.dart';
import '../services/notification_service.dart';
import 'drinks_repository.dart';
import 'preferences_repository.dart';

/// Package-private — widgets use [drinksRepositoryProvider] instead of
/// reaching [AppDatabase] directly (D2: Drift types never reach widgets).
final _appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => unawaited(db.close()));
  return db;
});

/// Repository provider — the only seam widgets use to reach persisted data.
final drinksRepositoryProvider = Provider<DrinksRepository>((ref) {
  return DrinksRepository(ref.watch(_appDatabaseProvider));
});

/// Stream of visible (non-hidden, non-deleted) presets, sorted by sortOrder.
final visiblePresetsProvider = StreamProvider<List<DrinkPreset>>((ref) {
  return ref.watch(drinksRepositoryProvider).watchVisiblePresets();
});

/// Reactive stream of today's total intake in ml.
/// Updates automatically whenever a drink is logged or deleted.
///
/// Re-subscribes at each day boundary so the query window rolls over
/// without requiring an app restart. Uses [UserPreferences.dayBoundaryHour]
/// so the window matches the one used by the progress card's expected intake.
final todayTotalMlProvider = StreamProvider<int>((ref) {
  final prefs = ref.watch(userPreferencesProvider).valueOrNull;
  if (prefs == null) return Stream.value(0);
  final now = DateTime.now();
  final nextBoundary = dayWindow(
    now: now,
    boundaryHour: prefs.dayBoundaryHour,
  ).$2;
  final timer = Timer(nextBoundary.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref
      .watch(drinksRepositoryProvider)
      .watchTodayTotalMl(now: now, boundaryHour: prefs.dayBoundaryHour);
});

// ---------------------------------------------------------------------------
// Preferences providers (issue #9)
// ---------------------------------------------------------------------------

/// Repository provider for user preferences and profile data.
///
/// Reuses [_appDatabaseProvider] — never creates a second [AppDatabase].
final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepository(ref.watch(_appDatabaseProvider));
});

/// Reactive stream of the [UserPreferences] singleton.
final userPreferencesProvider = StreamProvider<UserPreferences>((ref) {
  return ref.watch(preferencesRepositoryProvider).watchPreferences();
});

/// Reactive stream of the live [UserProfile]; null until onboarding writes it.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(preferencesRepositoryProvider).watchProfile();
});

// ---------------------------------------------------------------------------
// 7-day stat providers (issue #13)
// ---------------------------------------------------------------------------

/// Reactive stream of the 7-day daily average hydration intake in ml.
///
/// Excludes today — covers only the last 7 completed day windows.
/// Zero-fills empty days (divides by 7 regardless of data coverage).
///
/// Re-subscribes at each day boundary so the 7-day window rolls forward
/// without an app restart (mirrors [todayTotalMlProvider]).
final sevenDayAverageMlProvider = StreamProvider<double>((ref) {
  final prefs = ref.watch(userPreferencesProvider).valueOrNull;
  if (prefs == null) return Stream.value(0.0);
  final now = DateTime.now();
  final nextBoundary = dayWindow(
    now: now,
    boundaryHour: prefs.dayBoundaryHour,
  ).$2;
  final timer = Timer(nextBoundary.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref
      .watch(drinksRepositoryProvider)
      .watch7DayAverageMl(boundaryHour: prefs.dayBoundaryHour);
});

/// Reactive stream of how many of the last 7 completed days met the daily
/// hydration goal. Returns an integer in [0, 7].
///
/// Re-subscribes at each day boundary so the 7-day window rolls forward
/// without an app restart (mirrors [todayTotalMlProvider]).
final sevenDayDaysOnGoalProvider = StreamProvider<int>((ref) {
  final prefs = ref.watch(userPreferencesProvider).valueOrNull;
  if (prefs == null) return Stream.value(0);
  final now = DateTime.now();
  final nextBoundary = dayWindow(
    now: now,
    boundaryHour: prefs.dayBoundaryHour,
  ).$2;
  final timer = Timer(nextBoundary.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(drinksRepositoryProvider).watch7DayDaysOnGoal(
        dailyGoalMl: prefs.dailyGoalMl,
        boundaryHour: prefs.dayBoundaryHour,
      );
});

// ---------------------------------------------------------------------------
// Notification service (issue #19)
// ---------------------------------------------------------------------------

/// Notification scheduling / cancellation service.
///
/// Override in widget tests with a [FakeNotificationService] to avoid native
/// plugin calls.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return FlutterNotificationService();
});

// ---------------------------------------------------------------------------
// Goal celebration guard (issue #14)
// ---------------------------------------------------------------------------

/// Guards the once-per-day goal-met celebration overlay.
///
/// Override in tests with [InMemoryGoalCelebrationGuard] to avoid SharedPrefs
/// I/O and to control the day-key deterministically.
final goalCelebrationGuardProvider = Provider<GoalCelebrationGuard>((ref) {
  return SharedPrefsGoalCelebrationGuard();
});

// ---------------------------------------------------------------------------
// Today entries provider (issue #15)
// ---------------------------------------------------------------------------

/// Reactive stream of today's non-alcoholic drink entries, newest-first.
///
/// Used by the S6 Today Drinks Log screen. Re-subscribes at each day boundary
/// so the query window rolls over without requiring an app restart.
final todayEntriesProvider = StreamProvider<List<DrinkEntry>>((ref) {
  final prefs = ref.watch(userPreferencesProvider).valueOrNull;
  if (prefs == null) return Stream.value([]);
  final now = DateTime.now();
  final nextBoundary = dayWindow(
    now: now,
    boundaryHour: prefs.dayBoundaryHour,
  ).$2;
  final timer = Timer(nextBoundary.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref
      .watch(drinksRepositoryProvider)
      .watchTodayEntries(now: now, boundaryHour: prefs.dayBoundaryHour);
});
