import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../utils/color_utils.dart';

// Sentinel fill colours used as placeholders in every drink-icon SVG.
//
// When authoring or generating a drink-icon SVG, the silhouette (outer) path
// must use kSilhouettePlaceholder as its fill and the inner-detail path must
// use kDetailPlaceholder. Both are replaced at parse time with the
// runtime-tinted pair derived from the preset's [iconColor].
//
// The sentinel values are chosen outside the "human" sRGB palette (#000001 /
// #000002) so they are never produced accidentally by a design tool.

/// Fill placeholder for the silhouette (outer) path of a drink-icon SVG.
const Color kSilhouettePlaceholder = Color(0xFF000001);

/// Fill placeholder for the inner-detail path of a drink-icon SVG.
const Color kDetailPlaceholder = Color(0xFF000002);

/// [ColorMapper] that replaces the two sentinel fills at SVG parse time.
///
/// [silhouette] → replaces [kSilhouettePlaceholder]; equals `parseIconColor(iconColor)`.
/// [detail]     → replaces [kDetailPlaceholder];     equals `parseIconColorTint(iconColor)`.
///
/// The HSL ±15% offset maths lives entirely in `core` (via [parseIconColorTint]
/// → [tintIconColor]). This class never re-implements the offset.
@immutable
class DrinkIconColorMapper extends ColorMapper {
  const DrinkIconColorMapper({required this.silhouette, required this.detail});

  final Color silhouette;
  final Color detail;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color == kSilhouettePlaceholder) return silhouette;
    if (color == kDetailPlaceholder) return detail;
    return color;
  }

  @override
  bool operator ==(Object other) =>
      other is DrinkIconColorMapper &&
      other.silhouette == silhouette &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(silhouette, detail);
}

/// A widget that renders a drink-icon SVG with runtime two-shade tinting.
///
/// The SVG at [assetPath] must use [kSilhouettePlaceholder] (`#000001`) and
/// [kDetailPlaceholder] (`#000002`) as its two fill colours. Both are replaced
/// at parse time with the tinted pair derived from [iconColor].
///
/// Tint derivation:
///   silhouette = `parseIconColor(iconColor)` — the base colour verbatim.
///   inner detail = `parseIconColorTint(iconColor)` → delegates to core's
///     `tintIconColor` (HSL ±15% lightness offset, sRGB→HSL, clamped to
///     [0,100]) — Parity Rulebook §Two-shade icon tint.
///
/// Neither this widget nor [DrinkIconColorMapper] re-implement the HSL maths.
class TintedIcon extends StatelessWidget {
  const TintedIcon({
    super.key,
    required this.assetPath,
    required this.iconColor,
    this.size,
    this.semanticsLabel,
  });

  /// Asset path to the drink-icon SVG, e.g. `'assets/icons/glass.svg'`.
  final String assetPath;

  /// Six-digit hex colour string for the icon (with or without `#` prefix),
  /// e.g. `'#3b82f6'` or `'3b82f6'`. Parsed via [parseIconColor].
  final String iconColor;

  /// Width and height of the rendered icon in logical pixels.
  final double? size;

  /// VoiceOver/TalkBack label for this icon.
  ///
  /// Pass a non-null value to identify the icon to screen readers. Use
  /// [SemanticsLabels.drinkIconPrefix] + preset name as the convention.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final silhouette = parseIconColor(iconColor) ?? const Color(0xFF000000);
    final detail = parseIconColorTint(iconColor) ?? const Color(0xFF444444);

    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorMapper: DrinkIconColorMapper(silhouette: silhouette, detail: detail),
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: semanticsLabel == null,
    );
  }
}
