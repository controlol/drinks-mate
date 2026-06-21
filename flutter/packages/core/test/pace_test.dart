import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('expectedIntakeMl (Parity Rulebook — Expected intake / pace)', () {
    // Default active window 08:00–22:00 = 14h = 840 min, goal 2100 ml.
    test('start of window → 0', () {
      expect(
        expectedIntakeMl(goalMl: 2100, elapsedActiveMin: 0, activeWindowMin: 840),
        0,
      );
    });

    test('halfway through the active window → half the goal', () {
      expect(
        expectedIntakeMl(goalMl: 2100, elapsedActiveMin: 420, activeWindowMin: 840),
        closeTo(1050, 0.0001),
      );
    });

    test('clamps elapsed below 0 (before active start)', () {
      expect(
        expectedIntakeMl(goalMl: 2100, elapsedActiveMin: -60, activeWindowMin: 840),
        0,
      );
    });

    test('clamps elapsed above the window (after active end)', () {
      expect(
        expectedIntakeMl(goalMl: 2100, elapsedActiveMin: 9999, activeWindowMin: 840),
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
}
