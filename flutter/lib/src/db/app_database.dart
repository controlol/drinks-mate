import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Phase-1 Drift database — schema version 1, no feature tables yet.
///
/// Feature tables (DrinkEntry, DrinkPreset, UserProfile, etc.) are added in
/// subsequent issues on top of this migration baseline. Per D3, Account /
/// Friendship / ShareSetting must never appear in a Phase-1 migration (C0/C1).
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // TODO(db): add step-wise migrations before bumping schemaVersion;
          // v1 has no tables so upgrade is currently unreachable, but the hook
          // is here to prevent a silent startup crash when the first table lands.
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'drinks_mate.db'));
    return NativeDatabase.createInBackground(file);
  });
}
