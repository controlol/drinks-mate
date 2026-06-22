import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('BAC — worked example (party-session.md §Worked example)', () {
    // A 75 kg, 180 cm, 30-year-old male drinks two 250 ml beers at 5% ABV
    // at the same time.
    //
    // NOTE (spec discrepancy — flagged 2026-06-21): party-session.md's
    // sanity-check states TBW = 43.93 L → BAC 0.362 g/L (≈7.85 mmol/L). But the
    // Watson coefficients it (and the Parity Rulebook) define actually evaluate
    // to TBW = 44.14 L → BAC 0.360 g/L (≈7.82 mmol/L). The coefficients are the
    // authoritative Watson values (44.1 L is the correct reference for this
    // body), so these tests assert the *formula-correct* outputs. The doc's
    // worked-example numbers should be corrected; see the summary / tracking issue.
    final perBeer = alcoholGrams(volumeMl: 250, abvPercent: 5);
    final totalAlcohol = 2 * perBeer;
    final tbw = watsonTbwLitres(
      gender: Gender.male,
      ageYears: 30,
      heightCm: 180,
      weightKg: 75,
    );
    final initial =
        bacInitialWatson(alcoholGrams: totalAlcohol, tbwLitres: tbw);

    test('alcohol per beer ≈ 9.86 g', () {
      expect(perBeer, closeTo(9.8625, 0.0001));
    });

    test('Watson TBW ≈ 44.14 L (per the formula)', () {
      expect(tbw, closeTo(44.14, 0.01));
    });

    test('initial BAC ≈ 0.360 g/L (per the formula)', () {
      expect(initial, closeTo(0.360, 0.001));
    });

    test('initial BAC ≈ 7.82 mmol/L', () {
      expect(gPerLToMmol(initial), closeTo(7.82, 0.02));
    });

    test('after 2 hours ≈ 0.060 g/L', () {
      expect(
          bacAtTime(bacInitial: initial, hoursSince: 2), closeTo(0.060, 0.001));
    });

    test('clamps to 0 once eliminated (~2.4h+)', () {
      expect(bacAtTime(bacInitial: initial, hoursSince: 3), 0.0);
    });
  });

  group('BAC — building blocks', () {
    test('alcoholGrams uses ethanol density 0.789', () {
      // 500 ml @ 40% → 500 × 0.40 × 0.789 = 157.8 g
      expect(
          alcoholGrams(volumeMl: 500, abvPercent: 40), closeTo(157.8, 0.001));
    });

    test('unspecified gender uses female (conservative) TBW coefficients', () {
      final female = watsonTbwLitres(
          gender: Gender.female, ageYears: 30, heightCm: 170, weightKg: 70);
      final unspecified = watsonTbwLitres(
          gender: Gender.unspecified,
          ageYears: 30,
          heightCm: 170,
          weightKg: 70);
      expect(unspecified, female);
    });

    test('widmark r: 0.68 male, 0.55 female/unspecified', () {
      expect(widmarkR(Gender.male), 0.68);
      expect(widmarkR(Gender.female), 0.55);
      expect(widmarkR(Gender.unspecified), 0.55);
    });

    test('meal modifier: no meals → 1.0', () {
      expect(mealModifier(const []), 1.0);
    });

    test('meal modifier: meal after the drink (Δt<0) → 1.0', () {
      expect(
        mealModifierSingle(size: MealSize.large, deltaHours: -1),
        1.0,
      );
    });

    test('meal modifier: across meals takes the min', () {
      final m = mealModifier(const [
        (size: MealSize.small, deltaHours: 1.0),
        (size: MealSize.large, deltaHours: 0.5),
      ]);
      final large = mealModifierSingle(size: MealSize.large, deltaHours: 0.5);
      expect(m, large);
      expect(m, lessThan(1.0));
    });
  });
}
