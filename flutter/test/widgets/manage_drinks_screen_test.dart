// Widget tests for F14 "Manage drinks" — ManageDrinksScreen (issue #68
// rewrite: hide/unhide, delete, reorder, create/edit navigation, and Party
// Mode gating of alcoholic presets).
//
// Coverage:
//  1. Empty state shows "No drink presets yet." text.
//  2. Populated list shows preset name + volume for each preset.
//  3. A hidden preset shows the visibility_off icon; a visible one does not.
//  4. Party Mode gating: alcoholic presets render nowhere in the tree when
//     bacCapGramsPerL is null; they render alongside everything else when it
//     is set (features.md F14: "alcoholic presets visible only when Party
//     Mode active").
//  5. Hide/unhide button calls hidePreset/unhidePreset with the preset id.
//  6. Delete button only renders for isUserCreated presets; the confirm
//     dialog gates deletePreset on tapping "Delete" (not "Cancel").
//  7. Tapping the add FAB pushes PresetEditorScreen with a null preset.
//  8. Tapping a preset's ListTile pushes PresetEditorScreen with that preset.
//  9. Dragging a row's drag handle calls reorderPresets with the ids in the
//     new visual order.
//
// Provider harness: previously this file only overrode
// drinksRepositoryProvider, leaving userPreferencesProvider to fall through
// to the real (never-resolving, in this sandbox) preferencesRepositoryProvider
// — which happened to keep partyModeActive == false and fmt == null for the
// whole test, by accident rather than by design. Now that the screen's
// behaviour depends on userPreferencesProvider on purpose (Party Mode gating,
// price/volume formatting), every test overrides it explicitly with a fixed
// UserPreferences fixture via a ProviderContainer + UncontrolledProviderScope
// (mirrors preset_editor_screen_test.dart's harness), and both
// allPresetsProvider and userPreferencesProvider are warmed via `.future`
// before the first pump so no test accidentally observes AsyncLoading.

import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/manage_drinks_screen.dart';
import 'package:drinks_mate/src/screens/preset_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repository — stubs watchAllPresets(); records hide/unhide/delete/
// reorder calls instead of touching the real DB.
// ---------------------------------------------------------------------------

class _FakeDrinksRepo extends DrinksRepository {
  _FakeDrinksRepo(this._presets) : super(AppDatabase(NativeDatabase.memory()));

  final List<DrinkPreset> _presets;

  final List<String> hideCalls = [];
  final List<String> unhideCalls = [];
  final List<String> deleteCalls = [];
  final List<List<String>> reorderCalls = [];

  @override
  Stream<List<DrinkPreset>> watchAllPresets() => Stream.value(_presets);

  @override
  Future<void> hidePreset(String id) async => hideCalls.add(id);

  @override
  Future<void> unhidePreset(String id) async => unhideCalls.add(id);

  @override
  Future<void> deletePreset(String id) async => deleteCalls.add(id);

