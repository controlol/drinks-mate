import 'package:drift/drift.dart';

/// Drift table for drink entries — a single logged drink.
///
/// Schema v2 addition. All preset values are snapshotted at log time (log
/// immutability — data-model.md §Snapshot semantics). No FK back to
/// DrinkPreset. Token/Party fields added in a later migration when
/// PartySession table lands.
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

  /// Snapshot of price in minor units at log time.
  IntColumn get priceMinor => integer().nullable()();
  TextColumn get currency => text().nullable()();
  TextColumn get iconKey => text().nullable()();
  TextColumn get iconColor => text().nullable()();
  DateTimeColumn get consumedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
