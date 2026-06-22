import 'package:flutter/material.dart';

import 'color_tokens.dart';

export 'color_tokens.dart';

// Design-system token constants — see engineering/decisions/design-system.md.
// DM Sans (SIL OFL-1.1 variable font) is bundled in assets/fonts/ and declared
// under the 'fonts:' section of pubspec.yaml (D2).
const String _kFontFamily = 'DM Sans';

// Tabular figures force fixed-width digits on the headline numeric slots
// (intake value, BAC value) so they don't jitter on update (D2, C5).
const List<FontFeature> _kTabularFigures = [FontFeature.tabularFigures()];

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

    // Build the base ThemeData first so Flutter generates the M3 TextTheme
    // (sizes, weights, tracking) from the color scheme and fontFamily.
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _kFontFamily,
    );

    // Apply tabular figures to the display/headline slots used for the live
    // intake value and BAC display — digit widths must not shift on update (D2).
    final textTheme = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        fontFeatures: _kTabularFigures,
      ),
      displayMedium: base.textTheme.displayMedium?.copyWith(
        fontFeatures: _kTabularFigures,
      ),
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontFeatures: _kTabularFigures,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontFeatures: _kTabularFigures,
      ),
    );

    return base.copyWith(textTheme: textTheme);
  }
}
