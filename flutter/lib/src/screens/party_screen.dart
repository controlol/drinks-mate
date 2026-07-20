import 'dart:async';

import 'package:core/core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../a11y/semantics_labels.dart';
import '../models/drink_entry.dart';
import '../models/meal.dart';
import '../models/optional.dart';
import '../models/party_session.dart';
import '../models/session_day_summary.dart';
import '../models/user_profile.dart';
import '../repository/providers.dart';
import '../services/bac_chart_series.dart';
import '../services/bac_estimator.dart';
import '../services/format_service.dart';
import '../services/session_pricing_totals.dart';
import '../theme/app_theme.dart';
import 'party_log_drink_sheet.dart';
import 'party_pricing_sheet.dart';
import 'party_session_flows.dart';
import 'party_session_log_screen.dart';
import 'settings_screen.dart';

/// Party tab (S7) — Party Session UI (issue #22).
///
/// Emerald is the Party-Mode-only accent (C5 quarantine rule): every
/// Party-specific action in this file uses [PartyColorTokens], never the
/// general azure/honey accents, and this colour never leaves this screen.
class PartyScreen extends ConsumerWidget {
  const PartyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(activePartySessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Party'),
        actions: [_settingsButton(context, ref)],
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (session) => session == null
            ? const _NoSessionView()
            : _ActiveSessionView(key: ValueKey(session.id), session: session),
      ),
    );
  }
}

Color _emerald(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? PartyColorTokens.emeraldDark
        : PartyColorTokens.emerald;

// ---------------------------------------------------------------------------
// No active session
// ---------------------------------------------------------------------------

class _NoSessionView extends ConsumerWidget {
  const _NoSessionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final prefs = ref.watch(userPreferencesProvider).valueOrNull;
    final under18 = isUnder18(profile);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Icon(Icons.local_bar_outlined, size: 48, color: _emerald(context)),
        const SizedBox(height: 12),
        Text(
          'Party Mode',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Track alcoholic drinks during a session and see an estimated '
          'blood alcohol concentration (BAC).',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const _DisclaimerBanner(),
        const SizedBox(height: 24),
        // Only the "Start party session" branch is age-gated (party-session.md
        // §Logging alcohol when no session is active): the age check sits on
        // the "Start party session" arrow, not on "Don't start a session", so
        // an alcoholic drink can always be logged as an orphan regardless of
        // age. "Log alcohol" therefore stays visible even when under18.
        if (under18)
          const _Under18Gate()
        else
          Semantics(
            label: SemanticsLabels.startPartySession,
            button: true,
            excludeSemantics: true,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _emerald(context),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => startPartySessionFlow(context, ref),
              child: const Text('Start party session'),
            ),
          ),
        const SizedBox(height: 12),
        Semantics(
          label: SemanticsLabels.logAlcoholButton,
          button: true,
          excludeSemantics: true,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _emerald(context),
              side: BorderSide(color: _emerald(context)),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _handleLogAlcohol(context, ref, null),
            child: const Text('Log alcohol'),
          ),
        ),
        if (!under18 && prefs?.bacCapGramsPerL != null) ...[
          const SizedBox(height: 16),
          Text(
            'Your cap: ${prefs!.bacCapGramsPerL!.toStringAsFixed(2)} g/L '
            '(set in Settings → Party Mode)',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        const _PastSessionsList(),
      ],
    );
  }
}

/// Past-sessions list (user-experience.md §S7 → No active session —
/// subsequent visits): "session date/range, peak BAC, number of alcoholic
/// drinks, and how the session ended (manual/auto)." Tapping a row opens S9
/// in its read-only, ended-session mode.
class _PastSessionsList extends ConsumerWidget {
  const _PastSessionsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(partyEndedSessionSummariesProvider);
    final summaries = summariesAsync.valueOrNull ?? const [];
    if (summaries.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: SemanticsLabels.pastSessionsList,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Past sessions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final summary in summaries) _PastSessionRow(summary: summary),
        ],
      ),
    );
  }
}

