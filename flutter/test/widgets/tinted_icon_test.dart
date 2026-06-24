import 'dart:convert';

import 'package:core/core.dart';
import 'package:drinks_mate/src/utils/color_utils.dart';
import 'package:drinks_mate/src/widgets/tinted_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Minimal SVG using the two sentinel fill values so TintedIcon has real markup
// to parse. Sentinel hex values come from tinted_icon.dart constants.
const _kTestSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#000001" d="M12 2C6.477 2 2 6.477 2 12s4.477 10 10 10 10-4.477 10-10S17.523 2 12 2z"/>
  <path fill="#000002" d="M12 7a5 5 0 1 0 0 10A5 5 0 0 0 12 7z"/>
</svg>
''';

// Known colour used for parity tests. #3b82f6 chosen because it has L < 50 in
// HSL (≈ 0.52 lightness fraction → 52% → actually > 50; see worked check below)
// but the tests derive expected values from tintIconColor itself — no literal
// is frozen here. The requirement is delegation, not a specific numeric output.
// Source: issue acceptance criterion "compared against core's tintIconColor".
const _kKnownHex = '#3b82f6';

void main() {
  group('DrinkIconColorMapper.substitute', () {
    test('silhouette sentinel maps to parseIconColor(iconColor)', () {
      // Source: tinted_icon.dart — silhouette = parseIconColor(iconColor).
      final color = parseIconColor(_kKnownHex)!;
      final mapper = DrinkIconColorMapper(
        silhouette: color,
        detail: parseIconColorTint(_kKnownHex)!,
      );

      expect(
        mapper.substitute(null, 'path', 'fill', kSilhouettePlaceholder),
        color,
      );
    });

    test('detail sentinel maps to parseIconColorTint(iconColor)', () {
      // Source: tinted_icon.dart — detail = parseIconColorTint(iconColor).
      final detail = parseIconColorTint(_kKnownHex)!;
      final mapper = DrinkIconColorMapper(
        silhouette: parseIconColor(_kKnownHex)!,
        detail: detail,
      );

      expect(
        mapper.substitute(null, 'path', 'fill', kDetailPlaceholder),
        detail,
      );
    });

    test('detail color matches core tintIconColor output for known hex', () {
      // Acceptance criterion: widget test compares output against core's
      // tintIconColor for a known colour value.
      // Source: design-system.md Parity Rulebook §Two-shade icon tint;
      // parseIconColorTint delegates to tintIconColor without re-implementing
      // the HSL maths.
      final expectedDetailHex = tintIconColor(_kKnownHex);
      final expectedDetailColor = parseIconColor(expectedDetailHex)!;

      final mapper = DrinkIconColorMapper(
        silhouette: parseIconColor(_kKnownHex)!,
        detail: parseIconColorTint(_kKnownHex)!,
      );

      expect(
        mapper.substitute(null, 'path', 'fill', kDetailPlaceholder),
        expectedDetailColor,
      );
    });

    test('non-sentinel color passes through unchanged', () {
      // The mapper must be transparent for all colours that are not sentinel
      // placeholders. Source: tinted_icon.dart — `return color` branch.
      const arbitrary = Color(0xFFABCDEF);
      final mapper = DrinkIconColorMapper(
        silhouette: parseIconColor(_kKnownHex)!,
        detail: parseIconColorTint(_kKnownHex)!,
      );

      expect(mapper.substitute(null, 'rect', 'stroke', arbitrary), arbitrary);
    });
  });

  group('DrinkIconColorMapper equality', () {
    test('two instances with the same colors are equal', () {
      final a = DrinkIconColorMapper(
        silhouette: parseIconColor(_kKnownHex)!,
        detail: parseIconColorTint(_kKnownHex)!,
      );
      final b = DrinkIconColorMapper(
        silhouette: parseIconColor(_kKnownHex)!,
        detail: parseIconColorTint(_kKnownHex)!,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('instances with different silhouette colors are not equal', () {
      final a = DrinkIconColorMapper(
        silhouette: parseIconColor(_kKnownHex)!,
        detail: parseIconColorTint(_kKnownHex)!,
      );
      final b = DrinkIconColorMapper(
        silhouette: const Color(0xFF000000),
        detail: parseIconColorTint(_kKnownHex)!,
      );

      expect(a, isNot(equals(b)));
    });

    test('instances with different detail colors are not equal', () {
      final a = DrinkIconColorMapper(
        silhouette: parseIconColor(_kKnownHex)!,
        detail: parseIconColorTint(_kKnownHex)!,
      );
      final b = DrinkIconColorMapper(
        silhouette: parseIconColor(_kKnownHex)!,
        detail: const Color(0xFF000000),
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('TintedIcon widget', () {
    testWidgets('builds without error using a fake asset bundle', (
      tester,
    ) async {
      // SvgAssetLoader calls DefaultAssetBundle.of(context).load(assetName)
      // when no explicit bundle is provided. We override DefaultAssetBundle
      // to intercept that call and return the test SVG without touching the
      // file system or the real asset manifest.
      // Source: flutter_svg loaders.dart SvgAssetLoader._resolveBundle.
      final fakeBundle = _FakeAssetBundle({
        'assets/icons/test.svg': utf8.encode(_kTestSvg).buffer.asByteData(),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: fakeBundle,
            child: const TintedIcon(
              assetPath: 'assets/icons/test.svg',
              iconColor: _kKnownHex,
              size: 24,
              semanticsLabel: 'test icon',
            ),
          ),
        ),
      );

      // Allow async SVG parsing to complete.
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TintedIcon), findsOneWidget);
    });
  });
}

class _FakeAssetBundle extends Fake implements AssetBundle {
  _FakeAssetBundle(this._assets);

  final Map<String, ByteData> _assets;

  @override
  Future<ByteData> load(String key) async {
    final data = _assets[key];
    if (data == null) throw FlutterError('Asset not found: $key');
    return data;
  }
}
