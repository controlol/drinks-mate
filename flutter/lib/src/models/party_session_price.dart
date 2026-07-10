/// Pure-Dart domain model for a per-session, per-preset price override — no
/// Drift types (D2).
///
/// data-model.md §PartySessionPrice. [priceMinor] and [priceTokens] are
/// mutually exclusive (validated by `PartySessionRepository`, not enforced
/// by storage).
class PartySessionPrice {
  const PartySessionPrice({
    required this.id,
    required this.partySessionId,
    required this.drinkPresetId,
    this.priceMinor,
    this.currency,
    this.priceTokens,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String partySessionId;
  final String drinkPresetId;

  /// Money price for this drink during this session, in minor units.
  /// Mutually exclusive with [priceTokens].
  final int? priceMinor;

  /// 'EUR' | 'USD' | 'GBP'. Required when [priceMinor] is set.
  final String? currency;

  /// Token cost for this drink during this session.
  final int? priceTokens;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Soft-delete marker; null means the record is live.
  final DateTime? deletedAt;
}
