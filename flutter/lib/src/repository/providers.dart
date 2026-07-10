import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../models/drink_entry.dart';
import '../models/drink_preset.dart';
import '../models/meal.dart';
import '../models/party_session.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';
import '../services/app_info_service.dart';
import '../services/goal_celebration_guard.dart';
import '../services/notification_service.dart';
import '../services/reminder_scheduler.dart';
import 'drinks_repository.dart';
import 'party_session_repository.dart';
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

/// Stream of visible non-alcoholic presets — the default-drink picker only
/// offers non-alcoholic presets (user-experience.md S4 / features.md F6).
final visibleNonAlcoholicPresetsProvider = StreamProvider<List<DrinkPreset>>((
  ref,
) {
  return ref.watch(drinksRepositoryProvider).watchVisiblePresets().map(
        (presets) => presets.where((p) => !p.beverageType.isAlcoholic).toList(),
      );
});

/// Stream of all non-deleted presets (including hidden), sorted by
/// sortOrder — feeds the "Manage drinks" screen.
final allPresetsProvider = StreamProvider<List<DrinkPreset>>((ref) {
  return ref.watch(drinksRepositoryProvider).watchAllPresets();
});

/// Stream of visible alcoholic presets — feeds the Party Mode "Log alcohol"
/// preset picker (party-session.md §Logging an alcoholic drink).
final visibleAlcoholicPresetsProvider = StreamProvider<List<DrinkPreset>>((
  ref,
) {
  return ref.watch(drinksRepositoryProvider).watchAlcoholicPresets();
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
// Reminder scheduling (issue #20)
// ---------------------------------------------------------------------------

/// Resolves [UserPreferences.defaultDrinkPresetId] to a [DrinkPreset],
/// falling back to the seeded "Glass of water" preset when unset or when the
/// referenced preset no longer exists (data-model.md §UserPreferences).
final defaultDrinkPresetProvider = FutureProvider<DrinkPreset?>((ref) async {
  final prefs = ref.watch(userPreferencesProvider).valueOrNull;
  if (prefs == null) return null;
  final repo = ref.watch(drinksRepositoryProvider);
  final presetId = prefs.defaultDrinkPresetId;
  final preset = presetId == null ? null : await repo.getPresetById(presetId);
  return preset ?? await repo.getPresetById(kWaterGlassPresetId);
});

/// Schedules/cancels the three hydration-related reminder types (F5).
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return ReminderScheduler(
    ref.watch(notificationServiceProvider),
    ref.watch(drinksRepositoryProvider),
  );
});

/// Side-effect provider: re-runs [ReminderScheduler.reschedule] whenever
/// preferences, the resolved default drink, or today's intake change.
///
/// Must be `watch`ed somewhere always-mounted (see `_AppGate` in `app.dart`)
/// so it stays alive for the lifetime of the app — a provider nobody watches
/// never initializes and reminders silently stop rescheduling.
final reminderReschedulerProvider = Provider<void>((ref) {
  final prefs = ref.watch(userPreferencesProvider).valueOrNull;
  if (prefs == null) return;
  final defaultPreset = ref.watch(defaultDrinkPresetProvider).valueOrNull;
  // Re-run on every log/delete so the "reset timer on log" and "cancel on
  // goal met" rules (notifications.md §Scheduling) take effect promptly.
  ref.watch(todayTotalMlProvider);
  final scheduler = ref.watch(reminderSchedulerProvider);
  unawaited(
    scheduler.reschedule(prefs: prefs, defaultDrinkPreset: defaultPreset),
  );
});

// ---------------------------------------------------------------------------
// App info service (issue #18 — Settings → About)
// ---------------------------------------------------------------------------

/// App version lookup for Settings → About.
///
/// Override in widget tests with a [FakeAppInfoService] to avoid native
/// plugin calls.
final appInfoServiceProvider = Provider<AppInfoService>((ref) {
  return const PackageInfoAppInfoService();
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

// ---------------------------------------------------------------------------
// Party Session repository (issue #21)
// ---------------------------------------------------------------------------

/// Repository provider for Party Session data (sessions, meals, prices).
///
/// Reuses [_appDatabaseProvider] — never creates a second [AppDatabase].
final partySessionRepositoryProvider = Provider<PartySessionRepository>((ref) {
  return PartySessionRepository(ref.watch(_appDatabaseProvider));
});

/// Reactive stream of the current open Party Session, or null.
final activePartySessionProvider = StreamProvider<PartySession?>((ref) {
  return ref.watch(partySessionRepositoryProvider).watchActiveSession();
});

// ---------------------------------------------------------------------------
// Party Session UI (issue #22)
// ---------------------------------------------------------------------------

/// Reactive stream of a session's live drink entries — feeds the BAC card.
final partySessionEntriesProvider =
    StreamProvider.family<List<DrinkEntry>, String>((ref, sessionId) {
  return ref
      .watch(partySessionRepositoryProvider)
      .watchSessionEntries(sessionId);
});

/// Reactive stream of a session's live meals — feeds the BAC card's meal
/// modifier and the "add/last meal" indicator.
final partySessionMealsProvider = StreamProvider.family<List<Meal>, String>((
  ref,
  sessionId,
) {
  return ref.watch(partySessionRepositoryProvider).watchSessionMeals(sessionId);
});

/// Emits immediately, then once a minute — drives the BAC card's live
/// recompute (elapsed time, elimination) without a raw [Timer] in the widget
/// tree. Overridden in widget tests with a single-value stream so
/// `pumpAndSettle` doesn't hang on a repeating timer.
final nowTickerProvider = StreamProvider<DateTime>((ref) => _minuteTicker());

Stream<DateTime> _minuteTicker() async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
}
