import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'drinks_repository.dart';

/// Lazily opens the Drift database. Nothing in the placeholder shell reads
/// this provider, so widget tests never trigger [NativeDatabase] construction.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Repository provider — the only seam widgets use to reach persisted data.
final drinksRepositoryProvider = Provider<DrinksRepository>((ref) {
  return DrinksRepository(ref.watch(appDatabaseProvider));
});
