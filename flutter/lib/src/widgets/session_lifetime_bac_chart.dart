import 'package:core/core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../a11y/semantics_labels.dart';
import '../models/bac_chart_series.dart';

/// The History day drill-down's expanded session summary card's static BAC
/// chart (user-experience.md §S3 expand: "a static BAC line chart for the
/// session's full lifetime"). Unlike the Party tab's live chart
/// (`party_screen.dart`'s `_BacLineChartCard`), this has no tap-to-inspect
/// interaction and no cap-line/now-marker/dashed-projection — [series] is
/// expected to come from `buildSessionLifetimeBacSeries`, whose `projected`
/// is always empty.
class SessionLifetimeBacChart extends StatelessWidget {
  const SessionLifetimeBacChart({super.key, required this.series});

  final BacChartSeries series;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final axisMinutes =
        series.axisEnd.difference(series.axisStart).inMinutes.toDouble();
    final maxGPerL = series.actual.isEmpty
        ? 0.0
        : series.actual.map((p) => p.gPerL).reduce((a, b) => a > b ? a : b);
    final maxY = (maxGPerL * 1.2).clamp(0.1, double.infinity);

    return Semantics(
      label: SemanticsLabels.historySessionSummaryCardChart,
      container: true,
      child: SizedBox(
        height: 140,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: axisMinutes <= 0 ? 1 : axisMinutes,
            minY: 0,
            maxY: maxY.toDouble(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
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
                spots: [
                  for (final p in series.actual)
                    FlSpot(
                      p.time.difference(series.axisStart).inMinutes.toDouble(),
                      p.gPerL,
                    ),
                ],
                isCurved: false,
                color: colorScheme.primary,
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
