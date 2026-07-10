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
    final initial = bacInitialWatson(
      alcoholGrams: totalAlcohol,
      tbwLitres: tbw,
    );

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
        bacAtTime(bacInitial: initial, hoursSince: 2),
        closeTo(0.060, 0.001),
      );
    });

    test('clamps to 0 once eliminated (~2.4h+)', () {
      expect(bacAtTime(bacInitial: initial, hoursSince: 3), 0.0);
    });
  });

  group('BAC — building blocks', () {
    test('alcoholGrams uses ethanol density 0.789', () {
      // 500 ml @ 40% → 500 × 0.40 × 0.789 = 157.8 g
      expect(
        alcoholGrams(volumeMl: 500, abvPercent: 40),
        closeTo(157.8, 0.001),
      );
    });

    test('unspecified gender uses female (conservative) TBW coefficients', () {
      final female = watsonTbwLitres(
        gender: Gender.female,
        ageYears: 30,
        heightCm: 170,
        weightKg: 70,
      );
      final unspecified = watsonTbwLitres(
        gender: Gender.unspecified,
        ageYears: 30,
        heightCm: 170,
        weightKg: 70,
      );
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
      expect(mealModifierSingle(size: MealSize.large, deltaHours: -1), 1.0);
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

  group(
      'bacInitialForDrink — model selection (party-session.md §BAC '
      'estimation algorithm Step 2: "the app picks the most accurate option '
      'the available data supports")', () {
    // Fixture reuses the worked-example inputs (party-session.md §Worked
    // example): 75 kg / 180 cm / 30 y male, 2 × 250 ml 5% beers.
    final totalAlcohol = 2 * alcoholGrams(volumeMl: 250, abvPercent: 5);

    test('heightCm non-null → Watson path matches bacInitialWatson', () {
      final expectedTbw = watsonTbwLitres(
        gender: Gender.male,
        ageYears: 30,
        heightCm: 180,
        weightKg: 75,
      );
      final expected = bacInitialWatson(
        alcoholGrams: totalAlcohol,
        tbwLitres: expectedTbw,
      );
      final actual = bacInitialForDrink(
        alcoholGrams: totalAlcohol,
        gender: Gender.male,
        ageYears: 30,
        heightCm: 180,
        weightKg: 75,
      );
      expect(actual, closeTo(expected, 0.0001));
      // Cross-check against the worked-example formula-correct value.
      expect(actual, closeTo(0.360, 0.001));
    });

    test('heightCm null → Widmark path matches bacInitialWidmark(widmarkR)',
        () {
      final expected = bacInitialWidmark(
        alcoholGrams: totalAlcohol,
        weightKg: 75,
        r: widmarkR(Gender.male),
      );
      final actual = bacInitialForDrink(
        alcoholGrams: totalAlcohol,
        gender: Gender.male,
        ageYears: 30,
        weightKg: 75,
      );
      expect(actual, closeTo(expected, 0.0001));
    });

    test('mealModifier is applied linearly to whichever path is selected', () {
      final withoutMeal = bacInitialForDrink(
        alcoholGrams: totalAlcohol,
        gender: Gender.male,
        ageYears: 30,
        heightCm: 180,
        weightKg: 75,
      );
      final withMeal = bacInitialForDrink(
        alcoholGrams: totalAlcohol,
        gender: Gender.male,
        ageYears: 30,
        heightCm: 180,
        weightKg: 75,
        mealModifier: 0.85,
      );
      expect(withMeal, closeTo(withoutMeal * 0.85, 0.0001));

      final widmarkWithoutMeal = bacInitialForDrink(
        alcoholGrams: totalAlcohol,
        gender: Gender.male,
        ageYears: 30,
        weightKg: 75,
      );
      final widmarkWithMeal = bacInitialForDrink(
        alcoholGrams: totalAlcohol,
        gender: Gender.male,
        ageYears: 30,
        weightKg: 75,
        mealModifier: 0.85,
      );
      expect(widmarkWithMeal, closeTo(widmarkWithoutMeal * 0.85, 0.0001));
    });
  });

  group('bmi — kg/m² (design-system.md Parity Rulebook, "BMI warning" note)',
      () {
    test('70 kg / 175 cm ≈ 22.86', () {
      // 70 / (1.75^2) = 70 / 3.0625 = 22.857...
      expect(
        bmi(weightKg: 70, heightCm: 175),
        closeTo(22.86, 0.01),
      );
    });

    test('75 kg / 180 cm ≈ 23.15 (worked-example body)', () {
      // 75 / (1.80^2) = 75 / 3.24 = 23.148...
      expect(
        bmi(weightKg: 75, heightCm: 180),
        closeTo(23.15, 0.01),
      );
    });

    test('45 kg / 180 cm ≈ 13.89 (low-BMI fixture used below)', () {
      expect(
        bmi(weightKg: 45, heightCm: 180),
        closeTo(13.89, 0.01),
      );
    });
  });

  group(
    'bmiWarningApplies (design-system.md Parity Rulebook line ~204: '
    '"warn if BMI<17 (any), BMI>67 male, BMI>80 female/unspecified")',
    () {
      test('just below 17 warns for every gender', () {
        expect(
          bmiWarningApplies(bmi: 16.99, gender: Gender.male),
          isTrue,
        );
        expect(
          bmiWarningApplies(bmi: 16.99, gender: Gender.female),
          isTrue,
        );
        expect(
          bmiWarningApplies(bmi: 16.99, gender: Gender.unspecified),
          isTrue,
        );
      });

      test('exactly 17.0 does not warn (rule is strict <)', () {
        expect(bmiWarningApplies(bmi: 17.0, gender: Gender.male), isFalse);
        expect(bmiWarningApplies(bmi: 17.0, gender: Gender.female), isFalse);
        expect(
          bmiWarningApplies(bmi: 17.0, gender: Gender.unspecified),
          isFalse,
        );
      });

      test('exactly 67.0 does not warn for male (rule is strict >)', () {
        expect(bmiWarningApplies(bmi: 67.0, gender: Gender.male), isFalse);
      });

      test('just above 67 warns for male', () {
        expect(bmiWarningApplies(bmi: 67.01, gender: Gender.male), isTrue);
      });

      test('just above 67 does NOT warn for female/unspecified (needs >80)',
          () {
        expect(bmiWarningApplies(bmi: 67.01, gender: Gender.female), isFalse);
        expect(
          bmiWarningApplies(bmi: 67.01, gender: Gender.unspecified),
          isFalse,
        );
      });

      test('exactly 80.0 does not warn for female/unspecified (strict >)', () {
        expect(bmiWarningApplies(bmi: 80.0, gender: Gender.female), isFalse);
        expect(
          bmiWarningApplies(bmi: 80.0, gender: Gender.unspecified),
          isFalse,
        );
      });

      test('just above 80 warns for female/unspecified', () {
        expect(bmiWarningApplies(bmi: 80.01, gender: Gender.female), isTrue);
        expect(
          bmiWarningApplies(bmi: 80.01, gender: Gender.unspecified),
          isTrue,
        );
      });

      test(
          'just above 80 also still warns for male (already past its own '
          'threshold at 67)', () {
        expect(bmiWarningApplies(bmi: 80.01, gender: Gender.male), isTrue);
      });

      test('mid-range BMI (e.g. 23) does not warn for any gender', () {
        expect(bmiWarningApplies(bmi: 23, gender: Gender.male), isFalse);
        expect(bmiWarningApplies(bmi: 23, gender: Gender.female), isFalse);
        expect(
          bmiWarningApplies(bmi: 23, gender: Gender.unspecified),
          isFalse,
        );
      });
    },
  );

  group(
    'hoursToZero (bac.dart doc comment: t_zero = consumedAt + BAC_initial / '
    'β; party-session.md §Absorbing orphan drinks / notifications.md §Party '
    'Mode notifications sober-estimate trigger)',
    () {
      test('known-value vector: 0.3 g/L at β=0.15 → 2.0 hours', () {
        // 0.3 / 0.15 = 2.0 exactly on paper, but 0.15 has no exact binary
        // representation, so use closeTo rather than exact equality.
        expect(hoursToZero(0.3), closeTo(2.0, 1e-9));
      });

      test(
          'inverse of bacAtTime: decaying for hoursToZero(x) hours from x '
          'lands back at 0', () {
        const bacInitial = 0.360; // worked-example initial BAC.
        final hours = hoursToZero(bacInitial);
        expect(
          bacAtTime(bacInitial: bacInitial, hoursSince: hours),
          closeTo(0.0, 1e-9),
        );
      });

      test('BAC 0 → 0 hours to zero', () {
        expect(hoursToZero(0.0), 0.0);
      });
    },
  );

  group(
    'isApproachingCap (party-session.md §BAC goal (cap): '
    '"...pushes the estimated BAC past 80% of the cap")',
    () {
      const cap = 0.5;

      test('just below 80% of cap → false', () {
        expect(
          isApproachingCap(bacGPerL: 0.8 * cap - 0.001, capGPerL: cap),
          isFalse,
        );
      });

      test('exactly 80% of cap → true (boundary is inclusive)', () {
        expect(
          isApproachingCap(bacGPerL: 0.8 * cap, capGPerL: cap),
          isTrue,
        );
      });

      test('just above 80% of cap → true', () {
        expect(
          isApproachingCap(bacGPerL: 0.8 * cap + 0.001, capGPerL: cap),
          isTrue,
        );
      });

      test(
          'worked-example BAC (0.360 g/L) against a 0.4 g/L cap is '
          'approaching (0.360 ≥ 0.32)', () {
        expect(isApproachingCap(bacGPerL: 0.360, capGPerL: 0.4), isTrue);
      });

      test('at BAC 0 with any positive cap → false', () {
        expect(isApproachingCap(bacGPerL: 0.0, capGPerL: 0.5), isFalse);
      });
    },
  );
}
