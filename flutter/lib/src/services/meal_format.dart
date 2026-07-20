import 'package:core/core.dart';

/// Shared "size" label for a logged [MealSize] — the Party tab's meal
/// indicator and the History day drill-down's expanded session summary
/// card's full meals list (user-experience.md §S3 expand) both render
/// meals as "<size> meal · <relative time>".
String mealSizeLabel(MealSize size) => switch (size) {
      MealSize.small => 'Small',
      MealSize.medium => 'Medium',
      MealSize.large => 'Large',
    };

/// Shared "N min/h ago" relative-time formatting for a meal's `eatenAt`
/// against [now]. See [mealSizeLabel].
String relativeTimeAgo(DateTime eatenAt, DateTime now) {
  final d = now.difference(eatenAt);
  if (d.inMinutes < 60) {
    return '${d.inMinutes < 1 ? 1 : d.inMinutes} min ago';
  }
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  return minutes == 0 ? '$hours h ago' : '$hours h ${minutes}m ago';
}
