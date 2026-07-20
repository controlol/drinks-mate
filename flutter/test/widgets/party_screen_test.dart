// Widget tests for S7/issue #22 — PartyScreen.
//
// Coverage (mapped to the issue's acceptance criteria):
//  1. BAC card with known inputs — party-session.md §Worked example (75 kg,
//     180 cm, 30-year-old male; two 250 ml 5% ABV beers, same total alcohol
//     dose as one 500 ml 5% ABV entry): initial value, elimination after 2 h,
//     and the Widmark (null-height) fallback path.
//  2. Approaching-cap threshold — party-session.md §BAC goal (cap) / Parity
//     Rulebook `isApproachingCap`: banner shows at >=80% of cap, hidden below.
//  3. Meal prompt — party-session.md §Meals: a single skippable
//     Small/Medium/Large/Skip prompt fires once, at session start (never
//     per-drink, issue #98); picking a size calls
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

import 'dart:async';

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
import 'package:drinks_mate/src/models/session_day_summary.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/models/user_profile.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/party_session_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/party_screen.dart';
import 'package:drinks_mate/src/services/app_info_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Fake repositories — record calls without touching a real DB (beyond the
// throwaway in-memory instance each superclass constructor requires).
// Mirrors _FakeRepo in today_drinks_screen_test.dart / _FakePreferencesRepo
// in settings_screen_test.dart.
// ---------------------------------------------------------------------------

class _FakePartySessionRepo extends PartySessionRepository {
  _FakePartySessionRepo() : super(AppDatabase(NativeDatabase.memory()));

  final List<({String sessionId, MealSize size})> addMealCalls = [];
  final List<
      ({
        String sessionId,
        String presetId,
        String? name,
        int? priceMinor,
        String? currency,
      })> logAlcoholicDrinkCalls = [];
  final List<DateTime?> startSessionCalls = [];
  final List<String> deleteSessionCalls = [];
  final List<({String sessionId, String? name})> updateSessionNameCalls = [];

  /// Deterministic id so tests can assert on it without reading it back off
  /// a returned value threaded through several awaits.
  String nextSessionId = 'new-session-1';

  /// Sentinel session-wide resolved price — deliberately distinct from any
  /// price a test enters into [AlcoholicDrinkSelection.priceMinor], so
  /// item-6 tests can tell "the entered price was used" apart from "this
  /// sentinel leaked through" (i.e. that a one-off entered price correctly
  /// bypasses [resolvePrice] — party_screen.dart `_handleLogAlcohol` doc
  /// comment).
  static const sentinelResolvedPrice = ResolvedDrinkPrice(
    priceMinor: 999999,
    currency: 'SEK',
  );

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
    String? name,
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
      name: normalizePartySessionName(name),
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
  Future<void> updateSessionName(
    String sessionId,
    String? name, {
    DateTime? now,
  }) async {
    updateSessionNameCalls.add((sessionId: sessionId, name: name));
    // Only refreshes the tracked in-memory session (used by getSessionById)
    // when it's the one being edited — tests that build a PartySession
    // directly and pass it to _buildScreen (rather than obtaining it via
    // startSession) never populate _lastSession, and updateSessionName must
    // still record the call for those without throwing.
    final session = _lastSession;
    if (session == null || session.id != sessionId) {
      return;
    }
    _lastSession = PartySession(
      id: session.id,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      endReason: session.endReason,
      useSessionPrices: session.useSessionPrices,
      tokenName: session.tokenName,
      tokenValueMinor: session.tokenValueMinor,
      tokenValueCurrency: session.tokenValueCurrency,
      name: normalizePartySessionName(name),
      createdAt: session.createdAt,
      updatedAt: now ?? DateTime.now(),
      deletedAt: session.deletedAt,
    );
  }

  @override
  Future<ResolvedDrinkPrice> resolvePrice({
    required PartySession session,
    required DrinkPreset preset,
  }) async =>
      sentinelResolvedPrice;

