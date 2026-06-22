import '../db/app_database.dart';

/// Empty repository seam for Phase 1.
///
/// Drink-entry persistence methods land here once the DrinkEntry table is
/// added in a subsequent issue. Widgets always touch the database through this
/// class — never directly via Drift types (D2).
class DrinksRepository {
  const DrinksRepository(this._db);

  // ignore: unused_field — referenced by methods that land in subsequent issues.
  final AppDatabase _db;
}
