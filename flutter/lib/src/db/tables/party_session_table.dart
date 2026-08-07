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

  /// Optional, user-set freeform label (e.g. "Sarah's birthday"). Normalised
  /// via `normalizePartySessionName` (Parity Rulebook → "PartySession name")
  /// before storage — never the raw user input.
  TextColumn get name => text().nullable()();

  /// Schema v9 addition. Copied from `UserPreferences.drinkConsumeMinutes`
  /// when the session starts; mirrors the global value live while the
  /// session is active (`endedAt IS NULL`), and is frozen at whatever value
  /// was in effect the instant `endedAt` is set — data-model.md §PartySession,
  /// party-session.md §Drink consumption time. `.withDefault(20)` (rather
  /// than a bare non-nullable column) exists only so the migration can
  /// backfill pre-existing session rows with a value — those already-ended
  /// historical sessions never recompute their BAC display, so inheriting
  /// the current global default of 20 is an acceptable one-time
  /// approximation (same "frozen history" principle as the rest of this
  /// schema); every row written from here on always sets this explicitly.
  IntColumn get drinkConsumeMinutes =>
      integer().withDefault(const Constant(20))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
