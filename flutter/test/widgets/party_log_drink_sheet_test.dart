// Widget tests for PartyLogDrinkSheet's name/price fields (issue #85).
//
// Coverage:
//  1. Name field pre-fills with the picked preset's name and is editable;
//     an emptied name blocks Confirm (nameError != null -> onPressed: null).
//  2. Price field is optional: leaving it blank pops a selection with
//     priceMinor == null (party_log_drink_sheet.dart doc: "the caller should
//     resolve the price the usual way instead").
//  3. Entering a price pops priceMinor/currency correctly — currency from
//     the preset's regularCurrency, falling back to the user's preferred
//     currency when the preset has none (party_log_drink_sheet.dart
//     `_currency` getter).
//
// Harness: PartyLogDrinkSheet only reads visibleAlcoholicPresetsProvider
// (preset-pick phase) and userPreferencesProvider (price-currency fallback)
// — both overridden with Stream.value(...), same convention as
// party_screen_test.dart's _buildScreen.

import 'package:drinks_mate/src/db/app_database.dart' show kUserPreferencesId;
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/party_log_drink_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

UserPreferences _makePrefs({String currency = 'EUR'}) => UserPreferences(
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

/// Carries its own regularCurrency ('EUR') — used for the "price field
/// entered" test that must resolve currency from the PRESET, not user prefs.
const _pricedBeerPreset = DrinkPreset(
  id: 'preset-priced-beer',
  name: 'Priced Beer',
  beverageType: BeverageType.beer,
  volumeMl: 330,
  abvPercent: 5.0,
  regularPriceMinor: 450,
  regularCurrency: 'EUR',
  iconKey: 'beer_glass',
  iconColor: '#d97706',
  isUserCreated: false,
  isHidden: false,
  sortOrder: 1,
);

/// No regularCurrency — used for the "currency falls back to user prefs"
/// test.
const _unpricedBeerPreset = DrinkPreset(
  id: 'preset-unpriced-beer',
  name: 'Unpriced Beer',
  beverageType: BeverageType.beer,
  volumeMl: 330,
  abvPercent: 5.0,
  iconKey: 'beer_glass',
  iconColor: '#d97706',
  isUserCreated: false,
  isHidden: false,
  sortOrder: 1,
);

/// Pumps [PartyLogDrinkSheet] as a route pushed onto a bare [Scaffold], so
/// the popped [AlcoholicDrinkSelection] can be captured via the returned
/// Future — mirrors log_drink_sheet_test.dart's push-based harness for
/// capturing a sheet's pop value.
class _ResultBox {
  AlcoholicDrinkSelection? value;
}

/// Scrolls the confirm phase's `ListView` (Name/Volume/ABV/Price/Time) until
/// [finder] is visible — the sliver lazily mounts children below the fold,
/// same trap documented in settings_screen_test.dart's `_scrollToVisible`.
Future<void> _scrollToVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _pushSheet(
  WidgetTester tester,
  ProviderContainer container,
  _ResultBox box,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  box.value =
                      await showModalBottomSheet<AlcoholicDrinkSelection>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => const PartyLogDrinkSheet(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// [userPreferencesProvider] is pre-warmed (`.future` awaited) because
/// nothing in [PartyLogDrinkSheet]'s own widget tree `ref.watch`es it — the
/// `_currency` getter only `ref.read`s it lazily, from the Confirm tap
/// handler. Without warming, that first `ref.read` on a freshly-created
/// StreamProvider observes `AsyncLoading` (`valueOrNull == null`) instead of
/// the overridden preferences (same trap documented in
/// today_screen_test.dart's `_buildWarmContainer` / log_drink_sheet_test.dart's
/// `_buildContainer`).
Future<ProviderContainer> _buildContainer({
  required List<DrinkPreset> alcoholicPresets,
  UserPreferences? prefs,
}) async {
  final container = ProviderContainer(
    overrides: [
      visibleAlcoholicPresetsProvider.overrideWith(
        (_) => Stream.value(alcoholicPresets),
      ),
      userPreferencesProvider.overrideWith(
        (_) => Stream.value(prefs ?? _makePrefs()),
      ),
    ],
  );
  await container.read(userPreferencesProvider.future);
  return container;
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Name field: pre-fill, editable, empty blocks Confirm
  // -------------------------------------------------------------------------

  group('Name field (party_log_drink_sheet.dart party_log_drink_name_field)',
      () {
    testWidgets('pre-fills with the picked preset\'s name', (tester) async {
      final container = await _buildContainer(
        alcoholicPresets: const [_pricedBeerPreset],
      );
      addTearDown(container.dispose);
      final box = _ResultBox();
      await _pushSheet(tester, container, box);

      await tester.tap(find.text('Priced Beer'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('party_log_drink_name_field')),
            )
            .controller!
            .text,
        'Priced Beer',
      );
    });

    testWidgets(
      'is editable — Confirm pops the AlcoholicDrinkSelection with the '
      'edited name, not the preset\'s original name',
      (tester) async {
        final container = await _buildContainer(
          alcoholicPresets: const [_pricedBeerPreset],
        );
        addTearDown(container.dispose);
        final box = _ResultBox();
        await _pushSheet(tester, container, box);

        await tester.tap(find.text('Priced Beer'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('party_log_drink_name_field')),
          'My Custom Beer Name',
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        expect(box.value, isNotNull);
        expect(box.value!.name, 'My Custom Beer Name');
      },
    );

    testWidgets(
      'an emptied name shows an error and disables Confirm '
      '(party_log_drink_sheet.dart _onNameChanged: "Name is required")',
      (tester) async {
        final container = await _buildContainer(
          alcoholicPresets: const [_pricedBeerPreset],
        );
        addTearDown(container.dispose);
        final box = _ResultBox();
        await _pushSheet(tester, container, box);

        await tester.tap(find.text('Priced Beer'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('party_log_drink_name_field')),
          '',
        );
        await tester.pump();

        expect(find.text('Name is required'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Confirm'))
              .onPressed,
          isNull,
        );

        // Tapping a disabled button is a no-op — sheet stays open, nothing
        // popped.
        await tester.tap(
          find.widgetWithText(FilledButton, 'Confirm'),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(box.value, isNull);
      },
    );

    testWidgets(
      'a structurally-invalid name (too short) also blocks Confirm — same '
      'validatePresetName rule as DrinkPreset names elsewhere',
      (tester) async {
        final container = await _buildContainer(
          alcoholicPresets: const [_pricedBeerPreset],
        );
        addTearDown(container.dispose);
        final box = _ResultBox();
        await _pushSheet(tester, container, box);

        await tester.tap(find.text('Priced Beer'));
        await tester.pumpAndSettle();

        // < 3 runes — validatePresetName's structural error.
        await tester.enterText(
          find.byKey(const Key('party_log_drink_name_field')),
          'ab',
        );
        await tester.pump();

        expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Confirm'))
              .onPressed,
          isNull,
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // 2 & 3. Price field: optional, resolves currency correctly when entered
  // -------------------------------------------------------------------------

  group(
      'Price field (party_log_drink_sheet.dart party_log_drink_price_field '
      '— party-session.md §Logging an alcoholic drink (during a session))', () {
    testWidgets(
      'left blank: popped selection has priceMinor == null (caller resolves '
      'the price the usual way instead)',
      (tester) async {
        final container = await _buildContainer(
          alcoholicPresets: const [_pricedBeerPreset],
        );
        addTearDown(container.dispose);
        final box = _ResultBox();
        await _pushSheet(tester, container, box);

        await tester.tap(find.text('Priced Beer'));
        await tester.pumpAndSettle();
        // ABV/volume are pre-filled from the preset — no edits needed to
        // satisfy _confirm()'s volume/abv guard.

        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        expect(box.value, isNotNull);
        expect(box.value!.priceMinor, isNull);
        expect(box.value!.currency, isNull);
      },
    );

    testWidgets(
      'entering a price pops priceMinor (minor units, rounded) and currency '
      'from the preset\'s regularCurrency',
      (tester) async {
        final container = await _buildContainer(
          alcoholicPresets: const [_pricedBeerPreset],
        );
        addTearDown(container.dispose);
        final box = _ResultBox();
        await _pushSheet(tester, container, box);

        await tester.tap(find.text('Priced Beer'));
        await tester.pumpAndSettle();

        final priceField = find.byKey(
          const Key('party_log_drink_price_field'),
        );
        await _scrollToVisible(tester, priceField);
        await tester.enterText(priceField, '5.25');
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        expect(box.value, isNotNull);
        expect(box.value!.priceMinor, 525);
        // _pricedBeerPreset.regularCurrency ('EUR') takes priority over the
        // user's prefs currency ('EUR' too here, but see the fallback test
        // below for the discriminating case).
        expect(box.value!.currency, 'EUR');
      },
    );

    testWidgets(
      'currency falls back to the user\'s preferred currency when the '
      'preset has no regularCurrency of its own (same fallback pattern as '
      'the old Advanced editor\'s price resolution)',
      (tester) async {
        final container = await _buildContainer(
          alcoholicPresets: const [_unpricedBeerPreset],
          prefs: _makePrefs(currency: 'USD'),
        );
        addTearDown(container.dispose);
        final box = _ResultBox();
        await _pushSheet(tester, container, box);

        await tester.tap(find.text('Unpriced Beer'));
        await tester.pumpAndSettle();

        final priceField = find.byKey(
          const Key('party_log_drink_price_field'),
        );
        await _scrollToVisible(tester, priceField);
        await tester.enterText(priceField, '3.00');
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        expect(box.value, isNotNull);
        expect(box.value!.priceMinor, 300);
        expect(box.value!.currency, 'USD');
      },
    );
  });
}
