// Widget tests for S2 "Advanced editor" — LogDrinkSheet (issue #68).
//
// Coverage:
//  1. Phase 1 -> phase 2 navigation (sanity check; this file previously had
//     no coverage of LogDrinkSheet at all).
//  2. Advanced button opens the Advanced editor, prefilled from the selected
//     preset.
//  3. Advanced editor Confirm button: disabled for an invalid name, enabled
//     once valid (user-experience.md §S2 / Parity Rulebook DrinkPreset-name
//     validation, same `validatePresetName` used by preset_editor_screen.dart
//     — see preset_editor_screen_test.dart's "Name validation" group for the
//     exact error strings this reuses).
//  4. ABV field presence: only rendered for an alcoholic preset.
//  5. Path discrimination (the three S2 Advanced exit paths — user-
//     experience.md §S2, mirrored by log_drink_sheet.dart's own
//     `_applyAdvancedResult` doc comment):
//       - Advanced -> Confirm: logDrink only, preset row untouched.
//       - Advanced -> menu -> "Save and confirm": updatePreset then logDrink.
//       - Advanced -> menu -> "Save as copy and confirm" -> confirm the
//         copy-name dialog: createPreset then logDrink against the new
//         preset; updatePreset never called.
//  6. Back button discards edits, returns to phase 2 with original values,
//     no repo writes.
//  7. Cancelling the copy-name dialog aborts the whole save-as-copy flow.
//
// Fake-repo pattern mirrors party_screen_test.dart's _FakeDrinksRepo: a real
// AppDatabase(NativeDatabase.memory()) is passed to the super constructor,
// but every method LogDrinkSheet can call is overridden to *record* its
// arguments instead of touching the DB.
//
// allPresetsProvider warming mirrors preset_editor_screen_test.dart: the
// Advanced editor's "Save as copy and confirm" path reads
// `ref.read(allPresetsProvider).valueOrNull` synchronously inside
// _applyAdvancedResult, so the provider must already be warm before the tap
// that triggers it, or it would observe AsyncLoading and compute sortOrder
// from an empty list regardless of the fixture.

import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/optional.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/log_drink_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repository — records createPreset/updatePreset/logDrink/getPresetById
// calls; never touches the real DB.
// ---------------------------------------------------------------------------

typedef _LogDrinkCall = ({
  DrinkPreset preset,
  String? name,
  int? volumeMl,
  double? abvPercent,
  Optional<int?> priceMinor,
  Optional<String?> currency,
});

typedef _UpdatePresetCall = ({
  String id,
  String? name,
  Optional<double?> abvPercent,
  Optional<int?> regularPriceMinor,
  Optional<String?> regularCurrency,
});

