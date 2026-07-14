// Widget tests for S4/F6 — SettingsScreen.
//
// Coverage:
//  1. All 7 canonical section headers render (user-experience.md S4 /
//     features.md F6: Hydration, Reminders, Drinks, Profile, Party Mode,
//     Display & format, About).
//  2. Writing a field calls the corresponding PreferencesRepository method
//     with the right value (reminder master switch, notification toggles,
//     daily goal field, weight field, BAC cap field, Party Mode toggles,
//     units segmented button).
//  3. Toggling units 'metric' -> 'imperial' changes the displayed unit
//     suffixes for weight, height, and daily goal.
//  4. Party Mode gating: no birthdate / under-18 / 18+ each show the right
//     widget subtree (settings_screen.dart _PartyModeSection).
//  5. Default-drink dropdown only offers non-alcoholic presets (the real
//     visibleNonAlcoholicPresetsProvider filter runs against a fake
//     DrinksRepository seeded with a mixed alcoholic/non-alcoholic list).
//  6. Tapping "Manage drinks" pushes ManageDrinksScreen.
//  7. Toggling "Always show alcoholic drinks" calls
//     updateAlcoholicPresetsAlwaysVisible with the new value.
//
// Provider override pattern mirrors
// flutter/test/widgets/today_drinks_screen_test.dart — fake repository
// subclasses record calls without touching the DB; formatServiceProvider and
// appInfoServiceProvider are exercised through their real definitions (the
// former derives from the overridden userPreferencesProvider; the latter is
// overridden with FakeAppInfoService to avoid the package_info_plus platform
// channel).

import 'package:drift/native.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/models/user_preferences.dart';
import 'package:drinks_mate/src/models/user_profile.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/preferences_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/manage_drinks_screen.dart';
import 'package:drinks_mate/src/screens/settings_screen.dart';
import 'package:drinks_mate/src/services/app_info_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repositories — record calls; never touch the real DB.
// ---------------------------------------------------------------------------

class _FakePreferencesRepo extends PreferencesRepository {
  _FakePreferencesRepo() : super(AppDatabase(NativeDatabase.memory()));

  int? lastDailyGoalMl;
  int? lastDayBoundaryHour;
  String? lastUnits;
  String? lastCurrency;
  final List<
      ({
        bool? reminderEnabled,
        int? startHour,
        int? endHour,
        int? intervalMin,
      })> reminderScheduleCalls = [];
  final List<({bool? inactivityReminderEnabled, bool? weeklySummaryEnabled})>
      notificationToggleCalls = [];
  bool defaultDrinkPresetCalled = false;
  String? lastDefaultDrinkPresetId;
  bool bacCapCalled = false;
  double? lastBacCap;
  final List<
      ({
        bool? bacOnLockScreenEnabled,
        bool? approachingCapNotifEnabled,
        bool? soberEstimateNotifEnabled,
      })> partyModeCalls = [];
  UserProfile? lastUpsertedProfile;
  bool? lastAlcoholicPresetsAlwaysVisible;

  @override
  Future<void> updateDailyGoal(int dailyGoalMl) async {
    lastDailyGoalMl = dailyGoalMl;
  }

  @override
  Future<void> updateDayBoundaryHour(int hour) async {
    lastDayBoundaryHour = hour;
  }

  @override
  Future<void> updateUnits(String units) async {
    lastUnits = units;
  }

  @override
  Future<void> updateCurrency(String currency) async {
    lastCurrency = currency;
  }

  @override
  Future<void> updateReminderSchedule({
    bool? reminderEnabled,
    int? startHour,
    int? endHour,
    int? intervalMin,
  }) async {
    reminderScheduleCalls.add((
      reminderEnabled: reminderEnabled,
      startHour: startHour,
      endHour: endHour,
      intervalMin: intervalMin,
    ));
  }

  @override
  Future<void> updateNotificationToggles({
    bool? inactivityReminderEnabled,
    bool? weeklySummaryEnabled,
  }) async {
    notificationToggleCalls.add((
      inactivityReminderEnabled: inactivityReminderEnabled,
      weeklySummaryEnabled: weeklySummaryEnabled,
    ));
  }

