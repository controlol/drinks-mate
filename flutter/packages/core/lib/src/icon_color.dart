/// Two-shade icon tint — Parity Rulebook §Two-shade icon tint.
///
/// Rule: silhouette = iconColor; inner detail = iconColor with HSL lightness
/// offset ±15%, computed in sRGB→HSL, lightness clamped to [0, 100], converted
/// back and hex-formatted lowercase. Lighten (+15) if base L < 50, else
/// darken (-15).
library;

/// Returns the inner-detail hex colour for the two-shade icon tint rule.
///
/// Input: 6-digit hex string, with or without `#` prefix (e.g. `#3b82f6`).
/// Output: `#rrggbb` lowercase.
/// Throws [ArgumentError] on malformed input.
String tintIconColor(String hex) {
  final rgb = _parseHex(hex);
  final hsl = _rgbToHsl(rgb[0], rgb[1], rgb[2]);
  final l = hsl[2];
  final newL = (l < 50.0 ? l + 15.0 : l - 15.0).clamp(0.0, 100.0);
  final rgb2 = _hslToRgb(hsl[0], hsl[1], newL);
  return '#${_byte(rgb2[0])}${_byte(rgb2[1])}${_byte(rgb2[2])}';
}

List<int> _parseHex(String hex) {
  final s = hex.startsWith('#') ? hex.substring(1) : hex;
  if (s.length != 6) throw ArgumentError('Expected 6-digit hex, got: $hex');
  try {
    final v = int.parse(s, radix: 16);
    return [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
  } catch (_) {
    throw ArgumentError('Expected 6-digit hex, got: $hex');
  }
}

/// Returns [H (0–360), S (0–100), L (0–100)].
List<double> _rgbToHsl(int r, int g, int b) {
  final rf = r / 255.0;
  final gf = g / 255.0;
  final bf = b / 255.0;
  final max = [rf, gf, bf].reduce((a, b) => a > b ? a : b);
  final min = [rf, gf, bf].reduce((a, b) => a < b ? a : b);
  final l = (max + min) / 2.0;
  if (max == min) return [0.0, 0.0, l * 100.0];
  final d = max - min;
  final s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min);
  double h;
  if (max == rf) {
    h = (gf - bf) / d + (gf < bf ? 6.0 : 0.0);
  } else if (max == gf) {
    h = (bf - rf) / d + 2.0;
  } else {
    h = (rf - gf) / d + 4.0;
  }
  return [h * 60.0, s * 100.0, l * 100.0];
}

/// H (0–360), S (0–100), L (0–100) → [R, G, B] ∈ [0, 255].
List<int> _hslToRgb(double h, double s, double l) {
  final sf = s / 100.0;
  final lf = l / 100.0;
  if (sf == 0.0) {
    final v = (lf * 255).round();
    return [v, v, v];
  }
  final q = lf < 0.5 ? lf * (1.0 + sf) : lf + sf - lf * sf;
  final p = 2.0 * lf - q;
  final hf = h / 360.0;
  return [
    (_hue(p, q, hf + 1.0 / 3.0) * 255).round(),
    (_hue(p, q, hf) * 255).round(),
    (_hue(p, q, hf - 1.0 / 3.0) * 255).round(),
  ];
}

double _hue(double p, double q, double t) {
  var tt = t;
  if (tt < 0) tt += 1.0;
  if (tt > 1) tt -= 1.0;
  if (tt < 1.0 / 6.0) return p + (q - p) * 6.0 * tt;
  if (tt < 0.5) return q;
  if (tt < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - tt) * 6.0;
  return p;
}

String _byte(int v) => v.toRadixString(16).padLeft(2, '0');
