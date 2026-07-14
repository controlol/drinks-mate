// Widget tests for S7/issue #22 — PartyScreen.
//
// Coverage (mapped to the issue's acceptance criteria):
//  1. BAC card with known inputs — party-session.md §Worked example (75 kg,
//     180 cm, 30-year-old male; two 250 ml 5% ABV beers, same total alcohol
//     dose as one 500 ml 5% ABV entry): initial value, elimination after 2 h,
//     and the Widmark (null-height) fallback path.
//  2. Approaching-cap threshold — party-session.md §BAC goal (cap) / Parity
//     Rulebook `isApproachingCap`: banner shows at >=80% of cap, hidden below.
//  3. Meal prompt — party-session.md §Meals: log-alcohol flow ends with a
//     skippable Small/Medium/Large/Skip prompt; picking a size calls
//     PartySessionRepository.addMeal, Skip calls nothing.
//  4. Under-18 gate — party-session.md §Starting a session: under-18 profile
//     shows the gate instead of "Start party session"; 18+/no-birthdate show
//     the normal Start button.
//
// Provider override pattern mirrors flutter/test/widgets/today_drinks_screen_test.dart
// and flutter/test/widgets/settings_screen_test.dart — fake repository
// subclasses record calls without touching the DB; every stream provider is
// overridden with Stream.value(...) (including nowTickerProvider, mirroring
// flutter/test/widget_test.dart's note about the real 1-minute periodic
// ticker hanging pumpAndSettle).
//
// Numeric fixtures: rather than hand-deriving expected BAC strings, this file
// computes the expected g/L / mmol/L values via `core`'s own BAC functions
// (the same functions bac_estimator.dart calls), the same convention used by
// flutter/packages/core/test/bac_test.dart and
// flutter/test/party_session_repository_test.dart. The worked example's two
// simultaneous 250 ml beers are modelled as a single 500 ml entry with the
// same total alcohol dose — party_session_repository_test.dart's "orphan
// absorption" group already documents why: bac_estimator.dart's
// estimateSessionBac() computes each entry's BAC_initial from *that entry's
// own* alcohol grams and then eliminates each entry's contribution
// independently (clamped to >=0) before summing. At t=0 this collapses to the
// same total as the worked example's combined-dose arithmetic (linear in
// grams), but at t=2h it would NOT: two independent 9.86 g contributions
// (BAC_initial ≈ 0.180 each) individually reach zero at ≈1.2 h, so summing
// them at 2h would render 0.00 g/L, not the ≈0.06 g/L the worked example
// describes for a single combined 19.73 g dose. Using one 500 ml entry avoids
// that divergence and reproduces the doc's numbers under the real
// implementation.