  @override
  Future<DrinkEntry> logAlcoholicDrink({
    required DrinkPreset preset,
    required String sessionId,
    String? id,
    String? name,
    int? volumeMl,
    double? abvPercent,
    DateTime? consumedAt,
    int? priceMinor,
    String? currency,
    int? priceTokens,
    int? tokenValueMinor,
    String? tokenValueCurrency,
    bool isManualPriceOverride = false,
    DateTime? now,
  }) async {
    logAlcoholicDrinkCalls.add((
      sessionId: sessionId,
      presetId: preset.id,
      name: name,
      priceMinor: priceMinor,
      currency: currency,
    ));
    final at = now ?? DateTime.now();
    return DrinkEntry(
      id: id ?? 'fake-logged-entry',
      name: name ?? preset.name,
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
  Future<void> deleteSession(String id, {DateTime? now}) async {
    deleteSessionCalls.add(id);
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

  final List<
      ({
        String presetId,
        double? abvPercent,
        String? name,
        Optional<int?> priceMinor,
        Optional<String?> currency,
      })> logDrinkCalls = [];

  @override
  Future<String> logDrink({
    required DrinkPreset preset,
    String? id,
    String? name,
    int? volumeMl,
    double? abvPercent,
    Optional<int?> priceMinor = const Optional.absent(),
    Optional<String?> currency = const Optional.absent(),
    DateTime? consumedAt,
  }) async {
    logDrinkCalls.add((
      presetId: preset.id,
      abvPercent: abvPercent,
      name: name,
      priceMinor: priceMinor,
      currency: currency,
    ));
    return id ?? 'fake-entry-id';
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

PartySession _makeSession({
  required DateTime startedAt,
  String id = 's1',
  String? name,
}) {
  return PartySession(
    id: id,
    name: name,
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

/// Mirrors party_screen.dart `_PastSessionRow`'s date-range title formatting
/// exactly, so past-sessions-list tests can assert on the title text without
/// hardcoding a timezone-dependent string.
String _expectedPastSessionTitle(PartySession session) {
  final start = session.startedAt.toLocal();
  final end = (session.endedAt ?? session.startedAt).toLocal();
  final sameDay = start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  return sameDay
      ? DateFormat('MMM d').format(start)
      : '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(end)}';
}

/// Builds a testable PartyScreen with every provider PartyScreen reads
/// overridden — no real Drift stream is ever started (avoids the
/// pending-timer teardown issue noted in widget_test.dart).
Widget _buildScreen({
  PartySession? session,
  List<DrinkEntry> entries = const [],
  // Lets a test push multiple entries snapshots into the *same* running
  // widget tree (rather than calling `tester.pumpWidget` a second time,
  // which reconstructs a fresh `ProviderScope`/override set and isn't
  // guaranteed to flow through to an already-built family-provider
  // subscription) — mirrors goal_celebration_test.dart's
  // `StreamController`-based `totalMlStream` pattern. Defaults to a
  // single-value stream of `entries`, matching every pre-existing caller.
  Stream<List<DrinkEntry>>? entriesStream,
  List<Meal> meals = const [],
  UserProfile? profile,
  UserPreferences? prefs,
  required _FakePartySessionRepo partyRepo,
  _FakeDrinksRepo? drinksRepo,
  DateTime? now,
  List<DrinkPreset> alcoholicPresets = const [],
  List<SessionDaySummary> endedSessionSummaries = const [],
  // Drives `MediaQuery.alwaysUse24HourFormat`, which is what
  // `TimeOfDay.format(context)` actually keys off (not `Locale`) — see the
  // "Time-of-day display format" Parity Rulebook row. `null` (the default)
  // leaves the ambient MediaQuery untouched, matching every pre-existing
  // caller of this helper. `MaterialApp.builder` wraps above the Navigator,
  // so the override also reaches modal routes such as PartyLogDrinkSheet
  // (mirrors log_drink_sheet_test.dart's `_pumpSheet` helper).
  bool? alwaysUse24HourFormat,
}) {
  return ProviderScope(
    overrides: [
      partySessionRepositoryProvider.overrideWithValue(partyRepo),
      if (drinksRepo != null)
        drinksRepositoryProvider.overrideWithValue(drinksRepo),
      activePartySessionProvider.overrideWith((_) => Stream.value(session)),
      partySessionEntriesProvider.overrideWith(
        (ref, sessionId) => entriesStream ?? Stream.value(entries),
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
      // S7 past-sessions list (issue #86) — overridden with a single-value
      // stream/future so the underlying Drift `.watch()` query on
      // _FakePartySessionRepo's throwaway in-memory database never opens
      // (same "avoid touching real DB streams" rationale as the other
      // overrides above).
      partyEndedSessionsProvider.overrideWith(
        (_) => Stream.value(const <PartySession>[]),
      ),
      partyEndedSessionSummariesProvider.overrideWith(
        (_) async => endedSessionSummaries,
      ),
    ],
    child: MaterialApp(
      builder: alwaysUse24HourFormat == null
          ? null
          : (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(alwaysUse24HourFormat: alwaysUse24HourFormat),
                child: child!,
              ),
      home: const PartyScreen(),
    ),
  );
}

/// Locates the confirm-phase `_TimeButton`'s rendered label text
/// (party_log_drink_sheet.dart's `_TimeButton` is private, mirroring
/// log_drink_sheet_test.dart's `_timeButtonLabel`). `Icons.schedule` is
/// unique among the confirm phase's buttons — unlike LogDrinkSheet, this
/// phase has no "Advanced" button to disambiguate against.
///
/// The confirm-phase form (Name/Volume/ABV/Price/Time) is taller than the
/// sheet's visible extent, so the Time button sits beyond what the
/// `ListView`'s `SliverList` builds by default — it doesn't exist as an
/// Element until scrolled into range, so we scroll the list (keyed
/// `party_log_drink_confirm_list`) before searching for it.
Future<String> _timeButtonLabel(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byIcon(Icons.schedule),
    200.0,
    // .first: the TextFields inside this list each have their own internal
    // Scrollable (for text-cursor scrolling) — the list's own Scrollable is
    // the outermost/first match.
    scrollable: find
        .descendant(
          of: find.byKey(const Key('party_log_drink_confirm_list')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  final button = find.ancestor(
    of: find.byIcon(Icons.schedule),
    matching: find.byType(OutlinedButton),
  );
  expect(button, findsOneWidget);
  final text = tester.widget<Text>(
    find.descendant(of: button, matching: find.byType(Text)),
  );
  return text.data!;
}

/// Scrolls the active-session `ListView` until the "Log alcohol" button is
/// on-screen. Needed since issue #103 made `_BacLineChartCard` render
/// unconditionally — including its ~200px-tall empty-state flat line before
/// any drink is logged (party-session.md §BAC line chart -> Empty state) —
/// which now pushes this button below the fold at the default 800x600 test
/// surface for a freshly-started, drink-free active session. Mirrors
/// `_timeButtonLabel`'s `scrollUntilVisible` pattern above.
Future<void> _scrollToLogAlcohol(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Log alcohol'),
    300.0,
    scrollable: find.byType(Scrollable).first,
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

    testWidgets(
        'shows the session name above the BAC value when set '
        '(party-session.md §Party tab during a session)', (tester) async {
      final repo = _FakePartySessionRepo();
      final session = _makeSession(
        startedAt: _workedConsumedAt,
        name: "Sarah's birthday",
      );
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
          now: _workedConsumedAt,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Sarah's birthday"), findsOneWidget);
      expect(find.text('Add session name'), findsNothing);
    });

    testWidgets(
      'shows the "Add session name" placeholder when unset, and tapping '
      'the row + saving a name in the dialog calls updateSessionName '
      '(party_screen.dart _BacCard -> showEditSessionNameDialog)',
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
            partyRepo: repo,
            now: _workedConsumedAt,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add session name'), findsOneWidget);

        // find.bySemanticsLabel requires an active SemanticsHandle
        // (tester.ensureSemantics()), which most widget tests in this repo
        // don't enable (see the Approaching-cap banner test's own note
        // above) — tap the visible placeholder text instead, which sits
        // inside the same InkWell that carries the
        // SemanticsLabels.editSessionNameButton semantics.
        await tester.tap(find.text('Add session name'));
        await tester.pumpAndSettle();

        expect(find.text('Session name'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Office party');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        expect(
          repo.updateSessionNameCalls,
          contains((sessionId: session.id, name: 'Office party')),
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // 1.5 BAC line chart presence/rendering + summary-card vs. chart tap
  // targets (issue #103; party-session.md §BAC line chart, incl. "Empty
  // state" and "Tap to inspect a value").
  // -------------------------------------------------------------------------

  group('BAC line chart card (party-session.md §BAC line chart)', () {
    testWidgets(
      'before any alcoholic drink is logged, the chart still renders: a '
      'flat 0.00 g/L line across the 3h empty-state window, no dashed '
      'projection segment (party-session.md §BAC line chart -> Empty '
      'state)',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final session = _makeSession(startedAt: _workedConsumedAt);
        final profile = _makeProfile(birthDate: _workedBirthDate);

        await tester.pumpWidget(
          _buildScreen(
            session: session,
            entries: const [],
            profile: profile,
            partyRepo: repo,
            now: _workedConsumedAt,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LineChart), findsOneWidget);
        final chart = tester.widget<LineChart>(find.byType(LineChart));

        // No dashed projection bar — there is nothing to project yet.
        expect(chart.data.lineBarsData, hasLength(1));
        final spots = chart.data.lineBarsData.single.spots;
        // 3h empty-state window == 180 minutes (Parity Rulebook "BAC
        // chart empty-state window"), flat 0.00 g/L at both ends.
        expect(spots, hasLength(2));
        expect(spots.first.x, 0);
        expect(spots.first.y, 0);
        expect(spots.last.x, 180);
        expect(spots.last.y, 0);
      },
    );

    testWidgets(
      'the moment the first drink is logged, the chart switches to the '
      'normal solid+dashed rendering (non-zero actual value, a projected '
      'segment appears)',
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
            partyRepo: repo,
            now: _workedConsumedAt, // elapsed = 0
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LineChart), findsOneWidget);
        final chart = tester.widget<LineChart>(find.byType(LineChart));

        // Solid ("actual") + dashed ("projected") bars now both present —
        // unlike the empty state's single flat bar above.
        expect(chart.data.lineBarsData, hasLength(2));
        final actualSpots = chart.data.lineBarsData.first.spots;
        expect(actualSpots, isNotEmpty);
        // At elapsed = 0 the only actual point is the worked example's
        // initial BAC (party-session.md §Worked example: 0.362 g/L,
        // cross-checked via core's own bacInitialWatson above).
        expect(actualSpots.first.y, closeTo(_workedBacInitial, 0.001));
        expect(actualSpots.first.y, greaterThan(0));
      },
    );

    testWidgets(
      'tapping the BAC summary card (outside the session-name row) opens '
      'PartySessionLogScreen — same destination as the drinks-count line '
      '(party-session.md §Party tab during a session: "the entire card is '
      'tappable")',
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
            partyRepo: repo,
            now: _workedConsumedAt,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Party Session Log'), findsNothing);
        // "Elapsed:" sits inside the summary card's InkWell, well clear of
        // the session-name row's own nested InkWell above it.
        await tester.tap(find.textContaining('Elapsed:'));
        await tester.pumpAndSettle();

        expect(find.text('Party Session Log'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the chart itself never opens PartySessionLogScreen — the '
      'tap-to-inspect affordance is chart-local (party-session.md §BAC '
      'line chart -> Tap to inspect a value: "never navigates away from '
      'the Party tab")',
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
            partyRepo: repo,
            now: _workedConsumedAt,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(LineChart));
        await tester.pumpAndSettle();

        // Still on PartyScreen — a real navigation would have removed
        // this button (part of PartyScreen's own active-session body) and
        // shown PartySessionLogScreen's AppBar title instead. Scroll first:
        // the always-rendered chart card (issue #103) pushes this button
        // below the fold at the default test surface size.
        await _scrollToLogAlcohol(tester);
        expect(find.text('Log alcohol'), findsOneWidget);
        expect(find.text('Party Session Log'), findsNothing);
      },
    );

    testWidgets(
      'a tap-to-inspect marker set before the first drink is logged is '
      'cleared once buildBacChartSeries rescales the axis for the newly '
      'logged entry (party-session.md §BAC line chart -> Tap to inspect a '
      "value; regression for _BacLineChartCardState's didUpdateWidget "
      "reset — a stale marker from the empty state's flat 0.00 g/L line "
      'must not survive the empty-state -> real-series transition)',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final session = _makeSession(startedAt: _workedConsumedAt);
        final profile = _makeProfile(birthDate: _workedBirthDate);
        // Pushed into the *same* running widget tree (see `entriesStream`'s
        // doc comment on `_buildScreen`) so the update reliably reaches the
        // already-built `partySessionEntriesProvider` subscription and
        // exercises `_BacLineChartCard.didUpdateWidget`, rather than
        // reconstructing a fresh ProviderScope via a second `pumpWidget`.
        final entriesController = StreamController<List<DrinkEntry>>();
        addTearDown(entriesController.close);

        // Empty state: no alcoholic entries yet — flat 0.00 g/L line
        // across the 3h window (same fixture as the empty-state rendering
        // test above).
        await tester.pumpWidget(
          _buildScreen(
            session: session,
            entriesStream: entriesController.stream,
            profile: profile,
            partyRepo: repo,
            now: _workedConsumedAt,
          ),
        );
        entriesController.add(const []);
        await tester.pumpAndSettle();

        // The empty-state series has only two sampled spots — (x=0, y=0)
        // and (x=180, y=0) (the "before any alcoholic drink" test above) —
        // and fl_chart's default `LineTouchData.distanceCalculator` (the
        // package's own `_xDistance`) resolves a touch to the nearest spot
        // by **X-pixel distance only** (`touchSpotThreshold: 10` default),
        // ignoring Y entirely. So the tap must land within ~10px of the
        // x=0 spot's pixel column — near the chart's left edge, just past
        // its reserved left-axis-label gutter (`leftTitles`
        // `reservedSize: 32` above) — not at the visual centre of the flat
        // line. Y is unconstrained as long as it's inside the chart's
        // plotted region. Coordinates below were verified empirically
        // against this exact fixture (see this test's own commit).
        final chartRect = tester.getRect(find.byType(LineChart));
        await tester.tapAt(
          Offset(chartRect.left + 36, chartRect.bottom - 45),
        );
        await tester.pumpAndSettle();

        LineChart chart() => tester.widget<LineChart>(find.byType(LineChart));

        // The tapped-marker VerticalLine is the only one that sets a
        // label (the "now" marker and cap-line don't) — see
        // party_screen.dart _BacLineChartCardState.build.
        expect(
          chart().data.extraLinesData.verticalLines.any((l) => l.label.show),
          isTrue,
          reason: 'Tap should have set a tap-to-inspect marker before '
              'proceeding — if this fails, the tap itself did not '
              'register rather than the didUpdateWidget fix being '
              'exercised.',
        );

        // Now the first drink is logged — same session/profile/now, one
        // alcoholic entry. This flows a changed `alcoholicEntries` list
        // into `_BacLineChartCard`, triggering its didUpdateWidget and
        // rescaling the axis (party-session.md §BAC line chart
        // "Re-rendering": "whenever a drink is added").
        entriesController.add([
          _alcoholicEntry(
            volumeMl: 500,
            abvPercent: 5.0,
            consumedAt: _workedConsumedAt,
          ),
        ]);
        await tester.pumpAndSettle();

        expect(
          chart().data.extraLinesData.verticalLines.any((l) => l.label.show),
          isFalse,
          reason: 'The stale marker from the empty-state series must be '
              'cleared once alcoholicEntries changes and the axis is '
              'rescaled — a marker left over from the flat 0.00 g/L line '
              "wouldn't correspond to anything on the new series.",
        );
      },
    );

    testWidgets(
      'a tap-to-inspect marker set on the real (non-empty) series is also '
      'cleared when a further entry is logged into the same session '
      '(party-session.md §BAC line chart -> Tap to inspect a value / '
      'Re-rendering: any later edit that reflows the axis, not just the '
      'empty-state transition)',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final session = _makeSession(startedAt: _workedConsumedAt);
        final profile = _makeProfile(birthDate: _workedBirthDate);
        final firstEntry = [
          _alcoholicEntry(
            volumeMl: 500,
            abvPercent: 5.0,
            consumedAt: _workedConsumedAt,
          ),
        ];
        final entriesController = StreamController<List<DrinkEntry>>();
        addTearDown(entriesController.close);

        await tester.pumpWidget(
          _buildScreen(
            session: session,
            entriesStream: entriesController.stream,
            profile: profile,
            partyRepo: repo,
            now: _workedConsumedAt,
          ),
        );
        entriesController.add(firstEntry);
        await tester.pumpAndSettle();

        final chartRect = tester.getRect(find.byType(LineChart));
        await tester.tapAt(chartRect.center);
        await tester.pumpAndSettle();

        LineChart chart() => tester.widget<LineChart>(find.byType(LineChart));
        expect(
          chart().data.extraLinesData.verticalLines.any((l) => l.label.show),
          isTrue,
          reason: 'Tap should have set a tap-to-inspect marker before '
              'proceeding.',
        );

        // A second drink is logged into the same session — the entries
        // list changes again, and the axis (end = rounded-up
        // return-to-zero time) reflows accordingly.
        entriesController.add([
          ...firstEntry,
          _alcoholicEntry(
            id: 'entry-2',
            volumeMl: 500,
            abvPercent: 5.0,
            consumedAt: _workedConsumedAt.add(const Duration(minutes: 30)),
          ),
        ]);
        await tester.pumpAndSettle();

        expect(
          chart().data.extraLinesData.verticalLines.any((l) => l.label.show),
          isFalse,
          reason: 'The marker must be cleared whenever alcoholicEntries '
              'changes, not only on the empty-state -> first-drink '
              'transition.',
        );
      },
    );

    testWidgets(
      'tapping the drinks-count line still opens PartySessionLogScreen '
      '(party-session.md §Party tab during a session)',
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
            partyRepo: repo,
            now: _workedConsumedAt,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Party Session Log'), findsNothing);
        await tester.tap(find.textContaining('alcoholic drink'));
        await tester.pumpAndSettle();

        expect(find.text('Party Session Log'), findsOneWidget);
      },
    );
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
  // 3. Meal prompt — party-session.md §Meals: "A single, skippable prompt"
  // that fires once, at session start, and "There is never a per-drink food
  // prompt." Issue #98 fixed a regression where the prompt was (incorrectly)
  // re-shown after every alcoholic drink logged into an already-active
  // session; party_session_flows.dart's `startPartySessionFlow` now runs the
  // prompt exactly once (between the birthday/under-18 gate and the pricing
  // prompt), and `logAlcoholicDrinkIntoSession` (used for logging additional
  // drinks into an active session) never shows it.
  // -------------------------------------------------------------------------

  group(
      'Meal prompt (party-session.md §Meals: single prompt at session start '
      'only, issue #98)', () {
    testWidgets(
      'Starting a session shows the meal prompt exactly once, after the '
      'birthday/under-18 gate and before the pricing prompt; Medium calls '
      'addMeal(sessionId, MealSize.medium)',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final profile = _makeProfile(birthDate: _workedBirthDate);

        await tester.pumpWidget(
          _buildScreen(session: null, profile: profile, partyRepo: repo),
        );
        await tester.pumpAndSettle();

        // The no-session view's own "Start party session" button
        // (party_screen.dart _NoSessionView) — the profile already has a
        // birthdate and is 18+, so no birthdate dialog/gate interrupts.
        await tester.tap(find.text('Start party session'));
        await tester.pumpAndSettle();

        // Meal prompt (party_session_flows.dart showMealPrompt) fires first.
        expect(find.text('Did you eat recently?'), findsOneWidget);
        await tester.tap(find.text('Medium'));
        await tester.pumpAndSettle();

        expect(repo.addMealCalls, hasLength(1));
        expect(repo.addMealCalls.single.sessionId, repo.nextSessionId);
        expect(repo.addMealCalls.single.size, MealSize.medium);

        // Name prompt (party_session_flows.dart showNamePrompt) fires
        // between the meal prompt and the pricing prompt (party-session.md
        // §Starting a session) — this test doesn't care about naming, so
        // Skip is the no-op choice.
        expect(find.text('Name this session?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Skip'));
        await tester.pumpAndSettle();

        // Pricing prompt (party-session.md §Starting a session) follows the
        // meal prompt, not before it.
        expect(find.text('Set up party prices?'), findsOneWidget);
        await tester.tap(find.text('Skip — use regular prices'));
        await tester.pumpAndSettle();

        expect(repo.startSessionCalls, hasLength(1));
      },
    );

    testWidgets(
      'Skip on the session-start meal prompt calls addMeal zero times and '
      'still continues to the pricing prompt',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final profile = _makeProfile(birthDate: _workedBirthDate);

        await tester.pumpWidget(
          _buildScreen(session: null, profile: profile, partyRepo: repo),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start party session'));
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

        // Name prompt fires next, between the meal prompt and the pricing
        // prompt — this test doesn't care about naming, so Skip is the
        // no-op choice.
        expect(find.text('Name this session?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Skip'));
        await tester.pumpAndSettle();

        expect(find.text('Set up party prices?'), findsOneWidget);
        await tester.tap(find.text('Skip — use regular prices'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Logging drinks into an already-active session never shows the meal '
      'prompt and never calls addMeal (issue #98 — "There is never a '
      'per-drink food prompt")',
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

        // First drink.
        await _scrollToLogAlcohol(tester);
        await tester.tap(find.text('Log alcohol'));
        await tester.pumpAndSettle();
        expect(find.text('Test Beer'), findsOneWidget);
        await tester.tap(find.text('Test Beer'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        expect(find.text('Did you eat recently?'), findsNothing);
        expect(repo.addMealCalls, isEmpty);
        expect(repo.logAlcoholicDrinkCalls, hasLength(1));

        // Second drink into the same active session — still no prompt.
        await _scrollToLogAlcohol(tester);
        await tester.tap(find.text('Log alcohol'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test Beer'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        expect(find.text('Did you eat recently?'), findsNothing);
        expect(repo.addMealCalls, isEmpty);
        expect(repo.logAlcoholicDrinkCalls, hasLength(2));
      },
    );
  });

  // -------------------------------------------------------------------------
  // 3c. Name prompt — data-model.md §PartySession → name / party-session.md
  // §Starting a session: "an optional, skippable name field", sitting
  // between the meal prompt and the pricing prompt (issue #102).
  // -------------------------------------------------------------------------

  group(
      'Name prompt (data-model.md §PartySession → name, party-session.md '
      '§Starting a session, issue #102)', () {
    testWidgets(
      'entering a name and tapping Save calls updateSessionName with that '
      'name',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final profile = _makeProfile(birthDate: _workedBirthDate);

        await tester.pumpWidget(
          _buildScreen(session: null, profile: profile, partyRepo: repo),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start party session'));
        await tester.pumpAndSettle();

        expect(find.text('Did you eat recently?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Skip'));
        await tester.pumpAndSettle();

        expect(find.text('Name this session?'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Session name'),
          "Sarah's birthday",
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        expect(
          repo.updateSessionNameCalls,
          contains((sessionId: repo.nextSessionId, name: "Sarah's birthday")),
        );

        // Fall through the pricing prompt to complete the flow.
        expect(find.text('Set up party prices?'), findsOneWidget);
        await tester.tap(find.text('Skip — use regular prices'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'tapping Skip on the name prompt never calls updateSessionName',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final profile = _makeProfile(birthDate: _workedBirthDate);

        await tester.pumpWidget(
          _buildScreen(session: null, profile: profile, partyRepo: repo),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start party session'));
        await tester.pumpAndSettle();

        expect(find.text('Did you eat recently?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Skip'));
        await tester.pumpAndSettle();

        expect(find.text('Name this session?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Skip'));
        await tester.pumpAndSettle();

        expect(repo.updateSessionNameCalls, isEmpty);

        expect(find.text('Set up party prices?'), findsOneWidget);
        await tester.tap(find.text('Skip — use regular prices'));
        await tester.pumpAndSettle();
      },
    );
  });

  // -------------------------------------------------------------------------
  // 3a. PartyLogDrinkSheet confirm-phase time button honours the device's
  //     12h/24h preference (Parity Rulebook: "Time-of-day display format",
  //     issue #46) — third call site of the same bug fixed alongside
  //     log_drink_sheet.dart and history_day_screen.dart's edit sheet.
  //
  //     PartyLogDrinkSheet has no edit/existing-entry mode: `_consumedAt`
  //     always starts from `DateTime.now()` when a preset is picked
  //     (party_log_drink_sheet.dart's `_pickPreset`), with no constructor
  //     parameter to override it. So, as with log_drink_sheet_test.dart's
  //     equivalent group, these tests can't pin an exact consumedAt and
  //     assert an exact label (e.g. "9:30 AM") — they assert the *shape* of
  //     the rendered label instead, which is enough to catch a regression to
  //     a hardcoded 'HH:mm' format regardless of what "now" happens to be
  //     when the test runs:
  //       - 12h (alwaysUse24HourFormat=false): "<1-2 digits>:<2 digits>
  //         AM|PM".
  //       - 24h (alwaysUse24HourFormat=true): "<2 digits>:<2 digits>", no
  //         AM/PM suffix.
  // -------------------------------------------------------------------------

  group('PartyLogDrinkSheet time button format (issue #46)', () {
    final twelveHourPattern = RegExp(r'^\d{1,2}:\d{2}\s?(AM|PM)$');
    final twentyFourHourPattern = RegExp(r'^\d{2}:\d{2}$');

    testWidgets('renders 12h AM/PM format when alwaysUse24HourFormat=false', (
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
          alwaysUse24HourFormat: false,
        ),
      );
      await tester.pumpAndSettle();

      await _scrollToLogAlcohol(tester);
      await tester.tap(find.text('Log alcohol'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Beer'));
      await tester.pumpAndSettle();

      final label = await _timeButtonLabel(tester);
      expect(
        twelveHourPattern.hasMatch(label),
        isTrue,
        reason: 'Expected a 12h AM/PM label like "9:30 AM", got "$label"',
      );
    });

    testWidgets(
      'renders 24h format (no AM/PM) when alwaysUse24HourFormat=true',
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
            alwaysUse24HourFormat: true,
          ),
        );
        await tester.pumpAndSettle();

        await _scrollToLogAlcohol(tester);
        await tester.tap(find.text('Log alcohol'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test Beer'));
        await tester.pumpAndSettle();

        final label = await _timeButtonLabel(tester);
        expect(
          twentyFourHourPattern.hasMatch(label),
          isTrue,
          reason: 'Expected a 24h label like "09:30" with no AM/PM, got '
              '"$label"',
        );
        expect(label, isNot(contains('AM')));
        expect(label, isNot(contains('PM')));
      },
    );
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
      'Accepting "Start party session" runs the meal and pricing prompts '
      'as part of starting the session, then logs the drink into it',
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

        // The meal prompt (party-session.md §Meals, issue #98) fires first,
        // as part of starting the session — before the drink itself is
        // logged and before the pricing prompt.
        expect(find.text('Did you eat recently?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Skip'));
        await tester.pumpAndSettle();

        // Name prompt (party_session_flows.dart showNamePrompt) fires next,
        // between the meal prompt and the pricing prompt; this test doesn't
        // care about naming, so Skip is the no-op choice.
        expect(find.text('Name this session?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Skip'));
        await tester.pumpAndSettle();

        // The pricing prompt (party-session.md §Starting a session —
        // pricing prompt) follows the meal prompt; skip it to fall through
        // to the regular-prices default for this flow.
        expect(find.text('Set up party prices?'), findsOneWidget);
        await tester.tap(find.text('Skip — use regular prices'));
        await tester.pumpAndSettle();

        expect(repo.startSessionCalls, hasLength(1));
        expect(
          repo.logAlcoholicDrinkCalls,
          contains((
            sessionId: 'started-2',
            presetId: _beerPreset.id,
            name: 'Test Beer',
            priceMinor: _FakePartySessionRepo.sentinelResolvedPrice.priceMinor,
            currency: _FakePartySessionRepo.sentinelResolvedPrice.currency,
          )),
        );
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
          contains((
            presetId: _beerPreset.id,
            abvPercent: 5.0,
            name: 'Test Beer',
            // Price field left blank -> Optional.absent(), not an explicit
            // clear (party_screen.dart _logOrphanDrink doc comment).
            priceMinor: const Optional<int?>.absent(),
            currency: const Optional<String?>.absent(),
          )),
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

        // startPartySessionFlow's under-18 dialog (no actions, dismissed by
        // tapping the barrier) — party_session_flows.dart's `isUnder18` gate.
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
          contains((
            presetId: _beerPreset.id,
            abvPercent: 5.0,
            name: 'Test Beer',
            priceMinor: const Optional<int?>.absent(),
            currency: const Optional<String?>.absent(),
          )),
        );
        expect(repo.startSessionCalls, isEmpty);
        expect(repo.logAlcoholicDrinkCalls, isEmpty);
        expect(find.text('Did you eat recently?'), findsNothing);
        expect(find.text('Drink logged'), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 3c. Name/price override entered in the Party log-drink sheet (issue #85)
  // -------------------------------------------------------------------------

  group(
      'Name/price override entered in PartyLogDrinkSheet (party-session.md '
      '§Logging an alcoholic drink (during a session))', () {
    testWidgets(
      'active session (useSessionPrices on): an entered name+price is used '
      'verbatim, bypassing PartySessionRepository.resolvePrice() entirely '
      '(party_screen.dart _handleLogAlcohol doc: "takes priority over ... '
      'the session-wide PartySessionPrice table")',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final session = PartySession(
          id: 's1',
          startedAt: _workedConsumedAt,
          useSessionPrices: true,
          createdAt: _workedConsumedAt,
          updatedAt: _workedConsumedAt,
        );
        final profile = _makeProfile(birthDate: _workedBirthDate);

        // PartyLogDrinkSheet's confirm phase (Name/Volume/ABV/Price/Time) is
        // taller than the default 800x600 test surface, and PartyScreen
        // itself sits in the tree behind the modal — widen the surface so
        // every field is on-screen without needing to scroll a specific
        // (fragile-to-target) Scrollable among several.
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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

        await tester.enterText(
          find.byKey(const Key('party_log_drink_name_field')),
          'Party Beer',
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('party_log_drink_price_field')),
          '6.00',
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        expect(repo.logAlcoholicDrinkCalls, hasLength(1));
        final call = repo.logAlcoholicDrinkCalls.single;
        expect(call.name, 'Party Beer');
        // The entered price (600/EUR), NOT the fake's sentinel
        // resolvePrice() value — proves the one-off override bypassed
        // resolvePrice() rather than falling through to it.
        expect(call.priceMinor, 600);
        expect(call.currency, 'EUR');
        expect(
          call.priceMinor,
          isNot(_FakePartySessionRepo.sentinelResolvedPrice.priceMinor),
        );
      },
    );

    testWidgets(
      'active session: leaving the price field blank still resolves via '
      'the normal session-price/regular-price path (regression — must not '
      'break existing pricing tests)',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final session = PartySession(
          id: 's1',
          startedAt: _workedConsumedAt,
          useSessionPrices: true,
          createdAt: _workedConsumedAt,
          updatedAt: _workedConsumedAt,
        );
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

        await _scrollToLogAlcohol(tester);
        await tester.tap(find.text('Log alcohol'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test Beer'));
        await tester.pumpAndSettle();
        // Price field left blank — only the (required) name stays at its
        // pre-filled default.
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        expect(repo.logAlcoholicDrinkCalls, hasLength(1));
        final call = repo.logAlcoholicDrinkCalls.single;
        expect(
          call.priceMinor,
          _FakePartySessionRepo.sentinelResolvedPrice.priceMinor,
        );
        expect(
          call.currency,
          _FakePartySessionRepo.sentinelResolvedPrice.currency,
        );
      },
    );

    testWidgets(
      'orphan path (no active session): an entered name+price is honored on '
      'the logged entry',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final drinksRepo = _FakeDrinksRepo();
        final profile = _makeProfile(birthDate: _workedBirthDate);

        // See the "used verbatim" test above for why the surface is widened.
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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

        await tester.enterText(
          find.byKey(const Key('party_log_drink_name_field')),
          'Orphan Beer',
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('party_log_drink_price_field')),
          '4.50',
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();

        expect(find.text('Start a Party Session first?'), findsOneWidget);
        await tester.tap(find.text("Don't start a session"));
        await tester.pumpAndSettle();

        expect(drinksRepo.logDrinkCalls, hasLength(1));
        final call = drinksRepo.logDrinkCalls.single;
        expect(call.name, 'Orphan Beer');
        expect(call.priceMinor, const Optional.value(450));
        expect(call.currency, const Optional.value('EUR'));
      },
    );

    testWidgets(
        'orphan path: leaving name/price at defaults falls back to the '
        'preset\'s own name and regular price (Optional.absent, not an '
        'explicit clear)', (tester) async {
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

      expect(drinksRepo.logDrinkCalls, hasLength(1));
      final call = drinksRepo.logDrinkCalls.single;
      expect(call.name, 'Test Beer');
      expect(call.priceMinor, const Optional<int?>.absent());
      expect(call.currency, const Optional<String?>.absent());
    });
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

  // -------------------------------------------------------------------------
  // 5. Past-sessions list rendering (user-experience.md §S7 → No active
  // session — subsequent visits: "Each row shows session date/range, peak
  // BAC, number of alcoholic drinks, and how the session ended
  // (manual/auto). Tapping a row opens S9 ... in its read-only,
  // ended-session mode").
  // -------------------------------------------------------------------------

  group('Past-sessions list (partyEndedSessionSummariesProvider)', () {
    testWidgets(
      'renders one row per summary, with drink count and end-reason text',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final profile = _makeProfile(); // birthDate null -> Start button shown

        final manualSession = PartySession(
          id: 'manual-session',
          startedAt: DateTime.utc(2026, 7, 1, 20, 0),
          endedAt: DateTime.utc(2026, 7, 1, 23, 0),
          endReason: PartySessionEndReason.manual,
          useSessionPrices: false,
          createdAt: DateTime.utc(2026, 7, 1, 20, 0),
          updatedAt: DateTime.utc(2026, 7, 1, 23, 0),
        );
        final autoSession = PartySession(
          id: 'auto-session',
          startedAt: DateTime.utc(2026, 7, 5, 20, 0),
          endedAt: DateTime.utc(2026, 7, 6, 8, 0),
          endReason: PartySessionEndReason.autoTimeout,
          useSessionPrices: false,
          createdAt: DateTime.utc(2026, 7, 5, 20, 0),
          updatedAt: DateTime.utc(2026, 7, 6, 8, 0),
        );
        final summaries = [
          SessionDaySummary(
            session: manualSession,
            duration: const Duration(hours: 3),
            totalAlcoholicDrinks: 2,
            mealsLoggedCount: 1,
            peakBacGPerL: 0.36,
          ),
          SessionDaySummary(
            session: autoSession,
            duration: const Duration(hours: 12),
            totalAlcoholicDrinks: 1,
            mealsLoggedCount: 0,
          ),
        ];

        await tester.pumpWidget(
          _buildScreen(
            session: null,
            profile: profile,
            partyRepo: repo,
            endedSessionSummaries: summaries,
          ),
        );
        await tester.pumpAndSettle();

        // Source: party_screen.dart _PastSessionRow.build — title is the
        // date/range, subtitle combines drink count, optional peak BAC, and
        // end label (user-experience.md §S7: "session date/range, peak BAC,
        // number of alcoholic drinks, and how the session ended").
        expect(
          find.text(_expectedPastSessionTitle(manualSession)),
          findsOneWidget,
        );
        expect(
          find.text(_expectedPastSessionTitle(autoSession)),
          findsOneWidget,
        );
        expect(
          find.text('2 alcoholic drinks · peak 0.36 g/L · ended manually'),
          findsOneWidget,
        );
        expect(
          find.text('1 alcoholic drink · ended automatically'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a row for a session WITH a name shows "name · date" on one line, '
      'ahead of the date (user-experience.md §S7); a row with no name just '
      'shows the date',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final profile = _makeProfile();

        final namedSession = PartySession(
          id: 'named-session',
          name: "Sarah's birthday",
          startedAt: DateTime.utc(2026, 7, 1, 20, 0),
          endedAt: DateTime.utc(2026, 7, 1, 23, 0),
          endReason: PartySessionEndReason.manual,
          useSessionPrices: false,
          createdAt: DateTime.utc(2026, 7, 1, 20, 0),
          updatedAt: DateTime.utc(2026, 7, 1, 23, 0),
        );
        final unnamedSession = PartySession(
          id: 'unnamed-session',
          startedAt: DateTime.utc(2026, 7, 5, 20, 0),
          endedAt: DateTime.utc(2026, 7, 5, 23, 0),
          endReason: PartySessionEndReason.manual,
          useSessionPrices: false,
          createdAt: DateTime.utc(2026, 7, 5, 20, 0),
          updatedAt: DateTime.utc(2026, 7, 5, 23, 0),
        );
        final summaries = [
          SessionDaySummary(
            session: namedSession,
            duration: const Duration(hours: 3),
            totalAlcoholicDrinks: 1,
            mealsLoggedCount: 0,
          ),
          SessionDaySummary(
            session: unnamedSession,
            duration: const Duration(hours: 3),
            totalAlcoholicDrinks: 1,
            mealsLoggedCount: 0,
          ),
        ];

        await tester.pumpWidget(
          _buildScreen(
            session: null,
            profile: profile,
            partyRepo: repo,
            endedSessionSummaries: summaries,
          ),
        );
        await tester.pumpAndSettle();

        // Named row: "name · date" (party_screen.dart _PastSessionRow.build).
        expect(
          find.text(
            "Sarah's birthday · ${_expectedPastSessionTitle(namedSession)}",
          ),
          findsOneWidget,
        );
        // Unnamed row: just the date, unchanged.
        expect(
          find.text(_expectedPastSessionTitle(unnamedSession)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping a row navigates to PartySessionLogScreen for that session',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final profile = _makeProfile();

        final session = PartySession(
          id: 'tapped-session',
          startedAt: DateTime.utc(2026, 7, 1, 20, 0),
          endedAt: DateTime.utc(2026, 7, 1, 23, 0),
          endReason: PartySessionEndReason.manual,
          useSessionPrices: false,
          createdAt: DateTime.utc(2026, 7, 1, 20, 0),
          updatedAt: DateTime.utc(2026, 7, 1, 23, 0),
        );
        final summaries = [
          SessionDaySummary(
            session: session,
            duration: const Duration(hours: 3),
            totalAlcoholicDrinks: 1,
            mealsLoggedCount: 0,
            peakBacGPerL: 0.1,
          ),
        ];

        await tester.pumpWidget(
          _buildScreen(
            session: null,
            profile: profile,
            partyRepo: repo,
            endedSessionSummaries: summaries,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Party Session Log'), findsNothing);
        await tester.tap(
          find.text('1 alcoholic drink · peak 0.10 g/L · ended manually'),
        );
        await tester.pumpAndSettle();

        // PartySessionLogScreen's own AppBar title — confirms navigation
        // happened, regardless of whether its body can resolve a summary
        // for this session id from the fake repo (out of scope here; see
        // party_session_log_screen_test.dart for that screen's own
        // coverage).
        expect(find.text('Party Session Log'), findsOneWidget);
      },
    );

    testWidgets(
        'tapping the row\'s delete button then confirming calls '
        'PartySessionRepository.deleteSession with the session id '
        '(party-session.md §Deleting a session)', (tester) async {
      final repo = _FakePartySessionRepo();
      final profile = _makeProfile();

      final session = PartySession(
        id: 'delete-me',
        startedAt: DateTime.utc(2026, 7, 1, 20, 0),
        endedAt: DateTime.utc(2026, 7, 1, 23, 0),
        endReason: PartySessionEndReason.manual,
        useSessionPrices: false,
        createdAt: DateTime.utc(2026, 7, 1, 20, 0),
        updatedAt: DateTime.utc(2026, 7, 1, 23, 0),
      );
      final summaries = [
        SessionDaySummary(
          session: session,
          duration: const Duration(hours: 3),
          totalAlcoholicDrinks: 1,
          mealsLoggedCount: 0,
          peakBacGPerL: 0.1,
        ),
      ];

      await tester.pumpWidget(
        _buildScreen(
          session: null,
          profile: profile,
          partyRepo: repo,
          endedSessionSummaries: summaries,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete session?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repo.deleteSessionCalls, ['delete-me']);
    });

    testWidgets(
      'cancelling the delete confirmation calls deleteSession zero times',
      (tester) async {
        final repo = _FakePartySessionRepo();
        final profile = _makeProfile();

        final session = PartySession(
          id: 'keep-me',
          startedAt: DateTime.utc(2026, 7, 1, 20, 0),
          endedAt: DateTime.utc(2026, 7, 1, 23, 0),
          endReason: PartySessionEndReason.manual,
          useSessionPrices: false,
          createdAt: DateTime.utc(2026, 7, 1, 20, 0),
          updatedAt: DateTime.utc(2026, 7, 1, 23, 0),
        );
        final summaries = [
          SessionDaySummary(
            session: session,
            duration: const Duration(hours: 3),
            totalAlcoholicDrinks: 1,
            mealsLoggedCount: 0,
            peakBacGPerL: 0.1,
          ),
        ];

        await tester.pumpWidget(
          _buildScreen(
            session: null,
            profile: profile,
            partyRepo: repo,
            endedSessionSummaries: summaries,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Delete session?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(repo.deleteSessionCalls, isEmpty);
        // The row itself is still present — cancelling never navigated away.
        expect(find.text(_expectedPastSessionTitle(session)), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // "Settings opened" auto-end trigger point (issue #94)
  //
  // party-session.md §Auto-end is computed lazily lists "Settings opened" as
  // one of the five trigger points; party_screen.dart's `_settingsButton`
  // calls PartySessionRepository.checkAndApplyAutoEnd() immediately before
  // pushing SettingsScreen. Unlike every other test in this file, this one
  // wires a REAL PartySessionRepository (backed by a real in-memory
  // AppDatabase) into partySessionRepositoryProvider instead of
  // _FakePartySessionRepo, so the retroactive end is asserted against actual
  // DB state — proving PartyScreen's gear icon really runs the check, not
  // just that the repository method exists (already covered by
  // party_session_repository_test.dart's "lazy 12h auto-end" group).
  // ---------------------------------------------------------------------------

  group('PartyScreen — Settings-opened auto-end trigger', () {
    testWidgets(
      'tapping the settings gear retroactively ends a session whose 12h '
      'mark has already passed',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final realPartyRepo = PartySessionRepository(db);

        // Source: party-session.md §Ending a session — "12 hours after
        // startedAt if no alcoholic drinks were logged"; endedAt is the
        // mark, not "now". Truncated to whole-second precision — Drift's
        // default DateTime column stores a unix-seconds INTEGER, so a raw
        // DateTime.now() would never round-trip byte-for-byte.
        final nowSeconds =
            DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 * 1000;
        final startedAt = DateTime.fromMillisecondsSinceEpoch(
          nowSeconds,
          isUtc: true,
        ).subtract(const Duration(hours: 20));
        final session = await realPartyRepo.startSession(
          now: startedAt,
          startedAt: startedAt,
        );
        // A drink must be logged (at startedAt, so the auto-end mark below
        // still matches) so the session actually auto-ends instead of being
        // discarded as zero-drink (party-session.md §Zero-drink sessions are
        // never saved) — unrelated to what this test checks (the settings
        // gear trigger point), but required for endedAt/endReason to be set
        // at all.
        await realPartyRepo.logAlcoholicDrink(
          preset: _beerPreset,
          sessionId: session.id,
          consumedAt: startedAt,
          now: startedAt,
        );
        final mark = startedAt.add(const Duration(hours: 12));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              partySessionRepositoryProvider.overrideWithValue(realPartyRepo),
              // The screen renders with no active session in view — this
              // test only exercises the settings gear, not the BAC card.
              activePartySessionProvider.overrideWith(
                (_) => Stream.value(null),
              ),
              partySessionEntriesProvider.overrideWith(
                (ref, sessionId) => Stream.value(const <DrinkEntry>[]),
              ),
              partySessionMealsProvider.overrideWith(
                (ref, sessionId) => Stream.value(const <Meal>[]),
              ),
              partySessionPricesProvider.overrideWith(
                (ref, sessionId) => Stream.value(const <PartySessionPrice>[]),
              ),
              userProfileProvider.overrideWith((_) => Stream.value(null)),
              userPreferencesProvider.overrideWith(
                (_) => Stream.value(_makePrefs()),
              ),
              nowTickerProvider.overrideWith(
                (_) => Stream.value(DateTime.now()),
              ),
              visibleAlcoholicPresetsProvider.overrideWith(
                (_) => Stream.value(const <DrinkPreset>[]),
              ),
              partyEndedSessionsProvider.overrideWith(
                (_) => Stream.value(const <PartySession>[]),
              ),
              partyEndedSessionSummariesProvider.overrideWith(
                (_) async => const <SessionDaySummary>[],
              ),
              // SettingsScreen (pushed after the gear tap) watches this
              // directly — without an override it hits the real (unmocked)
              // drinksRepositoryProvider/_appDatabaseProvider chain, which
              // would try to open a real on-disk database in the test env.
              visibleNonAlcoholicPresetsProvider.overrideWith(
                (_) => Stream.value(const <DrinkPreset>[]),
              ),
              appInfoServiceProvider.overrideWithValue(
                const FakeAppInfoService(),
              ),
            ],
            child: const MaterialApp(home: PartyScreen()),
          ),
        );
        await tester.pump();

        expect((await db.getPartySessionById(session.id))!.endedAt, isNull);

        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();

        final row = await db.getPartySessionById(session.id);
        expect(row!.endedAt, isNotNull);
        expect(row.endedAt!.isAtSameMomentAs(mark), isTrue);
        expect(row.endReason, PartySessionEndReason.autoTimeout.stored);
        expect(await db.getActiveSession(), isNull);
      },
    );
  });
}
