import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('expectedIntakeMl (Parity Rulebook — Expected intake / pace)', () {
    // Default active window 08:00–22:00 = 14h = 840 min, goal 2100 ml.
    test('start of window → 0', () {
      expect(
        expectedIntakeMl(
          goalMl: 2100,
          elapsedActiveMin: 0,
          activeWindowMin: 840,
        ),
        0,
      );
    });

    test('halfway through the active window → half the goal', () {
      expect(
        expectedIntakeMl(
          goalMl: 2100,
          elapsedActiveMin: 420,
          activeWindowMin: 840,
        ),
        closeTo(1050, 0.0001),
      );
    });

    test('clamps elapsed below 0 (before active start)', () {
      expect(
        expectedIntakeMl(
          goalMl: 2100,
          elapsedActiveMin: -60,
          activeWindowMin: 840,
        ),
        0,
      );
    });

    test('clamps elapsed above the window (after active end)', () {
      expect(
        expectedIntakeMl(
          goalMl: 2100,
          elapsedActiveMin: 9999,
          activeWindowMin: 840,
        ),
        2100,
      );
    });
  });

  group('recommendedVolumeGlasses (Parity Rulebook — Recommended volume)', () {
    test('rounds to nearest 0.5', () {
      expect(recommendedVolumeGlasses(0.74), 0.5);
      expect(recommendedVolumeGlasses(0.76), 1.0);
      expect(recommendedVolumeGlasses(1.24), 1.0);
      expect(recommendedVolumeGlasses(1.26), 1.5);
    });

    test('minimum 0.5 even when on/ahead of pace', () {
      expect(recommendedVolumeGlasses(0.0), 0.5);
      expect(recommendedVolumeGlasses(-3.0), 0.5);
    });

    test('maximum 2.0', () {
      expect(recommendedVolumeGlasses(5.0), 2.0);
    });
  });

  // Source: threshold rules stated in the paceStatus() doc comment in
  // pace.dart (flagged as a maintainer-confirmed assumption, not yet in the
  // Parity Rulebook).  Thresholds:
  //   ahead   = intake >= goalMl      (goal already reached)
  //   behind  = intake < expectedMl   (below linear-pace marker)
  //   onPace  = intake >= expectedMl  AND  intake < goalMl
  //
  // Concrete fixture: goalMl=2000, expectedMl=1000 unless noted.
  group(
      'paceStatus (status-pill thresholds — pace.dart doc; not yet in Rulebook)',
      () {
    // Case 1: intake < expectedMl → behind
    // 500 < 1000 → intake is below the linear-pace marker.
    test('intake below expected → behind', () {
      expect(
        paceStatus(intakeMl: 500, expectedMl: 1000, goalMl: 2000),
        PaceStatus.behind,
      );
    });

    // Case 2: intake == expectedMl AND intake < goalMl → onPace
    // 1000 == 1000 and 1000 < 2000 → exactly on the pace marker, goal not yet reached.
    // Uses integer-valued doubles so '==' is exact (no floating-point hazard).
    test('intake exactly equal to expected (and below goal) → onPace', () {
      expect(
        paceStatus(intakeMl: 1000, expectedMl: 1000, goalMl: 2000),
        PaceStatus.onPace,
      );
    });

    // Case 3: intake > expectedMl AND intake < goalMl → onPace
    // 1500 > 1000 and 1500 < 2000 → ahead of linear pace but goal not yet reached.
    test('intake above expected but below goal → onPace', () {
      expect(
        paceStatus(intakeMl: 1500, expectedMl: 1000, goalMl: 2000),
        PaceStatus.onPace,
      );
    });

    // Case 4: intake == goalMl → ahead
    // 2000 == 2000 → daily goal exactly reached; goal check (>= goalMl) fires first.
    // Uses integer-valued doubles so '==' is exact.
    test('intake exactly equal to goal → ahead', () {
      expect(
        paceStatus(intakeMl: 2000, expectedMl: 1000, goalMl: 2000),
        PaceStatus.ahead,
      );
    });

    // Case 5: intake > goalMl → ahead (over-achieved)
    // 2500 > 2000 → intake exceeds the daily goal.
    test('intake exceeds goal (over-achieved) → ahead', () {
      expect(
        paceStatus(intakeMl: 2500, expectedMl: 1000, goalMl: 2000),
        PaceStatus.ahead,
      );
    });

    // Case 6: expectedMl == 0 AND intake == 0 → onPace
    // Before the active window starts, expected=0 and intake=0.
    // 0 < 0 is false → not behind; 0 < 2000 → onPace (not ahead).
    test('before active window (expected=0, intake=0) → onPace', () {
      expect(
        paceStatus(intakeMl: 0, expectedMl: 0, goalMl: 2000),
        PaceStatus.onPace,
      );
    });

    // Case 7a: expectedMl == 0 AND intake >= goalMl → ahead
    // Goal check fires before the expected check; goal already reached.
    test('expected=0, intake at goal → ahead', () {
      expect(
        paceStatus(intakeMl: 2000, expectedMl: 0, goalMl: 2000),
        PaceStatus.ahead,
      );
    });

    // Case 7b: expectedMl == 0 AND 0 < intake < goalMl → onPace
    // intake=500 is NOT below expected (0), so the behind branch is skipped.
    // 500 < 2000 → onPace (this is the meaningful edge for the expected=0 path).
    test('expected=0, intake positive but below goal → onPace', () {
      expect(
        paceStatus(intakeMl: 500, expectedMl: 0, goalMl: 2000),
        PaceStatus.onPace,
      );
    });
  });

  // Source: notifications.md §Recommended volume per reminder — the full
  // formula chaining expectedIntakeMl → deficit → glasses_raw →
  // recommendedVolumeGlasses. Fixture: goal=2100 ml, active hours 08:00–22:00
  // (840 min window) — the design doc's own worked example values.
  group(
      'recommendedReminderVolumeGlasses (notifications.md §Recommended '
      'volume per reminder)', () {
    final activeStart = DateTime(2026, 1, 1, 8, 0);
    final activeEnd = DateTime(2026, 1, 1, 22, 0);

    // (a) Worked-example-style case: 360 min elapsed of the 840 min window →
    // expected = 2100 * 360/840 = 900 ml. actual=300 ml → deficit=600 ml.
    // 200 ml default drink → glasses_raw = 3.0 → clamped to the 2.0 maximum.
    test('deficit far behind pace clamps to the 2.0 maximum', () {
      final glasses = recommendedReminderVolumeGlasses(
        goalMl: 2100,
        activeStart: activeStart,
        activeEnd: activeEnd,
        now: DateTime(2026, 1, 1, 14, 0),
        actualIntakeMl: 300,
        defaultDrinkVolumeMl: 200,
      );
      expect(glasses, closeTo(2.0, 0.001));
    });

    // (b) Same elapsed point (expected=900 ml), actual=600 ml → deficit=300 ml
    // → glasses_raw = 300/200 = 1.5 exactly. No clamping needed.
    test('mid-range deficit lands on 1.5 glasses without clamping', () {
      final glasses = recommendedReminderVolumeGlasses(
        goalMl: 2100,
        activeStart: activeStart,
        activeEnd: activeEnd,
        now: DateTime(2026, 1, 1, 14, 0),
        actualIntakeMl: 600,
        defaultDrinkVolumeMl: 200,
      );
      expect(glasses, closeTo(1.5, 0.001));
    });

    // (c) Ahead of pace: expected=900 ml, actual=1500 ml → deficit=-600 ml →
    // glasses_raw = -3.0 → clamps to the 0.5 minimum (never below, even far
    // ahead of pace — "the reminder still recommends half a glass").
    test('ahead of pace (negative deficit) clamps to the 0.5 minimum', () {
      final glasses = recommendedReminderVolumeGlasses(
        goalMl: 2100,
        activeStart: activeStart,
        activeEnd: activeEnd,
        now: DateTime(2026, 1, 1, 14, 0),
        actualIntakeMl: 1500,
        defaultDrinkVolumeMl: 200,
      );
      expect(glasses, closeTo(0.5, 0.001));
    });

    // (d) now == activeStart → elapsed=0 → expected=0 ml. actual=0 →
    // deficit=0 → glasses_raw=0 → rounds to 0, clamps up to the 0.5 minimum.
    test('now at active-window start (elapsed=0) clamps to 0.5', () {
      final glasses = recommendedReminderVolumeGlasses(
        goalMl: 2100,
        activeStart: activeStart,
        activeEnd: activeEnd,
        now: activeStart,
        actualIntakeMl: 0,
        defaultDrinkVolumeMl: 200,
      );
      expect(glasses, closeTo(0.5, 0.001));
    });

    // (e) now == activeEnd → elapsed = full 840 min window → expected = goal
    // = 2100 ml exactly (elapsed/window ratio is exactly 1.0, no clamp
    // needed to reach it). actual=2000 → deficit=100 → glasses_raw=0.5.
    test(
        'now at active-window end (elapsed=full window) reaches the goal '
        'exactly, no elapsed-clamp needed', () {
      final glasses = recommendedReminderVolumeGlasses(
        goalMl: 2100,
        activeStart: activeStart,
        activeEnd: activeEnd,
        now: activeEnd,
        actualIntakeMl: 2000,
        defaultDrinkVolumeMl: 200,
      );
      expect(glasses, closeTo(0.5, 0.001));
    });

    // (f) now after activeEnd → elapsed_active_min clamps to the window
    // (max 840 min per the formula's min(active_window_min, …)), so the
    // expected fraction never exceeds 1.0 — identical result to (e) despite
    // "now" being an hour later.
    test(
        'now after active-window end clamps elapsed to the window (same '
        'result as at activeEnd)', () {
      final glasses = recommendedReminderVolumeGlasses(
        goalMl: 2100,
        activeStart: activeStart,
        activeEnd: activeEnd,
        now: DateTime(2026, 1, 1, 23, 0),
        actualIntakeMl: 2000,
        defaultDrinkVolumeMl: 200,
      );
      expect(glasses, closeTo(0.5, 0.001));
    });
  });

  // Source: Parity Rulebook → "Glass-count copy formatting"; notifications.md
  // §Glass formatting table.
  group('formatGlassCount (Parity Rulebook — Glass-count copy formatting)', () {
    test('0.5 → "half a glass"', () {
      expect(formatGlassCount(0.5), 'half a glass');
    });

    test('1.0 → "a glass"', () {
      expect(formatGlassCount(1.0), 'a glass');
    });

    test('1.5 → "1.5 glasses"', () {
      expect(formatGlassCount(1.5), '1.5 glasses');
    });

    test('2.0 → "2 glasses"', () {
      expect(formatGlassCount(2.0), '2 glasses');
    });
  });
}
