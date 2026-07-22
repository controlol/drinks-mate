import 'package:core/core.dart';

import '../models/drink_entry.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';

/// Result of estimating a Party Session's current BAC (party-session.md
/// §BAC estimation algorithm) — orchestrates the pure `core` functions over
/// a session's alcoholic entries and meals, pooling every drink's
/// contribution into one running elimination total ([sessionBacAtTime]).
class BacEstimate {
  const BacEstimate({
    required this.gPerL,
    required this.mmolPerL,
    required this.usedWatson,
    required this.unspecifiedGenderConservative,
    required this.bmiWarning,
  });

  /// Primary display value — canonical unit (party-session.md §Display units).
  final double gPerL;

  /// Secondary display value, derived from [gPerL] (display-only).
  final double mmolPerL;

  /// True when the Watson TBW model was used (height present); false means
  /// the Widmark fallback was used.
  final bool usedWatson;

  /// True when [UserProfile.gender] is `unspecified` — the display should
  /// show the "conservative model" footnote (party-session.md §Required
  /// user inputs: "Gender — unspecified handling").
  final bool unspecifiedGenderConservative;

  /// True when the Watson-path BMI-range warning applies (only ever true
  /// when [usedWatson] is also true — see [bmiWarningApplies]).
  final bool bmiWarning;

  static const zero = BacEstimate(
    gPerL: 0,
    mmolPerL: 0,
    usedWatson: false,
    unspecifiedGenderConservative: false,
    bmiWarning: false,
  );
}

/// Estimates the current BAC for a Party Session (party-session.md §BAC
/// estimation algorithm, Steps 1–6).
///
/// [alcoholicEntries] should be the session's alcoholic [DrinkEntry] rows
/// (already-elapsed drinks only; future-dated entries are not expected).
/// [meals] are every [Meal] attached to the session — the meal modifier is
/// re-evaluated per drink from the full list (party-session.md §Meals: "take
/// the smallest modifier across all of them").
///
/// Requires [profile.birthDate] to be set — Party Mode's own precondition
/// (party-session.md §Required user inputs); throws [StateError] otherwise.
BacEstimate estimateSessionBac({
  required UserProfile profile,
  required List<DrinkEntry> alcoholicEntries,
  required List<Meal> meals,
  required DateTime at,
}) {
  if (alcoholicEntries.isEmpty) return BacEstimate.zero;

  final birthDateString = profile.birthDate;
  if (birthDateString == null) {
    throw StateError('UserProfile.birthDate is required to estimate BAC.');
  }
  final birthDate = DateTime.parse(birthDateString);
  final gender = _genderFromProfile(profile.gender);
  final weightKg = profile.weightKg ?? 70.0;
  final heightCm = profile.heightCm;
  final usedWatson = heightCm != null;

  final drinks = alcoholicEntries
      .map(
        (entry) => (
          consumedAt: entry.consumedAt,
          bacInitial: _bacInitialForEntry(
            birthDate: birthDate,
            gender: gender,
            weightKg: weightKg,
            heightCm: heightCm,
            entry: entry,
            meals: meals,
          ),
        ),
      )
      .toList();
  final totalGPerL = sessionBacAtTime(drinks: drinks, at: at);

  var bmiWarning = false;
  if (usedWatson) {
    final bodyMassIndex = bmi(weightKg: weightKg, heightCm: heightCm);
    bmiWarning = bmiWarningApplies(bmi: bodyMassIndex, gender: gender);
  }

  return BacEstimate(
    gPerL: totalGPerL,
    mmolPerL: gPerLToMmol(totalGPerL),
    usedWatson: usedWatson,
    unspecifiedGenderConservative: gender == Gender.unspecified,
    bmiWarning: bmiWarning,
  );
}

/// Projected time at which the session's pooled BAC ([sessionBacAtTime])
/// returns to 0 g/L, or `null` if there are no alcoholic entries yet.
///
/// [alcoholicEntries] is filtered to entries with `consumedAt <= at` before
/// folding, same as [estimateSessionBac] — an entry logged with a future
/// `consumedAt` (S9's edit affordance allows this, e.g. correcting a
/// mis-picked time) must not be pooled in before its time, or the projected
/// sober time would disagree with the current BAC estimate about what has
/// actually been "consumed" as of [at].
///
/// Requires [profile.birthDate] to be set — same precondition as
/// [estimateSessionBac].
DateTime? projectedSoberTime({
  required UserProfile profile,
  required List<DrinkEntry> alcoholicEntries,
  required List<Meal> meals,
  required DateTime at,
}) {
  final consumedByAt =
      alcoholicEntries.where((e) => !e.consumedAt.isAfter(at)).toList();
  if (consumedByAt.isEmpty) return null;

  final birthDateString = profile.birthDate;
  if (birthDateString == null) {
    throw StateError('UserProfile.birthDate is required to estimate BAC.');
  }
  final birthDate = DateTime.parse(birthDateString);
  final gender = _genderFromProfile(profile.gender);
  final weightKg = profile.weightKg ?? 70.0;
  final heightCm = profile.heightCm;

  final drinks = consumedByAt
      .map(
        (entry) => (
          consumedAt: entry.consumedAt,
          bacInitial: _bacInitialForEntry(
            birthDate: birthDate,
            gender: gender,
            weightKg: weightKg,
            heightCm: heightCm,
            entry: entry,
            meals: meals,
          ),
        ),
      )
      .toList();
  return sessionSoberTime(drinks: drinks);
}

double _bacInitialForEntry({
  required DateTime birthDate,
  required Gender gender,
  required double weightKg,
  required double? heightCm,
  required DrinkEntry entry,
  required List<Meal> meals,
}) {
  final ageYears = ageYearsFromBirthDate(
    birthDate: birthDate,
    today: entry.consumedAt.toLocal(),
  );
  final grams = alcoholGrams(
    volumeMl: entry.volumeMl.toDouble(),
    abvPercent: entry.abvPercent ?? 0,
  );
  final modifier = mealModifier(
    meals.map(
      (meal) => (
        size: meal.size,
        deltaHours: entry.consumedAt.difference(meal.eatenAt).inMicroseconds /
            Duration.microsecondsPerHour,
      ),
    ),
  );
  return bacInitialForDrink(
    alcoholGrams: grams,
    gender: gender,
    ageYears: ageYears,
    heightCm: heightCm,
    weightKg: weightKg,
    mealModifier: modifier,
  );
}

Gender _genderFromProfile(String? gender) => switch (gender) {
      'male' => Gender.male,
      'female' => Gender.female,
      _ => Gender.unspecified,
    };
