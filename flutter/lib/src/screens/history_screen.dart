import 'package:flutter/material.dart';

import 'settings_screen.dart';

/// History tab placeholder — chart history feature lands here in a later issue.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [_settingsButton(context)],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('History', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'Past intake and sessions coming soon.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _settingsButton(BuildContext context) => IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Settings',
      onPressed: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      ),
    );
