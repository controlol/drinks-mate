/// Notification copy for the three hydration-related reminder types.
///
/// Source: notifications.md §Notification copy, §Glass formatting. Copy sets
/// are copied verbatim from the design doc; only variable substitution and
/// emoji-dropping (for non-water default drinks) are implemented here.
library;

import 'dart:math';

import 'package:core/core.dart';

import '../models/beverage_type.dart';

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

const List<String> _weeklySummaryTemplates = [
  "Last week you hit your goal {x}/7 days. Nice work, here's to another good week 💧",
  "Last week's hydration: {x}/7 days at goal. Tap to see the chart.",
];

/// The beverage noun used in reminder copy ("of water" / "of tea" / …),
/// never the preset display name.
///
/// Source: notifications.md §Glass formatting.
String beverageNoun(BeverageType type) => switch (type) {
      BeverageType.water => 'water',
      BeverageType.coffee => 'coffee',
      BeverageType.tea => 'tea',
      BeverageType.juice => 'juice',
      BeverageType.softDrink => 'soda',
      BeverageType.milk => 'milk',
      BeverageType.nonAlcoholicBeer => 'non-alcoholic beer',
      BeverageType.other => 'your drink',
      // Alcoholic types are never the default drink (data-model.md
      // §UserPreferences: defaultDrinkPresetId must reference a
      // non-alcoholic preset); included only for switch exhaustiveness.
      BeverageType.beer ||
      BeverageType.wine ||
      BeverageType.spirit ||
      BeverageType.cocktail ||
      BeverageType.otherAlcohol =>
        'your drink',
    };

/// Builds the hydration reminder body: picks a random line from the on-pace
/// or off-pace set, substitutes the glass phrase, and adapts the beverage
/// noun (dropping the water-drop emoji for non-water drinks).
///
/// [missedPrevious] selects the copy set — see notifications.md §Notification
/// types → Hydration reminder. Injected [random] enables deterministic tests.
String hydrationReminderBody({
  required double glasses,
  required BeverageType beverageType,
  required bool missedPrevious,
  Random? random,
}) {
  final templates = missedPrevious ? _offPaceTemplates : _onPaceTemplates;
  final rng = random ?? Random();
  final template = templates[rng.nextInt(templates.length)];
  final phrase = formatGlassCount(glasses);
  var body = template.replaceAll('{n}', phrase);

  final noun = beverageNoun(beverageType);
  if (noun != 'water') {
    body = body.replaceAll('of water', 'of $noun').replaceAll(' 💧', '').trim();
  }
  return body;
}

/// Builds the once-daily inactivity reminder body (random line, no variables).
String inactivityReminderBody({Random? random}) {
  final rng = random ?? Random();
  return _inactivityTemplates[rng.nextInt(_inactivityTemplates.length)];
}

/// Builds the weekly-summary body from [daysAtGoal] (0–7 inclusive).
///
/// 0/7 and 7/7 use their fixed extreme-case lines; 1–6/7 pick randomly from
/// the general set. Markdown bold markers from the design doc are stripped —
/// plain notification bodies don't render markdown.
///
/// Source: notifications.md §Notification copy → Weekly summary.
String weeklySummaryBody(int daysAtGoal, {Random? random}) {
  assert(daysAtGoal >= 0 && daysAtGoal <= 7, 'daysAtGoal must be 0-7');
  if (daysAtGoal == 0) {
    return 'A slow week — every day is a fresh start. Tap to see your chart.';
  }
  if (daysAtGoal == 7) {
    return 'Perfect week: 7/7 days at goal 💧 nice.';
  }
  final rng = random ?? Random();
  final template =
      _weeklySummaryTemplates[rng.nextInt(_weeklySummaryTemplates.length)];
  return template.replaceAll('{x}', '$daysAtGoal');
}
