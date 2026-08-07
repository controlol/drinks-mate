import 'package:drift/drift.dart';

/// Drift table for meals logged within a Party Session.
///
/// Schema v4 addition (issue #21). Meals do not exist outside a session —
/// there is no standalone meal tracker (data-model.md §Meal).
///
/// [DataClassName] avoids a name collision with the pure-Dart domain model
/// [Meal] in lib/src/models/meal.dart.
@DataClassName('MealRow')
class Meals extends Table {
  TextColumn get id => text()();
  TextColumn get partySessionId => text()();

  /// 'small' | 'medium' | 'large'.
  TextColumn get size => text()();

  /// When the meal was eaten. Defaults to "now" at logging, adjustable.
  DateTimeColumn get eatenAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
