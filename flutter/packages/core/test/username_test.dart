import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('validateUsername (Parity Rulebook — Username rules)', () {
    bool ok(String s) => validateUsername(s).isValid;

    test('accepts simple valid names', () {
      expect(ok('luc'), isTrue);
      expect(ok('luc.appelman'), isTrue);
      expect(ok('a_b-c.d'), isTrue);
      expect(ok('Аня'), isTrue); // Unicode (Cyrillic) letters allowed
      expect(ok('user123'), isTrue);
    });

    test('length: rejects < 3 and > 30', () {
      expect(ok('ab'), isFalse);
      expect(ok('a' * 31), isFalse);
      expect(ok('a' * 30), isTrue);
      expect(ok('abc'), isTrue);
    });

    test('structure: must start and end with a letter or digit', () {
      expect(ok('_luc'), isFalse);
      expect(ok('luc_'), isFalse);
      expect(ok('.luc'), isFalse);
      expect(ok('-luc'), isFalse);
      expect(ok('luc.'), isFalse);
    });

    test('rejects whitespace', () {
      expect(ok('luc appelman'), isFalse);
      expect(ok('luc\tappelman'), isFalse);
    });

    test('rejects emoji and symbols', () {
      expect(ok('luc😀'), isFalse);
      expect(ok('luc\$money'), isFalse);
    });

    test('custom bounds support tokenName (1–30)', () {
      expect(validateUsername('x', minLength: 1).isValid, isTrue);
    });

    test('NFC normalisation: NFD input is accepted after normalisation', () {
      // 'café' is NFD for 'café' (e=U+0065, combining acute=U+0301).
      // After NFC this becomes 'café' (4 NFC code points) — a valid 4-char
      // username. Source: Parity Rulebook §Username length ("3–30 characters
      // after NFC normalisation") and §Username normalisation ("validate
      // against the normalised form").
      expect(ok('café'), isTrue);

      // 29 ASCII letters + NFD 'é' (2 runes) = 31 runes raw
      // → 30 NFC code points after normalisation → at max boundary (allowed).
      // Source: Parity Rulebook §Username length (max 30 measured after NFC).
      expect(ok('a' * 29 + 'é'), isTrue);

      // 30 ASCII letters + NFD 'é' (2 runes) = 32 runes raw
      // → 31 NFC code points after normalisation → too long (> 30 max).
      // Source: Parity Rulebook §Username length (max 30 measured after NFC).
      expect(ok('a' * 30 + 'é'), isFalse);
    });

    test('NFC normalisation: ASCII-only input is unchanged', () {
      // NFC(ASCII) == ASCII; existing behaviour must be preserved.
      // Source: Parity Rulebook §Username normalisation.
      expect(ok('luc'), isTrue);
      expect(ok('user123'), isTrue);
      expect(ok('ab'), isFalse); // < minLength
    });
  });

  group('validatePresetName (Parity Rulebook — DrinkPreset name rule)', () {
    bool ok(String s) => validatePresetName(s).isValid;

    test('accepts F14 seeded default names (multi-word with spaces)', () {
      expect(ok('Glass of water'), isTrue);
      expect(ok('Cup of coffee'), isTrue);
      expect(ok('Green tea'), isTrue);
    });

    test('accepts single-word names', () {
      expect(ok('Water'), isTrue);
      expect(ok('Juice'), isTrue);
      expect(ok('abc'), isTrue);
    });

    test('length: rejects < 3 and > 30', () {
      expect(ok('ab'), isFalse);
      expect(ok('a' * 31), isFalse);
      expect(ok('a' * 30), isTrue);
      expect(ok('abc'), isTrue);
    });

    test('structure: must start and end with a letter or digit', () {
      expect(ok(' Water'), isFalse); // leading space
      expect(ok('Water '), isFalse); // trailing space
      expect(ok('_Water'), isFalse);
      expect(ok('Water_'), isFalse);
    });

    test('rejects tabs, newlines, and non-ASCII whitespace', () {
      expect(ok('Green\ttea'), isFalse);
      expect(ok('Green\ntea'), isFalse);
      expect(ok('Green tea'), isFalse); // non-breaking space (U+00A0)
    });

    test('rejects emoji and symbols', () {
      expect(ok('Water😀'), isFalse);
      expect(ok('Water\$'), isFalse);
    });

    test('connectors _ - . still allowed', () {
      expect(ok('my_drink'), isTrue);
      expect(ok('my-drink'), isTrue);
      expect(ok('my.drink'), isTrue);
    });

    test('Unicode letters allowed', () {
      expect(ok('Café latte'), isTrue); // é is \p{L}
    });

    test('NFC normalisation: NFD input accepted after normalisation', () {
      // 'Café latte' is NFD for 'Café latte' (e=U+0065, combining
      // acute=U+0301). After NFC this becomes 'Café latte' — a valid preset
      // name (10 NFC code points including the space).
      // Source: Parity Rulebook §DrinkPreset name (3–30 chars, Unicode letters
      // L* allowed). NFC normalisation is applied by validatePresetName() per
      // the same §Username normalisation rule applied consistently.
      expect(ok('Café latte'), isTrue);
    });

    test('NFC normalisation: ASCII-only input is unchanged', () {
      // NFC(ASCII) == ASCII; existing behaviour must be preserved.
      // Source: Parity Rulebook §DrinkPreset name.
      expect(ok('Glass of water'), isTrue);
      expect(ok('ab'), isFalse);
    });
  });
}
