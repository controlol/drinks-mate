import 'package:core/core.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';

/// Repository seam for user preferences and profile data (D2).
///
/// Converts Drift row types ([UserPreferencesRow], [UserProfileRow]) to
/// pure-Dart domain models ([UserPreferences], [UserProfile]) before returning.
/// Drift types never escape this class.
class PreferencesRepository {
  PreferencesRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // UserPreferences — singleton CRUD
  // ---------------------------------------------------------------------------

  /// Reactive stream of the [UserPreferences] singleton.
  Stream<UserPreferences> watchPreferences() =>
      _db.watchPreferences().map(_rowToPreferences);

  /// One-shot read of the [UserPreferences] singleton.
  Future<UserPreferences> getPreferences() async =>
      _rowToPreferences(await _db.getPreferences());

  /// Update the daily hydration goal.
  Future<void> updateDailyGoal(int dailyGoalMl) => _db.updatePreferences(
        UserPreferencesTableCompanion(
          dailyGoalMl: Value(dailyGoalMl),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Update the day-boundary hour (0–23).
  Future<void> updateDayBoundaryHour(int hour) => _db.updatePreferences(
        UserPreferencesTableCompanion(
          dayBoundaryHour: Value(hour),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Update the display units ('metric' | 'imperial').
  Future<void> updateUnits(String units) => _db.updatePreferences(
        UserPreferencesTableCompanion(
          units: Value(units),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Update the preferred currency ('EUR' | 'USD' | 'GBP').
  Future<void> updateCurrency(String currency) => _db.updatePreferences(
        UserPreferencesTableCompanion(
          currency: Value(currency),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Update the reminder schedule fields as a group.
  Future<void> updateReminderSchedule({
    bool? reminderEnabled,
    int? startHour,
    int? endHour,
    int? intervalMin,
  }) =>
      _db.updatePreferences(
        UserPreferencesTableCompanion(
          reminderEnabled: reminderEnabled != null
              ? Value(reminderEnabled)
              : const Value.absent(),
          reminderStartHour:
              startHour != null ? Value(startHour) : const Value.absent(),
          reminderEndHour:
              endHour != null ? Value(endHour) : const Value.absent(),
          reminderIntervalMin:
              intervalMin != null ? Value(intervalMin) : const Value.absent(),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Update the notification toggles (inactivity, weekly summary).
  Future<void> updateNotificationToggles({
    bool? inactivityReminderEnabled,
    bool? weeklySummaryEnabled,
  }) =>
      _db.updatePreferences(
        UserPreferencesTableCompanion(
          inactivityReminderEnabled: inactivityReminderEnabled != null
              ? Value(inactivityReminderEnabled)
              : const Value.absent(),
          weeklySummaryEnabled: weeklySummaryEnabled != null
              ? Value(weeklySummaryEnabled)
              : const Value.absent(),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Update the default drink preset reference.
  Future<void> updateDefaultDrinkPreset(String? presetId) =>
      _db.updatePreferences(
        UserPreferencesTableCompanion(
          defaultDrinkPresetId: Value(presetId),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Update the BAC cap (g/L canonical; null clears the cap).
  Future<void> updateBacCap(double? bacCapGramsPerL) => _db.updatePreferences(
        UserPreferencesTableCompanion(
          bacCapGramsPerL: Value(bacCapGramsPerL),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Update the Party Mode notification and lock-screen settings.
  Future<void> updatePartyModeSettings({
    bool? bacOnLockScreenEnabled,
    bool? approachingCapNotifEnabled,
    bool? soberEstimateNotifEnabled,
  }) =>
      _db.updatePreferences(
        UserPreferencesTableCompanion(
          bacOnLockScreenEnabled: bacOnLockScreenEnabled != null
              ? Value(bacOnLockScreenEnabled)
              : const Value.absent(),
          approachingCapNotifEnabled: approachingCapNotifEnabled != null
              ? Value(approachingCapNotifEnabled)
              : const Value.absent(),
          soberEstimateNotifEnabled: soberEstimateNotifEnabled != null
              ? Value(soberEstimateNotifEnabled)
              : const Value.absent(),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  // ---------------------------------------------------------------------------
  // UserProfile — watch / upsert
  // ---------------------------------------------------------------------------

  /// Reactive stream of the live [UserProfile]; null until onboarding writes it.
  Stream<UserProfile?> watchProfile() =>
      _db.watchProfile().map((row) => row == null ? null : _rowToProfile(row));

  /// One-shot read of the live [UserProfile]; null until onboarding writes it.
  Future<UserProfile?> getProfile() async {
    final row = await _db.getProfile();
    return row == null ? null : _rowToProfile(row);
  }

  /// Update the username (NFC-normalised, validated, then stored).
  ///
  /// NFC-normalises the input before validation and storage so visually
  /// identical inputs produce the same stored bytes (data-model.md §Username).
  Future<void> updateUsername(String username) {
    final normalized = normalizeNfc(username);
    final validation = validateUsername(normalized);
    if (!validation.isValid) {
      throw ArgumentError.value(username, 'username', validation.error);
    }
    return _db.updatePreferences(
      UserPreferencesTableCompanion(
        username: Value(normalized),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Atomically writes the onboarding result: username + daily goal + profile.
  ///
  /// The profile row is written first; the username is written last so it acts
  /// as the commit marker for the onboarding gate in [_AppGate]. If either
  /// write fails, Drift rolls back the transaction and the gate remains on the
  /// onboarding flow.
  ///
  /// NFC-normalises and validates [username] before persisting (data-model.md
  /// §Username rules). Throws [ArgumentError] on invalid username.
  Future<void> completeOnboarding({
    required String username,
    required UserProfile profile,
    required int dailyGoalMl,
  }) async {
    final normalized = normalizeNfc(username);
    final validation = validateUsername(normalized);
    if (!validation.isValid) {
      throw ArgumentError.value(username, 'username', validation.error);
    }
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await _db.upsertProfile(
        UserProfilesCompanion(
          id: Value(profile.id),
          gender: Value(profile.gender),
          weightKg: Value(profile.weightKg),
          heightCm: Value(profile.heightCm),
          birthDate: Value(profile.birthDate),
          createdAt: Value(profile.createdAt),
          updatedAt: Value(now),
          deletedAt: Value(profile.deletedAt),
        ),
      );
      await _db.updatePreferences(
        UserPreferencesTableCompanion(
          username: Value(normalized),
          dailyGoalMl: Value(dailyGoalMl),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Create or replace the user profile.
  ///
  /// [profile.id] must be a stable UUID — callers should generate it once and
  /// keep it (e.g. stored in the returned [UserProfile]). Passing the same id
  /// on subsequent calls updates the existing row (ON CONFLICT REPLACE).
  Future<void> upsertProfile(UserProfile profile) async {
    if (profile.id.isEmpty) {
      throw ArgumentError.value(
        profile.id,
        'profile.id',
        'must be a non-empty UUID',
      );
    }
    final now = DateTime.now().toUtc();
    await _db.upsertProfile(
      UserProfilesCompanion(
        id: Value(profile.id),
        gender: Value(profile.gender),
        weightKg: Value(profile.weightKg),
        heightCm: Value(profile.heightCm),
        birthDate: Value(profile.birthDate),
        createdAt: Value(profile.createdAt),
        updatedAt: Value(now),
        deletedAt: Value(profile.deletedAt),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers — Drift row → domain model
  // ---------------------------------------------------------------------------

  static UserPreferences _rowToPreferences(UserPreferencesRow row) =>
      UserPreferences(
        id: row.id,
        username: row.username,
        dailyGoalMl: row.dailyGoalMl,
        dayBoundaryHour: row.dayBoundaryHour,
        units: row.units,
        currency: row.currency,
        reminderEnabled: row.reminderEnabled,
        reminderStartHour: row.reminderStartHour,
        reminderEndHour: row.reminderEndHour,
        reminderIntervalMin: row.reminderIntervalMin,
        inactivityReminderEnabled: row.inactivityReminderEnabled,
        weeklySummaryEnabled: row.weeklySummaryEnabled,
        defaultDrinkPresetId: row.defaultDrinkPresetId,
        bacCapGramsPerL: row.bacCapGramsPerL,
        bacOnLockScreenEnabled: row.bacOnLockScreenEnabled,
        approachingCapNotifEnabled: row.approachingCapNotifEnabled,
        soberEstimateNotifEnabled: row.soberEstimateNotifEnabled,
        installedAt: DateTime.fromMillisecondsSinceEpoch(
          row.installedAt,
          isUtc: true,
        ),
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  static UserProfile _rowToProfile(UserProfileRow row) => UserProfile(
        id: row.id,
        gender: row.gender,
        weightKg: row.weightKg,
        heightCm: row.heightCm,
        birthDate: row.birthDate,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
      );
}
