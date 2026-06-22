import 'package:flutter/material.dart';

// Design-system token placeholders (see engineering/decisions/design-system.md).
// Exact hex values are pending the designer's first pass (noted as open design
// questions in designer-brief.md). These seeds produce a Material 3 scheme
// from the named accents; final values land when the designer delivers tokens.

/// Primary brand colour — azure / sky (hydration identity, progress bar fill).
const Color kColorAzure = Color(0xFF4A90D9);

/// Action accent — honey / amber (CTAs, goal-met celebration).
const Color kColorHoney = Color(0xFFF5A623);

// Note: emerald / mint is the Party-Mode-only accent (C5 quarantine rule) and
// is intentionally absent here. It lives in a Party-specific token namespace.

/// Builds the Material 3 [ThemeData] (light + dark) from design-system tokens.
abstract final class AppTheme {
  AppTheme._();

  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: kColorAzure,
      secondary: kColorHoney,
      brightness: brightness,
    );
    // DM Sans is specified in D2 (engineering/decisions/flutter-stack.md).
    // Font asset files are not bundled yet; this name reference silently falls
    // back to the system font until the OFL-1.1 variable-font asset is added.
    // Do NOT use google_fonts here — runtime fetching violates C0 offline-first.
    const fontFamily = 'DM Sans';
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );
  }
}
