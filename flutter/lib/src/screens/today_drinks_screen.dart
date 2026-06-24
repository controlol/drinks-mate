import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../a11y/semantics_labels.dart';
import '../models/drink_entry.dart';
import '../models/user_preferences.dart';
import '../repository/providers.dart';
import '../services/format_service.dart';
import '../utils/color_utils.dart';
import 'log_drink_sheet.dart';

/// S6 — Today Drinks Log.
///
/// Reached by tapping the progress card on the Today screen. Shows today's
/// non-alcoholic entries in reverse-chronological order with per-entry edit
/// (volumeMl and consumedAt only) and soft-delete actions.
///
/// Immutability: snapshot fields (name, icon, ABV, price) are never exposed
/// in the edit form — only volumeMl and consumedAt are user-editable after
/// log time (data-model.md §Snapshot semantics).
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = entry.consumedAt.toLocal();
    final timeLabel =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final volumeText =
        fmt?.formatVolume(entry.volumeMl.toDouble()) ?? '${entry.volumeMl} ml';
    final iconColor = entry.iconColor != null
        ? parseIconColor(entry.iconColor!) ??
            Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.primary;

    return Semantics(
      label: '${entry.name ?? 'Drink'}, $volumeText, $timeLabel',
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withAlpha(38),
          child: Icon(Icons.local_drink_outlined, color: iconColor, size: 22),
        ),
        title: Text(entry.name ?? 'Drink'),
        subtitle: Text('$volumeText · $timeLabel'),
        trailing: Row(
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditEntrySheet(entry: entry, prefs: prefs),
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
// Edit entry bottom sheet
// ---------------------------------------------------------------------------

class _EditEntrySheet extends ConsumerStatefulWidget {
  const _EditEntrySheet({required this.entry, required this.prefs});

  final DrinkEntry entry;
  final UserPreferences? prefs;

  @override
  ConsumerState<_EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends ConsumerState<_EditEntrySheet> {
  late TextEditingController _volumeCtrl;
  late DateTime _consumedAt;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _volumeCtrl = TextEditingController(text: widget.entry.volumeMl.toString());
    _consumedAt = widget.entry.consumedAt;
  }

  @override
  void dispose() {
    _volumeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_submitting) return;
    final volume = int.tryParse(_volumeCtrl.text.trim());
    if (volume == null || volume < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Volume must be at least 1 ml')),
      );
      return;
    }

    setState(() => _submitting = true);
    final repo = ref.read(drinksRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await repo.updateDrinkEntry(
        id: widget.entry.id,
        volumeMl: volume,
        consumedAt: _consumedAt,
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to save changes')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = _consumedAt.toLocal();
    final timeLabel =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHandle(),
          const SizedBox(height: 8),
          Text('Edit drink', style: Theme.of(context).textTheme.titleLarge),
          if (widget.entry.name != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.entry.name!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _volumeCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Volume (ml)',
              suffixText: 'ml',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Time', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text(timeLabel),
                onPressed: () => _pickTime(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final local = _consumedAt.toLocal();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (picked == null || !mounted) return;

    // Map the picked TimeOfDay back into the day window correctly.
    // With dayBoundaryHour = B, the window spans [B:00 day D, B:00 day D+1).
    // Times >= B belong to calendar day D (dayStart); times < B belong to
    // calendar day D+1 (dayEnd). This avoids the midnight-straddling trap
    // where naively combining picked time with local.day produces a DateTime
    // outside the window.
    final boundaryHour = widget.prefs?.dayBoundaryHour ?? 5;
    final window = dayWindow(
      now: _consumedAt.toLocal(),
      boundaryHour: boundaryHour,
    );
    final dayStart = window.$1.toLocal();
    final dayEnd = window.$2.toLocal();

    final DateTime updated;
    if (picked.hour >= boundaryHour) {
      updated = DateTime(
        dayStart.year,
        dayStart.month,
        dayStart.day,
        picked.hour,
        picked.minute,
      );
    } else {
      updated = DateTime(
        dayEnd.year,
        dayEnd.month,
        dayEnd.day,
        picked.hour,
        picked.minute,
      );
    }

    setState(() => _consumedAt = updated);
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

// ---------------------------------------------------------------------------
// Sheet handle (shared)
// ---------------------------------------------------------------------------

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
