import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../a11y/semantics_labels.dart';
import '../models/drink_preset.dart';
import '../repository/providers.dart';
import '../services/format_service.dart';
import '../theme/app_theme.dart';
import '../utils/color_utils.dart';
import 'log_drink_sheet.dart';
import 'settings_screen.dart';

/// Today tab — F3 home screen (issue #13).
///
/// Layout (top to bottom):
///   1. Progress card — intake vs goal, pace tick, status pill (taps → S6 log).
///   2. Stat card pair — 7-day daily average and days-on-goal n/7.
///   3. Quick-log row — horizontally scrollable preset shortcuts.
///   4. "Log drink" button — full-width, opens S2 sheet.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [_settingsButton(context)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProgressCard(),
          const SizedBox(height: 12),
          _StatCardRow(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Quick log',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          _QuickLogRow(),
          const Spacer(),
          _LogDrinkButton(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress card
// ---------------------------------------------------------------------------

class _ProgressCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(todayTotalMlProvider);
    final prefsAsync = ref.watch(userPreferencesProvider);
    final fmt = ref.watch(formatServiceProvider);

    final prefs = prefsAsync.valueOrNull;
    final totalMl = totalAsync.valueOrNull ?? 0;
    if (prefs == null) return const _ProgressCardSkeleton();

    // Compute pace tick position and status pill from active-window formula.
    // active_start = date(dayWindow.$1) at reminderStartHour:00
    // active_end   = date(dayWindow.$1) at reminderEndHour:00
    // Source: notifications.md §Recommended volume; Parity Rulebook §Expected intake.
    final now = DateTime.now();
    final dayStart = dayWindow(
      now: now,
      boundaryHour: prefs.dayBoundaryHour,
    ).$1;
    final activeStart = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day,
      prefs.reminderStartHour,
    );
    final activeEnd = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day,
      prefs.reminderEndHour,
    );
    final activeWindowMin = activeEnd.difference(activeStart).inMinutes;
    final elapsedMin = now.difference(activeStart).inMinutes;
    final goalMl = prefs.dailyGoalMl.toDouble();

    final expectedMl = expectedIntakeMl(
      goalMl: goalMl,
      elapsedActiveMin: elapsedMin,
      activeWindowMin: activeWindowMin,
    );

    final intakeMl = totalMl.toDouble();
    final fillFraction = goalMl > 0 ? (intakeMl / goalMl).clamp(0.0, 1.0) : 0.0;
    final tickFraction =
        goalMl > 0 ? (expectedMl / goalMl).clamp(0.0, 1.0) : 0.0;
    final status = goalMl > 0
        ? paceStatus(intakeMl: intakeMl, expectedMl: expectedMl, goalMl: goalMl)
        : PaceStatus.onPace;

    final intakeText = fmt?.formatLargeVolume(intakeMl) ?? '$totalMl ml';
    final goalText = fmt?.formatLargeVolume(goalMl) ?? '${goalMl.round()} ml';

    return Semantics(
      label: SemanticsLabels.progressCard,
      button: true,
      excludeSemantics: true,
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            /* TODO: navigate to S6 Today Drinks Log */
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProgressCardHeader(
                  intakeText: intakeText,
                  goalText: goalText,
                  status: status,
                ),
                const SizedBox(height: 16),
                _PaceProgressBar(
                  fillFraction: fillFraction,
                  tickFraction: tickFraction,
                  isBehind: status == PaceStatus.behind,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressCardSkeleton extends StatelessWidget {
  const _ProgressCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SizedBox(height: 104),
    );
  }
}

class _ProgressCardHeader extends StatelessWidget {
  const _ProgressCardHeader({
    required this.intakeText,
    required this.goalText,
    required this.status,
  });

  final String intakeText;
  final String goalText;
  final PaceStatus status;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                intakeText,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '/ $goalText',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusPill(status: status),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final PaceStatus status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;
    switch (status) {
      case PaceStatus.behind:
        label = 'Behind';
        bg = kColorWarning.withAlpha(38); // ~15% opacity
        fg = kColorWarning;
      case PaceStatus.onPace:
        label = 'On pace';
        bg = Theme.of(context).colorScheme.primaryContainer;
        fg = Theme.of(context).colorScheme.onPrimaryContainer;
      case PaceStatus.ahead:
        // Goal reached — use success/green to distinguish from "On pace".
        // Parity Rulebook §Non-colour-signal rules: goal-met requires icon + text.
        label = 'Ahead';
        bg = kColorSuccess.withAlpha(38); // ~15% opacity
        fg = kColorSuccess;
    }