class _PastSessionRow extends ConsumerWidget {
  const _PastSessionRow({required this.summary});

  final SessionDaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = summary.session;
    final start = session.startedAt.toLocal();
    final end = (session.endedAt ?? session.startedAt).toLocal();
    final dateRange = _sameDay(start, end)
        ? DateFormat('MMM d').format(start)
        : '${DateFormat('MMM d').format(start)} – '
            '${DateFormat('MMM d').format(end)}';
    final peakBac = summary.peakBacGPerL;
    final endLabel = session.endReason == PartySessionEndReason.autoTimeout
        ? 'ended automatically'
        : 'ended manually';
    // Name before the date, on the same line (user-experience.md §S7 → No
    // active session — subsequent visits); rows with no name just start
    // with the date.
    final name = session.name;
    final titleText = name != null ? '$name · $dateRange' : dateRange;

    return Card(
      child: ListTile(
        leading: Icon(
          Icons.local_bar_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(titleText),
        subtitle: Text(
          '${summary.totalAlcoholicDrinks} alcoholic '
          '${summary.totalAlcoholicDrinks == 1 ? 'drink' : 'drinks'}'
          '${peakBac != null ? ' · peak ${peakBac.toStringAsFixed(2)} g/L' : ''}'
          ' · $endLabel',
        ),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PartySessionLogScreen(sessionId: session.id),
          ),
        ),
        trailing: Semantics(
          label: SemanticsLabels.deleteSessionButton,
          button: true,
          excludeSemantics: true,
          child: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => confirmDeleteSession(context, ref, session),
          ),
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Under18Gate extends StatelessWidget {
  const _Under18Gate();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: SemanticsLabels.under18Gate,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Party Mode requires you to be 18 or older.',
                style: Theme.of(context).textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'If you entered your birthday incorrectly, you can update it '
                'in Settings and try again.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active session
// ---------------------------------------------------------------------------

class _ActiveSessionView extends ConsumerStatefulWidget {
  const _ActiveSessionView({required super.key, required this.session});

  final PartySession session;

  @override
  ConsumerState<_ActiveSessionView> createState() => _ActiveSessionViewState();
}

class _ActiveSessionViewState extends ConsumerState<_ActiveSessionView> {
  bool _bmiWarningDismissed = false;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(
      partySessionEntriesProvider(widget.session.id),
    );
    final mealsAsync = ref.watch(partySessionMealsProvider(widget.session.id));
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final prefs = ref.watch(userPreferencesProvider).valueOrNull;

    // profile.birthDate can briefly be null right after a session starts via
    // the birthday-collection dialog (profile write vs. this stream's next
    // emission racing) — show a loading state rather than let
    // estimateSessionBac's precondition throw.
    if (profile == null ||
        profile.birthDate == null ||
        !entriesAsync.hasValue ||
        !mealsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final alcoholicEntries = entriesAsync.requireValue
        .where((e) => e.beverageType.isAlcoholic)
        .toList();
    final estimate = estimateSessionBac(
      profile: profile,
      alcoholicEntries: alcoholicEntries,
      meals: mealsAsync.requireValue,
      at: now,
    );
    final cap = prefs?.bacCapGramsPerL;
    final approachingCap = cap != null &&
        isApproachingCap(bacGPerL: estimate.gPerL, capGPerL: cap);
    final elapsed = now.difference(widget.session.startedAt);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _BacCard(
          session: widget.session,
          estimate: estimate,
          elapsed: elapsed,
          capGPerL: cap,
          approachingCap: approachingCap,
        ),
        if (estimate.bmiWarning && !_bmiWarningDismissed) ...[
          const SizedBox(height: 12),
          _BmiWarningBanner(
            onDismiss: () {
              setState(() => _bmiWarningDismissed = true);
            },
          ),
        ],
        if (approachingCap) ...[
          const SizedBox(height: 12),
          const _ApproachingCapBanner(),
        ],
        const SizedBox(height: 12),
        _BacLineChartCard(
          profile: profile,
          session: widget.session,
          alcoholicEntries: alcoholicEntries,
          meals: mealsAsync.requireValue,
          now: now,
          capGPerL: cap,
        ),
        const SizedBox(height: 12),
        _DrinksCountLine(
          session: widget.session,
          alcoholicEntries: alcoholicEntries,
        ),
        const SizedBox(height: 12),
        _MealIndicator(
          sessionId: widget.session.id,
          meals: mealsAsync.requireValue,
          now: now,
        ),
        const SizedBox(height: 16),
        _SessionPricesControl(session: widget.session),
        const SizedBox(height: 12),
        _SessionTotalsStrip(
          entries: entriesAsync.requireValue,
          tokenName: widget.session.tokenName,
        ),
        const SizedBox(height: 16),
        Semantics(
          label: SemanticsLabels.logAlcoholButton,
          button: true,
          excludeSemantics: true,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _emerald(context),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _handleLogAlcohol(context, ref, widget.session),
            child: const Text('Log alcohol'),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: SemanticsLabels.endPartySession,
          button: true,
          excludeSemantics: true,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _confirmEndSession(context, ref, widget.session),
            child: const Text('End session'),
          ),
        ),
        const SizedBox(height: 16),
        const _DisclaimerBanner(),
      ],
    );
  }
}

