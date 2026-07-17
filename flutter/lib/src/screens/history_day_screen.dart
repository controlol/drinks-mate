import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../a11y/semantics_labels.dart';
import '../models/drink_entry.dart';
import '../repository/providers.dart';
import '../services/format_service.dart';
import '../utils/color_utils.dart';
import '../widgets/session_summary_card.dart';

/// History day drill-down (F4/S3, issue #26).
///
/// Reached by tapping a day bar on any History chart. Read-only — per
/// user-experience.md S3 ("Charts are read-only"), this screen shows the
/// day's data but does not expose edit/delete affordances (unlike the S6
/// Today Drinks Log), keeping this issue's scope to display only.
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
                        _DayEntryTile(entry: entry, fmt: fmt),
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

class _DayEntryTile extends StatelessWidget {
  const _DayEntryTile({required this.entry, required this.fmt});

  final DrinkEntry entry;
  final FormatService? fmt;

  @override
  Widget build(BuildContext context) {
    final local = entry.consumedAt.toLocal();
    final timeLabel =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
