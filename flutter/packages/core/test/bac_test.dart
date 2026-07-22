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
    'sessionBacAtTime / sessionSoberTime (party-session.md §BAC estimation '
    'algorithm Step 5: pooled elimination, not independent per-drink sum)',
    () {
      // Two drinks, each bacInitial 0.30 g/L, 1 hour apart. Drink 1 alone
      // would decay to 0 after 2h (hoursToZero(0.30) = 2.0), so at drink 2's
      // consumedAt (t=1h) drink 1 still has 0.15 g/L left — the drinks
      // overlap for the hour between t=1h and t=2h.
      final t0 = DateTime.utc(2026, 1, 1, 0);
      final t1 = t0.add(const Duration(hours: 1));
      final drinks = [
        (consumedAt: t0, bacInitial: 0.30),
        (consumedAt: t1, bacInitial: 0.30),
      ];

      test(
          'at the second drink\'s own consumedAt, pooled == independent sum '
          '(only one decay-then-add step has happened)', () {
        // Pool: 0.30 decayed 1h to 0.15, then + 0.30 = 0.45.
        expect(sessionBacAtTime(drinks: drinks, at: t1), closeTo(0.45, 1e-9));
      });

      test(
          'during the overlap, pooled elimination beats independent-sum '
          'elimination by β per extra concurrently-active drink', () {
        final at = t0.add(const Duration(minutes: 90)); // t=1.5h
        // Pooled: 0.45 (at t1) decayed 0.5h → 0.45 − 0.15×0.5 = 0.375.
        expect(sessionBacAtTime(drinks: drinks, at: at), closeTo(0.375, 1e-9));
        // Independent-sum (the old, over-eliminating model, for contrast):
        // drink 1 alone at 1.5h: 0.30 − 0.15×1.5 = 0.075.
        // drink 2 alone at 0.5h since consumed: 0.30 − 0.15×0.5 = 0.225.
        // Sum = 0.30 — 0.075 g/L lower than the pooled 0.375, i.e. β×0.5h
        // of extra elimination for the hour the two drinks were both active.
        final independentSum = bacAtTime(bacInitial: 0.30, hoursSince: 1.5) +
            bacAtTime(bacInitial: 0.30, hoursSince: 0.5);
        expect(independentSum, closeTo(0.30, 1e-9));
      });

      test('drinks consumed after `at` are ignored', () {
        expect(sessionBacAtTime(drinks: drinks, at: t0), closeTo(0.30, 1e-9));
      });

      test('unsorted input is handled the same as sorted input', () {
        final reversed = drinks.reversed.toList();
        expect(
          sessionBacAtTime(drinks: reversed, at: t1),
          sessionBacAtTime(drinks: drinks, at: t1),
        );
      });

      test('empty drinks → 0', () {
        expect(sessionBacAtTime(drinks: const [], at: t0), 0.0);
      });

      test(
          'sessionSoberTime projects from the pooled total at the last '
          'drink, later than the old max-independent-t_zero would', () {
        // Pool right after the second drink folds in: 0.45 g/L.
        // hoursToZero(0.45) = 3.0h → sober at t1 + 3h = t0 + 4h.
        final expected = t1.add(const Duration(hours: 3));
        expect(sessionSoberTime(drinks: drinks), expected);

        // Contrast: each drink's own independent t_zero is only 2h after its
        // own consumedAt (hoursToZero(0.30) = 2.0h), so the old model's max
        // across them would land at t0+2h vs. t1+2h — both earlier than t0+4h.
        final oldMaxTZero = t1.add(const Duration(hours: 2));
        expect(sessionSoberTime(drinks: drinks)!.isAfter(oldMaxTZero), isTrue);
      });

      test('sessionSoberTime with no drinks → null', () {
        expect(sessionSoberTime(drinks: const []), isNull);
      });

      test(
          'a drink that fully decays to 0 before the next is added does not '
          'leave a negative residual carried forward (the floor applies mid-'
          'fold, not just at the final sample)', () {
        // Drink 1 (0.30 g/L) fully decays after 2h (hoursToZero(0.30) = 2.0).
        // Drink 2 is logged 3h later, well after drink 1 hit 0 — no overlap.
        final farApart = [
          (consumedAt: t0, bacInitial: 0.30),
          (consumedAt: t0.add(const Duration(hours: 3)), bacInitial: 0.20),
        ];
        // If the mid-fold decay didn't floor at 0, drink 1's contribution
        // would go to -0.15 g/L by t0+3h and wrongly cancel out part of
        // drink 2's own 0.20 g/L peak.
        expect(
          sessionBacAtTime(
            drinks: farApart,
            at: t0.add(const Duration(hours: 3)),
          ),
          closeTo(0.20, 1e-9),
        );
      });

      test('three drinks: pool folds every addition, not just the latest', () {
        // 0.10 @ t0, 0.10 @ t0+1h, 0.10 @ t0+2h — each spaced exactly
        // hoursToZero(0.10) = 0.667h apart, so every earlier drink is still
        // partially active when the next is added.
        final threeDrinks = [
          (consumedAt: t0, bacInitial: 0.10),
          (consumedAt: t0.add(const Duration(hours: 1)), bacInitial: 0.10),
          (consumedAt: t0.add(const Duration(hours: 2)), bacInitial: 0.10),
        ];
        // Fold: 0.10 -(1h*0.15)-> max(0, -0.05)=0 , +0.10 = 0.10
        //       0.10 -(1h*0.15)-> max(0, -0.05)=0 , +0.10 = 0.10
        expect(
          sessionBacAtTime(
            drinks: threeDrinks,
            at: t0.add(const Duration(hours: 2)),
          ),
          closeTo(0.10, 1e-9),
        );
      });

      test(
          'sampling strictly between two drinks reflects only the earlier '
          "one's decay so far", () {
        final at = t0.add(const Duration(minutes: 30)); // between t0 and t1
        // Only drink 1 has been consumed by `at`: 0.30 − 0.15×0.5 = 0.225.
        expect(sessionBacAtTime(drinks: drinks, at: at), closeTo(0.225, 1e-9));
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

  group(
    'roundUpToNextHalfHour (party-session.md §BAC line chart: "the end time '
    'is rounded up to the next 30 minutes ... predicted 02:47 → axis ends '
    'at 03:00; predicted 02:05 → axis ends at 02:30")',
    () {
      // NOTE: constructed with the local DateTime(...) constructor (not
      // .utc(...)) — bac.dart's doc comment: "Operates on [time]'s own
      // wall-clock fields ... callers wanting the local tick labels must
      // pass a local DateTime." DateTime.== also compares the isUtc flag, so
      // mixing local/UTC here would make an instant-equal comparison fail.
      test('02:47 → 03:00 (spec example)', () {
        expect(
          roundUpToNextHalfHour(DateTime(2026, 7, 10, 2, 47)),
          DateTime(2026, 7, 10, 3, 0),
        );
      });

      test('02:05 → 02:30 (spec example)', () {
        expect(
          roundUpToNextHalfHour(DateTime(2026, 7, 10, 2, 5)),
          DateTime(2026, 7, 10, 2, 30),
        );
      });

      test(
        'already exactly on a half-hour mark (02:30:00.000) is returned '
        'unchanged — ceiling, not "always add 30 minutes" (bac.dart doc: '
        '"is returned unchanged — this is ceiling ... not always add time")',
        () {
          final exact = DateTime(2026, 7, 10, 2, 30);
          expect(roundUpToNextHalfHour(exact), exact);
        },
      );

      test('already exactly on the hour (03:00:00.000) is returned unchanged',
          () {
        final exact = DateTime(2026, 7, 10, 3, 0);
        expect(roundUpToNextHalfHour(exact), exact);
      });

      test('minute 59 rounds up into the next hour\'s :00', () {
        expect(
          roundUpToNextHalfHour(DateTime(2026, 7, 10, 2, 59)),
          DateTime(2026, 7, 10, 3, 0),
        );
      });

      test('a sub-minute component still rounds up (02:30:00.500)', () {
        // Not exactly on the mark once sub-second precision is considered —
        // must still ceiling forward, matching "already exact" being the
        // narrow case, not the default.
        final almostExact = DateTime(2026, 7, 10, 2, 30, 0, 500);
        expect(
          roundUpToNextHalfHour(almostExact),
          DateTime(2026, 7, 10, 3, 0),
        );
      });
    },
  );

  group(
    'bacChartTickInterval (party-session.md §BAC line chart: "every 30 min '
    'for spans under ~3h, every hour for ~3-8h, every 2 hours beyond that")',
    () {
      // Only span values comfortably inside a tier are asserted — the spec's
      // own "~3h"/"~8h" hedge makes the exact 3h/8h boundary a documented
      // implementation judgment call (bac.dart doc: "picks inclusive upper
      // bounds for the tighter tiers"), not a hard spec requirement.
      test('1h span → 30 min ticks', () {
        expect(
          bacChartTickInterval(const Duration(hours: 1)),
          const Duration(minutes: 30),
        );
      });

      test('2h59m span → 30 min ticks (comfortably under the ~3h tier)', () {
        expect(
          bacChartTickInterval(const Duration(hours: 2, minutes: 59)),
          const Duration(minutes: 30),
        );
      });

      test('5h span → 1h ticks (comfortably inside the ~3-8h tier)', () {
        expect(
          bacChartTickInterval(const Duration(hours: 5)),
          const Duration(hours: 1),
        );
      });

      test('9h span → 2h ticks (comfortably beyond the ~8h tier)', () {
        expect(
          bacChartTickInterval(const Duration(hours: 9)),
          const Duration(hours: 2),
        );
      });
    },
  );
}
