import 'dart:math' as math;

/// Pace and recommended-volume.
///
/// Source: Parity Rulebook → "Expected intake / pace" and
/// "Recommended volume (glasses)".

/// Expected intake so far today, ml.
///
/// `elapsed_active_min = max(0, min(active_window_min, t_now − active_start))`
/// `expected_intake_ml = goal_ml × (elapsed_active_min / active_window_min)`
double expectedIntakeMl({
  required double goalMl,
  required int elapsedActiveMin,
  required int activeWindowMin,
}) {
  assert(activeWindowMin > 0, 'active window must be positive');
  final elapsed =
      math.max(0, math.min(activeWindowMin, elapsedActiveMin));
  return goalMl * (elapsed / activeWindowMin);
}

/// Recommended next volume in glasses.
///
/// `glasses_rounded = round(glasses_raw × 2) / 2` (nearest 0.5),
/// then `clamp(_, 0.5, 2.0)`. Minimum 0.5 even when on/ahead of pace.
double recommendedVolumeGlasses(double glassesRaw) {
  final rounded = (glassesRaw * 2).round() / 2;
  // num.clamp returns num; this domain is always double, so coerce back.
  return rounded.clamp(0.5, 2.0).toDouble();
}
