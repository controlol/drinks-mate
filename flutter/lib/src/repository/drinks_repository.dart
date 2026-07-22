import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/beverage_type.dart';
import '../models/daily_bucket.dart';
import '../models/drink_entry.dart';
import '../models/drink_icons.dart';
import '../models/drink_preset.dart';
import '../models/optional.dart';
import 'party_session_repository.dart';

/// Repository seam — the only way widgets touch persisted drink data (D2).
///
/// Converts Drift row types ([DrinkPresetRow], [DrinkEntryRow]) to pure-Dart
/// domain models ([DrinkPreset], [DrinkEntry]) before returning. Drift types
/// never escape this class.
class DrinksRepository {
  DrinksRepository(this._db, {PartySessionRepository? partySessionRepository})
      : _partySessionRepository = partySessionRepository;

  final AppDatabase _db;
  final PartySessionRepository? _partySessionRepository;
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

  /// One-shot read of a single preset by id, or null if missing/deleted-out.
  ///
  /// Used by the reminder scheduler to resolve `defaultDrinkPresetId` at
  /// reschedule time (data-model.md §UserPreferences).
  Future<DrinkPreset?> getPresetById(String id) async {
    final row = await _db.getPresetById(id);
    return row == null ? null : _rowToPreset(row);
  }

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

  /// The [sortOrder] to use for a newly created preset: one greater than the
  /// current maximum among non-deleted presets (1 if none exist).
  ///
  /// Callers must not derive this from a preset *count* — [deletePreset] is a
  /// soft delete, so the count of live presets can be lower than the highest
  /// sortOrder still in use, and a `count + 1` value can then collide with an
  /// existing preset's sortOrder (undefined relative ordering, since
  /// `ORDER BY sortOrder ASC` has no secondary tiebreaker).
  Future<int> nextSortOrder() async {
    final maxSortOrder = await _db.getMaxPresetSortOrder();
    return (maxSortOrder ?? 0) + 1;
  }