import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/meal.dart';
import 'package:drinks_mate/src/models/optional.dart';
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/party_session_price.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/models/user_profile.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/party_session_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/party_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repositories — record calls without touching a real DB (beyond the
// throwaway in-memory instance each superclass constructor requires).
// Mirrors _FakeRepo in today_drinks_screen_test.dart / _FakePreferencesRepo
// in settings_screen_test.dart.
// ---------------------------------------------------------------------------

class _FakePartySessionRepo extends PartySessionRepository {
  _FakePartySessionRepo() : super(AppDatabase(NativeDatabase.memory()));

  final List<({String sessionId, MealSize size})> addMealCalls = [];
  final List<({String sessionId, String presetId})> logAlcoholicDrinkCalls = [];
  final List<DateTime?> startSessionCalls = [];

  /// Deterministic id so tests can assert on it without reading it back off
  /// a returned value threaded through several awaits.
  String nextSessionId = 'new-session-1';

  /// Tracks the most recently started fake session so [getSessionById] (used
  /// by the start-session flow to refresh its in-memory copy after the
  /// pricing prompt) can resolve it without touching the real DB.
  PartySession? _lastSession;

  @override
  Future<PartySession> startSession({
    DateTime? startedAt,
    bool useSessionPrices = false,
    String? tokenName,
    int? tokenValueMinor,
    String? tokenValueCurrency,
    DateTime? now,
  }) async {
    startSessionCalls.add(startedAt);
    final at = now ?? DateTime.now();
    final session = PartySession(
      id: nextSessionId,
      startedAt: startedAt ?? at,
      useSessionPrices: useSessionPrices,
      tokenName: tokenName,
      tokenValueMinor: tokenValueMinor,
      tokenValueCurrency: tokenValueCurrency,
      createdAt: at,
      updatedAt: at,
    );
    _lastSession = session;
    return session;
  }

  @override
  Future<PartySession> getSessionById(String id) async {
    final session = _lastSession;
    if (session != null && session.id == id) return session;
    throw StateError('PartySession $id not found.');
  }

  @override
  Future<DrinkEntry> logAlcoholicDrink({
    required DrinkPreset preset,
    required String sessionId,
    int? volumeMl,
    double? abvPercent,
    DateTime? consumedAt,
    int? priceMinor,
    String? currency,
    int? priceTokens,
    int? tokenValueMinor,
    String? tokenValueCurrency,
    DateTime? now,
  }) async {
    logAlcoholicDrinkCalls.add((sessionId: sessionId, presetId: preset.id));
    final at = now ?? DateTime.now();
    return DrinkEntry(
      id: 'fake-logged-entry',
      name: preset.name,
      beverageType: preset.beverageType,
      volumeMl: volumeMl ?? preset.volumeMl,
      abvPercent: abvPercent ?? preset.abvPercent,
      partySessionId: sessionId,
      consumedAt: consumedAt ?? at,
      createdAt: at,
      updatedAt: at,
    );
  }

  @override
  Future<Meal> addMeal({
    required String sessionId,
    required MealSize size,
    DateTime? eatenAt,
    DateTime? now,
  }) async {
    addMealCalls.add((sessionId: sessionId, size: size));
    final at = now ?? DateTime.now();
    return Meal(
      id: 'fake-meal',
      partySessionId: sessionId,
      size: size,
      eatenAt: eatenAt ?? at,
      createdAt: at,
      updatedAt: at,
    );
  }
}

class _FakeDrinksRepo extends DrinksRepository {
  _FakeDrinksRepo() : super(AppDatabase(NativeDatabase.memory()));

  final List<({String presetId, double? abvPercent})> logDrinkCalls = [];

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
    logDrinkCalls.add((presetId: preset.id, abvPercent: abvPercent));
  }
}

// ---------------------------------------------------------------------------
// Fixture builders
// ---------------------------------------------------------------------------

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

