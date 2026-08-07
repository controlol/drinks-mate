import 'package:core/core.dart';

/// Pure-Dart domain model for a meal logged within a Party Session — no
/// Drift types (D2).
///
/// data-model.md §Meal. [size] reuses `core`'s [MealSize] (small/medium/
/// large) — the same enum that drives the BAC meal-modifier calculation.
class Meal {
  const Meal({
    required this.id,
    required this.partySessionId,
    required this.size,
    required this.eatenAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String partySessionId;
  final MealSize size;

  /// When the meal was eaten. Defaults to "now" at logging, adjustable.
  final DateTime eatenAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Soft-delete marker; null means the record is live.
  final DateTime? deletedAt;
}

/// Canonical string used in the database — mirrors [BeverageType.stored].
extension MealSizeStorage on MealSize {
  String get stored => switch (this) {
        MealSize.small => 'small',
        MealSize.medium => 'medium',
        MealSize.large => 'large',
      };

  static MealSize fromStored(String value) => switch (value) {
        'small' => MealSize.small,
        'medium' => MealSize.medium,
        'large' => MealSize.large,
        _ => throw ArgumentError.value(value, 'value', 'Unknown meal size'),
      };
}
