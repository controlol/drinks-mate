import 'package:flutter/widgets.dart';

// Reduce-motion guard — C5, designer-brief §Motion & feedback.
//
// Every animated element in the app must call [ReduceMotion.isEnabled] and
// substitute a static/instant fallback when true.
//
// Example:
//   final duration = ReduceMotion.isEnabled(context)
//       ? Duration.zero
//       : MotionTokens.progressBarFill;
abstract final class ReduceMotion {
  ReduceMotion._();

  /// Returns true when the OS reduce-motion accessibility setting is active.
  ///
  /// Uses [MediaQuery.disableAnimations], which maps to:
  ///   - iOS: Settings → Accessibility → Motion → Reduce Motion
  ///   - Android: Settings → Accessibility → Remove animations
  static bool isEnabled(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;
}
