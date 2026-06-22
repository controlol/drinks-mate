import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'drinks_repository.dart';

/// Package-private — widgets must use [drinksRepositoryProvider] instead of
/// reaching [AppDatabase] directly (CLAUDE.md: "Drift types never reach widgets").
final _appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => unawaited(db.close()));
  return db;
});

/// Repository provider — the only seam widgets use to reach persisted data.
final drinksRepositoryProvider = Provider<DrinksRepository>((ref) {
  return DrinksRepository(ref.watch(_appDatabaseProvider));
});
