// Widget tests for F14 preset create/edit form — PresetEditorScreen
// (issue #68).
//
// Coverage:
//  1. Create mode: title "Add drink"; Save disabled until name+volume valid.
//  2. Name validation: invalid name shows the Parity Rulebook error text and
//     keeps Save disabled; a valid name clears it.
//  3. Selecting an alcoholic beverage type reveals the ABV field and gates
//     Save on it; switching back to non-alcoholic hides the field again.
//  4. Icon picker: tapping a different icon updates which _IconChoice is
//     visually selected (border width 2 vs 1).
//  5. Colour picker round-trip: tapped swatch hex reaches createPreset.
//  6. Save in create mode calls createPreset with the expected args,
//     including sortOrder computed from the current preset count.
//  7. Save in edit mode pre-fills fields from the passed-in preset and calls
//     updatePreset with the edited fields.
//  8. Price field: empty -> Optional.value(null)/Optional.value(null);
//     "2.50" -> Optional.value(250) and the preset's OWN currency if it
//     already had one (never the user's current preference — Parity
//     Rulebook §No FX conversion), falling back to the preference only for
//     a preset that never had a price before.
//

// Fake-repo pattern mirrors manage_drinks_screen_test.dart: a real
// AppDatabase(NativeDatabase.memory()) is passed to the super constructor,
// but createPreset/updatePreset are overridden to *record* their arguments
// instead of touching the DB (settings_screen_test.dart's "record calls"
// pattern), and watchAllPresets() is stubbed to a fixed list so the
// create-mode sortOrder computation is deterministic.
//
// allPresetsProvider is only ever `ref.read` (never `ref.watch`) by the
// screen, inside _save(). In production this is already warm because the
// caller (ManageDrinksScreen) watches it before navigating here; in an
// isolated widget test nothing pre-subscribes it, so we explicitly warm it
// via `container.read(allPresetsProvider.future)` before pumping — otherwise
// the first read would observe AsyncLoading (valueOrNull == null) and
// silently compute sortOrder from an empty list regardless of the fixture.

// Hide isNull/isNotNull — drift.dart's query-builder matchers collide with
// package:matcher's (via flutter_test) identically-named test matchers.
import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/optional.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/preset_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repository — records createPreset/updatePreset args; never touches
// the real DB. watchAllPresets() is stubbed for the sortOrder computation.
// ---------------------------------------------------------------------------

typedef _CreateArgs = ({
  String name,
  BeverageType beverageType,
  int volumeMl,
  double? abvPercent,
  int? regularPriceMinor,
  String? regularCurrency,
  String iconKey,
  String iconColor,
  int sortOrder,
});

typedef _UpdateArgs = ({
  String id,
  String? name,
  int? volumeMl,
  Optional<double?> abvPercent,
  Optional<int?> regularPriceMinor,
  Optional<String?> regularCurrency,
  String? iconKey,
  String? iconColor,
});

class _FakeDrinksRepo extends DrinksRepository {
  _FakeDrinksRepo({this.presets = const [], this.nextSortOrderValue = 1})
      : super(AppDatabase(NativeDatabase.memory()));

  final List<DrinkPreset> presets;

  /// Stubbed [nextSortOrder] return value — the real implementation queries
  /// `MAX(sortOrder)` against the DB this fake never populates, so it can't
  /// be exercised through the real method here.
  final int nextSortOrderValue;

  _CreateArgs? lastCreateArgs;
  _UpdateArgs? lastUpdateArgs;

  /// When set, createPreset/updatePreset throw this instead of recording —
  /// exercises the SnackBar-on-failure branch. Not used by the tests below
  /// (no such scenario was requested) but kept minimal/unused would be
  /// dead code, so it is omitted entirely.

  @override
  Stream<List<DrinkPreset>> watchAllPresets() => Stream.value(presets);

  @override
  Future<int> nextSortOrder() async => nextSortOrderValue;

