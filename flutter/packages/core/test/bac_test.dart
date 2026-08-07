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
    'β whenever r > β; party-session.md §Step 6 "Emergent property" / '
    '§Absorbing orphan drinks / notifications.md §Party Mode notifications '
    'sober-estimate trigger)',
    () {
      test(
          'known-value vector: 0.3 g/L at β=0.15, drinkConsumeMinutes=20 '
          '(r > β) → 2.0 hours', () {
        // 0.3 / 0.15 = 2.0 exactly on paper, but 0.15 has no exact binary
        // representation, so use closeTo rather than exact equality.
        expect(
          hoursToZero(bacInitial: 0.3, drinkConsumeMinutes: 20),
          closeTo(2.0, 1e-9),
        );
      });

      test(
          'inverse of bacAtTime: decaying for hoursToZero(x) hours from x '
          'lands back at 0', () {
        const bacInitial = 0.360; // worked-example initial BAC.
        final hours = hoursToZero(
          bacInitial: bacInitial,
          drinkConsumeMinutes: 20,
        );
        expect(
          bacAtTime(bacInitial: bacInitial, hoursSince: hours),
          closeTo(0.0, 1e-9),
        );
      });

      test('BAC 0 → 0 hours to zero', () {
        expect(
          hoursToZero(bacInitial: 0.0, drinkConsumeMinutes: 20),
          0.0,
        );
      });
    },
  );

  group(
    'sessionBacAtTime / sessionSoberTime (party-session.md §BAC estimation '
    'algorithm Step 6: pooled elimination across overlapping absorption '
    'windows, not independent per-drink sum)',
    () {
      // drinkConsumeMinutes = 30 → T_hours = (30+30)/60 = 1.0h exactly, a
      // deliberately round absorption window chosen only to keep this
      // group's hand-derived arithmetic exact; it is not otherwise special
      // (the dedicated "absorption window" group below uses the spec's own
      // default of 20).
      const drinkConsumeMinutes = 30;

      // Two drinks, each bacInitial 0.30 g/L, 1 hour apart — exactly one
      // absorption window (1h), so drink 1's window [t0, t1) ends the
      // instant drink 2's window [t1, t0+2h) begins: no double-active
      // overlap, but the pool the first drink built up is still decaying
      // when the second starts absorbing, which is what "pooled, not
      // independent" exercises here.
      final t0 = DateTime.utc(2026, 1, 1, 0);
      final t1 = t0.add(const Duration(hours: 1));
      final drinks = [
        (consumedAt: t0, bacInitial: 0.30),
        (consumedAt: t1, bacInitial: 0.30),
      ];

      test(
          'at the second drink\'s own consumedAt, the pool reflects only '
          "drink 1's now-complete absorption — drink 2 has not started "
          'ramping up yet, unlike the pre-absorption-window model\'s '
          'instant spike', () {
        // Drink 1's window [t0, t1) closes exactly at t1, at its peak:
        // net rate r-β=0.15 sustained over the full 1h window → 0.15.
        // Drink 2's window starts at this same instant t1, but a window's
        // start contributes nothing at that exact instant (Step 4: "the
        // drink is absorbing during [consumedAt, consumedAt+T) and
        // contributes nothing to the pool before consumedAt") — so unlike
        // the pre-absorption-window model (which would show 0.30 here from
        // an instant add of drink 2 on top of drink 1's decayed 0.15), the
        // pool at t1 is exactly drink 1's own peak.
        expect(
          sessionBacAtTime(
            drinks: drinks,
            at: t1,
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
          closeTo(0.15, 1e-9),
        );
      });

      test(
          'during the overlap-adjacent decay, pooled elimination continues '
          'smoothly across the hand-off between drink 1 closing and drink 2 '
          'absorbing', () {
        final at = t0.add(const Duration(minutes: 90)); // t=1.5h
        // From t1 (pool 0.15, net rate r-β=0.15 while drink 2 absorbs):
        // 0.15 + 0.15×0.5 = 0.225.
        expect(
          sessionBacAtTime(
            drinks: drinks,
            at: at,
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
          closeTo(0.225, 1e-9),
        );
      });

      test('drinks consumed after `at` are ignored', () {
        // At t0 itself, drink 1 has not absorbed anything yet either — the
        // pool is 0, not 0.30 (see the previous two tests' note on ramping).
        expect(
          sessionBacAtTime(
            drinks: drinks,
            at: t0,
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
          closeTo(0.0, 1e-9),
        );
      });

      test('unsorted input is handled the same as sorted input', () {
        final reversed = drinks.reversed.toList();
        expect(
          sessionBacAtTime(
            drinks: reversed,
            at: t1,
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
          sessionBacAtTime(
            drinks: drinks,
            at: t1,
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
        );
      });

      test('empty drinks → 0', () {
        expect(
          sessionBacAtTime(
            drinks: const [],
            at: t0,
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
          0.0,
        );
      });

      test(
          'sessionSoberTime projects from the pooled total, later than the '
          'old max-independent-t_zero would', () {
        // Mass-balance shortcut (Step 6 emergent property): total alcohol
        // 0.60 g/L / β = 4.0h from t0 — matches even though the shape now
        // ramps instead of spiking, because neither drink's contribution
        // ever floors to 0 along the way (verified against the direct
        // event-timeline walk; see the module-level note in bac.dart).
        final expected = t0.add(const Duration(hours: 4));
        expect(
          sessionSoberTime(
            drinks: drinks,
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
          expected,
        );

        // Contrast: each drink's own independent t_zero (bacInitial/β) is
        // only 2h after its own consumedAt, so the old per-drink-max model
        // would land at t0+2h vs. t1+2h — both earlier than t0+4h.
        final oldMaxTZero = t1.add(const Duration(hours: 2));
        expect(
          sessionSoberTime(
            drinks: drinks,
            drinkConsumeMinutes: drinkConsumeMinutes,
          )!
              .isAfter(oldMaxTZero),
          isTrue,
        );
      });

      test('sessionSoberTime with no drinks → null', () {
        expect(
          sessionSoberTime(
            drinks: const [],
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
          isNull,
        );
      });

      test(
          'a drink that fully decays to 0 before the next starts absorbing '
          'does not leave a negative residual carried forward (the floor '
          'applies mid-walk, not just at the final sample)', () {
        // Drink 1 (0.30 g/L, T=1h) peaks at 0.15 (t0+1h) then decays alone;
        // it hits the floor at t0+1h+1h=t0+2h (0.15 − 0.15×1 = 0). Drink 2
        // (0.20 g/L) starts absorbing 3h after drink 1, i.e. a full hour
        // after drink 1 already floored — no overlap.
        final farApart = [
          (consumedAt: t0, bacInitial: 0.30),
          (consumedAt: t0.add(const Duration(hours: 3)), bacInitial: 0.20),
        ];
        // At t0+2h drink 1 has just floored and drink 2 hasn't started:
        // pool is exactly 0 — this is the step that would go negative
        // (0.15 − 0.15×2 = −0.15) without the mid-walk floor.
        expect(
          sessionBacAtTime(
            drinks: farApart,
            at: t0.add(const Duration(hours: 2)),
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
          closeTo(0.0, 1e-9),
        );
        // At t0+3h (drink 2's own consumedAt) the pool is still 0 (drink 2
        // hasn't absorbed anything yet).
        expect(
          sessionBacAtTime(
            drinks: farApart,
            at: t0.add(const Duration(hours: 3)),
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
          closeTo(0.0, 1e-9),
        );
        // At t0+4h (drink 2's window closes) the pool is drink 2's own
        // uncontaminated peak: r=0.20, net=0.20−0.15=0.05, ×T(1h)=0.05. If
        // the floor had NOT applied at t0+3h above, drink 1's un-floored
        // −0.15 residual would still be dragging this down to ≈−0.40.
        expect(
          sessionBacAtTime(
            drinks: farApart,
            at: t0.add(const Duration(hours: 4)),
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
          closeTo(0.05, 1e-9),
        );
      });

      test('three drinks: pool folds every addition, not just the latest', () {
        // 0.30 g/L each, 30 min apart (t0, t0+30min, t0+1h) with T=1h, so
        // each pair of consecutive drinks overlaps for 30 min — genuinely
        // exercising 3-drink pooling (unlike back-to-back non-overlapping
        // windows).
        final threeDrinks = [
          (consumedAt: t0, bacInitial: 0.30),
          (consumedAt: t0.add(const Duration(minutes: 30)), bacInitial: 0.30),
          (consumedAt: t0.add(const Duration(hours: 1)), bacInitial: 0.30),
        ];
        // At t0+1h (drink 3's own consumedAt), drinks 1 and 2 have already
        // pooled to 0.30 from their own 30-minute overlap — proving the
        // fold carries forward past drink 2's addition, not just drink 1's.
        expect(
          sessionBacAtTime(
            drinks: threeDrinks,
            at: t0.add(const Duration(hours: 1)),
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
          closeTo(0.30, 1e-9),
        );
        // At t0+2h, all three windows have closed. Mass balance: 0.90 g/L
        // absorbed total, minus β×2h=0.30 eliminated (the pool is positive
        // throughout, so elimination is never wasted against an empty
        // floor) = 0.60.
        expect(
          sessionBacAtTime(
            drinks: threeDrinks,
            at: t0.add(const Duration(hours: 2)),
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
          closeTo(0.60, 1e-9),
        );
      });

      test(
          'sampling strictly between two drinks reflects only the earlier '
          "one's own partial absorption so far", () {
        final at = t0.add(const Duration(minutes: 30)); // between t0 and t1
        // Only drink 1 is absorbing by `at`, halfway through its window:
        // net rate r-β=0.15 for 0.5h → 0.075.
        expect(
          sessionBacAtTime(
            drinks: drinks,
            at: at,
            drinkConsumeMinutes: drinkConsumeMinutes,
          ),
          closeTo(0.075, 1e-9),
        );
      });
    },
  );

  group(
    'sessionBacAtTime / sessionSoberTime — absorption window (Step 4-6, '
    'party-session.md §Worked example / §Worked example 2 — staggered '
    'drinks)',
    () {
      // Same spec discrepancy as the NOTE at the top of this file: the
      // design doc hand-computed its peak/etc. worked-example numbers
      // (0.237, 0.011/0.201/0.212 g/L) from its own rounded 0.362 g/L
      // intermediate, not the formula-precise ~0.360. So — as with the
      // top-of-file NOTE — the fixtures below recompute `bacInitial`
      // programmatically from this same 75kg/180cm/30yo-male/two-beers
      // profile and derive every expected value from *that* precise
      // number, rather than hand-copying the doc's rounded literals. The
      // doc's numbers remain a useful sanity-check on magnitude/shape
      // only.
      final perBeerAlcohol = alcoholGrams(volumeMl: 250, abvPercent: 5);
      final totalAlcohol = 2 * perBeerAlcohol;
      final tbw = watsonTbwLitres(
        gender: Gender.male,
        ageYears: 30,
        heightCm: 180,
        weightKg: 75,
      );
      final bacInitial = bacInitialWatson(
        alcoholGrams: totalAlcohol,
        tbwLitres: tbw,
      );
      final perBeerBacInitial = bacInitialWatson(
        alcoholGrams: perBeerAlcohol,
        tbwLitres: tbw,
      );

      const drinkConsumeMinutes = 20; // party-session.md default.
      final t0 = DateTime.utc(2026, 1, 1, 0);

      group('absorptionWindowHours', () {
        test('boundary values: 0 min → 0.5h (fixed floor), 60 min → 1.5h', () {
          expect(absorptionWindowHours(0), 0.5);
          expect(absorptionWindowHours(60), 1.5);
        });

        test('20 min (default) → 50/60 h', () {
          expect(absorptionWindowHours(20), 50 / 60);
        });
      });

      group('Worked example 1 — two beers logged at the same instant', () {
        final tHours = absorptionWindowHours(drinkConsumeMinutes);
        final drinks = [(consumedAt: t0, bacInitial: bacInitial)];

        test('T_hours = 50/60 (20 + 30 min)', () {
          expect(tHours, closeTo(50 / 60, 1e-12));
        });

        test(
            'pool at consumedAt + 50min equals the peak: '
            '(r - β) × T_hours', () {
          final r = bacInitial / tHours;
          final net = r - eliminationBetaGPerLPerHour;
          final peak = net * tHours;
          expect(
            sessionBacAtTime(
              drinks: drinks,
              at: t0.add(const Duration(minutes: 50)),
              drinkConsumeMinutes: drinkConsumeMinutes,
            ),
            closeTo(peak, 1e-9),
          );
        });

        test(
            'pool at consumedAt + 2h equals bacInitial − β×2 — the same '
            "decay line the old instant-absorption model sits on, once "
            "the window has closed (Step 6 emergent property)", () {
          expect(
            sessionBacAtTime(
              drinks: drinks,
              at: t0.add(const Duration(hours: 2)),
              drinkConsumeMinutes: drinkConsumeMinutes,
            ),
            closeTo(bacInitial - eliminationBetaGPerLPerHour * 2, 1e-9),
          );
        });

        test(
            'sessionSoberTime = consumedAt + bacInitial/β — unaffected by '
            'the absorption window (r > β here)', () {
          final expected = t0.add(
            Duration(
              microseconds: (bacInitial /
                      eliminationBetaGPerLPerHour *
                      Duration.microsecondsPerHour)
                  .round(),
            ),
          );
          expect(
            sessionSoberTime(
              drinks: drinks,
              drinkConsumeMinutes: drinkConsumeMinutes,
            ),
            expected,
          );
        });
      });

      group('Worked example 2 — staggered drinks, 10 min apart', () {
        // Beer A at consumedAt=t0, beer B 10 min later — each individually
        // at perBeerBacInitial, exercising overlapping (not identical)
        // absorption windows: A absorbs over [0, 50min), B over
        // [10min, 60min), a 40-minute overlap.
        final beerA = (consumedAt: t0, bacInitial: perBeerBacInitial);
        final beerB = (
          consumedAt: t0.add(const Duration(minutes: 10)),
          bacInitial: perBeerBacInitial,
        );
        final staggered = [beerA, beerB];

        double poolAt(int minutes) => sessionBacAtTime(
              drinks: staggered,
              at: t0.add(Duration(minutes: minutes)),
              drinkConsumeMinutes: drinkConsumeMinutes,
            );

        test(
            'pool at 10 min (A only, just before B starts absorbing) — '
            'derived from perBeerBacInitial, not the design doc\'s rounded '
            '0.011', () {
          final tHours = absorptionWindowHours(drinkConsumeMinutes);
          final rA = perBeerBacInitial / tHours;
          final netAOnly = rA - eliminationBetaGPerLPerHour;
          final expected = netAOnly * (10 / 60);
          expect(poolAt(10), closeTo(expected, 1e-9));
        });

        test(
            'pool at 50 min (A\'s window closes, A+B both active since '
            '10min)', () {
          // Regression against the "naive independent-sum" bug Step 6
          // pooling avoids: one shared β through the whole 10-50min
          // overlap, not β subtracted once per active drink.
          final tHours = absorptionWindowHours(drinkConsumeMinutes);
          final rA = perBeerBacInitial / tHours;
          final rB = rA;
          final poolAt10 = (rA - eliminationBetaGPerLPerHour) * (10 / 60);
          final pooledNet = (rA + rB) - eliminationBetaGPerLPerHour;
          final naiveNet = (rA - eliminationBetaGPerLPerHour) +
              (rB - eliminationBetaGPerLPerHour);
          expect(
            pooledNet,
            greaterThan(naiveNet),
          ); // pooled subtracts β once, naive subtracts it twice.
          final expected = poolAt10 + pooledNet * (40 / 60);
          expect(poolAt(50), closeTo(expected, 1e-9));
        });

        test('pool at 60 min (B\'s window closes too — the overall peak)', () {
          final tHours = absorptionWindowHours(drinkConsumeMinutes);
          final rB = perBeerBacInitial / tHours;
          final netBOnly = rB - eliminationBetaGPerLPerHour;
          final poolAt50 = poolAt(50);
          final expected = poolAt50 + netBOnly * (10 / 60);
          expect(poolAt(60), closeTo(expected, 1e-9));
        });
      });

      group('hoursToZero — orphan absorption edge cases', () {
        test(
            'typical drink (r > β): same value as the pre-absorption-window '
            'formula bacInitial/β', () {
          expect(
            hoursToZero(bacInitial: 0.3, drinkConsumeMinutes: 20),
            closeTo(0.3 / eliminationBetaGPerLPerHour, 1e-9),
          );
        });

        test(
            'slow enough that r <= β (small bacInitial, long '
            'drinkConsumeMinutes): never accumulates residual BAC → 0', () {
          // bacInitial=0.05, drinkConsumeMinutes=60 → T_hours=1.5,
          // r=0.05/1.5≈0.0333 < β=0.15.
          const smallBacInitial = 0.05;
          const slowMinutes = 60;
          final r = smallBacInitial / absorptionWindowHours(slowMinutes);
          expect(r, lessThan(eliminationBetaGPerLPerHour));
          expect(
            hoursToZero(
              bacInitial: smallBacInitial,
              drinkConsumeMinutes: slowMinutes,
            ),
            0.0,
          );
        });
      });

      group(
        'sessionSoberTime — genuine sober gap followed by a later drink',
        () {
          // Beer A at t0 fully decays to 0 in isolation well before beer B
          // starts (A's own isolated sober time is t0 + bacInitial/β ≈ 72
          // min, comfortably inside the 180-minute gap before B). A real
          // sober gap therefore exists between A clearing and B starting —
          // sessionSoberTime must report B's own eventual zero-time, not
          // stop at the first (A's) crossing it finds while scanning
          // forward.
          final aIsolatedHoursToZero = hoursToZero(
            bacInitial: perBeerBacInitial,
            drinkConsumeMinutes: drinkConsumeMinutes,
          );
          const gapMinutes = 180;
          final beerA = (consumedAt: t0, bacInitial: perBeerBacInitial);
          final beerBConsumedAt = t0.add(const Duration(minutes: gapMinutes));
          final beerB =
              (consumedAt: beerBConsumedAt, bacInitial: perBeerBacInitial);
          final drinks = [beerA, beerB];

          test('the gap is real: pool is exactly 0 partway through it', () {
            // A's window ends at t0+50min and it fully clears by
            // ~t0+72min — sampling at t0+120min (still 60 min before B
            // starts) must read 0, confirming there is genuinely nothing
            // left in the blood at that instant.
            expect(
              sessionBacAtTime(
                drinks: drinks,
                at: t0.add(const Duration(minutes: 120)),
                drinkConsumeMinutes: drinkConsumeMinutes,
              ),
              0.0,
            );
          });

          test(
              'sessionSoberTime reports B\'s own zero-time, not the '
              'earlier A-only crossing', () {
            final expected = beerBConsumedAt.add(
              Duration(
                microseconds:
                    (aIsolatedHoursToZero * Duration.microsecondsPerHour)
                        .round(),
              ),
            );
            final actual = sessionSoberTime(
              drinks: drinks,
              drinkConsumeMinutes: drinkConsumeMinutes,
            );
            expect(actual, isNotNull);
            expect(
              actual!.difference(expected).inSeconds.abs(),
              lessThanOrEqualTo(1),
            );
            // Regression guard: the bug this test catches returned A's own
            // (much earlier) isolated sober time instead.
            final aOnlySoberTime = t0.add(
              Duration(
                microseconds:
                    (aIsolatedHoursToZero * Duration.microsecondsPerHour)
                        .round(),
              ),
            );
            expect(actual.isAfter(aOnlySoberTime), isTrue);
          });
        },
      );

      group(
        'sessionSoberTime — trailing r <= β drink floors before its own '
        'window closes',
        () {
          // A = 0.30 g/L @ t0, B = 0.05 g/L @ t0+90min, drinkConsumeMinutes
          // = 30 (T_hours = 1h for both). r_B = 0.05/1 = 0.05 < β = 0.15, so
          // B's own segment (net rate r_B-β = -0.10) is negative for its
          // entire [90,150)min window — the pool floors to 0 partway
          // through that window, not at its close. Regression for a bug
          // where sessionSoberTime assumed the crossing always lands
          // exactly at the last breakpoint's own time.
          const localDrinkConsumeMinutes = 30;
          final drinkA = (consumedAt: t0, bacInitial: 0.30);
          final bConsumedAt = t0.add(const Duration(minutes: 90));
          final drinkB = (consumedAt: bConsumedAt, bacInitial: 0.05);
          final drinks = [drinkA, drinkB];

          final tHours = absorptionWindowHours(localDrinkConsumeMinutes);
          final rB = 0.05 / tHours;

          test('confirms the floor is reached before B\'s window closes', () {
            // rB < β is the whole premise of this fixture — B's segment
            // must be negative for its entire window, not just partially.
            expect(rB, lessThan(eliminationBetaGPerLPerHour));
            // Pool at B's own window-close (t0+150min) must already read
            // 0 — otherwise this fixture doesn't actually exercise the bug.
            expect(
              sessionBacAtTime(
                drinks: drinks,
                at: t0.add(const Duration(minutes: 150)),
                drinkConsumeMinutes: localDrinkConsumeMinutes,
              ),
              0.0,
            );
          });

          test('reports the true mid-window crossing, not the window close',
              () {
            // Pool entering B's segment (at t0+90min) is A's own remaining
            // decay: A absorbed over [0,60min) at r_A=0.30/1=0.30, net
            // 0.30-0.15=0.15, peak 0.15 at 60min, then pure -β decay for
            // 30 more minutes to 90min: 0.15 - 0.15*0.5 = 0.075.
            const poolEnteringB = 0.075;
            final netInB = rB - eliminationBetaGPerLPerHour;
            final hoursToFloor = poolEnteringB / -netInB;
            final expected = bConsumedAt.add(
              Duration(
                microseconds:
                    (hoursToFloor * Duration.microsecondsPerHour).round(),
              ),
            );
            final actual = sessionSoberTime(
              drinks: drinks,
              drinkConsumeMinutes: localDrinkConsumeMinutes,
            );
            expect(actual, isNotNull);
            expect(
              actual!.difference(expected).inSeconds.abs(),
              lessThanOrEqualTo(1),
            );
            // Regression guard: the bug this test catches returned B's
            // window-close time (t0+150min) instead of the true ~t0+135min
            // crossing — a 15-minute overshoot.
            expect(
              actual.isBefore(t0.add(const Duration(minutes: 150))),
              isTrue,
            );
          });
        },
      );
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