class _BacCard extends ConsumerWidget {
  const _BacCard({
    required this.session,
    required this.estimate,
    required this.elapsed,
    required this.capGPerL,
    required this.approachingCap,
  });

  final PartySession session;
  final BacEstimate estimate;
  final Duration elapsed;
  final double? capGPerL;
  final bool approachingCap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // BAC display precision: 2 decimal places for both g/L and mmol/L,
    // matching party-session.md §Display units' own example
    // ("0.36 g/L (≈ 7.85 mmol/L)"). The Rulebook does not pin BAC display
    // precision explicitly; this choice is documented here for the reviewer.
    final gPerLText = estimate.gPerL.toStringAsFixed(2);
    final mmolText = estimate.mmolPerL.toStringAsFixed(2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Session name (party-session.md §Party tab during a session):
            // shown above the BAC value when set; tappable to add/edit at
            // any point during the active session. Kept as its own tap
            // target, outside the card-wide S9 tap target below, so it
            // keeps taking priority over the whole-card tap in its own
            // bounds (nested InkWells resolve to the innermost hit).
            Semantics(
              label: SemanticsLabels.editSessionNameButton,
              button: true,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showEditSessionNameDialog(context, ref, session),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.name ?? 'Add session name',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // The rest of the card (party-session.md §Party tab during a
            // session): "the entire card is tappable" and opens S9, same
            // destination as _DrinksCountLine below. No `excludeSemantics`
            // here — unlike the name-edit InkWell above, the BAC-value
            // Semantics node below carries detail (g/L + mmol/L) worth
            // keeping independently explorable, not just this button label.
            Semantics(
              label: SemanticsLabels.bacSummaryCard,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PartySessionLogScreen(sessionId: session.id),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      label: '${SemanticsLabels.bacValue}: $gPerLText g/L, '
                          'approximately $mmolText mmol/L',
                      excludeSemantics: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$gPerLText g/L',
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '≈ $mmolText mmol/L',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'estimate',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                    if (capGPerL != null) ...[
                      const SizedBox(height: 16),
                      _CapReferenceBar(
                        bacGPerL: estimate.gPerL,
                        capGPerL: capGPerL!,
                        approachingCap: approachingCap,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Elapsed: ${_formatElapsed(elapsed)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (estimate.unspecifiedGenderConservative) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Estimate uses a conservative model since gender "
                        "isn't specified.",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatElapsed(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}

class _CapReferenceBar extends StatelessWidget {
  const _CapReferenceBar({
    required this.bacGPerL,
    required this.capGPerL,
    required this.approachingCap,
  });

  final double bacGPerL;
  final double capGPerL;
  final bool approachingCap;

  @override
  Widget build(BuildContext context) {
    final scaleMax = [
      bacGPerL,
      capGPerL * 1.25,
      0.01,
    ].reduce((a, b) => a > b ? a : b);
    final bacFraction = (bacGPerL / scaleMax).clamp(0.0, 1.0);
    final capFraction = (capGPerL / scaleMax).clamp(0.0, 1.0);
    final fillColor =
        approachingCap ? kColorWarning : Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal cap: ${capGPerL.toStringAsFixed(2)} g/L',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: bacFraction,
                    child: Container(
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (width * capFraction - 1).clamp(
                      0.0,
                      (width - 2).clamp(0.0, double.infinity),
                    ),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// BAC line chart (party-session.md §BAC line chart). Always rendered from
/// the moment the session starts, including the flat 0.00 g/L empty-state
/// window before the first alcoholic drink (§BAC line chart → Empty state)
/// — [buildBacChartSeries] never returns `null` for a live session, so the
/// chart's footprint never jumps when the first drink lands.
///
/// Owns its own tap-to-inspect state (§BAC line chart → Tap to inspect a
/// value): tapping a plotted point shows a vertical marker + BAC label at
/// that point; tapping outside the card dismisses it. This is entirely
/// local to the chart and never navigates — the card-wide tap-to-open-S9
/// affordance lives on `_BacCard` above, not here.
class _BacLineChartCard extends StatefulWidget {
  const _BacLineChartCard({
    required this.profile,
    required this.session,
    required this.alcoholicEntries,
    required this.meals,
    required this.now,
    required this.capGPerL,
  });

  final UserProfile profile;
  final PartySession session;
  final List<DrinkEntry> alcoholicEntries;
  final List<Meal> meals;
  final DateTime now;
  final double? capGPerL;

  @override
  State<_BacLineChartCard> createState() => _BacLineChartCardState();
}

class _BacLineChartCardState extends State<_BacLineChartCard> {
  // The tapped-on spot, in the chart's own data coordinates (x = minutes
  // since axisStart, y = g/L) — set from the touched line's own sampled
  // point (fl_chart's `LineTouchResponse.lineBarSpots`), so the inspected
  // value is exactly what's plotted rather than a value recomputed
  // independently.
  FlSpot? _tappedSpot;

  @override
  void didUpdateWidget(covariant _BacLineChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The tapped spot's coordinates are only meaningful against the series
    // that was plotted when it was tapped. Entries/meals changes can rescale
    // the axis (e.g. the empty state -> first-drink transition) or change
    // the sampled values at the same x, so drop a stale marker rather than
    // let it render at a position/value nothing on the new series matches.
    // `now` ticking alone doesn't move axisStart/axisEnd for an unchanged
    // series, so the marker is deliberately left alone in that case.
    if (!listEquals(oldWidget.alcoholicEntries, widget.alcoholicEntries) ||
        !listEquals(oldWidget.meals, widget.meals)) {
      _tappedSpot = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final series = buildBacChartSeries(
      profile: widget.profile,
      sessionStartedAt: widget.session.startedAt,
      alcoholicEntries: widget.alcoholicEntries,
      meals: widget.meals,
      now: widget.now,
    );
    if (series == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final capGPerL = widget.capGPerL;
    final axisMinutes =
        series.axisEnd.difference(series.axisStart).inMinutes.toDouble();
    final nowMinutes =
        widget.now.toLocal().difference(series.axisStart).inMinutes.toDouble();
    final maxGPerL = [
      ...series.actual.map((p) => p.gPerL),
      ...series.projected.map((p) => p.gPerL),
      capGPerL ?? 0.0,
    ].reduce((a, b) => a > b ? a : b);
    final maxY = (maxGPerL * 1.2).clamp(0.1, double.infinity);
    final tappedSpot = _tappedSpot;

    return Semantics(
      label: SemanticsLabels.bacLineChart,
      container: true,
      child: TapRegion(
        onTapOutside: (_) => setState(() => _tappedSpot = null),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: axisMinutes <= 0 ? 1 : axisMinutes,
                  minY: 0,
                  maxY: maxY.toDouble(),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    handleBuiltInTouches: false,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (_) => const [],
                    ),
                    touchCallback: (event, response) {
                      final spots = response?.lineBarSpots;
                      if (event is FlTapDownEvent &&
                          spots != null &&
                          spots.isNotEmpty) {
                        setState(() => _tappedSpot = spots.first);
                      }
                    },
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (capGPerL != null)
                        HorizontalLine(
                          y: capGPerL,
                          color: colorScheme.outline,
                          strokeWidth: 1.5,
                          dashArray: const [6, 4],
                        ),
                    ],
                    verticalLines: [
                      // `series.projected.isNotEmpty` also hides the "now"
                      // marker in the empty state (party-session.md §BAC
                      // line chart -> Empty state: no "now" marker before
                      // the first drink) — the empty-state series always
                      // has an empty `projected`, so this one guard covers
                      // both cases.
                      if (series.projected.isNotEmpty &&
                          nowMinutes >= 0 &&
                          nowMinutes <= axisMinutes)
                        VerticalLine(
                          x: nowMinutes,
                          color: colorScheme.outline,
                          strokeWidth: 1,
                          dashArray: const [4, 4],
                        ),
                      if (tappedSpot != null)
                        VerticalLine(
                          x: tappedSpot.x,
                          color: colorScheme.primary,
                          strokeWidth: 2,
                          label: VerticalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(bottom: 4, left: 4),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            labelResolver: (_) =>
                                '${tappedSpot.y.toStringAsFixed(2)} g/L\n'
                                '≈ ${gPerLToMmol(tappedSpot.y).toStringAsFixed(2)} mmol/L',
                          ),
                        ),
                    ],
                  ),
                  rangeAnnotations: RangeAnnotations(
                    verticalRangeAnnotations: [
                      if (series.projected.isNotEmpty)
                        VerticalRangeAnnotation(
                          x1: nowMinutes.clamp(0, axisMinutes),
                          x2: axisMinutes,
                          color: kColorWarning.withAlpha(20),
                        ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) => Text(
                          gPerLToMmol(value).toStringAsFixed(1),
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        interval: series.tickInterval.inMinutes.toDouble(),
                        getTitlesWidget: (value, meta) {
                          final t = series.axisStart.add(
                            Duration(minutes: value.round()),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${t.hour.toString().padLeft(2, '0')}:'
                              '${t.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _spots(series.actual, series.axisStart),
                      isCurved: false,
                      color: colorScheme.primary,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                    if (series.projected.isNotEmpty)
                      LineChartBarData(
                        spots: _spots(series.projected, series.axisStart),
                        isCurved: false,
                        color: colorScheme.primary,
                        barWidth: 2,
                        dashArray: const [6, 4],
                        dotData: const FlDotData(show: false),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static List<FlSpot> _spots(List<BacChartPoint> points, DateTime axisStart) {
    return [
      for (final p in points)
        FlSpot(p.time.difference(axisStart).inMinutes.toDouble(), p.gPerL),
    ];
  }
}

/// Drinks-count / total-grams line (party-session.md §Party tab during a
/// session): tappable, opens S9 in its editable, active-session mode
/// (user-experience.md §S7 → Active session).
class _DrinksCountLine extends StatelessWidget {
  const _DrinksCountLine({
    required this.session,
    required this.alcoholicEntries,
  });

  final PartySession session;
  final List<DrinkEntry> alcoholicEntries;

  @override
  Widget build(BuildContext context) {
    final totalGrams = alcoholicEntries.fold<double>(
      0,
      (sum, e) =>
          sum +
          alcoholGrams(
            volumeMl: e.volumeMl.toDouble(),
            abvPercent: e.abvPercent ?? 0,
          ),
    );

    return Semantics(
      label: SemanticsLabels.drinksCountLine,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PartySessionLogScreen(sessionId: session.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${alcoholicEntries.length} alcoholic '
                  '${alcoholicEntries.length == 1 ? 'drink' : 'drinks'} · '
                  '${totalGrams.round()} g alcohol',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Persistent meal indicator (party-session.md §Party tab during a session):
/// shows the most recent meal ("Medium meal · 2 h ago") or "Add meal" when
/// none has been logged. Tapping opens an action to log a new meal or edit
/// the last one.
class _MealIndicator extends ConsumerWidget {
  const _MealIndicator({
    required this.sessionId,
    required this.meals,
    required this.now,
  });

  final String sessionId;
  final List<Meal> meals;
  final DateTime now;

  Meal? get _lastMeal {
    if (meals.isEmpty) return null;
    return meals.reduce((a, b) => a.eatenAt.isAfter(b.eatenAt) ? a : b);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = _lastMeal;
    final label = last == null
        ? 'Add meal'
        : '${_sizeLabel(last.size)} meal · ${_relativeTime(last.eatenAt, now)}';

    return Semantics(
      label: SemanticsLabels.mealIndicator,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openMealActions(context, ref, last),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.restaurant_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMealActions(
    BuildContext context,
    WidgetRef ref,
    Meal? last,
  ) async {
    final action = await showModalBottomSheet<_MealAction>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Log new meal'),
              onTap: () => Navigator.of(context).pop(_MealAction.logNew),
            ),
            if (last != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit last meal'),
                onTap: () => Navigator.of(context).pop(_MealAction.editLast),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    if (action == _MealAction.logNew) {
      final size = await showMealPrompt(context);
      if (size != null) {
        await ref
            .read(partySessionRepositoryProvider)
            .addMeal(sessionId: sessionId, size: size);
      }
    } else if (last != null) {
      final size = await _pickMealSize(context, initial: last.size);
      if (size != null) {
        await ref
            .read(partySessionRepositoryProvider)
            .updateMeal(id: last.id, size: size);
      }
    }
  }

  Future<MealSize?> _pickMealSize(
    BuildContext context, {
    required MealSize initial,
  }) {
    return showModalBottomSheet<MealSize>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit last meal',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              for (final size in MealSize.values)
                ListTile(
                  title: Text(_sizeLabel(size)),
                  trailing: size == initial ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(size),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _sizeLabel(MealSize size) => switch (size) {
        MealSize.small => 'Small',
        MealSize.medium => 'Medium',
        MealSize.large => 'Large',
      };

  static String _relativeTime(DateTime eatenAt, DateTime now) {
    final d = now.difference(eatenAt);
    if (d.inMinutes < 60) {
      return '${d.inMinutes < 1 ? 1 : d.inMinutes} min ago';
    }
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return minutes == 0 ? '$hours h ago' : '$hours h ${minutes}m ago';
  }
}

enum _MealAction { logNew, editLast }

class _BmiWarningBanner extends StatelessWidget {
  const _BmiWarningBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: SemanticsLabels.bmiWarningBanner,
      child: Material(
        color: kColorWarning.withAlpha(38),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: kColorWarning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'BAC estimates may be less accurate for users outside '
                  'typical body composition ranges.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Dismiss',
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApproachingCapBanner extends StatelessWidget {
  const _ApproachingCapBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: SemanticsLabels.approachingCapBanner,
      child: Material(
        color: kColorWarning.withAlpha(38),
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                size: 18,
                color: kColorWarning,
              ),
              SizedBox(width: 8),
              Expanded(child: Text('Approaching your personal cap')),
            ],
          ),
        ),
      ),
    );
  }
}

/// The session-prices control (party-session.md §Party tab during a
/// session): a live toggle for [PartySession.useSessionPrices] plus a
/// "Manage prices" link. Reads live overrides only to decide the toggle's
/// off-state label ("off — using regular prices" vs plain "off").
class _SessionPricesControl extends ConsumerWidget {
  const _SessionPricesControl({required this.session});

  final PartySession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides =
        ref.watch(partySessionPricesProvider(session.id)).valueOrNull ?? [];
    final hasOverrides = overrides.isNotEmpty;
    final label = session.useSessionPrices
        ? 'Session prices: on'
        : hasOverrides
            ? 'Session prices: off — using regular prices'
            : 'Session prices: off';

    return Semantics(
      label: SemanticsLabels.useSessionPricesToggle,
      child: Row(
        children: [
          Switch(
            value: session.useSessionPrices,
            onChanged: (value) => ref
                .read(partySessionRepositoryProvider)
                .setUseSessionPrices(session.id, value),
          ),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Semantics(
            label: SemanticsLabels.managePricesButton,
            button: true,
            excludeSemantics: true,
            child: TextButton(
              onPressed: () => _showManagePrices(context, ref, session),
              child: const Text('Manage prices'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the per-session price table pre-filled with [session]'s existing
/// overrides and token config (party-session.md §Editing prices during a
/// session).
Future<void> _showManagePrices(
  BuildContext context,
  WidgetRef ref,
  PartySession session,
) async {
  final repo = ref.read(partySessionRepositoryProvider);
  final existing = await repo.getSessionPrices(session.id);
  if (!context.mounted) return;
  final presets = ref.read(visiblePresetsProvider).valueOrNull ?? [];
  final defaultCurrency =
      ref.read(userPreferencesProvider).valueOrNull?.currency ?? 'EUR';

  final result = await showModalBottomSheet<PricingSetupResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PartyPricingSheet(
      presets: presets,
      existingOverrides: existing,
      initialTokenName: session.tokenName,
      initialTokenValueMinor: session.tokenValueMinor,
      initialTokenValueCurrency: session.tokenValueCurrency,
      defaultCurrency: defaultCurrency,
    ),
  );
  if (result == null) return;
  await repo.setSessionPrices(sessionId: session.id, prices: result.prices);
  await repo.updateTokenConfig(
    sessionId: session.id,
    tokenName: result.tokenName,
    tokenValueMinor: result.tokenValueMinor,
    tokenValueCurrency: result.tokenValueCurrency,
  );
}

/// Session totals strip (party-session.md §Aggregations across mixed
/// payment): money spent grouped by currency, tokens used, and the token
/// money-equivalent if set — never summed across currencies.
class _SessionTotalsStrip extends StatelessWidget {
  const _SessionTotalsStrip({required this.entries, this.tokenName});

  final List<DrinkEntry> entries;
  final String? tokenName;

  @override
  Widget build(BuildContext context) {
    final totals = SessionPricingTotals.fromEntries(entries);
    if (totals.moneyByCurrency.isEmpty && totals.tokensSpent == 0) {
      return const SizedBox.shrink();
    }

    final moneyText = totals.moneyByCurrency.entries
        .map((e) => FormatService.formatPriceValue(e.value, e.key))
        .join(' | ');
    final tokenValueText = totals.tokenValueByCurrency.entries
        .map((e) => FormatService.formatPriceValue(e.value, e.key))
        .join(' | ');

    return Semantics(
      label: SemanticsLabels.sessionTotalsStrip,
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          if (moneyText.isNotEmpty) Text('Spent: $moneyText'),
          if (totals.tokensSpent > 0)
            Text('${tokenName ?? 'Tokens'} used: ${totals.tokensSpent}'),
          if (tokenValueText.isNotEmpty) Text('Token value: ≈ $tokenValueText'),
        ],
      ),
    );
  }
}

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: SemanticsLabels.bacDisclaimer,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                SemanticsLabels.bacDisclaimer,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Start a Party Session first?" prompt (party-session.md §Logging
/// alcohol when no session is active). Returns true to start a session,
/// false to log as an orphan. Null means the dialog was dismissed without an
/// explicit choice (e.g. the Android back gesture, which bypasses
/// `barrierDismissible`) — the caller treats that as cancelling the whole
/// log action, not as an implicit "don't start a session".
Future<bool?> _showStartSessionPrompt(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Start a Party Session first?'),
      content: const Text(
        'You can track this drink in a Party Session to see an estimated '
        'BAC, or just log it without tracking.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Don't start a session"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Start party session'),
        ),
      ],
    ),
  );
}

/// Logs [selection] as an orphan drink (no Party Session) and shows a
/// confirmation SnackBar.
Future<void> _logOrphanDrink(
  BuildContext context,
  WidgetRef ref,
  AlcoholicDrinkSelection selection,
) async {
  await ref.read(drinksRepositoryProvider).logDrink(
        preset: selection.preset,
        name: selection.name,
        volumeMl: selection.volumeMl,
        abvPercent: selection.abvPercent,
        consumedAt: selection.consumedAt,
        // One-off override (party-session.md §Logging an alcoholic drink):
        // Optional.absent (not .value(null)) when the field was left blank,
        // so it falls back to the preset's regular price instead of
        // explicitly clearing it.
        priceMinor: selection.priceMinor != null
            ? Optional.value(selection.priceMinor)
            : const Optional.absent(),
        currency: selection.priceMinor != null
            ? Optional.value(selection.currency)
            : const Optional.absent(),
      );
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Drink logged')));
  }
}

/// Orchestrates the whole "Log alcohol" flow: pick a preset (via
/// [PartyLogDrinkSheet]), then — if there's no active [session] — the
/// start-or-orphan prompt (which, when a new session is started, runs its
/// own once-per-session meal prompt), then the actual log call.
Future<void> _handleLogAlcohol(
  BuildContext context,
  WidgetRef ref,
  PartySession? session,
) async {
  final selection = await showModalBottomSheet<AlcoholicDrinkSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const PartyLogDrinkSheet(),
  );
  if (selection == null || !context.mounted) return;

  var activeSession = session;
  if (activeSession == null) {
    final startNewSession = await _showStartSessionPrompt(context);
    if (startNewSession == null) return;
    if (!startNewSession) {
      if (context.mounted) await _logOrphanDrink(context, ref, selection);
      return;
    }
    if (!context.mounted) return;
    final newSession = await startPartySessionFlow(
      context,
      ref,
      startedAt: selection.consumedAt,
    );
    if (newSession == null) {
      // Blocked by the under-18 gate or the birthdate dialog was cancelled —
      // the user already confirmed this drink, so fall back to logging it as
      // an orphan rather than silently discarding it (party-session.md
      // §Logging alcohol when no session is active).
      if (context.mounted) await _logOrphanDrink(context, ref, selection);
      return;
    }
    activeSession = newSession;
  }

  if (!context.mounted) return;
  await logAlcoholicDrinkIntoSession(context, ref, activeSession, selection);
}

Future<void> _confirmEndSession(
  BuildContext context,
  WidgetRef ref,
  PartySession session,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('End session?'),
      content: const Text('This ends your current Party Session.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('End session'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref
        .read(partySessionRepositoryProvider)
        .endSession(session.id, PartySessionEndReason.manual);
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

Widget _settingsButton(BuildContext context, WidgetRef ref) => IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Settings',
      onPressed: () {
        unawaited(
            ref.read(partySessionRepositoryProvider).checkAndApplyAutoEnd());
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
        );
      },
    );