UserPreferences _makePrefs({double? bacCapGramsPerL}) {
  return UserPreferences(
    id: kUserPreferencesId,
    username: 'tester',
    dailyGoalMl: 2000,
    dayBoundaryHour: 5,
    units: 'metric',
    currency: 'EUR',
    reminderEnabled: false,
    reminderStartHour: 8,
    reminderEndHour: 22,
    reminderIntervalMin: 90,
    inactivityReminderEnabled: false,
    weeklySummaryEnabled: false,
    bacCapGramsPerL: bacCapGramsPerL,
    bacOnLockScreenEnabled: false,
    approachingCapNotifEnabled: false,
    soberEstimateNotifEnabled: false,
    alcoholicPresetsAlwaysVisible: true,
    installedAt: _epoch,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

UserProfile _makeProfile({
  String gender = 'male',
  double? weightKg = 75,
  double? heightCm = 180,
  String? birthDate,
}) {
  return UserProfile(
    id: 'profile-1',
    gender: gender,
    weightKg: weightKg,
    heightCm: heightCm,
    birthDate: birthDate,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

PartySession _makeSession({required DateTime startedAt, String id = 's1'}) {
  return PartySession(
    id: id,
    startedAt: startedAt,
    useSessionPrices: false,
    createdAt: startedAt,
    updatedAt: startedAt,
  );
}

DrinkEntry _alcoholicEntry({
  required int volumeMl,
  required double abvPercent,
  required DateTime consumedAt,
  String id = 'entry-1',
}) {
  return DrinkEntry(
    id: id,
    beverageType: BeverageType.beer,
    volumeMl: volumeMl,
    abvPercent: abvPercent,
    consumedAt: consumedAt,
    createdAt: consumedAt,
    updatedAt: consumedAt,
  );
}

const _beerPreset = DrinkPreset(
  id: 'preset-beer',
  name: 'Test Beer',
  beverageType: BeverageType.beer,
  volumeMl: 250,
  abvPercent: 5.0,
  iconKey: 'beer_glass',
  iconColor: '#d97706',
  isUserCreated: false,
  isHidden: false,
  sortOrder: 1,
);

/// ISO-8601 'yyyy-MM-dd' matching UserProfile.birthDate's stored format.
String _isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Builds a testable PartyScreen with every provider PartyScreen reads
/// overridden — no real Drift stream is ever started (avoids the
/// pending-timer teardown issue noted in widget_test.dart).
Widget _buildScreen({
  PartySession? session,
  List<DrinkEntry> entries = const [],
  List<Meal> meals = const [],
  UserProfile? profile,
  UserPreferences? prefs,
  required _FakePartySessionRepo partyRepo,
  _FakeDrinksRepo? drinksRepo,
  DateTime? now,
  List<DrinkPreset> alcoholicPresets = const [],
}) {
  return ProviderScope(
    overrides: [
      partySessionRepositoryProvider.overrideWithValue(partyRepo),
      if (drinksRepo != null)
        drinksRepositoryProvider.overrideWithValue(drinksRepo),
      activePartySessionProvider.overrideWith((_) => Stream.value(session)),
      partySessionEntriesProvider.overrideWith(
        (ref, sessionId) => Stream.value(entries),
      ),
      partySessionMealsProvider.overrideWith(
        (ref, sessionId) => Stream.value(meals),
      ),
      partySessionPricesProvider.overrideWith(
        (ref, sessionId) => Stream.value(const <PartySessionPrice>[]),
      ),
      userProfileProvider.overrideWith((_) => Stream.value(profile)),
      userPreferencesProvider.overrideWith(
        (_) => Stream.value(prefs ?? _makePrefs()),
      ),
      // Single-value override — the real nowTickerProvider is a repeating
      // 1-minute Stream.periodic that would otherwise hang pumpAndSettle
      // (same convention as widget_test.dart's activePartySessionProvider
      // note).
      nowTickerProvider.overrideWith(
        (_) => Stream.value(now ?? DateTime.now()),
      ),
      visibleAlcoholicPresetsProvider.overrideWith(
        (_) => Stream.value(alcoholicPresets),
      ),
    ],
    child: const MaterialApp(home: PartyScreen()),
  );
}

// ---------------------------------------------------------------------------
// Shared worked-example fixture (party-session.md §Worked example): 75 kg,
// 180 cm, 30-year-old male; total alcohol dose of two 250 ml 5% ABV beers
// modelled as one 500 ml 5% ABV entry (see file-level comment for why).
// Expected values are computed via `core`'s own BAC functions — the same
// functions bac_estimator.dart's estimateSessionBac() calls — not
// hand-derived, and cross-checked against flutter/packages/core/test/
// bac_test.dart's worked-example vectors (closeTo 0.360 g/L / 7.82 mmol/L /
// 0.060 g/L after 2h).
// ---------------------------------------------------------------------------

// Birthdate deliberately ~30 years and 1 month before consumedAt, not
// exactly 30 years: age.dart's `floor((today - birthDate) / 365.25)` (Parity
// Rulebook formula) rounds an *exact* 30-calendar-year gap down to 29 (30
// calendar years is 10957 days here, one short of 30*365.25 = 10957.5). The
// extra month of margin lands cleanly on age 30, matching the worked
// example's stated age and its clean 0.360 g/L / 7.82 mmol/L figures
// (verified via the sanity test below, not assumed).
const _workedBirthDate = '1996-06-01';
final _workedConsumedAt = DateTime.utc(2026, 7, 1, 12, 0);
final _workedAgeYears = ageYearsFromBirthDate(
  birthDate: DateTime.parse(_workedBirthDate),
  today: _workedConsumedAt.toLocal(),
);
final _workedGrams = alcoholGrams(volumeMl: 500, abvPercent: 5.0);
final _workedTbw = watsonTbwLitres(
  gender: Gender.male,
  ageYears: _workedAgeYears,
  heightCm: 180,
  weightKg: 75,
);
final _workedBacInitial = bacInitialWatson(
  alcoholGrams: _workedGrams,
  tbwLitres: _workedTbw,
);
final _workedBacAfter2h = bacAtTime(
  bacInitial: _workedBacInitial,
  hoursSince: 2,
);

void main() {
  // -------------------------------------------------------------------------
  // 1. BAC card with known inputs
  // -------------------------------------------------------------------------

  group('BAC card — known inputs (party-session.md §Worked example)', () {
    test('sanity: matches the formula-correct worked-example vectors', () {
      // Cross-checked against flutter/packages/core/test/bac_test.dart lines
      // 37-49 (same total alcohol dose, same profile).
      expect(_workedBacInitial, closeTo(0.360, 0.001));
      expect(gPerLToMmol(_workedBacInitial), closeTo(7.82, 0.02));
      expect(_workedBacAfter2h, closeTo(0.060, 0.001));
    });

    testWidgets('renders the initial BAC in g/L and mmol/L, 2 dp, no cap bar', (
      tester,
    ) async {
      final repo = _FakePartySessionRepo();
      final session = _makeSession(startedAt: _workedConsumedAt);
      final profile = _makeProfile(birthDate: _workedBirthDate);
      final entries = [
        _alcoholicEntry(
          volumeMl: 500,
          abvPercent: 5.0,
          consumedAt: _workedConsumedAt,
        ),
      ];

      await tester.pumpWidget(
        _buildScreen(
          session: session,
          entries: entries,
          profile: profile,
          partyRepo: repo,
          now: _workedConsumedAt, // elapsed = 0
        ),
      );
      await tester.pumpAndSettle();

      final gPerLText = _workedBacInitial.toStringAsFixed(2);
      final mmolText = gPerLToMmol(_workedBacInitial).toStringAsFixed(2);

      // Source: party_screen.dart _BacCard.build — '$gPerLText g/L' and
      // '≈ $mmolText mmol/L' as separate Text widgets.
      expect(find.text('$gPerLText g/L'), findsOneWidget);
      expect(find.text('≈ $mmolText mmol/L'), findsOneWidget);

      // No cap configured → no _CapReferenceBar / "Personal cap:" label.
      expect(find.textContaining('Personal cap:'), findsNothing);
    });

    testWidgets(
      'renders the elimination-adjusted BAC 2 hours after consumption',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final session = _makeSession(startedAt: _workedConsumedAt);
        final profile = _makeProfile(birthDate: _workedBirthDate);
        final entries = [
          _alcoholicEntry(
            volumeMl: 500,
            abvPercent: 5.0,
            consumedAt: _workedConsumedAt,
          ),
        ];
        final at = _workedConsumedAt.add(const Duration(hours: 2));

        await tester.pumpWidget(
          _buildScreen(
            session: session,
            entries: entries,
            profile: profile,
            partyRepo: repo,
            now: at,
          ),
        );
        await tester.pumpAndSettle();

        final gPerLText = _workedBacAfter2h.toStringAsFixed(2);
        expect(find.text('$gPerLText g/L'), findsOneWidget);
      },
    );

    testWidgets('null height (Widmark fallback) still renders the BAC card', (
      tester,
    ) async {
      // party-session.md §Required user inputs: "When height is missing,
      // it falls back to Widmark." Expected value computed via the same
      // core functions PartySessionRepository's own Widmark test uses
      // (flutter/test/party_session_repository_test.dart "Widmark fallback
      // path" group), not hand-derived.
      final repo = _FakePartySessionRepo();
      final session = _makeSession(startedAt: _workedConsumedAt);
      final profile = _makeProfile(birthDate: _workedBirthDate, heightCm: null);
      final entries = [
        _alcoholicEntry(
          volumeMl: 500,
          abvPercent: 5.0,
          consumedAt: _workedConsumedAt,
        ),
      ];

      final widmarkBacInitial = bacInitialWidmark(
        alcoholGrams: _workedGrams,
        weightKg: 75,
        r: widmarkR(Gender.male),
      );

      await tester.pumpWidget(
        _buildScreen(
          session: session,
          entries: entries,
          profile: profile,
          partyRepo: repo,
          now: _workedConsumedAt,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('${widmarkBacInitial.toStringAsFixed(2)} g/L'),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 2. Approaching-cap threshold
  // -------------------------------------------------------------------------

  group(
      'Approaching-cap banner (party-session.md §BAC goal (cap) / '
      'isApproachingCap: bac >= 80% of cap)', () {
    testWidgets(
      'cap 0.4 g/L — worked-example BAC (0.360) is >=80% (0.32) — banner '
      'shown',
      (tester) async {
        // Source: flutter/packages/core/test/bac_test.dart line 320-324
        // ("worked-example BAC (0.360 g/L) against a 0.4 g/L cap is
        // approaching").
        final repo = _FakePartySessionRepo();
        final session = _makeSession(startedAt: _workedConsumedAt);
        final profile = _makeProfile(birthDate: _workedBirthDate);
        final entries = [
          _alcoholicEntry(
            volumeMl: 500,
            abvPercent: 5.0,
            consumedAt: _workedConsumedAt,
          ),
        ];

        await tester.pumpWidget(
          _buildScreen(
            session: session,
            entries: entries,
            profile: profile,
            prefs: _makePrefs(bacCapGramsPerL: 0.4),
            partyRepo: repo,
            now: _workedConsumedAt,
          ),
        );
        await tester.pumpAndSettle();

        // find.bySemanticsLabel requires an active SemanticsHandle
        // (tester.ensureSemantics()), which most widget tests in this repo
        // don't enable — assert on the visible text instead, which is the
        // same string as SemanticsLabels.approachingCapBanner (see
        // party_screen.dart _ApproachingCapBanner.build).
        expect(find.text('Approaching your personal cap'), findsOneWidget);
      },
    );

    testWidgets(
        'cap 1.0 g/L — worked-example BAC (0.360) is below 80% (0.8) — '
        'banner absent', (tester) async {
      final repo = _FakePartySessionRepo();
      final session = _makeSession(startedAt: _workedConsumedAt);
      final profile = _makeProfile(birthDate: _workedBirthDate);
      final entries = [
        _alcoholicEntry(
          volumeMl: 500,
          abvPercent: 5.0,
          consumedAt: _workedConsumedAt,
        ),
      ];

      await tester.pumpWidget(
        _buildScreen(
          session: session,
          entries: entries,
          profile: profile,
          prefs: _makePrefs(bacCapGramsPerL: 1.0),
          partyRepo: repo,
          now: _workedConsumedAt,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Approaching your personal cap'), findsNothing);
    });

    testWidgets(
      'no cap set — renders without crashing and without the banner',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final session = _makeSession(startedAt: _workedConsumedAt);
        final profile = _makeProfile(birthDate: _workedBirthDate);
        final entries = [
          _alcoholicEntry(
            volumeMl: 500,
            abvPercent: 5.0,
            consumedAt: _workedConsumedAt,
          ),
        ];

        await tester.pumpWidget(
          _buildScreen(
            session: session,
            entries: entries,
            profile: profile,
            prefs: _makePrefs(),
            partyRepo: repo,
            now: _workedConsumedAt,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Approaching your personal cap'), findsNothing);
        expect(find.textContaining('Personal cap:'), findsNothing);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 3. Meal prompt — issue #22's own Scope/Acceptance-criteria bullets state
  // (verbatim, twice) that the prompt "appears after each alcoholic drink
  // log". party-session.md §Meals separately describes a single start-of-
  // session prompt plus an always-available "add meal" affordance during the
  // session — but that affordance is explicitly out of this issue's Scope
  // list, so a start-only prompt with no other way to log a meal would make
  // meals effectively unloggable whenever the user skips it once. Per-drink
  // is therefore the coherent choice for this issue's scope, matching what
  // the issue's AC literally asks for and what _handleLogAlcohol implements.
  // -------------------------------------------------------------------------

  group(
      'Meal prompt (issue #22 AC: "Meal prompt appears after each alcoholic '
      'drink log")', () {
    testWidgets(
      'Log alcohol into an active session -> meal prompt -> Medium calls '
      'addMeal(sessionId, MealSize.medium)',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final session = _makeSession(startedAt: _workedConsumedAt);
        final profile = _makeProfile(birthDate: _workedBirthDate);

        await tester.pumpWidget(
          _buildScreen(
            session: session,
            profile: profile,
            partyRepo: repo,
            now: _workedConsumedAt,
            alcoholicPresets: const [_beerPreset],
          ),
        );
        await tester.pumpAndSettle();

        // Tap "Log alcohol" on the active-session view.
        await tester.tap(find.text('Log alcohol'));
        await tester.pumpAndSettle();

        // Preset-pick phase (PartyLogDrinkSheet / _AlcoholicPickPhase).
        expect(find.text('Test Beer'), findsOneWidget);
        await tester.tap(find.text('Test Beer'));
        await tester.pumpAndSettle();

        // Confirm phase — volume/ABV pre-filled from the preset.
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        expect(
          repo.logAlcoholicDrinkCalls,
          contains((sessionId: session.id, presetId: _beerPreset.id)),
        );

        // Meal prompt (party_screen.dart _showMealPrompt).
        expect(find.text('Did you eat recently?'), findsOneWidget);
        await tester.tap(find.text('Medium'));
        await tester.pumpAndSettle();

        expect(repo.addMealCalls, hasLength(1));
        expect(repo.addMealCalls.single.sessionId, session.id);
        expect(repo.addMealCalls.single.size, MealSize.medium);
      },
    );

    testWidgets('Skip on the meal prompt calls addMeal zero times', (
      tester,
    ) async {
      final repo = _FakePartySessionRepo();
      final session = _makeSession(startedAt: _workedConsumedAt);
      final profile = _makeProfile(birthDate: _workedBirthDate);

      await tester.pumpWidget(
        _buildScreen(
          session: session,
          profile: profile,
          partyRepo: repo,
          now: _workedConsumedAt,
          alcoholicPresets: const [_beerPreset],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log alcohol'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Beer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Did you eat recently?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await tester.pumpAndSettle();

      expect(
        repo.addMealCalls,
        isEmpty,
        reason: 'Skip must not log a meal (party-session.md §Meals: '
            '"Skipping means we don\'t know — no food modifier")',
      );
    });

    testWidgets(
        'the prompt reappears on a second drink logged into the same '
        'session — confirms "each" log, not a one-shot', (tester) async {
      final repo = _FakePartySessionRepo();
      final session = _makeSession(startedAt: _workedConsumedAt);
      final profile = _makeProfile(birthDate: _workedBirthDate);

      await tester.pumpWidget(
        _buildScreen(
          session: session,
          profile: profile,
          partyRepo: repo,
          now: _workedConsumedAt,
          alcoholicPresets: const [_beerPreset],
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Log alcohol'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test Beer'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        expect(find.text('Did you eat recently?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Skip'));
        await tester.pumpAndSettle();
      }

      expect(repo.logAlcoholicDrinkCalls, hasLength(2));
    });
  });

  // -------------------------------------------------------------------------
  // 3b. Log alcohol with no active session (party-session.md §Logging
  // alcohol when no session is active) — the "Start a Party Session first?"
  // prompt and its two branches.
  // -------------------------------------------------------------------------

  group(
      'Log alcohol with no active session (party-session.md §Logging alcohol '
      'when no session is active)', () {
    testWidgets(
      'Accepting "Start party session" starts a session, logs the drink '
      'into it, then shows the meal prompt',
      (tester) async {
        final repo = _FakePartySessionRepo()..nextSessionId = 'started-2';
        final profile = _makeProfile(birthDate: _workedBirthDate);

        await tester.pumpWidget(
          _buildScreen(
            session: null,
            profile: profile,
            partyRepo: repo,
            alcoholicPresets: const [_beerPreset],
          ),
        );
        await tester.pumpAndSettle();

        // The no-session view's own "Log alcohol" button
        // (flutter/lib/src/screens/party_screen.dart _NoSessionView).
        await tester.tap(find.text('Log alcohol'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test Beer'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        // "Start a Party Session first?" prompt (_showStartSessionPrompt).
        // Scoped to the AlertDialog: the no-session view behind it also
        // has its own "Start party session" FilledButton in the tree.
        expect(find.text('Start a Party Session first?'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Start party session'),
          ),
        );
        await tester.pumpAndSettle();

        // The pricing prompt (party-session.md §Starting a session —
        // pricing prompt) fires right after the session is created; skip it
        // to fall through to the regular-prices default for this flow.
        expect(find.text('Set up party prices?'), findsOneWidget);
        await tester.tap(find.text('Skip — use regular prices'));
        await tester.pumpAndSettle();

        expect(repo.startSessionCalls, hasLength(1));
        expect(
          repo.logAlcoholicDrinkCalls,
          contains((sessionId: 'started-2', presetId: _beerPreset.id)),
        );

        // The per-drink meal prompt fires after the drink is logged into
        // the newly-started session.
        expect(find.text('Did you eat recently?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Skip'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Declining ("Don\'t start a session") logs the drink as an orphan '
      'via DrinksRepository.logDrink, starts no session, shows no meal '
      'prompt',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final drinksRepo = _FakeDrinksRepo();
        final profile = _makeProfile(birthDate: _workedBirthDate);

        await tester.pumpWidget(
          _buildScreen(
            session: null,
            profile: profile,
            partyRepo: repo,
            drinksRepo: drinksRepo,
            alcoholicPresets: const [_beerPreset],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Log alcohol'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test Beer'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        expect(find.text('Start a Party Session first?'), findsOneWidget);
        await tester.tap(find.text("Don't start a session"));
        await tester.pumpAndSettle();

        expect(
          drinksRepo.logDrinkCalls,
          contains((presetId: _beerPreset.id, abvPercent: 5.0)),
        );
        expect(repo.startSessionCalls, isEmpty);
        expect(repo.logAlcoholicDrinkCalls, isEmpty);
        expect(find.text('Did you eat recently?'), findsNothing);
        expect(find.text('Drink logged'), findsOneWidget);
      },
    );

    testWidgets(
      'Accepting "Start party session" while under 18 falls back to logging '
      'the drink as an orphan instead of discarding it',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final drinksRepo = _FakeDrinksRepo();
        final now = DateTime.now();
        // 10 years ago — comfortably under 18.
        final birthDate = _isoDate(DateTime(now.year - 10, now.month, now.day));
        final profile = _makeProfile(birthDate: birthDate);

        await tester.pumpWidget(
          _buildScreen(
            session: null,
            profile: profile,
            partyRepo: repo,
            drinksRepo: drinksRepo,
            alcoholicPresets: const [_beerPreset],
          ),
        );
        await tester.pumpAndSettle();

        // The no-session view's own "Log alcohol" button — the under-18
        // gate only hides "Start party session", not this button (see the
        // "Under-18 gate" group below).
        await tester.tap(find.text('Log alcohol'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test Beer'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        expect(find.text('Start a Party Session first?'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Start party session'),
          ),
        );
        await tester.pumpAndSettle();

        // _startPartySessionFlow's under-18 dialog (no actions, dismissed by
        // tapping the barrier) — party_screen.dart's `_isUnder18` gate.
        expect(
          find.text('Party Mode requires you to be 18 or older'),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(1, 1));
        await tester.pumpAndSettle();

        // The drink the user already picked and confirmed must not be
        // silently discarded: it's logged as an orphan, same as the
        // "Don't start a session" branch.
        expect(
          drinksRepo.logDrinkCalls,
          contains((presetId: _beerPreset.id, abvPercent: 5.0)),
        );
        expect(repo.startSessionCalls, isEmpty);
        expect(repo.logAlcoholicDrinkCalls, isEmpty);
        expect(find.text('Did you eat recently?'), findsNothing);
        expect(find.text('Drink logged'), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 4. Under-18 gate
  // -------------------------------------------------------------------------

  group(
    'Under-18 gate (party-session.md §Starting a session / no-session view)',
    () {
      testWidgets(
        'under-18 birthdate shows the under-18 gate, not the Start button',
        (tester) async {
          final repo = _FakePartySessionRepo();
          final now = DateTime.now();
          // 10 years ago — comfortably under 18.
          final birthDate = _isoDate(
            DateTime(now.year - 10, now.month, now.day),
          );
          final profile = _makeProfile(birthDate: birthDate);

          await tester.pumpWidget(
            _buildScreen(session: null, profile: profile, partyRepo: repo),
          );
          await tester.pumpAndSettle();

          // Visible text (not the SemanticsLabels.under18Gate string, which
          // is a different, spoken-only label) — source: party_screen.dart
          // _Under18Gate.build.
          expect(
            find.text('Party Mode requires you to be 18 or older.'),
            findsOneWidget,
          );
          expect(find.text('Start party session'), findsNothing);
          // party-session.md §Logging alcohol when no session is active: the
          // age gate only sits on the "Start party session" branch — orphan
          // logging has no age check, so "Log alcohol" must stay visible.
          expect(find.text('Log alcohol'), findsOneWidget);
        },
      );

      testWidgets(
        '18+ birthdate shows the Start button, not the under-18 gate',
        (tester) async {
          final repo = _FakePartySessionRepo();
          final now = DateTime.now();
          // 30 years ago — comfortably 18+.
          final birthDate = _isoDate(
            DateTime(now.year - 30, now.month, now.day),
          );
          final profile = _makeProfile(birthDate: birthDate);

          await tester.pumpWidget(
            _buildScreen(session: null, profile: profile, partyRepo: repo),
          );
          await tester.pumpAndSettle();

          expect(find.text('Start party session'), findsOneWidget);
          expect(
            find.text('Party Mode requires you to be 18 or older.'),
            findsNothing,
          );
        },
      );

      testWidgets(
          'no birthdate shows the Start button, not the under-18 gate '
          '(the gate only applies once a birthdate resolves to under-18)', (
        tester,
      ) async {
        final repo = _FakePartySessionRepo();
        final profile = _makeProfile(); // birthDate is null

        await tester.pumpWidget(
          _buildScreen(session: null, profile: profile, partyRepo: repo),
        );
        await tester.pumpAndSettle();

        expect(find.text('Start party session'), findsOneWidget);
        expect(
          find.text('Party Mode requires you to be 18 or older.'),
          findsNothing,
        );
      });
    },
  );
}
