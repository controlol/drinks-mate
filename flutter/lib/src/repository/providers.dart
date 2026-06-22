import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../models/drink_preset.dart';
import 'drinks_repository.dart';

/// Package-private — widgets use [drinksRepositoryProvider] instead of
/// reaching [AppDatabase] directly (D2: Drift types never reach widgets).
final _appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => unawaited(db.close()));
  return db;
});

/// Repository provider — the only seam widgets use to reach persisted data.
final drinksRepositoryProvider = Provider<DrinksRepository>((ref) {
  return DrinksRepository(ref.watch(_appDatabaseProvider));
});

/// Stream of visible (non-hidden, non-deleted) presets, sorted by sortOrder.
final visiblePresetsProvider = StreamProvider<List<DrinkPreset>>((ref) {
  return ref.watch(drinksRepositoryProvider).watchVisiblePresets();
});

/// Reactive stream of today's total intake in ml.
/// Updates automatically whenever a drink is logged or deleted.
///
/// Re-subscribes at each 05:00 day boundary so the query window rolls over
/// without requiring an app restart.
final todayTotalMlProvider = StreamProvider<int>((ref) {
  final now = DateTime.now();
  final nextBoundary = dayWindow(now: now).$2;
  final timer = Timer(nextBoundary.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(drinksRepositoryProvider).watchTodayTotalMl(now: now);
});
