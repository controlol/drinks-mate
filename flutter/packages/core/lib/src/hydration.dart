/// Hydration goal.
///
/// Source: Parity Rulebook → "Hydration goal".
/// `dailyGoalMl = round_to_nearest(30 × weightKg, 100)`, round-half-up on the
/// ml value. 70 kg → 2100 ml; the .50 boundary 65 kg → 1950 → **2000**.
int dailyGoalMl(double weightKg) {
  final raw = 30 * weightKg;
  // Dart's .round() rounds half away from zero, which is round-half-up for the
  // non-negative weights this domain allows.
  return (raw / 100).round() * 100;
}
