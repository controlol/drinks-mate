import '../models/bac_daily_bucket.dart';
import '../models/drink_entry.dart';
import '../models/meal.dart';
import '../models/party_session.dart';
import '../models/session_day_summary.dart';
import '../models/user_profile.dart';
import 'bac_estimator.dart';

/// Computes the "Max estimated BAC per day" History chart (features.md F4;
/// party-session.md BAC peak sampling), one [BacDailyBucket] per day-window
/// in `[rangeStart, rangeEnd)`, ordered oldest-first.
///
/// For each day, every [sessions] entry whose window overlaps that day is
/// sampled at [sampleInterval] steps (starting at the overlap start, so the
/// grid is not calendar-aligned) across the overlap of the session's active
/// window, the day window, and [now] — samples never run into the future or
/// past an ongoing session's still-unknown end. The bucket's value is the
/// max [BacEstimate.gPerL] found across every sample of every session
/// touching that day.
///
/// Immediate-absorption means a drink's true peak sits at its own
/// `consumedAt`, which may fall between grid points — this sampling
/// approach can under-report a peak, matching the "sampling" language in
/// features.md F4 rather than an exact-peak calculation.
///
/// A day with **no** overlapping session gets `maxGPerL: null` (no bar —
/// features.md F4: "days with no session show no bar ... to avoid implying
/// the estimate ran and produced 0 g/L"). A day a session *does* touch but
/// whose sampled BAC is fully decayed gets `maxGPerL: 0.0` (a real bar at
/// zero), which is why the session overlay band matters — it is the only
/// signal distinguishing "session, decayed to 0" from "no session".
///
/// [profile] must have `birthDate` set (Party Mode's own precondition,
/// mirrored from [estimateSessionBac]) — callers with an incomplete profile
/// should not call this; every day resolves to `null` if the profile is
/// incomplete, since no estimate can be computed.
List<BacDailyBucket> computeMaxBacPerDay({
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required int boundaryHour,
  int boundaryMinute = 0,
  required List<PartySession> sessions,
  required List<DrinkEntry> alcoholicEntries,
  required List<Meal> meals,
  required UserProfile? profile,
  required DateTime now,
  Duration sampleInterval = const Duration(minutes: 15),
}) {
  final buckets = <BacDailyBucket>[];
  if (profile == null || profile.birthDate == null || sessions.isEmpty) {
    var day = rangeStart;
    while (day.isBefore(rangeEnd)) {
      buckets.add(BacDailyBucket(dayStart: day));
      day = DateTime(
        day.year,
        day.month,
        day.day + 1,
        boundaryHour,
        boundaryMinute,
      );
    }
    return buckets;
  }

  final entriesBySession = <String, List<DrinkEntry>>{};
  for (final entry in alcoholicEntries) {
    final sessionId = entry.partySessionId;
    if (sessionId == null) continue;
    (entriesBySession[sessionId] ??= []).add(entry);
  }
  final mealsBySession = <String, List<Meal>>{};
  for (final meal in meals) {
    (mealsBySession[meal.partySessionId] ??= []).add(meal);
  }

  var day = rangeStart;
  while (day.isBefore(rangeEnd)) {
    final dayEnd = DateTime(
      day.year,
      day.month,
      day.day + 1,
      boundaryHour,
      boundaryMinute,
    );
    buckets.add(
      BacDailyBucket(
        dayStart: day,
        maxGPerL: _maxBacForWindow(
          windowStart: day,
          windowEnd: dayEnd,
          sessions: sessions,
          entriesBySession: entriesBySession,
          mealsBySession: mealsBySession,
          profile: profile,
          now: now,
          sampleInterval: sampleInterval,
        ),
      ),
    );
    day = dayEnd;
  }
  return buckets;
}