  @override
  Future<DrinkPreset> createPreset({
    required String name,
    required BeverageType beverageType,
    required int volumeMl,
    double? abvPercent,
    int? regularPriceMinor,
    String? regularCurrency,
    required String iconKey,
    required String iconColor,
    required int sortOrder,
  }) async {
    lastCreateArgs = (
      name: name,
      beverageType: beverageType,
      volumeMl: volumeMl,
      abvPercent: abvPercent,
      regularPriceMinor: regularPriceMinor,
      regularCurrency: regularCurrency,
      iconKey: iconKey,
      iconColor: iconColor,
      sortOrder: sortOrder,
    );
    return DrinkPreset(
      id: 'created-id',
      name: name,
      beverageType: beverageType,
      volumeMl: volumeMl,
      abvPercent: abvPercent,
      regularPriceMinor: regularPriceMinor,
      regularCurrency: regularCurrency,
      iconKey: iconKey,
      iconColor: iconColor,
      isUserCreated: true,
      isHidden: false,
      sortOrder: sortOrder,
    );
  }

  @override
  Future<void> updatePreset({
    required String id,
    String? name,
    int? volumeMl,
    Optional<double?> abvPercent = const Optional.absent(),
    Optional<int?> regularPriceMinor = const Optional.absent(),
    Optional<String?> regularCurrency = const Optional.absent(),
    String? iconKey,
    String? iconColor,
  }) async {
    lastUpdateArgs = (
      id: id,
      name: name,
      volumeMl: volumeMl,
      abvPercent: abvPercent,
      regularPriceMinor: regularPriceMinor,
      regularCurrency: regularCurrency,
      iconKey: iconKey,
      iconColor: iconColor,
    );
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

UserPreferences _prefs({String currency = 'EUR'}) {
  final now = DateTime.utc(2026, 1, 1);
  return UserPreferences(
    id: 'singleton',
    username: 'tester',
    dailyGoalMl: 2000,
    dayBoundaryHour: 4,
    units: 'metric',
    currency: currency,
    reminderEnabled: false,
    reminderStartHour: 8,
    reminderEndHour: 22,
    reminderIntervalMin: 60,
    inactivityReminderEnabled: false,
    weeklySummaryEnabled: false,
    bacOnLockScreenEnabled: false,
    approachingCapNotifEnabled: false,
    soberEstimateNotifEnabled: false,
    alcoholicPresetsAlwaysVisible: true,
    installedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

DrinkPreset _editPreset() => const DrinkPreset(
      id: 'preset-1',
      name: 'Craft Lager',
      beverageType: BeverageType.beer,
      volumeMl: 330,
      abvPercent: 5.0,
      regularPriceMinor: 450,
      regularCurrency: 'EUR',
      iconKey: 'bottle',
      iconColor: '#111111',
      isUserCreated: true,
      isHidden: false,
      sortOrder: 2,
    );

DrinkPreset _editPresetWithoutPrice() => const DrinkPreset(
      id: 'preset-1',
      name: 'Craft Lager',
      beverageType: BeverageType.beer,
      volumeMl: 330,
      abvPercent: 5.0,
      iconKey: 'bottle',
      iconColor: '#111111',
      isUserCreated: true,
      isHidden: false,
      sortOrder: 2,
    );

DrinkPreset _existingPreset(String id, int sortOrder) => DrinkPreset(
      id: id,
      name: 'Preset $id',
      beverageType: BeverageType.water,
      volumeMl: 250,
      iconKey: 'glass',
      iconColor: BeverageType.water.defaultIconColor,
      isUserCreated: false,
      isHidden: false,
      sortOrder: sortOrder,
    );

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

/// Builds a [ProviderContainer] with the fake repo/prefs wired in, and warms
/// [allPresetsProvider] (see file header) before returning.
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
  return container;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ProviderContainer container, {
  DrinkPreset? preset,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: PresetEditorScreen(preset: preset)),
    ),
  );
  // Let userPreferencesProvider deliver + TintedIcon's async SVG parsing
  // settle (design/notifications.md-adjacent conventions from
  // tinted_icon_test.dart: "a single extra pump should let it settle").
  await tester.pump();
  await tester.pump();
}

TextButton _saveButton(WidgetTester tester) => tester.widget<TextButton>(
      find.byKey(const Key('preset_editor_save_button')),
    );

/// Invokes the beverage-type dropdown's onChanged directly (see call sites
/// for why the overlay menu isn't driven via tap+text).
void _selectBeverageType(WidgetTester tester, BeverageType type) {
  final dropdown = tester.widget<DropdownButtonFormField<BeverageType>>(
    find.byKey(const Key('preset_editor_type_field')),
  );
  dropdown.onChanged!(type);
}

/// Border width of the _IconChoice Container for [iconKey] — 2 when
/// selected, 1 otherwise (preset_editor_screen.dart _IconChoice.build).
double _iconBorderWidth(WidgetTester tester, String iconKey) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byKey(Key('preset_editor_icon_$iconKey')),
      matching: find.byType(Container),
    ),
  );
  final decoration = container.decoration! as BoxDecoration;
  return (decoration.border! as Border).top.width;
}

