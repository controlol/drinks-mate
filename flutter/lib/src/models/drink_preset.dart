import 'beverage_type.dart';

/// Pure-Dart domain model for a drink preset — no Drift types (D2).
///
/// Widgets and [DrinksRepository] use this; [AppDatabase] converts
/// Drift row → [DrinkPreset] before returning.
class DrinkPreset {
  const DrinkPreset({
    required this.id,
    required this.name,
    required this.beverageType,
    required this.volumeMl,
    this.abvPercent,
    this.regularPriceMinor,
    this.regularCurrency,
    required this.iconKey,
    required this.iconColor,
    required this.isUserCreated,
    required this.isHidden,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final BeverageType beverageType;
  final int volumeMl;
  final double? abvPercent;
  final int? regularPriceMinor;
  final String? regularCurrency;
  final String iconKey;
  final String iconColor;
  final bool isUserCreated;
  final bool isHidden;
  final int sortOrder;
}
