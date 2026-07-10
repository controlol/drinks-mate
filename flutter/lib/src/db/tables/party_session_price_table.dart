import 'package:drift/drift.dart';

/// Drift table for per-session, per-preset price overrides.
///
/// Schema v4 addition (issue #21). At most one live row per
/// `(partySessionId, drinkPresetId)` pair (enforced at the repository
/// layer). `priceMinor` and `priceTokens` are mutually exclusive per row —
/// the storage layer leaves both nullable; validation happens in
/// `PartySessionRepository` (data-model.md §PartySessionPrice).
///
/// [DataClassName] avoids a name collision with the pure-Dart domain model
/// [PartySessionPrice] in lib/src/models/party_session_price.dart.
@DataClassName('PartySessionPriceRow')
class PartySessionPrices extends Table {
  TextColumn get id => text()();
  TextColumn get partySessionId => text()();
  TextColumn get drinkPresetId => text()();

  /// Money price for this drink during this session, in minor units.
  IntColumn get priceMinor => integer().nullable()();

  /// 'EUR' | 'USD' | 'GBP'. Required when [priceMinor] is set.
  TextColumn get currency => text().nullable()();

  /// Token cost for this drink during this session.
  IntColumn get priceTokens => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