/// Border colour of the _ColorSwatch Container for [hex] — the theme's
/// primary colour when selected, [Colors.transparent] otherwise
/// (preset_editor_screen.dart _ColorSwatch.build).
Color _swatchBorderColor(WidgetTester tester, String hex) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byKey(Key('preset_editor_color_$hex')),
      matching: find.byType(Container),
    ),
  );
  final decoration = container.decoration! as BoxDecoration;
  return (decoration.border! as Border).top.color;
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Create mode: title + Save disabled until valid
  // -------------------------------------------------------------------------

  testWidgets(
    'create mode shows "Add drink" title and Save is disabled until name '
    'and volume are valid',
    (tester) async {
      final repo = _FakeDrinksRepo();
      final container = await _buildContainer(repo: repo);
      addTearDown(container.dispose);
      await _pumpScreen(tester, container);

      expect(find.text('Add drink'), findsOneWidget);
      // Empty name -> _nameError = 'Name is required' set in initState.
      // Source: preset_editor_screen.dart _validateName.
      expect(_saveButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('preset_editor_name_field')),
        'Cola',
      );
      await tester.pump();
      // Name valid but volume still empty -> Save still disabled.
      expect(_saveButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('preset_editor_volume_field')),
        '330',
      );
      await tester.pump();
      // Water (non-alcoholic) requires no ABV -> Save now enabled.
      expect(_saveButton(tester).onPressed, isNotNull);
    },
  );

  // -------------------------------------------------------------------------
  // 2. Name validation
  // -------------------------------------------------------------------------

  testWidgets(
      'invalid name shows the Parity Rulebook error and keeps Save '
      'disabled; a valid name clears it', (tester) async {
    final repo = _FakeDrinksRepo();
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    await tester.enterText(
      find.byKey(const Key('preset_editor_volume_field')),
      '330',
    );
    await tester.pump();

    // Too short (< 3 runes). Source: core/src/username.dart
    // validatePresetName — 'Must be 3–30 characters.'
    await tester.enterText(
      find.byKey(const Key('preset_editor_name_field')),
      'ab',
    );
    await tester.pump();
    expect(find.text('Must be 3–30 characters.'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    // Starts with a disallowed leading character (hyphen).
    // Source: core/src/username.dart validatePresetName — structural error.
    await tester.enterText(
      find.byKey(const Key('preset_editor_name_field')),
      '-Abc',
    );
    await tester.pump();
    expect(
      find.text(
        'Use letters, digits, spaces, ( ), and _ - . — must start and end '
        'with a letter, digit, or parenthesis.',
      ),
      findsOneWidget,
    );
    expect(_saveButton(tester).onPressed, isNull);

    // A valid name clears the error and enables Save.
    await tester.enterText(
      find.byKey(const Key('preset_editor_name_field')),
      'Cola',
    );
    await tester.pump();
    expect(find.text('Must be 3–30 characters.'), findsNothing);
    expect(
      find.text(
        'Use letters, digits, spaces, ( ), and _ - . — must start and end '
        'with a letter, digit, or parenthesis.',
      ),
      findsNothing,
    );
    expect(_saveButton(tester).onPressed, isNotNull);
  });

  // -------------------------------------------------------------------------
  // 3. Alcoholic type reveals ABV field; gates Save; hides when switched back
  // -------------------------------------------------------------------------

  testWidgets(
    'selecting an alcoholic type reveals the ABV field and gates Save on '
    'it; switching back to non-alcoholic hides it again',
    (tester) async {
      final repo = _FakeDrinksRepo();
      final container = await _buildContainer(repo: repo);
      addTearDown(container.dispose);
      await _pumpScreen(tester, container);

      // Source: preset_editor_screen.dart — ABV field only built
      // `if (_beverageType.isAlcoholic)`; initial type is BeverageType.water.
      expect(find.byKey(const Key('preset_editor_abv_field')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('preset_editor_name_field')),
        'Craft Lager',
      );
      await tester.enterText(
        find.byKey(const Key('preset_editor_volume_field')),
        '330',
      );
      await tester.pump();

      // DropdownButtonFormField's overlay menu is driven through onChanged
      // directly rather than tapping the popup route — the popup only builds
      // items near the current scroll offset, which made tapping a specific
      // item's Text flaky once the selection had already moved away from the
      // top of the list (e.g. re-opening the menu after Beer was selected).
      _selectBeverageType(tester, BeverageType.beer);
      await tester.pump();

      expect(find.byKey(const Key('preset_editor_abv_field')), findsOneWidget);
      // Name + volume valid, but ABV empty for an alcoholic type -> Save
      // disabled (preset_editor_screen.dart _canSave).
      expect(_saveButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('preset_editor_abv_field')),
        '5.0',
      );
      await tester.pump();
      expect(_saveButton(tester).onPressed, isNotNull);

      // Switch back to a non-alcoholic type -> ABV field is hidden again.
      _selectBeverageType(tester, BeverageType.water);
      await tester.pump();

      expect(find.byKey(const Key('preset_editor_abv_field')), findsNothing);
      expect(_saveButton(tester).onPressed, isNotNull);
    },
  );

  // -------------------------------------------------------------------------
  // 4. Icon picker round-trip
  // -------------------------------------------------------------------------

  testWidgets(
      'tapping a different icon updates which _IconChoice is visually '
      'selected', (tester) async {
    final repo = _FakeDrinksRepo();
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    // Initial selection is kDrinkIconKeys.first == 'glass'.
    expect(_iconBorderWidth(tester, 'glass'), 2);
    expect(_iconBorderWidth(tester, 'bottle'), 1);

    await tester.tap(find.byKey(const Key('preset_editor_icon_bottle')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(_iconBorderWidth(tester, 'bottle'), 2);
    expect(_iconBorderWidth(tester, 'glass'), 1);
  });

  // -------------------------------------------------------------------------
  // 5. Colour picker round-trip -> reaches createPreset
  // -------------------------------------------------------------------------

  testWidgets(
    'tapping a colour swatch selects it and the hex reaches createPreset '
    'on save',
    (tester) async {
      final repo = _FakeDrinksRepo();
      final container = await _buildContainer(repo: repo);
      addTearDown(container.dispose);
      await _pumpScreen(tester, container);

      // Water's default colour swatch (#3b82f6) is first/selected initially.
      expect(_swatchBorderColor(tester, '#3b82f6'), isNot(Colors.transparent));
      expect(_swatchBorderColor(tester, '#15803d'), Colors.transparent);

      await tester.tap(find.byKey(const Key('preset_editor_color_#15803d')));
      await tester.pump();

      expect(_swatchBorderColor(tester, '#15803d'), isNot(Colors.transparent));
      expect(_swatchBorderColor(tester, '#3b82f6'), Colors.transparent);

      await tester.enterText(
        find.byKey(const Key('preset_editor_name_field')),
        'Cola',
      );
      await tester.enterText(
        find.byKey(const Key('preset_editor_volume_field')),
        '330',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('preset_editor_save_button')));
      await tester.pump();

      expect(repo.lastCreateArgs?.iconColor, '#15803d');
    },
  );

  testWidgets(
      'typing a valid custom hex colour and tapping Save directly (no '
      'keyboard submit) applies the typed colour', (tester) async {
    // Regression: _onCustomColorSubmitted previously only fired from
    // onSubmitted/onEditingComplete (keyboard submit), so tapping Save
    // right after typing a valid hex silently discarded it in favour of
    // whichever swatch/default was selected before.
    final repo = _FakeDrinksRepo();
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    await tester.enterText(
      find.byKey(const Key('preset_editor_custom_color_field')),
      '15803d',
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('preset_editor_name_field')),
      'Cola',
    );
    await tester.enterText(
      find.byKey(const Key('preset_editor_volume_field')),
      '330',
    );
    await tester.pump();

    // No onSubmitted/onEditingComplete triggered — straight to Save.
    await tester.tap(find.byKey(const Key('preset_editor_save_button')));
    await tester.pump();

    expect(repo.lastCreateArgs?.iconColor, '#15803d');
  });

  // -------------------------------------------------------------------------
  // 6. Save in create mode -> createPreset args, incl. sortOrder
  // -------------------------------------------------------------------------

  testWidgets(
      'save in create mode calls createPreset with the expected args, '
      'including sortOrder from repo.nextSortOrder()', (
    tester,
  ) async {
    final repo = _FakeDrinksRepo(
      presets: [_existingPreset('p1', 1), _existingPreset('p2', 2)],
      nextSortOrderValue: 3,
    );
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    await tester.enterText(
      find.byKey(const Key('preset_editor_name_field')),
      'Cola',
    );
    await tester.enterText(
      find.byKey(const Key('preset_editor_volume_field')),
      '330',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('preset_editor_save_button')));
    await tester.pump();

    final args = repo.lastCreateArgs;
    expect(args, isNotNull);
    expect(args!.name, 'Cola');
    expect(args.beverageType, BeverageType.water);
    expect(args.volumeMl, 330);
    expect(args.iconKey, 'glass');
    expect(args.iconColor, '#3b82f6');
    // Source: preset_editor_screen.dart _save — create-mode `sortOrder:
    // await repo.nextSortOrder()`.
    expect(args.sortOrder, 3);
  });

  // -------------------------------------------------------------------------
  // 7. Edit mode: prefill + save with updatePreset
  // -------------------------------------------------------------------------

  testWidgets(
      'edit mode pre-fills fields from the passed-in preset and calling '
      'save sends updatePreset with the edited fields', (tester) async {
    final repo = _FakeDrinksRepo();
    final container = await _buildContainer(repo: repo);
    addTearDown(container.dispose);
    final preset = _editPreset();
    await _pumpScreen(tester, container, preset: preset);

    expect(find.text('Edit drink'), findsOneWidget);
    expect(find.text('Craft Lager'), findsOneWidget);
    expect(find.text('330'), findsOneWidget);
    // Source: preset_editor_screen.dart initState —
    // `preset?.abvPercent?.toString() ?? ''`.
    expect(find.text('5.0'), findsOneWidget);
    // Source: initState — `(preset.regularPriceMinor! / 100).toStringAsFixed(2)`.
    expect(find.text('4.50'), findsOneWidget);
    expect(find.text('Beer'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.enterText(
      find.byKey(const Key('preset_editor_name_field')),
      'Craft Lager Deluxe',
    );
    await tester.enterText(
      find.byKey(const Key('preset_editor_volume_field')),
      '500',
    );
    await tester.enterText(
      find.byKey(const Key('preset_editor_abv_field')),
      '4.5',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('preset_editor_save_button')));
    await tester.pump();

    final args = repo.lastUpdateArgs;
    expect(args, isNotNull);
    expect(args!.id, 'preset-1');
    expect(args.name, 'Craft Lager Deluxe');
    expect(args.volumeMl, 500);
    expect(args.abvPercent, const Optional.value(4.5));
    expect(args.iconKey, 'bottle');
    expect(args.iconColor, '#111111');
    // Price field untouched ('4.50') -> re-parsed to 450, currency from
    // current prefs (EUR here, matching the fixture preset's own currency).
    // Source: preset_editor_screen.dart _save — regularPriceMinor/
    // regularCurrency are always recomputed from _priceCtrl/prefs.currency.
    expect(args.regularPriceMinor, const Optional.value(450));
    expect(args.regularCurrency, const Optional.value('EUR'));
  });

  // -------------------------------------------------------------------------
  // 8. Price field: empty -> Optional.value(null); "2.50" -> Optional.value(250)/Optional.value(currency)
  // -------------------------------------------------------------------------

  testWidgets(
    'edit mode: empty price field saves Optional.value(null)/Optional.value(null)',
    (tester) async {
      final repo = _FakeDrinksRepo();
      final container = await _buildContainer(repo: repo, prefs: _prefs());
      addTearDown(container.dispose);
      final preset = _editPreset();
      await _pumpScreen(tester, container, preset: preset);

      await tester.enterText(
        find.byKey(const Key('preset_editor_price_field')),
        '',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('preset_editor_save_button')));
      await tester.pump();

      final args = repo.lastUpdateArgs;
      expect(args, isNotNull);
      expect(args!.regularPriceMinor, const Optional.value(null));
      expect(args.regularCurrency, const Optional.value(null));
    },
  );

  testWidgets(
      'edit mode: "2.50" price field saves Optional.value(250) and '
      "preserves the preset's own currency (not the user's current "
      'preference)', (tester) async {
    // _editPreset() already has regularCurrency 'EUR'; prefs here is 'USD'
    // to prove the preset's own currency wins — Parity Rulebook §No FX
    // conversion: editing price must never silently relabel stored money
    // under a different currency.
    final repo = _FakeDrinksRepo();
    final container = await _buildContainer(
      repo: repo,
      prefs: _prefs(currency: 'USD'),
    );
    addTearDown(container.dispose);
    final preset = _editPreset();
    await _pumpScreen(tester, container, preset: preset);

    await tester.enterText(
      find.byKey(const Key('preset_editor_price_field')),
      '2.50',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('preset_editor_save_button')));
    await tester.pump();

    final args = repo.lastUpdateArgs;
    expect(args, isNotNull);
    expect(args!.regularPriceMinor, const Optional.value(250));
    expect(args.regularCurrency, const Optional.value('EUR'));
  });

  testWidgets(
    'edit mode: adding a price to a preset with no prior price falls back '
    "to the user's current currency preference",
    (tester) async {
      final repo = _FakeDrinksRepo();
      final container = await _buildContainer(
        repo: repo,
        prefs: _prefs(currency: 'GBP'),
      );
      addTearDown(container.dispose);
      final preset = _editPresetWithoutPrice();
      await _pumpScreen(tester, container, preset: preset);

      await tester.enterText(
        find.byKey(const Key('preset_editor_price_field')),
        '3.00',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('preset_editor_save_button')));
      await tester.pump();

      final args = repo.lastUpdateArgs;
      expect(args, isNotNull);
      expect(args!.regularPriceMinor, const Optional.value(300));
      expect(args.regularCurrency, const Optional.value('GBP'));
    },
  );
}
