import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drink_preset.dart';
import '../repository/providers.dart';
import '../utils/color_utils.dart';
import 'log_drink_sheet.dart';
import 'settings_screen.dart';

/// Today tab — hydration tracking (issue #2, F1 + F3 minimal slice).
///
/// Shows today's total intake and lets the user log a drink in ≤ 2 taps:
///   1 tap  — quick-log tile on this screen → logged immediately.
///   2 taps — "Log drink" button → S2 sheet → pick preset (already on screen,
///            so confirm = 3rd tap; full-drawer path is allowed per spec).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [_settingsButton(context)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TotalCard(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Quick log',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          _QuickLogRow(),
          const Spacer(),
          _LogDrinkButton(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today total card
// ---------------------------------------------------------------------------

class _TotalCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(todayTotalMlProvider);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's intake",
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            totalAsync.when(
              loading: () => Text(
                '— ml',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              error: (_, __) => Text(
                'Error',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              data: (ml) => Text(
                _formatIntake(ml),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats an intake value for display: ml below 1000, litres above.
String _formatIntake(int ml) {
  if (ml < 1000) return '$ml ml';
  final litres = ml / 1000;
  final formatted = litres == litres.truncateToDouble()
      ? '${litres.toInt()} L'
      : '${litres.toStringAsFixed(1)} L';
  return formatted;
}

// ---------------------------------------------------------------------------
// Quick-log row
// ---------------------------------------------------------------------------

class _QuickLogRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(visiblePresetsProvider);
    return SizedBox(
      height: 96,
      child: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (presets) {
          // Show the first 5 presets as quick-log shortcuts (seeded defaults
          // until usage-frequency sorting lands in a later issue).
          final shown = presets.take(5).toList();
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _QuickLogTile(preset: shown[i]),
          );
        },
      ),
    );
  }
}

class _QuickLogTile extends ConsumerWidget {
  const _QuickLogTile({required this.preset});

  final DrinkPreset preset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _quickLog(context, ref),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_drink_outlined,
              size: 28,
              color: parseIconColor(preset.iconColor),
            ),
            const SizedBox(height: 4),
            Text(
              preset.name,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickLog(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(drinksRepositoryProvider).logDrink(preset: preset);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged ${preset.name}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to log drink')));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Log drink button
// ---------------------------------------------------------------------------

class _LogDrinkButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: FilledButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('Log drink'),
        onPressed: () => _openSheet(context),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const LogDrinkSheet(),
    );
    if (logged == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Drink logged'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _settingsButton(BuildContext context) => IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Settings',
      onPressed: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      ),
    );