  @override
  Future<void> reorderPresets(List<String> orderedIds) async =>
      reorderCalls.add(orderedIds);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

DrinkPreset _preset({
  required String id,
  required String name,
  int volumeMl = 250,
  bool isHidden = false,
  bool isUserCreated = false,
  BeverageType beverageType = BeverageType.water,
  int sortOrder = 0,
}) {
  return DrinkPreset(
    id: id,
    name: name,
    beverageType: beverageType,
    volumeMl: volumeMl,
    iconKey: 'glass',
    iconColor: beverageType.defaultIconColor,
    isUserCreated: isUserCreated,
    isHidden: isHidden,
    sortOrder: sortOrder,
  );
}

/// [bacCapGramsPerL] drives Party Mode gating
/// (manage_drinks_screen.dart: `partyModeActive = bacCapGramsPerL != null`).
UserPreferences _prefs({double? bacCapGramsPerL}) {
  final now = DateTime.utc(2026, 1, 1);
  return UserPreferences(
    id: kUserPreferencesId,
    username: 'tester',
    dailyGoalMl: 2000,
    dayBoundaryHour: 4,
    units: 'metric',
    currency: 'EUR',
    reminderEnabled: false,
    reminderStartHour: 8,
    reminderEndHour: 22,
    reminderIntervalMin: 60,
    inactivityReminderEnabled: false,
    weeklySummaryEnabled: false,
    bacCapGramsPerL: bacCapGramsPerL,
    bacOnLockScreenEnabled: false,
    approachingCapNotifEnabled: false,
    soberEstimateNotifEnabled: false,
    installedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

/// Builds a [ProviderContainer] with [repo]/[prefs] wired in and warms both
/// [allPresetsProvider] and [userPreferencesProvider] (see file header) so
/// the first pump already observes resolved data, not AsyncLoading.
Future<ProviderContainer> _buildContainer({
  required _FakeDrinksRepo repo,
  UserPreferences? prefs,
}) async {
  final container = ProviderContainer(
    overrides: [
      drinksRepositoryProvider.overrideWithValue(repo),
      userPreferencesProvider.overrideWith(
        (ref) => Stream.value(prefs ?? _prefs()),
      ),
    ],
  );
  await container.read(allPresetsProvider.future);
  await container.read(userPreferencesProvider.future);
  return container;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ManageDrinksScreen()),
    ),
  );
  // Both providers are already warmed (see _buildContainer), but a couple of
  // pumps let the StreamProviders' first-frame rebuild settle, mirroring
  // preset_editor_screen_test.dart's harness.
  await tester.pump();
  await tester.pump();
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Empty state
  // -------------------------------------------------------------------------

