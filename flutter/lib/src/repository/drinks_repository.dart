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
  // Presets — read
  // ---------------------------------------------------------------------------

  /// Visible (non-hidden, non-deleted) presets ordered by [sortOrder].
  Stream<List<DrinkPreset>> watchVisiblePresets() =>
      _db.watchVisiblePresets().map((rows) => rows.map(_rowToPreset).toList());

  /// All non-deleted presets (including hidden) ordered by [sortOrder].
  /// Intended for the "Manage drinks" settings UI.
  Stream<List<DrinkPreset>> watchAllPresets() =>
      _db.watchAllPresets().map((rows) => rows.map(_rowToPreset).toList());

  /// Non-deleted, non-hidden alcoholic presets ordered by [sortOrder].
  /// Intended for the Party Mode preset picker.
  Stream<List<DrinkPreset>> watchAlcoholicPresets() {
    final alcoholicTypes = BeverageType.values
        .where((t) => t.isAlcoholic)
        .map((t) => t.stored)
        .toList();
    return _db
        .watchAlcoholicPresets(alcoholicTypes)
        .map((rows) => rows.map(_rowToPreset).toList());
  }

  // ---------------------------------------------------------------------------
  // Presets — write
  // ---------------------------------------------------------------------------

  /// Creates a new user-owned preset.
  ///
  /// Validates [name] via [validatePresetName]; throws [ArgumentError] on
  /// failure. Also enforces:
  /// - [volumeMl] > 0 (data-model.md §DrinkPreset: "Required, must be > 0")
  /// - [abvPercent] non-null for alcoholic [beverageType] (null → 0 g alcohol in BAC)
  /// - [regularCurrency] non-null when [regularPriceMinor] is set
  Future<DrinkPreset> createPreset({
    required String name,
    required BeverageType beverageType,
    required int volumeMl,
    double? abvPercent,
    int? regularPriceMinor,
    String? regularCurrency,
    required String iconKey,
    required String iconColor,
    required int sortOrder,
  }) async {
    _assertValidPresetName(name);
    name = normalizeNfc(name);
    if (volumeMl <= 0) {
      throw ArgumentError.value(volumeMl, 'volumeMl', 'Must be > 0');
    }
    if (beverageType.isAlcoholic && abvPercent == null) {
      throw ArgumentError.value(
        abvPercent,
        'abvPercent',
        'Required for alcoholic beverageType $beverageType',
      );
    }
    if (!beverageType.isAlcoholic && abvPercent != null) {
      throw ArgumentError.value(
        abvPercent,
        'abvPercent',
        'Must be null for non-alcoholic beverageType $beverageType',
      );
    }
    if (regularPriceMinor != null && regularCurrency == null) {
      throw ArgumentError(
        'regularCurrency is required when regularPriceMinor is set',
      );
    }
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _db.insertPreset(
      DrinkPresetsCompanion.insert(
        id: id,
        name: name,
        beverageType: beverageType.stored,
        volumeMl: volumeMl,
        abvPercent: Value(abvPercent),
        regularPriceMinor: Value(regularPriceMinor),
        regularCurrency: Value(regularCurrency),
        iconKey: iconKey,
        iconColor: iconColor,
        isUserCreated: true,
        sortOrder: sortOrder,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final row = await _db.getPresetById(id);
    return _rowToPreset(row!);
  }

  /// Updates mutable fields of an existing preset.
  ///
  /// Only fields with a non-absent [Value] are written; omitted fields retain
  /// their current values (no snapshot-immutability breach — [DrinkEntry] rows
  /// are never touched).
  ///
  /// For nullable fields ([abvPercent], [regularPriceMinor], [regularCurrency])
  /// use [Value.absent] (the default) to leave the field unchanged,
  /// [Value(someValue)] to set it, and [Value(null)] to clear it to null.
  ///
  /// Validates [name] via [validatePresetName] when provided; throws
  /// [ArgumentError] on failure. Throws [StateError] if [id] does not exist.
  Future<void> updatePreset({
    required String id,
    String? name,
    int? volumeMl,
    Value<double?> abvPercent = const Value.absent(),
    Value<int?> regularPriceMinor = const Value.absent(),
    Value<String?> regularCurrency = const Value.absent(),
    String? iconKey,
    String? iconColor,
  }) async {
    if (name != null) {
      _assertValidPresetName(name);
      name = normalizeNfc(name);
    }
    if (volumeMl != null && volumeMl <= 0) {
      throw ArgumentError.value(volumeMl, 'volumeMl', 'Must be > 0');
    }
    DrinkPresetRow? existing;
    if (abvPercent.present) {
      existing = await _db.getPresetById(id);
      if (existing != null) {
        final storedType = BeverageType.fromStored(existing.beverageType);
        if (abvPercent.value == null && storedType.isAlcoholic) {
          throw ArgumentError(
            'abvPercent cannot be cleared on an alcoholic preset',
          );
        }
        if (abvPercent.value != null && !storedType.isAlcoholic) {
          throw ArgumentError(
            'abvPercent must be null for non-alcoholic preset',
          );
        }
      }
    }
    if (regularPriceMinor.present || regularCurrency.present) {
      existing ??= await _db.getPresetById(id);
      if (existing != null) {
        final effectivePrice = regularPriceMinor.present
            ? regularPriceMinor.value
            : existing.regularPriceMinor;
        final effectiveCurrency = regularCurrency.present
            ? regularCurrency.value
            : existing.regularCurrency;
        if (effectivePrice != null && effectiveCurrency == null) {
          throw ArgumentError(
            'regularCurrency is required when regularPriceMinor is set',
          );
        }
      }
    }
    final now = DateTime.now().toUtc();
    final rows = await _db.updatePresetFields(
      id,
      DrinkPresetsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        volumeMl: volumeMl != null ? Value(volumeMl) : const Value.absent(),
        abvPercent: abvPercent,
        regularPriceMinor: regularPriceMinor,
        regularCurrency: regularCurrency,
        iconKey: iconKey != null ? Value(iconKey) : const Value.absent(),
        iconColor: iconColor != null ? Value(iconColor) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
    if (rows == 0) throw StateError('Preset $id not found.');
  }

  /// Hides a preset so it no longer appears in quick-log or the log-drink
  /// picker. Hidden presets remain in the database and can be restored.
  ///
  /// Throws [StateError] if [id] does not exist.
  Future<void> hidePreset(String id) async {
    final row = await _db.getPresetById(id);
    if (row == null) throw StateError('Preset $id not found.');
    await _db.setPresetHidden(id, true, DateTime.now().toUtc());
  }

  /// Restores a previously hidden preset to the visible list.
  ///
  /// Throws [StateError] if [id] does not exist.
  Future<void> unhidePreset(String id) async {
    final row = await _db.getPresetById(id);
    if (row == null) throw StateError('Preset $id not found.');
    await _db.setPresetHidden(id, false, DateTime.now().toUtc());
  }

  /// Soft-deletes a preset (sets [deletedAt]).
  ///
  /// Applies to any preset — user-created or seeded default. Per data-model.md
  /// §DrinkPreset: "The user can edit, hide, or delete them — there is no
  /// special protection."
  ///
  /// Note: a future "Reset to defaults" action must use INSERT OR REPLACE (or
  /// an explicit UPDATE … SET deletedAt = NULL keyed on stable UUIDs) —
  /// INSERT OR IGNORE is a no-op for rows that already exist, even if
  /// soft-deleted.
  ///
  /// Throws [StateError] if the preset does not exist.
  Future<void> deletePreset(String id) async {
    final row = await _db.getPresetById(id);
    if (row == null) throw StateError('Preset $id not found.');
    await _db.softDeletePreset(id, DateTime.now().toUtc());
  }

  /// Bulk-updates [sortOrder] for each id in [orderedIds] in a single
  /// transaction. Index 0 receives sortOrder 1.
  Future<void> reorderPresets(List<String> orderedIds) =>
      _db.reorderPresets(orderedIds, DateTime.now().toUtc());

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

  // ---------------------------------------------------------------------------
  // Validation helpers
  // ---------------------------------------------------------------------------

  static void _assertValidPresetName(String name) {
    final result = validatePresetName(name);
    if (!result.isValid) {
      throw ArgumentError.value(name, 'name', result.error);
    }
  }
}
