// Tests for `computeMaxBacPerDay` / `buildSessionDaySummary`
// (flutter/lib/src/services/history_bac_service.dart, issue #26) — the pure
// BAC-per-day sampling that drives the History "Max estimated BAC per day"
// chart and the day drill-down's session summary card (features.md F4;
// design/party-session.md §BAC estimation algorithm).
//
// Contract points covered (see the issue brief / history_bac_service.dart's
// own doc comments):
//   1. No PartySession overlapping a day -> maxGPerL: null (not 0.0).
//   2. A day a session touches, but whose BAC has fully decayed by the
//      sampled instant -> maxGPerL: 0.0 (a real zero, not null).
//   3. 15-minute grid starting at the overlap's start (not calendar-aligned),
//      always sampling the overlap's end point too.
//   4. Sampling never runs past `now` (an active session's unknowable
//      future) nor past the session's own `endedAt`.
//   5. A session that "touches" a window per its own start/end bounds, but
//      whose *actual* overlap (after the `now` clamp) is empty, still floors
//      the bucket to 0.0 rather than leaving it null (history_bac_service.dart
//      `_maxBacForWindow`: "that still counts as 'a session was here'").
//   6. `profile == null` / `profile.birthDate == null` -> graceful nulls,
//      never a throw.
//   7. `buildSessionDaySummary`'s `duration`/`totalAlcoholicDrinks`/
//      `mealsLoggedCount` are clipped to `[dayStart, dayEnd)`, not the
//      session's full lifetime.
//
// The final group is a regression test for a fixed bug where sampling an
// early grid point counted not-yet-consumed drinks at their full undecayed
// peak (see `_sampleAt` in history_bac_service.dart and that group's comment).
//
// Added for issue #105 (History day drill-down expand-on-tap):
//   8. `buildSessionDaySummary`'s new `totalAlcoholGrams`/`meals` fields are
//      day-clipped (same scope as `totalAlcoholicDrinks`/`mealsLoggedCount`)
//      — cross-checked against `alcoholGrams` summed over the day-clipped
//      entries, not a hand-derived number (design/user-experience.md §S3:
//      "Total consumed alcohol in grams ... day-clipped").
//   9. `buildSessionLifetimeBacSeries` — the History expand card's static
//      whole-session chart (issue #105): axis spans the session's own
//      `startedAt`/`endedAt` (or `now` while active), `projected` is always
//      empty, the zero/negative-duration edge case still yields exactly one
//      point, and multi-sample points are cross-checked against
//      `estimateSessionBac` directly (replicating `_sampleAt`'s
//      `consumedAt <= t` filter, not the full entry list — see that
//      function's own doc comment on why that filter matters).
//  10. The multi-day acceptance criterion itself (design/user-experience.md
//      §S3: "For a multi-day session these are identical on every day card
//      it touches"): `buildSessionDaySummary` called for two different days
//      of the same midnight-spanning session yields different day-clipped
//      grams/meals but byte-identical `lifetimeBacChart`s and identical
//      `session.startedAt`/`endedAt`.
//  11. `buildSessionSummary` (the S9/S7 whole-session builder): issue #122
//      extended it to also populate `totalAlcoholGrams`/`lifetimeBacChart`
//      across the whole session (unclipped), gated on the same
//      profile-completeness precondition as `peakBacGPerL` — `meals`/`asOf`
//      remain unset (still `SessionDaySummary`'s own defaults), since S9
//      surfaces meals via its own merged entry list rather than this
//      builder's `meals` field.
//
// Added for issue #122 (S3 multi-day pill / S9 meals-merge / #105 meals-list
// removal):
//  12. `sessionMultiDayPosition` — the "Day N of M" pill's pure helper:
//      single-day session -> null; 2- and 4-day-window sessions -> correct
//      1-indexed `dayIndex`/`totalDays` for every touched day; the day
//      boundary is honoured (not midnight — `boundaryHour: 5`, the app
//      default), per `core`'s `dayWindow` contract; an active session
//      (`endedAt == null`) uses `now` as the effective end.
import 'package:core/core.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/models/meal.dart';
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/user_profile.dart';
import 'package:drinks_mate/src/services/bac_estimator.dart';
import 'package:drinks_mate/src/services/history_bac_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

final _epoch = DateTime.utc(2020, 1, 1);

