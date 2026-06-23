import 'package:flutter/services.dart';

// Haptic feedback levels — designer-brief §Motion & feedback, C5.
//
// Only two haptic moments exist:
//   - Light on every drink log (iOS impactLight / Android tick).
//   - Medium on goal-met celebration (iOS impactMedium / Android heavy click).
//
// No other haptics. Keeping haptic reserved for these two moments ensures
// it remains meaningful and not noise.
abstract final class HapticTokens {
  HapticTokens._();

  /// Fire when a drink is successfully logged.
  static Future<void> onLog() => HapticFeedback.lightImpact();

  /// Fire when the user first crosses their daily hydration goal.
  static Future<void> onGoalMet() => HapticFeedback.mediumImpact();
}
