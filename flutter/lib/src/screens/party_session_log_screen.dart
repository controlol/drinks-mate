import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../a11y/semantics_labels.dart';
import '../models/drink_entry.dart';
import '../models/meal.dart';
import '../models/party_session.dart';
import '../repository/providers.dart';
import '../services/bac_estimator.dart';
import '../services/format_service.dart';
import '../services/meal_format.dart';
import '../widgets/entry_edit_sheet.dart';
import '../widgets/entry_row.dart';
import '../widgets/session_summary_card.dart';
import 'party_log_drink_sheet.dart';
import 'party_session_flows.dart';

/// A row in S9's merged entry list — either a [DrinkEntry] or a [Meal],
/// interleaved chronologically (user-experience.md §S9: "merged with the
/// meals logged during it").
sealed class _LogItem {
  DateTime get time;
}

class _DrinkItem extends _LogItem {
  _DrinkItem(this.entry);

  final DrinkEntry entry;

  @override
  DateTime get time => entry.consumedAt;
}

class _MealItem extends _LogItem {
  _MealItem(this.meal);

  final Meal meal;

  @override
  DateTime get time => meal.eatenAt;
}

/// Merges [entries] and [meals] into one newest-first list (user-experience.md
/// §S9: "newest first"). [List.sort] isn't guaranteed stable, so two items
/// sharing an identical timestamp are tie-broken by their original position
/// (drinks before meals, each in [entries]/[meals] order) rather than left
/// to vary run to run.
List<_LogItem> _mergeEntriesAndMeals(
  List<DrinkEntry> entries,
  List<Meal> meals,
) {
  final items = <_LogItem>[
    for (final entry in entries) _DrinkItem(entry),
    for (final meal in meals) _MealItem(meal),
  ];
  final originalIndex = {for (final (i, item) in items.indexed) item: i};
  items.sort((a, b) {
    final byTime = b.time.compareTo(a.time);
    return byTime != 0 ? byTime : originalIndex[a]! - originalIndex[b]!;
  });
  return items;
}

/// S9 — Party Session Log (user-experience.md §S9).
///
/// One screen serves both an active session (editable — tapping a row opens
/// the edit sheet directly, and each row also carries a delete button; see
/// [EntryRow]) and any ended session (fully read-only). [sessionId]
/// identifies the session; mode is derived reactively from whether it
/// matches the currently-active session, so a session ending while this
/// screen is open switches it to read-only rather than requiring a fresh
/// navigation.
class PartySessionLogScreen extends ConsumerWidget {
  const PartySessionLogScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activePartySessionProvider).valueOrNull;
    final isActive = activeSession != null && activeSession.id == sessionId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Party Session Log'),
        // No delete affordance on the active session — party-session.md
        // §Deleting a session: "there is no delete affordance on the active
        // session; end it first."
        actions: [if (!isActive) _DeleteSessionButton(sessionId: sessionId)],
      ),
      body: isActive
          ? _ActiveLog(session: activeSession)
          : _EndedLog(sessionId: sessionId),
    );
  }
}

