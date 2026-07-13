import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../a11y/semantics_labels.dart';
import '../models/bac_daily_bucket.dart';
import '../models/daily_bucket.dart';
import '../models/history_range.dart';
import '../models/party_session.dart';
import '../models/user_preferences.dart';
import '../repository/providers.dart';
import '../services/format_service.dart';
import '../theme/color_tokens.dart';
import 'history_day_screen.dart';
import 'settings_screen.dart';

/// History tab — F4/S3: weekly/monthly range paging over the hydration
/// charts (issue #25) plus the conditional alcohol charts, session overlay
/// band, and day drill-down (issue #26).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryRangeSelection _selection = const HistoryRangeSelection();

  void _setMode(HistoryRangeMode mode) {
    if (mode == _selection.mode) return;
    // Offset resets — "week 3 back" has no meaningful equivalent in months.
    setState(() => _selection = HistoryRangeSelection(mode: mode));
  }

  void _pageBack() {
    setState(
      () => _selection = _selection.copyWith(offset: _selection.offset + 1),
    );
  }

  void _pageForward() {
    if (_selection.offset == 0) return;
    setState(
      () => _selection = _selection.copyWith(offset: _selection.offset - 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(userPreferencesProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [_settingsButton(context)],
      ),
      body: prefs == null
          ? const Center(child: CircularProgressIndicator())
          : _HistoryBody(
              prefs: prefs,
              selection: _selection,
              onModeChanged: _setMode,
              onPageBack: _pageBack,
              onPageForward: _pageForward,
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

// ---------------------------------------------------------------------------
// Body — range selector + charts
// ---------------------------------------------------------------------------

class _HistoryBody extends ConsumerWidget {
  const _HistoryBody({
    required this.prefs,
    required this.selection,
    required this.onModeChanged,
    required this.onPageBack,
    required this.onPageForward,
  });

  final UserPreferences prefs;
  final HistoryRangeSelection selection;
  final ValueChanged<HistoryRangeMode> onModeChanged;
  final VoidCallback onPageBack;
  final VoidCallback onPageForward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final window = selection.mode == HistoryRangeMode.weekly
        ? pagedIsoWeekWindow(
            now: now,
            offset: selection.offset,
            boundaryHour: prefs.dayBoundaryHour,
          )
        : pagedMonthWindow(
            now: now,
            offset: selection.offset,
            boundaryHour: prefs.dayBoundaryHour,
          );
    final key = (
      rangeStart: window.$1,
      rangeEnd: window.$2,
      boundaryHour: prefs.dayBoundaryHour,
    );

    final totalsAsync = ref.watch(historyDailyTotalsProvider(key));
    final countsAsync = ref.watch(historyDrinksPerDayProvider(key));
    final alcoholicCountsAsync = ref.watch(
      historyAlcoholicDrinksPerDayProvider(key),
    );
    final sessionsAsync = ref.watch(historySessionsInRangeProvider(key));
    final maxBacAsync = ref.watch(historyMaxBacPerDayProvider(key));
    final fmt = ref.watch(formatServiceProvider);

    return Column(
      children: [
        _RangeSelector(
          selection: selection,
          rangeLabel: _rangeLabel(selection, window.$1, window.$2),
          onModeChanged: onModeChanged,
          onPageBack: onPageBack,
          onPageForward: onPageForward,
        ),
        Expanded(
          child: totalsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text('Could not load history.')),
            data: (totals) {
              final counts = countsAsync.valueOrNull ?? [];
              // features.md F4: alcohol charts show only when at least one
              // PartySession intersects the selected range — driven off the
              // sessions stream itself, not off whether any BAC bucket is
              // non-null, so a party-only period (no hydration/non-alcoholic
              // drinks logged) still shows the alcohol section instead of
              // falling into the all-zero empty state below.
              final sessions = sessionsAsync.valueOrNull ?? [];
              final hasAlcoholSection = sessions.isNotEmpty;
              final isEmpty = totals.every((b) => b.value == 0) &&
                  counts.every((b) => b.value == 0) &&
                  !hasAlcoholSection;
              if (isEmpty) return const _EmptyState();

              void onDayTap(int index) {
                if (index < 0 || index >= totals.length) return;
                _openDayDrilldown(
                  context,
                  dayStart: totals[index].dayStart,
                  boundaryHour: prefs.dayBoundaryHour,
                );
              }

              return ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  _ChartCard(
                    title: 'Hydration per day',
                    child: _HydrationChart(
                      buckets: totals,
                      goalMl: prefs.dailyGoalMl,
                      mode: selection.mode,
                      fmt: fmt,
                      onDayTap: onDayTap,
                    ),
                  ),
                  _ChartCard(
                    title: 'Drinks per day',
                    child: _DrinksPerDayChart(
                      buckets: counts,
                      mode: selection.mode,
                      onDayTap: onDayTap,
                    ),
                  ),
                  if (hasAlcoholSection) ...[
                    _ChartCard(
                      title: 'Alcoholic drinks per day',
                      child: _AlcoholicDrinksPerDayChart(
                        buckets: alcoholicCountsAsync.valueOrNull ?? [],
                        dayStarts: totals.map((b) => b.dayStart).toList(),
                        sessions: sessions,
                        boundaryHour: prefs.dayBoundaryHour,
                        mode: selection.mode,
                        onDayTap: onDayTap,
                      ),
                    ),
                    _ChartCard(
                      title: 'Max estimated BAC per day',
                      child: _MaxBacChart(
                        buckets: maxBacAsync.valueOrNull ??
                            totals
                                .map(
                                  (b) => BacDailyBucket(dayStart: b.dayStart),
                                )
                                .toList(),
                        dayStarts: totals.map((b) => b.dayStart).toList(),
                        sessions: sessions,
                        boundaryHour: prefs.dayBoundaryHour,
                        capGPerL: prefs.bacCapGramsPerL,
                        mode: selection.mode,
                        fmt: fmt,
                        onDayTap: onDayTap,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static void _openDayDrilldown(
    BuildContext context, {
    required DateTime dayStart,
    required int boundaryHour,
  }) {
    final dayEnd = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day + 1,
      boundaryHour,
    );
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HistoryDayScreen(dayStart: dayStart, dayEnd: dayEnd),
      ),
    );
  }

  static String _rangeLabel(
    HistoryRangeSelection selection,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    if (selection.mode == HistoryRangeMode.monthly) {
      return DateFormat('MMMM yyyy').format(rangeStart);
    }
    final lastDay = rangeEnd.subtract(const Duration(days: 1));
    final sameYear = rangeStart.year == lastDay.year;
    final startText = DateFormat(
      sameYear ? 'MMM d' : 'MMM d, yyyy',
    ).format(rangeStart);
    final endText = DateFormat('MMM d, yyyy').format(lastDay);
    return '$startText – $endText';
  }
}

// ---------------------------------------------------------------------------
// Range selector
// ---------------------------------------------------------------------------

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selection,
    required this.rangeLabel,
    required this.onModeChanged,
    required this.onPageBack,
    required this.onPageForward,
  });

  final HistoryRangeSelection selection;
  final String rangeLabel;
  final ValueChanged<HistoryRangeMode> onModeChanged;
  final VoidCallback onPageBack;
  final VoidCallback onPageForward;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: SemanticsLabels.historyRangeModeSelector,
            excludeSemantics: true,
            child: SegmentedButton<HistoryRangeMode>(
              segments: const [
                ButtonSegment(
                  value: HistoryRangeMode.weekly,
                  label: Text('Weekly'),
                ),
                ButtonSegment(
                  value: HistoryRangeMode.monthly,
                  label: Text('Monthly'),
                ),
              ],
              selected: {selection.mode},
              onSelectionChanged: (s) => onModeChanged(s.first),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                label: SemanticsLabels.historyPageBack,
                excludeSemantics: true,
                child: IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPageBack,
                ),
              ),
              Expanded(
                child: Text(
                  rangeLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Semantics(
                label: SemanticsLabels.historyPageForward,
                excludeSemantics: true,
                child: IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: selection.offset == 0 ? null : onPageForward,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart card shell
// ---------------------------------------------------------------------------

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(height: 220, child: child),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hydration-per-day chart
// ---------------------------------------------------------------------------

class _HydrationChart extends StatelessWidget {
  const _HydrationChart({
    required this.buckets,
    required this.goalMl,
    required this.mode,
    required this.fmt,
    required this.onDayTap,
  });

  final List<DailyBucket> buckets;
  final int goalMl;
  final HistoryRangeMode mode;
  final FormatService? fmt;
  final ValueChanged<int> onDayTap;

  @override
  Widget build(BuildContext context) {
    final maxBarValue = buckets.fold(0, (m, b) => math.max(m, b.value));
    final maxY = (math.max(maxBarValue, goalMl) * 1.15).ceilToDouble();
    final belowGoalCount = buckets.where((b) => b.value < goalMl).length;
    final colorScheme = Theme.of(context).colorScheme;
    final dayStarts = buckets.map((b) => b.dayStart).toList();

    return Semantics(
      container: true,
      label: '${SemanticsLabels.historyHydrationChartPrefix}'
          '$belowGoalCount of ${buckets.length} days below goal.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = _barWidth(buckets.length, constraints.maxWidth);
          return BarChart(
            BarChartData(
              maxY: maxY <= 0 ? 1 : maxY,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: barTouchDataForDayTap(
                onDayTap,
                touchExtraThreshold: fullColumnTouchExtraThreshold(
                  barWidth: barWidth,
                  bucketCount: buckets.length,
                  chartWidth: constraints.maxWidth,
                  leftReservedSize: 44,
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: goalMl.toDouble(),
                    color: colorScheme.outline,
                    strokeWidth: 2,
                    dashArray: const [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: TextStyle(
                        color: colorScheme.outline,
                        fontSize: 10,
                      ),
                      labelResolver: (_) =>
                          fmt?.formatLargeVolume(goalMl.toDouble()) ??
                          '$goalMl ml',
                    ),
                  ),
                ],
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        fmt?.formatLargeVolume(value) ?? '${value.round()}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: mode == HistoryRangeMode.weekly ? 1 : 5,
                    getTitlesWidget: (value, meta) =>
                        dayLabel(dayStarts, value, mode),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < buckets.length; i++)
                  _barGroup(i, buckets[i], goalMl, barWidth, colorScheme),
              ],
            ),
          );
        },
      ),
    );
  }

  static BarChartGroupData _barGroup(
    int index,
    DailyBucket bucket,
    int goalMl,
    double barWidth,
    ColorScheme colorScheme,
  ) {
    final isBelowGoal = bucket.value < goalMl;
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: bucket.value.toDouble(),
          width: barWidth,
          borderRadius: BorderRadius.circular(3),
          color: isBelowGoal ? kColorWarning : kColorAzure,
          // Non-colour below-goal signal (C3; design-system.md
          // §Non-colour-signal rules): a visible outline in addition to the
          // colour change, so the state reads without relying on hue.
          borderSide: isBelowGoal
              ? BorderSide(color: colorScheme.onSurface, width: 1.5)
              : BorderSide.none,
        ),
      ],
    );
  }

  static double _barWidth(int count, double availableWidth) {
    if (count == 0) return 8;
    return ((availableWidth - 44) / count * 0.55).clamp(3.0, 22.0);
  }
}

