/// Pure-Dart domain model for per-device user preferences (singleton).
///
/// All time-of-day values are integer hours (0–23). installedAt is a [DateTime]
/// in the domain model; the repository maps to/from epoch-ms in the DB.
/// No Drift types — the repository maps [UserPreferencesRow] → [UserPreferences].
class UserPreferences {
  const UserPreferences({
    required this.id,
    required this.dailyGoalMl,
    required this.dayBoundaryHour,
    required this.units,
    required this.currency,
    required this.reminderEnabled,
    required this.reminderStartHour,
    required this.reminderEndHour,
    required this.reminderIntervalMin,
    required this.inactivityReminderEnabled,
    required this.weeklySummaryEnabled,
    this.defaultDrinkPresetId,
    this.bacCapGramsPerL,
    required this.bacOnLockScreenEnabled,
    required this.approachingCapNotifEnabled,
    required this.soberEstimateNotifEnabled,
    required this.installedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// Daily hydration goal in millilitres (metric canonical).
  final int dailyGoalMl;

  /// Hour-of-day (0–23) when the new "day" begins for goal tracking.
  final int dayBoundaryHour;

  /// 'metric' | 'imperial' — affects display only; storage is always metric.
  final String units;

  /// 'EUR' | 'USD' | 'GBP'.
  final String currency;

  final bool reminderEnabled;

  /// Hour-of-day (0–23) when the reminder active window opens.
  final int reminderStartHour;

  /// Hour-of-day (0–23) when the reminder active window closes.
  final int reminderEndHour;

  /// Reminder interval in minutes.
  final int reminderIntervalMin;

  final bool inactivityReminderEnabled;
  final bool weeklySummaryEnabled;

  /// ID of the user's chosen default drink preset. Null → fall back to seeded
  /// "Glass of water" or hardcoded 200 ml water (data-model.md §UserPreferences).
  final String? defaultDrinkPresetId;

  /// Personal BAC cap in g/L. Null = no cap set.
  final double? bacCapGramsPerL;

  final bool bacOnLockScreenEnabled;

  /// Party Mode notifications — default OFF (notifications.md §4).
  final bool approachingCapNotifEnabled;
  final bool soberEstimateNotifEnabled;

  /// When the local database was first created on this device.
  final DateTime installedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  UserPreferences copyWith({
    String? id,
    int? dailyGoalMl,
    int? dayBoundaryHour,
    String? units,
    String? currency,
    bool? reminderEnabled,
    int? reminderStartHour,
    int? reminderEndHour,
    int? reminderIntervalMin,
    bool? inactivityReminderEnabled,
    bool? weeklySummaryEnabled,
    Object? defaultDrinkPresetId = _sentinel,
    Object? bacCapGramsPerL = _sentinel,
    bool? bacOnLockScreenEnabled,
    bool? approachingCapNotifEnabled,
    bool? soberEstimateNotifEnabled,
    DateTime? installedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      id: id ?? this.id,
      dailyGoalMl: dailyGoalMl ?? this.dailyGoalMl,
      dayBoundaryHour: dayBoundaryHour ?? this.dayBoundaryHour,
      units: units ?? this.units,
      currency: currency ?? this.currency,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderStartHour: reminderStartHour ?? this.reminderStartHour,
      reminderEndHour: reminderEndHour ?? this.reminderEndHour,
      reminderIntervalMin: reminderIntervalMin ?? this.reminderIntervalMin,
      inactivityReminderEnabled:
          inactivityReminderEnabled ?? this.inactivityReminderEnabled,
      weeklySummaryEnabled: weeklySummaryEnabled ?? this.weeklySummaryEnabled,
      defaultDrinkPresetId: defaultDrinkPresetId == _sentinel
          ? this.defaultDrinkPresetId
          : defaultDrinkPresetId as String?,
      bacCapGramsPerL: bacCapGramsPerL == _sentinel
          ? this.bacCapGramsPerL
          : bacCapGramsPerL as double?,
      bacOnLockScreenEnabled:
          bacOnLockScreenEnabled ?? this.bacOnLockScreenEnabled,
      approachingCapNotifEnabled:
          approachingCapNotifEnabled ?? this.approachingCapNotifEnabled,
      soberEstimateNotifEnabled:
          soberEstimateNotifEnabled ?? this.soberEstimateNotifEnabled,
      installedAt: installedAt ?? this.installedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const _sentinel = Object();
