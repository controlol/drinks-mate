// Widget tests for S9/issue #86 — PartySessionLogScreen.
//
// Coverage (user-experience.md §S9 — Party Session Log):
//  1. Active mode (sessionId matches the active session): BAC/drinks-count/
//     elapsed header, newest-first entry list, empty state with "Log
//     alcohol" button when there are no alcoholic entries.
//  2. Ended mode (sessionId does NOT match the active session, or there is
//     no active session): SessionSummaryCard-based header
//     (duration/total drinks/meals logged/peak BAC), read-only entries (no
//     chevron/tap), no "Log alcohol" affordance in the empty state.
//  3. Only alcoholic entries appear in the list.
//  4. Tapping a row in active mode -> "Edit" opens the edit sheet pre-filled
//     with the entry's current values; Save calls
//     PartySessionRepository.updateAlcoholicEntry with the edited values.
//  5. Tapping a row in active mode -> "Delete" -> confirm calls
//     DrinksRepository.deleteDrinkEntry with the entry's id.
//
// Provider override pattern mirrors flutter/test/widgets/party_screen_test.dart
// — fake repository subclasses record calls without touching the DB; every
// stream/future provider PartySessionLogScreen reads is overridden directly
// (including partySessionSummaryProvider, per this repo's convention of
// overriding derived FutureProviders directly rather than re-deriving them
// through a fake repository's getSessionById/getEntriesForSessions).
import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/models/meal.dart';
import 'package:drinks_mate/src/models/optional.dart';
import 'package:drinks_mate/src/models/party_session.dart';
import 'package:drinks_mate/src/models/session_day_summary.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/models/user_profile.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/party_session_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/party_session_log_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repositories — record calls without touching a real DB (beyond the
// throwaway in-memory instance each superclass constructor requires).
// ---------------------------------------------------------------------------

class _FakePartySessionRepo extends PartySessionRepository {
  _FakePartySessionRepo() : super(AppDatabase(NativeDatabase.memory()));

  final List<
      ({
        String id,
        int? volumeMl,
        String? name,
        double? abvPercent,
        DateTime? consumedAt,
        Optional<int?> priceMinor,
        Optional<String?> currency,
      })> updateAlcoholicEntryCalls = [];

  @override
  Future<void> updateAlcoholicEntry({
    required String id,
    int? volumeMl,
    String? name,
    double? abvPercent,
    DateTime? consumedAt,
    Optional<int?> priceMinor = const Optional.absent(),
    Optional<String?> currency = const Optional.absent(),
    DateTime? now,
  }) async {
    updateAlcoholicEntryCalls.add((
      id: id,
      volumeMl: volumeMl,
      name: name,
      abvPercent: abvPercent,
      consumedAt: consumedAt,
      priceMinor: priceMinor,
      currency: currency,
    ));
  }
}

class _FakeDrinksRepo extends DrinksRepository {
  _FakeDrinksRepo() : super(AppDatabase(NativeDatabase.memory()));

  final List<String> deleteDrinkEntryCalls = [];

  @override
  Future<void> deleteDrinkEntry(String id) async {
    deleteDrinkEntryCalls.add(id);
  }
}

// ---------------------------------------------------------------------------
// Fixture builders
// ---------------------------------------------------------------------------

final _epoch = DateTime.utc(2020, 1, 1);