class _DeleteSessionButton extends ConsumerWidget {
  const _DeleteSessionButton({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: SemanticsLabels.deleteSessionButton,
      button: true,
      excludeSemantics: true,
      child: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete',
        onPressed: () async {
          final summary = await ref.read(
            partySessionSummaryProvider(sessionId).future,
          );
          if (!context.mounted) return;
          final deleted = await confirmDeleteSession(
            context,
            ref,
            summary.session,
          );
          if (deleted && context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active mode
// ---------------------------------------------------------------------------

class _ActiveLog extends ConsumerWidget {
  const _ActiveLog({required this.session});

  final PartySession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(partySessionEntriesProvider(session.id));
    final mealsAsync = ref.watch(partySessionMealsProvider(session.id));
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final fmt = ref.watch(formatServiceProvider);
    final defaultCurrency =
        ref.watch(userPreferencesProvider).valueOrNull?.currency;

    if (profile == null ||
        profile.birthDate == null ||
        !entriesAsync.hasValue ||
        !mealsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final alcoholicEntries = entriesAsync.requireValue
        .where((e) => e.beverageType.isAlcoholic)
        .toList();
    final meals = mealsAsync.requireValue;
    // partySessionEntriesProvider is oldest-first; S9 wants newest-first
    // (user-experience.md §S9) — _mergeEntriesAndMeals re-sorts, so the
    // provider's own ordering doesn't matter here.
    final mergedItems = _mergeEntriesAndMeals(alcoholicEntries, meals);
    final estimate = estimateSessionBac(
      profile: profile,
      alcoholicEntries: alcoholicEntries,
      meals: meals,
      at: now,
    );
    final elapsed = now.difference(session.startedAt);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _ActiveHeader(
          estimate: estimate,
          drinksCount: alcoholicEntries.length,
          elapsed: elapsed,
        ),
        const SizedBox(height: 20),
        if (alcoholicEntries.isEmpty) _EmptyActiveState(session: session),
        if (mergedItems.isNotEmpty)
          Semantics(
            label: SemanticsLabels.partySessionEntryList,
            container: true,
            child: Column(
              children: [
                for (final item in mergedItems)
                  switch (item) {
                    _DrinkItem(:final entry) => _EntryRow(
                        entry: entry,
                        active: true,
                        sessionStartedAt: session.startedAt,
                        fmt: fmt,
                        defaultCurrency: defaultCurrency,
                      ),
                    _MealItem(:final meal) => _MealRow(meal: meal, now: now),
                  },
              ],
            ),
          ),
      ],
    );
  }
}

class _ActiveHeader extends StatelessWidget {
  const _ActiveHeader({
    required this.estimate,
    required this.drinksCount,
    required this.elapsed,
  });

  final BacEstimate estimate;
  final int drinksCount;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final gPerLText = estimate.gPerL.toStringAsFixed(2);
    final mmolText = estimate.mmolPerL.toStringAsFixed(2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '≈ $mmolText mmol/L',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$drinksCount alcoholic ${drinksCount == 1 ? 'drink' : 'drinks'} '
              'this session',
            ),
            Text('Elapsed: ${_formatElapsed(elapsed)}'),
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

class _EmptyActiveState extends ConsumerWidget {
  const _EmptyActiveState({required this.session});

  final PartySession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.local_bar_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Semantics(
            label: SemanticsLabels.partySessionEmptyState,
            child: Text(
              'No alcoholic drinks logged in this session yet',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: SemanticsLabels.logAlcoholButton,
            button: true,
            excludeSemantics: true,
            child: FilledButton(
              onPressed: () => _openLogAlcoholSheet(context, ref, session),
              child: const Text('Log alcohol'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLogAlcoholSheet(
    BuildContext context,
    WidgetRef ref,
    PartySession session,
  ) async {
    final selection = await showModalBottomSheet<AlcoholicDrinkSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PartyLogDrinkSheet(),
    );
    if (selection == null || !context.mounted) return;
    await logAlcoholicDrinkIntoSession(context, ref, session, selection);
  }
}

// ---------------------------------------------------------------------------
// Ended mode
// ---------------------------------------------------------------------------

class _EndedLog extends ConsumerWidget {
  const _EndedLog({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(partySessionSummaryProvider(sessionId));
    final entriesAsync = ref.watch(partySessionEntriesProvider(sessionId));
    final mealsAsync = ref.watch(partySessionMealsProvider(sessionId));
    final fmt = ref.watch(formatServiceProvider);
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Could not load this session.')),
      data: (summary) {
        final entries = entriesAsync.valueOrNull ?? const <DrinkEntry>[];
        final alcoholicEntries =
            entries.where((e) => e.beverageType.isAlcoholic).toList();
        final meals = mealsAsync.valueOrNull ?? const <Meal>[];
        final mergedItems = _mergeEntriesAndMeals(alcoholicEntries, meals);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            SessionSummaryCard(
              summary: summary,
              expandable: true,
              onEditName: () =>
                  showEditSessionNameDialog(context, ref, summary.session),
            ),
            const SizedBox(height: 20),
            if (alcoholicEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Semantics(
                    label: SemanticsLabels.partySessionEmptyState,
                    child: Text(
                      'No alcoholic drinks were logged in this session',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            if (mergedItems.isNotEmpty)
              Semantics(
                label: SemanticsLabels.partySessionEntryList,
                container: true,
                child: Column(
                  children: [
                    for (final item in mergedItems)
                      switch (item) {
                        _DrinkItem(:final entry) => _EntryRow(
                            entry: entry,
                            active: false,
                            fmt: fmt,
                          ),
                        _MealItem(:final meal) => _MealRow(
                            meal: meal,
                            now: now,
                          ),
                      },
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
// Entry row (shared)
// ---------------------------------------------------------------------------

class _EntryRow extends ConsumerWidget {
  const _EntryRow({
    required this.entry,
    required this.active,
    this.sessionStartedAt,
    this.fmt,
    this.defaultCurrency,
  });

  final DrinkEntry entry;
  final bool active;
  final FormatService? fmt;

  /// The session's `startedAt` — bounds the edit sheet's free date picker to
  /// `[sessionStartedAt, now]`, so a session-attached entry can never be
  /// moved outside its own session's window (which would break that
  /// session's BAC/duration math). Only meaningful (and only read) when
  /// [active] is true — ended-mode rows never open the edit sheet, so
  /// [_EndedLog] passes nothing here.
  final DateTime? sessionStartedAt;

  /// The user's preferred currency — falls back for a first-time price entry
  /// on an entry logged with no price/currency yet (mirrors S6/S3's wiring
  /// of the same field through [EntryEditSheet]). Only meaningful when
  /// [active] is true, same as [sessionStartedAt].
  final String? defaultCurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EntryRow(
      entry: entry,
      fmt: fmt,
      onTap: active ? () => _showEditSheet(context, ref) : null,
      onDelete: active ? () => _confirmDelete(context, ref) : null,
    );
  }

  Future<void> _showEditSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntryEditSheet(
        entry: entry,
        defaultCurrency: defaultCurrency,
        // Bounded to this session's own window — never unbounded, unlike
        // S3's DateEditPicker.free() — since moving a session-attached
        // entry outside [session.startedAt, now] would break that
        // session's BAC/duration math.
        datePicker: DateEditPicker.free(
          minDate: sessionEditMinDate(
            sessionStartedAt: sessionStartedAt,
            entryConsumedAt: entry.consumedAt,
          ),
          maxDate: DateTime.now(),
        ),
        onSave: ({
          required volumeMl,
          name,
          abvPercent,
          required priceMinor,
          required currency,
          required consumedAt,
        }) =>
            ref.read(partySessionRepositoryProvider).updateAlcoholicEntry(
                  id: entry.id,
                  volumeMl: volumeMl,
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
          'Remove "${entry.name ?? 'this drink'}" from this session? This '
          'cannot be undone.',
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
    // Same soft-delete semantic as S6 — deleting an absorbed orphan
    // permanently removes the drink rather than reverting it to orphan
    // status (user-experience.md §S9), since deletion never touches
    // `partySessionId`.
    if (confirmed == true) {
      await ref.read(drinksRepositoryProvider).deleteDrinkEntry(entry.id);
    }
  }
}

/// A meal merged into S9's entry list (user-experience.md §S9: "visually
/// distinct (meal icon, size, and time)"). Always display-only — no tap or
/// delete affordance, in either session mode; meals stay editable only from
/// the Party tab's meal indicator.
class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, required this.now});

  final Meal meal;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final label = '${mealSizeLabel(meal.size)} meal';
    final timeLabel = relativeTimeAgo(meal.eatenAt, now);
    final primary = Theme.of(context).colorScheme.primary;

    return Semantics(
      label: '$label, $timeLabel',
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primary.withAlpha(38),
          child: Icon(Icons.restaurant_outlined, color: primary, size: 22),
        ),
        title: Text(label),
        subtitle: Text(timeLabel),
      ),
    );
  }
}

/// The lower bound for S9's edit-sheet date picker — the **earlier** of
/// [sessionStartedAt] and [entryConsumedAt], not [sessionStartedAt] alone.
///
/// An absorbed orphan drink can predate the session it was absorbed into
/// (party-session.md §Absorbing orphan drinks — "absorbed orphans extend
/// backwards in time"), so clamping every entry's lower bound to session
/// start would make an orphan's existing pre-session timestamp both
/// unreachable in the picker and force-moved forward the moment the sheet
/// opens. Taking the entry's own timestamp as a floor when it's already
/// earlier preserves that case, while a normal (non-orphan) entry — whose
/// `consumedAt` is never before `sessionStartedAt` — still gets
/// [sessionStartedAt] as its floor, exactly as intended.
///
/// Returns null (meaning [DateEditPicker.free]'s own default, `2000-01-01`)
/// when [sessionStartedAt] is null — [_EndedLog] rows, where editing is
/// unreachable, are the only case that passes null.
DateTime? sessionEditMinDate({
  required DateTime? sessionStartedAt,
  required DateTime entryConsumedAt,
}) {
  if (sessionStartedAt == null) return null;
  return entryConsumedAt.isBefore(sessionStartedAt)
      ? entryConsumedAt
      : sessionStartedAt;
}
