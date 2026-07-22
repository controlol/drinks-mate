import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../a11y/semantics_labels.dart';
import '../models/drink_entry.dart';
import '../models/user_preferences.dart';
import '../repository/providers.dart';
import '../services/format_service.dart';
import '../services/history_bac_service.dart';
import '../theme/motion_tokens.dart';
import '../theme/reduce_motion.dart';
import '../widgets/entry_edit_sheet.dart';
import '../widgets/entry_row.dart';
import '../widgets/session_summary_card.dart';
import 'party_session_log_screen.dart';

/// History day drill-down (F4/S3, issue #26; edit/delete added for #67;
/// swipe-to-change-day added for #128).
///
/// Reached by tapping a day bar on any History chart. Per
/// user-experience.md §S3, this is one of only two general-purpose editing
/// surfaces app-wide (alongside the S6 Today Drinks Log) — tapping a row
/// opens the edit sheet directly, and each row also carries a delete button
/// (see [EntryRow]), except an alcoholic drink attached to a Party Session
/// (`partySessionId` set), which renders fully read-only here; the S9
/// Party Session Log is the authoritative place to edit or delete those.
/// Editable fields: volume, name, ABV (alcoholic entries only), price, and
/// time — S3 is the only screen that additionally exposes name (unlike S6);
/// see [EntryEditSheet] for the shared edit-sheet implementation.
///
/// [dayStart]/[dayEnd] are the *initial* day shown — the exact day-window
/// instants (from `core`'s `dayWindow`/History bucketing), not just
/// calendar-day midnights, so the entry list and session overlap checks line
/// up with the chart's own day boundaries. Once open, a horizontal swipe
/// anywhere on the screen steps to the adjacent day via `core`'s
/// [pagedDayWindow], independent of the History range selector underneath
/// (design/user-experience.md §S3 "Swipe to change day").
class HistoryDayScreen extends ConsumerStatefulWidget {
  const HistoryDayScreen({
    super.key,
    required this.dayStart,
    required this.dayEnd,
  });

  final DateTime dayStart;
  final DateTime dayEnd;

  @override
  ConsumerState<HistoryDayScreen> createState() => _HistoryDayScreenState();
}

class _HistoryDayScreenState extends ConsumerState<HistoryDayScreen>
    with SingleTickerProviderStateMixin {
  static const double _swipeVelocityThreshold = 250;
  static const double _swipeDistanceThreshold = 60;
  static const double _resistanceExtent = 12;

  late DateTime _dayStart;
  late DateTime _dayEnd;

  // +1 while the most recent transition moved forward (to a later day), -1
  // while it moved backward; read by [_transitionBuilder] to slide the
  // outgoing/incoming pair in opposite directions.
  int _direction = 0;
  bool _isTransitioning = false;
  double _dragTotal = 0;

  // Attempting to swipe past a bound is a no-op with subtle resistance
  // rather than an error (design/user-experience.md §S3) — a small nudge in
  // the attempted direction, driven independently of the day-content switch.
  int _resistanceDirection = 0;
  late final AnimationController _resistanceController;
  late final Animation<double> _resistanceAnimation;

  @override
  void initState() {
    super.initState();
    _dayStart = widget.dayStart;
    _dayEnd = widget.dayEnd;
    _resistanceController = AnimationController(
      vsync: this,
      duration: MotionTokens.fast,
    );
    _resistanceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _resistanceController,
        curve: MotionTokens.easing,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant HistoryDayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dayStart != oldWidget.dayStart ||
        widget.dayEnd != oldWidget.dayEnd) {
      setState(() {
        _dayStart = widget.dayStart;
        _dayEnd = widget.dayEnd;
      });
    }
  }

  @override
  void dispose() {
    _resistanceController.dispose();
    super.dispose();
  }

  Duration get _transitionDuration =>
      ReduceMotion.isEnabled(context) ? Duration.zero : MotionTokens.standard;

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragTotal += details.delta.dx;
  }

  void _handleDragCancel() {
    _dragTotal = 0;
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final dx = _dragTotal;
    _dragTotal = 0;
    if (velocity.abs() < _swipeVelocityThreshold &&
        dx.abs() < _swipeDistanceThreshold) {
      return;
    }
    // Swipe left (negative dx/velocity) steps forward to the next day;
    // swipe right steps backward — the same left-is-forward convention as
    // a horizontal timeline.
    final forward = velocity != 0 ? velocity < 0 : dx < 0;
    _navigate(forward: forward);
  }

  void _navigate({required bool forward}) {
    if (_isTransitioning) return;
    final boundaryHour =
        ref.read(userPreferencesProvider).valueOrNull?.dayBoundaryHour ?? 5;
    final candidate = pagedDayWindow(
      now: _dayStart,
      offset: forward ? -1 : 1,
      boundaryHour: boundaryHour,
    );

    if (forward) {
      final today = dayWindow(now: DateTime.now(), boundaryHour: boundaryHour);
      if (candidate.$1.isAfter(today.$1)) {
        _playResistance(forward: true);
        return;
      }
    } else {
      final earliestBound =
          ref.read(historyEarliestDayBoundProvider).valueOrNull;
      if (earliestBound == null) {
        // Bound not resolved yet — block rather than risk paging past an
        // unknown floor; resolves near-instantly from the local DB.
        _playResistance(forward: false);
        return;
      }
      final earliestWindow = dayWindow(
        now: earliestBound,
        boundaryHour: boundaryHour,
      );
      if (candidate.$1.isBefore(earliestWindow.$1)) {
        _playResistance(forward: false);
        return;
      }
    }

    final duration = _transitionDuration;
    setState(() {
      _direction = forward ? 1 : -1;
      _dayStart = candidate.$1;
      _dayEnd = candidate.$2;
      _isTransitioning = true;
    });
    Future.delayed(duration, () {
      if (mounted) setState(() => _isTransitioning = false);
    });
  }

  void _playResistance({required bool forward}) {
    if (ReduceMotion.isEnabled(context)) return;
    _resistanceDirection = forward ? 1 : -1;
    _resistanceController.forward(from: 0);
  }

  Widget _transitionBuilder(Widget child, Animation<double> animation) {
    final isIncoming = child.key == ValueKey(_dayStart);
    final sign = _direction.toDouble();
    final beginX = isIncoming ? sign : -sign;
    return ClipRect(
      child: SlideTransition(
        position:
            Tween<Offset>(begin: Offset(beginX, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: MotionTokens.easing),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the backward-bound query warm so it's ready by the time the
    // user attempts a backward swipe.
    ref.watch(historyEarliestDayBoundProvider);
    final dateLabel = DateFormat('EEEE, MMM d').format(_dayStart);

    return Scaffold(
      appBar: AppBar(title: Text(dateLabel)),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: _handleDragCancel,
        child: AnimatedBuilder(
          animation: _resistanceAnimation,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              _resistanceAnimation.value *
                  _resistanceDirection *
                  _resistanceExtent,
              0,
            ),
            child: child,
          ),
          child: AnimatedSwitcher(
            duration: _transitionDuration,
            switchInCurve: Curves.linear,
            switchOutCurve: Curves.linear,
            transitionBuilder: _transitionBuilder,
            child: _HistoryDayContent(
              key: ValueKey(_dayStart),
              dayStart: _dayStart,
              dayEnd: _dayEnd,
            ),
          ),
        ),
      ),
    );
  }
}

