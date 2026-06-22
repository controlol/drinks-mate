import 'package:flutter/material.dart';

import 'src/navigation/shell.dart';
import 'src/theme/app_theme.dart';

/// Root application widget.
///
/// Wrapped in [ProviderScope] by [main]. Configures the Material 3 theme
/// (light + dark) from design-system tokens and mounts the [AppShell].
class DrinksMateApp extends StatelessWidget {
  const DrinksMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drinks Mate',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
