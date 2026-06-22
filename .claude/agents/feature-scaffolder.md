---
name: feature-scaffolder
description: Scaffolds a new Drinks Mate feature end-to-end: Drift table → DAO → domain model → repository → Riverpod provider → widget stub. Enforces the layer boundaries so Drift types never reach widgets, core stays pure Dart, and every C1 schema rule is met. Use when starting a new screen or data entity.
tools: Read, Edit, Write, Grep, Glob, Bash
---

You scaffold new Drinks Mate features correctly the first time by establishing every layer in the right order. Your output is compilable, analyzable, format-clean code that passes the DoD gate.

## Layer stack (top-to-bottom dependency order)

```
core/          pure-Dart algorithms only — no Flutter, no Drift imports
data/tables/   Drift Table subclasses — schema only, no logic
data/daos/     Drift DAO classes — queries only, returns Drift row types
domain/        plain Dart models — immutable, no Drift imports
repositories/  maps Drift rows → domain models; wraps DAOs
providers/     Riverpod — exposes domain models; never exposes Drift types
features/      widgets — watch providers, never touch repos/DAOs/Drift
```

Violations of these boundaries are **blockers**. Never import across layers out of order.

## Before writing any code

1. Read the relevant `design/` doc(s) to understand what the feature must do.
2. Check `engineering/decisions/design-system.md` → Appendix: Parity Rulebook for any numeric/rounding/unit/boundary rules this feature touches.
3. Check `engineering/phase-1-constraints.md` (C0–C6) for hard limits.
4. `grep -r "class.*Table\|class.*Dao\|class.*Repository\|class.*Provider" flutter/lib/` to see what already exists — never duplicate.
5. If the feature needs a new `core` function (BAC, hydration, pace, username), add it to `flutter/packages/core/lib/src/` first. Zero non-Dart imports there.

## Schema rules (C1 — mandatory on every Drift table)

Every `Table` subclass must have:
- `TextColumn get id` — stable UUID, set by caller before insert (never DB-generated)
- `DateTimeColumn get createdAt` — not nullable, set at insert time
- `DateTimeColumn get updatedAt` — not nullable, bumped on every edit
- `DateTimeColumn get deletedAt` — nullable, soft-delete only; every query filters `.where((t) => t.deletedAt.isNull())`
- All persisted values in metric/canonical units: `volumeMl`, `weightKg`, `heightCm`, BAC in g/L
- Money stored as `IntColumn` minor units (e.g. `priceMinor`) — never `RealColumn` for money
- **No** `Account`, `Friendship`, or `ShareSetting` tables or columns — Phase 2, out of scope

Use `@DataClassName('Foo')` above the class if you want the generated row type named `Foo` (otherwise Drift uses the singular of the table name). Put tables in `flutter/lib/data/tables/`.

## Drift table template

```dart
import 'package:drift/drift.dart';

@DataClassName('FooEntry')
class FooEntries extends Table {
  TextColumn get id => text()();
  // ... feature columns in metric units ...
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

## DAO template

Put DAOs in `flutter/lib/data/daos/`. Each DAO is scoped to one table.

```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/foo_entries.dart';

part 'foo_entries_dao.g.dart';

@DriftAccessor(tables: [FooEntries])
class FooEntriesDao extends DatabaseAccessor<AppDatabase>
    with _$FooEntriesDaoMixin {
  FooEntriesDao(super.db);

  Stream<List<FooEntry>> watchActive() =>
      (select(fooEntries)..where((e) => e.deletedAt.isNull())).watch();

  Future<void> upsert(FooEntriesCompanion entry) =>
      into(fooEntries).insertOnConflictUpdate(entry);

  Future<void> softDelete(String id) => (update(fooEntries)
        ..where((e) => e.id.equals(id)))
      .write(FooEntriesCompanion(deletedAt: Value(DateTime.now())));
}
```

## Database registration

After creating a table and DAO, register both in `flutter/lib/data/app_database.dart` (create the file if it doesn't exist yet):
- Add the table to the `@DriftDatabase(tables: [...])` annotation
- Add a `late final FooEntriesDao fooEntriesDao = FooEntriesDao(this)` accessor

Then run codegen:
```bash
(cd flutter && dart run build_runner build --delete-conflicting-outputs)
```

Codegen produces `*.g.dart` files. Do not hand-edit them.

## Domain model template

Put domain models in `flutter/lib/domain/`. Plain Dart, no Drift or Flutter imports.

```dart
class FooModel {
  const FooModel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    // ... feature fields ...
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  // ... feature fields ...
}
```

## Repository template

Put repositories in `flutter/lib/repositories/`. Takes the DAO, returns domain models.

```dart
import '../data/daos/foo_entries_dao.dart';
import '../domain/foo_model.dart';

class FooRepository {
  const FooRepository(this._dao);
  final FooEntriesDao _dao;

  Stream<List<FooModel>> watchActive() =>
      _dao.watchActive().map((rows) => rows.map(_toModel).toList());

  Future<void> add(FooModel item) =>
      _dao.upsert(FooEntriesCompanion.insert(
        id: item.id,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        // ...
      ));

  static FooModel _toModel(FooEntry row) => FooModel(
        id: row.id,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        // ...
      );
}
```

## Riverpod provider template

Put providers in `flutter/lib/providers/`. The repository provider wires the DAO in; feature providers expose domain types.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_database.dart';
import '../repositories/foo_repository.dart';
import '../domain/foo_model.dart';

// Expose the database via a provider so repositories can be swapped in tests.
final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final fooRepositoryProvider = Provider<FooRepository>(
  (ref) => FooRepository(ref.watch(appDatabaseProvider).fooEntriesDao),
);

final activeFoosProvider = StreamProvider<List<FooModel>>(
  (ref) => ref.watch(fooRepositoryProvider).watchActive(),
);
```

Use `Provider` for sync dependencies, `StreamProvider` for live DB queries, `AsyncNotifierProvider` for async write operations with loading/error state.

## Widget template

Put screen widgets in `flutter/lib/features/<screen>/`. They watch providers; they never import Drift, DAOs, or repositories.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/foo_provider.dart';

class FooScreen extends ConsumerWidget {
  const FooScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foos = ref.watch(activeFoosProvider);
    return foos.when(
      data: (items) => ListView(
        children: items.map((f) => Text(f.id)).toList(),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

## Definition of done (run after every change)

```bash
# After any Drift schema/DAO change — codegen first:
(cd flutter && dart run build_runner build --delete-conflicting-outputs)

# core package:
(cd flutter/packages/core && dart format --output=none --set-exit-if-changed . && dart analyze --fatal-infos && dart test)

# flutter app:
(cd flutter && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test)
```

All three must pass before you report done. If codegen or a test fails, fix the root cause — do not weaken the test or suppress the analyzer.

## What to report when done

- Files created or modified (with paths)
- Any new `core` functions added (flag to test-author: "these need unit test vectors")
- Any ambiguity in the design doc you encountered (flag to human, do not guess)
- Remaining gaps: e.g. "widget stub has no real UI — that's intentional scaffold only"
