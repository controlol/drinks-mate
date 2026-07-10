// Tests for `SessionPricingTotals.fromEntries` — the Party Session pricing
// aggregation used by the totals strip (party-session.md §Aggregations
// across mixed payment).
//
// Every expected value traces to:
//  - engineering/decisions/design-system.md → Appendix, "Money storage" /
//    "No FX conversion" rows: currencies are never summed together, only
//    grouped.
//  - design/party-session.md §Aggregations across mixed payment: "Spent:
//    €18.50 (sum of money-paid drinks, grouped by currency)", "Tokens used: 7
//    (sum of token-paid drinks)", "Token value: ≈ €10.50 (only shown if
//    tokenValueMinor is set...)".
//  - design/data-model.md §DrinkEntry `tokenValueMinor`: the money-equivalent
//    is computed from each entry's own snapshot, not the session's live
//    token config, so historical totals stay correct if that config changes
//    later.

import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/services/session_pricing_totals.dart';

/// Builds a minimal alcoholic [DrinkEntry] with only the pricing fields under
/// test varied; the rest are arbitrary-but-valid fixture values.
DrinkEntry _entry({
  String id = 'entry',
  int? priceMinor,
  String? currency,
  int? priceTokens,
  int? tokenValueMinor,
  String? tokenValueCurrency,
}) {
  final now = DateTime.utc(2026, 7, 10, 20, 0);
  return DrinkEntry(
    id: id,
    beverageType: BeverageType.beer,
    volumeMl: 330,
    priceMinor: priceMinor,
    currency: currency,
    priceTokens: priceTokens,
    tokenValueMinor: tokenValueMinor,
    tokenValueCurrency: tokenValueCurrency,
    consumedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('SessionPricingTotals.fromEntries — moneyByCurrency', () {
    test(
      'groups money-paid entries by currency instead of summing across '
      'currencies (Parity Rulebook §No FX conversion)',
      () {
        // Source: issue #23 worked example — EUR 300 + EUR 550 + USD 300
        // must produce {'EUR': 850, 'USD': 300}, NOT a combined scalar and
        // NOT {'EUR': 1150}.
        final totals = SessionPricingTotals.fromEntries([
          _entry(id: 'e1', priceMinor: 300, currency: 'EUR'),
          _entry(id: 'e2', priceMinor: 550, currency: 'EUR'),
          _entry(id: 'e3', priceMinor: 300, currency: 'USD'),
        ]);

        expect(totals.moneyByCurrency, {'EUR': 850, 'USD': 300});
      },
    );

    test(
      'excludes entries missing either priceMinor or currency (both must '
      'be set to count as a money-paid drink — data-model.md §DrinkEntry)',
      () {
        final totals = SessionPricingTotals.fromEntries([
          _entry(id: 'no-currency', priceMinor: 300),
          _entry(id: 'no-price', currency: 'EUR'),
          _entry(id: 'neither'),
        ]);

        expect(totals.moneyByCurrency, isEmpty);
      },
    );
  });

  group('SessionPricingTotals.fromEntries — tokensSpent', () {
    test(
      'sums priceTokens across entries, treating null (money-paid or '
      'unpriced) drinks as 0 (party-session.md: "Tokens used: 7 (sum of '
      'token-paid drinks)")',
      () {
        final totals = SessionPricingTotals.fromEntries([
          _entry(id: 't1', priceTokens: 2),
          _entry(id: 'money', priceMinor: 300, currency: 'EUR'),
          _entry(id: 't2', priceTokens: 5),
        ]);

        expect(totals.tokensSpent, 7);
      },
    );
  });

  group('SessionPricingTotals.fromEntries — tokenValueByCurrency', () {
    test(
      'sums priceTokens * tokenValueMinor grouped by tokenValueCurrency, '
      'using each entry\'s own snapshot fields (party-session.md: "Token '
      'value: ≈ €10.50"; data-model.md §DrinkEntry tokenValueMinor note)',
      () {
        final totals = SessionPricingTotals.fromEntries([
          _entry(
            id: 't1',
            priceTokens: 2,
            tokenValueMinor: 150,
            tokenValueCurrency: 'EUR',
          ),
          _entry(
            id: 't2',
            priceTokens: 3,
            tokenValueMinor: 150,
            tokenValueCurrency: 'EUR',
          ),
          _entry(
            id: 't3',
            priceTokens: 1,
            tokenValueMinor: 500,
            tokenValueCurrency: 'USD',
          ),
        ]);

        // EUR: 2*150 + 3*150 = 750. USD: 1*500 = 500. Grouped, not summed.
        expect(totals.tokenValueByCurrency, {'EUR': 750, 'USD': 500});
        expect(totals.tokensSpent, 6);
      },
    );

    test(
      'a token-paid entry with no tokenValueMinor/tokenValueCurrency counts '
      'toward tokensSpent but contributes nothing to tokenValueByCurrency '
      '(the token value snapshot is optional per drink)',
      () {
        final totals = SessionPricingTotals.fromEntries([
          _entry(id: 'no-value', priceTokens: 4),
        ]);

        expect(totals.tokensSpent, 4);
        expect(totals.tokenValueByCurrency, isEmpty);
      },
    );
  });

  group('SessionPricingTotals.fromEntries — empty input', () {
    test('an empty entry list yields all-empty/zero totals', () {
      final totals = SessionPricingTotals.fromEntries(const []);

      expect(totals.moneyByCurrency, isEmpty);
      expect(totals.tokensSpent, 0);
      expect(totals.tokenValueByCurrency, isEmpty);
    });
  });
}
