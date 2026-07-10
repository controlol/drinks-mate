import 'package:drift/drift.dart';

/// Drift table for Party Sessions — a discrete drinking occasion.
///
/// Schema v4 addition (issue #21). At most one live row has `endedAt IS
/// NULL` at any time (enforced at the repository layer, not the schema).
/// `bacCapGramsPerL` deliberately does **not** live here — data-model.md
/// §UserPreferences: the cap is "a single persistent setting... not
/// per-session", already stored as `UserPreferences.bacCapGramsPerL`.
///
/// [DataClassName] avoids a name collision with the pure-Dart domain model
/// [PartySession] in lib/src/models/party_session.dart.
@DataClassName('PartySessionRow')
class PartySessions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// 'manual' | 'auto_timeout'. Null while active.
  TextColumn get endReason => text().nullable()();

  /// Whether to apply this session's [PartySessionPrices] overrides when
  /// logging drinks. Toggled live during the session.
  BoolColumn get useSessionPrices => boolean()();

  /// Display label for the session's tokens (e.g. "Token", "Munt"). Null
  /// when tokens are not used in this session.
  TextColumn get tokenName => text().nullable()();

  /// What one token is worth, in the minor unit of [tokenValueCurrency].
  IntColumn get tokenValueMinor => integer().nullable()();

  /// 'EUR' | 'USD' | 'GBP'. Required when [tokenValueMinor] is set.
  TextColumn get tokenValueCurrency => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
