// Unit tests for units.dart — display-boundary imperial conversions.
//
// All expected values are derived from the conversion constants and rounding
// rules pinned in the Parity Rulebook ("Volume conversion", "Mass conversion",
// "Height conversion", "Imperial display", "Storage unit" rows):
//   - 1 US fl oz  = 29.5735295625 ml   (NIST)
//   - 1 kg        = 2.20462262185 lb   (international avoirdupois pound)
//   - 1 inch      = 2.54 cm exactly    (international definition)
//
// Rounding rules (Parity Rulebook):
//   - Volume  : fl oz rounded to 1 decimal place (round half away from zero);
//               ml rounded to the nearest integer.
//   - Mass    : lb rounded to 1 decimal place; kg rounded to 3 decimal places.
//   - Height  : total inches rounded to nearest int, then split into ft+in;
//               cm (from ft+in) rounded to 1 decimal place.
//
// Source: engineering/decisions/design-system.md → Appendix: Parity Rulebook.

import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  // -------------------------------------------------------------------------
  // mlToFlOz
  // -------------------------------------------------------------------------

  group('mlToFlOz', () {
    // Derived: ml / 29.5735295625, rounded to 1 dp.

    test('0 ml → 0.0 fl oz', () {
      // 0 / 29.5735295625 = 0.0
      expect(mlToFlOz(0), equals(0.0));
    });

    test('100 ml → 3.4 fl oz', () {
      // 100 / 29.5735295625 = 3.3814022..., rounds to 3.4
      expect(mlToFlOz(100), closeTo(3.4, 0.001));
    });

    test('240 ml → 8.1 fl oz', () {
      // 240 / 29.5735295625 = 8.1153654..., rounds to 8.1
      expect(mlToFlOz(240), closeTo(8.1, 0.001));
    });

    test('355 ml → 12.0 fl oz', () {
      // 355 / 29.5735295625 = 12.0039780..., rounds to 12.0
      // Covers just-above-half case where result rounds down to .0
      expect(mlToFlOz(355), closeTo(12.0, 0.001));
    });

    test('500 ml → 16.9 fl oz', () {
      // 500 / 29.5735295625 = 16.9070113..., rounds to 16.9
      expect(mlToFlOz(500), closeTo(16.9, 0.001));
    });

    test('750 ml → 25.4 fl oz', () {
      // 750 / 29.5735295625 = 25.3605170..., rounds to 25.4
      expect(mlToFlOz(750), closeTo(25.4, 0.001));
    });

    test('return type is double', () {
      expect(mlToFlOz(250), isA<double>());
    });
  });

  // -------------------------------------------------------------------------
  // flOzToMl
  // -------------------------------------------------------------------------

  group('flOzToMl', () {
    // Derived: flOz * 29.5735295625, rounded to nearest ml.

    test('0 fl oz → 0.0 ml', () {
      // 0 * 29.5735295625 = 0.0
      expect(flOzToMl(0), equals(0.0));
    });

    test('12.0 fl oz → 355.0 ml', () {
      // 12 * 29.5735295625 = 354.8823547..., rounds to 355
      expect(flOzToMl(12.0), equals(355.0));
    });

    test('16.9 fl oz → 500.0 ml', () {
      // 16.9 * 29.5735295625 = 499.7926496..., rounds to 500
      expect(flOzToMl(16.9), equals(500.0));
    });

    test('8.1 fl oz → 240.0 ml', () {
      // 8.1 * 29.5735295625 = 239.5455894..., rounds to 240
      expect(flOzToMl(8.1), equals(240.0));
    });

    test('return type is double (integer result)', () {
      // roundToDouble() always returns a double
      expect(flOzToMl(12.0), isA<double>());
    });

    // Note: the Parity Rulebook explicitly accepts that the imperial↔metric
    // round-trip may lose minor precision ("Imperial→metric→imperial round-trip
    // may lose minor precision (accepted)").  For example:
    //   mlToFlOz(100) = 3.4 fl oz, but flOzToMl(3.4) = 101 ml (not 100 ml).
    // No lossless round-trip test is written; that would encode a false expectation.
  });

  // -------------------------------------------------------------------------
  // kgToLb
  // -------------------------------------------------------------------------

  group('kgToLb', () {
    // Derived: kg * 2.20462262185, rounded to 1 dp.

    test('0 kg → 0.0 lb', () {
      // 0 * 2.20462262185 = 0.0
      expect(kgToLb(0), equals(0.0));
    });

    test('70 kg → 154.3 lb', () {
      // 70 * 2.20462262185 = 154.3235835..., rounds to 154.3
      expect(kgToLb(70), closeTo(154.3, 0.001));
    });

    test('50 kg → 110.2 lb', () {
      // 50 * 2.20462262185 = 110.2311310..., rounds to 110.2
      expect(kgToLb(50), closeTo(110.2, 0.001));
    });

    test('100 kg → 220.5 lb', () {
      // 100 * 2.20462262185 = 220.4622621..., rounds to 220.5
      // Covers rounding up the .4 fractional part at the .5 boundary
      expect(kgToLb(100), closeTo(220.5, 0.001));
    });

    test('75 kg → 165.3 lb', () {
      // 75 * 2.20462262185 = 165.3466996..., rounds to 165.3
      expect(kgToLb(75), closeTo(165.3, 0.001));
    });

    test('return type is double', () {
      expect(kgToLb(80), isA<double>());
    });
  });

  // -------------------------------------------------------------------------
  // lbToKg
  // -------------------------------------------------------------------------

  group('lbToKg', () {
    // Derived: lb / 2.20462262185, rounded to 3 decimal places.
    //
    // Tolerance for closeTo is 0.0005 (half a quantum at 3 dp) so that any
    // last-digit regression (±0.001) is caught — using 0.001 would pass a
    // one-digit drift at the boundary.

    test('0 lb → 0.0 kg', () {
      // 0 / 2.20462262185 = 0.0
      expect(lbToKg(0), equals(0.0));
    });

    test('154.3 lb → 69.989 kg', () {
      // 154.3 / 2.20462262185 = 69.9893026..., rounds to 69.989
      expect(lbToKg(154.3), closeTo(69.989, 0.0005));
    });

    test('220.5 lb → 100.017 kg', () {
      // 220.5 / 2.20462262185 = 100.0171175..., rounds to 100.017
      expect(lbToKg(220.5), closeTo(100.017, 0.0005));
    });

    test('110.2 lb → 49.986 kg', () {
      // 110.2 / 2.20462262185 = 49.9858791..., rounds to 49.986
      expect(lbToKg(110.2), closeTo(49.986, 0.0005));
    });

    test('return type is double', () {
      expect(lbToKg(150), isA<double>());
    });
  });

  // -------------------------------------------------------------------------
  // cmToFtIn
  // -------------------------------------------------------------------------

  group('cmToFtIn', () {
    // Derived: cm / 2.54 → round to nearest int → split into (ft = total ~/ 12,
    // in = total % 12).  Result fields are int — use equals on the record.

    test('180 cm → (feet: 5, inches: 11)', () {
      // 180 / 2.54 = 70.8661417..., rounds to 71 in → 5*12 + 11
      expect(cmToFtIn(180), equals((feet: 5, inches: 11)));
    });

    test('170 cm → (feet: 5, inches: 7)', () {
      // 170 / 2.54 = 66.9291338..., rounds to 67 in → 5*12 + 7
      expect(cmToFtIn(170), equals((feet: 5, inches: 7)));
    });

    test('152.4 cm → (feet: 5, inches: 0)', () {
      // 152.4 / 2.54 = 60.0 exactly → 60 in → 5*12 + 0
      expect(cmToFtIn(152.4), equals((feet: 5, inches: 0)));
    });

    test('30.48 cm → (feet: 1, inches: 0)', () {
      // 30.48 / 2.54 = 12.0 exactly → 12 in → 1*12 + 0
      expect(cmToFtIn(30.48), equals((feet: 1, inches: 0)));
    });

    test('0 cm → (feet: 0, inches: 0)', () {
      // 0 / 2.54 = 0 → 0 in → 0*12 + 0
      expect(cmToFtIn(0), equals((feet: 0, inches: 0)));
    });

    test('162.56 cm → (feet: 5, inches: 4)', () {
      // 162.56 / 2.54 = 64.0 exactly → 64 in → 5*12 + 4
      expect(cmToFtIn(162.56), equals((feet: 5, inches: 4)));
    });

    test('182.88 cm → (feet: 6, inches: 0)', () {
      // 182.88 / 2.54 = 72.0 exactly → 72 in → 6*12 + 0
      expect(cmToFtIn(182.88), equals((feet: 6, inches: 0)));
    });

    test('returns named record with int feet and int inches', () {
      final result = cmToFtIn(175);
      expect(result.feet, isA<int>());
      expect(result.inches, isA<int>());
    });
  });

  // -------------------------------------------------------------------------
  // ftInToCm
  // -------------------------------------------------------------------------

  group('ftInToCm', () {
    // Derived: (feet*12 + inches) * 2.54, rounded to 1 dp.

    test('(0, 0) → 0.0 cm', () {
      // 0 * 2.54 = 0.0
      expect(ftInToCm(0, 0), equals(0.0));
    });

    test('(5, 11) → 180.3 cm', () {
      // (5*12+11) * 2.54 = 71 * 2.54 = 180.34, rounds to 180.3
      expect(ftInToCm(5, 11), closeTo(180.3, 0.001));
    });

    test('(5, 0) → 152.4 cm', () {
      // (5*12+0) * 2.54 = 60 * 2.54 = 152.4, rounds to 152.4
      expect(ftInToCm(5, 0), closeTo(152.4, 0.001));
    });

    test('(6, 0) → 182.9 cm', () {
      // (6*12+0) * 2.54 = 72 * 2.54 = 182.88, rounds to 182.9
      expect(ftInToCm(6, 0), closeTo(182.9, 0.001));
    });

    test('(5, 7) → 170.2 cm', () {
      // (5*12+7) * 2.54 = 67 * 2.54 = 170.18, rounds to 170.2
      expect(ftInToCm(5, 7), closeTo(170.2, 0.001));
    });

    test('(1, 0) → 30.5 cm', () {
      // (1*12+0) * 2.54 = 12 * 2.54 = 30.48, rounds to 30.5
      expect(ftInToCm(1, 0), closeTo(30.5, 0.001));
    });

    test('return type is double', () {
      expect(ftInToCm(5, 10), isA<double>());
    });

    // Round-trip consistency note: cmToFtIn(180) → (5, 11) → ftInToCm(5,11)
    // = 180.3, not 180.0. The Parity Rulebook accepts this precision loss for
    // imperial display round-trips; no lossless round-trip test is written.
  });
}
