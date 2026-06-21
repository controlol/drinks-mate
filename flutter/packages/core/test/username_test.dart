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
}
