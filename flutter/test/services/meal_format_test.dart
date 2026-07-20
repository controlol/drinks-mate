// Tests for `mealSizeLabel`/`relativeTimeAgo`
// (flutter/lib/src/services/meal_format.dart, issue #105) — pure formatting
// helpers extracted from the Party tab's `_MealIndicator` (party_screen.dart)
// so the History day drill-down's expanded session summary card
// (design/user-experience.md §S3: "size + relative time") can reuse the
// exact same rendering.
//
// Coverage:
//   1. mealSizeLabel — one case per MealSize value (small/medium/large).
//   2. relativeTimeAgo boundaries:
//      - < 1 minute floors to "1 min ago" (never "0 min ago").
//      - Just under the 60-minute transition still reads in minutes.
//      - Exactly 60 minutes reads "1 h ago" (no "0m" suffix).
//      - > 1 hour with a nonzero remainder reads "${h} h ${m}m ago".
//      - eatenAt in the future relative to now (Duration.zero floor via the
//        `d.inMinutes < 1` branch — Duration.difference can go negative, but
//        inMinutes on a negative duration is <= 0, still caught by the same
//        "< 1 -> 1 min ago" floor) does not throw or go negative.
import 'package:core/core.dart';
import 'package:drinks_mate/src/services/meal_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mealSizeLabel', () {
    test('small -> "Small"', () {
      expect(mealSizeLabel(MealSize.small), 'Small');
    });
    test('medium -> "Medium"', () {
      expect(mealSizeLabel(MealSize.medium), 'Medium');
    });
    test('large -> "Large"', () {
      expect(mealSizeLabel(MealSize.large), 'Large');
    });
  });

  group('relativeTimeAgo', () {
    final now = DateTime.utc(2026, 7, 20, 12, 0);

    test('under 1 minute floors to "1 min ago", not "0 min ago"', () {
      final eatenAt = now.subtract(const Duration(seconds: 30));
      expect(relativeTimeAgo(eatenAt, now), '1 min ago');
    });

    test('exactly 1 minute -> "1 min ago"', () {
      final eatenAt = now.subtract(const Duration(minutes: 1));
      expect(relativeTimeAgo(eatenAt, now), '1 min ago');
    });

    test('59 minutes -> "59 min ago" (still under the 60-minute transition)',
        () {
      final eatenAt = now.subtract(const Duration(minutes: 59));
      expect(relativeTimeAgo(eatenAt, now), '59 min ago');
    });

    test('exactly 60 minutes -> "1 h ago" (no "0m" suffix)', () {
      final eatenAt = now.subtract(const Duration(minutes: 60));
      expect(relativeTimeAgo(eatenAt, now), '1 h ago');
    });

    test('2 hours exactly -> "2 h ago"', () {
      final eatenAt = now.subtract(const Duration(hours: 2));
      expect(relativeTimeAgo(eatenAt, now), '2 h ago');
    });

    test('2 hours 30 minutes -> "2 h 30m ago"', () {
      final eatenAt = now.subtract(const Duration(hours: 2, minutes: 30));
      expect(relativeTimeAgo(eatenAt, now), '2 h 30m ago');
    });

    test(
        'eatenAt after now (negative elapsed) does not throw and still '
        'floors to "1 min ago", not a negative reading', () {
      final eatenAt = now.add(const Duration(minutes: 5));
      expect(() => relativeTimeAgo(eatenAt, now), returnsNormally);
      expect(relativeTimeAgo(eatenAt, now), '1 min ago');
    });
  });
}
