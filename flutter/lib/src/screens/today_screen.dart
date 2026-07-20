import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../a11y/semantics_labels.dart';
import '../models/beverage_type.dart';
import '../models/drink_preset.dart';
import '../repository/providers.dart';
import '../services/format_service.dart';
import '../theme/app_theme.dart';
import '../utils/color_utils.dart';
import '../widgets/goal_celebration_overlay.dart';
import 'log_drink_sheet.dart';
import 'party_session_flows.dart';
import 'settings_screen.dart';
import 'today_drinks_screen.dart';

/// Today tab — F3 home screen (issue #13; Log-a-drink grid: issue #78).
///
/// Layout, below [kTabletBreakpointWidth] (top to bottom):
///   1. Progress card — intake vs goal, pace tick, status pill (taps → S6 log).
///   2. Stat card pair — 7-day daily average and days-on-goal n/7.
///   3. Log-a-drink section — sort-mode dropdown + a vertically-scrolling
///      grid of the top [kLogADrinkGridSize] presets by the selected mode
///      (Manual / Recently used / Most used — F14 §Sort modes).
///   4. "Log drink" button — full-width, opens S2 sheet.
///
/// At or above [kTabletBreakpointWidth], 1–2 sit in a left column beside the
/// Log-a-drink section on the right, with the "Log drink" button still
/// full-width at the bottom (user-experience.md §Responsive layout).
///
/// Also listens for the first intake-crosses-goal event each day and shows
/// the full-screen [GoalCelebrationOverlay] (issue #14).
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  @override
  Widget build(BuildContext context) {
    // Detect first upward crossing of the daily goal within the current day.
    ref.listen<AsyncValue<int>>(todayTotalMlProvider, (prev, next) async {
      // Skip the very first emission (prev == null = cold open, no crossing).
      if (prev == null) return;

      final prevMl = prev.valueOrNull ?? 0;
      final currentMl = next.valueOrNull;
      if (currentMl == null) return;

      final prefs = ref.read(userPreferencesProvider).valueOrNull;
      if (prefs == null) return;

      // Only trigger on upward crossing (prev < goal AND current >= goal).
      if (prevMl >= prefs.dailyGoalMl || currentMl < prefs.dailyGoalMl) return;

      // Capture the navigator BEFORE any await so we hold a NavigatorState
      // (not a BuildContext) across the async gap — satisfies
      // use_build_context_synchronously without needing context after awaits.
      if (!mounted) return;
      final nav = Navigator.of(context);

      final now = DateTime.now();
      final dayStart = dayWindow(
        now: now,
        boundaryHour: prefs.dayBoundaryHour,
      ).$1;

      final guard = ref.read(goalCelebrationGuardProvider);
      final shouldShow = await guard.shouldShowForDay(dayStart);
      if (!shouldShow) return;

      await guard.markShownForDay(dayStart);
      if (!mounted) return;

      // Push onto the root navigator so the overlay covers the tab bar.
      // NavigatorState (nav) — not BuildContext — is used after the awaits.
      unawaited(
        nav.push<void>(
          RawDialogRoute<void>(
            pageBuilder: (ctx, _, __) =>
                GoalCelebrationOverlay(onDismissed: () => nav.pop()),
            barrierDismissible: false,
            barrierLabel: 'Goal celebration',
            barrierColor: Colors.transparent,
            transitionDuration: Duration.zero,
          ),
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [_settingsButton(context, ref)],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Tablet/desktop: the Log-a-drink section sits beside the progress
          // + stat cards instead of below them (user-experience.md
          // §Responsive layout; breakpoint chosen to match Material's
          // "expanded" window-size class, ≥840dp — see the PR description
          // for the full breakpoint table).
          final isWide = constraints.maxWidth >= kTabletBreakpointWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isWide)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ProgressCard(),
                            const SizedBox(height: 12),
                            _StatCardRow(),
                          ],
                        ),
                      ),
                      Expanded(child: _LogADrinkSection()),
                    ],
                  ),
                )
              else ...[
                _ProgressCard(),
                const SizedBox(height: 12),
                _StatCardRow(),
                Expanded(child: _LogADrinkSection()),
              ],
              _LogDrinkButton(),
            ],
          );
        },
      ),
    );
  }
}

/// Below this width, the Today screen stacks the Log-a-drink section under
/// the progress/stat cards; at or above it, they sit side by side. Matches
/// Material's "expanded" window-size-class threshold (≥840dp) — a
/// reasonable, documented choice per the issue's `[OPEN]` breakpoint note,
/// not a value pinned by the design docs.
const double kTabletBreakpointWidth = 840;

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
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const TodayDrinksScreen()),
          ),
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
// Log-a-drink section — responsive grid + sort-mode dropdown (F3/F14 §Sort
// modes, issue #78). Replaces the old horizontally-scrolling quick-log row.
// ---------------------------------------------------------------------------

/// Number of grid columns for a given *available width* (not necessarily the
/// full screen width — on the tablet/desktop split layout this section gets
/// roughly half the screen). The 600dp tier matches Material's "compact"
/// window-size-class threshold (the same family [kTabletBreakpointWidth]'s
/// 840dp "expanded" threshold is drawn from); 900dp has no such source —
/// see that constant's doc comment:
///   < 600dp  -> 2 columns (phone)
///   600–899  -> 3 columns (wide phone / the tablet-desktop side panel)
///   >= 900dp -> 4 columns (a full-width tablet/desktop grid)
int _gridColumnsForWidth(double width) {
  if (width >= 900) return 4;
  if (width >= 600) return 3;
  return 2;
}

