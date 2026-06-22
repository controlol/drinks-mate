import 'package:drinks_mate/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell renders with 3-tab NavigationBar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DrinksMateApp()));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
  });

  testWidgets('all 3 tab labels are visible', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DrinksMateApp()));
    final navBar = find.byType(NavigationBar);
    for (final label in ['Today', 'Party', 'History']) {
      expect(
        find.descendant(of: navBar, matching: find.text(label)),
        findsOneWidget,
        reason: '$label tab label not found in NavigationBar',
      );
    }
  });

  testWidgets('tapping History tab switches screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DrinksMateApp()));

    // Today screen is initially visible.
    expect(find.text('Hydration tracking coming soon.'), findsOneWidget);

    // Tap the History tab in the NavigationBar.
    final navBar = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: navBar, matching: find.text('History')),
    );
    await tester.pumpAndSettle();

    // History placeholder is now visible; Today placeholder is gone.
    expect(find.text('Past intake and sessions coming soon.'), findsOneWidget);
    expect(find.text('Hydration tracking coming soon.'), findsNothing);
  });

  testWidgets('tapping Party tab switches screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DrinksMateApp()));

    final navBar = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: navBar, matching: find.text('Party')));
    await tester.pumpAndSettle();

    expect(find.text('Party Session feature coming soon.'), findsOneWidget);
  });

  testWidgets('gear icon navigates to Settings full-screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DrinksMateApp()));

    // Tap the settings gear icon in the Today tab header.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    // Settings screen is pushed; tab bar is hidden (Navigator covers AppShell).
    expect(find.text('App settings coming soon.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
