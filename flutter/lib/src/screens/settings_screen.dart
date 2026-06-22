import 'package:flutter/material.dart';

/// Settings tab placeholder — S4 Settings screen lands here in a later issue.
///
/// Note: the design spec (user-experience.md, designer-brief.md) reaches
/// Settings via a gear icon in the page header rather than a bottom-nav tab.
/// Issue #1 explicitly scaffolds Settings as a 4th tab for the shell; the
/// navigation model will be reconciled when S4 Settings is implemented.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.settings_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'App settings coming soon.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
