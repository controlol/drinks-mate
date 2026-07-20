import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../models/bac_daily_bucket.dart';
import '../models/daily_bucket.dart';
import '../models/drink_entry.dart';
import '../models/drink_preset.dart';
import '../models/meal.dart';
import '../models/party_session.dart';
import '../models/party_session_price.dart';
import '../models/session_day_summary.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';
import '../services/app_info_service.dart';
import '../services/bac_estimator.dart';
import '../services/goal_celebration_guard.dart';
import '../services/history_bac_service.dart';
import '../services/notification_service.dart';
import '../services/party_notification_guard.dart';
import '../services/party_notification_service.dart';
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
///
/// Depends on [partySessionRepositoryProvider] so [DrinksRepository.logDrink]
/// can run the lazy 12h auto-end check on every drink logged, including
/// non-alcoholic ones (party-session.md §Auto-end is computed lazily,
/// "a drink is logged" trigger) — not just alcoholic entries logged via
/// [PartySessionRepository.logAlcoholicDrink].
final drinksRepositoryProvider = Provider<DrinksRepository>((ref) {
  return DrinksRepository(
    ref.watch(_appDatabaseProvider),
    partySessionRepository: ref.watch(partySessionRepositoryProvider),
  );
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

// ---------------------------------------------------------------------------
// Preset sort modes (F14 §Sort modes — issue #78)
// ---------------------------------------------------------------------------

/// Reactive stream of per-preset usage stats (last-used timestamp, trailing
/// 30-day count) — the raw signal behind the Recently-used/Most-used sort
/// modes. See [DrinksRepository.watchPresetUsageStats].
///
/// The underlying stream already recomputes "now" on every DB-driven
/// emission (a logged/deleted entry), but the trailing window must also
/// slide forward on pure time passage with no new writes — so, mirroring
/// [todayTotalMlProvider]/[sevenDayAverageMlProvider], this re-subscribes at
/// the next day boundary.
final presetUsageStatsProvider = StreamProvider<Map<String, PresetUsageStats>>((
  ref,
) {
  final prefs = ref.watch(userPreferencesProvider).valueOrNull;
  final now = DateTime.now();
  final nextBoundary = dayWindow(
    now: now,
    boundaryHour: prefs?.dayBoundaryHour ?? 5,
  ).$2;
  final timer = Timer(nextBoundary.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(drinksRepositoryProvider).watchPresetUsageStats();
});

/// Visible presets ([visiblePresetsProvider]) ranked by the user's
/// [UserPreferences.drinkSortMode] — the single source of ordering shared by
/// the Today "Log a drink" grid and the S2 picker (F14 §Sort modes).
///
/// Resolves to an empty list until presets/usage/preferences have all loaded
/// at least once, same "no data yet" behaviour as other `.valueOrNull ?? []`
/// combinations in this file (e.g. [reminderReschedulerProvider]).
final rankedVisiblePresetsProvider = Provider<List<DrinkPreset>>((ref) {
  final presets = ref.watch(visiblePresetsProvider).valueOrNull ?? const [];
  final usage = ref.watch(presetUsageStatsProvider).valueOrNull ?? const {};
  final mode = ref.watch(userPreferencesProvider).valueOrNull?.drinkSortMode ??
      PresetSortMode.recentlyUsed;

  final rankedIds = rankPresetIds(
    presetIds: [for (final p in presets) p.id],
    sortOrders: {for (final p in presets) p.id: p.sortOrder},
    usage: usage,
    mode: mode,
  );
  final byId = {for (final p in presets) p.id: p};
  return [for (final id in rankedIds) byId[id]!];
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

/// The boundary-aligned start of "today" (Parity Rulebook → "Day
/// boundary"), independent of drink data — exists purely so
/// [_todayTotalMlValueProvider] can tell a genuine day-boundary rollover
/// apart from a same-day resume-triggered resubscription of
/// [todayTotalMlProvider] (see that provider's doc for why the distinction
/// matters).
///
/// Re-subscribes at each day boundary, mirroring [todayTotalMlProvider],
/// and is invalidated by `AppShell._invalidateDayWindowProviders` on every
/// app resume (issue #95) so a boundary crossed while the app was
/// backgrounded is picked up immediately rather than waiting on this
/// provider's own [Timer].
final todayDayStartProvider = Provider<DateTime?>((ref) {
  final prefs = ref.watch(userPreferencesProvider).valueOrNull;
  if (prefs == null) return null;
  final now = DateTime.now();
  final window = dayWindow(now: now, boundaryHour: prefs.dayBoundaryHour);
  final timer = Timer(window.$2.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return window.$1;
});

/// Today's total intake in ml paired with [todayDayStartProvider] — a
/// stable [Provider] wrapper so [reminderReschedulerProvider] only rebuilds
/// when the *total* changes or a *day-boundary rollover* actually happened.
///
/// `AppShell._invalidateDayWindowProviders` (issue #95) invalidates
/// [todayTotalMlProvider] on every app resume to force it to recompute
/// "now". A plain `ref.watch(todayTotalMlProvider)` inside
/// [reminderReschedulerProvider] would rebuild on that resubscription too —
/// even when it re-emits the same total — re-anchoring the hydration
/// reminder to the resume moment (notifications.md §Scheduling reserves
/// that for *logging a drink*).
///
/// Suppressing purely on total-value equality broke the once-daily
/// inactivity reminder: [ReminderScheduler]'s `_rescheduleInactivity`
/// places only a single one-time notification per
/// [ReminderScheduler.reschedule] call, so it depends on `reschedule()`
/// running again at least once per day. A day-boundary rollover that
/// happens to re-emit an unchanged total (e.g. 0 ml → 0 ml on a
/// zero-intake streak) would otherwise be silently swallowed. Pairing the
/// total with [todayDayStartProvider]'s value means
/// Riverpod's default record `==` still suppresses a same-day resume
/// (identical pair), while a genuine rollover (different day start) always
/// notifies downstream regardless of whether the total happened to repeat
/// (see providers_test.dart / reminder_reschedule_on_resume_test.dart for
/// the regression coverage).
final _todayTotalMlValueProvider =
    Provider<({int? totalMl, DateTime? dayStart})>((ref) {
  return (
    totalMl: ref.watch(todayTotalMlProvider).valueOrNull,
    dayStart: ref.watch(todayDayStartProvider),
  );
});

/// Side-effect provider: re-runs [ReminderScheduler.reschedule] whenever
/// preferences, the resolved default drink, today's intake, or the current
/// day window change.
///
/// Must be `watch`ed somewhere always-mounted (see `_AppGate` in `app.dart`)
/// so it stays alive for the lifetime of the app — a provider nobody watches
/// never initializes and reminders silently stop rescheduling.
final reminderReschedulerProvider = Provider<void>((ref) {
  final prefs = ref.watch(userPreferencesProvider).valueOrNull;
  if (prefs == null) return;
  final defaultPreset = ref.watch(defaultDrinkPresetProvider).valueOrNull;
  // Re-run on every log/delete and on every genuine day-boundary rollover
  // (notifications.md §Scheduling) — see [_todayTotalMlValueProvider]'s doc
  // for why this watches that rather than [todayTotalMlProvider] directly.
  ref.watch(_todayTotalMlValueProvider);
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

/// Reactive stream of today's drink entries, newest-first — every beverage
/// type, hydration and alcoholic alike (design/user-experience.md §S6).
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
// History (issue #25)
// ---------------------------------------------------------------------------

/// Keying record for the History range providers below — a plain record has
/// structural `==`/`hashCode`, which `.family` needs to dedupe subscriptions
/// for the same range.
typedef HistoryRangeKey = ({
  DateTime rangeStart,
  DateTime rangeEnd,
  int boundaryHour,
});

/// Reactive stream of zero-filled daily hydration totals (ml) for the range
/// in [key]. See [DrinksRepository.watchDailyTotalsMl].
final historyDailyTotalsProvider =
    StreamProvider.family<List<DailyBucket>, HistoryRangeKey>((ref, key) {
  return ref.watch(drinksRepositoryProvider).watchDailyTotalsMl(
        rangeStart: key.rangeStart,
        rangeEnd: key.rangeEnd,
        boundaryHour: key.boundaryHour,
      );
});

/// Reactive stream of zero-filled daily drink counts for the range in [key].
/// See [DrinksRepository.watchDrinksPerDay].
final historyDrinksPerDayProvider =
    StreamProvider.family<List<DailyBucket>, HistoryRangeKey>((ref, key) {
  return ref.watch(drinksRepositoryProvider).watchDrinksPerDay(
        rangeStart: key.rangeStart,
        rangeEnd: key.rangeEnd,
        boundaryHour: key.boundaryHour,
      );
});

// ---------------------------------------------------------------------------
// History — alcohol charts + day drill-down (issue #26)
// ---------------------------------------------------------------------------

/// Reactive stream of zero-filled daily alcoholic-drink counts for the range
/// in [key]. See [DrinksRepository.watchAlcoholicDrinksPerDay].
final historyAlcoholicDrinksPerDayProvider =
    StreamProvider.family<List<DailyBucket>, HistoryRangeKey>((ref, key) {
  return ref.watch(drinksRepositoryProvider).watchAlcoholicDrinksPerDay(
        rangeStart: key.rangeStart,
        rangeEnd: key.rangeEnd,
        boundaryHour: key.boundaryHour,
      );
});

/// Reactive stream of live [PartySession]s overlapping the range in [key].
/// Drives the alcohol section's conditional visibility (features.md F4:
/// "shown only when the user has at least one PartySession whose window
/// intersects the selected range") and the session overlay band.
final historySessionsInRangeProvider =
    StreamProvider.family<List<PartySession>, HistoryRangeKey>((ref, key) {
  return ref
      .watch(partySessionRepositoryProvider)
      .watchSessionsInRange(key.rangeStart, key.rangeEnd);
});

/// Computes the "Max estimated BAC per day" chart data for the range in
/// [key] (party-session.md BAC peak sampling; features.md F4).
///
/// Re-fetches session entries/meals whenever the overlapping-sessions list
/// or the user profile changes. Also watches
/// [historyAlcoholicDrinksPerDayProvider] purely as an extra recompute
/// trigger, so a drink logged into an already-known session updates the BAC
/// bars too, not just the drinks-per-day chart.
final historyMaxBacPerDayProvider =
    FutureProvider.family<List<BacDailyBucket>, HistoryRangeKey>((
  ref,
  key,
) async {
  final sessions =
      ref.watch(historySessionsInRangeProvider(key)).valueOrNull ?? [];
  ref.watch(historyAlcoholicDrinksPerDayProvider(key));
  final profile = ref.watch(userProfileProvider).valueOrNull;

  final repo = ref.watch(partySessionRepositoryProvider);
  final sessionIds = sessions.map((s) => s.id).toList();
  final entries = await repo.getEntriesForSessions(sessionIds);
  final meals = await repo.getMealsForSessions(sessionIds);

  return computeMaxBacPerDay(
    rangeStart: key.rangeStart,
    rangeEnd: key.rangeEnd,
    boundaryHour: key.boundaryHour,
    sessions: sessions,
    alcoholicEntries: entries,
    meals: meals,
    profile: profile,
    now: DateTime.now(),
  );
});

/// Keying record for a single day's History drill-down providers.
typedef HistoryDayKey = ({DateTime dayStart, DateTime dayEnd});

/// Reactive stream of every live entry (any beverage type) for the day in
/// [key], newest-first. See [DrinksRepository.watchDayEntries].
final historyDayEntriesProvider =
    StreamProvider.family<List<DrinkEntry>, HistoryDayKey>((ref, key) {
  return ref
      .watch(drinksRepositoryProvider)
      .watchDayEntries(key.dayStart, key.dayEnd);
});

/// Reactive stream of live [PartySession]s overlapping the day in [key].
final historyDaySessionsProvider =
    StreamProvider.family<List<PartySession>, HistoryDayKey>((ref, key) {
  return ref
      .watch(partySessionRepositoryProvider)
      .watchSessionsInRange(key.dayStart, key.dayEnd);
});

/// One [SessionDaySummary] per session overlapping the day in [key] — feeds
/// the day drill-down's session summary card(s) (F4/#26).
final historyDaySessionSummariesProvider =
    FutureProvider.family<List<SessionDaySummary>, HistoryDayKey>((
  ref,
  key,
) async {
  final sessions = ref.watch(historyDaySessionsProvider(key)).valueOrNull ?? [];
  if (sessions.isEmpty) return [];

  final profile = ref.watch(userProfileProvider).valueOrNull;
  final repo = ref.watch(partySessionRepositoryProvider);
  final sessionIds = sessions.map((s) => s.id).toList();
  final entries = await repo.getEntriesForSessions(sessionIds);
  final meals = await repo.getMealsForSessions(sessionIds);
  final now = DateTime.now();

  return [
    for (final session in sessions)
      buildSessionDaySummary(
        session: session,
        dayStart: key.dayStart,
        dayEnd: key.dayEnd,
        entries: entries,
        meals: meals,
        profile: profile,
        now: now,
      ),
  ];
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

/// Reactive stream of every ended Party Session, newest-ended-first — feeds
/// the S7 "past sessions" list (user-experience.md §S7 → No active session —
/// subsequent visits).
final partyEndedSessionsProvider = StreamProvider<List<PartySession>>((ref) {
  return ref.watch(partySessionRepositoryProvider).watchEndedSessions();
});

/// One whole-session [SessionDaySummary] per [partyEndedSessionsProvider]
/// entry (date/range, peak BAC, drink count, end reason — user-experience.md
/// §S7). Mirrors [historyDaySessionSummariesProvider]'s bulk-fetch shape, but
/// unclipped ([buildSessionSummary] rather than [buildSessionDaySummary]).
final partyEndedSessionSummariesProvider =
    FutureProvider<List<SessionDaySummary>>((ref) async {
  final sessions = ref.watch(partyEndedSessionsProvider).valueOrNull ?? [];
  if (sessions.isEmpty) return [];

  final profile = ref.watch(userProfileProvider).valueOrNull;
  final repo = ref.watch(partySessionRepositoryProvider);
  final sessionIds = sessions.map((s) => s.id).toList();
  final entries = await repo.getEntriesForSessions(sessionIds);
  final meals = await repo.getMealsForSessions(sessionIds);
  final now = DateTime.now();

  return [
    for (final session in sessions)
      buildSessionSummary(
        session: session,
        entries: entries,
        meals: meals,
        profile: profile,
        now: now,
      ),
  ];
});

/// A single session's whole-lifetime summary, keyed by session id — feeds
/// [S9 Party Session Log]'s ended-mode header.
final partySessionSummaryProvider =
    FutureProvider.family<SessionDaySummary, String>((ref, sessionId) async {
  final repo = ref.watch(partySessionRepositoryProvider);
  final session = await repo.getSessionById(sessionId);
  final profile = ref.watch(userProfileProvider).valueOrNull;
  final entries = await repo.getEntriesForSessions([sessionId]);
  final meals = await repo.getMealsForSessions([sessionId]);
  return buildSessionSummary(
    session: session,
    entries: entries,
    meals: meals,
    profile: profile,
    now: DateTime.now(),
  );
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

// ---------------------------------------------------------------------------
// Party Session pricing (issue #23)
// ---------------------------------------------------------------------------

/// Reactive stream of a session's live price overrides — feeds the
/// session-prices control's "off — using regular prices" label and the
/// "Manage prices" sheet.
final partySessionPricesProvider =
    StreamProvider.family<List<PartySessionPrice>, String>((ref, sessionId) {
  return ref
      .watch(partySessionRepositoryProvider)
      .watchSessionPrices(sessionId);
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

// ---------------------------------------------------------------------------
// Party Mode notifications (issue #24)
// ---------------------------------------------------------------------------

/// Once-per-session guard for the approaching-cap notification.
final partyNotificationGuardProvider = Provider<PartyNotificationGuard>((ref) {
  return SharedPrefsPartyNotificationGuard();
});

/// Schedules/cancels the approaching-cap and sober-estimate notifications.
final partyNotificationServiceProvider = Provider<PartyNotificationService>((
  ref,
) {
  return PartyNotificationService(
    ref.watch(notificationServiceProvider),
    ref.watch(partyNotificationGuardProvider),
  );
});

/// Side-effect provider: re-syncs Party Mode's two session-scoped
/// notifications whenever the active session, its drinks/meals, or
/// preferences change.
///
/// Both notification types are event-driven (a logged drink, a changed
/// toggle) rather than time-driven, so this deliberately does not watch
/// [nowTickerProvider] — see [PartyNotificationService.sync]'s doc.
///
/// Must be `watch`ed somewhere always-mounted (see `_AppGate` in `app.dart`),
/// mirroring [reminderReschedulerProvider], so notifications keep syncing
/// even while the user isn't looking at the Party tab.
final partyNotificationSyncProvider = Provider<void>((ref) {
  final prefs = ref.watch(userPreferencesProvider).valueOrNull;
  if (prefs == null) return;
  final session = ref.watch(activePartySessionProvider).valueOrNull;
  final service = ref.watch(partyNotificationServiceProvider);

  if (session == null) {
    unawaited(service.sync(session: null, prefs: prefs));
    return;
  }

  final profile = ref.watch(userProfileProvider).valueOrNull;
  final entriesAsync = ref.watch(partySessionEntriesProvider(session.id));
  final mealsAsync = ref.watch(partySessionMealsProvider(session.id));
  if (profile == null ||
      profile.birthDate == null ||
      !entriesAsync.hasValue ||
      !mealsAsync.hasValue) {
    return;
  }

  final alcoholicEntries = entriesAsync.requireValue
      .where((e) => e.beverageType.isAlcoholic)
      .toList();
  final meals = mealsAsync.requireValue;
  final now = DateTime.now();
  final estimate = estimateSessionBac(
    profile: profile,
    alcoholicEntries: alcoholicEntries,
    meals: meals,
    at: now,
  );
  final soberTime = alcoholicEntries.isEmpty
      ? null
      : projectedSoberTime(
          profile: profile,
          alcoholicEntries: alcoholicEntries,
          meals: meals,
        );

  unawaited(
    service.sync(
      session: session,
      prefs: prefs,
      estimate: estimate,
      capGPerL: prefs.bacCapGramsPerL,
      projectedSoberTime: soberTime,
      now: now,
    ),
  );
});