  /// Creates a new user-owned preset.
  ///
  /// Validates [name] via [validatePresetName]; throws [ArgumentError] on
  /// failure. Also enforces:
  /// - [volumeMl] > 0 (data-model.md §DrinkPreset: "Required, must be > 0")
  /// - [abvPercent] non-null for alcoholic [beverageType] (null → 0 g alcohol in BAC)
  /// - [regularCurrency] non-null when [regularPriceMinor] is set
  /// - [iconKey] must be one of [kDrinkIconKeys] (the bundled icon allowlist)
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
    if (!kDrinkIconKeys.contains(iconKey)) {
      throw ArgumentError.value(
        iconKey,
        'iconKey',
        'Not a recognised bundled icon key',
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
  /// Only fields with a present [Optional] are written; omitted fields retain
  /// their current values (no snapshot-immutability breach — [DrinkEntry] rows
  /// are never touched).
  ///
  /// For nullable fields ([abvPercent], [regularPriceMinor], [regularCurrency])
  /// use [Optional.absent] (the default) to leave the field unchanged,
  /// [Optional.value] with a non-null argument to set it, and
  /// [Optional.value] with `null` to clear it. [Optional] is this
  /// repository's own present/absent wrapper — never Drift's `Value` — so
  /// callers (including widgets) don't need a `package:drift` import
  /// (D2: "Drift types never reach widgets").
  ///
  /// Validates [name] via [validatePresetName] when provided; throws
  /// [ArgumentError] on failure. When provided, [iconKey] must be one of
  /// [kDrinkIconKeys] (the bundled icon allowlist); throws [ArgumentError]
  /// otherwise. Throws [StateError] if [id] does not exist.
  Future<void> updatePreset({
    required String id,
    String? name,
    int? volumeMl,
    Optional<double?> abvPercent = const Optional.absent(),
    Optional<int?> regularPriceMinor = const Optional.absent(),
    Optional<String?> regularCurrency = const Optional.absent(),
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
    if (iconKey != null && !kDrinkIconKeys.contains(iconKey)) {
      throw ArgumentError.value(
        iconKey,
        'iconKey',
        'Not a recognised bundled icon key',
      );
    }
    DrinkPresetRow? existing;
    if (abvPercent.isPresent) {
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
    if (regularPriceMinor.isPresent || regularCurrency.isPresent) {
      existing ??= await _db.getPresetById(id);
      if (existing != null) {
        final effectivePrice = regularPriceMinor.isPresent
            ? regularPriceMinor.value
            : existing.regularPriceMinor;
        final effectiveCurrency = regularCurrency.isPresent
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
        abvPercent: abvPercent.isPresent
            ? Value(abvPercent.value)
            : const Value.absent(),
        regularPriceMinor: regularPriceMinor.isPresent
            ? Value(regularPriceMinor.value)
            : const Value.absent(),
        regularCurrency: regularCurrency.isPresent
            ? Value(regularCurrency.value)
            : const Value.absent(),
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
  /// Restricted to user-created presets. Per data-model.md §DrinkPreset
  /// "Seeded defaults": deleting a seeded default has no recovery path until
  /// a "Reset to defaults" action exists in settings to re-seed missing
  /// defaults, so this is an interim restriction — not a permanent
  /// invariant — enforced here (not just in the Manage Drinks UI) so no
  /// other caller can bypass it.
  ///
  /// Note: a future "Reset to defaults" action must use INSERT OR REPLACE (or
  /// an explicit UPDATE … SET deletedAt = NULL keyed on stable UUIDs) —
  /// INSERT OR IGNORE is a no-op for rows that already exist, even if
  /// soft-deleted.
  ///
  /// Throws [StateError] if the preset does not exist, or if it is a seeded
  /// (non-user-created) preset.
  Future<void> deletePreset(String id) async {
    final row = await _db.getPresetById(id);
    if (row == null) throw StateError('Preset $id not found.');
    if (!row.isUserCreated) {
      throw StateError(
        'Cannot delete a seeded (non-user-created) preset: $id.',
      );
    }
    await _db.softDeletePreset(id, DateTime.now().toUtc());
  }

  /// Bulk-updates [sortOrder] for every non-deleted preset in a single
  /// transaction. Ids in [orderedIds] receive sortOrder 1..N (in the order
  /// given); any other non-deleted preset (e.g. a seeded default not passed
  /// in) keeps its relative order and is appended after, so [orderedIds] may
  /// be a partial list without creating duplicate sortOrder values.
  ///
  /// Throws [ArgumentError] if [orderedIds] contains duplicates, or
  /// [StateError] if it contains an id that does not exist or is deleted.
  Future<void> reorderPresets(List<String> orderedIds) =>
      _db.reorderPresets(orderedIds, DateTime.now().toUtc());

  // ---------------------------------------------------------------------------
  // Entries
  // ---------------------------------------------------------------------------

  /// Log a drink from a preset, snapshotting its values at the current time.
  ///
  /// [volumeMl] overrides the preset default (phase-2 edit in S2).
  /// [abvPercent] overrides the preset default — used for the Party Mode
  /// "orphan drink" path (party-session.md §Logging alcohol when no session
  /// is active: "Don't start a session"), where the user may still edit ABV
  /// even though the drink is never attached to a session. A future session's
  /// orphan absorption reads this stored value, so it must reflect the
  /// user's actual entry, not just the preset default.
  /// [name] and [abvPercent] override the preset default when non-null.
  /// [priceMinor] and [currency] override the preset default — the S2
  /// Advanced editor's "Confirm" path (user-experience.md §S2): "logs the
  /// drink with the entered values for this entry only. The underlying
  /// preset is unchanged." Use [Optional.absent] (the default) to fall back
  /// to the preset's stored price/currency, or [Optional.value] — including
  /// `Optional.value(null)` to explicitly log this entry with no price —
  /// to override it for this entry only. Passing these does not write to
  /// the [DrinkPreset] row; callers that want the preset itself updated
  /// must call [updatePreset] first and pass the refreshed preset in.
  /// [consumedAt] defaults to now.
  ///
  /// [id], when provided, is used as the new entry's id instead of a
  /// freshly generated one — callers that pop a UI element *before* this
  /// future settles (S2's "close immediately, write in background" pattern)
  /// need the id up front to wire a post-log Undo action to the right row.
  /// Returns the id actually used (generated or caller-supplied).
  ///
  /// Throws [ArgumentError] if the effective price is non-null while the
  /// effective currency is null (data-model.md `DrinkEntry.currency`:
  /// "Required when priceMinor is set"), or if [name] fails
  /// [validatePresetName] — the same rule `createPreset`/`updatePreset`
  /// enforce, since `DrinkEntry.name` follows the same Parity Rulebook shape.
  Future<String> logDrink({
    required DrinkPreset preset,
    String? id,
    String? name,
    int? volumeMl,
    double? abvPercent,
    Optional<int?> priceMinor = const Optional.absent(),
    Optional<String?> currency = const Optional.absent(),
    DateTime? consumedAt,
  }) async {
    if (name != null) {
      _assertValidPresetName(name);
      name = normalizeNfc(name);
    }
    final effectivePriceMinor =
        priceMinor.isPresent ? priceMinor.value : preset.regularPriceMinor;
    final effectiveCurrency =
        currency.isPresent ? currency.value : preset.regularCurrency;
    if (effectivePriceMinor != null && effectiveCurrency == null) {
      throw ArgumentError('currency is required when priceMinor is set');
    }
    final entryId = id ?? _uuid.v4();
    final now = DateTime.now().toUtc();
    final consumed = consumedAt?.toUtc() ?? now;
    final companion = DrinkEntriesCompanion.insert(
      id: entryId,
      name: Value(name ?? preset.name),
      beverageType: preset.beverageType.stored,
      volumeMl: volumeMl ?? preset.volumeMl,
      abvPercent: Value(abvPercent ?? preset.abvPercent),
      priceMinor: Value(effectivePriceMinor),
      currency: Value(effectiveCurrency),
      iconKey: Value(preset.iconKey),
      iconColor: Value(preset.iconColor),
      presetId: Value(preset.id),
      consumedAt: consumed,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insertDrinkEntry(companion);
    // Auto-end trigger point: "a drink is logged" (party-session.md
    // §Auto-end is computed lazily) — a non-alcoholic drink logged well
    // after the active session's last alcoholic entry must still surface
    // the retroactive end.
    await _partySessionRepository?.checkAndApplyAutoEnd(now: now);
    return entryId;
  }

  /// Reactive stream of per-preset usage stats (last-used timestamp,
  /// trailing 30-day count), keyed by preset id — feeds [rankPresetIds] for
  /// the Recently-used/Most-used sort modes (F14 §Sort modes).
  ///
  /// [now] is injected for deterministic tests; defaults to the wall clock,
  /// **re-read on every emission** (not captured once at subscription time)
  /// so the trailing window actually keeps sliding for the life of a
  /// long-lived subscription — e.g. a drink logged the moment it's consumed
  /// must land inside its own window, not be excluded by a "now" frozen from
  /// whenever the stream first started. Both signals key off live entries'
  /// `consumedAt` (never `createdAt`), aggregated in Dart from a single
  /// watched row set — same pattern as the 7-day stat streams above.
  Stream<Map<String, PresetUsageStats>> watchPresetUsageStats({DateTime? now}) {
    return _db.watchPresetEntryTimestamps().map((timestamps) {
      final nowUtc = (now ?? DateTime.now()).toUtc();
      final windowStartUtc = nowUtc.subtract(const Duration(days: 30));
      return _aggregateUsageStats(
        timestamps,
        windowStartUtc: windowStartUtc,
        nowUtc: nowUtc,
      );
    });
  }

  static Map<String, PresetUsageStats> _aggregateUsageStats(
    List<(String, DateTime)> timestamps, {
    required DateTime windowStartUtc,
    required DateTime nowUtc,
  }) {
    final lastUsed = <String, DateTime>{};
    final count30d = <String, int>{};
    for (final (presetId, consumedAt) in timestamps) {
      final existing = lastUsed[presetId];
      if (existing == null || consumedAt.isAfter(existing)) {
        lastUsed[presetId] = consumedAt;
      }
      if (!consumedAt.isBefore(windowStartUtc) && !consumedAt.isAfter(nowUtc)) {
        count30d[presetId] = (count30d[presetId] ?? 0) + 1;
      }
    }
    final ids = {...lastUsed.keys, ...count30d.keys};
    return {
      for (final id in ids)
        id: PresetUsageStats(
          lastUsedAt: lastUsed[id],
          count30d: count30d[id] ?? 0,
        ),
    };
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

  /// One-shot read of today's hydration total in ml — same filter as
  /// [watchTodayTotalMl], for reminder-scheduling reads that don't need a
  /// live subscription.
  Future<int> getTodayTotalMl({DateTime? now, int boundaryHour = 5}) {
    final window = dayWindow(
      now: now ?? DateTime.now(),
      boundaryHour: boundaryHour,
    );
    final nonAlcoholicTypes = BeverageType.values
        .where((t) => !t.isAlcoholic)
        .map((t) => t.stored)
        .toList();
    return _db.getTotalMlInWindow(
      window.$1.toUtc(),
      window.$2.toUtc(),
      nonAlcoholicTypes,
    );
  }

  /// One-shot read of the most recent drink's `consumedAt`, across every
  /// beverage type (alcoholic entries count as engagement too), or null if
  /// the user has never logged a drink.
  ///
  /// Feeds the reminder scheduler's inactive-user silence check
  /// (notifications.md §Inactive-user silence).
  Future<DateTime?> getLatestDrinkConsumedAt() =>
      _db.getLatestDrinkConsumedAt();

  /// Reactive stream of the earliest drink's `consumedAt`, across every
  /// beverage type, or null if the user has never logged a drink.
  ///
  /// Feeds the History day drill-down's backward swipe bound (S3).
  Stream<DateTime?> watchEarliestDrinkConsumedAt() =>
      _db.watchEarliestDrinkConsumedAt();

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

  /// One-shot count of how many days in the current ISO week (Monday–Sunday,
  /// containing [now]) met the daily goal so far.
  ///
  /// Unlike [watch7DayDaysOnGoal] (trailing 7 days, today excluded), this
  /// covers the fixed Mon–Sun calendar week and *includes* today — the
  /// weekly-summary notification fires on the Sunday of the week it reports
  /// on (notifications.md §Notification types → Weekly summary: "the seven
  /// days ending on the day of firing").
  Future<int> isoWeekDaysOnGoal({
    required int dailyGoalMl,
    int boundaryHour = 5,
    DateTime? now,
  }) async {
    final window = isoWeekWindow(
      now: now ?? DateTime.now(),
      boundaryHour: boundaryHour,
    );
    final nonAlcoholicTypes = BeverageType.values
        .where((t) => !t.isAlcoholic)
        .map((t) => t.stored)
        .toList();
    final entries = await _db.getEntriesInWindow(
      window.$1.toUtc(),
      window.$2.toUtc(),
      nonAlcoholicTypes,
    );
    final byDay = <DateTime, int>{};
    for (final (consumedAt, volumeMl) in entries) {
      final dayStart = dayWindow(
        now: consumedAt.toLocal(),
        boundaryHour: boundaryHour,
      ).$1;
      byDay[dayStart] = (byDay[dayStart] ?? 0) + volumeMl;
    }
    return byDay.values.where((total) => total >= dailyGoalMl).length;
  }

  // ---------------------------------------------------------------------------
  // History (F4)
  // ---------------------------------------------------------------------------

  /// Reactive stream of daily hydration totals (ml) for every day-window in
  /// `[rangeStart, rangeEnd)`, one zero-filled [DailyBucket] per day,
  /// ordered oldest-first.
  ///
  /// [rangeStart] must itself be a day-window boundary instant (e.g. from
  /// `isoWeekWindow`/`monthWindow` with the same [boundaryHour]/
  /// [boundaryMinute]) so the zero-fill loop lines up with the per-entry
  /// bucketing below.
  ///
  /// Excludes alcoholic beverages — same scope as [watchTodayTotalMl]
  /// (data-model.md §BeverageType: "the two flows are strictly disjoint").
  Stream<List<DailyBucket>> watchDailyTotalsMl({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    int boundaryHour = 5,
    int boundaryMinute = 0,
  }) {
    final nonAlcoholicTypes = BeverageType.values
        .where((t) => !t.isAlcoholic)
        .map((t) => t.stored)
        .toList();
    return _db
        .watchEntriesInWindow(
          rangeStart.toUtc(),
          rangeEnd.toUtc(),
          nonAlcoholicTypes,
        )
        .map(
          (entries) => _bucketByDay(
            entries,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            boundaryHour: boundaryHour,
            boundaryMinute: boundaryMinute,
            reduce: (acc, volumeMl) => acc + volumeMl,
          ),
        );
  }

  /// Reactive stream of hydration drink counts for every day-window in
  /// `[rangeStart, rangeEnd)`, one zero-filled [DailyBucket] per day,
  /// ordered oldest-first. See [watchDailyTotalsMl] for the [rangeStart]
  /// alignment requirement.
  ///
  /// Counts non-deleted, non-alcoholic entries — issue #25 scopes History's
  /// charts to hydration only; alcohol charts land in a follow-up (#26).
  Stream<List<DailyBucket>> watchDrinksPerDay({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    int boundaryHour = 5,
    int boundaryMinute = 0,
  }) {
    final nonAlcoholicTypes = BeverageType.values
        .where((t) => !t.isAlcoholic)
        .map((t) => t.stored)
        .toList();
    return _db
        .watchEntriesInWindow(
          rangeStart.toUtc(),
          rangeEnd.toUtc(),
          nonAlcoholicTypes,
        )
        .map(
          (entries) => _bucketByDay(
            entries,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            boundaryHour: boundaryHour,
            boundaryMinute: boundaryMinute,
            reduce: (acc, _) => acc + 1,
          ),
        );
  }

  /// Groups `(consumedAt, volumeMl)` pairs into one zero-filled [DailyBucket]
  /// per day-window in `[rangeStart, rangeEnd)`. [reduce] folds each entry
  /// into its day's running value — sum of ml for totals, or a `+1` count.
  static List<DailyBucket> _bucketByDay(
    List<(DateTime, int)> entries, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required int boundaryHour,
    required int boundaryMinute,
    required int Function(int acc, int volumeMl) reduce,
  }) {
    final byDay = <DateTime, int>{};
    for (final (consumedAt, volumeMl) in entries) {
      final dayStart = dayWindow(
        now: consumedAt.toLocal(),
        boundaryHour: boundaryHour,
        boundaryMinute: boundaryMinute,
      ).$1;
      byDay[dayStart] = reduce(byDay[dayStart] ?? 0, volumeMl);
    }
    final buckets = <DailyBucket>[];
    var day = rangeStart;
    while (day.isBefore(rangeEnd)) {
      buckets.add(DailyBucket(dayStart: day, value: byDay[day] ?? 0));
      day = DateTime(
        day.year,
        day.month,
        day.day + 1,
        boundaryHour,
        boundaryMinute,
      );
    }
    return buckets;
  }

  /// Reactive stream of alcoholic drink counts (non-deleted, any
  /// [BeverageType.isAlcoholic] entry — session-attached *or* orphan) for
  /// every day-window in `[rangeStart, rangeEnd)`, one zero-filled
  /// [DailyBucket] per day, ordered oldest-first — F4/#26 "Alcoholic drinks
  /// per day". features.md F4 specs this chart as counting "alcoholic drink
  /// entries", with no `partySessionId` condition; entries logged outside
  /// Party Mode (e.g. via the Today tab's `LogDrinkSheet`) count too, so this
  /// chart stays consistent with the day drill-down's full entry list (issue
  /// #66). See [watchDailyTotalsMl] for the [rangeStart] alignment
  /// requirement.
  Stream<List<DailyBucket>> watchAlcoholicDrinksPerDay({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    int boundaryHour = 5,
    int boundaryMinute = 0,
  }) {
    final alcoholicTypes = BeverageType.values
        .where((t) => t.isAlcoholic)
        .map((t) => t.stored)
        .toList();
    return _db
        .watchEntriesInWindow(
          rangeStart.toUtc(),
          rangeEnd.toUtc(),
          alcoholicTypes,
        )
        .map(
          (entries) => _bucketByDay(
            entries,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            boundaryHour: boundaryHour,
            boundaryMinute: boundaryMinute,
            reduce: (acc, _) => acc + 1,
          ),
        );
  }

  /// Reactive stream of every live entry (any beverage type) within
  /// `[dayStart, dayEnd)`, newest-first — feeds the History day drill-down
  /// (F4/#26), which shows both hydration and alcoholic entries for the day.
  Stream<List<DrinkEntry>> watchDayEntries(DateTime dayStart, DateTime dayEnd) {
    final allTypes = BeverageType.values.map((t) => t.stored).toList();
    return _db
        .watchEntriesInWindowFull(dayStart.toUtc(), dayEnd.toUtc(), allTypes)
        .map((rows) => rows.map(_rowToEntry).toList());
  }

  /// Reactive stream of today's logged entries in reverse-chronological order.
  ///
  /// Every beverage type is included — hydration and alcoholic entries alike
  /// (design/user-experience.md §S6; design/party-session.md §Logging alcohol
  /// when no session is active). Soft-deleted entries are excluded.
  Stream<List<DrinkEntry>> watchTodayEntries({
    DateTime? now,
    int boundaryHour = 5,
  }) {
    final window = dayWindow(
      now: now ?? DateTime.now(),
      boundaryHour: boundaryHour,
    );
    final allTypes = BeverageType.values.map((t) => t.stored).toList();
    return _db
        .watchEntriesInWindowFull(
          window.$1.toUtc(),
          window.$2.toUtc(),
          allTypes,
        )
        .map((rows) => rows.map(_rowToEntry).toList());
  }

  /// Updates fields of an existing entry — the shared edit affordance
  /// behind S6 (Today Drinks Log) and S3 (History day drill-down); S9
  /// (Party Session Log) uses the equivalent
  /// [PartySessionRepository.updateAlcoholicEntry] for session-attached
  /// entries instead. [volumeMl], [abvPercent], [priceMinor]/[currency], and
  /// [consumedAt] are editable from every caller; [name] is additionally
  /// exposed by S3 only — S6's UI never passes it (data-model.md §Snapshot
  /// semantics: "the only path to change a DrinkEntry is a direct,
  /// deliberate user edit of that entry" — this permits, rather than
  /// forbids, editing snapshot fields; each screen's own UI decides which
  /// fields it exposes).
  ///
  /// [priceMinor]/[currency] mirror [PartySessionRepository]'s pairing rule:
  /// a **one-off, this-entry-only** override (same semantics as at log
  /// time), a present pair always writes a money price and clears any token
  /// price (money/tokens stay mutually exclusive — data-model.md
  /// §DrinkEntry), and touching them sets `manualPriceOverride`, exempting
  /// the entry from a future retroactive party-price sweep (harmless for a
  /// non-session entry, since the sweep only ever touches
  /// `partySessionId`-attached rows).
  ///
  /// Throws [ArgumentError] if [volumeMl] is provided and `< 1`, if
  /// [abvPercent] is provided and `< 0` (0 is a legal ABV — e.g. a
  /// declared-alcoholic-but-0%-ABV preset — matching [createPreset]'s and
  /// the log sheet's own advanced-editor validation, so an entry logged
  /// from such a preset can still round-trip through this method; this is
  /// intentionally more permissive than
  /// [PartySessionRepository.updateAlcoholicEntry]'s `<= 0` check — tightening
  /// this one to match would reintroduce the same round-trip bug for S6/S3
  /// that motivated relaxing it here), if [name] fails [validatePresetName],
  /// or if [priceMinor] is present with a null value but [currency] is
  /// absent (or vice versa) — clearing the price requires clearing both
  /// together. Throws [StateError] if [id] does not match a live entry.
  Future<void> updateDrinkEntry({
    required String id,
    int? volumeMl,
    DateTime? consumedAt,
    String? name,
    double? abvPercent,
    Optional<int?> priceMinor = const Optional.absent(),
    Optional<String?> currency = const Optional.absent(),
  }) async {
    if (volumeMl != null && volumeMl < 1) {
      throw ArgumentError.value(volumeMl, 'volumeMl', 'must be ≥ 1 ml');
    }
    if (abvPercent != null && abvPercent < 0) {
      throw ArgumentError.value(abvPercent, 'abvPercent', 'must be >= 0');
    }
    var normalizedName = name;
    if (name != null) {
      final result = validatePresetName(name);
      if (!result.isValid) {
        throw ArgumentError.value(name, 'name', result.error);
      }
      normalizedName = normalizeNfc(name);
    }
    if (priceMinor.isPresent != currency.isPresent) {
      throw ArgumentError(
        'priceMinor and currency must be set or cleared together',
      );
    }
    if (priceMinor.isPresent &&
        (priceMinor.value == null) != (currency.value == null)) {
      throw ArgumentError(
        'currency is required when priceMinor is set, and must be null '
        'otherwise',
      );
    }

    final now = DateTime.now().toUtc();
    final rows = await _db.updateDrinkEntryFields(
      id,
      DrinkEntriesCompanion(
        name: normalizedName != null
            ? Value(normalizedName)
            : const Value.absent(),
        volumeMl: volumeMl != null ? Value(volumeMl) : const Value.absent(),
        abvPercent:
            abvPercent != null ? Value(abvPercent) : const Value.absent(),
        consumedAt: consumedAt != null
            ? Value(consumedAt.toUtc())
            : const Value.absent(),
        priceMinor: priceMinor.isPresent
            ? Value(priceMinor.value)
            : const Value.absent(),
        currency:
            priceMinor.isPresent ? Value(currency.value) : const Value.absent(),
        // Money and tokens are mutually exclusive per drink — a one-off
        // money override on this entry must clear any prior token price.
        priceTokens:
            priceMinor.isPresent ? const Value(null) : const Value.absent(),
        tokenValueMinor:
            priceMinor.isPresent ? const Value(null) : const Value.absent(),
        tokenValueCurrency:
            priceMinor.isPresent ? const Value(null) : const Value.absent(),
        manualPriceOverride:
            priceMinor.isPresent ? const Value(true) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
    if (rows == 0) throw StateError('DrinkEntry $id not found.');
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
        priceTokens: row.priceTokens,
        tokenValueMinor: row.tokenValueMinor,
        tokenValueCurrency: row.tokenValueCurrency,
        iconKey: row.iconKey,
        iconColor: row.iconColor,
        partySessionId: row.partySessionId,
        presetId: row.presetId,
        manualPriceOverride: row.manualPriceOverride,
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