/// How many top-ranked presets the grid shows (features.md F14 §Sort modes).
const int kLogADrinkGridSize = 8;

class _LogADrinkSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(rankedVisiblePresetsProvider);
    final mode =
        ref.watch(userPreferencesProvider).valueOrNull?.drinkSortMode ??
            PresetSortMode.recentlyUsed;
    final shown = presets.take(kLogADrinkGridSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Log a drink',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _SortModeDropdown(
                mode: mode,
                onChanged: (newMode) => ref
                    .read(preferencesRepositoryProvider)
                    .updateDrinkSortMode(newMode),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = _gridColumnsForWidth(constraints.maxWidth);
                return GridView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (context, i) => _LogADrinkTile(preset: shown[i]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SortModeDropdown extends StatelessWidget {
  const _SortModeDropdown({required this.mode, required this.onChanged});

  final PresetSortMode mode;
  final ValueChanged<PresetSortMode> onChanged;

  static const _labels = {
    PresetSortMode.manual: 'Manual',
    PresetSortMode.recentlyUsed: 'Recently used',
    PresetSortMode.mostUsed: 'Most used',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: SemanticsLabels.sortModeSelector,
      child: DropdownButton<PresetSortMode>(
        value: mode,
        underline: const SizedBox.shrink(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        items: [
          for (final entry in _labels.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
      ),
    );
  }
}

class _LogADrinkTile extends ConsumerWidget {
  const _LogADrinkTile({required this.preset});

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
    // party-session.md §Logging from Today: an alcoholic drink attaches to
    // an already-active session directly, instead of logging as an orphan.
    final activeSession = preset.beverageType.isAlcoholic
        ? ref.read(activePartySessionProvider).valueOrNull
        : null;
    try {
      final String entryId;
      if (activeSession != null) {
        final partyRepo = ref.read(partySessionRepositoryProvider);
        final resolved = await partyRepo.resolvePrice(
          session: activeSession,
          preset: preset,
        );
        final entry = await partyRepo.logAlcoholicDrink(
          preset: preset,
          sessionId: activeSession.id,
          priceMinor: resolved.priceMinor,
          currency: resolved.currency,
          priceTokens: resolved.priceTokens,
          tokenValueMinor: resolved.tokenValueMinor,
          tokenValueCurrency: resolved.tokenValueCurrency,
        );
        entryId = entry.id;
      } else {
        entryId =
            await ref.read(drinksRepositoryProvider).logDrink(preset: preset);
      }
      if (context.mounted) {
        _showLoggedSnackBar(
          context,
          ref,
          entryId: entryId,
          name: preset.name,
          beverageType: preset.beverageType,
          // Already awaited above — nothing left to race an Undo tap
          // against.
          pendingWrite: Future.value(),
          hasActiveSession: activeSession != null,
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

class _LogDrinkButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          onPressed: () => _openSheet(context, ref),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final logged = await showModalBottomSheet<LoggedDrinkResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const LogDrinkSheet(),
    );
    if (logged != null && context.mounted) {
      _showLoggedSnackBar(
        context,
        ref,
        entryId: logged.id,
        name: logged.name,
        beverageType: logged.beverageType,
        pendingWrite: logged.pendingWrite,
        hasActiveSession: logged.attachedToSession,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Shared "Logged {name}" toast for both the grid-tile tap and the S2
/// confirm path (user-experience.md §S1: "The `Logged` toast ... after any
/// preset-tile tap in the 'Log a drink' grid or successful S2 confirm").
///
/// Non-alcoholic entries, and alcoholic entries attached to an already-active
/// Party Session, get an inline Undo that soft-deletes the entry — after
/// [pendingWrite] settles, since C6 shows this toast before the write lands
/// and an instant Undo tap could otherwise race the insert. An alcoholic
/// entry logged with **no** active session (an orphan) gets a "Start
/// session" action in that slot instead — a toast only cleanly fits one
/// action (party-session.md §Logging from Today).
void _showLoggedSnackBar(
  BuildContext context,
  WidgetRef ref, {
  required String entryId,
  required String name,
  required BeverageType beverageType,
  required Future<void> pendingWrite,
  required bool hasActiveSession,
}) {
  final offerStartSession = beverageType.isAlcoholic && !hasActiveSession;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Logged $name'),
      duration: const Duration(seconds: 4),
      // SnackBar.persist defaults to (action != null) when omitted, which
      // makes ScaffoldMessenger's auto-hide timer no-op for every call site
      // here since they all attach an action. Force it false so the 4s
      // auto-dismiss (user-experience.md §S1) always applies.
      persist: false,
      action: offerStartSession
          ? SnackBarAction(
              label: 'Start session',
              onPressed: () => startPartySessionFlow(context, ref),
            )
          : SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await pendingWrite;
                await ref
                    .read(drinksRepositoryProvider)
                    .deleteDrinkEntry(entryId);
              },
            ),
    ),
  );
}

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
