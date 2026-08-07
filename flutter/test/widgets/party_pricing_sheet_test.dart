// Widget tests for PartyPricingSheet's token-name validation (issue #23).
//
// Regression coverage for a defect caught during spec-audit review: the
// sheet used to pop an unvalidated tokenName straight into
// PartySessionRepository.updateTokenConfig(), which throws ArgumentError
// for any name that fails validateUsername() (Parity Rulebook — tokenName
// shares the username whitelist, 1-30 chars, no spaces). A user typing a
// natural two-word name (e.g. the design docs' own "Drink ticket" example)
// would hit an unhandled exception. The sheet now validates inline before
// popping, mirroring _BirthdateDialog's pattern in party_screen.dart.

import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/screens/party_pricing_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _preset = DrinkPreset(
  id: 'p1',
  name: 'Test Beer',
  beverageType: BeverageType.beer,
  volumeMl: 330,
  abvPercent: 5.0,
  iconKey: 'beer_glass',
  iconColor: '#d97706',
  isUserCreated: false,
  isHidden: false,
  sortOrder: 1,
);

/// Pumps a screen with a button that opens [PartyPricingSheet] as a modal
/// bottom sheet, taps it, and returns the (still-pending) Future for the
/// sheet's result — callers await the setup, interact with the open sheet,
/// then await the returned future once the sheet is expected to pop.
Future<Future<PricingSetupResult?>> _openSheet(WidgetTester tester) async {
  late Future<PricingSetupResult?> resultFuture;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              resultFuture = showModalBottomSheet<PricingSetupResult>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const PartyPricingSheet(
                  presets: [_preset],
                  existingOverrides: [],
                  defaultCurrency: 'EUR',
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return resultFuture;
}

void main() {
  testWidgets(
    'a two-word token name (e.g. "Drink ticket") shows an inline error '
    'instead of throwing an unhandled ArgumentError',
    (tester) async {
      await _openSheet(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Token'),
        'Drink ticket',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // No exception propagated (the test framework would fail this test
      // if updateTokenConfig's ArgumentError had leaked through), and the
      // sheet stays open (didn't pop) with an inline validation error.
      expect(find.text('Party prices'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    },
  );

  testWidgets(
    'a valid single-word token name pops the sheet with the normalised '
    'name in the result',
    (tester) async {
      final resultFuture = await _openSheet(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Token'), 'Munt');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final result = await resultFuture;
      expect(result, isNotNull);
      expect(result!.tokenName, 'Munt');
    },
  );
}