/// Builds the day drill-down's session summary card for [session] clipped to
/// `[dayStart, dayEnd)` (F4/#26). [entries]/[meals] should be [session]'s
/// full (unclipped) lists — see [computeMaxBacPerDay].
SessionDaySummary buildSessionDaySummary({
  required PartySession session,
  required DateTime dayStart,
  required DateTime dayEnd,
  required List<DrinkEntry> entries,
  required List<Meal> meals,
  required UserProfile? profile,
  required DateTime now,
}) {
  final sessionEnd = session.endedAt ?? now;
  final clipStart = _laterOf(dayStart, session.startedAt);
  final clipEnd = _earlierOf(dayEnd, sessionEnd);
  final duration = clipEnd.isAfter(clipStart)
      ? clipEnd.difference(clipStart)
      : Duration.zero;

  final sessionEntries =
      entries.where((e) => e.partySessionId == session.id).toList();
  final sessionMeals =
      meals.where((m) => m.partySessionId == session.id).toList();
  final dayEntries = sessionEntries
      .where(
        (e) =>
            !e.consumedAt.isBefore(dayStart) && e.consumedAt.isBefore(dayEnd),
      )
      .toList();
  final dayMeals = sessionMeals
      .where((m) => !m.eatenAt.isBefore(dayStart) && m.eatenAt.isBefore(dayEnd))
      .toList();

  final peakBac = _maxBacForWindow(
    windowStart: dayStart,
    windowEnd: dayEnd,
    sessions: [session],
    entriesBySession: {session.id: sessionEntries},
    mealsBySession: {session.id: sessionMeals},
    profile: profile,
    now: now,
    sampleInterval: const Duration(minutes: 15),
  );

  return SessionDaySummary(
    session: session,
    duration: duration,
    totalAlcoholicDrinks: dayEntries.length,
    mealsLoggedCount: dayMeals.length,
    peakBacGPerL: peakBac,
  );
}

/// Shared sampler behind [computeMaxBacPerDay] and [buildSessionDaySummary]:
/// the max [BacEstimate.gPerL] across every [sessions] entry that overlaps
/// `[windowStart, windowEnd)`, or null if none do.
double? _maxBacForWindow({
  required DateTime windowStart,
  required DateTime windowEnd,
  required List<PartySession> sessions,
  required Map<String, List<DrinkEntry>> entriesBySession,
  required Map<String, List<Meal>> mealsBySession,
  required UserProfile? profile,
  required DateTime now,
  required Duration sampleInterval,
}) {
  if (profile == null || profile.birthDate == null) return null;

  double? windowMax;
  for (final session in sessions) {
    final sessionEnd = session.endedAt ?? now;
    final touchesWindow = session.startedAt.isBefore(windowEnd) &&
        sessionEnd.isAfter(windowStart);
    if (!touchesWindow) continue;

    // A session touches this window (per the check above) even if `now`
    // clamps the sampled slice to zero width — that still counts as "a
    // session was here", so the running max is floored at 0.0 rather than
    // left null.
    windowMax = windowMax ?? 0.0;

    final overlapStart = _laterOf(windowStart, session.startedAt);
    final rawOverlapEnd = _earlierOf(windowEnd, sessionEnd);
    final overlapEnd = _earlierOf(rawOverlapEnd, now);
    if (overlapEnd.isBefore(overlapStart)) continue;

    final sessionEntries = entriesBySession[session.id] ?? const [];
    final sessionMeals = mealsBySession[session.id] ?? const [];

    var t = overlapStart;
    var lastSampled = false;
    while (!t.isAfter(overlapEnd)) {
      final gPerL = _sampleAt(t, profile, sessionEntries, sessionMeals);
      if (gPerL > windowMax!) windowMax = gPerL;
      lastSampled = t == overlapEnd;
      t = t.add(sampleInterval);
    }
    if (!lastSampled) {
      // Ensure the overlap's end instant (e.g. session end, or the window
      // boundary) is always sampled even when the interval doesn't divide
      // the overlap evenly.
      final gPerL = _sampleAt(
        overlapEnd,
        profile,
        sessionEntries,
        sessionMeals,
      );
      if (gPerL > windowMax!) windowMax = gPerL;
    }
  }
  return windowMax;
}

/// Samples the estimated BAC at instant [t], counting only entries already
/// consumed by [t].
///
/// [estimateSessionBac] clamps `hoursSince` to `>= 0` for each entry it's
/// given (a guard against clock-skew, not "this drink hasn't happened yet")
/// — so passing it a session's *entire* entry list at an early sample point
/// would double-count not-yet-consumed drinks at their full undecayed peak,
/// summing peaks from drinks that never coexisted in the body. Filtering to
/// `consumedAt <= t` here is what makes sampling at a past instant correct.
/// Meals need no equivalent filter — `mealModifierSingle` already returns
/// 1.00 (no effect) for a meal with `deltaHours < 0`.
double _sampleAt(
  DateTime t,
  UserProfile profile,
  List<DrinkEntry> entries,
  List<Meal> meals,
) {
  final consumedByT = entries.where((e) => !e.consumedAt.isAfter(t)).toList();
  return estimateSessionBac(
    profile: profile,
    alcoholicEntries: consumedByT,
    meals: meals,
    at: t,
  ).gPerL;
}

DateTime _laterOf(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

DateTime _earlierOf(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
