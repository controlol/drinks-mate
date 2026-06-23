import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/navigation/shell.dart';
import 'src/repository/providers.dart';
import 'src/screens/onboarding/onboarding_flow.dart';
import 'src/theme/app_theme.dart';

/// Root application widget.
///
/// Wrapped in [ProviderScope] by [main]. Configures the Material 3 theme
/// (light + dark) from design-system tokens and mounts [_AppGate].
class DrinksMateApp extends StatelessWidget {
  const DrinksMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drinks Mate',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _AppGate(),
    );
  }
}

/// Routes to [OnboardingFlow] until the user sets a username, then [AppShell].
///
/// Gates on [UserPreferences.username] — null means onboarding has not been
/// completed. The gate reacts reactively: once [completeOnboarding] writes the
/// username, [userPreferencesProvider] emits a new value and [AppShell] is
/// shown automatically without any manual navigation.
class _AppGate extends ConsumerWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(userPreferencesProvider);
    return prefsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(
          child: Text('Could not load preferences. Please restart the app.'),
        ),
      ),
      data: (prefs) =>
          prefs.username == null ? const OnboardingFlow() : const AppShell(),
    );
  }
}
