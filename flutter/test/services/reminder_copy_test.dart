import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/services/reminder_copy.dart';

// ---------------------------------------------------------------------------
// FixedRandom — a controllable dart:math Random for deterministic template
// selection. `Random` is abstract (only the factory constructors are
// external), so implementing it directly lets every index of a copy set be
// exercised without depending on a specific PRNG sequence/seed, which could
// change across Dart SDK versions.
// ---------------------------------------------------------------------------
class FixedRandom implements Random {
  FixedRandom(this.value);
  final int value;

  @override
  int nextInt(int max) => value;

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  bool nextBool() => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Copy sets copied verbatim from notifications.md §Notification copy — these
// are the source of truth the implementation's private template lists must
// match. Kept local to the test (the implementation's lists are private to
// reminder_copy.dart) so a change to either drifts the test, not silently
// freezes a bug.
//
// The weekly-summary general-set lines are reproduced WITHOUT the doc's `**`
// markdown bold markers around `{x}/7` — reminder_copy.dart deliberately
// drops markdown ("plain notification bodies don't render markdown"), a
// phase-1 rendering choice documented in the implementation, not a Parity
// Rulebook rule.
// ---------------------------------------------------------------------------
const List<String> _onPaceTemplates = [
  'Time for {n} of water 💧',
  'Quick hydration check — how about {n}?',
  'Staying steady. {n} of water now.',
  '{n} of water keeps you on pace.',
  "You're doing well — keep it up with {n}.",
  'A little break for {n} of water 💧',
];

const List<String> _offPaceTemplates = [
  'Looks like the last one slipped by — {n} of water now? 💧',
  'Catching up: {n} of water gets you back on pace.',
  "It's been a while. {n} of water 💧",
  "No worries — let's pick it back up with {n} of water.",
];

const List<String> _inactivityTemplates = [
  "Hey, did you forget to log? Tap to add what you've had today.",
  "We haven't seen anything from you yet today — log a drink?",
  "Quick check-in: how's hydration looking today?",
];

const List<String> _weeklySummaryGeneralTemplates = [
  "Last week you hit your goal {x}/7 days. Nice work, here's to another good week 💧",
  "Last week's hydration: {x}/7 days at goal. Tap to see the chart.",
];

const String _weeklySummaryZero =
    'A slow week — every day is a fresh start. Tap to see your chart.';
const String _weeklySummarySeven = 'Perfect week: 7/7 days at goal 💧 nice.';

void main() {
  // -------------------------------------------------------------------------
  // beverageNoun
  // -------------------------------------------------------------------------
  group('beverageNoun (notifications.md §Glass formatting)', () {
    test('water → "water"', () {
      expect(beverageNoun(BeverageType.water), 'water');
    });

    test('coffee → "coffee"', () {
      expect(beverageNoun(BeverageType.coffee), 'coffee');
    });

    test('tea → "tea"', () {
      expect(beverageNoun(BeverageType.tea), 'tea');
    });

    test('alcoholic types never crash (never actually the default drink)', () {
      // data-model.md §UserPreferences: defaultDrinkPresetId must reference a
      // non-alcoholic preset, so these branches are unreachable in practice —
      // included here only for switch exhaustiveness / to guard against a
      // future crash if that invariant is ever violated.
      for (final type in [
        BeverageType.beer,
        BeverageType.wine,
        BeverageType.spirit,
        BeverageType.cocktail,
        BeverageType.otherAlcohol,
      ]) {
        expect(beverageNoun(type), isNotEmpty);
      }
    });
  });

  // -------------------------------------------------------------------------
  // hydrationReminderBody
  // -------------------------------------------------------------------------
  group('hydrationReminderBody (notifications.md §On-pace/Off-pace sets)', () {
    test(
      'on-pace set (missedPrevious=false): every index selects the matching '
      'template with {n} substituted correctly',
      () {
        const glasses = 1.5; // formatGlassCount(1.5) == "1.5 glasses"
        for (var i = 0; i < _onPaceTemplates.length; i++) {
          final body = hydrationReminderBody(
            glasses: glasses,
            beverageType: BeverageType.water,
            missedPrevious: false,
            random: FixedRandom(i),
          );
          final expected = _onPaceTemplates[i].replaceAll(
            '{n}',
            '1.5 glasses',
          );
          expect(body, expected);
        }
      },
    );

    test(
      'off-pace set (missedPrevious=true): every index selects the matching '
      'template with {n} substituted correctly',
      () {
        const glasses = 0.5; // formatGlassCount(0.5) == "half a glass"
        for (var i = 0; i < _offPaceTemplates.length; i++) {
          final body = hydrationReminderBody(
            glasses: glasses,
            beverageType: BeverageType.water,
            missedPrevious: true,
            random: FixedRandom(i),
          );
          final expected = _offPaceTemplates[i].replaceAll(
            '{n}',
            'half a glass',
          );
          expect(body, expected);
        }
      },
    );

    test(
      'body is always a member of the known copy set (membership check, '
      'independent of PRNG sequence)',
      () {
        final expectedOnPace =
            _onPaceTemplates.map((t) => t.replaceAll('{n}', 'a glass')).toSet();
        for (var i = 0; i < _onPaceTemplates.length; i++) {
          final body = hydrationReminderBody(
            glasses: 1.0,
            beverageType: BeverageType.water,
            missedPrevious: false,
            random: FixedRandom(i),
          );
          expect(expectedOnPace, contains(body));
        }
      },
    );

    test(
      'tea beverage type: "of water" → "of tea", 💧 emoji dropped',
      () {
        // Template index 0 on-pace: "Time for {n} of water 💧".
        final body = hydrationReminderBody(
          glasses: 1.0,
          beverageType: BeverageType.tea,
          missedPrevious: false,
          random: FixedRandom(0),
        );
        expect(body, contains('of tea'));
        expect(body, isNot(contains('of water')));
        expect(body, isNot(contains('💧')));
      },
    );

    test(
      'water beverage type: 💧 emoji IS preserved',
      () {
        final body = hydrationReminderBody(
          glasses: 1.0,
          beverageType: BeverageType.water,
          missedPrevious: false,
          random: FixedRandom(0),
        );
        expect(body, contains('of water'));
        expect(body, contains('💧'));
      },
    );

    test(
      'coffee beverage type: "of water" → "of coffee" on an off-pace template',
      () {
        // Off-pace template index 2: "It's been a while. {n} of water 💧"
        final body = hydrationReminderBody(
          glasses: 2.0,
          beverageType: BeverageType.coffee,
          missedPrevious: true,
          random: FixedRandom(2),
        );
        expect(body, contains('of coffee'));
        expect(body, isNot(contains('of water')));
        expect(body, isNot(contains('💧')));
      },
    );
  });

  // -------------------------------------------------------------------------
  // inactivityReminderBody
  // -------------------------------------------------------------------------
  group('inactivityReminderBody (notifications.md §Inactivity reminder)', () {
    test('every index returns one of the exact 3 known lines', () {
      for (var i = 0; i < _inactivityTemplates.length; i++) {
        final body = inactivityReminderBody(random: FixedRandom(i));
        expect(body, _inactivityTemplates[i]);
      }
    });

    test('body is always a member of the known set', () {
      for (var i = 0; i < _inactivityTemplates.length; i++) {
        final body = inactivityReminderBody(random: FixedRandom(i));
        expect(_inactivityTemplates, contains(body));
      }
    });
  });

  // -------------------------------------------------------------------------
  // weeklySummaryBody
  // -------------------------------------------------------------------------
  group('weeklySummaryBody (notifications.md §Weekly summary)', () {
    test('daysAtGoal=0 → exact fixed "slow week" string', () {
      expect(weeklySummaryBody(0), _weeklySummaryZero);
    });

    test('daysAtGoal=7 → exact fixed "perfect week" string', () {
      expect(weeklySummaryBody(7), _weeklySummarySeven);
    });

    test(
      'daysAtGoal=3 (general range): one of the two general templates with '
      '{x} substituted, no markdown bold markers',
      () {
        for (var i = 0; i < _weeklySummaryGeneralTemplates.length; i++) {
          final body = weeklySummaryBody(3, random: FixedRandom(i));
          final expected = _weeklySummaryGeneralTemplates[i].replaceAll(
            '{x}',
            '3',
          );
          expect(body, expected);
          expect(body, isNot(contains('**')));
        }
      },
    );

    test('boundary: daysAtGoal=1 (adjacent to the 0/7 fixed extreme)', () {
      for (var i = 0; i < _weeklySummaryGeneralTemplates.length; i++) {
        final body = weeklySummaryBody(1, random: FixedRandom(i));
        final expected = _weeklySummaryGeneralTemplates[i].replaceAll(
          '{x}',
          '1',
        );
        expect(body, expected);
        expect(body, isNot(contains('**')));
      }
    });

    test('boundary: daysAtGoal=6 (adjacent to the 7/7 fixed extreme)', () {
      for (var i = 0; i < _weeklySummaryGeneralTemplates.length; i++) {
        final body = weeklySummaryBody(6, random: FixedRandom(i));
        final expected = _weeklySummaryGeneralTemplates[i].replaceAll(
          '{x}',
          '6',
        );
        expect(body, expected);
        expect(body, isNot(contains('**')));
      }
    });
  });
}
