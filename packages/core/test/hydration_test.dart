import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('dailyGoalMl (Parity Rulebook — Hydration goal)', () {
    test('70 kg → 2100 ml', () {
      expect(dailyGoalMl(70), 2100);
    });

    test('.50 boundary: 65 kg → 1950 → 2000 (round-half-up)', () {
      expect(dailyGoalMl(65), 2000);
    });

    test('rounds to nearest 100', () {
      expect(dailyGoalMl(62), 1900); // 1860 → 1900
      expect(dailyGoalMl(61), 1800); // 1830 → 1800
    });
  });
}
