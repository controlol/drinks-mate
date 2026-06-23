import 'package:core/core.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/user_profile.dart';
import 'package:drinks_mate/src/repository/preferences_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:drinks_mate/src/screens/onboarding/onboarding_flow.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _memDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

Widget _wrap(Widget child, PreferencesRepository repo) {
  return ProviderScope(
    overrides: [preferencesRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(home: child),
  );
}

UserProfile _profile(DateTime now) => UserProfile(
      id: 'test-profile-id',
      weightKg: 70.0,
      createdAt: now,
      updatedAt: now,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('OnboardingFlow — navigation', () {
    testWidgets('step 1 shows welcome copy and CTA', (tester) async {
      final db = _memDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        _wrap(const OnboardingFlow(), PreferencesRepository(db)),
      );
      await tester.pump();

      expect(find.text('Welcome to Drinks Mate'), findsOneWidget);
      expect(find.text("Let's start"), findsOneWidget);
    });

    testWidgets("tapping Let's start advances to username step", (
      tester,
    ) async {
      final db = _memDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        _wrap(const OnboardingFlow(), PreferencesRepository(db)),
      );
      await tester.pump();

      await tester.tap(find.text("Let's start"));
      await tester.pumpAndSettle();

      expect(find.text('Choose a username'), findsOneWidget);
    });

    testWidgets('Next is disabled on username step when field is empty', (
      tester,
    ) async {
      final db = _memDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        _wrap(const OnboardingFlow(), PreferencesRepository(db)),
      );
      await tester.pump();

      await tester.tap(find.text("Let's start"));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('onboarding_cta_next')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Next is enabled after entering a valid username', (
      tester,
    ) async {
      final db = _memDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        _wrap(const OnboardingFlow(), PreferencesRepository(db)),
      );
      await tester.pump();

      await tester.tap(find.text("Let's start"));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('onboarding_username_field')),
        'Alice',
      );
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('onboarding_cta_next')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('username with fewer than 3 chars keeps Next disabled', (
      tester,
    ) async {
      final db = _memDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        _wrap(const OnboardingFlow(), PreferencesRepository(db)),
      );
      await tester.pump();

      await tester.tap(find.text("Let's start"));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('onboarding_username_field')),
        'ab',
      );
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('onboarding_cta_next')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('can navigate through all 5 steps', (tester) async {
      final db = _memDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        _wrap(const OnboardingFlow(), PreferencesRepository(db)),
      );
      await tester.pump();

      // Step 1 → 2
      await tester.tap(find.text("Let's start"));
      await tester.pumpAndSettle();
      expect(find.text('Choose a username'), findsOneWidget);

      // Step 2 → 3
      await tester.enterText(
        find.byKey(const Key('onboarding_username_field')),
        'Alice',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('onboarding_cta_next')));
      await tester.pumpAndSettle();
      expect(find.text('About you'), findsOneWidget);

      // Step 3 → 4
      await tester.tap(find.byKey(const Key('onboarding_cta_next')));
      await tester.pumpAndSettle();
      expect(find.text('Your daily goal'), findsOneWidget);

      // Step 4 → 5
      await tester.tap(find.byKey(const Key('onboarding_cta_next')));
      await tester.pumpAndSettle();
      expect(find.text('Stay on track'), findsOneWidget);

      expect(find.byKey(const Key('onboarding_cta_done')), findsOneWidget);
    });
  });

  group('OnboardingFlow — data persistence', () {
    testWidgets('writes username to preferences on Done', (tester) async {
      final db = _memDb();
      addTearDown(db.close);
      final repo = PreferencesRepository(db);

      await tester.pumpWidget(_wrap(const OnboardingFlow(), repo));
      await tester.pump();

      await tester.tap(find.text("Let's start"));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('onboarding_username_field')),
        'Alice',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('onboarding_cta_next')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_cta_next')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_cta_next')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_cta_done')));
      await tester.pumpAndSettle();

      final prefs = await repo.getPreferences();
      expect(prefs.username, 'Alice');
    });

    // §S5: "a user who taps 'next' through the whole thing ends up with weight
    // 70 kg … daily goal 2100 ml". Weight defaults to 70, goal defaults to
    // dailyGoalMl(70) = 2100 — verify the tap-through path persists 2100.
    testWidgets(
      'tap-through defaults persist 2100 ml goal (§S5 spec example)',
      (tester) async {
        final db = _memDb();
        addTearDown(db.close);
        final repo = PreferencesRepository(db);

        await tester.pumpWidget(_wrap(const OnboardingFlow(), repo));
        await tester.pump();

        await tester.tap(find.text("Let's start"));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('onboarding_username_field')),
          'TapThrough',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('onboarding_cta_next')));
        await tester.pumpAndSettle();

        // Accept default weight (70 kg) — no change needed.
        await tester.tap(find.byKey(const Key('onboarding_cta_next')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_cta_next')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_cta_done')));
        await tester.pumpAndSettle();

        final prefs = await repo.getPreferences();
        expect(prefs.dailyGoalMl, 2100);
      },
    );

    // Parity Rulebook §hydration: dailyGoalMl = round_to_nearest(30 × kg, 100).
    // 70 kg → 30×70 = 2100 → rounds to 2100.
    testWidgets(
      '70 kg weight yields 2100 ml daily goal (Parity Rulebook §hydration)',
      (tester) async {
        final db = _memDb();
        addTearDown(db.close);
        final repo = PreferencesRepository(db);

        await tester.pumpWidget(_wrap(const OnboardingFlow(), repo));
        await tester.pump();

        await tester.tap(find.text("Let's start"));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('onboarding_username_field')),
          'Bob',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('onboarding_cta_next')));
        await tester.pumpAndSettle();

        // Enter 70 kg in the personal-info step.
        await tester.enterText(
          find.byKey(const Key('onboarding_weight_field')),
          '70',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('onboarding_cta_next')));
        await tester.pumpAndSettle();

        // Goal field must now show 2100 (computed by core, not ad-hoc).
        final goalField = tester.widget<TextField>(
          find.byKey(const Key('onboarding_goal_field')),
        );
        expect(goalField.controller!.text, '2100');

        await tester.tap(find.byKey(const Key('onboarding_cta_next')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_cta_done')));
        await tester.pumpAndSettle();

        final prefs = await repo.getPreferences();
        expect(prefs.dailyGoalMl, 2100);
      },
    );

    testWidgets('user-adjusted goal overrides the computed value', (
      tester,
    ) async {
      final db = _memDb();
      addTearDown(db.close);
      final repo = PreferencesRepository(db);

      await tester.pumpWidget(_wrap(const OnboardingFlow(), repo));
      await tester.pump();

      await tester.tap(find.text("Let's start"));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('onboarding_username_field')),
        'Carol',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('onboarding_cta_next')));
      await tester.pumpAndSettle();

      // 70 kg suggests 2100, but user adjusts to 2500.
      await tester.enterText(
        find.byKey(const Key('onboarding_weight_field')),
        '70',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('onboarding_cta_next')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('onboarding_goal_field')),
        '2500',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('onboarding_cta_next')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_cta_done')));
      await tester.pumpAndSettle();

      final prefs = await repo.getPreferences();
      expect(prefs.dailyGoalMl, 2500);
    });

    // Regression: clearing the goal field must fall back to weight-derived goal,
    // not the hardcoded 70 kg default. 65 kg → 2000, not 2100.
    testWidgets(
      'cleared goal field falls back to weight-derived goal (P1 regression)',
      (tester) async {
        final db = _memDb();
        addTearDown(db.close);
        final repo = PreferencesRepository(db);

        await tester.pumpWidget(_wrap(const OnboardingFlow(), repo));
        await tester.pump();

        await tester.tap(find.text("Let's start"));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('onboarding_username_field')),
          'Reg',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('onboarding_cta_next')));
        await tester.pumpAndSettle();

        // Enter 65 kg — goal field updates to 2000 via _syncGoalFromWeight.
        await tester.enterText(
          find.byKey(const Key('onboarding_weight_field')),
          '65',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('onboarding_cta_next')));
        await tester.pumpAndSettle();

        // Clear the goal field — fallback must use the 65 kg weight, not 70 kg.
        await tester.enterText(
          find.byKey(const Key('onboarding_goal_field')),
          '',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('onboarding_cta_next')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('onboarding_cta_done')));
        await tester.pumpAndSettle();

        final prefs = await repo.getPreferences();
        expect(prefs.dailyGoalMl, 2000);
      },
    );

    testWidgets('profile row is created with entered weight', (tester) async {
      final db = _memDb();
      addTearDown(db.close);
      final repo = PreferencesRepository(db);

      await tester.pumpWidget(_wrap(const OnboardingFlow(), repo));
      await tester.pump();

      await tester.tap(find.text("Let's start"));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('onboarding_username_field')),
        'Dana',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('onboarding_cta_next')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('onboarding_weight_field')),
        '65',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('onboarding_cta_next')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_cta_next')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_cta_done')));
      await tester.pumpAndSettle();

      final profile = await repo.getProfile();
      expect(profile, isNotNull);
      expect(profile!.weightKg, 65.0);
    });
  });

  group('PreferencesRepository — completeOnboarding', () {
    test('writes username, goal, and profile atomically', () async {
      final db = _memDb();
      addTearDown(db.close);
      final repo = PreferencesRepository(db);
      final now = DateTime.now().toUtc();

      await repo.completeOnboarding(
        username: 'Eve',
        profile: _profile(now),
        dailyGoalMl: 2100,
      );

      final prefs = await repo.getPreferences();
      expect(prefs.username, 'Eve');
      expect(prefs.dailyGoalMl, 2100);

      final profile = await repo.getProfile();
      expect(profile, isNotNull);
      expect(profile!.weightKg, 70.0);
    });

    test('rejects username that is too short', () async {
      final db = _memDb();
      addTearDown(db.close);
      final repo = PreferencesRepository(db);
      final now = DateTime.now().toUtc();

      expect(
        () => repo.completeOnboarding(
          username: 'ab',
          profile: _profile(now),
          dailyGoalMl: 2000,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('leaves prefs unchanged when username is invalid', () async {
      final db = _memDb();
      addTearDown(db.close);
      final repo = PreferencesRepository(db);
      final now = DateTime.now().toUtc();

      try {
        await repo.completeOnboarding(
          username: 'ab',
          profile: _profile(now),
          dailyGoalMl: 9999,
        );
      } catch (_) {}

      final prefs = await repo.getPreferences();
      expect(prefs.username, isNull);
      expect(prefs.dailyGoalMl, 2000); // seeded placeholder unchanged
    });

    // Parity Rulebook §hydration: 65 kg → 30×65 = 1950 → rounds to 2000.
    test('65 kg weight → 2000 ml goal (boundary round-half-up)', () async {
      final db = _memDb();
      addTearDown(db.close);
      final repo = PreferencesRepository(db);
      final now = DateTime.now().toUtc();

      final profile = UserProfile(
        id: 'test-65kg',
        weightKg: 65.0,
        createdAt: now,
        updatedAt: now,
      );

      await repo.completeOnboarding(
        username: 'Frank',
        profile: profile,
        dailyGoalMl: dailyGoalMl(65.0),
      );

      final prefs = await repo.getPreferences();
      expect(prefs.dailyGoalMl, 2000);
    });
  });
}
