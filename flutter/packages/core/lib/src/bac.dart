import 'dart:math' as math;

/// Blood-alcohol estimation.
///
/// Source: Parity Rulebook → "BAC: *" rows (party-session.md Steps 1–6).
/// g/L is the canonical internal unit; mmol/L is display-only.

/// Ethanol density, g/mL.
const double ethanolDensityGPerMl = 0.789;

/// Water fraction of whole blood (Watson path).
const double bloodWaterFraction = 0.806;

/// Widmark elimination rate, g/L per hour (β).
const double eliminationBetaGPerLPerHour = 0.15;

/// g/L → mmol/L conversion factor (display-only).
const double gPerLToMmolPerL = 21.7;

/// Unspecified uses the **female** factor/coefficients throughout (conservative
/// = higher estimate). See Parity Rulebook note.
enum Gender { male, female, unspecified }

/// Meal size before/around a drink. Drives the meal modifier.
enum MealSize { small, medium, large }

/// Step 1 — grams of pure alcohol in a drink.
///
/// `alcohol_grams = volume_ml × (abv_percent / 100) × 0.789`
double alcoholGrams({required double volumeMl, required double abvPercent}) =>
    volumeMl * (abvPercent / 100) * ethanolDensityGPerMl;

/// Step 2 — Watson total body water, litres.
///
/// `unspecified` uses the female coefficients (conservative).
double watsonTbwLitres({
  required Gender gender,
  required int ageYears,
  required double heightCm,
  required double weightKg,
}) {
  if (gender == Gender.male) {
    return 2.447 - 0.09516 * ageYears + 0.1074 * heightCm + 0.3362 * weightKg;
  }
  return -2.097 + 0.1069 * heightCm + 0.2466 * weightKg;
}

/// Step 2 — Widmark r factor (used only when height is missing).
///
/// 0.68 male, 0.55 female, 0.55 unspecified (conservative).
double widmarkR(Gender gender) => gender == Gender.male ? 0.68 : 0.55;

/// Meal modifier for a single meal logged `deltaHours` before the drink.
///
/// `Δt<0 → 1.00`; else `1.00 − (1.00 − peak) × exp(−Δt/τ)`.
/// peak/τ: small 0.95/1.5h, medium 0.85/2.5h, large 0.75/3.5h.
double mealModifierSingle({
  required MealSize size,
  required double deltaHours,
}) {
  if (deltaHours < 0) return 1.0;
  final (peak, tau) = switch (size) {
    MealSize.small => (0.95, 1.5),
    MealSize.medium => (0.85, 2.5),
    MealSize.large => (0.75, 3.5),
  };
  return 1.0 - (1.0 - peak) * math.exp(-deltaHours / tau);
}

/// Across multiple meals, take the **min** modifier. No meals → 1.00.
double mealModifier(Iterable<({MealSize size, double deltaHours})> meals) {
  var modifier = 1.0;
  for (final m in meals) {
    final v = mealModifierSingle(size: m.size, deltaHours: m.deltaHours);
    if (v < modifier) modifier = v;
  }
  return modifier;
}

/// Step 3 — initial BAC via the Watson path (height available), g/L.
///
/// `(alcohol_grams × 0.806) / TBW_L × meal_modifier`
double bacInitialWatson({
  required double alcoholGrams,
  required double tbwLitres,
  double mealModifier = 1.0,
}) =>
    (alcoholGrams * bloodWaterFraction) / tbwLitres * mealModifier;

/// Step 3 — initial BAC via the Widmark fallback (height missing), g/L.
///
/// `alcohol_grams / (weight_kg × r) × meal_modifier`
double bacInitialWidmark({
  required double alcoholGrams,
  required double weightKg,
  required double r,
  double mealModifier = 1.0,
}) =>
    alcoholGrams / (weightKg * r) * mealModifier;

/// Steps 4–5 — zero-order elimination from one drink.
///
/// `BAC(t) = max(0, BAC_initial − β × hoursSince)`
double bacAtTime({required double bacInitial, required double hoursSince}) =>
    math.max(0.0, bacInitial - eliminationBetaGPerLPerHour * hoursSince);

/// Step 6 — g/L → mmol/L (display-only).
double gPerLToMmol(double gPerL) => gPerL * gPerLToMmolPerL;

/// Step 2/3 combined — picks Watson (height available) or Widmark (height
/// missing) and returns that drink's initial BAC, g/L. Model choice is
/// data-driven, never user-selectable (party-session.md §BAC estimation
/// algorithm Step 2: "the app picks the most accurate option the available
/// data supports").
double bacInitialForDrink({
  required double alcoholGrams,
  required Gender gender,
  required int ageYears,
  double? heightCm,
  required double weightKg,
  double mealModifier = 1.0,
}) {
  if (heightCm != null) {
    final tbw = watsonTbwLitres(
      gender: gender,
      ageYears: ageYears,
      heightCm: heightCm,
      weightKg: weightKg,
    );
    return bacInitialWatson(
      alcoholGrams: alcoholGrams,
      tbwLitres: tbw,
      mealModifier: mealModifier,
    );
  }
  return bacInitialWidmark(
    alcoholGrams: alcoholGrams,
    weightKg: weightKg,
    r: widmarkR(gender),
    mealModifier: mealModifier,
  );
}

/// Body-mass index, kg/m² — feeds the Watson-path BMI-range warning.
double bmi({required double weightKg, required double heightCm}) {
  final heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}

/// Watson-path BMI-range warning (party-session.md §BAC estimation algorithm
/// Step 2; Parity Rulebook note): warn if `BMI < 17` (any gender), `BMI > 67`
/// for `male`, or `BMI > 80` for `female`/`unspecified` (unspecified follows
/// the conservative path). Informational only — the estimate still displays
/// when this returns true. Only meaningful on the Watson path; callers on the
/// Widmark fallback (no height, so no BMI) should never call this.
bool bmiWarningApplies({required double bmi, required Gender gender}) {
  if (bmi < 17) return true;
  return switch (gender) {
    Gender.male => bmi > 67,
    Gender.female || Gender.unspecified => bmi > 80,
  };
}

/// party-session.md §BAC goal / Parity Rulebook (design-system.md
/// "Approaching-cap trigger"): the "approaching cap" trigger fires once the
/// estimated BAC reaches **80%** of the personal cap. The boundary is
/// inclusive (`>=`, not `>`) — reaching the threshold counts as approaching
/// it, matching the app's conservative-estimate posture elsewhere (e.g. the
/// unspecified-gender path). Pinned explicitly here and in the Rulebook
/// rather than left implicit, since "past 80%" alone is ambiguous.
bool isApproachingCap({required double bacGPerL, required double capGPerL}) =>
    bacGPerL >= 0.8 * capGPerL;
