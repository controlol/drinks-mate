import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/beverage_type.dart';
import '../models/drink_preset.dart';

/// Repository seam — the only way widgets touch persisted drink data (D2).
///
/// Converts Drift row types ([DrinkPresetRow], [DrinkEntryRow]) to pure-Dart
/// domain models ([DrinkPreset], [DrinkEntry]) before returning. Drift types
/// never escape this class.
class DrinksRepository {
  DrinksRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Presets
  // ---------------------------------------------------------------------------

  Stream<List<DrinkPreset>> watchVisiblePresets() =>
      _db.watchVisiblePresets().map(
            (rows) => rows.map(_rowToPreset).toList(),
          );

  // ---------------------------------------------------------------------------
  // Entries
  // ---------------------------------------------------------------------------

  /// Log a drink from a preset, snapshotting its values at the current time.
  ///
  /// [volumeMl] overrides the preset default (phase-2 edit in S2).
  /// [consumedAt] defaults to now.
  Future<void> logDrink({
    required DrinkPreset preset,
    int? volumeMl,
    DateTime? consumedAt,
  }) async {
    final now = DateTime.now().toUtc();
    final consumed = (consumedAt ?? DateTime.now()).toUtc();
    final companion = DrinkEntriesCompanion.insert(
      id: _uuid.v4(),
      name: Value(preset.name),
      beverageType: preset.beverageType.stored,
      volumeMl: volumeMl ?? preset.volumeMl,
      abvPercent: Value(preset.abvPercent),
      priceMinor: Value(preset.regularPriceMinor),
      currency: Value(preset.regularCurrency),
      iconKey: Value(preset.iconKey),
      iconColor: Value(preset.iconColor),
      consumedAt: consumed,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insertDrinkEntry(companion);
  }

  /// Reactive stream of today's hydration total in ml.
  ///
  /// Excludes alcoholic beverages — data-model.md §BeverageType: "the two
  /// flows are strictly disjoint; a beer does not move the daily-water goal."
  /// Emits a new value whenever a drink is logged or deleted.
  Stream<int> watchTodayTotalMl() {
    final window = dayWindow(now: DateTime.now());
    final nonAlcoholicTypes = BeverageType.values
        .where((t) => !t.isAlcoholic)
        .map((t) => t.stored)
        .toList();
    return _db.watchTotalMlInWindow(
      window.$1.toUtc(),
      window.$2.toUtc(),
      nonAlcoholicTypes,
    );
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  static DrinkPreset _rowToPreset(DrinkPresetRow row) => DrinkPreset(
        id: row.id,
        name: row.name,
        beverageType: BeverageType.fromStored(row.beverageType),
        volumeMl: row.volumeMl,
        abvPercent: row.abvPercent,
        regularPriceMinor: row.regularPriceMinor,
        regularCurrency: row.regularCurrency,
        iconKey: row.iconKey,
        iconColor: row.iconColor,
        isUserCreated: row.isUserCreated,
        isHidden: row.isHidden,
        sortOrder: row.sortOrder,
      );
}
