import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../a11y/semantics_labels.dart';
import '../models/session_day_summary.dart';

/// A Party Session's summary card: duration, total alcoholic drinks, meals
/// logged, and peak estimated BAC. Shared by the History day drill-down
/// (day-clipped, [buildSessionDaySummary]) and S9 Party Session Log's
/// ended-mode header (whole-session, [buildSessionSummary]) —
/// user-experience.md §S9: "the same fields already shown on the History day
/// drill-down's session summary card."
class SessionSummaryCard extends StatelessWidget {
  const SessionSummaryCard({super.key, required this.summary, this.onEditName});

  final SessionDaySummary summary;

  /// Tap target for the "edit name" affordance. Only S9's ended-mode header
  /// passes this (user-experience.md §S9: "tappable to add/edit one in
  /// either mode") — the History day drill-down usage of this same card
  /// leaves it null, so no edit affordance appears there.
  final VoidCallback? onEditName;

  @override
  Widget build(BuildContext context) {
    final peakBac = summary.peakBacGPerL;
    final name = summary.session.name;

    return Semantics(
      label: SemanticsLabels.historySessionSummaryCard,
      container: true,
      child: Card(
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Duration: ${formatSessionDuration(summary.duration)}'),
              Text('Alcoholic drinks: ${summary.totalAlcoholicDrinks}'),
              Text('Meals logged: ${summary.mealsLoggedCount}'),
              if (peakBac != null)
                Text(
                  'Peak estimated BAC: ${peakBac.toStringAsFixed(2)} g/L '
                  '(≈ ${gPerLToMmol(peakBac).toStringAsFixed(2)} mmol/L) '
                  '— estimate',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared `${hours}h ${minutes}m` duration formatting for session summaries.
String formatSessionDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  return '${hours}h ${minutes}m';
}
