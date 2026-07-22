import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../a11y/semantics_labels.dart';
import '../models/session_day_summary.dart';
import 'session_lifetime_bac_chart.dart';

/// A Party Session's summary card: duration, total alcoholic drinks, meals
/// logged, and peak estimated BAC. Shared by the History day drill-down
/// (day-clipped, [buildSessionDaySummary]) and S9 Party Session Log's
/// ended-mode header (whole-session, [buildSessionSummary]) —
/// user-experience.md §S9: "the same fields already shown on the History day
/// drill-down's session summary card."
///
/// [expandable] additionally gates the accordion-expand behaviour shared by
/// both usages (user-experience.md §S3 expand, issue #105; §S9): tapping the
/// card reveals start/end time, total consumed alcohol in grams, and a
/// static whole-lifetime BAC chart — never a meals list; S9 surfaces meals
/// in its own entry list instead (user-experience.md §S9).
class SessionSummaryCard extends StatefulWidget {
  const SessionSummaryCard({
    super.key,
    required this.summary,
    this.onEditName,
    this.expandable = false,
    this.multiDayPosition,
    this.onViewFullSession,
  });

  final SessionDaySummary summary;

  /// Tap target for the "edit name" affordance. Only S9's ended-mode header
  /// passes this (user-experience.md §S9: "tappable to add/edit one in
  /// either mode") — the History day drill-down usage of this same card
  /// leaves it null, so no edit affordance appears there.
  final VoidCallback? onEditName;

  final bool expandable;

  /// This card's 1-indexed position among the calendar days its session
  /// touches, and the total day count — renders the "Day N of M" pill
  /// (user-experience.md §S3 multi-day indicator). Null (the default) shows
  /// no pill, which is every single-day session and every S9 usage (S9 is
  /// never day-clipped, so the pill never applies there). Only the History
  /// day drill-down's call site ever passes this.
  final ({int dayIndex, int totalDays})? multiDayPosition;

  /// Tap target for the "View full session" button, rendered at the bottom
  /// of the expanded content after the BAC chart (user-experience.md §S3
  /// expand). Only the History day drill-down's call site passes this — S9
  /// never does, since S9 already is the full-session view.
  final VoidCallback? onViewFullSession;

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
                if (widget.multiDayPosition != null) ...[
                  _MultiDayPill(position: widget.multiDayPosition!),
                  const SizedBox(height: 8),
                ],
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
                  if (summary.lifetimeBacChart != null) ...[
                    const SizedBox(height: 8),
                    SessionLifetimeBacChart(series: summary.lifetimeBacChart!),
                  ],
                  if (widget.onViewFullSession != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        label: SemanticsLabels.viewFullSessionButton,
                        button: true,
                        excludeSemantics: true,
                        child: OutlinedButton(
                          onPressed: widget.onViewFullSession,
                          child: const Text('View full session'),
                        ),
                      ),
                    ),
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

/// The "Day N of M" multi-day indicator (user-experience.md §S3 multi-day
/// indicator) — same rounded-pill shape as S1's `_StatusPill`
/// (today_screen.dart), but with neutral, non-semantic colouring since this
/// carries no good/bad signal the way pace status does.
class _MultiDayPill extends StatelessWidget {
  const _MultiDayPill({required this.position});

  final ({int dayIndex, int totalDays}) position;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Day ${position.dayIndex} of ${position.totalDays}',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
