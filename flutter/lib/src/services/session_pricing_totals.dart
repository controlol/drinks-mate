import '../models/drink_entry.dart';

/// Running Party Session pricing totals, aggregated from live [DrinkEntry]
/// snapshots — never sums across currencies (Parity Rulebook §No FX
/// conversion; party-session.md §Aggregations across mixed payment).
class SessionPricingTotals {
  const SessionPricingTotals({
    required this.moneyByCurrency,
    required this.tokensSpent,
    required this.tokenValueByCurrency,
  });

  /// Money-paid drink totals, in minor units, keyed by currency code.
  /// e.g. `{'EUR': 550, 'USD': 300}` displays as "€5.50 | $3.00", never
  /// summed together.
  final Map<String, int> moneyByCurrency;

  /// Total tokens spent (the session's token unit).
  final int tokensSpent;

  /// Money-equivalent of token spend, in minor units, keyed by currency.
  /// Computed from each entry's *own* `tokenValueMinor`/`tokenValueCurrency`
  /// snapshot — not the session's current token config — so historical
  /// totals stay correct even if that config changes later (data-model.md
  /// §DrinkEntry: `tokenValueMinor` "lets historical totals show a
  /// money-equivalent... even if the session's token configuration changes
  /// later").
  final Map<String, int> tokenValueByCurrency;

  /// Aggregates [entries] (typically a session's live drink entries) into
  /// [SessionPricingTotals].
  factory SessionPricingTotals.fromEntries(Iterable<DrinkEntry> entries) {
    final money = <String, int>{};
    final tokenValue = <String, int>{};
    var tokens = 0;
    for (final e in entries) {
      if (e.priceMinor != null && e.currency != null) {
        money[e.currency!] = (money[e.currency!] ?? 0) + e.priceMinor!;
      }
      if (e.priceTokens != null) {
        tokens += e.priceTokens!;
        if (e.tokenValueMinor != null && e.tokenValueCurrency != null) {
          tokenValue[e.tokenValueCurrency!] =
              (tokenValue[e.tokenValueCurrency!] ?? 0) +
                  e.priceTokens! * e.tokenValueMinor!;
        }
      }
    }
    return SessionPricingTotals(
      moneyByCurrency: money,
      tokensSpent: tokens,
      tokenValueByCurrency: tokenValue,
    );
  }
}