typedef _CreatePresetCall = ({
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

class _FakeDrinksRepo extends DrinksRepository {
  _FakeDrinksRepo({this.existingPresets = const []})
      : super(AppDatabase(NativeDatabase.memory()));

  /// Feeds allPresetsProvider (via watchAllPresets) — the "existing preset
  /// count" saveAsCopyAndConfirm's sortOrder is derived from.
  final List<DrinkPreset> existingPresets;

  /// What getPresetById returns after updatePreset — simulates the refetch
  /// in the "Save and confirm" path (log_drink_sheet.dart:
  /// `getPresetById(preset.id) ?? preset`). Defaults to null (falls back to
  /// the original, un-refetched preset) unless a test sets it.
  DrinkPreset? refetchResult;

  final List<_LogDrinkCall> logDrinkCalls = [];
  final List<_UpdatePresetCall> updatePresetCalls = [];
  final List<_CreatePresetCall> createPresetCalls = [];

  @override
  Stream<List<DrinkPreset>> watchAllPresets() => Stream.value(existingPresets);

  @override
  Future<void> logDrink({
    required DrinkPreset preset,
    String? name,
    int? volumeMl,
    double? abvPercent,
    Optional<int?> priceMinor = const Optional.absent(),
    Optional<String?> currency = const Optional.absent(),
    DateTime? consumedAt,
  }) async {
    logDrinkCalls.add((
      preset: preset,
      name: name,
      volumeMl: volumeMl,
      abvPercent: abvPercent,
      priceMinor: priceMinor,
      currency: currency,
    ));
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
    updatePresetCalls.add((
      id: id,
      name: name,
      abvPercent: abvPercent,
      regularPriceMinor: regularPriceMinor,
      regularCurrency: regularCurrency,
    ));
  }

  @override
  Future<DrinkPreset?> getPresetById(String id) async => refetchResult;

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
    createPresetCalls.add((
      name: name,
      beverageType: beverageType,
      volumeMl: volumeMl,
      abvPercent: abvPercent,
      regularPriceMinor: regularPriceMinor,
      regularCurrency: regularCurrency,
      iconKey: iconKey,
      iconColor: iconColor,
      sortOrder: sortOrder,
    ));
    return DrinkPreset(
      id: 'created-preset',
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
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

UserPreferences _prefs({String currency = 'EUR'}) => UserPreferences(
      id: kUserPreferencesId,
      username: 'tester',
      dailyGoalMl: 2000,
      dayBoundaryHour: 5,
      units: 'metric',
      currency: currency,
      reminderEnabled: false,
      reminderStartHour: 8,
      reminderEndHour: 22,
      reminderIntervalMin: 90,
      inactivityReminderEnabled: false,
      weeklySummaryEnabled: false,
      bacOnLockScreenEnabled: false,
      approachingCapNotifEnabled: false,
      soberEstimateNotifEnabled: false,
      alcoholicPresetsAlwaysVisible: true,
      installedAt: _epoch,
      createdAt: _epoch,
      updatedAt: _epoch,
    );

/// Alcoholic fixture — used for ABV-field-present / path-discrimination
/// tests. Already carries a regularCurrency so the Advanced editor's
/// `_currency` getter (preset.regularCurrency ?? prefs.currency) never needs
/// to fall back to userPreferencesProvider.
const _beerPreset = DrinkPreset(
  id: 'preset-beer',
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
  sortOrder: 1,
);

/// Non-alcoholic fixture — used for the "ABV field absent" case.
const _waterPreset = DrinkPreset(
  id: 'preset-water',
  name: 'Glass of water',
  beverageType: BeverageType.water,
  volumeMl: 250,
  iconKey: 'glass',
  iconColor: '#3b82f6',
  isUserCreated: false,
  isHidden: false,
  sortOrder: 1,
);

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Builds a [ProviderContainer] wired to [repo], with [visiblePresets] fixed
/// (deterministic phase-1 list) and allPresetsProvider/userPreferencesProvider
/// pre-warmed (see file header).
Future<ProviderContainer> _buildContainer({
  required _FakeDrinksRepo repo,
  required List<DrinkPreset> visiblePresets,
  UserPreferences? prefs,
}) async {
  final container = ProviderContainer(
    overrides: [
      drinksRepositoryProvider.overrideWithValue(repo),
      visiblePresetsProvider.overrideWith(
        (ref) => Stream.value(visiblePresets),
      ),
      userPreferencesProvider.overrideWith(
        (ref) => Stream.value(prefs ?? _prefs()),
      ),
    ],
  );
  await container.read(allPresetsProvider.future);
  await container.read(userPreferencesProvider.future);
  return container;
}

/// Pumps LogDrinkSheet as plain body content — a modal bottom sheet route
/// isn't required for testing; DraggableScrollableSheet just needs bounded
/// height from its ancestor.
Future<void> _pumpSheet(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: SizedBox(height: 700, child: LogDrinkSheet())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pickPreset(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

Future<void> _openAdvanced(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('log_drink_advanced_button')));
  await tester.pumpAndSettle();
}

/// Edits the phase-2 volume field (the only TextFormField in that phase —
/// it has no key of its own) to [volume]. Used to distinguish the *edited*
/// volume from the preset default in the path-discrimination tests below;
/// without this, a regression that swapped the edited volume for the
/// preset's own volumeMl would pass silently whenever the two happened to
/// be equal.
Future<void> _editVolume(WidgetTester tester, String volume) async {
  await tester.enterText(find.byType(TextFormField), volume);
  await tester.pump();
}

Future<void> _fillAdvanced(
  WidgetTester tester, {
  String? name,
  String? abv,
  String? price,
}) async {
  if (name != null) {
    await tester.enterText(
      find.byKey(const Key('advanced_editor_name_field')),
      name,
    );
  }
  if (abv != null) {
    await tester.enterText(
      find.byKey(const Key('advanced_editor_abv_field')),
      abv,
    );
  }
  if (price != null) {
    await tester.enterText(
      find.byKey(const Key('advanced_editor_price_field')),
      price,
    );
  }
  await tester.pump();
}

/// Opens the Advanced editor's overflow menu and taps the item with [label]
/// text (exact match against the PopupMenuItem's Text child).
Future<void> _selectMenuAction(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('advanced_editor_menu_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Phase 1 -> phase 2 navigation
  // -------------------------------------------------------------------------

  testWidgets('tapping a preset in phase 1 moves to phase 2', (tester) async {
    final repo = _FakeDrinksRepo();
    final container = await _buildContainer(
      repo: repo,
      visiblePresets: const [_beerPreset],
    );
    addTearDown(container.dispose);
    await _pumpSheet(tester, container);

    // Phase 1: preset list.
    expect(find.text('Log a drink'), findsOneWidget);
    expect(find.text('Craft Lager'), findsOneWidget);

    await _pickPreset(tester, 'Craft Lager');

    // Phase 2: confirm screen with the Advanced/Confirm buttons.
    expect(find.text('Log a drink'), findsNothing);
    expect(find.byKey(const Key('log_drink_advanced_button')), findsOneWidget);
    expect(find.byKey(const Key('log_drink_confirm_button')), findsOneWidget);
    // Volume field prefilled from the preset.
    expect(find.text('330'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 1b. Plain (non-Advanced) Confirm path — no test file existed for this
  // screen before, so this path (unchanged by #68) is covered here too.
  // -------------------------------------------------------------------------

  testWidgets(
      'plain Confirm calls logDrink with the edited volume and no '
      'name/abv/price overrides, and never touches the preset row', (
    tester,
  ) async {
    final repo = _FakeDrinksRepo();
    final container = await _buildContainer(
      repo: repo,
      visiblePresets: const [_beerPreset],
    );
    addTearDown(container.dispose);
    await _pumpSheet(tester, container);
    await _pickPreset(tester, 'Craft Lager');
    await _editVolume(tester, '500');

    await tester.tap(find.byKey(const Key('log_drink_confirm_button')));
    await tester.pumpAndSettle();

    expect(repo.logDrinkCalls, hasLength(1));
    final call = repo.logDrinkCalls.single;
    expect(call.preset.id, _beerPreset.id);
    expect(call.volumeMl, 500);
    // Plain _confirm() passes no name/abv/price overrides — the repo falls
    // back to the preset's own values (log_drink_sheet.dart _confirm).
    expect(call.name, isNull);
    expect(call.abvPercent, isNull);
    expect(call.priceMinor, const Optional<int?>.absent());
    expect(call.currency, const Optional<String?>.absent());

    expect(repo.updatePresetCalls, isEmpty);
    expect(repo.createPresetCalls, isEmpty);
  });

  // -------------------------------------------------------------------------
  // 2. Advanced button opens the editor, prefilled from the preset
  // -------------------------------------------------------------------------

  testWidgets(
    'Advanced button opens the Advanced editor with fields prefilled from '
    'the selected preset',
    (tester) async {
      final repo = _FakeDrinksRepo();
      final container = await _buildContainer(
        repo: repo,
        visiblePresets: const [_beerPreset],
      );
      addTearDown(container.dispose);
      await _pumpSheet(tester, container);
      await _pickPreset(tester, 'Craft Lager');
      await _openAdvanced(tester);

      // Editor is open: its name field key is unique (unlike the "Advanced"
      // text, which also matches the phase-2 button label underneath).
      expect(
        find.byKey(const Key('advanced_editor_name_field')),
        findsOneWidget,
      );

      // Source: log_drink_sheet.dart _AdvancedEditorSheetState.initState —
      // name/ABV/price controllers seeded from the preset.
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('advanced_editor_name_field')),
            )
            .controller!
            .text,
        'Craft Lager',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('advanced_editor_abv_field')),
            )
            .controller!
            .text,
        '5.0',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('advanced_editor_price_field')),
            )
            .controller!
            .text,
        '4.50',
      );
    },
  );

  // -------------------------------------------------------------------------
  // 3. Confirm button disabled for invalid name, enabled once valid
  // -------------------------------------------------------------------------

  testWidgets(
    'Advanced editor Confirm is disabled for an invalid name and enabled '
    'once the name is valid',
    (tester) async {
      final repo = _FakeDrinksRepo();
      final container = await _buildContainer(
        repo: repo,
        visiblePresets: const [_beerPreset],
      );
      addTearDown(container.dispose);
      await _pumpSheet(tester, container);
      await _pickPreset(tester, 'Craft Lager');
      await _openAdvanced(tester);

      // Preset name is valid initially -> Confirm enabled.
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('advanced_editor_confirm_button')),
            )
            .onPressed,
        isNotNull,
      );

      // Too short (< 3 runes) -> validatePresetName's structural error (same
      // string as preset_editor_screen_test.dart's "Name validation" group).
      await _fillAdvanced(tester, name: 'ab');
      expect(find.text('Must be 3–30 characters.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('advanced_editor_confirm_button')),
            )
            .onPressed,
        isNull,
      );

      // A valid name re-enables Confirm.
      await _fillAdvanced(tester, name: 'Craft Lager Deluxe');
      expect(find.text('Must be 3–30 characters.'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('advanced_editor_confirm_button')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  // -------------------------------------------------------------------------
  // 4. ABV field presence
  // -------------------------------------------------------------------------

  testWidgets('ABV field is present for an alcoholic preset', (tester) async {
    final repo = _FakeDrinksRepo();
    final container = await _buildContainer(
      repo: repo,
      visiblePresets: const [_beerPreset],
    );
    addTearDown(container.dispose);
    await _pumpSheet(tester, container);
    await _pickPreset(tester, 'Craft Lager');
    await _openAdvanced(tester);

    expect(find.byKey(const Key('advanced_editor_abv_field')), findsOneWidget);
  });

  testWidgets('ABV field is absent for a non-alcoholic preset', (tester) async {
    final repo = _FakeDrinksRepo();
    final container = await _buildContainer(
      repo: repo,
      visiblePresets: const [_waterPreset],
    );
    addTearDown(container.dispose);
    await _pumpSheet(tester, container);
    await _pickPreset(tester, 'Glass of water');
    await _openAdvanced(tester);

    expect(find.byKey(const Key('advanced_editor_name_field')), findsOneWidget);
    expect(find.byKey(const Key('advanced_editor_abv_field')), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 5. Path discrimination — the three S2 Advanced exit paths
  // -------------------------------------------------------------------------

  group('Path discrimination (user-experience.md §S2 Advanced exit paths)', () {
    testWidgets(
        'Advanced -> Confirm calls logDrink with the edited values and '
        'never touches the preset row', (tester) async {
      final repo = _FakeDrinksRepo();
      final container = await _buildContainer(
        repo: repo,
        visiblePresets: const [_beerPreset],
      );
      addTearDown(container.dispose);
      await _pumpSheet(tester, container);
      await _pickPreset(tester, 'Craft Lager');
      await _editVolume(tester, '500');
      await _openAdvanced(tester);

      await _fillAdvanced(
        tester,
        name: 'Craft Lager Deluxe',
        abv: '6.5',
        price: '5.25',
      );

      await tester.tap(find.byKey(const Key('advanced_editor_confirm_button')));
      await tester.pumpAndSettle();

      expect(repo.logDrinkCalls, hasLength(1));
      final call = repo.logDrinkCalls.single;
      // "Confirm — logs the drink with the entered values for this entry
      // only. The underlying preset is unchanged."
      expect(call.preset.id, _beerPreset.id);
      // Edited phase-2 volume (500), not the preset default (330) — proves
      // the sheet reads from _volumeCtrl, not preset.volumeMl.
      expect(call.volumeMl, 500);
      expect(call.name, 'Craft Lager Deluxe');
      expect(call.abvPercent, 6.5);
      expect(call.priceMinor, const Optional.value(525));
      expect(call.currency, const Optional.value('EUR'));

      expect(repo.updatePresetCalls, isEmpty);
      expect(repo.createPresetCalls, isEmpty);
    });

    testWidgets(
      'Advanced -> Confirm with the price field cleared logs this entry '
      'with no price, instead of falling back to the preset\'s stored '
      'price (regression: entry-only price-clear must not resolve to the '
      'preset default)',
      (tester) async {
        final repo = _FakeDrinksRepo();
        final container = await _buildContainer(
          repo: repo,
          visiblePresets: const [_beerPreset],
        );
        addTearDown(container.dispose);
        await _pumpSheet(tester, container);
        await _pickPreset(tester, 'Craft Lager');
        await _editVolume(tester, '500');
        await _openAdvanced(tester);

        // _beerPreset has a regularPriceMinor; clearing the pre-filled price
        // field must explicitly clear it for this entry, not silently keep
        // the preset's stored price (drinks_repository.dart logDrink).
        await _fillAdvanced(tester, name: 'Craft Lager', abv: '5.0', price: '');

        await tester.tap(
          find.byKey(const Key('advanced_editor_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(repo.logDrinkCalls, hasLength(1));
        final call = repo.logDrinkCalls.single;
        expect(call.priceMinor, const Optional<int?>.value(null));
        expect(call.currency, const Optional<String?>.value(null));
      },
    );

    testWidgets(
      'Advanced -> menu -> "Save and confirm" calls updatePreset with the '
      'edited fields, then logDrink, and never calls createPreset',
      (tester) async {
        final repo = _FakeDrinksRepo()
          // Simulates the post-update refetch reflecting the edited fields —
          // log_drink_sheet.dart: `getPresetById(preset.id) ?? preset`.
          ..refetchResult = const DrinkPreset(
            id: 'preset-beer',
            name: 'Craft Lager Deluxe',
            beverageType: BeverageType.beer,
            volumeMl: 330,
            abvPercent: 6.5,
            regularPriceMinor: 525,
            regularCurrency: 'EUR',
            iconKey: 'bottle',
            iconColor: '#111111',
            isUserCreated: true,
            isHidden: false,
            sortOrder: 1,
          );
        final container = await _buildContainer(
          repo: repo,
          visiblePresets: const [_beerPreset],
        );
        addTearDown(container.dispose);
        await _pumpSheet(tester, container);
        await _pickPreset(tester, 'Craft Lager');
        await _editVolume(tester, '500');
        await _openAdvanced(tester);

        await _fillAdvanced(
          tester,
          name: 'Craft Lager Deluxe',
          abv: '6.5',
          price: '5.25',
        );

        await _selectMenuAction(tester, 'Save and confirm');

        expect(repo.updatePresetCalls, hasLength(1));
        final update = repo.updatePresetCalls.single;
        expect(update.id, 'preset-beer');
        expect(update.name, 'Craft Lager Deluxe');
        expect(update.abvPercent, const Optional.value(6.5));
        expect(update.regularPriceMinor, const Optional.value(525));
        expect(update.regularCurrency, const Optional.value('EUR'));

        expect(repo.logDrinkCalls, hasLength(1));
        // logDrink is called against the refetched (edited) preset, not raw
        // name/abv/price overrides — saveAndConfirm passes only volume/time.
        expect(repo.logDrinkCalls.single.preset.name, 'Craft Lager Deluxe');
        expect(repo.logDrinkCalls.single.preset.abvPercent, 6.5);
        expect(repo.logDrinkCalls.single.name, isNull);
        // Edited phase-2 volume (500), not the preset default (330).
        expect(repo.logDrinkCalls.single.volumeMl, 500);

        expect(repo.createPresetCalls, isEmpty);
      },
    );

    testWidgets(
      'Advanced -> menu -> "Save as copy and confirm" -> confirm dialog '
      'calls createPreset then logDrink against the new preset, and '
      'never calls updatePreset',
      (tester) async {
        final repo = _FakeDrinksRepo(existingPresets: const [_beerPreset]);
        final container = await _buildContainer(
          repo: repo,
          visiblePresets: const [_beerPreset],
        );
        addTearDown(container.dispose);
        await _pumpSheet(tester, container);
        await _pickPreset(tester, 'Craft Lager');
        await _editVolume(tester, '500');
        await _openAdvanced(tester);

        await _fillAdvanced(
          tester,
          name: 'Craft Lager Deluxe',
          abv: '6.5',
          price: '5.25',
        );

        await tester.tap(find.byKey(const Key('advanced_editor_menu_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save as copy and confirm'));
        await tester.pumpAndSettle();

        // Copy-name dialog, prefilled '<name> (copy)'.
        expect(find.text('New preset name'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('advanced_editor_copy_name_field')),
              )
              .controller!
              .text,
          'Craft Lager Deluxe (copy)',
        );

        await tester.enterText(
          find.byKey(const Key('advanced_editor_copy_name_field')),
          'Craft Lager Copy',
        );
        await tester.tap(
          find.byKey(const Key('advanced_editor_copy_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(repo.createPresetCalls, hasLength(1));
        final create = repo.createPresetCalls.single;
        expect(create.name, 'Craft Lager Copy');
        expect(create.beverageType, BeverageType.beer);
        // Icon/colour are not editable in the Advanced editor — copied as-is.
        expect(create.iconKey, 'bottle');
        expect(create.iconColor, '#111111');
        // Edited phase-2 volume (500), not the preset default (330).
        expect(create.volumeMl, 500);
        expect(create.abvPercent, 6.5);
        expect(create.regularPriceMinor, 525);
        expect(create.regularCurrency, 'EUR');
        // sortOrder = existing preset count (1) + 1.
        expect(create.sortOrder, 2);

        expect(repo.logDrinkCalls, hasLength(1));
        expect(repo.logDrinkCalls.single.preset.id, 'created-preset');

        expect(repo.updatePresetCalls, isEmpty);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 6. Back button discards edits
  // -------------------------------------------------------------------------

  testWidgets(
    'Back button in the Advanced editor discards edits and returns to '
    'phase 2 with the original values, with no repo writes',
    (tester) async {
      final repo = _FakeDrinksRepo();
      final container = await _buildContainer(
        repo: repo,
        visiblePresets: const [_beerPreset],
      );
      addTearDown(container.dispose);
      await _pumpSheet(tester, container);
      await _pickPreset(tester, 'Craft Lager');
      await _openAdvanced(tester);

      await _fillAdvanced(tester, name: 'Something Else', abv: '9.9');

      await tester.tap(find.byKey(const Key('advanced_editor_back_button')));
      await tester.pumpAndSettle();

      // Back in phase 2 — LogDrinkSheet itself was never popped.
      expect(
        find.byKey(const Key('log_drink_advanced_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('log_drink_confirm_button')), findsOneWidget);
      // Original preset name still shown (phase 2's title uses preset.name,
      // never mutated by the discarded Advanced edit).
      expect(find.text('Craft Lager'), findsOneWidget);
      // Volume field still shows the preset default (330), unedited.
      expect(find.text('330'), findsOneWidget);

      expect(repo.logDrinkCalls, isEmpty);
      expect(repo.updatePresetCalls, isEmpty);
      expect(repo.createPresetCalls, isEmpty);
    },
  );

  // -------------------------------------------------------------------------
  // 7. Cancelling the copy-name dialog aborts the whole save-as-copy flow
  // -------------------------------------------------------------------------

  testWidgets(
    'Cancelling the copy-name dialog aborts the save-as-copy flow: no '
    'createPreset/logDrink call, Advanced editor stays open',
    (tester) async {
      final repo = _FakeDrinksRepo(existingPresets: const [_beerPreset]);
      final container = await _buildContainer(
        repo: repo,
        visiblePresets: const [_beerPreset],
      );
      addTearDown(container.dispose);
      await _pumpSheet(tester, container);
      await _pickPreset(tester, 'Craft Lager');
      await _openAdvanced(tester);

      await _fillAdvanced(tester, name: 'Craft Lager Deluxe');

      await tester.tap(find.byKey(const Key('advanced_editor_menu_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save as copy and confirm'));
      await tester.pumpAndSettle();

      expect(find.text('New preset name'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('advanced_editor_copy_cancel_button')),
      );
      await tester.pumpAndSettle();

      // Dialog dismissed; _finish returns early (newPresetName == null), so
      // the Advanced editor sheet is never popped and stays visible.
      expect(find.text('New preset name'), findsNothing);
      // Editor still open — its name field key is unique (unlike the
      // "Advanced" text, which also matches the phase-2 button label
      // underneath).
      expect(
        find.byKey(const Key('advanced_editor_name_field')),
        findsOneWidget,
      );

      expect(repo.createPresetCalls, isEmpty);
      expect(repo.logDrinkCalls, isEmpty);
      expect(repo.updatePresetCalls, isEmpty);
    },
  );

  // -------------------------------------------------------------------------
  // 8. Copy-name dialog validates the name (its "(copy)" default can overflow
  //    the 30-rune limit on its own for a long-enough base name).
  // -------------------------------------------------------------------------

  testWidgets(
    'Copy-name dialog disables Create for an over-length default name and '
    're-enables it once edited to a valid name',
    (tester) async {
      final repo = _FakeDrinksRepo(existingPresets: const [_beerPreset]);
      final container = await _buildContainer(
        repo: repo,
        visiblePresets: const [_beerPreset],
      );
      addTearDown(container.dispose);
      await _pumpSheet(tester, container);
      await _pickPreset(tester, 'Craft Lager');
      await _openAdvanced(tester);

      // 24-char base name + ' (copy)' (7 chars) = 31 runes, over the 30 max.
      await _fillAdvanced(tester, name: 'Craft Lager Super Deluxe');

      await tester.tap(find.byKey(const Key('advanced_editor_menu_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save as copy and confirm'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('advanced_editor_copy_name_field')),
            )
            .controller!
            .text,
        'Craft Lager Super Deluxe (copy)',
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('advanced_editor_copy_confirm_button')),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('advanced_editor_copy_name_field')),
        'Craft Lager Copy',
      );
      await tester.pump();

      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('advanced_editor_copy_confirm_button')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(
        find.byKey(const Key('advanced_editor_copy_confirm_button')),
      );
      await tester.pumpAndSettle();

      expect(repo.createPresetCalls.single.name, 'Craft Lager Copy');
    },
  );
}