UserProfile _profile({
  String? gender = 'male',
  double? weightKg = 75.0,
  double? heightCm = 180.0,
  String? birthDate = '1996-07-01',
}) {
  return UserProfile(
    id: 'profile-1',
    gender: gender,
    weightKg: weightKg,
    heightCm: heightCm,
    birthDate: birthDate,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

PartySession _session({
  required String id,
  required DateTime startedAt,
  DateTime? endedAt,
}) {
  return PartySession(
    id: id,
    startedAt: startedAt,
    endedAt: endedAt,
    endReason: endedAt == null ? null : PartySessionEndReason.manual,
    useSessionPrices: false,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

DrinkEntry _entry({
  required String id,
  required DateTime consumedAt,
  int volumeMl = 250,
  double abvPercent = 5.0,
  String? partySessionId,
}) {
  return DrinkEntry(
    id: id,
    beverageType: BeverageType.beer,
    volumeMl: volumeMl,
    abvPercent: abvPercent,
    partySessionId: partySessionId,
    consumedAt: consumedAt,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

Meal _meal({
  required String id,
  required DateTime eatenAt,
  required String partySessionId,
  MealSize size = MealSize.medium,
}) {
  return Meal(
    id: id,
    partySessionId: partySessionId,
    size: size,
    eatenAt: eatenAt,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

/// Mirrors `_maxBacForWindow`'s private sampling loop
/// (history_bac_service.dart) exactly, using the public [estimateSessionBac]
/// — per this task's instruction to derive grid-sampled expectations by
/// simulating the *same* grid the implementation uses, not an independently
/// computed "true peak".
double _simulateGridMax({
  required DateTime overlapStart,
  required DateTime overlapEnd,
  required List<DrinkEntry> entries,
  required List<Meal> meals,
  required UserProfile profile,
  Duration interval = const Duration(minutes: 15),
}) {
  var max = 0.0;
  var t = overlapStart;
  var lastSampled = false;
  while (!t.isAfter(overlapEnd)) {
    final estimate = estimateSessionBac(
      profile: profile,
      alcoholicEntries: entries,
      meals: meals,
      at: t,
    );
    if (estimate.gPerL > max) max = estimate.gPerL;
    lastSampled = t == overlapEnd;
    t = t.add(interval);
  }
  if (!lastSampled) {
    final estimate = estimateSessionBac(
      profile: profile,
      alcoholicEntries: entries,
      meals: meals,
      at: overlapEnd,
    );
    if (estimate.gPerL > max) max = estimate.gPerL;
  }
  return max;
}

void main() {
  // ---------------------------------------------------------------------------
  // Worked-example fixture (design/party-session.md §Worked example): 75 kg,
  // 180 cm, 30-year-old male, two 250 ml 5% ABV beers "at the same time".
  //
  // NOTE (matches the established precedent in
  // flutter/packages/core/test/bac_test.dart and
  // flutter/test/party_session_repository_test.dart): the doc's own stated
  // TBW (43.93 L -> 0.362 g/L) doesn't match its own Watson coefficients,
  // which evaluate to TBW ~= 44.14 L -> ~0.360 g/L. These tests use the
  // formula-correct value computed via `core`'s own functions (the
  // authoritative source), not the doc's arithmetic.
  // ---------------------------------------------------------------------------
  const birthDate = '1996-07-01';
  final consumedAt = DateTime.utc(2026, 7, 1, 12, 0);
  final ageYears = ageYearsFromBirthDate(
    birthDate: DateTime.parse(birthDate),
    today: consumedAt.toLocal(),
  );
  final perBeerGrams = alcoholGrams(volumeMl: 250, abvPercent: 5.0);
  final tbw = watsonTbwLitres(
    gender: Gender.male,
    ageYears: ageYears,
    heightCm: 180.0,
    weightKg: 75.0,
  );
  final twoBeerInitial = bacInitialWatson(
    alcoholGrams: 2 * perBeerGrams,
    tbwLitres: tbw,
  );
  final oneBeerInitial = bacInitialWatson(
    alcoholGrams: perBeerGrams,
    tbwLitres: tbw,
  );

  test('sanity: matches the (formula-correct) worked example', () {
    expect(twoBeerInitial, closeTo(0.360, 0.001));
  });

  // ---------------------------------------------------------------------------
  // Group 1: null (no session) vs 0.0 (session, decayed) vs a real peak.
  // ---------------------------------------------------------------------------

  group('computeMaxBacPerDay — null vs 0.0 vs real value per day', () {
    test(
        'day with the drink shows the peak; a later day the session still '
        "touches but has fully decayed shows 0.0; a day after the session "
        'ended shows null', () {
      final rangeStart = DateTime.utc(2026, 7, 1, 5, 0);
      final rangeEnd = DateTime.utc(2026, 7, 4, 5, 0); // 3 day-windows

      // Session starts exactly when the two beers are drunk (so day 1's
      // first grid sample, at overlapStart == session.startedAt ==
      // consumedAt, captures the undecayed combined peak exactly) and ends
      // mid-morning on day 2 (so day 2 is touched, day 3 is not).
      final session = _session(
        id: 's1',
        startedAt: consumedAt,
        endedAt: DateTime.utc(2026, 7, 2, 10, 0),
      );
      final entries = [
        _entry(id: 'e1', consumedAt: consumedAt, partySessionId: 's1'),
        _entry(id: 'e2', consumedAt: consumedAt, partySessionId: 's1'),
      ];

      final buckets = computeMaxBacPerDay(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        boundaryHour: 5,
        sessions: [session],
        alcoholicEntries: entries,
        meals: const [],
        profile: _profile(),
        now: DateTime.utc(2026, 7, 4, 5, 0),
      );

      expect(buckets, hasLength(3));

      // Day 1 [Jul 1 05:00, Jul 2 05:00): overlapStart == consumedAt.
      expect(buckets[0].dayStart, DateTime.utc(2026, 7, 1, 5, 0));
      expect(buckets[0].maxGPerL, closeTo(twoBeerInitial, 0.001));

      // Day 2 [Jul 2 05:00, Jul 3 05:00): the session still touches (ends
      // 10:00 that day), but day 2's own window starts ~17h after
      // consumedAt — long past elimination (~0.360/0.15 =~ 2.4h) — a real,
      // sampled zero, not "no session" (features.md F4).
      expect(buckets[1].maxGPerL, 0.0);

      // Day 3 [Jul 3 05:00, Jul 4 05:00): the session ended the day
      // before — no overlap at all — must be null, not 0.0.
      expect(buckets[2].maxGPerL, isNull);
    });

    test(
      "a session whose endedAt is EXACTLY a day's start does NOT count as "
      'touching that day — the half-open [start, end) convention used '
      'consistently elsewhere (e.g. watchSessionsInRange\'s own '
      '"starts at rangeEnd -> excluded" rule) means the previous day still '
      'reads non-null while the day starting exactly at endedAt reads null',
      () {
        // NOTE re: contract point 5 ("a session overlapping a day only at a
        // single instant, e.g. it ends exactly at that day's start, still
        // counts as touching that day") — this test demonstrates the
        // *opposite* for this exact literal wording: with the strict
        // `sessionEnd.isAfter(windowStart)` check in `_maxBacForWindow`,
        // `endedAt == dayN.start` does NOT touch day N (matches the
        // half-open convention used throughout the app). Flagging as loose
        // wording in the brief rather than a bug — the actually-reachable
        // "touches per bounds, but zero-width sampled overlap" case is
        // covered separately below (the `now`-clamp floor-to-0.0 test).
        final day1Start = DateTime.utc(2026, 7, 15, 5, 0);
        final day2Start = DateTime.utc(2026, 7, 16, 5, 0);
        final day3Start = DateTime.utc(2026, 7, 17, 5, 0);
        final drinkAt = DateTime.utc(2026, 7, 15, 20, 0);
        final session = _session(
          id: 's1',
          startedAt: drinkAt,
          endedAt: day2Start, // ends EXACTLY at day 2's start.
        );
        final entries = [
          _entry(id: 'e1', consumedAt: drinkAt, partySessionId: 's1'),
        ];

        final buckets = computeMaxBacPerDay(
          rangeStart: day1Start,
          rangeEnd: day3Start,
          boundaryHour: 5,
          sessions: [session],
          alcoholicEntries: entries,
          meals: const [],
          profile: _profile(),
          now: day3Start,
        );

        expect(buckets, hasLength(2));
        expect(
          buckets[0].maxGPerL,
          isNotNull,
          reason: 'day 1 (the drink\'s own day) is touched',
        );
        expect(
          buckets[1].maxGPerL,
          isNull,
          reason: 'day 2, which only starts exactly where the session ends, '
              'is NOT touched under the half-open [start, end) convention',
        );
      },
    );

    test('sessions.isEmpty short-circuits to all-null buckets', () {
      final rangeStart = DateTime.utc(2026, 7, 1, 5, 0);
      final rangeEnd = DateTime.utc(2026, 7, 3, 5, 0);

      final buckets = computeMaxBacPerDay(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        boundaryHour: 5,
        sessions: const [],
        alcoholicEntries: const [],
        meals: const [],
        profile: _profile(),
        now: rangeEnd,
      );

      expect(buckets, hasLength(2));
      expect(buckets.every((b) => b.maxGPerL == null), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 2: max across multiple sessions on the same day.
  // ---------------------------------------------------------------------------

  group('computeMaxBacPerDay — multiple sessions the same day', () {
    test('the bucket takes the higher of two same-day sessions\' peaks', () {
      final rangeStart = DateTime.utc(2026, 7, 10, 5, 0);
      final rangeEnd = DateTime.utc(2026, 7, 11, 5, 0);

      final sessionA = _session(
        id: 'sA',
        startedAt: DateTime.utc(2026, 7, 10, 8, 0),
        endedAt: DateTime.utc(2026, 7, 10, 9, 0),
      );
      final sessionB = _session(
        id: 'sB',
        startedAt: DateTime.utc(2026, 7, 10, 20, 0),
        endedAt: DateTime.utc(2026, 7, 10, 21, 0),
      );
      final entries = [
        _entry(
          id: 'eA',
          consumedAt: DateTime.utc(2026, 7, 10, 8, 0),
          partySessionId: 'sA',
        ),
        _entry(
          id: 'eB1',
          consumedAt: DateTime.utc(2026, 7, 10, 20, 0),
          partySessionId: 'sB',
        ),
        _entry(
          id: 'eB2',
          consumedAt: DateTime.utc(2026, 7, 10, 20, 0),
          partySessionId: 'sB',
        ),
      ];

      final buckets = computeMaxBacPerDay(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        boundaryHour: 5,
        sessions: [sessionA, sessionB],
        alcoholicEntries: entries,
        meals: const [],
        profile: _profile(),
        now: rangeEnd,
      );

      expect(buckets, hasLength(1));
      // sessionA peaks at ~oneBeerInitial (0.18), sessionB at ~twoBeerInitial
      // (0.36) — the bucket must reflect sessionB's higher peak.
      expect(oneBeerInitial, lessThan(twoBeerInitial));
      expect(buckets[0].maxGPerL, closeTo(twoBeerInitial, 0.001));
    });
  });

  // ---------------------------------------------------------------------------
  // Group 3: incomplete profile -> graceful nulls, never a throw.
  // ---------------------------------------------------------------------------

  group('computeMaxBacPerDay — incomplete profile', () {
    final rangeStart = DateTime.utc(2026, 7, 1, 5, 0);
    final rangeEnd = DateTime.utc(2026, 7, 2, 5, 0);
    final session = _session(
      id: 's1',
      startedAt: consumedAt,
      endedAt: consumedAt.add(const Duration(hours: 1)),
    );
    final entries = [
      _entry(id: 'e1', consumedAt: consumedAt, partySessionId: 's1'),
    ];

    test('profile == null -> every bucket is null, no throw', () {
      expect(
        () => computeMaxBacPerDay(
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          boundaryHour: 5,
          sessions: [session],
          alcoholicEntries: entries,
          meals: const [],
          profile: null,
          now: rangeEnd,
        ),
        returnsNormally,
      );
      final buckets = computeMaxBacPerDay(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        boundaryHour: 5,
        sessions: [session],
        alcoholicEntries: entries,
        meals: const [],
        profile: null,
        now: rangeEnd,
      );
      expect(buckets.every((b) => b.maxGPerL == null), isTrue);
    });

    test('profile.birthDate == null -> every bucket is null, no throw', () {
      final incompleteProfile = _profile(birthDate: null);
      final buckets = computeMaxBacPerDay(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        boundaryHour: 5,
        sessions: [session],
        alcoholicEntries: entries,
        meals: const [],
        profile: incompleteProfile,
        now: rangeEnd,
      );
      expect(buckets.every((b) => b.maxGPerL == null), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 4: the `now` clamp — an active session's unknowable future.
  // ---------------------------------------------------------------------------

  group('computeMaxBacPerDay — now clamp', () {
    test(
        'an active (endedAt == null) session never makes a day fully after '
        '`now` non-null — the day has not "happened yet"', () {
      final day1Start = DateTime.utc(2026, 7, 20, 5, 0);
      final day2Start = DateTime.utc(2026, 7, 21, 5, 0);
      final day3Start = DateTime.utc(2026, 7, 22, 5, 0);
      final rangeEnd = DateTime.utc(2026, 7, 23, 5, 0);

      final earlyDrink = DateTime.utc(2026, 7, 20, 6, 0);
      final session = _session(id: 's1', startedAt: day1Start);
      final entries = [
        _entry(id: 'e1', consumedAt: earlyDrink, partySessionId: 's1'),
      ];
      // "now" is partway through day 2 — the session is still active.
      final now = DateTime.utc(2026, 7, 21, 12, 0);

      final buckets = computeMaxBacPerDay(
        rangeStart: day1Start,
        rangeEnd: rangeEnd,
        boundaryHour: 5,
        sessions: [session],
        alcoholicEntries: entries,
        meals: const [],
        profile: _profile(),
        now: now,
      );

      expect(buckets, hasLength(3));
      // computeMaxBacPerDay reconstructs each subsequent day's dayStart via
      // a local-time `DateTime(...)` constructor regardless of whether
      // `rangeStart` was UTC or local (matching real callers, whose
      // `rangeStart` comes from `DateTime.now()`-based local day-window
      // helpers) — compare by instant (`isAtSameMomentAs`), not `==`,
      // since `==` also requires matching `isUtc` flags.
      expect(buckets[0].dayStart.isAtSameMomentAs(day1Start), isTrue);
      expect(buckets[1].dayStart.isAtSameMomentAs(day2Start), isTrue);
      expect(buckets[2].dayStart.isAtSameMomentAs(day3Start), isTrue);
      // Day 1 touches (fully decayed by day1's own end, but the peak
      // early in the day is still found).
      expect(buckets[0].maxGPerL, isNotNull);
      // Day 2 (contains `now`) touches — sampling is clamped at `now`,
      // not day2's end. The single old drink has long since decayed to 0
      // by day2's start (~30h after `earlyDrink`), and since the model's
      // per-sample contribution never increases with time once elapsed
      // (it only decays or stays flat), the day-2 max equals the value at
      // day2's own start — still a real, sampled 0.0.
      expect(buckets[1].maxGPerL, 0.0);
      // Day 3 is entirely *after* `now` — the active session's future is
      // unknowable, so this day must read null (no session "yet"), not a
      // bar extrapolated from an ongoing session with no defined end.
      expect(
        buckets[2].maxGPerL,
        isNull,
        reason: 'sampling must never run past `now` into an active '
            "session's unknowable future (history_bac_service.dart "
            'touchesWindow uses sessionEnd = endedAt ?? now)',
      );
    });

    test(
        'a session that touches a window per its own start/end bounds, but '
        'whose actual overlap the `now` clamp collapses to nothing, still '
        'floors the bucket at 0.0 rather than leaving it null', () {
      // Source: history_bac_service.dart _maxBacForWindow — "A session
      // touches this window (per the check above) even if `now` clamps
      // the sampled slice to zero width — that still counts as 'a session
      // was here', so the running max is floored at 0.0 rather than left
      // null."
      final dayStart = DateTime.utc(2026, 7, 5, 5, 0);
      final dayEnd = DateTime.utc(2026, 7, 6, 5, 0);
      final now = DateTime.utc(2026, 7, 5, 10, 0);
      // The session "starts" after `now` (a degenerate, clock-skew-style
      // input — never produced by normal session-start flow, but not
      // rejected by the type system either) so its window still overlaps
      // `[dayStart, dayEnd)` per the coarse start/end check, yet the
      // `now`-clamped actual overlap is empty.
      final session = _session(
        id: 's1',
        startedAt: DateTime.utc(2026, 7, 5, 12, 0),
      );

      final buckets = computeMaxBacPerDay(
        rangeStart: dayStart,
        rangeEnd: dayEnd,
        boundaryHour: 5,
        sessions: [session],
        alcoholicEntries: const [],
        meals: const [],
        profile: _profile(),
        now: now,
      );

      expect(buckets, hasLength(1));
      expect(buckets[0].maxGPerL, 0.0);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 5: 15-minute grid mechanics (contract point 3).
  // ---------------------------------------------------------------------------

  group('computeMaxBacPerDay — 15-minute grid sampling', () {
    test(
        'a non-15-minute-aligned overlap samples the same grid the '
        'implementation uses, always including the overlap end point', () {
      final dayStart = DateTime.utc(2026, 7, 12, 5, 0);
      final dayEnd = DateTime.utc(2026, 7, 13, 5, 0);
      // Deliberately not aligned to :00/:15/:30/:45 and not a multiple of
      // 15 minutes apart, per the grid's "starts at the overlap start, not
      // calendar-aligned" contract.
      final sessionStart = DateTime.utc(2026, 7, 12, 6, 7);
      final sessionEnd = DateTime.utc(2026, 7, 12, 9, 52);
      final session = _session(
        id: 's1',
        startedAt: sessionStart,
        endedAt: sessionEnd,
      );
      final entries = [
        _entry(id: 'e1', consumedAt: sessionStart, partySessionId: 's1'),
      ];
      final profile = _profile();

      final expected = _simulateGridMax(
        overlapStart: sessionStart,
        overlapEnd: sessionEnd,
        entries: entries,
        meals: const [],
        profile: profile,
      );

      final buckets = computeMaxBacPerDay(
        rangeStart: dayStart,
        rangeEnd: dayEnd,
        boundaryHour: 5,
        sessions: [session],
        alcoholicEntries: entries,
        meals: const [],
        profile: profile,
        now: dayEnd,
      );

      expect(buckets, hasLength(1));
      expect(buckets[0].maxGPerL, closeTo(expected, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // Group 6: buildSessionDaySummary — per-day clipping.
  // ---------------------------------------------------------------------------

  group('buildSessionDaySummary — clips to the day window', () {
    final day1Start = DateTime.utc(2026, 7, 20, 5, 0);
    final day2Start = DateTime.utc(2026, 7, 21, 5, 0);
    final day3Start = DateTime.utc(2026, 7, 22, 5, 0);

    test(
        'a session spanning midnight gets a shorter, correctly-clipped '
        'duration on each day it touches', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime.utc(2026, 7, 20, 22, 0),
        endedAt: DateTime.utc(2026, 7, 21, 8, 0),
      );

      final day1Summary = buildSessionDaySummary(
        session: session,
        dayStart: day1Start,
        dayEnd: day2Start,
        entries: const [],
        meals: const [],
        profile: _profile(),
        now: day2Start,
      );
      final day2Summary = buildSessionDaySummary(
        session: session,
        dayStart: day2Start,
        dayEnd: day3Start,
        entries: const [],
        meals: const [],
        profile: _profile(),
        now: day3Start,
      );

      // Day 1: 22:00 -> day1's own end (05:00) = 7h.
      expect(day1Summary.duration, const Duration(hours: 7));
      // Day 2: day2's start (05:00) -> session end (08:00) = 3h.
      expect(day2Summary.duration, const Duration(hours: 3));
    });

    test(
        "totalAlcoholicDrinks counts only that day's entries for the "
        "session, excluding entries on other days and (per the session's "
        "own unclipped entries list) counting entries even after the "
        "session's own endedAt if their consumedAt still falls in the day "
        'window', () {
      final session = _session(
        id: 's1',
        startedAt: day2Start,
        endedAt: DateTime.utc(2026, 7, 21, 7, 0),
      );
      final entries = [
        // Within the session's active window AND day 2.
        _entry(
          id: 'e1',
          consumedAt: DateTime.utc(2026, 7, 21, 6, 0),
          volumeMl: 250,
          partySessionId: 's1',
        ),
        // After the session's own endedAt (07:00), but still same
        // partySessionId and still within day 2's window — the
        // implementation filters by day window only, not by the
        // session's own start/end, for this count.
        _entry(
          id: 'e2',
          consumedAt: DateTime.utc(2026, 7, 21, 9, 0),
          volumeMl: 330,
          partySessionId: 's1',
        ),
        // The previous day — excluded from day 2's total.
        _entry(
          id: 'e3',
          consumedAt: DateTime.utc(2026, 7, 20, 23, 0),
          volumeMl: 500,
          partySessionId: 's1',
        ),
      ];
      final meals = [
        // Within day 2 — counted.
        _meal(
          id: 'm1',
          eatenAt: DateTime.utc(2026, 7, 21, 6, 30),
          partySessionId: 's1',
        ),
        // The previous day — excluded from day 2's count.
        _meal(
          id: 'm2',
          eatenAt: DateTime.utc(2026, 7, 20, 23, 0),
          partySessionId: 's1',
        ),
      ];

      final summary = buildSessionDaySummary(
        session: session,
        dayStart: day2Start,
        dayEnd: day3Start,
        entries: entries,
        meals: meals,
        profile: _profile(),
        now: day3Start,
      );

      expect(summary.totalAlcoholicDrinks, 2);
      expect(summary.mealsLoggedCount, 1);
    });

    test('peakBacGPerL reflects only that day\'s sampled window', () {
      // Single dose, consumed exactly at the session/day start so the
      // grid's first sample captures the exact undecayed peak — avoids the
      // multi-drink summation issue flagged separately in this file.
      final session = _session(
        id: 's1',
        startedAt: day2Start,
        endedAt: day2Start.add(const Duration(hours: 2)),
      );
      final entries = [
        _entry(id: 'e1', consumedAt: day2Start, partySessionId: 's1'),
      ];

      final summary = buildSessionDaySummary(
        session: session,
        dayStart: day2Start,
        dayEnd: day3Start,
        entries: entries,
        meals: const [],
        profile: _profile(),
        now: day2Start.add(const Duration(hours: 2)),
      );

      expect(summary.peakBacGPerL, closeTo(oneBeerInitial, 0.001));
    });

    test(
        'profile == null -> peakBacGPerL is null but '
        'duration/totalAlcoholicDrinks are still computed correctly (no '
        'throw)', () {
      final session = _session(
        id: 's1',
        startedAt: day2Start,
        endedAt: day2Start.add(const Duration(hours: 2)),
      );
      final entries = [
        _entry(
          id: 'e1',
          consumedAt: day2Start,
          volumeMl: 250,
          partySessionId: 's1',
        ),
      ];

      final summary = buildSessionDaySummary(
        session: session,
        dayStart: day2Start,
        dayEnd: day3Start,
        entries: entries,
        meals: const [],
        profile: null,
        now: day2Start.add(const Duration(hours: 2)),
      );

      expect(summary.peakBacGPerL, isNull);
      expect(summary.duration, const Duration(hours: 2));
      expect(summary.totalAlcoholicDrinks, 1);
    });

    test('profile.birthDate == null -> peakBacGPerL is null, no throw', () {
      final session = _session(
        id: 's1',
        startedAt: day2Start,
        endedAt: day2Start.add(const Duration(hours: 2)),
      );
      final summary = buildSessionDaySummary(
        session: session,
        dayStart: day2Start,
        dayEnd: day3Start,
        entries: const [],
        meals: const [],
        profile: _profile(birthDate: null),
        now: day2Start.add(const Duration(hours: 2)),
      );
      expect(summary.peakBacGPerL, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 8: buildSessionDaySummary — new day-clipped totalAlcoholGrams/meals
  // fields (issue #105).
  // ---------------------------------------------------------------------------

  group(
    'buildSessionDaySummary — totalAlcoholGrams/meals are day-clipped '
    '(issue #105)',
    () {
      final day2Start = DateTime.utc(2026, 7, 21, 5, 0);
      final day3Start = DateTime.utc(2026, 7, 22, 5, 0);

      test(
          'totalAlcoholGrams sums only that day\'s entries (cross-checked '
          "against core's alcoholGrams, not a hand-derived number), and "
          'meals.length == mealsLoggedCount', () {
        final session = _session(
          id: 's1',
          startedAt: day2Start,
          endedAt: DateTime.utc(2026, 7, 21, 7, 0),
        );
        final entries = [
          // Within day 2 — counted.
          _entry(
            id: 'e1',
            consumedAt: DateTime.utc(2026, 7, 21, 6, 0),
            volumeMl: 250,
            abvPercent: 5.0,
            partySessionId: 's1',
          ),
          _entry(
            id: 'e2',
            consumedAt: DateTime.utc(2026, 7, 21, 6, 30),
            volumeMl: 330,
            abvPercent: 4.5,
            partySessionId: 's1',
          ),
          // The previous day — excluded from day 2's grams total, same
          // day-window filter buildSessionDaySummary already applies to
          // totalAlcoholicDrinks (Group 6 above).
          _entry(
            id: 'e3',
            consumedAt: DateTime.utc(2026, 7, 20, 23, 0),
            volumeMl: 500,
            abvPercent: 5.0,
            partySessionId: 's1',
          ),
        ];
        final meals = [
          _meal(
            id: 'm1',
            eatenAt: DateTime.utc(2026, 7, 21, 6, 15),
            partySessionId: 's1',
            size: MealSize.large,
          ),
          // Previous day — excluded.
          _meal(
            id: 'm2',
            eatenAt: DateTime.utc(2026, 7, 20, 23, 0),
            partySessionId: 's1',
          ),
        ];

        final summary = buildSessionDaySummary(
          session: session,
          dayStart: day2Start,
          dayEnd: day3Start,
          entries: entries,
          meals: meals,
          profile: _profile(),
          now: day3Start,
        );

        // Source: alcoholGrams (package:core) — Parity Rulebook's own
        // grams-of-alcohol formula, summed over only the day-clipped
        // entries (e1 + e2, excluding e3).
        final expectedGrams = alcoholGrams(volumeMl: 250, abvPercent: 5.0) +
            alcoholGrams(volumeMl: 330, abvPercent: 4.5);
        expect(summary.totalAlcoholGrams, closeTo(expectedGrams, 1e-9));

        expect(summary.meals, hasLength(1));
        expect(summary.meals.single.id, 'm1');
        expect(summary.meals.length, summary.mealsLoggedCount);
      });

      test('no entries that day -> totalAlcoholGrams is 0, meals is empty', () {
        final session = _session(
          id: 's1',
          startedAt: day2Start,
          endedAt: day2Start.add(const Duration(hours: 1)),
        );

        final summary = buildSessionDaySummary(
          session: session,
          dayStart: day2Start,
          dayEnd: day3Start,
          entries: const [],
          meals: const [],
          profile: _profile(),
          now: day3Start,
        );

        expect(summary.totalAlcoholGrams, 0);
        expect(summary.meals, isEmpty);
      });

      test('asOf is set to the `now` the summary was built with', () {
        final session = _session(
          id: 's1',
          startedAt: day2Start,
          endedAt: day2Start.add(const Duration(hours: 1)),
        );
        final now = day2Start.add(const Duration(hours: 4));

        final summary = buildSessionDaySummary(
          session: session,
          dayStart: day2Start,
          dayEnd: day3Start,
          entries: const [],
          meals: const [],
          profile: _profile(),
          now: now,
        );

        expect(summary.asOf, now);
      });
    },
  );

  // ---------------------------------------------------------------------------
  // Group 9: buildSessionLifetimeBacSeries — the History expand card's
  // static whole-session BAC chart (issue #105).
  // ---------------------------------------------------------------------------

  group('buildSessionLifetimeBacSeries', () {
    test(
        'axis spans the session\'s own startedAt/endedAt (local), and '
        '`projected` is always empty — a static, already-elapsed view, '
        'unlike the Party tab\'s live projection chart', () {
      final startedAt = DateTime.utc(2026, 7, 21, 18, 0);
      final endedAt = DateTime.utc(2026, 7, 21, 18, 20);
      final session =
          _session(id: 's1', startedAt: startedAt, endedAt: endedAt);
      final entries = [
        _entry(id: 'e1', consumedAt: startedAt, partySessionId: 's1'),
      ];

      final series = buildSessionLifetimeBacSeries(
        session: session,
        alcoholicEntries: entries,
        meals: const [],
        profile: _profile(),
        now: endedAt,
      );

      expect(series.axisStart, startedAt.toLocal());
      expect(series.axisEnd, endedAt.toLocal());
      expect(series.projected, isEmpty);
    });

    test(
        'a still-active session (endedAt == null) uses `now` as axisEnd, not '
        'a projected sober time', () {
      final startedAt = DateTime.utc(2026, 7, 21, 18, 0);
      final now = startedAt.add(const Duration(minutes: 20));
      final session = _session(id: 's1', startedAt: startedAt);

      final series = buildSessionLifetimeBacSeries(
        session: session,
        alcoholicEntries: const [],
        meals: const [],
        profile: _profile(),
        now: now,
      );

      expect(series.axisEnd, now.toLocal());
      expect(series.projected, isEmpty);
    });

    test(
        'zero/negative-duration edge case (endedAt not after startedAt): '
        'axisEnd clamps to axisStart, and `actual` still has exactly one '
        'point (history_bac_service.dart doc comment: "if endedAt/now is '
        'not after startedAt ... axisEnd is clamped to axisStart")', () {
      final startedAt = DateTime.utc(2026, 7, 21, 18, 0);
      // endedAt EXACTLY equal to startedAt — the boundary of the "not after"
      // clamp condition.
      final session =
          _session(id: 's1', startedAt: startedAt, endedAt: startedAt);

      final series = buildSessionLifetimeBacSeries(
        session: session,
        alcoholicEntries: const [],
        meals: const [],
        profile: _profile(),
        now: startedAt,
      );

      expect(series.axisEnd.isAtSameMomentAs(series.axisStart), isTrue);
      expect(series.actual, hasLength(1));
      expect(series.actual.single.time, series.axisStart);
    });

    test(
        'a genuinely negative window (endedAt before startedAt — a '
        'degenerate/clock-skew-style input, never produced by normal '
        'session flow) still clamps axisEnd to axisStart rather than '
        'producing a negative-length axis', () {
      final startedAt = DateTime.utc(2026, 7, 21, 18, 0);
      final endedAt = startedAt.subtract(const Duration(minutes: 5));
      final session =
          _session(id: 's1', startedAt: startedAt, endedAt: endedAt);

      final series = buildSessionLifetimeBacSeries(
        session: session,
        alcoholicEntries: const [],
        meals: const [],
        profile: _profile(),
        now: startedAt,
      );

      expect(series.axisEnd.isAtSameMomentAs(series.axisStart), isTrue);
      expect(series.actual, hasLength(1));
    });

    test(
        'multi-sample points are cross-checked against estimateSessionBac '
        'directly, replicating the consumedAt <= t filter _sampleAt applies '
        '(a single dose consumed exactly at startedAt keeps the filter a '
        'no-op at every sampled instant)', () {
      final startedAt = DateTime.utc(2026, 7, 21, 18, 0);
      final endedAt = startedAt.add(const Duration(minutes: 20));
      final session =
          _session(id: 's1', startedAt: startedAt, endedAt: endedAt);
      final entries = [
        _entry(id: 'e1', consumedAt: startedAt, partySessionId: 's1'),
      ];
      final profile = _profile();

      final series = buildSessionLifetimeBacSeries(
        session: session,
        alcoholicEntries: entries,
        meals: const [],
        profile: profile,
        now: endedAt,
        sampleInterval: const Duration(minutes: 5),
      );

      // 20-minute span / 5-minute interval = 5 points (0,5,10,15,20).
      expect(series.actual, hasLength(5));
      for (final point in series.actual) {
        final consumedByPoint =
            entries.where((e) => !e.consumedAt.isAfter(point.time)).toList();
        final expected = estimateSessionBac(
          profile: profile,
          alcoholicEntries: consumedByPoint,
          meals: const [],
          at: point.time,
        ).gPerL;
        expect(point.gPerL, closeTo(expected, 0.001));
      }
      // The first point captures the undecayed peak exactly (sampled at
      // startedAt itself).
      expect(series.actual.first.gPerL, closeTo(oneBeerInitial, 0.001));
    });

    test('tickInterval matches bacChartTickInterval(axisEnd - axisStart)', () {
      final startedAt = DateTime.utc(2026, 7, 21, 18, 0);
      final endedAt = startedAt.add(const Duration(hours: 3));
      final session =
          _session(id: 's1', startedAt: startedAt, endedAt: endedAt);

      final series = buildSessionLifetimeBacSeries(
        session: session,
        alcoholicEntries: const [],
        meals: const [],
        profile: _profile(),
        now: endedAt,
      );

      expect(
        series.tickInterval,
        bacChartTickInterval(series.axisEnd.difference(series.axisStart)),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group 10: the multi-day invariant (design/user-experience.md §S3: "For a
  // multi-day session these are identical on every day card it touches") —
  // the core acceptance criterion of issue #105.
  // ---------------------------------------------------------------------------

  group(
    'buildSessionDaySummary — multi-day session: lifetimeBacChart and '
    'session start/end are identical across every day card, while '
    'grams/meals differ per day',
    () {
      test(
          'a session spanning midnight yields different day-clipped grams/'
          'meals for day 1 vs day 2, but byte-identical lifetimeBacChart '
          'axis/points and identical session.startedAt/endedAt', () {
        final day1Start = DateTime.utc(2026, 7, 20, 5, 0);
        final day2Start = DateTime.utc(2026, 7, 21, 5, 0);
        final day3Start = DateTime.utc(2026, 7, 22, 5, 0);
        final startedAt = DateTime.utc(2026, 7, 20, 22, 0);
        final endedAt = DateTime.utc(2026, 7, 21, 8, 0);
        final session =
            _session(id: 's1', startedAt: startedAt, endedAt: endedAt);
        final entries = [
          // Day 1 (before midnight).
          _entry(
            id: 'e1',
            consumedAt: DateTime.utc(2026, 7, 20, 23, 0),
            volumeMl: 250,
            abvPercent: 5.0,
            partySessionId: 's1',
          ),
          // Day 2 (after midnight).
          _entry(
            id: 'e2',
            consumedAt: DateTime.utc(2026, 7, 21, 6, 0),
            volumeMl: 330,
            abvPercent: 4.5,
            partySessionId: 's1',
          ),
        ];
        final meals = [
          _meal(
            id: 'm1',
            eatenAt: DateTime.utc(2026, 7, 20, 23, 30),
            partySessionId: 's1',
          ),
        ];
        final now = day3Start;

        final day1Summary = buildSessionDaySummary(
          session: session,
          dayStart: day1Start,
          dayEnd: day2Start,
          entries: entries,
          meals: meals,
          profile: _profile(),
          now: now,
        );
        final day2Summary = buildSessionDaySummary(
          session: session,
          dayStart: day2Start,
          dayEnd: day3Start,
          entries: entries,
          meals: meals,
          profile: _profile(),
          now: now,
        );

        // Day-clipped fields genuinely differ per day.
        expect(day1Summary.totalAlcoholicDrinks, 1);
        expect(day2Summary.totalAlcoholicDrinks, 1);
        expect(day1Summary.meals, hasLength(1));
        expect(day2Summary.meals, isEmpty);
        expect(
          day1Summary.totalAlcoholGrams,
          isNot(closeTo(day2Summary.totalAlcoholGrams, 1e-9)),
          reason: 'e1 (250ml/5%) and e2 (330ml/4.5%) have different grams',
        );

        // Session-level facts (not day-clipped) are identical on both cards.
        expect(
          day1Summary.session.startedAt,
          day2Summary.session.startedAt,
        );
        expect(day1Summary.session.endedAt, day2Summary.session.endedAt);

        // lifetimeBacChart is built from the session's whole (unclipped)
        // lifetime on both cards — identical axis and every sampled point,
        // even though the two day windows themselves differ.
        final chart1 = day1Summary.lifetimeBacChart!;
        final chart2 = day2Summary.lifetimeBacChart!;
        expect(chart1.axisStart, chart2.axisStart);
        expect(chart1.axisEnd, chart2.axisEnd);
        expect(chart1.actual, hasLength(chart2.actual.length));
        for (var i = 0; i < chart1.actual.length; i++) {
          expect(chart1.actual[i].time, chart2.actual[i].time);
          expect(chart1.actual[i].gPerL, chart2.actual[i].gPerL);
        }
      });

      test(
          'lifetimeBacChart is null exactly when peakBacGPerL is null '
          '(incomplete profile)', () {
        final day2Start = DateTime.utc(2026, 7, 21, 5, 0);
        final day3Start = DateTime.utc(2026, 7, 22, 5, 0);
        final session = _session(
          id: 's1',
          startedAt: day2Start,
          endedAt: day2Start.add(const Duration(hours: 1)),
        );

        final summary = buildSessionDaySummary(
          session: session,
          dayStart: day2Start,
          dayEnd: day3Start,
          entries: const [],
          meals: const [],
          profile: _profile(birthDate: null),
          now: day3Start,
        );

        expect(summary.peakBacGPerL, isNull);
        expect(summary.lifetimeBacChart, isNull);
      });
    },
  );

  // ---------------------------------------------------------------------------
  // buildSessionSummary — whole-session (unclipped) sibling of
  // buildSessionDaySummary (history_bac_service.dart doc comment: "every
  // metric spans [startedAt, endedAt) ... rather than a single calendar
  // day"). Feeds the S7 past-sessions list and S9's ended-mode header
  // (user-experience.md §S9).
  // ---------------------------------------------------------------------------

  group(
    'buildSessionSummary — whole-session (unclipped)',
    () {
      test(
        'a session spanning midnight, with entries/meals on both sides, is '
        'not clipped to either day — duration/counts/peak span the entire '
        '[startedAt, endedAt) lifetime',
        () {
          final startedAt = DateTime.utc(2026, 7, 20, 22, 0);
          final endedAt = DateTime.utc(2026, 7, 21, 8, 0);
          final session =
              _session(id: 's1', startedAt: startedAt, endedAt: endedAt);
          final entries = [
            // Before midnight.
            _entry(
              id: 'e1',
              consumedAt: DateTime.utc(2026, 7, 20, 23, 0),
              partySessionId: 's1',
            ),
            // After midnight, still inside the session.
            _entry(
              id: 'e2',
              consumedAt: DateTime.utc(2026, 7, 21, 6, 0),
              partySessionId: 's1',
            ),
          ];
          final meals = [
            _meal(
              id: 'm1',
              eatenAt: DateTime.utc(2026, 7, 20, 23, 30),
              partySessionId: 's1',
            ),
            _meal(
              id: 'm2',
              eatenAt: DateTime.utc(2026, 7, 21, 6, 30),
              partySessionId: 's1',
            ),
          ];

          final summary = buildSessionSummary(
            session: session,
            entries: entries,
            meals: meals,
            profile: _profile(),
            now: endedAt,
          );

          // Full lifetime — 22:00 -> 08:00 next day = 10h, not clipped to
          // either day's own window (contrast buildSessionDaySummary's
          // "clips to the day window" group above, which would report 2h
          // for day 1 and 8h for day 2 for this same session).
          expect(summary.duration, const Duration(hours: 10));
          expect(summary.totalAlcoholicDrinks, 2);
          expect(summary.mealsLoggedCount, 2);
        },
      );

      test(
        'peakBacGPerL is sampled across the whole lifetime, cross-checked '
        'against estimateSessionBac directly rather than a hand-derived '
        'number',
        () {
          final startedAt = DateTime.utc(2026, 7, 20, 22, 0);
          final endedAt = DateTime.utc(2026, 7, 21, 2, 0);
          final session =
              _session(id: 's1', startedAt: startedAt, endedAt: endedAt);
          // Single dose consumed exactly at session start, so the grid's
          // first sample captures the undecayed peak exactly (avoids the
          // multi-drink summation caveat documented in the regression group
          // below).
          final entries = [
            _entry(id: 'e1', consumedAt: startedAt, partySessionId: 's1'),
          ];

          final summary = buildSessionSummary(
            session: session,
            entries: entries,
            meals: const [],
            profile: _profile(),
            now: endedAt,
          );

          expect(summary.peakBacGPerL, closeTo(oneBeerInitial, 0.001));
          // Cross-check directly against estimateSessionBac at t=startedAt,
          // per this task's instruction to verify against the estimator
          // rather than an independently hand-computed magic number.
          expect(
            summary.peakBacGPerL,
            closeTo(
              estimateSessionBac(
                profile: _profile(),
                alcoholicEntries: entries,
                meals: const [],
                at: startedAt,
              ).gPerL,
              0.001,
            ),
          );
        },
      );

      test(
        'a still-active session (endedAt == null) spans [startedAt, now) '
        'instead of throwing or defaulting to zero duration',
        () {
          final startedAt = DateTime.utc(2026, 7, 20, 22, 0);
          final now = startedAt.add(const Duration(hours: 3));
          final session = _session(id: 's1', startedAt: startedAt);

          final summary = buildSessionSummary(
            session: session,
            entries: const [],
            meals: const [],
            profile: _profile(),
            now: now,
          );

          expect(summary.duration, const Duration(hours: 3));
        },
      );

      test(
        'entries/meals belonging to a different session are ignored',
        () {
          final startedAt = DateTime.utc(2026, 7, 20, 22, 0);
          final endedAt = DateTime.utc(2026, 7, 21, 2, 0);
          final session =
              _session(id: 's1', startedAt: startedAt, endedAt: endedAt);
          final entries = [
            _entry(id: 'e1', consumedAt: startedAt, partySessionId: 's1'),
            _entry(
              id: 'e2',
              consumedAt: startedAt,
              partySessionId: 'other-session',
            ),
          ];
          final meals = [
            _meal(id: 'm1', eatenAt: startedAt, partySessionId: 's1'),
            _meal(
                id: 'm2', eatenAt: startedAt, partySessionId: 'other-session'),
          ];

          final summary = buildSessionSummary(
            session: session,
            entries: entries,
            meals: meals,
            profile: _profile(),
            now: endedAt,
          );

          expect(summary.totalAlcoholicDrinks, 1);
          expect(summary.mealsLoggedCount, 1);
        },
      );

      test(
        'profile == null -> peakBacGPerL is null but duration/counts are '
        'still computed correctly (no throw)',
        () {
          final startedAt = DateTime.utc(2026, 7, 20, 22, 0);
          final endedAt = DateTime.utc(2026, 7, 21, 2, 0);
          final session =
              _session(id: 's1', startedAt: startedAt, endedAt: endedAt);
          final entries = [
            _entry(id: 'e1', consumedAt: startedAt, partySessionId: 's1'),
          ];

          final summary = buildSessionSummary(
            session: session,
            entries: entries,
            meals: const [],
            profile: null,
            now: endedAt,
          );

          expect(summary.peakBacGPerL, isNull);
          expect(summary.duration, const Duration(hours: 4));
          expect(summary.totalAlcoholicDrinks, 1);
        },
      );

      test(
          'profile.birthDate == null -> peakBacGPerL and lifetimeBacChart '
          'are both null, no throw (mirrors buildSessionDaySummary\'s '
          'identical null-profile chart guard)', () {
        final startedAt = DateTime.utc(2026, 7, 20, 22, 0);
        final endedAt = DateTime.utc(2026, 7, 21, 2, 0);
        final session =
            _session(id: 's1', startedAt: startedAt, endedAt: endedAt);

        final summary = buildSessionSummary(
          session: session,
          entries: const [],
          meals: const [],
          profile: _profile(birthDate: null),
          now: endedAt,
        );

        expect(summary.peakBacGPerL, isNull);
        expect(summary.lifetimeBacChart, isNull);
      });

      test(
          'issue #122: buildSessionSummary now populates totalAlcoholGrams '
          'and lifetimeBacChart across the whole (unclipped) session — '
          'cross-checked against core\'s alcoholGrams directly, not a '
          'hand-derived number, mirroring buildSessionDaySummary\'s own '
          'grams test above. meals/asOf remain unset (still '
          'SessionDaySummary\'s own defaults) — S9 surfaces meals via its '
          'own merged entry list, not this field', () {
        final startedAt = DateTime.utc(2026, 7, 20, 22, 0);
        final endedAt = DateTime.utc(2026, 7, 21, 2, 0);
        final session =
            _session(id: 's1', startedAt: startedAt, endedAt: endedAt);
        final entries = [
          // Before midnight.
          _entry(
            id: 'e1',
            consumedAt: DateTime.utc(2026, 7, 20, 23, 0),
            volumeMl: 250,
            abvPercent: 5.0,
            partySessionId: 's1',
          ),
          // After midnight, still inside the session.
          _entry(
            id: 'e2',
            consumedAt: DateTime.utc(2026, 7, 21, 1, 0),
            volumeMl: 330,
            abvPercent: 4.5,
            partySessionId: 's1',
          ),
        ];
        final meals = [
          _meal(id: 'm1', eatenAt: startedAt, partySessionId: 's1'),
        ];

        final summary = buildSessionSummary(
          session: session,
          entries: entries,
          meals: meals,
          profile: _profile(),
          now: endedAt,
        );

        // Source: alcoholGrams (package:core) — Parity Rulebook's own
        // grams-of-alcohol formula, summed over the whole (unclipped)
        // session, not a single day.
        final expectedGrams = alcoholGrams(volumeMl: 250, abvPercent: 5.0) +
            alcoholGrams(volumeMl: 330, abvPercent: 4.5);
        expect(summary.totalAlcoholGrams, closeTo(expectedGrams, 1e-9));

        expect(summary.lifetimeBacChart, isNotNull);
        expect(summary.lifetimeBacChart!.axisStart, startedAt.toLocal());
        expect(summary.lifetimeBacChart!.axisEnd, endedAt.toLocal());

        // meals/asOf remain unset (SessionDaySummary's own defaults) —
        // buildSessionSummary doesn't scope a day-clipped meals list (that's
        // buildSessionDaySummary's job); S9 merges meals into its own entry
        // list instead (party_session_log_screen.dart).
        expect(summary.meals, isEmpty);
        expect(summary.asOf, isNull);
      });
    },
  );

  // ---------------------------------------------------------------------------
  // sessionMultiDayPosition — the "Day N of M" pill's pure helper (issue
  // #122, design/user-experience.md §S3 multi-day indicator).
  // ---------------------------------------------------------------------------

  group('sessionMultiDayPosition', () {
    // boundaryHour: 5 throughout (the app default) — deliberately NOT
    // midnight, so these tests also exercise dayWindow's own "a pre-boundary
    // instant belongs to the PREVIOUS day-window" contract (see
    // flutter/packages/core/test/day_boundary_test.dart /
    // day_boundary.dart's `dayWindow`), not just plain calendar-day math.
    final day1Start = DateTime.utc(2026, 7, 20, 5, 0);
    final day2Start = DateTime.utc(2026, 7, 21, 5, 0);
    final day3Start = DateTime.utc(2026, 7, 22, 5, 0);
    final day4Start = DateTime.utc(2026, 7, 23, 5, 0);

    test('(a) a session fully inside one day-window returns null', () {
      final session = _session(
        id: 's1',
        startedAt: day1Start.add(const Duration(hours: 2)),
        endedAt: day1Start.add(const Duration(hours: 5)),
      );

      final result = sessionMultiDayPosition(
        session: session,
        dayStart: day1Start,
        boundaryHour: 5,
        now: day1Start.add(const Duration(hours: 6)),
      );

      expect(result, isNull);
    });

    test(
        '(b) a session spanning exactly 2 day-windows returns correct '
        'dayIndex/totalDays for both day 1\'s and day 2\'s dayStart', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime.utc(2026, 7, 20, 22, 0),
        endedAt: DateTime.utc(2026, 7, 21, 8, 0),
      );
      final now = DateTime.utc(2026, 7, 21, 8, 0);

      final day1Result = sessionMultiDayPosition(
        session: session,
        dayStart: day1Start,
        boundaryHour: 5,
        now: now,
      );
      final day2Result = sessionMultiDayPosition(
        session: session,
        dayStart: day2Start,
        boundaryHour: 5,
        now: now,
      );

      expect(day1Result, (dayIndex: 1, totalDays: 2));
      expect(day2Result, (dayIndex: 2, totalDays: 2));
    });

    test(
        '(c) a session spanning 4 day-windows returns the correct middle '
        'index', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime.utc(2026, 7, 20, 20, 0),
        endedAt: DateTime.utc(2026, 7, 23, 8, 0),
      );
      final now = DateTime.utc(2026, 7, 23, 8, 0);

      final result = sessionMultiDayPosition(
        session: session,
        dayStart: day3Start,
        boundaryHour: 5,
        now: now,
      );

      expect(result, (dayIndex: 3, totalDays: 4));
      // Sanity-check the other end of the same span, per (b)'s pattern.
      expect(
        sessionMultiDayPosition(
          session: session,
          dayStart: day1Start,
          boundaryHour: 5,
          now: now,
        ),
        (dayIndex: 1, totalDays: 4),
      );
      expect(
        sessionMultiDayPosition(
          session: session,
          dayStart: day4Start,
          boundaryHour: 5,
          now: now,
        ),
        (dayIndex: 4, totalDays: 4),
      );
    });

    test(
        '(d) the boundary is NOT midnight (boundaryHour: 5) — a session '
        'starting at 04:00 belongs to the PREVIOUS day-window, matching '
        'dayWindow\'s own contract, not a naive calendar-day split', () {
      // 04:00 is before the 05:00 boundary, so per dayWindow it falls in
      // the day-window that STARTED the day before (day1Start), not
      // day2Start — this is the case the task brief calls out explicitly.
      final startedAt = DateTime.utc(2026, 7, 21, 4, 0);
      final endedAt = DateTime.utc(2026, 7, 21, 8, 0);
      final session =
          _session(id: 's1', startedAt: startedAt, endedAt: endedAt);
      final now = endedAt;

      // Sanity check against dayWindow directly (core's own contract) —
      // confirms the fixture actually exercises the non-midnight boundary
      // rather than assuming it.
      final startedAtWindow = dayWindow(now: startedAt, boundaryHour: 5);
      expect(
        startedAtWindow.$1.isAtSameMomentAs(day1Start),
        isTrue,
        reason: '04:00 is before the 05:00 boundary, so it falls in the '
            "PREVIOUS day-window (day1Start), not day2Start's",
      );

      final day1Result = sessionMultiDayPosition(
        session: session,
        dayStart: day1Start,
        boundaryHour: 5,
        now: now,
      );
      final day2Result = sessionMultiDayPosition(
        session: session,
        dayStart: day2Start,
        boundaryHour: 5,
        now: now,
      );

      expect(day1Result, (dayIndex: 1, totalDays: 2));
      expect(day2Result, (dayIndex: 2, totalDays: 2));
    });

    test(
        '(e) an active session (endedAt == null) uses `now` as the '
        'effective end', () {
      final session = _session(
        id: 's1',
        startedAt: DateTime.utc(2026, 7, 20, 20, 0),
        // endedAt: null — still active.
      );
      final now = DateTime.utc(2026, 7, 21, 8, 0);

      final day1Result = sessionMultiDayPosition(
        session: session,
        dayStart: day1Start,
        boundaryHour: 5,
        now: now,
      );
      final day2Result = sessionMultiDayPosition(
        session: session,
        dayStart: day2Start,
        boundaryHour: 5,
        now: now,
      );

      expect(day1Result, (dayIndex: 1, totalDays: 2));
      expect(day2Result, (dayIndex: 2, totalDays: 2));
    });

    test(
        'an active session still fully inside its own single day-window '
        'returns null (the `now` effective-end does not itself force a '
        'multi-day result)', () {
      final session = _session(
        id: 's1',
        startedAt: day1Start.add(const Duration(hours: 1)),
      );
      final now = day1Start.add(const Duration(hours: 3));

      final result = sessionMultiDayPosition(
        session: session,
        dayStart: day1Start,
        boundaryHour: 5,
        now: now,
      );

      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 7: multi-drink over-reporting regression (previously a known bug).
  // ---------------------------------------------------------------------------

  group('computeMaxBacPerDay — multi-drink over-reporting regression', () {
    test(
        'two drinks 3 hours apart (first fully eliminated before the second) '
        'reports a peak near the higher single-dose value (~0.180 g/L), not '
        'the sum of both undecayed doses (~0.359 g/L)', () {
      // Regression test for a fixed bug: `_maxBacForWindow` used to sample
      // `t = overlapStart` (before the session's later drinks were even
      // logged) while passing the session's *entire* entry list to
      // `estimateSessionBac`. Since `estimateSessionBac` clamps
      // `hoursSince` to >= 0 (bac_estimator.dart, "Clamp to >=0" comment),
      // a not-yet-consumed drink counted at its full undecayed
      // `bacInitial` instead of 0, so this scenario used to report
      // ~0.359 g/L (both drinks "already peaked" simultaneously) instead
      // of the true peak of ~0.180 g/L (the first drink alone, fully
      // eliminated ~1h12m before the second is even drunk at +3h). Fixed
      // by filtering each sample to `consumedAt <= t` (`_sampleAt`).
      final rangeStart = DateTime.utc(2026, 7, 1, 5, 0);
      final rangeEnd = DateTime.utc(2026, 7, 2, 5, 0);
      final sessionStart = DateTime.utc(2026, 7, 1, 20, 0);
      final drink1At = DateTime.utc(2026, 7, 1, 20, 5);
      final drink2At = DateTime.utc(2026, 7, 1, 23, 0); // +3h
      final session = _session(
        id: 's1',
        startedAt: sessionStart,
        endedAt: DateTime.utc(2026, 7, 2, 1, 0),
      );
      final entries = [
        _entry(id: 'e1', consumedAt: drink1At, partySessionId: 's1'),
        _entry(id: 'e2', consumedAt: drink2At, partySessionId: 's1'),
      ];

      final buckets = computeMaxBacPerDay(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        boundaryHour: 5,
        sessions: [session],
        alcoholicEntries: entries,
        meals: const [],
        profile: _profile(),
        now: rangeEnd,
      );

      expect(buckets, hasLength(1));
      expect(buckets[0].maxGPerL, closeTo(oneBeerInitial, 0.01));
    });
  });
}
