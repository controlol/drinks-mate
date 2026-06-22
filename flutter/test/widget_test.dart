import 'package:drift/native.dart';
import 'package:drinks_mate/app.dart';
import 'package:drinks_mate/src/db/app_database.dart';
import 'package:drinks_mate/src/models/drink_preset.dart';
import 'package:drinks_mate/src/repository/drinks_repository.dart';
import 'package:drinks_mate/src/repository/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build a test app where every Drift stream query is replaced by a static
/// value. This avoids the pending-timer assertion that Flutter's test binding
/// raises when a Drift QueryStream is cancelled during widget disposal.
///
/// [drinksRepositoryProvider] is still overridden with a real in-memory DB so
/// that [logDrink] calls work without touching the file system.
Widget _appWithFakeStreams() {
  final db = AppDatabase(NativeDatabase.memory());
  return ProviderScope(
    overrides: [
      // Repository uses an in-memory DB — no file system needed.
      drinksRepositoryProvider.overrideWithValue(DrinksRepository(db)),
      // Override the stream providers so Drift's QueryStream is never started,
      // and therefore its cleanup timer never fires mid-teardown.
      visiblePresetsProvider
          .overrideWith((_) => Stream.value(const <DrinkPreset>[])),
      todayTotalMlProvider.overrideWith((_) => Stream.value(0)),
    ],
    child: const DrinksMateApp(),
  );
}

void main() {
  testWidgets('app shell renders with 3-tab NavigationBar', (tester) async {
    await tester.pumpWidget(_appWithFakeStreams());
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
  });

  testWidgets('all 3 tab labels are visible', (tester) async {
    await tester.pumpWidget(_appWithFakeStreams());
    final navBar = find.byType(NavigationBar);
    for (final label in ['Today', 'Party', 'History']) {
      expect(
        find.descendant(of: navBar, matching: find.text(label)),
        findsOneWidget,
        reason: '$label tab label not found in NavigationBar',
      );
    }
  });

  testWidgets('Today screen shows intake card and Log drink button',
      (tester) async {
    await tester.pumpWidget(_appWithFakeStreams());
    await tester.pump(); // let StreamProvider emit the first value
    expect(find.text("Today's intake"), findsOneWidget);
    expect(find.text('Log drink'), findsOneWidget);
  });

  testWidgets('tapping History tab switches screen', (tester) async {
    await tester.pumpWidget(_appWithFakeStreams());

    // Today screen is initially visible.
    expect(find.text("Today's intake"), findsOneWidget);

    // Tap the History tab.
    final navBar = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: navBar, matching: find.text('History')),
    );
    await tester.pumpAndSettle();

    // History placeholder visible; Today content gone.
    expect(find.text('Past intake and sessions coming soon.'), findsOneWidget);
    expect(find.text("Today's intake"), findsNothing);
  });

  testWidgets('tapping Party tab switches screen', (tester) async {
    await tester.pumpWidget(_appWithFakeStreams());

    final navBar = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: navBar, matching: find.text('Party')));
    await tester.pumpAndSettle();

    expect(find.text('Party Session feature coming soon.'), findsOneWidget);
  });

  testWidgets('gear icon navigates to Settings full-screen', (tester) async {
    await tester.pumpWidget(_appWithFakeStreams());

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('App settings coming soon.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
