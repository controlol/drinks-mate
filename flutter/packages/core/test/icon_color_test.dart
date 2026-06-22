import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('tintIconColor (Parity Rulebook — Two-shade icon tint)', () {
    // Achromatic test vectors — computed analytically:
    //   #000000: L=0%  → lighten +15 → L=15%  → v=round(0.15*255)=38=0x26
    //   #ffffff: L=100% → darken -15 → L=85%  → v=round(0.85*255)=217=0xd9
    //   #808080: L=50.2% → darken -15 → L=35.2% → v=round(0.352*255)=90=0x5a
    //   #7f7f7f: L=49.8% → lighten +15 → L=64.8% → v=round(0.648*255)=165=0xa5

    test('black (#000000) L=0% lightens to L=15% → #262626', () {
      expect(tintIconColor('#000000'), '#262626');
    });

    test('white (#ffffff) L=100% darkens to L=85% → #d9d9d9', () {
      expect(tintIconColor('#ffffff'), '#d9d9d9');
    });

    test('mid-gray (#808080) L=50.2% darkens to L=35.2% → #5a5a5a', () {
      expect(tintIconColor('#808080'), '#5a5a5a');
    });

    test('near-mid-gray (#7f7f7f) L=49.8% lightens to L=64.8% → #a5a5a5', () {
      expect(tintIconColor('#7f7f7f'), '#a5a5a5');
    });

    test('output is always 7-character lowercase hex (#rrggbb)', () {
      for (final hex in [
        '#000000',
        '#ffffff',
        '#3b82f6',
        '#92400e',
        '#808080',
      ]) {
        expect(
          tintIconColor(hex),
          matches(r'^#[0-9a-f]{6}$'),
          reason: 'input: $hex',
        );
      }
    });

    test('tinted colour differs from input (offset always applied)', () {
      // L=0 and L=100 are edge cases that produce a different colour.
      // All other inputs also differ because the ±15 offset is non-zero.
      for (final hex in [
        '#000000',
        '#ffffff',
        '#3b82f6',
        '#92400e',
        '#808080',
      ]) {
        expect(tintIconColor(hex), isNot(hex), reason: 'input: $hex');
      }
    });

    test(
      'chromatic blue (#3b82f6) L≈60% darkens — output parses without error',
      () {
        expect(() => tintIconColor('#3b82f6'), returnsNormally);
      },
    );

    test(
      'chromatic dark-brown (#92400e) L≈31% lightens — output parses without error',
      () {
        expect(() => tintIconColor('#92400e'), returnsNormally);
      },
    );

    group('error handling', () {
      test('wrong length throws ArgumentError', () {
        expect(() => tintIconColor('#ffff'), throwsArgumentError);
        expect(() => tintIconColor('#ffffffff'), throwsArgumentError);
      });

      test('invalid hex digits throw ArgumentError', () {
        expect(() => tintIconColor('#gg0000'), throwsArgumentError);
      });

      test('empty string throws ArgumentError', () {
        expect(() => tintIconColor(''), throwsArgumentError);
      });
    });
  });
}
