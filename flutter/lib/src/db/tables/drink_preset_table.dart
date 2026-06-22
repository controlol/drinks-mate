import 'package:drift/drift.dart';

/// Drift table for drink presets — named, pre-configured drink shortcuts.
///
/// Schema v2 addition. Volumes stored in ml (metric canonical per Parity
/// Rulebook). Money in integer minor units. No Phase-2 entities.
///
/// [DataClassName] avoids a name collision with the pure-Dart domain model
/// [DrinkPreset] in lib/src/models/drink_preset.dart.
@DataClassName('DrinkPresetRow')
class DrinkPresets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Stored as the canonical string from [BeverageType.stored].
  TextColumn get beverageType => text()();
  IntColumn get volumeMl => integer()();
  RealColumn get abvPercent => real().nullable()();
  IntColumn get regularPriceMinor => integer().nullable()();
  TextColumn get regularCurrency => text().nullable()();
  TextColumn get iconKey => text()();
  TextColumn get iconColor => text()();
  BoolColumn get isUserCreated => boolean()();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
