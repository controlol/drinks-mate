/// Username and DrinkPreset name validation.
///
/// Sources:
///  - Parity Rulebook → "Username *" rows (data-model.md §Username rules).
///  - Parity Rulebook → "DrinkPreset name" row (data-model.md §DrinkPreset).
///
/// [validateUsername] rules:
///  - length 3–30 (measured after NFC normalisation),
///  - allowed chars: Unicode letters `\p{L}` + ASCII digits + connectors `_ - .`,
///  - must start AND end with a letter or digit,
///  - whitespace, control/format/surrogate/private-use/unassigned, emoji and
///    symbols are all rejected by the whitelist.
///
/// [validatePresetName] rules (same as username except ASCII space is allowed):
///  - length 3–30,
///  - allowed chars: same as username **plus ASCII space**,
///  - must start AND end with a letter or digit (leading/trailing spaces rejected).
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

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

/// Returns the NFC canonical form of [s] for storage or comparison.
///
/// Apply this before persisting any value that was validated by
/// [validateUsername] or [validatePresetName], so visually identical inputs
/// produce the same stored bytes (data-model.md §Username rules).
String normalizeNfc(String s) => unorm.nfc(s);

/// Validates a username against the Parity Rulebook structural rules.
///
/// [minLength]/[maxLength] default to the username bounds (3–30); pass
/// `minLength: 1` for `tokenName` (1–30).
UsernameValidation validateUsername(
  String input, {
  int minLength = 3,
  int maxLength = 30,
}) {
  final normalized = unorm.nfc(input);
  // Count user-perceived characters, not UTF-16 code units.
  final length = normalized.runes.length;
  if (length < minLength || length > maxLength) {
    return UsernameValidation.invalid(
      'Must be $minLength–$maxLength characters.',
    );
  }
  if (!_usernamePattern.hasMatch(normalized)) {
    return const UsernameValidation.invalid(
      'Use letters, digits, and _ - . — must start and end with a letter or digit.',
    );
  }
  return const UsernameValidation.valid();
}

/// Like [_usernamePattern] but also permits ASCII space between words.
/// Leading/trailing spaces are rejected because the pattern requires the first
/// and last character to be a letter or digit.
final RegExp _presetNamePattern = RegExp(
  r'^[\p{L}0-9]([\p{L}0-9_.\- ]*[\p{L}0-9])?$',
  unicode: true,
);

/// Validates a [DrinkPreset] name against the Parity Rulebook rules.
///
/// Same structural rules as [validateUsername] except ASCII space is allowed
/// between words (e.g. "Glass of water" is valid).
UsernameValidation validatePresetName(String input) {
  final normalized = unorm.nfc(input);
  final length = normalized.runes.length;
  if (length < 3 || length > 30) {
    return const UsernameValidation.invalid('Must be 3–30 characters.');
  }
  if (!_presetNamePattern.hasMatch(normalized)) {
    return const UsernameValidation.invalid(
      'Use letters, digits, spaces, and _ - . — must start and end with a letter or digit.',
    );
  }
  return const UsernameValidation.valid();
}
