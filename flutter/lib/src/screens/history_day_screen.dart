import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../a11y/semantics_labels.dart';
import '../models/drink_entry.dart';
import '../models/user_preferences.dart';
import '../repository/providers.dart';
import '../services/format_service.dart';
import '../utils/color_utils.dart';
import '../widgets/session_summary_card.dart';

/// History day drill-down (F4/S3, issue #26; edit/delete added for #67).
///
/// Reached by tapping a day bar on any History chart. Per
/// user-experience.md §S3, this is one of only two general-purpose editing
/// surfaces app-wide (alongside the S6 Today Drinks Log) — every entry gets
/// an edit/delete affordance, except an alcoholic drink attached to a Party
/// Session (`partySessionId` set), which renders read-only here; the S9
/// Party Session Log is the authoritative place to edit or delete those.
/// Editable fields mirror S6: volumeMl and consumedAt only — other fields
/// are immutable snapshots (data-model.md §Snapshot semantics).
///
/// [dayStart]/[dayEnd] must be the exact day-window instants (from
/// `core`'s `dayWindow`/History bucketing) — not just calendar-day
/// midnights — so the entry list and session overlap checks line up with
/// the chart's own day boundaries.
class HistoryDayScreen extends ConsumerWidget {
  const HistoryDayScreen({
    super.key,
    required this.dayStart,
    required this.dayEnd,
  });

  final DateTime dayStart;
  final DateTime dayEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (dayStart: dayStart, dayEnd: dayEnd);
    final entriesAsync = ref.watch(historyDayEntriesProvider(key));
    final summariesAsync = ref.watch(historyDaySessionSummariesProvider(key));
    final prefs = ref.watch(userPreferencesProvider).valueOrNull;
    final fmt = ref.watch(formatServiceProvider);
    final dateLabel = DateFormat('EEEE, MMM d').format(dayStart);

    return Scaffold(
      appBar: AppBar(title: Text(dateLabel)),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load this day.')),
        data: (entries) {
          // Hydration total excludes alcoholic entries — same disjoint-flows
          // rule as the daily goal everywhere else (data-model.md
          // §BeverageType).
          final hydrationMl = entries
              .where((e) => !e.beverageType.isAlcoholic)
              .fold(0, (sum, e) => sum + e.volumeMl);
          final goalMl = prefs?.dailyGoalMl ?? 0;
          final summaries = summariesAsync.valueOrNull ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _DayTotalsHeader(
                hydrationMl: hydrationMl,
                goalMl: goalMl,
                fmt: fmt,
              ),
              for (final summary in summaries) ...[
                const SizedBox(height: 12),
                SessionSummaryCard(summary: summary),
              ],
              const SizedBox(height: 20),
              Text('Drinks', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                const _EmptyDayState()
              else
                Semantics(
                  label: SemanticsLabels.historyDayEntryList,
                  container: true,
                  child: Column(
                    children: [
                      for (final entry in entries)
                        _DayEntryTile(entry: entry, fmt: fmt, prefs: prefs),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Totals header
// ---------------------------------------------------------------------------

class _DayTotalsHeader extends StatelessWidget {
  const _DayTotalsHeader({
    required this.hydrationMl,
    required this.goalMl,
    required this.fmt,
  });

  final int hydrationMl;
  final int goalMl;
  final FormatService? fmt;

  @override
  Widget build(BuildContext context) {
    final intakeText =
        fmt?.formatLargeVolume(hydrationMl.toDouble()) ?? '$hydrationMl ml';
    final goalText = fmt?.formatLargeVolume(goalMl.toDouble()) ?? '$goalMl ml';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(intakeText, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '/ $goalText hydration goal',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Entry tile
// ---------------------------------------------------------------------------

class _DayEntryTile extends ConsumerWidget {
  const _DayEntryTile({required this.entry, required this.fmt, this.prefs});

  final DrinkEntry entry;
  final FormatService? fmt;
  final UserPreferences? prefs;

  /// Session-attached alcoholic entries are read-only here — the S9 Party
  /// Session Log is the single authoritative place to edit or delete them
  /// (design/user-experience.md §S3, mirroring §S6).
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
    final name = entry.name ?? entry.beverageType.displayName;
    final iconColor = entry.iconColor != null
        ? parseIconColor(entry.iconColor!) ??
            Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.primary;

    return Semantics(
      label: '$name, $volumeText, $timeLabel',
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withAlpha(38),
          child: Icon(
            entry.beverageType.isAlcoholic
                ? Icons.local_bar_outlined
                : Icons.local_drink_outlined,
            color: iconColor,
            size: 22,
          ),
        ),
        title: Text(name),
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
                      onPressed: () => _showEditSheet(context),
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

  Future<void> _showEditSheet(BuildContext context) async {
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
          'Remove "${entry.name ?? 'this drink'}" from this day\'s log? '
          'This cannot be undone.',
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
//
// Mirrors today_drinks_screen.dart's _EditEntrySheet exactly (same fields,
// same repository call) — duplicated rather than shared, matching this
// codebase's existing convention of a private per-screen entry-row/edit-sheet
// widget (today_drinks_screen.dart, party_session_log_screen.dart).
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
    // Source: Parity Rulebook — "Time-of-day display format" (honours the
    // device's 12h/24h preference rather than a hardcoded format).
    final timeLabel = TimeOfDay.fromDateTime(local).format(context);

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
// Sheet handle
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

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyDayState extends StatelessWidget {
  const _EmptyDayState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Semantics(
          label: SemanticsLabels.historyDayEmptyState,
          child: Text(
            'No drinks logged this day',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
    );
  }
}
