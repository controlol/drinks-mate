import 'package:shared_preferences/shared_preferences.dart';

// Once-per-day guard for the goal-met celebration.
//
// Designer-brief §Goal-met celebration: fires once the first time the user
// crosses their daily goal each day; does not re-fire even if the user drops
// below goal and re-crosses upward later the same day.
//
// The guard key maps to an ISO date string of the day-window start so it
// respects the configurable day-boundary hour (UserPreferences.dayBoundaryHour).

abstract interface class GoalCelebrationGuard {
  Future<bool> shouldShowForDay(DateTime dayWindowStart);
  Future<void> markShownForDay(DateTime dayWindowStart);
}

// Production implementation backed by SharedPreferences.
class SharedPrefsGoalCelebrationGuard implements GoalCelebrationGuard {
  static const _key = 'goal_celebration_date';

  @override
  Future<bool> shouldShowForDay(DateTime dayWindowStart) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    return stored != _dateKey(dayWindowStart);
  }

  @override
  Future<void> markShownForDay(DateTime dayWindowStart) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _dateKey(dayWindowStart));
  }

  static String _dateKey(DateTime dayWindowStart) =>
      dayWindowStart.toIso8601String().substring(0, 10);
}

// In-memory implementation for widget tests — no SharedPreferences I/O.
class InMemoryGoalCelebrationGuard implements GoalCelebrationGuard {
  String? _shownDate;

  @override
  Future<bool> shouldShowForDay(DateTime dayWindowStart) async =>
      _shownDate != _dateKey(dayWindowStart);

  @override
  Future<void> markShownForDay(DateTime dayWindowStart) async =>
      _shownDate = _dateKey(dayWindowStart);

  static String _dateKey(DateTime dayWindowStart) =>
      dayWindowStart.toIso8601String().substring(0, 10);
}
