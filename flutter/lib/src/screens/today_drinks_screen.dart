import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../a11y/semantics_labels.dart';
import '../models/drink_entry.dart';
import '../models/user_preferences.dart';
import '../repository/providers.dart';
import '../services/format_service.dart';
import '../utils/color_utils.dart';
import '../widgets/entry_edit_sheet.dart';
import 'log_drink_sheet.dart';

/// S6 — Today Drinks Log.
///
/// Reached by tapping the progress card on the Today screen. Shows every
/// beverage type logged today in reverse-chronological order, with
/// per-entry edit and soft-delete actions — except an alcoholic entry
/// attached to a Party Session (`partySessionId` set), which renders
/// read-only here; [S9 Party Session Log] is the authoritative place to edit
/// or delete those (design/user-experience.md §S6).
///
/// Editable fields: volume, ABV (alcoholic entries only), price, and time —
/// name is not exposed here (unlike [S3 History day drill-down]); see
/// [EntryEditSheet] for the shared edit-sheet implementation.
class TodayDrinksScreen extends ConsumerWidget {
  const TodayDrinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(todayEntriesProvider);
    final prefsAsync = ref.watch(userPreferencesProvider);
    final fmt = ref.watch(formatServiceProvider);

    final prefs = prefsAsync.valueOrNull;
    final totalMlAsync = ref.watch(todayTotalMlProvider);
    final totalMl = totalMlAsync.valueOrNull ?? 0;
    final goalMl = prefs?.dailyGoalMl ?? 0;
    final intakeText =
        fmt?.formatLargeVolume(totalMl.toDouble()) ?? '$totalMl ml';
    final goalText = fmt?.formatLargeVolume(goalMl.toDouble()) ?? '$goalMl ml';

    return Scaffold(
      appBar: AppBar(title: const Text("Today's drinks")),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load entries.')),
        data: (entries) => _Body(
          entries: entries,
          intakeText: intakeText,
          goalText: goalText,
          prefs: prefs,
          fmt: fmt,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _Body extends StatelessWidget {
  const _Body({
    required this.entries,
    required this.intakeText,
    required this.goalText,
    required this.prefs,
    required this.fmt,
  });

  final List<DrinkEntry> entries;
  final String intakeText;
  final String goalText;
  final UserPreferences? prefs;
  final FormatService? fmt;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _SummaryHeader(intakeText: intakeText, goalText: goalText),
        ),
        if (entries.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) =>
                  _EntryRow(entry: entries[i], fmt: fmt, prefs: prefs),
              childCount: entries.length,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Summary header
// ---------------------------------------------------------------------------

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.intakeText, required this.goalText});

  final String intakeText;
  final String goalText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            intakeText,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '/ $goalText',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entry row
// ---------------------------------------------------------------------------

class _EntryRow extends ConsumerWidget {
  const _EntryRow({
    required this.entry,
    required this.fmt,
    required this.prefs,
  });

  final DrinkEntry entry;
  final FormatService? fmt;
  final UserPreferences? prefs;

  /// Session-attached alcoholic entries are read-only here — [S9 Party
  /// Session Log] is the single authoritative place to edit or delete them
  /// (design/user-experience.md §S6).
  bool get _isSessionAttached =>
      entry.beverageType.isAlcoholic && entry.partySessionId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = entry.consumedAt.toLocal();
    // Source: Parity Rulebook — "Time-of-day display format" (honours the
    // device's 12h/24h preference rather than a hardcoded format).
    final timeLabel = TimeOfDay.fromDateTime(local).format(context);
    final volumeText =
        fmt?.formatVolume(entry.volumeMl.toDouble()) ?? '${entry.volumeMl} ml';
    final iconColor = entry.iconColor != null
        ? parseIconColor(entry.iconColor!) ??
            Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.primary;
    final icon = entry.beverageType.isAlcoholic
        ? Icons.local_bar_outlined
        : Icons.local_drink_outlined;

    return Semantics(
      label: '${entry.name ?? 'Drink'}, $volumeText, $timeLabel',
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withAlpha(38),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(entry.name ?? 'Drink'),
        subtitle: Text('$volumeText · $timeLabel'),
        trailing: _isSessionAttached
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: SemanticsLabels.editEntryButton,
                    button: true,
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showEditSheet(context, ref),
                      tooltip: 'Edit',
                    ),
                  ),
                  Semantics(
                    label: SemanticsLabels.deleteEntryButton,
                    button: true,
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, ref),
                      tooltip: 'Delete',
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showEditSheet(BuildContext context, WidgetRef ref) async {
    final boundaryHour = prefs?.dayBoundaryHour ?? 5;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntryEditSheet(
        entry: entry,
        defaultCurrency: prefs?.currency,
        onPickTime: (ctx, current) =>
            pickDayWindowTime(ctx, current, boundaryHour: boundaryHour),
        onSave: ({
          required volumeMl,
          name,
          abvPercent,
          required priceMinor,
          required currency,
          required consumedAt,
        }) =>
            ref.read(drinksRepositoryProvider).updateDrinkEntry(
                  id: entry.id,
                  volumeMl: volumeMl,
                  abvPercent: abvPercent,
                  priceMinor: priceMinor,
                  currency: currency,
                  consumedAt: consumedAt,
                ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
          'Remove "${entry.name ?? 'this drink'}" from today\'s log? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(drinksRepositoryProvider).deleteDrinkEntry(entry.id);
    }
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Semantics(
              label: SemanticsLabels.emptyDrinkLog,
              child: Text(
                'No drinks logged yet',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start tracking your hydration by logging your first drink.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Semantics(
              label: SemanticsLabels.logFirstDrinkButton,
              button: true,
              excludeSemantics: true,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Log a drink'),
                onPressed: () => _openLogSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLogSheet(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const LogDrinkSheet(),
    );
  }
}