/// The current day's content — extracted from [HistoryDayScreen] so it can
/// be swapped by an [AnimatedSwitcher] as the user swipes between days.
class _HistoryDayContent extends ConsumerWidget {
  const _HistoryDayContent({
    required super.key,
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

    return entriesAsync.when(
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
              SessionSummaryCard(
                summary: summary,
                expandable: true,
                multiDayPosition: sessionMultiDayPosition(
                  session: summary.session,
                  dayStart: dayStart,
                  boundaryHour: prefs?.dayBoundaryHour ?? 5,
                  // Reuses the same snapshot instant buildSessionDaySummary
                  // stamped this card's other data with (summary.asOf),
                  // rather than a fresh DateTime.now() at build time, so an
                  // active multi-day session can't show a pill computed
                  // against a different instant than its duration/grams.
                  now: summary.asOf ?? DateTime.now(),
                ),
                onViewFullSession: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PartySessionLogScreen(sessionId: summary.session.id),
                  ),
                ),
              ),
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
                      _DayEntryTile(entry: entry, fmt: fmt, prefs: prefs),
                  ],
                ),
              ),
          ],
        );
      },
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

class _DayEntryTile extends ConsumerWidget {
  const _DayEntryTile({required this.entry, required this.fmt, this.prefs});

  final DrinkEntry entry;
  final FormatService? fmt;
  final UserPreferences? prefs;

  /// Session-attached alcoholic entries are read-only here — the S9 Party
  /// Session Log is the single authoritative place to edit or delete them
  /// (design/user-experience.md §S3, mirroring §S6).
  bool get _isSessionAttached =>
      entry.beverageType.isAlcoholic && entry.partySessionId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EntryRow(
      entry: entry,
      fmt: fmt,
      onTap: _isSessionAttached ? null : () => _showEditSheet(context, ref),
      onDelete: _isSessionAttached ? null : () => _confirmDelete(context, ref),
    );
  }

  Future<void> _showEditSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntryEditSheet(
        entry: entry,
        showName: true,
        defaultCurrency: prefs?.currency,
        // Free, not day-locked — S3 is the historical-correction surface,
        // so unlike S6 it lets the user move an entry to a different day
        // (e.g. a drink logged just after midnight that should count for
        // the previous day). Bounded to "never the future" by
        // DateEditPicker.free's default; no lower bound.
        datePicker: const DateEditPicker.free(),
        onSave: ({
          required volumeMl,
          name,
          abvPercent,
          required priceMinor,
          required currency,
          required consumedAt,
        }) =>
            ref.read(drinksRepositoryProvider).updateDrinkEntry(
                  id: entry.id,
                  volumeMl: volumeMl,
                  name: name,
                  abvPercent: abvPercent,
                  priceMinor: priceMinor,
                  currency: currency,
                  consumedAt: consumedAt,
                ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
          'Remove "${entry.name ?? 'this drink'}" from this day\'s log? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(drinksRepositoryProvider).deleteDrinkEntry(entry.id);
    }
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