  @override
  Future<void> updateDefaultDrinkPreset(String? presetId) async {
    defaultDrinkPresetCalled = true;
    lastDefaultDrinkPresetId = presetId;
  }

  @override
  Future<void> updateBacCap(double? bacCapGramsPerL) async {
    bacCapCalled = true;
    lastBacCap = bacCapGramsPerL;
  }

  @override
  Future<void> updatePartyModeSettings({
    bool? bacOnLockScreenEnabled,
    bool? approachingCapNotifEnabled,
    bool? soberEstimateNotifEnabled,
  }) async {
    partyModeCalls.add((
      bacOnLockScreenEnabled: bacOnLockScreenEnabled,
      approachingCapNotifEnabled: approachingCapNotifEnabled,
      soberEstimateNotifEnabled: soberEstimateNotifEnabled,
    ));
  }

  @override
  Future<void> upsertProfile(UserProfile profile) async {
    lastUpsertedProfile = profile;
  }

  @override
  Future<void> updateAlcoholicPresetsAlwaysVisible(bool value) async {
    lastAlcoholicPresetsAlwaysVisible = value;
  }
}

/// Fake [DrinksRepository] whose visible/all preset streams both yield a
/// fixed list — lets the *real* [visibleNonAlcoholicPresetsProvider]
/// definition (the `.where((p) => !p.beverageType.isAlcoholic)` filter) run
/// against test data, instead of stubbing the filtered result directly.
class _FakeDrinksRepo extends DrinksRepository {
  _FakeDrinksRepo([this._presets = const []])
      : super(AppDatabase(NativeDatabase.memory()));

  final List<DrinkPreset> _presets;

  @override
  Stream<List<DrinkPreset>> watchVisiblePresets() => Stream.value(_presets);

  @override
  Stream<List<DrinkPreset>> watchAllPresets() => Stream.value(_presets);
}

// ---------------------------------------------------------------------------
// Fixture builders
// ---------------------------------------------------------------------------

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

UserPreferences _makePrefs({
  String units = 'metric',
  String currency = 'EUR',
  int dailyGoalMl = 2000,
  bool reminderEnabled = false,
  bool inactivityReminderEnabled = false,
  bool weeklySummaryEnabled = false,
  String? defaultDrinkPresetId,
  double? bacCapGramsPerL,
  bool bacOnLockScreenEnabled = false,
  bool approachingCapNotifEnabled = false,
  bool soberEstimateNotifEnabled = false,
  bool alcoholicPresetsAlwaysVisible = true,
}) {
  return UserPreferences(
    id: kUserPreferencesId,
    username: 'tester',
    dailyGoalMl: dailyGoalMl,
    dayBoundaryHour: 5,
    units: units,
    currency: currency,
    reminderEnabled: reminderEnabled,
    reminderStartHour: 8,
    reminderEndHour: 22,
    reminderIntervalMin: 90,
    inactivityReminderEnabled: inactivityReminderEnabled,
    weeklySummaryEnabled: weeklySummaryEnabled,
    defaultDrinkPresetId: defaultDrinkPresetId,
    bacCapGramsPerL: bacCapGramsPerL,
    bacOnLockScreenEnabled: bacOnLockScreenEnabled,
    approachingCapNotifEnabled: approachingCapNotifEnabled,
    soberEstimateNotifEnabled: soberEstimateNotifEnabled,
    alcoholicPresetsAlwaysVisible: alcoholicPresetsAlwaysVisible,
    installedAt: _epoch,
    createdAt: _epoch,
    updatedAt: _epoch,
  );
}

