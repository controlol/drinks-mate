import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../a11y/semantics_labels.dart';
import '../models/drink_entry.dart';
import '../models/party_session.dart';
import '../repository/providers.dart';
import '../services/bac_estimator.dart';
import '../utils/color_utils.dart';
import '../widgets/entry_edit_sheet.dart';
import '../widgets/session_summary_card.dart';
import 'party_log_drink_sheet.dart';
import 'party_session_flows.dart';

/// S9 — Party Session Log (user-experience.md §S9).
///
/// One screen serves both an active session (editable) and any ended session
/// (read-only). [sessionId] identifies the session; mode is derived
/// reactively from whether it matches the currently-active session, so a
/// session ending while this screen is open switches it to read-only rather
/// than requiring a fresh navigation.
class PartySessionLogScreen extends ConsumerWidget {
  const PartySessionLogScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activePartySessionProvider).valueOrNull;
    final isActive = activeSession != null && activeSession.id == sessionId;

    return Scaffold(
      appBar: AppBar(title: const Text('Party Session Log')),
      body: isActive
          ? _ActiveLog(session: activeSession)
          : _EndedLog(sessionId: sessionId),
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

    if (profile == null ||
        profile.birthDate == null ||
        !entriesAsync.hasValue ||
        !mealsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    // partySessionEntriesProvider is oldest-first; S9 wants newest-first
    // (user-experience.md §S9).
    final alcoholicEntries = entriesAsync.requireValue
        .where((e) => e.beverageType.isAlcoholic)
        .toList();
    final displayEntries = alcoholicEntries.reversed.toList();
    final estimate = estimateSessionBac(
      profile: profile,
      alcoholicEntries: alcoholicEntries,
      meals: mealsAsync.requireValue,
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
        if (displayEntries.isEmpty)
          _EmptyActiveState(session: session)
        else
          Semantics(
            label: SemanticsLabels.partySessionEntryList,
            container: true,
            child: Column(
              children: [
                for (final entry in displayEntries)
                  _EntryRow(
                    entry: entry,
                    active: true,
                    sessionStartedAt: session.startedAt,
                  ),
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

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Could not load this session.')),
      data: (summary) {
        final entries = entriesAsync.valueOrNull ?? const <DrinkEntry>[];
        final alcoholicEntries =
            entries.where((e) => e.beverageType.isAlcoholic).toList();
        final displayEntries = alcoholicEntries.reversed.toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            SessionSummaryCard(summary: summary),
            const SizedBox(height: 20),
            if (displayEntries.isEmpty)
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
              )
            else
              Semantics(
                label: SemanticsLabels.partySessionEntryList,
                container: true,
                child: Column(
                  children: [
                    for (final entry in displayEntries)
                      _EntryRow(entry: entry, active: false),
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

enum _EntryAction { edit, delete }

class _EntryRow extends ConsumerWidget {
  const _EntryRow({
    required this.entry,
    required this.active,
    this.sessionStartedAt,
  });

  final DrinkEntry entry;
  final bool active;

  /// The session's `startedAt` — bounds the edit sheet's free date picker to
  /// `[sessionStartedAt, now]`, so a session-attached entry can never be
  /// moved outside its own session's window (which would break that
  /// session's BAC/duration math). Only meaningful (and only read) when
  /// [active] is true — ended-mode rows never open the edit sheet, so
  /// [_EndedLog] passes nothing here.
  final DateTime? sessionStartedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = entry.consumedAt.toLocal();
    final timeLabel = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    final volumeText = '${entry.volumeMl} ml';
    final abvText =
        entry.abvPercent != null ? ' · ${entry.abvPercent}% ABV' : '';
    final name = entry.name ?? 'Drink';
    final iconColor = entry.iconColor != null
        ? parseIconColor(entry.iconColor!) ??
            Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.primary;

    return Semantics(
      label: '$name, $volumeText$abvText, $timeLabel',
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withAlpha(38),
          child: Icon(Icons.local_bar_outlined, color: iconColor, size: 22),
        ),
        title: Text(name),
        subtitle: Text('$volumeText$abvText · $timeLabel'),
        trailing: active ? const Icon(Icons.chevron_right) : null,
        onTap: active ? () => _openActions(context, ref) : null,
      ),
    );
  }

  Future<void> _openActions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<_EntryAction>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.of(context).pop(_EntryAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.of(context).pop(_EntryAction.delete),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    if (action == _EntryAction.edit) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => EntryEditSheet(
          entry: entry,
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
    } else {
      await _confirmDelete(context, ref);
    }
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
