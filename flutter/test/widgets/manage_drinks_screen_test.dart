// Widget tests for F14 "Manage drinks" — ManageDrinksScreen.
//
// Coverage:
//  1. Empty state shows "No drink presets yet." text.
//  2. Populated list shows preset name + volume for each preset.
//  3. A hidden preset shows the visibility_off icon; a visible one does not.
//
// Provider override pattern mirrors
// flutter/test/widgets/today_drinks_screen_test.dart — a fake
// DrinksRepository subclass records nothing here (the screen is read-only)
// but avoids touching the real DB by overriding drinksRepositoryProvider
// with an in-memory-backed instance whose watchAllPresets() stream is
// stubbed directly.
//
// Source: manage_drinks_screen.dart — read-only ListView.builder of
// ListTiles (name + volume; isHidden -> trailing visibility_off_outlined
// icon). See its doc comment for why this is intentionally minimal (issue
// #17's full CRUD UI never shipped; see the #18 PR description).

import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/manage_drinks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repository — stubs watchAllPresets(); never touches the real DB.
// ---------------------------------------------------------------------------

class _FakeDrinksRepo extends DrinksRepository {
  _FakeDrinksRepo(this._presets) : super(AppDatabase(NativeDatabase.memory()));

  final List<DrinkPreset> _presets;

  @override
  Stream<List<DrinkPreset>> watchAllPresets() => Stream.value(_presets);
}

DrinkPreset _preset({
  required String id,
  required String name,
  int volumeMl = 250,
  bool isHidden = false,
  BeverageType beverageType = BeverageType.water,
}) {
  return DrinkPreset(
    id: id,
    name: name,
    beverageType: beverageType,
    volumeMl: volumeMl,
    iconKey: 'glass',
    iconColor: beverageType.defaultIconColor,
    isUserCreated: false,
    isHidden: isHidden,
    sortOrder: 0,
  );
}

Widget _buildScreen(List<DrinkPreset> presets) {
  return ProviderScope(
    overrides: [
      drinksRepositoryProvider.overrideWithValue(_FakeDrinksRepo(presets)),
    ],
    child: const MaterialApp(home: ManageDrinksScreen()),
  );
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Empty state
  // -------------------------------------------------------------------------

  testWidgets('empty state shows "No drink presets yet." text', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScreen(const []));
    await tester.pump(); // let the StreamProvider deliver []

    // Source: manage_drinks_screen.dart ManageDrinksScreen.build — empty
    // branch of presetsAsync.when.
    expect(find.text('No drink presets yet.'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Populated list shows preset name + volume
  // -------------------------------------------------------------------------

  testWidgets('populated list shows preset name and volume', (tester) async {
    final presets = [
      _preset(id: 'p1', name: 'Glass of water', volumeMl: 250),
      _preset(
          id: 'p2',
          name: 'Espresso',
          volumeMl: 60,
          beverageType: BeverageType.coffee),
    ];

    await tester.pumpWidget(_buildScreen(presets));
    await tester.pump();

    expect(find.text('Glass of water'), findsOneWidget);
    // Source: manage_drinks_screen.dart ListTile subtitle: '${preset.volumeMl} ml'.
    expect(find.text('250 ml'), findsOneWidget);

    expect(find.text('Espresso'), findsOneWidget);
    expect(find.text('60 ml'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Hidden preset shows visibility_off icon; visible one does not
  // -------------------------------------------------------------------------

  testWidgets(
      'hidden preset shows the visibility_off icon; visible preset does not',
      (tester) async {
    final presets = [
      _preset(id: 'p1', name: 'Visible Water', isHidden: false),
      _preset(
          id: 'p2',
          name: 'Hidden Juice',
          isHidden: true,
          beverageType: BeverageType.juice),
    ];

    await tester.pumpWidget(_buildScreen(presets));
    await tester.pump();

    // Exactly one hidden preset -> exactly one visibility_off icon overall.
    // Source: manage_drinks_screen.dart:
    //   trailing: preset.isHidden ? const Icon(Icons.visibility_off_outlined) : null
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    final hiddenTile = find.widgetWithText(ListTile, 'Hidden Juice');
    final visibleTile = find.widgetWithText(ListTile, 'Visible Water');

    expect(
      find.descendant(
        of: hiddenTile,
        matching: find.byIcon(Icons.visibility_off_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: visibleTile,
        matching: find.byIcon(Icons.visibility_off_outlined),
      ),
      findsNothing,
    );
  });
}
