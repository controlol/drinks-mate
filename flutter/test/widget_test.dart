import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinks_mate/main.dart';

void main() {
  testWidgets('app shell renders', (tester) async {
    await tester.pumpWidget(const DrinksMateApp());
    expect(find.text('Drinks Mate'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
