/// Drinks Mate computation core — pure Dart, no Flutter/Drift imports.
///
/// Every function here implements a rule from the **Parity Rulebook**
/// (`engineering/decisions/design-system.md` → Appendix). Because there is a
/// single implementation, iOS/Android parity holds by construction (D7).
///
/// All computation is in metric / canonical units (ml, kg, cm, g/L). Formatting
/// and imperial conversion happen only at the display boundary.
library core;

export 'src/age.dart';
export 'src/bac.dart';
export 'src/day_boundary.dart';
export 'src/hydration.dart';
export 'src/icon_color.dart';
export 'src/pace.dart';
export 'src/preset_ranking.dart';
export 'src/units.dart';
export 'src/username.dart';
export 'src/notification_guard.dart';
