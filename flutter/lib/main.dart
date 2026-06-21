import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: DrinksMateApp()));
}

/// Phase 1 app shell. Screens (Today, History, Party, Settings) and the design
/// system land on top of this — see design/ and engineering/decisions/.
class DrinksMateApp extends StatelessWidget {
  const DrinksMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drinks Mate',
      theme: ThemeData(useMaterial3: true),
      home: const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Drinks Mate')),
    );
  }
}
