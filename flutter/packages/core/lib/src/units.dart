import 'dart:math' as math;

/// Unit conversion helpers — display boundary only.
///
/// Source: Parity Rulebook → "Volume conversion", "Mass conversion",
/// "Height conversion", "Imperial display", "Storage unit".
/// All storage is metric; these helpers convert **to/from imperial for display
/// only**. Algorithms (BAC, hydration, pace) never call these functions.
///
/// Rounding (from Parity Rulebook):
///   - Volume:  fl oz to **1 decimal place** (round half away from zero).
///              ml   to the **nearest integer** ml.
///   - Mass:    lb   to **1 decimal place** (round half away from zero).
///              kg   to **3 decimal places** (sub-gram accuracy for storage).
///   - Height:  total inches rounded to the **nearest inch**, then split into
///              feet and remaining inches. cm to **1 decimal place**.
///
/// Conversion factors (from Parity Rulebook):
///   - Volume:  1 US fl oz = 29.5735295625 ml (NIST).
///              US fl oz is used throughout (not UK imperial fl oz = 28.4130625 ml).
///   - Mass:    1 kg = 2.20462262185 lb (international avoirdupois pound).
///   - Height:  1 inch = 2.54 cm exactly (international definition).

// ---------------------------------------------------------------------------
// Volume
// ---------------------------------------------------------------------------

/// Millilitres per US fluid ounce (NIST).
const double _mlPerUsFlOz = 29.5735295625;

/// Convert millilitres to US fluid ounces, rounded to 1 decimal place.
double mlToFlOz(double ml) => _round1dp(ml / _mlPerUsFlOz);

/// Convert US fluid ounces to millilitres, rounded to the nearest millilitre.
double flOzToMl(double flOz) => (flOz * _mlPerUsFlOz).roundToDouble();

// ---------------------------------------------------------------------------
// Mass
// ---------------------------------------------------------------------------

/// Pounds per kilogram (international avoirdupois pound).
const double _lbPerKg = 2.20462262185;

/// Convert kilograms to pounds, rounded to 1 decimal place.
double kgToLb(double kg) => _round1dp(kg * _lbPerKg);

/// Convert pounds to kilograms, rounded to 3 decimal places (sub-gram accuracy).
double lbToKg(double lb) => _round3dp(lb / _lbPerKg);

// ---------------------------------------------------------------------------
// Height
// ---------------------------------------------------------------------------

/// Centimetres per inch (exact international definition).
const double _cmPerInch = 2.54;

/// Convert centimetres to `(feet, inches)` tuple.
///
/// Total inches are rounded to the nearest inch **before** splitting into
/// feet and remaining inches, so the result is always whole numbers.
/// e.g. 180 cm → 70.87 in → 71 in → (5 ft, 11 in).
({int feet, int inches}) cmToFtIn(double cm) {
  final totalInches = (cm / _cmPerInch).round();
  return (feet: totalInches ~/ 12, inches: totalInches % 12);
}

/// Convert feet + inches to centimetres, rounded to 1 decimal place.
double ftInToCm(int feet, int inches) {
  final totalInches = feet * 12 + inches;
  return _round1dp(totalInches * _cmPerInch);
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

double _round1dp(double value) => (value * 10).round() / 10;

double _round3dp(double value) {
  final factor = math.pow(10, 3);
  return (value * factor).round() / factor;
}
