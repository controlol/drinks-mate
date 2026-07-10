import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../a11y/semantics_labels.dart';
import '../models/daily_bucket.dart';
import '../models/history_range.dart';
import '../models/user_preferences.dart';
import '../repository/providers.dart';
import '../services/format_service.dart';
import '../theme/color_tokens.dart';
import 'settings_screen.dart';

/// History tab — F4/S3: weekly/monthly range paging over the hydration
/// charts (issue #25). Alcohol charts (BAC, session overlay) land in #26.
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
              final isEmpty = totals.every((b) => b.value == 0);
              if (isEmpty) return const _EmptyState();
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
                    ),
                  ),
                  _ChartCard(
                    title: 'Drinks per day',
                    child: _DrinksPerDayChart(
                      buckets: counts,
                      mode: selection.mode,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
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
  });

  final List<DailyBucket> buckets;
  final int goalMl;
  final HistoryRangeMode mode;
  final FormatService? fmt;

  @override
  Widget build(BuildContext context) {
    final maxBarValue = buckets.fold(0, (m, b) => math.max(m, b.value));
    final maxY = (math.max(maxBarValue, goalMl) * 1.15).ceilToDouble();
    final belowGoalCount = buckets.where((b) => b.value < goalMl).length;
    final colorScheme = Theme.of(context).colorScheme;

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
              barTouchData: BarTouchData(enabled: false),
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
                        _dayLabel(buckets, value, mode),
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
  const _DrinksPerDayChart({required this.buckets, required this.mode});

  final List<DailyBucket> buckets;
  final HistoryRangeMode mode;

  @override
  Widget build(BuildContext context) {
    final maxCount = buckets.fold(0, (m, b) => math.max(m, b.value));
    final maxY = math.max(maxCount, 1) * 1.2;

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
              barTouchData: BarTouchData(enabled: false),
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
                        _dayLabel(buckets, value, mode),
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

Widget _dayLabel(
  List<DailyBucket> buckets,
  double value,
  HistoryRangeMode mode,
) {
  final index = value.round();
  if (index < 0 || index >= buckets.length) return const SizedBox.shrink();
  final day = buckets[index].dayStart;
  final text = mode == HistoryRangeMode.weekly
      ? DateFormat('E').format(day)
      : DateFormat('d').format(day);
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: const TextStyle(fontSize: 10)),
  );
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
