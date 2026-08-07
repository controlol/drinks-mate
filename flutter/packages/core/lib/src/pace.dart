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
  final elapsed = math.max(0, math.min(activeWindowMin, elapsedActiveMin));
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

/// Full per-reminder recommended-volume formula.
///
/// Ties together [expectedIntakeMl] and [recommendedVolumeGlasses]:
/// `deficit_ml = expected_intake_ml − actual_intake_ml`,
/// `glasses_raw = deficit_ml / default_drink_volume_ml`.
///
/// Source: notifications.md §Recommended volume per reminder.
double recommendedReminderVolumeGlasses({
  required double goalMl,
  required DateTime activeStart,
  required DateTime activeEnd,
  required DateTime now,
  required double actualIntakeMl,
  required double defaultDrinkVolumeMl,
}) {
  assert(defaultDrinkVolumeMl > 0, 'default drink volume must be positive');
  final activeWindowMin = activeEnd.difference(activeStart).inMinutes;
  final elapsedActiveMin = now.difference(activeStart).inMinutes;
  final expectedMl = expectedIntakeMl(
    goalMl: goalMl,
    elapsedActiveMin: elapsedActiveMin,
    activeWindowMin: activeWindowMin,
  );
  final deficitMl = expectedMl - actualIntakeMl;
  final glassesRaw = deficitMl / defaultDrinkVolumeMl;
  return recommendedVolumeGlasses(glassesRaw);
}

/// Renders a glasses value as the natural-language phrase used in reminder
/// copy. Does not include the beverage noun ("of water") — callers append it.
///
/// Source: Parity Rulebook → "Glass-count copy formatting"; notifications.md
/// §Glass formatting.
String formatGlassCount(double glasses) {
  return switch (glasses) {
    0.5 => 'half a glass',
    1.0 => 'a glass',
    2.0 => '2 glasses',
    _ => '$glasses glasses',
  };
}

/// Status-pill states for the Today progress card.
///
/// Source: designer-brief §S1; user-experience S1; Parity Rulebook
/// §Non-colour-signal rules.
///
/// Threshold: "Ahead" = daily goal already reached (intake ≥ goalMl).
/// "Behind" = below the linear-pace marker (intake < expectedMl).
/// "On pace" = at/above the marker but goal not yet reached.
/// (Threshold assumption flagged for maintainer confirmation in the PR.)
enum PaceStatus { behind, onPace, ahead }

/// Derives the status-pill state from current intake, pace expectation, and goal.
PaceStatus paceStatus({
  required double intakeMl,
  required double expectedMl,
  required double goalMl,
}) {
  assert(goalMl > 0, 'goal must be positive');
  if (intakeMl >= goalMl) return PaceStatus.ahead;
  if (intakeMl < expectedMl) return PaceStatus.behind;
  return PaceStatus.onPace;
}