UserProfile _makeProfile({
  String? gender,
  double? weightKg,
  double? heightCm,
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

DrinkPreset _preset({
  required String id,
  required String name,
  required BeverageType beverageType,
  int volumeMl = 250,
  bool isHidden = false,
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

/// ISO-8601 'yyyy-MM-dd' — matches settings_screen.dart's _formatDate output
/// format, which _BirthDateTile/_PartyModeSection round-trip via
/// DateTime.parse.
String _isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

Widget _buildScreen({
  required UserPreferences prefs,
  UserProfile? profile,
  required _FakePreferencesRepo repo,
  List<DrinkPreset> presets = const [],
}) {
  return ProviderScope(
    overrides: [
      preferencesRepositoryProvider.overrideWithValue(repo),
      userPreferencesProvider.overrideWith((_) => Stream.value(prefs)),
      userProfileProvider.overrideWith((_) => Stream.value(profile)),
      drinksRepositoryProvider.overrideWithValue(_FakeDrinksRepo(presets)),
      appInfoServiceProvider.overrideWithValue(const FakeAppInfoService()),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

/// Scrolls the Settings ListView (a plain `ListView(children: [...])`, which
/// still lazily mounts children through a sliver, so widgets below the fold
/// are absent from the tree until scrolled into the viewport + cache extent)
/// until [finder] is visible. Explicitly targets the first [Scrollable]
/// because `find.byType(Scrollable)` alone can match more than one instance
/// (e.g. one nested inside an open dropdown overlay).
///
/// `scrollUntilVisible` only scrolls until [finder] is *found in the tree*
/// (i.e. within the sliver's cache extent), which can leave it just outside
/// the actual on-screen viewport bounds and make a subsequent `tester.tap()`
/// hit-test-miss. The trailing `ensureVisible` does a precise scroll (via
/// `Scrollable.ensureVisible`) so the widget's bounds are fully on-screen.
Future<void> _scrollToVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. All 7 section headers render
  // -------------------------------------------------------------------------

  testWidgets('renders all 7 canonical S4 section headers', (tester) async {
    final repo = _FakePreferencesRepo();
    final profile = _makeProfile(
      gender: 'male',
      weightKg: 75,
      heightCm: 180,
      birthDate:
          _isoDate(DateTime.now().subtract(const Duration(days: 365 * 30))),
    );

    await tester.pumpWidget(
      _buildScreen(prefs: _makePrefs(), profile: profile, repo: repo),
    );
    await tester.pump(); // let the StreamProviders deliver their first values

    // Source: settings_screen.dart _SettingsBody.build — canonical S4/F6
    // group order: Hydration, Reminders, Drinks, Profile, Party Mode,
    // Display & format, About.
    //
    // The ListView only mounts children within the viewport + cache extent
    // (true even for a plain ListView(children: [...]), since it still
    // renders through a sliver list), so later sections must be scrolled
    // into view before their header text exists in the widget tree.
    // "Reminders" matches 2 widgets once mounted (the section header and the
    // master-switch label) — scrollUntilVisible needs a single-match finder
    // that exists both before and after scrolling, so scroll to a unique key
    // for that section instead of the ambiguous text.
    final scrollTargets = <String, Finder>{
      'Reminders': find.byKey(const Key('settings_reminder_master_switch')),
    };

    for (final title in [
      'Hydration',
      'Reminders',
      'Drinks',
      'Profile',
      'Party Mode',
      'Display & format',
      'About',
    ]) {
      final finder = find.text(title);
      await _scrollToVisible(tester, scrollTargets[title] ?? finder);
      // Some section titles (e.g. "Reminders") also appear as a
      // switch/tile label inside their own section, so assert presence,
      // not an exact count.
      expect(finder, findsAtLeastNWidgets(1),
          reason: 'missing "$title" section header');
    }
  });

  // -------------------------------------------------------------------------
  // 2. Writing fields calls the right PreferencesRepository method
  // -------------------------------------------------------------------------

  testWidgets(
      'tapping the reminder master switch calls '
      'updateReminderSchedule(reminderEnabled: true)', (tester) async {
    final repo = _FakePreferencesRepo();
    await tester.pumpWidget(
      _buildScreen(prefs: _makePrefs(reminderEnabled: false), repo: repo),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings_reminder_master_switch')));
    await tester.pump();

    expect(repo.reminderScheduleCalls, hasLength(1));
    expect(repo.reminderScheduleCalls.single.reminderEnabled, isTrue);
  });

  testWidgets(
      'toggling inactivity + weekly summary switches calls '
      'updateNotificationToggles with the right flag', (tester) async {
    final repo = _FakePreferencesRepo();
    await tester.pumpWidget(
      _buildScreen(
        prefs: _makePrefs(
          inactivityReminderEnabled: false,
          weeklySummaryEnabled: false,
        ),
        repo: repo,
      ),
    );
    await tester.pump();

    await _scrollToVisible(
        tester, find.byKey(const Key('settings_inactivity_switch')));
    await tester.tap(find.byKey(const Key('settings_inactivity_switch')));
    await tester.pump();
    await _scrollToVisible(
        tester, find.byKey(const Key('settings_weekly_summary_switch')));
    await tester.tap(find.byKey(const Key('settings_weekly_summary_switch')));
    await tester.pump();

    expect(repo.notificationToggleCalls, hasLength(2));
    expect(
      repo.notificationToggleCalls[0].inactivityReminderEnabled,
      isTrue,
    );
    expect(
      repo.notificationToggleCalls[1].weeklySummaryEnabled,
      isTrue,
    );
  });

  testWidgets('submitting the daily goal field (metric) calls updateDailyGoal',
      (tester) async {
    final repo = _FakePreferencesRepo();
    await tester.pumpWidget(
      _buildScreen(
          prefs: _makePrefs(units: 'metric', dailyGoalMl: 2000), repo: repo),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('settings_daily_goal_field')),
      '2500',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // Metric branch: `ml = value.roundToDouble()` then `.round()` — 2500 ml.
    // Source: settings_screen.dart _HydrationSection onSubmitted.
    expect(repo.lastDailyGoalMl, 2500);
  });

  testWidgets(
      'submitting the weight field (metric) calls upsertProfile with the '
      'parsed weightKg', (tester) async {
    final repo = _FakePreferencesRepo();
    final profile = _makeProfile(weightKg: 70);
    await tester.pumpWidget(
      _buildScreen(prefs: _makePrefs(), profile: profile, repo: repo),
    );
    await tester.pump();

    await _scrollToVisible(
        tester, find.byKey(const Key('settings_weight_field')));
    await tester.enterText(
      find.byKey(const Key('settings_weight_field')),
      '82.5',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // Metric branch: kg = v (no conversion). Source: settings_screen.dart
    // _ProfileSection weight field onSubmitted.
    expect(repo.lastUpsertedProfile?.weightKg, closeTo(82.5, 0.001));
  });

  testWidgets(
      'tapping the units segmented button (metric -> imperial) calls '
      'updateUnits', (tester) async {
    final repo = _FakePreferencesRepo();
    await tester.pumpWidget(
      _buildScreen(prefs: _makePrefs(units: 'metric'), repo: repo),
    );
    await tester.pump();

    await _scrollToVisible(
        tester, find.byKey(const Key('settings_units_segmented')));
    await tester.tap(find.descendant(
      of: find.byKey(const Key('settings_units_segmented')),
      matching: find.text('Imperial'),
    ));
    await tester.pumpAndSettle();

    expect(repo.lastUnits, 'imperial');
  });

  // -------------------------------------------------------------------------
  // 2b. Imperial write path — the screen must convert the entered imperial
  // value back to the metric-canonical unit before calling the repository
  // (settings_screen.dart _HydrationSection/_ProfileSection/_HeightEditor
  // onSubmitted: `isImperial ? flOzToMl(value) : ...`, `isImperial ?
  // lbToKg(v) : v`, `ftInToCm(ft, inch)`). If this conversion were ever
  // dropped, an imperial user's fl-oz/lb/ft-in input would be silently
  // stored as raw ml/kg/cm.
  // -------------------------------------------------------------------------

  testWidgets(
      'submitting the daily goal field (imperial) calls updateDailyGoal '
      'with the fl-oz value converted to ml', (tester) async {
    final repo = _FakePreferencesRepo();
    await tester.pumpWidget(
      _buildScreen(
        prefs: _makePrefs(units: 'imperial', dailyGoalMl: 2000),
        repo: repo,
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('settings_daily_goal_field')),
      '16.9',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // 16.9 fl oz -> 500 ml. Source: units_test.dart flOzToMl(16.9) == 500.0
    // (Parity Rulebook: 1 US fl oz = 29.5735295625 ml, rounded to nearest ml).
    expect(repo.lastDailyGoalMl, 500);
  });

  testWidgets(
      'submitting the weight field (imperial) calls upsertProfile with the '
      'lb value converted to kg', (tester) async {
    final repo = _FakePreferencesRepo();
    final profile = _makeProfile(weightKg: 70);
    await tester.pumpWidget(
      _buildScreen(
        prefs: _makePrefs(units: 'imperial'),
        profile: profile,
        repo: repo,
      ),
    );
    await tester.pump();

    await _scrollToVisible(
        tester, find.byKey(const Key('settings_weight_field')));
    await tester.enterText(
      find.byKey(const Key('settings_weight_field')),
      '154.3',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // 154.3 lb -> 69.989 kg. Source: units_test.dart lbToKg(154.3) closeTo
    // 69.989 (Parity Rulebook: 1 kg = 2.20462262185 lb, kg rounded to 3 dp).
    // Same 0.0005 tolerance as units_test.dart — half a quantum at 3 dp.
    expect(repo.lastUpsertedProfile?.weightKg, closeTo(69.989, 0.0005));
  });

  testWidgets(
      'submitting the height ft/in fields (imperial) calls upsertProfile '
      'with the value converted to heightCm', (tester) async {
    final repo = _FakePreferencesRepo();
    final profile = _makeProfile(heightCm: 175);
    await tester.pumpWidget(
      _buildScreen(
        prefs: _makePrefs(units: 'imperial'),
        profile: profile,
        repo: repo,
      ),
    );
    await tester.pump();

    await _scrollToVisible(
        tester, find.byKey(const Key('settings_height_ft_field')));
    await tester.enterText(
      find.byKey(const Key('settings_height_ft_field')),
      '5',
    );
    await tester.enterText(
      find.byKey(const Key('settings_height_in_field')),
      '11',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // (5 ft, 11 in) -> 180.3 cm. Source: units_test.dart ftInToCm(5, 11)
    // closeTo 180.3 (Parity Rulebook: 1 inch = 2.54 cm exactly, cm rounded
    // to 1 dp). _submitImperial reads both controllers on either field's
    // onSubmitted, so the "done" action after entering both fields commits
    // the pair together.
    expect(repo.lastUpsertedProfile?.heightCm, closeTo(180.3, 0.001));
  });

  // -------------------------------------------------------------------------
  // 3. Units toggle changes displayed suffixes
  // -------------------------------------------------------------------------

  testWidgets('metric fixture shows kg/cm/ml suffixes', (tester) async {
    final repo = _FakePreferencesRepo();
    final profile = _makeProfile(weightKg: 70, heightCm: 175);
    await tester.pumpWidget(
      _buildScreen(
        prefs: _makePrefs(units: 'metric', dailyGoalMl: 2000),
        profile: profile,
        repo: repo,
      ),
    );
    await tester.pump();

    // Suffix texts come from InputDecoration.suffixText — source:
    // settings_screen.dart _HydrationSection/_ProfileSection/_HeightEditor.
    expect(find.text('ml'), findsOneWidget); // daily goal suffix (in view)

    final heightCmFieldFinder =
        find.byKey(const Key('settings_height_cm_field'));
    await _scrollToVisible(tester, heightCmFieldFinder);

    expect(find.text('kg'), findsOneWidget); // weight suffix
    expect(find.text('cm'), findsOneWidget); // height suffix (metric field)
    expect(heightCmFieldFinder, findsOneWidget);
    expect(find.byKey(const Key('settings_height_ft_field')), findsNothing);
  });

  testWidgets('imperial fixture shows lb/ft/in/fl oz suffixes', (tester) async {
    final repo = _FakePreferencesRepo();
    final profile = _makeProfile(weightKg: 70, heightCm: 175);
    await tester.pumpWidget(
      _buildScreen(
        prefs: _makePrefs(units: 'imperial', dailyGoalMl: 2000),
        profile: profile,
        repo: repo,
      ),
    );
    await tester.pump();

    expect(find.text('fl oz'), findsOneWidget); // daily goal suffix (in view)

    final heightFtFieldFinder =
        find.byKey(const Key('settings_height_ft_field'));
    await _scrollToVisible(tester, heightFtFieldFinder);

    expect(find.text('lb'), findsOneWidget); // weight suffix
    expect(find.text('ft'), findsOneWidget); // height feet suffix
    expect(find.text('in'), findsOneWidget); // height inches suffix
    expect(heightFtFieldFinder, findsOneWidget);
    expect(find.byKey(const Key('settings_height_cm_field')), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 4. Party Mode gating
  // -------------------------------------------------------------------------

  testWidgets('Party Mode: no birthdate shows the no-birthdate info tile',
      (tester) async {
    final repo = _FakePreferencesRepo();
    final profile = _makeProfile(); // birthDate is null

    await tester.pumpWidget(
      _buildScreen(prefs: _makePrefs(), profile: profile, repo: repo),
    );
    await tester.pump();

    final noBirthdateFinder =
        find.byKey(const Key('settings_party_mode_no_birthdate'));
    await _scrollToVisible(tester, noBirthdateFinder);

    expect(noBirthdateFinder, findsOneWidget);
    expect(find.byKey(const Key('settings_party_mode_under_18')), findsNothing);
    expect(find.byKey(const Key('settings_bac_cap_field')), findsNothing);
  });

  testWidgets('Party Mode: under-18 birthdate shows the under-18 info tile',
      (tester) async {
    final repo = _FakePreferencesRepo();
    // 10 years ago — comfortably under 18, no leap-year boundary risk.
    final under18 = DateTime.now();
    final birthDate = _isoDate(
      DateTime(under18.year - 10, under18.month, under18.day),
    );
    final profile = _makeProfile(birthDate: birthDate);

    await tester.pumpWidget(
      _buildScreen(prefs: _makePrefs(), profile: profile, repo: repo),
    );
    await tester.pump();

    final under18Finder = find.byKey(const Key('settings_party_mode_under_18'));
    await _scrollToVisible(tester, under18Finder);

    expect(under18Finder, findsOneWidget);
    expect(
      find.byKey(const Key('settings_party_mode_no_birthdate')),
      findsNothing,
    );
    expect(find.byKey(const Key('settings_bac_cap_field')), findsNothing);
  });

  testWidgets(
      'Party Mode: 18+ birthdate shows the cap field, toggles, and legal '
      'limits info', (tester) async {
    final repo = _FakePreferencesRepo();
    // 30 years ago — comfortably 18+, no leap-year boundary risk.
    final now = DateTime.now();
    final birthDate = _isoDate(DateTime(now.year - 30, now.month, now.day));
    final profile = _makeProfile(birthDate: birthDate);

    await tester.pumpWidget(
      _buildScreen(prefs: _makePrefs(), profile: profile, repo: repo),
    );
    await tester.pump();

    final capFieldFinder = find.byKey(const Key('settings_bac_cap_field'));
    await _scrollToVisible(tester, capFieldFinder);
    expect(capFieldFinder, findsOneWidget);

    final legalLimitsFinder =
        find.byKey(const Key('settings_legal_limits_info'));
    await _scrollToVisible(tester, legalLimitsFinder);

    expect(
      find.byKey(const Key('settings_approaching_cap_switch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings_sober_estimate_switch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings_bac_lock_screen_switch')),
      findsOneWidget,
    );
    expect(legalLimitsFinder, findsOneWidget);
    expect(
      find.byKey(const Key('settings_party_mode_no_birthdate')),
      findsNothing,
    );
    expect(find.byKey(const Key('settings_party_mode_under_18')), findsNothing);
  });

  testWidgets(
      'Party Mode (18+): submitting the BAC cap field calls updateBacCap',
      (tester) async {
    final repo = _FakePreferencesRepo();
    final now = DateTime.now();
    final birthDate = _isoDate(DateTime(now.year - 30, now.month, now.day));
    final profile = _makeProfile(birthDate: birthDate);

    await tester.pumpWidget(
      _buildScreen(prefs: _makePrefs(), profile: profile, repo: repo),
    );
    await tester.pump();

    await _scrollToVisible(
        tester, find.byKey(const Key('settings_bac_cap_field')));
    await tester.enterText(
      find.byKey(const Key('settings_bac_cap_field')),
      '0.5',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(repo.bacCapCalled, isTrue);
    expect(repo.lastBacCap, closeTo(0.5, 0.001));
  });

  testWidgets(
      'Party Mode (18+): toggling the approaching-cap switch calls '
      'updatePartyModeSettings(approachingCapNotifEnabled: true)',
      (tester) async {
    final repo = _FakePreferencesRepo();
    final now = DateTime.now();
    final birthDate = _isoDate(DateTime(now.year - 30, now.month, now.day));
    final profile = _makeProfile(birthDate: birthDate);

    await tester.pumpWidget(
      _buildScreen(
        prefs: _makePrefs(approachingCapNotifEnabled: false),
        profile: profile,
        repo: repo,
      ),
    );
    await tester.pump();

    await _scrollToVisible(
        tester, find.byKey(const Key('settings_approaching_cap_switch')));
    await tester.tap(find.byKey(const Key('settings_approaching_cap_switch')));
    await tester.pump();

    expect(repo.partyModeCalls, hasLength(1));
    expect(repo.partyModeCalls.single.approachingCapNotifEnabled, isTrue);
  });

  // -------------------------------------------------------------------------
  // 5. Default-drink dropdown only offers non-alcoholic presets
  // -------------------------------------------------------------------------

  testWidgets('default-drink dropdown never lists an alcoholic preset by name',
      (tester) async {
    final repo = _FakePreferencesRepo();
    final presets = [
      _preset(
          id: 'w1', name: 'Sparkling Water', beverageType: BeverageType.water),
      _preset(id: 'b1', name: 'House Lager', beverageType: BeverageType.beer),
    ];

    await tester.pumpWidget(
      _buildScreen(prefs: _makePrefs(), repo: repo, presets: presets),
    );
    await tester.pump();

    // Not visible collapsed (hint text shown, no default preset selected).
    expect(find.text('House Lager'), findsNothing);

    // Open the dropdown menu and check the full item list.
    await _scrollToVisible(
        tester, find.byKey(const Key('settings_default_drink_dropdown')));
    await tester.tap(find.byKey(const Key('settings_default_drink_dropdown')));
    await tester.pumpAndSettle();

    expect(
      find.text('House Lager'),
      findsNothing,
      reason: 'visibleNonAlcoholicPresetsProvider must filter out alcoholic '
          'presets (data-model.md / features.md F6: default-drink picker is '
          'non-alcoholic only)',
    );
    expect(find.text('Sparkling Water'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Tapping "Manage drinks" pushes ManageDrinksScreen
  // -------------------------------------------------------------------------

  testWidgets('tapping "Manage drinks" pushes ManageDrinksScreen',
      (tester) async {
    final repo = _FakePreferencesRepo();
    await tester.pumpWidget(_buildScreen(prefs: _makePrefs(), repo: repo));
    await tester.pump();

    await _scrollToVisible(
        tester, find.byKey(const Key('settings_manage_drinks_tile')));
    await tester.tap(find.byKey(const Key('settings_manage_drinks_tile')));
    await tester.pumpAndSettle();

    expect(find.byType(ManageDrinksScreen), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 7. "Always show alcoholic drinks" toggle
  // -------------------------------------------------------------------------

  testWidgets(
      'toggling "Always show alcoholic drinks" off calls '
      'updateAlcoholicPresetsAlwaysVisible(false)', (tester) async {
    final repo = _FakePreferencesRepo();
    await tester.pumpWidget(
      _buildScreen(
        prefs: _makePrefs(alcoholicPresetsAlwaysVisible: true),
        repo: repo,
      ),
    );
    await tester.pump();

    final switchFinder = find.byKey(
      const Key('settings_alcoholic_presets_always_visible_switch'),
    );
    await _scrollToVisible(tester, switchFinder);
    await tester.tap(switchFinder);
    await tester.pump();

    expect(repo.lastAlcoholicPresetsAlwaysVisible, isFalse);
  });
}
