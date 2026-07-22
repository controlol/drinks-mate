// Tests for issue #24's bac_estimator.dart additions:
//  - projectedSoberTime() (new)
//  - estimateSessionBac() (characterization — previously only covered
//    indirectly via widgets/party_screen_test.dart; pins the behaviour
//    behind the new _bacInitialForEntry extraction).
//
// Fixture-builder conventions (UserProfile/DrinkEntry/Meal literals, the
// worked-example birthdate/consumedAt pair) mirror
// flutter/test/widgets/party_screen_test.dart, which already establishes and
// documents them — expected numeric values are derived from `core`'s own BAC
// functions (never hand-typed), same convention as bac_test.dart and
// party_screen_test.dart.

import 'package:core/core.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/models/meal.dart';
import 'package:drinks_mate/src/models/user_profile.dart';
import 'package:drinks_mate/src/services/bac_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

final _epoch = DateTime.utc(2026, 1, 1);

UserProfile _profile({
  String gender = 'male',
  double? weightKg = 75,
  double? heightCm,
  String? birthDate = '1990-01-01',
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

DrinkEntry _entry({
  required int volumeMl,
  required double abvPercent,
  required DateTime consumedAt,
  String id = 'entry-1',
}) {
  return DrinkEntry(
    id: id,
    beverageType: BeverageType.beer,
    volumeMl: volumeMl,
    abvPercent: abvPercent,
    consumedAt: consumedAt,
    createdAt: consumedAt,
    updatedAt: consumedAt,
  );
}

Meal _meal({
  required MealSize size,
  required DateTime eatenAt,
  String id = 'meal-1',
}) {
  return Meal(
    id: id,
    partySessionId: 's1',
    size: size,
    eatenAt: eatenAt,
    createdAt: eatenAt,
    updatedAt: eatenAt,
  );
}

/// Mirrors projectedSoberTime()'s own t_zero expression (bac_estimator.dart):
/// `consumedAt + Duration(microseconds: round(hoursToZero(bacInitial) * µs/h))`.
/// Building the expected value the same way the production code documents its
/// formula (not reading it off the implementation's output) keeps this a
/// faithful spec check rather than a implementation-freeze.
DateTime _expectedTZero({
  required DateTime consumedAt,
  required double bacInitial,
}) {
  return consumedAt.add(
    Duration(
      microseconds:
          (hoursToZero(bacInitial) * Duration.microsecondsPerHour).round(),
    ),
  );
}

void main() {
  group('projectedSoberTime — empty entries', () {
    test('returns null when there are no alcoholic entries', () {
      final result = projectedSoberTime(
        profile: _profile(),
        alcoholicEntries: const [],
        meals: const [],
        at: DateTime.utc(2026, 3, 1),
      );
      expect(result, isNull);
    });
  });

  group(
    'projectedSoberTime — known worked example (Widmark fallback, no meals)',
    () {
      // 75 kg male, no height → Widmark path (widmarkR(male) = 0.68).
      // One 500 ml 5% ABV beer:
      //   alcohol_grams = 500 * 0.05 * 0.789 = 19.725 g
      //   bacInitial = 19.725 / (75 * 0.68) = 19.725 / 51 ≈ 0.38676 g/L
      //   hoursToZero = 0.38676... / 0.15 ≈ 2.5784 h (≈ 2h 34m 42s)
      // (Parity Rulebook "BAC: Widmark fallback"; bac.dart hoursToZero doc.)
      final consumedAt = DateTime.utc(2026, 3, 1, 20, 0);
      final grams = alcoholGrams(volumeMl: 500, abvPercent: 5.0);
      final bacInitial = bacInitialWidmark(
        alcoholGrams: grams,
        weightKg: 75,
        r: widmarkR(Gender.male),
      );

      test('sanity: bacInitial ≈ 0.3868 g/L', () {
        expect(bacInitial, closeTo(0.3868, 0.0001));
      });

      test('t_zero = consumedAt + hoursToZero(bacInitial)', () {
        final expected = _expectedTZero(
          consumedAt: consumedAt,
          bacInitial: bacInitial,
        );
        final actual = projectedSoberTime(
          profile: _profile(heightCm: null),
          alcoholicEntries: [
            _entry(volumeMl: 500, abvPercent: 5.0, consumedAt: consumedAt),
          ],
          meals: const [],
          at: consumedAt,
        );
        expect(actual, expected);
        // Human-checkable anchor for the exact value asserted above.
        expect(
          actual!.difference(consumedAt).inMilliseconds / 1000 / 3600,
          closeTo(2.5784, 0.001),
        );
      });
    },
  );

  group('projectedSoberTime — multiple drinks: pooled, not per-drink max', () {
    // Three drinks, same 75 kg male / no-height (Widmark) profile, logged in
    // list order A, B, C (A earliest consumedAt, C latest). B — the *middle*
    // entry, neither first nor last — has by far the largest dose (1000 ml
    // 40% spirit). Under the pooled model (party-session.md §BAC estimation
    // algorithm Step 5; core's sessionSoberTime), the session goes sober once
    // the *shared* pool empties after the last drink, not per-drink — so the
    // expected value is built the same way projectedSoberTime documents it:
    // via core's own sessionSoberTime, not a hand-picked per-drink t_zero.
    final consumedAtA = DateTime.utc(2026, 3, 1, 8, 0);
    final consumedAtB = DateTime.utc(2026, 3, 1, 12, 0);
    final consumedAtC = DateTime.utc(2026, 3, 1, 18, 0);

    final gramsA = alcoholGrams(volumeMl: 250, abvPercent: 5.0);
    final gramsB = alcoholGrams(volumeMl: 1000, abvPercent: 40.0);
    final gramsC = alcoholGrams(volumeMl: 500, abvPercent: 12.0);

    final bacA = bacInitialWidmark(
      alcoholGrams: gramsA,
      weightKg: 75,
      r: widmarkR(Gender.male),
    );
    final bacB = bacInitialWidmark(
      alcoholGrams: gramsB,
      weightKg: 75,
      r: widmarkR(Gender.male),
    );
    final bacC = bacInitialWidmark(
      alcoholGrams: gramsC,
      weightKg: 75,
      r: widmarkR(Gender.male),
    );

    final tZeroA = _expectedTZero(consumedAt: consumedAtA, bacInitial: bacA);
    final tZeroB = _expectedTZero(consumedAt: consumedAtB, bacInitial: bacB);
    final tZeroC = _expectedTZero(consumedAt: consumedAtC, bacInitial: bacC);

    final expectedPooled = sessionSoberTime(
      drinks: [
        (consumedAt: consumedAtA, bacInitial: bacA),
        (consumedAt: consumedAtB, bacInitial: bacB),
        (consumedAt: consumedAtC, bacInitial: bacC),
      ],
    );

    test(
        'sanity: the pooled sober time is later than every individual '
        "drink's own independent t_zero — B's huge dose keeps the shared "
        'pool going well past when any drink alone would have decayed', () {
      expect(expectedPooled!.isAfter(tZeroA), isTrue);
      expect(expectedPooled.isAfter(tZeroB), isTrue);
      expect(expectedPooled.isAfter(tZeroC), isTrue);
    });

    test(
        'projectedSoberTime matches core\'s sessionSoberTime for the same '
        'drinks', () {
      final actual = projectedSoberTime(
        profile: _profile(heightCm: null),
        alcoholicEntries: [
          _entry(
            id: 'A',
            volumeMl: 250,
            abvPercent: 5.0,
            consumedAt: consumedAtA,
          ),
          _entry(
            id: 'B',
            volumeMl: 1000,
            abvPercent: 40.0,
            consumedAt: consumedAtB,
          ),
          _entry(
            id: 'C',
            volumeMl: 500,
            abvPercent: 12.0,
            consumedAt: consumedAtC,
          ),
        ],
        meals: const [],
        at: consumedAtC,
      );
      expect(actual, expectedPooled);
    });
  });

  group('projectedSoberTime — meal modifier shifts the projection', () {
    // party-session.md §Meals: the meal modifier reduces bacInitial, which
    // (via hoursToZero) pulls t_zero earlier than the no-meal case. Same
    // Widmark fixture as above, single drink, one medium meal eaten 1 hour
    // before the drink.
    final consumedAt = DateTime.utc(2026, 3, 1, 20, 0);
    final mealEatenAt = consumedAt.subtract(const Duration(hours: 1));
    final grams = alcoholGrams(volumeMl: 500, abvPercent: 5.0);

    final bacNoMeal = bacInitialWidmark(
      alcoholGrams: grams,
      weightKg: 75,
      r: widmarkR(Gender.male),
    );
    final modifier = mealModifierSingle(
      size: MealSize.medium,
      deltaHours: 1.0,
    );
    final bacWithMeal = bacInitialWidmark(
      alcoholGrams: grams,
      weightKg: 75,
      r: widmarkR(Gender.male),
      mealModifier: modifier,
    );

    test('sanity: meal modifier < 1.0 strictly lowers bacInitial', () {
      expect(modifier, lessThan(1.0));
      expect(bacWithMeal, lessThan(bacNoMeal));
    });

    test(
        'projectedSoberTime with the meal reflects the meal-adjusted '
        'bacInitial, landing earlier than the no-meal t_zero', () {
      final expectedWithMeal = _expectedTZero(
        consumedAt: consumedAt,
        bacInitial: bacWithMeal,
      );
      final expectedNoMeal = _expectedTZero(
        consumedAt: consumedAt,
        bacInitial: bacNoMeal,
      );

      final actualWithMeal = projectedSoberTime(
        profile: _profile(heightCm: null),
        alcoholicEntries: [
          _entry(volumeMl: 500, abvPercent: 5.0, consumedAt: consumedAt),
        ],
        meals: [_meal(size: MealSize.medium, eatenAt: mealEatenAt)],
        at: consumedAt,
      );
      final actualNoMeal = projectedSoberTime(
        profile: _profile(heightCm: null),
        alcoholicEntries: [
          _entry(volumeMl: 500, abvPercent: 5.0, consumedAt: consumedAt),
        ],
        meals: const [],
        at: consumedAt,
      );

      expect(actualWithMeal, expectedWithMeal);
      expect(actualNoMeal, expectedNoMeal);
      expect(actualWithMeal!.isBefore(actualNoMeal!), isTrue);
    });
  });

  group('projectedSoberTime — precondition', () {
    test(
        'throws StateError when profile.birthDate is null (same '
        'precondition as estimateSessionBac)', () {
      expect(
        () => projectedSoberTime(
          profile: _profile(birthDate: null),
          alcoholicEntries: [
            _entry(
              volumeMl: 500,
              abvPercent: 5.0,
              consumedAt: DateTime.utc(2026, 3, 1),
            ),
          ],
          meals: const [],
          at: DateTime.utc(2026, 3, 1),
        ),
        throwsStateError,
      );
    });
  });

  group(
    'estimateSessionBac — characterization (party-session.md §Worked '
    'example; pins behaviour through the new _bacInitialForEntry '
    'extraction)',
    () {
      // Reuses the exact worked-example birthdate/consumedAt pair from
      // widgets/party_screen_test.dart: an exact 30-calendar-year gap rounds
      // DOWN to age 29 under the Parity Rulebook's
      // floor((today-birthDate)/365.25) formula (10957 days < 10957.5), so
      // the ~1-month margin here is required to land on the worked example's
      // stated age 30 and its 0.360 g/L figure.
      const birthDate = '1996-06-01';
      final consumedAt = DateTime.utc(2026, 7, 1, 12, 0);

      final ageYears = ageYearsFromBirthDate(
        birthDate: DateTime.parse(birthDate),
        today: consumedAt.toLocal(),
      );
      final grams = alcoholGrams(volumeMl: 500, abvPercent: 5.0);
      final tbw = watsonTbwLitres(
        gender: Gender.male,
        ageYears: ageYears,
        heightCm: 180,
        weightKg: 75,
      );
      final expectedBacInitial = bacInitialWatson(
        alcoholGrams: grams,
        tbwLitres: tbw,
      );
      final expectedBmi = bmi(weightKg: 75, heightCm: 180);
      final expectedBmiWarning = bmiWarningApplies(
        bmi: expectedBmi,
        gender: Gender.male,
      );

      test(
        'one drink, at consumedAt (elapsed=0): gPerL/mmolPerL/usedWatson/'
        'bmiWarning all match hand-computed expectations',
        () {
          final estimate = estimateSessionBac(
            profile: _profile(
              gender: 'male',
              weightKg: 75,
              heightCm: 180,
              birthDate: birthDate,
            ),
            alcoholicEntries: [
              _entry(volumeMl: 500, abvPercent: 5.0, consumedAt: consumedAt),
            ],
            meals: const [],
            at: consumedAt,
          );

          expect(estimate.gPerL, closeTo(expectedBacInitial, 0.0001));
          expect(estimate.gPerL, closeTo(0.360, 0.001));
          expect(
            estimate.mmolPerL,
            closeTo(gPerLToMmol(expectedBacInitial), 0.0001),
          );
          expect(estimate.usedWatson, isTrue);
          expect(estimate.unspecifiedGenderConservative, isFalse);
          expect(estimate.bmiWarning, expectedBmiWarning);
          expect(estimate.bmiWarning, isFalse); // BMI ≈ 23.15 — mid-range.
        },
      );
    },
  );
}
