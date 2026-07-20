import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../a11y/semantics_labels.dart';
import '../models/session_day_summary.dart';
import '../services/meal_format.dart';
import 'session_lifetime_bac_chart.dart';

/// A Party Session's summary card: duration, total alcoholic drinks, meals
/// logged, and peak estimated BAC. Shared by the History day drill-down
/// (day-clipped, [buildSessionDaySummary]) and S9 Party Session Log's
/// ended-mode header (whole-session, [buildSessionSummary]) —
/// user-experience.md §S9: "the same fields already shown on the History day
/// drill-down's session summary card."
///
/// [expandable] additionally gates the History day drill-down's own
/// accordion-expand behaviour (user-experience.md §S3 expand, issue #105):
/// tapping the card reveals start/end time, total consumed alcohol in
/// grams, the full meals list, and a static whole-lifetime BAC chart. S9's
/// ended-mode header passes `false` (the default) — it stays unexpanded, as
/// the full itemised drink list is already right below it.
class SessionSummaryCard extends StatefulWidget {
  const SessionSummaryCard({
    super.key,
    required this.summary,
    this.onEditName,
    this.expandable = false,
  });

  final SessionDaySummary summary;

  /// Tap target for the "edit name" affordance. Only S9's ended-mode header
  /// passes this (user-experience.md §S9: "tappable to add/edit one in
  /// either mode") — the History day drill-down usage of this same card
  /// leaves it null, so no edit affordance appears there. Never combined
  /// with [expandable] in practice — each call site uses exactly one.
  final VoidCallback? onEditName;

  final bool expandable;

  @override
  State<SessionSummaryCard> createState() => _SessionSummaryCardState();
}

class _SessionSummaryCardState extends State<SessionSummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final onEditName = widget.onEditName;
    final expandable = widget.expandable;
    final peakBac = summary.peakBacGPerL;
    final name = summary.session.name;
    final expanded = expandable && _expanded;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      label: SemanticsLabels.historySessionSummaryCard,
      container: true,
      button: expandable,
      child: Card(
        child: InkWell(
          onTap:
              expandable ? () => setState(() => _expanded = !_expanded) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_bar_outlined,
                      size: 18,
                      color: onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name ?? 'Party session',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (onEditName != null)
                      Semantics(
                        label: SemanticsLabels.editSessionNameButton,
                        button: true,
                        excludeSemantics: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: onEditName,
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (expandable)
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Duration: ${formatSessionDuration(summary.duration)}'),
                if (expanded) ...[
                  Text(
                    'Started: ${_timeLabel(context, summary.session.startedAt)}',
                  ),
                  Text(
                    'Ended: ${summary.session.endedAt == null ? 'Ongoing' : _timeLabel(context, summary.session.endedAt!)}',
                  ),
                ],
                Text('Alcoholic drinks: ${summary.totalAlcoholicDrinks}'),
                Text('Meals logged: ${summary.mealsLoggedCount}'),
                if (peakBac != null)
                  Text(
                    'Peak estimated BAC: ${peakBac.toStringAsFixed(2)} g/L '
                    '(≈ ${gPerLToMmol(peakBac).toStringAsFixed(2)} mmol/L) '
                    '— estimate',
                  ),
                if (expanded) ...[
                  Text(
                    'Total consumed alcohol: ${summary.totalAlcoholGrams.round()} g',
                  ),
                  if (summary.meals.isNotEmpty)
                    Semantics(
                      label: SemanticsLabels.historySessionSummaryCardMeals,
                      container: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final meal in summary.meals)
                            Text(
                              '${mealSizeLabel(meal.size)} meal · '
                              '${relativeTimeAgo(meal.eatenAt, summary.asOf ?? DateTime.now())}',
                            ),
                        ],
                      ),
                    ),
                  if (summary.lifetimeBacChart != null) ...[
                    const SizedBox(height: 8),
                    SessionLifetimeBacChart(series: summary.lifetimeBacChart!),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Source: Parity Rulebook — "Time-of-day display format" (honours the
  // device's 12h/24h preference rather than a hardcoded format), mirroring
  // entry_row.dart's identical usage.
  String _timeLabel(BuildContext context, DateTime dateTime) =>
      TimeOfDay.fromDateTime(dateTime.toLocal()).format(context);
}

/// Shared `${hours}h ${minutes}m` duration formatting for session summaries.
String formatSessionDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  return '${hours}h ${minutes}m';
}
