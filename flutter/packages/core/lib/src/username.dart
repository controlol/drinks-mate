/// Username / preset-name validation.
///
/// Source: Parity Rulebook → "Username *" rows (data-model.md §Username rules).
///
/// Rules implemented here:
///  - length 3–30 (after NFC normalisation — see TODO below),
///  - allowed chars: Unicode letters `\p{L}` + ASCII digits + connectors `_ - .`,
///  - must start AND end with a letter or digit,
///  - the whitelist inherently rejects whitespace, control/format/surrogate/
///    private-use/unassigned code points, emoji and symbols.
///
/// TODO(core): NFC normalisation must be applied before validation. Dart's core
/// library has no built-in NFC, and `core` is intentionally dependency-free, so
/// the caller (or a future small helper) must normalise first. Tracked as a
/// follow-up; the structural rules below are framework-independent and final.

class UsernameValidation {
  const UsernameValidation.valid()
      : isValid = true,
        error = null;
  const UsernameValidation.invalid(this.error) : isValid = false;

  final bool isValid;
  final String? error;
}

/// Whitelist + structure in one pass. `unicode: true` enables `\p{L}`.
/// The optional tail group permits a valid single-character name (e.g.
/// `tokenName` with `minLength: 1`) while still requiring the first and last
/// character to be a letter or digit for multi-character names.
final RegExp _usernamePattern = RegExp(
  r'^[\p{L}0-9]([\p{L}0-9_.\-]*[\p{L}0-9])?$',
  unicode: true,
);

/// Validates a username against the Parity Rulebook structural rules.
///
/// [minLength]/[maxLength] default to the username bounds (3–30); pass other
/// bounds for `DrinkPreset.name` (3–30) or `tokenName` (1–30).
UsernameValidation validateUsername(
  String input, {
  int minLength = 3,
  int maxLength = 30,
}) {
  // Count user-perceived characters, not UTF-16 code units.
  final length = input.runes.length;
  if (length < minLength || length > maxLength) {
    return UsernameValidation.invalid(
      'Must be $minLength–$maxLength characters.',
    );
  }
  if (!_usernamePattern.hasMatch(input)) {
    return const UsernameValidation.invalid(
      'Use letters, digits, and _ - . — must start and end with a letter or digit.',
    );
  }
  return const UsernameValidation.valid();
}
