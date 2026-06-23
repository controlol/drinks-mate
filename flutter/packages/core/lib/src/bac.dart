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
}) => (alcoholGrams * bloodWaterFraction) / tbwLitres * mealModifier;

/// Step 3 — initial BAC via the Widmark fallback (height missing), g/L.
///
/// `alcohol_grams / (weight_kg × r) × meal_modifier`
double bacInitialWidmark({
  required double alcoholGrams,
  required double weightKg,
  required double r,
  double mealModifier = 1.0,
}) => alcoholGrams / (weightKg * r) * mealModifier;

/// Steps 4–5 — zero-order elimination from one drink.
///
/// `BAC(t) = max(0, BAC_initial − β × hoursSince)`
double bacAtTime({required double bacInitial, required double hoursSince}) =>
    math.max(0.0, bacInitial - eliminationBetaGPerLPerHour * hoursSince);

/// Step 6 — g/L → mmol/L (display-only).
double gPerLToMmol(double gPerL) => gPerL * gPerLToMmolPerL;
