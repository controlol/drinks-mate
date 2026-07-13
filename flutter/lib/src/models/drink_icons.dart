/// Bundled drink-icon catalog — features.md F14 "Icon (bundled SVG set)".
///
/// Every key here has a matching `assets/icons/<key>.svg`, drawn with the
/// two sentinel fills [kSilhouettePlaceholder]/[kDetailPlaceholder] (see
/// `widgets/tinted_icon.dart`) so [TintedIcon] can tint it at render time.
/// The slot list and order match the design docs exactly; final artwork is
/// still `[OPEN]` per designer-brief.md — these are simple geometric
/// stand-ins for each slot, not final art.
const List<String> kDrinkIconKeys = [
  'glass',
  'bottle',
  'can',
  'mug',
  'small_cup',
  'wine_glass',
  'beer_glass',
  'plastic_cup',
  'cocktail',
  'shot_glass',
];

/// Resolves a [DrinkPreset.iconKey] to its bundled SVG asset path.
String drinkIconAssetPath(String iconKey) => 'assets/icons/$iconKey.svg';
