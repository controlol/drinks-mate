import 'package:drift/drift.dart';

/// Drift table for user preferences — a singleton row per device.
///
/// Schema v3 addition. Enforced singleton via a well-known primary key
/// [kUserPreferencesId]. No deletedAt (never deleted).
/// All time-of-day values stored as INTEGER hour-of-day (0–23) per issue spec.
/// installedAt stored as INTEGER epoch-milliseconds (set once on first launch).
///
/// [DataClassName] avoids a name collision with the pure-Dart domain model
/// [UserPreferences] in lib/src/models/user_preferences.dart.
@DataClassName('UserPreferencesRow')
class UserPreferencesTable extends Table {
  @override
  String get tableName => 'user_preferences';

  TextColumn get id => text()();

  /// Display username — NFC-normalised before storing (Parity Rulebook §Username).
  /// Null until the user completes onboarding.
  TextColumn get username => text().nullable()();

  /// Daily hydration goal in millilitres (metric canonical — C1).
  /// Updated during onboarding. Seeded to 2000 ml as a placeholder.
  IntColumn get dailyGoalMl => integer()();

  /// Hour-of-day when the new "day" begins for goal tracking (0–23).
  IntColumn get dayBoundaryHour => integer().withDefault(const Constant(5))();

  /// Display unit preference: 'metric' | 'imperial'. Storage is always metric.
  TextColumn get units => text().withDefault(const Constant('metric'))();

  /// Preferred currency: 'EUR' | 'USD' | 'GBP'.
  TextColumn get currency => text().withDefault(const Constant('EUR'))();

  BoolColumn get reminderEnabled => boolean()();

  /// Hour-of-day when the reminder active window starts (default 8 = 08:00).
  IntColumn get reminderStartHour => integer().withDefault(const Constant(8))();

  /// Hour-of-day when the reminder active window ends (default 22 = 22:00).
  IntColumn get reminderEndHour => integer().withDefault(const Constant(22))();

  /// How often to remind, in minutes.
  IntColumn get reminderIntervalMin =>
      integer().withDefault(const Constant(90))();

  BoolColumn get inactivityReminderEnabled => boolean()();
  BoolColumn get weeklySummaryEnabled => boolean()();

  /// FK to DrinkPresets.id. Nullable — falls back to seeded "Glass of water".
  TextColumn get defaultDrinkPresetId => text().nullable()();

  /// Optional personal BAC cap, g/L canonical. Null = no cap.
  RealColumn get bacCapGramsPerL => real().nullable()();

  BoolColumn get bacOnLockScreenEnabled => boolean()();

  /// Party Mode notification toggles — default OFF per notifications.md §4.
  BoolColumn get approachingCapNotifEnabled => boolean()();
  BoolColumn get soberEstimateNotifEnabled => boolean()();

  /// Schema v5 addition. When `true` (default), alcoholic presets are always
  /// shown in the Manage Drinks screen (F14). When `false`, they're shown
  /// only while a [PartySession] is active (`endedAt IS NULL`) — see
  /// `ManageDrinksScreen`'s doc comment for the full rationale.
  BoolColumn get alcoholicPresetsAlwaysVisible =>
      boolean().withDefault(const Constant(true))();

  /// Schema v6 addition. One of `manual` / `recentlyUsed` / `mostUsed`
  /// (see `PresetSortMode` in `core`) — the sort mode shared by the Today
  /// "Log a drink" grid and the S2 log-drink picker (features.md F14 §Sort
  /// modes). Default `recentlyUsed`.
  TextColumn get drinkSortMode =>
      text().withDefault(const Constant('recentlyUsed'))();

  /// Epoch-milliseconds of when the local database was first created.
  /// Set once in beforeOpen; never changes.
  IntColumn get installedAt => integer()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
