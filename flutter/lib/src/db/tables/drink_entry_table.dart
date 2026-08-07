import 'package:drift/drift.dart';

/// Drift table for drink entries — a single logged drink.
///
/// Schema v2 addition; Party Session columns added in schema v4 (issue #21);
/// [presetId] added in schema v6 (issue #78). All preset values are
/// snapshotted at log time (log immutability — data-model.md §Snapshot
/// semantics); [presetId] is the one exception — see its own doc comment.
///
/// [DataClassName] avoids a name collision with the pure-Dart domain model
/// [DrinkEntry] in lib/src/models/drink_entry.dart.
@DataClassName('DrinkEntryRow')
class DrinkEntries extends Table {
  TextColumn get id => text()();

  /// Snapshot of preset name at log time. Null when logged without a preset.
  TextColumn get name => text().nullable()();

  /// Stored as canonical string — see [BeverageType.stored].
  TextColumn get beverageType => text()();
  IntColumn get volumeMl => integer()();
  RealColumn get abvPercent => real().nullable()();

  /// Snapshot of price in minor units at log time. Mutually exclusive with
  /// [priceTokens] (data-model.md §DrinkEntry).
  IntColumn get priceMinor => integer().nullable()();
  TextColumn get currency => text().nullable()();

  /// Snapshot of the token cost at log time, when paid for in tokens during
  /// a Party Session. Mutually exclusive with [priceMinor].
  IntColumn get priceTokens => integer().nullable()();

  /// Snapshot of the token-to-money value at log time, in the minor unit of
  /// [tokenValueCurrency]. Null when [priceTokens] is null.
  IntColumn get tokenValueMinor => integer().nullable()();

  /// Snapshot of the currency the token value was expressed in. Null when
  /// [priceTokens] is null.
  TextColumn get tokenValueCurrency => text().nullable()();
  TextColumn get iconKey => text().nullable()();
  TextColumn get iconColor => text().nullable()();

  /// FK to [PartySessions.id]. Null for non-alcoholic drinks and for
  /// alcoholic "orphan" drinks logged with no active session
  /// (data-model.md §Meal → Relationship to DrinkEntry).
  TextColumn get partySessionId => text().nullable()();

  /// Preset the entry was logged from, or null when logged without one.
  /// **Not** a foreign-key constraint (no `ON DELETE` behaviour) and never
  /// authoritative for display — those values are the snapshot columns
  /// above, per log immutability. This column exists solely to feed the
  /// preset-usage aggregation (last-used timestamp, trailing 30-day count)
  /// behind the Recently-used/Most-used sort modes (F14 §Sort modes); a
  /// deleted preset simply stops accumulating new usage, and its historical
  /// entries keep their id here with no cascading effect.
  TextColumn get presetId => text().nullable()();

  /// Schema v7 addition (issue #87). True when this entry's price snapshot
  /// was set by a deliberate, this-entry-only edit — the log-time price
  /// field on [PartyLogDrinkSheet] or S9's per-entry price edit — rather
  /// than resolved from the preset's regular price or the session-wide
  /// `PartySessionPrice` table. A retroactive party-price edit
  /// (`setSessionPrices`) sweeps its new price onto already-logged entries
  /// for that preset **except** ones with this flag set, so the one-off
  /// override always wins over the session-wide table (party-session.md
  /// §Editing prices during a session).
  BoolColumn get manualPriceOverride =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get consumedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