// ---------------------------------------------------------------------------
// Drinks-per-day chart
// ---------------------------------------------------------------------------

class _DrinksPerDayChart extends StatelessWidget {
  const _DrinksPerDayChart({
    required this.buckets,
    required this.mode,
    required this.onDayTap,
  });

  final List<DailyBucket> buckets;
  final HistoryRangeMode mode;
  final ValueChanged<int> onDayTap;

  @override
  Widget build(BuildContext context) {
    final maxCount = buckets.fold(0, (m, b) => math.max(m, b.value));
    final maxY = math.max(maxCount, 1) * 1.2;
    final dayStarts = buckets.map((b) => b.dayStart).toList();

    return Semantics(
      container: true,
      label: '${SemanticsLabels.historyDrinksChartPrefix}'
          '${buckets.fold(0, (s, b) => s + b.value)} drinks logged.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = _HydrationChart._barWidth(
            buckets.length,
            constraints.maxWidth,
          );
          return BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: barTouchDataForDayTap(
                onDayTap,
                touchExtraThreshold: fullColumnTouchExtraThreshold(
                  barWidth: barWidth,
                  bucketCount: buckets.length,
                  chartWidth: constraints.maxWidth,
                  leftReservedSize: 32,
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 1,
                    getTitlesWidget: (value, meta) =>
                        value == value.roundToDouble()
                            ? Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              )
                            : const SizedBox.shrink(),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: mode == HistoryRangeMode.weekly ? 1 : 5,
                    getTitlesWidget: (value, meta) =>
                        dayLabel(dayStarts, value, mode),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < buckets.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: buckets[i].value.toDouble(),
                        width: barWidth,
                        borderRadius: BorderRadius.circular(3),
                        color: kColorAzure,
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shared bottom-axis day label — used by every History day-bar chart
/// (hydration, drinks, alcoholic drinks, max BAC) so all four stay aligned
/// on the same day index → date mapping.
Widget dayLabel(List<DateTime> dayStarts, double value, HistoryRangeMode mode) {
  final index = value.round();
  if (index < 0 || index >= dayStarts.length) return const SizedBox.shrink();
  final day = dayStarts[index];
  final text = mode == HistoryRangeMode.weekly
      ? DateFormat('E').format(day)
      : DateFormat('d').format(day);
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: const TextStyle(fontSize: 10)),
  );
}

/// Shared bar-tap-to-drill-down wiring (user-experience.md S3: "Tapping a
/// day on any chart ... drills into the day detail") — every History day-bar
/// chart uses this so a tap on any bar (including a transparent
/// no-session/no-bar rod) navigates to that day.
///
/// [touchExtraThreshold] must be [fullColumnTouchExtraThreshold] (or
/// equivalent) rather than fl_chart's tiny `EdgeInsets.all(4)` default — see
/// that function's doc for why a zero-height rod is otherwise only tappable
/// within an ~8px strip at the baseline.
///
/// [getTooltipItem] optionally renders a tooltip on touch before the tap-up
/// navigates away (used by the max-BAC chart for its mmol/L secondary value
/// — features.md F4: "mmol/L shown alongside in tooltips"); charts that
/// don't need one get a fully transparent, content-free tooltip.
BarTouchData barTouchDataForDayTap(
  ValueChanged<int> onDayTap, {
  required EdgeInsets touchExtraThreshold,
  BarTooltipItem? Function(BarChartGroupData, int, BarChartRodData, int)?
      getTooltipItem,
}) {
  return BarTouchData(
    touchExtraThreshold: touchExtraThreshold,
    touchTooltipData: BarTouchTooltipData(
      getTooltipColor: (_) => Colors.transparent,
      // Suppress fl_chart's default y-value tooltip text when the caller
      // doesn't supply its own — a floating, background-less number would
      // otherwise show on every tap given the transparent tooltip colour
      // above (which exists to avoid a visible box over the day-drill-down
      // gesture, not to hide a rendered value).
      getTooltipItem: getTooltipItem ?? (_, __, ___, ____) => null,
    ),
    touchCallback: (event, response) {
      if (event is! FlTapUpEvent) return;
      final index = response?.spot?.touchedBarGroupIndex;
      if (index != null) onDayTap(index);
    },
  );
}

/// Widens a bar's tap target to its entire day column, not just its own
/// rendered rod.
///
/// fl_chart 0.68.0's `BarChartPainter.handleTouch` hit-tests a bar against
/// `[barTopY, barBotY]` of its *rendered* rod, padded only by
/// `BarTouchData.touchExtraThreshold` (default `EdgeInsets.all(4)`). For a
/// rod with `toY: 0` (every no-session max-BAC bar, and every zero-count day
/// on the drinks/alcoholic-drinks charts), `barTopY == barBotY ==` the y=0
/// baseline pixel, so only an ~8px strip at the very bottom of the chart is
/// tappable. The `spaceAround` gaps between bars (see fl_chart's
/// `BarChartDataExtension.calculateGroupsX`) are dead zones too, for every
/// bar regardless of height.
///
/// Since [BarChartAlignment.spaceAround] spaces every group evenly across
/// the plot width (`(index + 0.5) * plotWidth / bucketCount`, in the same
/// pixel space fl_chart hit-tests against), a horizontal threshold of
/// `pitch/2 - barWidth/2` extends each bar's hit box to exactly the midpoint
/// with its neighbours — covering the full column with no overlap. A large
/// vertical threshold makes the column tappable at any height, not just
/// near a rendered (possibly zero-height) rod.
EdgeInsets fullColumnTouchExtraThreshold({
  required double barWidth,
  required int bucketCount,
  required double chartWidth,
  required double leftReservedSize,
}) {
  final plotWidth = math.max(chartWidth - leftReservedSize, 0.0);
  final pitch = bucketCount == 0 ? 0.0 : plotWidth / bucketCount;
  final horizontalSlack = math.max((pitch - barWidth) / 2, 0.0);
  return EdgeInsets.only(
    left: horizontalSlack,
    right: horizontalSlack,
    // Comfortably exceeds this app's fixed 220px chart height (_ChartCard).
    top: 1000,
  );
}

/// Builds the session-overlay band (features.md F4: "both alcohol charts
/// get a shaded background band ... spanning the relevant days") — one
/// [VerticalRangeAnnotation] per session, covering every day index in
/// [dayStarts] that session's `[startedAt, endedAt)` window touches.
///
/// Uses an opacity fill (not a flat saturated colour) as the accessibility
/// signal so the band never relies on hue alone, and is what disambiguates
/// a session-day whose BAC has fully decayed to 0 (an invisible zero-height
/// bar) from a day with no session at all (also no visible bar) — only the
/// former gets the band.
RangeAnnotations sessionOverlayAnnotations({
  required List<DateTime> dayStarts,
  required List<PartySession> sessions,
  required int boundaryHour,
  required Color color,
}) {
  final annotations = <VerticalRangeAnnotation>[];
  for (final session in sessions) {
    final sessionEnd = session.endedAt ?? DateTime.now();
    int? firstIndex;
    int? lastIndex;
    for (var i = 0; i < dayStarts.length; i++) {
      final day = dayStarts[i];
      final dayEnd = DateTime(day.year, day.month, day.day + 1, boundaryHour);
      final touchesDay =
          session.startedAt.isBefore(dayEnd) && sessionEnd.isAfter(day);
      if (touchesDay) {
        firstIndex ??= i;
        lastIndex = i;
      }
    }
    if (firstIndex != null && lastIndex != null) {
      annotations.add(
        VerticalRangeAnnotation(
          x1: firstIndex - 0.5,
          x2: lastIndex + 0.5,
          color: color,
        ),
      );
    }
  }
  return RangeAnnotations(verticalRangeAnnotations: annotations);
}

/// Alcohol-section overlay/bar tint — a shared warm accent (not the
/// Party-only emerald token; History is not a Party screen, so
/// [PartyColorTokens] must never appear here — design-system.md §Dark mode &
/// emerald quarantine).
Color alcoholAccent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? kColorWarningDark
        : kColorWarning;

// ---------------------------------------------------------------------------
// Alcoholic drinks-per-day chart
// ---------------------------------------------------------------------------

class _AlcoholicDrinksPerDayChart extends StatelessWidget {
  const _AlcoholicDrinksPerDayChart({
    required this.buckets,
    required this.dayStarts,
    required this.sessions,
    required this.boundaryHour,
    required this.mode,
    required this.onDayTap,
  });

