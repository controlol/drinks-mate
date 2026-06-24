import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/beverage_type.dart';
import '../models/drink_entry.dart';
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
      _db.watchVisiblePresets().map((rows) => rows.map(_rowToPreset).toList());

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
    final consumed = consumedAt?.toUtc() ?? now;
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
  /// [now] is injected by the provider so the boundary timer and the query
  /// window share the exact same instant.
  Stream<int> watchTodayTotalMl({DateTime? now, int boundaryHour = 5}) {
    final window = dayWindow(
      now: now ?? DateTime.now(),
      boundaryHour: boundaryHour,
    );
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

  /// Reactive stream of the 7-day daily average hydration intake in ml.
  ///
  /// Covers the last 7 completed day windows before today (today is excluded).
  /// Zero-fills missing days — divides by 7 regardless of how many days have
  /// data, so the average is never inflated.
  Stream<double> watch7DayAverageMl({int boundaryHour = 5, DateTime? now}) {
    final nowLocal = now ?? DateTime.now();
    final todayStart = dayWindow(now: nowLocal, boundaryHour: boundaryHour).$1;
    final sevenDaysAgoStart = DateTime(
      todayStart.year,
      todayStart.month,
      todayStart.day - 7,
      todayStart.hour,
      todayStart.minute,
    );
    final nonAlcoholicTypes = BeverageType.values
        .where((t) => !t.isAlcoholic)
        .map((t) => t.stored)
        .toList();
    return _db
        .watchEntriesInWindow(
      sevenDaysAgoStart.toUtc(),
      todayStart.toUtc(),
      nonAlcoholicTypes,
    )
        .map((entries) {
      var totalMl = 0;
      for (final (_, volumeMl) in entries) {
        totalMl += volumeMl;
      }
      return totalMl / 7.0;
    });
  }

  /// Reactive stream of how many of the last 7 completed day windows met the
  /// daily goal.
  ///
  /// "Met the goal" means the sum of non-alcoholic intake in a day window is
  /// ≥ [dailyGoalMl]. Returns an integer in [0, 7].
  Stream<int> watch7DayDaysOnGoal({
    required int dailyGoalMl,
    int boundaryHour = 5,
    DateTime? now,
  }) {
    final nowLocal = now ?? DateTime.now();
    final todayStart = dayWindow(now: nowLocal, boundaryHour: boundaryHour).$1;
    final sevenDaysAgoStart = DateTime(
      todayStart.year,
      todayStart.month,
      todayStart.day - 7,
      todayStart.hour,
      todayStart.minute,
    );
    final nonAlcoholicTypes = BeverageType.values
        .where((t) => !t.isAlcoholic)
        .map((t) => t.stored)
        .toList();
    return _db
        .watchEntriesInWindow(
      sevenDaysAgoStart.toUtc(),
      todayStart.toUtc(),
      nonAlcoholicTypes,
    )
        .map((entries) {
      final byDay = <DateTime, int>{};
      for (final (consumedAt, volumeMl) in entries) {
        final dayStart = dayWindow(
          now: consumedAt.toLocal(),
          boundaryHour: boundaryHour,
        ).$1;
        byDay[dayStart] = (byDay[dayStart] ?? 0) + volumeMl;
      }
      return byDay.values.where((total) => total >= dailyGoalMl).length;
    });
  }

  /// Reactive stream of today's logged entries in reverse-chronological order.
  ///
  /// Only non-alcoholic entries are included — this screen is reached from the
  /// hydration progress card (issue #15 scope: non-alcoholic only).
  /// Soft-deleted entries are excluded.
  Stream<List<DrinkEntry>> watchTodayEntries({
    DateTime? now,
    int boundaryHour = 5,
  }) {
    final window = dayWindow(
      now: now ?? DateTime.now(),
      boundaryHour: boundaryHour,
    );
    final nonAlcoholicTypes = BeverageType.values
        .where((t) => !t.isAlcoholic)
        .map((t) => t.stored)
        .toList();
    return _db
        .watchEntriesInWindowFull(
          window.$1.toUtc(),
          window.$2.toUtc(),
          nonAlcoholicTypes,
        )
        .map((rows) => rows.map(_rowToEntry).toList());
  }

  /// Updates the [volumeMl] and/or [consumedAt] of an existing entry.
  ///
  /// Snapshot fields (name, icon, ABV, etc.) are never changed — log
  /// immutability (data-model.md §Snapshot semantics).
  /// [volumeMl] must be ≥ 1 ml if provided.
  Future<void> updateDrinkEntry({
    required String id,
    int? volumeMl,
    DateTime? consumedAt,
  }) {
    if (volumeMl != null && volumeMl < 1) {
      throw ArgumentError.value(volumeMl, 'volumeMl', 'must be ≥ 1 ml');
    }
    final now = DateTime.now().toUtc();
    return _db.updateDrinkEntryPartial(
      id,
      volumeMl: volumeMl,
      consumedAtUtc: consumedAt?.toUtc(),
      updatedAtUtc: now,
    );
  }

  /// Soft-deletes an entry by setting [deletedAt] = now (F7).
  ///
  /// The row is never hard-deleted. The reactive streams automatically
  /// exclude soft-deleted rows so the UI updates without a manual refresh.
  Future<void> deleteDrinkEntry(String id) {
    final now = DateTime.now().toUtc();
    return _db.softDeleteDrinkEntry(id, now);
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

  static DrinkEntry _rowToEntry(DrinkEntryRow row) => DrinkEntry(
        id: row.id,
        name: row.name,
        beverageType: BeverageType.fromStored(row.beverageType),
        volumeMl: row.volumeMl,
        abvPercent: row.abvPercent,
        priceMinor: row.priceMinor,
        currency: row.currency,
        iconKey: row.iconKey,
        iconColor: row.iconColor,
        consumedAt: row.consumedAt,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
      );
}