  testWidgets('empty state shows "No drink presets yet." text', (
    tester,
  ) async {
    final repo = _FakeDrinksRepo(const []);
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

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
        beverageType: BeverageType.coffee,
      ),
    ];
    final repo = _FakeDrinksRepo(presets);
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    expect(find.text('Glass of water'), findsOneWidget);
    // Source: Parity Rulebook "Imperial display" — metric volume formatting
    // is '${ml.round()} ml' (FormatService.formatVolume, units: 'metric').
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
      _preset(id: 'p1', name: 'Visible Water'),
      _preset(
        id: 'p2',
        name: 'Hidden Juice',
        isHidden: true,
        beverageType: BeverageType.juice,
      ),
    ];
    final repo = _FakeDrinksRepo(presets);
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    // Exactly one hidden preset -> exactly one visibility_off icon overall.
    // Source: manage_drinks_screen.dart _PresetTile.build —
    // `preset.isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined`.
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

  // -------------------------------------------------------------------------
  // 4. Party Mode gating
  // -------------------------------------------------------------------------

  group('Party Mode gating', () {
    List<DrinkPreset> presets() => [
          _preset(id: 'water', name: 'Glass of water'),
          _preset(
            id: 'beer',
            name: 'Craft Lager',
            beverageType: BeverageType.beer,
          ),
        ];

    testWidgets(
        'alcoholic presets do not render at all when bacCapGramsPerL is null',
        (tester) async {
      final repo = _FakeDrinksRepo(presets());
      final container = await _buildContainer(
        repo: repo,
        prefs: _prefs(),
      );
      addTearDown(container.dispose);
      await _pumpScreen(tester, container);

      expect(find.text('Glass of water'), findsOneWidget);
      // Source: manage_drinks_screen.dart ManageDrinksScreen.build —
      // `partyModeActive` false -> `allPresets.where((p) =>
      // !p.beverageType.isAlcoholic)`; features.md F14: "alcoholic presets
      // visible only when Party Mode active".
      expect(find.text('Craft Lager'), findsNothing);
    });

    testWidgets(
        'alcoholic presets render alongside everything else when '
        'bacCapGramsPerL is set', (tester) async {
      final repo = _FakeDrinksRepo(presets());
      final container = await _buildContainer(
        repo: repo,
        prefs: _prefs(bacCapGramsPerL: 0.5),
      );
      addTearDown(container.dispose);
      await _pumpScreen(tester, container);

      expect(find.text('Glass of water'), findsOneWidget);
      expect(find.text('Craft Lager'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 5. Hide/unhide button
  // -------------------------------------------------------------------------

  testWidgets(
      'tapping the visibility button on a visible preset calls hidePreset',
      (tester) async {
    final repo = _FakeDrinksRepo([_preset(id: 'p1', name: 'Visible Water')]);
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    await tester.tap(find.byKey(const Key('manage_drinks_visibility_p1')));
    await tester.pump();

    expect(repo.hideCalls, ['p1']);
    expect(repo.unhideCalls, isEmpty);
  });

  testWidgets(
      'tapping the visibility button on a hidden preset calls unhidePreset',
      (tester) async {
    final repo = _FakeDrinksRepo([
      _preset(id: 'p1', name: 'Hidden Juice', isHidden: true),
    ]);
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    await tester.tap(find.byKey(const Key('manage_drinks_visibility_p1')));
    await tester.pump();

    expect(repo.unhideCalls, ['p1']);
    expect(repo.hideCalls, isEmpty);
  });

  // -------------------------------------------------------------------------
  // 6. Delete button — user-created only, gated behind a confirm dialog
  // -------------------------------------------------------------------------

  testWidgets('delete button only renders for user-created presets', (
    tester,
  ) async {
    final repo = _FakeDrinksRepo([
      _preset(id: 'seeded', name: 'Glass of water'),
      _preset(id: 'custom', name: 'My Cola', isUserCreated: true),
    ]);
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    // Source: manage_drinks_screen.dart _PresetTile.build —
    // `if (preset.isUserCreated) IconButton(key: manage_drinks_delete_...)`.
    expect(find.byKey(const Key('manage_drinks_delete_seeded')), findsNothing);
    expect(
      find.byKey(const Key('manage_drinks_delete_custom')),
      findsOneWidget,
    );
  });

  testWidgets(
      'tapping Cancel on the delete confirm dialog does not call '
      'deletePreset', (tester) async {
    final repo = _FakeDrinksRepo([
      _preset(id: 'custom', name: 'My Cola', isUserCreated: true),
    ]);
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    await tester.tap(find.byKey(const Key('manage_drinks_delete_custom')));
    await tester.pump();

    // Source: manage_drinks_screen.dart _PresetTile._confirmDelete —
    // AlertDialog title `Delete "${preset.name}"?`.
    expect(find.text('Delete "My Cola"?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, isEmpty);
  });

  testWidgets('tapping Delete on the delete confirm dialog calls deletePreset',
      (tester) async {
    final repo = _FakeDrinksRepo([
      _preset(id: 'custom', name: 'My Cola', isUserCreated: true),
    ]);
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    await tester.tap(find.byKey(const Key('manage_drinks_delete_custom')));
    await tester.pump();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, ['custom']);
  });

  // -------------------------------------------------------------------------
  // 7. FAB navigates to create
  // -------------------------------------------------------------------------

  testWidgets(
      'tapping the add FAB pushes PresetEditorScreen with a null '
      'preset', (tester) async {
    final repo = _FakeDrinksRepo(const []);
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    await tester.tap(find.byKey(const Key('manage_drinks_add_fab')));
    await tester.pumpAndSettle();

    expect(find.byType(PresetEditorScreen), findsOneWidget);
    final pushed = tester.widget<PresetEditorScreen>(
      find.byType(PresetEditorScreen),
    );
    expect(pushed.preset, isNull);
    expect(find.text('Add drink'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 8. Tapping a preset tile navigates to edit
  // -------------------------------------------------------------------------

  testWidgets(
      'tapping a preset tile pushes PresetEditorScreen with that preset',
      (tester) async {
    final preset = _preset(id: 'p1', name: 'Glass of water');
    final repo = _FakeDrinksRepo([preset]);
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    await tester.tap(find.widgetWithText(ListTile, 'Glass of water'));
    await tester.pumpAndSettle();

    expect(find.byType(PresetEditorScreen), findsOneWidget);
    final pushed = tester.widget<PresetEditorScreen>(
      find.byType(PresetEditorScreen),
    );
    expect(pushed.preset?.id, 'p1');
    expect(find.text('Edit drink'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 9. Reorder — dragging the drag handle calls reorderPresets
  // -------------------------------------------------------------------------

  testWidgets(
      'dragging a row past the others calls reorderPresets with the new id '
      'order', (tester) async {
    final presets = [
      _preset(id: 'p1', name: 'Preset One', sortOrder: 1),
      _preset(id: 'p2', name: 'Preset Two', sortOrder: 2),
      _preset(id: 'p3', name: 'Preset Three', sortOrder: 3),
    ];
    final repo = _FakeDrinksRepo(presets);
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    // Source: manage_drinks_screen.dart _PresetTile — drag handle is a
    // ReorderableDragStartListener-wrapped Icon inside the _PresetTile keyed
    // by ValueKey(preset.id).
    final handle = find.descendant(
      of: find.byKey(const ValueKey('p1')),
      matching: find.byIcon(Icons.drag_handle),
    );
    expect(handle, findsOneWidget);

    // ReorderableDragStartListener starts the drag immediately on pointer
    // down (no long-press needed, unlike the default drag handles this
    // screen disables via buildDefaultDragHandles: false). Drag p1 down far
    // enough to pass both p2 and p3, landing it last.
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 500));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(repo.reorderCalls, isNotEmpty);
    // p1 dragged from index 0 past p2 and p3 -> final visual order is
    // [p2, p3, p1]. Source: DrinksRepository.reorderPresets doc — "ids in
    // final order"; manage_drinks_screen.dart _onReorder passes
    // `reordered.map((p) => p.id)` after removeAt(oldIndex)/insert(newIndex)
    // using ReorderableListView's onReorderItem callback, whose newIndex is
    // already adjusted for the removed item (Flutter framework doc:
    // "onReorderItem ... adjusts the newIndex parameter for a removed item
    // at the oldIndex" — unlike the deprecated onReorder).
    expect(repo.reorderCalls.last, ['p2', 'p3', 'p1']);
  });

  testWidgets(
    'dragging a row when an alcoholic preset is hidden by Party Mode '
    "filtering keeps the hidden preset's absolute position instead of "
    'pushing it to the tail of sortOrder (regression: reorderPresets '
    'appends any id not passed in after the full passed-in list, so '
    'passing only the visible subset would silently move every hidden '
    'alcoholic preset on every reorder)',
    (tester) async {
      final presets = [
        _preset(id: 'p1', name: 'Preset One', sortOrder: 1),
        _preset(
          id: 'alc',
          name: 'Hidden Beer',
          beverageType: BeverageType.beer,
          sortOrder: 2,
        ),
        _preset(id: 'p2', name: 'Preset Two', sortOrder: 3),
        _preset(id: 'p3', name: 'Preset Three', sortOrder: 4),
      ];
      // Party Mode off (default _prefs()) — 'alc' is filtered out of the
      // visible list entirely, but must still appear in reorderPresets'
      // orderedIds at its original relative position.
      final repo = _FakeDrinksRepo(presets);
      final container = await _buildContainer(repo: repo);
      addTearDown(container.dispose);
      await _pumpScreen(tester, container);

      final handle = find.descendant(
        of: find.byKey(const ValueKey('p1')),
        matching: find.byIcon(Icons.drag_handle),
      );
      expect(handle, findsOneWidget);

      // Drag p1 (visible index 0) past p2 and p3, landing it last among the
      // visible rows -> visible order becomes [p2, p3, p1].
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 500));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(repo.reorderCalls, isNotEmpty);
      // 'alc' must stay interleaved at its original absolute position
      // (between p1 and p2 in allPresets) — not appended after the
      // reordered visible subset as ['p2', 'p3', 'p1', 'alc'] would be.
      expect(repo.reorderCalls.last, ['p2', 'alc', 'p3', 'p1']);
    },
  );
}