    // Goal-met (ahead) renders icon + text per Rulebook §Non-colour-signal rules.
    // Other states (on pace, behind) use text label only — Rulebook permits this.
    final Widget content = status == PaceStatus.ahead
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: fg),
              ),
            ],
          )
        : Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
          );

    return Semantics(
      label: '${SemanticsLabels.statusPill}: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: content,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress bar with pace tick
// ---------------------------------------------------------------------------

class _PaceProgressBar extends StatelessWidget {
  const _PaceProgressBar({
    required this.fillFraction,
    required this.tickFraction,
    required this.isBehind,
  });

  final double fillFraction;
  final double tickFraction;
  final bool isBehind;

  @override
  Widget build(BuildContext context) {
    final fillColor =
        isBehind ? kColorWarning : Theme.of(context).colorScheme.primary;
    final trackColor = Theme.of(context).colorScheme.outlineVariant;
    return SizedBox(
      height: 10,
      child: CustomPaint(
        painter: _ProgressBarPainter(
          fillFraction: fillFraction,
          tickFraction: tickFraction,
          fillColor: fillColor,
          trackColor: trackColor,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  const _ProgressBarPainter({
    required this.fillFraction,
    required this.tickFraction,
    required this.fillColor,
    required this.trackColor,
  });

  final double fillFraction;
  final double tickFraction;
  final Color fillColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(5);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      radius,
    );

    // Track.
    canvas.drawRRect(rrect, Paint()..color = trackColor);

    // Fill (clipped to the rounded track).
    if (fillFraction > 0) {
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * fillFraction, size.height),
        Paint()..color = fillColor,
      );
      canvas.restore();
    }

    // Pace tick — white, drawn last so it sits on top of fill and track.
    // Non-fill-colour treatment per Parity Rulebook §Non-colour-signal rules.
    final tickX = size.width * tickFraction;
    canvas.drawLine(
      Offset(tickX, 0),
      Offset(tickX, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ProgressBarPainter old) =>
      old.fillFraction != fillFraction ||
      old.tickFraction != tickFraction ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor;
}

// ---------------------------------------------------------------------------
// 7-day stat cards
// ---------------------------------------------------------------------------

class _StatCardRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avgAsync = ref.watch(sevenDayAverageMlProvider);
    final daysAsync = ref.watch(sevenDayDaysOnGoalProvider);
    final fmt = ref.watch(formatServiceProvider);

    final avgMl = avgAsync.valueOrNull ?? 0.0;
    final avgText = fmt?.formatLargeVolume(avgMl) ?? '${avgMl.round()} ml';
    final days = daysAsync.valueOrNull ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: '7-day avg',
              value: avgText,
              semanticsLabel: SemanticsLabels.sevenDayAverage,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Days on goal',
              value: '$days/7',
              semanticsLabel: SemanticsLabels.daysOnGoal,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.semanticsLabel,
  });

  final String label;
  final String value;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick-log row
// ---------------------------------------------------------------------------

class _QuickLogRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(visiblePresetsProvider);
    return SizedBox(
      height: 96,
      child: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (presets) {
          final shown = presets.take(5).toList();
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _QuickLogTile(preset: shown[i]),
          );
        },
      ),
    );
  }
}

class _QuickLogTile extends ConsumerWidget {
  const _QuickLogTile({required this.preset});

  final DrinkPreset preset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: '${SemanticsLabels.quickLogPrefix}${preset.name}',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _quickLog(context, ref),
        child: Container(
          width: 80,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_drink_outlined,
                size: 28,
                color: parseIconColor(preset.iconColor),
              ),
              const SizedBox(height: 4),
              Text(
                preset.name,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickLog(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(drinksRepositoryProvider).logDrink(preset: preset);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged ${preset.name}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to log drink')));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Log drink button
// ---------------------------------------------------------------------------

class _LogDrinkButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Semantics(
        label: SemanticsLabels.logDrinkButton,
        button: true,
        excludeSemantics: true,
        child: FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Log drink'),
          onPressed: () => _openSheet(context),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const LogDrinkSheet(),
    );
    if (logged == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Drink logged'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _settingsButton(BuildContext context) => IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Settings',
      onPressed: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      ),
    );