  final List<DailyBucket> buckets;
  final List<DateTime> dayStarts;
  final List<PartySession> sessions;
  final int boundaryHour;
  final HistoryRangeMode mode;
  final ValueChanged<int> onDayTap;

  @override
  Widget build(BuildContext context) {
    final maxCount = buckets.fold(0, (m, b) => math.max(m, b.value));
    final maxY = math.max(maxCount, 1) * 1.2;
    final accent = alcoholAccent(context);

    return Semantics(
      container: true,
      label: '${SemanticsLabels.historyAlcoholicDrinksChartPrefix}'
          '${buckets.fold(0, (s, b) => s + b.value)} alcoholic drinks logged.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = _HydrationChart._barWidth(
            buckets.length,
            constraints.maxWidth,
          );
          return BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: barTouchDataForDayTap(
                onDayTap,
                touchExtraThreshold: fullColumnTouchExtraThreshold(
                  barWidth: barWidth,
                  bucketCount: buckets.length,
                  chartWidth: constraints.maxWidth,
                  leftReservedSize: 32,
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              rangeAnnotations: sessionOverlayAnnotations(
                dayStarts: dayStarts,
                sessions: sessions,
                boundaryHour: boundaryHour,
                color: accent.withAlpha(46),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 1,
                    getTitlesWidget: (value, meta) =>
                        value == value.roundToDouble()
                            ? Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              )
                            : const SizedBox.shrink(),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: mode == HistoryRangeMode.weekly ? 1 : 5,
                    getTitlesWidget: (value, meta) =>
                        dayLabel(dayStarts, value, mode),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < buckets.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: buckets[i].value.toDouble(),
                        width: barWidth,
                        borderRadius: BorderRadius.circular(3),
                        color: accent,
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Max estimated BAC-per-day chart
// ---------------------------------------------------------------------------

class _MaxBacChart extends StatelessWidget {
  const _MaxBacChart({
    required this.buckets,
    required this.dayStarts,
    required this.sessions,
    required this.boundaryHour,
    required this.capGPerL,
    required this.mode,
    required this.fmt,
    required this.onDayTap,
  });

  final List<BacDailyBucket> buckets;
  final List<DateTime> dayStarts;
  final List<PartySession> sessions;
  final int boundaryHour;
  final double? capGPerL;
  final HistoryRangeMode mode;
  final FormatService? fmt;
  final ValueChanged<int> onDayTap;

  @override
  Widget build(BuildContext context) {
    final maxValue = buckets.fold(
      0.0,
      (m, b) => math.max(m, b.maxGPerL ?? 0.0),
    );
    final maxY = math.max(math.max(maxValue, capGPerL ?? 0) * 1.25, 0.01);
    final accent = alcoholAccent(context);
    final daysWithSession = buckets.where((b) => b.maxGPerL != null).length;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: '${SemanticsLabels.historyMaxBacChartPrefix}'
          '$daysWithSession of ${buckets.length} days had a party session.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = _HydrationChart._barWidth(
            buckets.length,
            constraints.maxWidth,
          );
          return BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: barTouchDataForDayTap(
                onDayTap,
                touchExtraThreshold: fullColumnTouchExtraThreshold(
                  barWidth: barWidth,
                  bucketCount: buckets.length,
                  chartWidth: constraints.maxWidth,
                  leftReservedSize: 40,
                ),
                // features.md F4: "g/L ... with ... mmol/L shown alongside
                // in tooltips" — no-session (null) days have nothing to
                // show, so their transparent rod gets no tooltip.
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final value = groupIndex < buckets.length
                      ? buckets[groupIndex].maxGPerL
                      : null;
                  if (value == null) return null;
                  return BarTooltipItem(
                    '${value.toStringAsFixed(2)} g/L\n'
                    '≈ ${gPerLToMmol(value).toStringAsFixed(2)} mmol/L',
                    TextStyle(color: colorScheme.onSurface, fontSize: 11),
                  );
                },
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              rangeAnnotations: sessionOverlayAnnotations(
                dayStarts: dayStarts,
                sessions: sessions,
                boundaryHour: boundaryHour,
                color: accent.withAlpha(46),
              ),
              extraLinesData: capGPerL == null
                  ? const ExtraLinesData()
                  : ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: capGPerL!,
                          color: kColorError,
                          strokeWidth: 2,
                          dashArray: const [6, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: const TextStyle(
                              color: kColorError,
                              fontSize: 10,
                            ),
                            labelResolver: (_) =>
                                '${capGPerL!.toStringAsFixed(2)} g/L cap',
                          ),
                        ),
                      ],
                    ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        value.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: mode == HistoryRangeMode.weekly ? 1 : 5,
                    getTitlesWidget: (value, meta) =>
                        dayLabel(dayStarts, value, mode),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < buckets.length; i++)
                  _bacBarGroup(
                    i,
                    buckets[i],
                    capGPerL,
                    barWidth,
                    accent,
                    colorScheme,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static BarChartGroupData _bacBarGroup(
    int index,
    BacDailyBucket bucket,
    double? capGPerL,
    double barWidth,
    Color accent,
    ColorScheme colorScheme,
  ) {
    final value = bucket.maxGPerL;
    // "at or above cap" mirrors isApproachingCap's inclusive boundary
    // (core/bac.dart) — the conservative-estimate posture applied
    // consistently across the app.
    final isAboveCap = value != null && capGPerL != null && value >= capGPerL;
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: value ?? 0,
          width: barWidth,
          borderRadius: BorderRadius.circular(3),
          // No-session days get a transparent rod (F4: "no bar" — not a
          // visible zero) while still occupying this x position, so every
          // day stays tappable for the day drill-down.
          color: value == null
              ? Colors.transparent
              : (isAboveCap ? kColorError : accent),
          // Non-colour above-cap signal, mirroring the hydration chart's
          // below-goal border (Parity Rulebook §Non-colour-signal rules).
          borderSide: isAboveCap
              ? BorderSide(color: colorScheme.onSurface, width: 1.5)
              : BorderSide.none,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Semantics(
              label: SemanticsLabels.historyEmptyState,
              child: Text(
                'No drinks logged in this period',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log a drink or pick a different range to see it here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
