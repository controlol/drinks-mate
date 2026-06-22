/// Fixed beverage type enum — data-model.md §BeverageType.
///
/// Non-alcoholic types contribute to hydration progress.
/// Alcoholic types contribute to BAC and do NOT add to daily hydration.
enum BeverageType {
  water,
  coffee,
  tea,
  juice,
  softDrink,
  milk,
  nonAlcoholicBeer,
  other,
  // Alcoholic — only logged during an active Party Session (Phase 1).
  beer,
  wine,
  spirit,
  cocktail,
  otherAlcohol;

  bool get isAlcoholic => switch (this) {
        beer || wine || spirit || cocktail || otherAlcohol => true,
        _ => false,
      };

  /// Canonical string used in the database (matches data-model.md).
  String get stored => switch (this) {
        water => 'water',
        coffee => 'coffee',
        tea => 'tea',
        juice => 'juice',
        softDrink => 'soft_drink',
        milk => 'milk',
        nonAlcoholicBeer => 'non_alcoholic_beer',
        other => 'other',
        beer => 'beer',
        wine => 'wine',
        spirit => 'spirit',
        cocktail => 'cocktail',
        otherAlcohol => 'other_alcohol',
      };

  static BeverageType fromStored(String value) => switch (value) {
        'water' => water,
        'coffee' => coffee,
        'tea' => tea,
        'juice' => juice,
        'soft_drink' => softDrink,
        'milk' => milk,
        'non_alcoholic_beer' => nonAlcoholicBeer,
        'other' => other,
        'beer' => beer,
        'wine' => wine,
        'spirit' => spirit,
        'cocktail' => cocktail,
        'other_alcohol' => otherAlcohol,
        _ => throw ArgumentError('Unknown beverage type: $value'),
      };

  String get displayName => switch (this) {
        water => 'Water',
        coffee => 'Coffee',
        tea => 'Tea',
        juice => 'Juice',
        softDrink => 'Soft drink',
        milk => 'Milk',
        nonAlcoholicBeer => 'Non-alcoholic beer',
        other => 'Other',
        beer => 'Beer',
        wine => 'Wine',
        spirit => 'Spirit',
        cocktail => 'Cocktail',
        otherAlcohol => 'Other alcoholic',
      };

  /// Default icon colour per beverage type (hex, #rrggbb).
  /// Source: features.md F14 — "Default colours per beverage type".
  String get defaultIconColor => switch (this) {
        water => '#3b82f6',
        coffee => '#92400e',
        tea => '#15803d',
        juice => '#ea580c',
        softDrink => '#7c3aed',
        milk => '#d1d5db',
        nonAlcoholicBeer => '#b45309',
        other => '#6b7280',
        beer => '#d97706',
        wine => '#be185d',
        spirit => '#0369a1',
        cocktail => '#0d9488',
        otherAlcohol => '#374151',
      };
}
