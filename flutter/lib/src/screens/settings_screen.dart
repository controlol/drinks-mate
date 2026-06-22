import 'package:flutter/material.dart';

/// Settings placeholder — S4 Settings screen lands here in a later issue.
///
/// Reached by tapping the gear icon in the header of any top-level tab screen
/// (per user-experience.md S4). Presented as a full-screen push; the bottom
/// tab bar is hidden because the Navigator route covers AppShell entirely.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
