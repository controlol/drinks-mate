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
      expect(ok('Green tea'), isFalse); // non-breaking space
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
  });
}