UserProfile _makeProfile() {
  return UserProfile(
    id: 'profile-1',
    gender: 'male',
    weightKg: 75,
    heightCm: 180,
    birthDate: '1996-06-01',
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

UserPreferences _makePrefs({String currency = 'EUR'}) {
  return UserPreferences(
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
  required String id,
  required DateTime consumedAt,
  int volumeMl = 330,
  double abvPercent = 5.0,
  String? name,
  int? priceMinor,
  String? currency,
  int? priceTokens,
  int? tokenValueMinor,
  String? tokenValueCurrency,
}) {
  return DrinkEntry(
    id: id,
    name: name ?? 'Test Beer',
    beverageType: BeverageType.beer,
    volumeMl: volumeMl,
    abvPercent: abvPercent,
    priceMinor: priceMinor,
    currency: currency,
    priceTokens: priceTokens,
    tokenValueMinor: tokenValueMinor,
    tokenValueCurrency: tokenValueCurrency,
    consumedAt: consumedAt,
    createdAt: consumedAt,
    updatedAt: consumedAt,
  );
}

DrinkEntry _waterEntry({required String id, required DateTime consumedAt}) {
  return DrinkEntry(
    id: id,
    name: 'Water',
    beverageType: BeverageType.water,
    volumeMl: 300,
    consumedAt: consumedAt,
    createdAt: consumedAt,
    updatedAt: consumedAt,
  );
}

/// Builds a testable PartySessionLogScreen with every provider it reads
/// overridden — no real Drift stream is ever started.
/// [alwaysUse24HourFormat] drives `MediaQuery.alwaysUse24HourFormat`, which
/// is what `TimeOfDay.format(context)` actually keys off (not [Locale]) —
/// see the "Time-of-day display format" Parity Rulebook row. Mirrors
/// today_drinks_screen_test.dart's/history_day_screen_test.dart's
/// `_buildScreen` helper.
Widget _buildScreen({
  required String sessionId,
  PartySession? activeSession,
  List<DrinkEntry> entries = const [],
  List<Meal> meals = const [],
  UserProfile? profile,
  DateTime? now,
  SessionDaySummary? endedSummary,
  bool alwaysUse24HourFormat = false,
  String prefsCurrency = 'EUR',
  required _FakePartySessionRepo partyRepo,
  required _FakeDrinksRepo drinksRepo,
}) {
  return ProviderScope(
    overrides: [
      partySessionRepositoryProvider.overrideWithValue(partyRepo),
      drinksRepositoryProvider.overrideWithValue(drinksRepo),
      activePartySessionProvider.overrideWith(
        (_) => Stream.value(activeSession),
      ),
      partySessionEntriesProvider.overrideWith(
        (ref, id) => Stream.value(entries),
      ),
      partySessionMealsProvider.overrideWith((ref, id) => Stream.value(meals)),
      userProfileProvider.overrideWith((_) => Stream.value(profile)),
      userPreferencesProvider.overrideWith(
        (_) => Stream.value(_makePrefs(currency: prefsCurrency)),
      ),
      nowTickerProvider
          .overrideWith((_) => Stream.value(now ?? DateTime.now())),
      if (endedSummary != null)
        partySessionSummaryProvider.overrideWith(
          (ref, id) async => endedSummary,
        ),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(alwaysUse24HourFormat: alwaysUse24HourFormat),
        child: child!,
      ),
      home: PartySessionLogScreen(sessionId: sessionId),
    ),
  );
}

void main() {
  final startedAt = DateTime.utc(2026, 7, 10, 20, 0);

  // -------------------------------------------------------------------------
  // 1. Active mode
  // -------------------------------------------------------------------------

  group('Active mode (sessionId matches the active session)', () {
    testWidgets(
      'shows BAC/drinks-count/elapsed header and a newest-first entry list',
      (tester) async {
        final session = _makeSession(startedAt: startedAt);
        // Distinct names so the two rows are distinguishable — with both
        // entries named identically, any list-position assertion would pass
        // regardless of actual ordering and couldn't catch a regression
        // that dropped the newest-first `.reversed`.
        final entries = [
          _alcoholicEntry(
            id: 'first',
            consumedAt: startedAt,
            name: 'Earlier Beer',
          ),
          _alcoholicEntry(
            id: 'second',
            consumedAt: startedAt.add(const Duration(hours: 1)),
            name: 'Later Beer',
          ),
        ];
        final now = startedAt.add(const Duration(hours: 2));

        await tester.pumpWidget(
          _buildScreen(
            sessionId: session.id,
            activeSession: session,
            entries: entries,
            profile: _makeProfile(),
            now: now,
            partyRepo: _FakePartySessionRepo(),
            drinksRepo: _FakeDrinksRepo(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('g/L'), findsWidgets);
        expect(find.text('2 alcoholic drinks this session'), findsOneWidget);
        expect(find.text('Elapsed: 2h 0m'), findsOneWidget);

        // Newest-first (user-experience.md §S9: "newest first"): the
        // later-consumed entry ('Later Beer') must render above the
        // earlier-consumed one ('Earlier Beer').
        final laterDy = tester.getTopLeft(find.text('Later Beer')).dy;
        final earlierDy = tester.getTopLeft(find.text('Earlier Beer')).dy;
        expect(laterDy, lessThan(earlierDy));
      },
    );

    testWidgets(
      'empty state shows a friendly prompt and a "Log alcohol" button',
      (tester) async {
        final session = _makeSession(startedAt: startedAt);

        await tester.pumpWidget(
          _buildScreen(
            sessionId: session.id,
            activeSession: session,
            entries: const [],
            profile: _makeProfile(),
            now: startedAt,
            partyRepo: _FakePartySessionRepo(),
            drinksRepo: _FakeDrinksRepo(),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('No alcoholic drinks logged in this session yet'),
          findsOneWidget,
        );
        expect(
            find.widgetWithText(FilledButton, 'Log alcohol'), findsOneWidget);
      },
    );

    testWidgets(
      'only alcoholic entries appear — a non-alcoholic entry does not render '
      'as a row',
      (tester) async {
        final session = _makeSession(startedAt: startedAt);
        final entries = [
          _alcoholicEntry(id: 'beer-1', consumedAt: startedAt),
          _waterEntry(
            id: 'water-1',
            consumedAt: startedAt.add(const Duration(minutes: 10)),
          ),
        ];

        await tester.pumpWidget(
          _buildScreen(
            sessionId: session.id,
            activeSession: session,
            entries: entries,
            profile: _makeProfile(),
            now: startedAt,
            partyRepo: _FakePartySessionRepo(),
            drinksRepo: _FakeDrinksRepo(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('Water'), findsNothing);
        expect(find.text('Test Beer'), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // 3a. Row subtitle: FormatService-backed volume, ABV, and a time label
    //     that honours the device's 12h/24h preference (EntryRow — shared
    //     across S6/S3/S9, entry_row.dart). Before the shared EntryRow
    //     extraction, S9 rendered a hand-built, always-24h "HH:mm" string —
    //     this pins the fix (Parity Rulebook "Time-of-day display format").
    // -----------------------------------------------------------------------

    testWidgets(
      'row subtitle shows volume, ABV, and a 12h/24h time label honouring '
      'the device preference',
      (tester) async {
        final session = _makeSession(startedAt: startedAt);
        final entries = [
          _alcoholicEntry(id: 'beer-1', consumedAt: startedAt),
        ];

        await tester.pumpWidget(
          _buildScreen(
            sessionId: session.id,
            activeSession: session,
            entries: entries,
            profile: _makeProfile(),
            now: startedAt,
            alwaysUse24HourFormat: false,
            partyRepo: _FakePartySessionRepo(),
            drinksRepo: _FakeDrinksRepo(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('330 ml · 5.0% ABV · 8:00 PM'), findsOneWidget);
      },
    );

    testWidgets(
      'row subtitle time label renders 24h when alwaysUse24HourFormat=true',
      (tester) async {
        final session = _makeSession(startedAt: startedAt);
        final entries = [
          _alcoholicEntry(id: 'beer-1', consumedAt: startedAt),
        ];

        await tester.pumpWidget(
          _buildScreen(
            sessionId: session.id,
            activeSession: session,
            entries: entries,
            profile: _makeProfile(),
            now: startedAt,
            alwaysUse24HourFormat: true,
            partyRepo: _FakePartySessionRepo(),
            drinksRepo: _FakeDrinksRepo(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('330 ml · 5.0% ABV · 20:00'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a row opens the edit sheet directly, pre-filled with the '
      'entry\'s current volume/ABV/price (no name field — S9 no longer '
      'edits name, matching S6); saving calls updateAlcoholicEntry with the '
      'edited values',
      (tester) async {
        final session = _makeSession(startedAt: startedAt);
        final entry = _alcoholicEntry(
          id: 'beer-1',
          consumedAt: startedAt,
          volumeMl: 330,
          abvPercent: 5.0,
          name: 'Original Beer',
          priceMinor: 450,
          currency: 'EUR',
        );
        final repo = _FakePartySessionRepo();

        // EntryEditSheet's 3 fields + Save button are taller than the
        // default 800x600 test surface — widen it (same convention as
        // party_screen_test.dart's PartyLogDrinkSheet tests) so the Save
        // button is on-screen and hit-testable without scrolling a
        // fragile-to-target Scrollable.
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildScreen(
            sessionId: session.id,
            activeSession: session,
            entries: [entry],
            profile: _makeProfile(),
            now: startedAt,
            partyRepo: repo,
            drinksRepo: _FakeDrinksRepo(),
          ),
        );
        await tester.pumpAndSettle();

        // No intermediate action menu — tapping the row opens the edit
        // sheet directly.
        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();

        expect(find.text('Edit drink'), findsOneWidget);
        final textFields = find.byType(TextField);
        expect(textFields, findsNWidgets(3));
        // Declaration order in EntryEditSheet.build: volume, abv, price.
        final volumeField = tester.widget<TextField>(textFields.at(0));
        final abvField = tester.widget<TextField>(textFields.at(1));
        final priceField = tester.widget<TextField>(textFields.at(2));
        expect(volumeField.controller!.text, '330');
        expect(abvField.controller!.text, '5.0');
        expect(priceField.controller!.text, '4.50');

        // The time button must show the date, not just the time-of-day — S9
        // (unlike S6/S3) lets an entry move across calendar days, since a
        // session can span midnight (EntryEditSheet's `showDate: true`).
        expect(find.textContaining('2026-07-10'), findsOneWidget);

        await tester.enterText(textFields.at(0), '500');
        await tester.enterText(textFields.at(1), '8.0');
        await tester.enterText(textFields.at(2), '6.00');
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        expect(repo.updateAlcoholicEntryCalls, hasLength(1));
        final call = repo.updateAlcoholicEntryCalls.single;
        expect(call.id, 'beer-1');
        expect(call.name, isNull, reason: 'S9 no longer edits name');
        expect(call.volumeMl, 500);
        expect(call.abvPercent, 8.0);
        expect(call.priceMinor, const Optional.value(600));
        expect(call.currency, const Optional.value('EUR'));
      },
    );

    testWidgets(
      'editing only volume of a token-priced entry leaves its price '
      'untouched (Optional.absent()) — the money-only price field renders '
      'blank for a token price, and must not be treated as "clear the '
      'price" just because it was never touched',
      (tester) async {
        final session = _makeSession(startedAt: startedAt);
        final entry = _alcoholicEntry(
          id: 'token-beer',
          consumedAt: startedAt,
          name: 'Token Beer',
          priceTokens: 2,
          tokenValueMinor: 300,
          tokenValueCurrency: 'EUR',
        );
        final repo = _FakePartySessionRepo();

        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildScreen(
            sessionId: session.id,
            activeSession: session,
            entries: [entry],
            profile: _makeProfile(),
            now: startedAt,
            partyRepo: repo,
            drinksRepo: _FakeDrinksRepo(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        final priceField = tester.widget<TextField>(textFields.at(2));
        // Blank — the field can't represent a token price.
        expect(priceField.controller!.text, '');

        // Only touch the volume field; leave price alone.
        await tester.enterText(textFields.at(0), '500');
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        expect(repo.updateAlcoholicEntryCalls, hasLength(1));
        final call = repo.updateAlcoholicEntryCalls.single;
        expect(call.volumeMl, 500);
        expect(call.priceMinor, const Optional<int?>.absent());
        expect(call.currency, const Optional<String?>.absent());
      },
    );

    testWidgets(
      'setting a first-time price on an entry logged with no price/currency '
      "falls back to the user's preferred currency (defaultCurrency), not "
      "a hardcoded 'EUR'",
      (tester) async {
        final session = _makeSession(startedAt: startedAt);
        final entry = _alcoholicEntry(
          id: 'beer-1',
          consumedAt: startedAt,
        );
        final repo = _FakePartySessionRepo();

        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildScreen(
            sessionId: session.id,
            activeSession: session,
            entries: [entry],
            profile: _makeProfile(),
            now: startedAt,
            prefsCurrency: 'USD',
            partyRepo: repo,
            drinksRepo: _FakeDrinksRepo(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(2), '6.00');
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        expect(repo.updateAlcoholicEntryCalls, hasLength(1));
        final call = repo.updateAlcoholicEntryCalls.single;
        expect(call.priceMinor, const Optional.value(600));
        expect(call.currency, const Optional.value('USD'));
      },
    );

    testWidgets(
      'tapping the row\'s Delete button then confirming calls '
      'DrinksRepository.deleteDrinkEntry with the entry\'s id',
      (tester) async {
        final session = _makeSession(startedAt: startedAt);
        final entry =
            _alcoholicEntry(id: 'beer-to-delete', consumedAt: startedAt);
        final drinksRepo = _FakeDrinksRepo();

        await tester.pumpWidget(
          _buildScreen(
            sessionId: session.id,
            activeSession: session,
            entries: [entry],
            profile: _makeProfile(),
            now: startedAt,
            partyRepo: _FakePartySessionRepo(),
            drinksRepo: drinksRepo,
          ),
        );
        await tester.pumpAndSettle();

        // No intermediate action menu — a Delete button sits directly on
        // the row (mirrors S6/S3's EntryRow).
        await tester.tap(find.byTooltip('Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Delete entry?'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(drinksRepo.deleteDrinkEntryCalls, ['beer-to-delete']);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 2. Ended mode
  // -------------------------------------------------------------------------

  group(
    'Ended mode (sessionId does NOT match the active session, or there is '
    'no active session)',
    () {
      testWidgets(
        'shows the SessionSummaryCard-based header (duration/total drinks/'
        'meals logged/peak BAC) when there is no active session',
        (tester) async {
          final session = _makeSession(startedAt: startedAt);
          final summary = SessionDaySummary(
            session: session,
            duration: const Duration(hours: 3, minutes: 15),
            totalAlcoholicDrinks: 2,
            mealsLoggedCount: 1,
            peakBacGPerL: 0.36,
          );

          await tester.pumpWidget(
            _buildScreen(
              sessionId: session.id,
              activeSession: null,
              entries: const [],
              profile: _makeProfile(),
              partyRepo: _FakePartySessionRepo(),
              drinksRepo: _FakeDrinksRepo(),
              endedSummary: summary,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Duration: 3h 15m'), findsOneWidget);
          expect(find.text('Alcoholic drinks: 2'), findsOneWidget);
          expect(find.text('Meals logged: 1'), findsOneWidget);
          expect(find.textContaining('Peak estimated BAC: 0.36 g/L'),
              findsOneWidget);
        },
      );

      testWidgets(
        'shows ended-mode when sessionId does not match the currently '
        'active session (a different session is active)',
        (tester) async {
          final viewedSession = _makeSession(
            startedAt: startedAt,
            id: 'viewed-session',
          );
          final otherActiveSession = _makeSession(
            startedAt: startedAt.add(const Duration(days: 1)),
            id: 'other-active-session',
          );
          final summary = SessionDaySummary(
            session: viewedSession,
            duration: const Duration(hours: 1),
            totalAlcoholicDrinks: 1,
            mealsLoggedCount: 0,
            peakBacGPerL: 0.1,
          );

          await tester.pumpWidget(
            _buildScreen(
              sessionId: viewedSession.id,
              activeSession: otherActiveSession,
              entries: const [],
              profile: _makeProfile(),
              partyRepo: _FakePartySessionRepo(),
              drinksRepo: _FakeDrinksRepo(),
              endedSummary: summary,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Duration: 1h 0m'), findsOneWidget);
        },
      );

      testWidgets(
        'entries are read-only — no Delete button, and tapping a row does '
        'nothing',
        (tester) async {
          final session = _makeSession(startedAt: startedAt);
          final entry = _alcoholicEntry(id: 'beer-1', consumedAt: startedAt);
          final summary = SessionDaySummary(
            session: session,
            duration: const Duration(hours: 1),
            totalAlcoholicDrinks: 1,
            mealsLoggedCount: 0,
            peakBacGPerL: 0.1,
          );

          await tester.pumpWidget(
            _buildScreen(
              sessionId: session.id,
              activeSession: null,
              entries: [entry],
              profile: _makeProfile(),
              partyRepo: _FakePartySessionRepo(),
              drinksRepo: _FakeDrinksRepo(),
              endedSummary: summary,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byTooltip('Delete'), findsNothing);
          expect(
            tester.widget<ListTile>(find.byType(ListTile)).onTap,
            isNull,
          );

          await tester.tap(find.byType(ListTile));
          await tester.pumpAndSettle();

          expect(find.text('Edit drink'), findsNothing);
          expect(find.text('Delete entry?'), findsNothing);
        },
      );

      testWidgets(
        'empty state shows a friendly prompt with NO "Log alcohol" '
        'affordance',
        (tester) async {
          final session = _makeSession(startedAt: startedAt);
          final summary = SessionDaySummary(
            session: session,
            duration: const Duration(hours: 1),
            totalAlcoholicDrinks: 0,
            mealsLoggedCount: 0,
          );

          await tester.pumpWidget(
            _buildScreen(
              sessionId: session.id,
              activeSession: null,
              entries: const [],
              profile: _makeProfile(),
              partyRepo: _FakePartySessionRepo(),
              drinksRepo: _FakeDrinksRepo(),
              endedSummary: summary,
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('No alcoholic drinks were logged in this session'),
            findsOneWidget,
          );
          expect(find.text('Log alcohol'), findsNothing);
        },
      );
    },
  );

  // ---------------------------------------------------------------------------
  // sessionEditMinDate — pure helper behind the edit sheet's date-picker
  // lower bound (see the DateEditPicker.free wiring in
  // party_session_log_screen.dart's _openActions).
  // ---------------------------------------------------------------------------

  group('sessionEditMinDate', () {
    final sessionStartedAt = DateTime.utc(2026, 7, 10, 20, 0);

    test('returns null when sessionStartedAt is null (ended-mode rows)', () {
      expect(
        sessionEditMinDate(
          sessionStartedAt: null,
          entryConsumedAt: DateTime.utc(2026, 7, 10, 21, 0),
        ),
        isNull,
      );
    });

    test(
      'returns sessionStartedAt for a normal entry logged during the '
      'session (consumedAt >= sessionStartedAt)',
      () {
        expect(
          sessionEditMinDate(
            sessionStartedAt: sessionStartedAt,
            entryConsumedAt: DateTime.utc(2026, 7, 10, 21, 0),
          ),
          sessionStartedAt,
        );
      },
    );

    test(
      'returns the entry\'s own consumedAt for an absorbed orphan that '
      'predates the session (party-session.md: "absorbed orphans extend '
      'backwards in time") — sessionStartedAt alone would make that '
      'earlier timestamp unreachable in the picker',
      () {
        final orphanConsumedAt = DateTime.utc(2026, 7, 10, 18, 0);
        expect(
          sessionEditMinDate(
            sessionStartedAt: sessionStartedAt,
            entryConsumedAt: orphanConsumedAt,
          ),
          orphanConsumedAt,
        );
      },
    );

    test(
      'returns sessionStartedAt (not entryConsumedAt) when consumedAt '
      'exactly equals sessionStartedAt',
      () {
        expect(
          sessionEditMinDate(
            sessionStartedAt: sessionStartedAt,
            entryConsumedAt: sessionStartedAt,
          ),
          sessionStartedAt,
        );
      },
    );
  });
}
