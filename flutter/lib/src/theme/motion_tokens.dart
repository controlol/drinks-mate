import 'package:flutter/animation.dart';

// Motion / animation tokens — designer-brief §Motion & feedback, C5.
//
// Motion personality: smooth ease-in-out, NO bounce, NO overshoot.
// Every animated element must respect [ReduceMotion.isEnabled] and fall back
// to a static/instant variant.
abstract final class MotionTokens {
  MotionTokens._();

  // -------------------------------------------------------------------------
  // Named durations
  // -------------------------------------------------------------------------

  /// Quick micro-interaction (e.g. button press feedback).
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transition (e.g. progress bar fill, card swap).
  static const Duration standard = Duration(milliseconds: 300);

  /// Leisurely emphasis animation (e.g. goal-met celebration entry).
  static const Duration slow = Duration(milliseconds: 450);

  /// "Logged" toast visible duration — 4 s per spec (designer-brief §Log feedback).
  static const Duration toastVisible = Duration(seconds: 4);

  // Convenience aliases for named animation moments.

  /// Duration for the log-feedback progress bar fill animation.
  static const Duration progressBarFill = standard;

  // -------------------------------------------------------------------------
  // Easing
  // -------------------------------------------------------------------------

  /// Smooth ease-in-out — the only easing used in Drinks Mate.
  /// No bounce; no overshoot; maps to iOS standard curve and Material easing.
  static const Curve easing = Curves.easeInOut;
}
