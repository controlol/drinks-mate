import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../a11y/semantics_labels.dart';
import '../models/drink_entry.dart';
import '../models/optional.dart';
import '../models/party_session.dart';
import '../repository/providers.dart';
import '../services/bac_estimator.dart';
import '../utils/color_utils.dart';
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
                  _EntryRow(entry: entry, active: true),
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
  const _EntryRow({required this.entry, required this.active});

  final DrinkEntry entry;
  final bool active;

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
        builder: (_) => _EditAlcoholicEntrySheet(entry: entry),
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

// ---------------------------------------------------------------------------
// Edit entry sheet (active mode only)
// ---------------------------------------------------------------------------

class _EditAlcoholicEntrySheet extends ConsumerStatefulWidget {
  const _EditAlcoholicEntrySheet({required this.entry});

  final DrinkEntry entry;

  @override
  ConsumerState<_EditAlcoholicEntrySheet> createState() =>
      _EditAlcoholicEntrySheetState();
}

class _EditAlcoholicEntrySheetState
    extends ConsumerState<_EditAlcoholicEntrySheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _volumeCtrl;
  late TextEditingController _abvCtrl;
  late TextEditingController _priceCtrl;
  late DateTime _consumedAt;

  /// The price field's initial text — compared against at save time so an
  /// entry priced in tokens (which this money-only field can't represent,
  /// and so leaves blank) doesn't get its token price silently cleared by
  /// an edit that never touched price at all (data-model.md §Snapshot
  /// semantics: only a "direct, deliberate user edit" may change a field).
  late String _initialPriceText;
  String? _nameError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _nameCtrl = TextEditingController(text: entry.name ?? '');
    _volumeCtrl = TextEditingController(text: entry.volumeMl.toString());
    _abvCtrl = TextEditingController(text: entry.abvPercent?.toString() ?? '');
    _initialPriceText = entry.priceMinor != null
        ? (entry.priceMinor! / 100).toStringAsFixed(2)
        : '';
    _priceCtrl = TextEditingController(text: _initialPriceText);
    _consumedAt = entry.consumedAt.toLocal();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _volumeCtrl.dispose();
    _abvCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    final result = value.isEmpty
        ? const UsernameValidation.invalid('Name is required')
        : validatePresetName(value);
    setState(() => _nameError = result.isValid ? null : result.error);
  }

  Future<void> _save() async {
    if (_submitting) return;
    final volume = int.tryParse(_volumeCtrl.text.trim());
    if (volume == null || volume < 1) {
      _showError('Volume must be at least 1 ml');
      return;
    }
    final abv = double.tryParse(_abvCtrl.text.trim());
    if (abv == null || abv <= 0) {
      _showError('ABV must be greater than 0%');
      return;
    }
    if (_nameError != null) return;

    // Only send a price change if the field was actually touched — this
    // field is money-only, so an entry priced in tokens renders it blank;
    // leaving it untouched must not clear that token price as a side
    // effect of an unrelated volume/name/ABV/time edit.
    final priceTouched = _priceCtrl.text.trim() != _initialPriceText;
    var priceMinor = const Optional<int?>.absent();
    var currency = const Optional<String?>.absent();
    if (priceTouched) {
      // Non-blank is a one-off, this-entry-only money override
      // (party-session.md §Logging an alcoholic drink), same semantics as
      // the log-time sheet; blank clears any existing money/token price.
      int? priceMinorValue;
      if (_priceCtrl.text.trim().isNotEmpty) {
        final major = double.tryParse(_priceCtrl.text.trim());
        if (major == null || major < 0) {
          _showError('Price must be a positive number');
          return;
        }
        priceMinorValue = (major * 100).round();
      }
      final currencyValue = priceMinorValue == null
          ? null
          : (widget.entry.currency ??
              ref.read(userPreferencesProvider).valueOrNull?.currency ??
              'EUR');
      priceMinor = Optional.value(priceMinorValue);
      currency = Optional.value(currencyValue);
    }

    setState(() => _submitting = true);
    final repo = ref.read(partySessionRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await repo.updateAlcoholicEntry(
        id: widget.entry.id,
        volumeMl: volume,
        name: _nameCtrl.text,
        abvPercent: abv,
        consumedAt: _consumedAt,
        priceMinor: priceMinor,
        currency: currency,
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to save changes')),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _consumedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_consumedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _consumedAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${_consumedAt.year}-'
        '${_consumedAt.month.toString().padLeft(2, '0')}-'
        '${_consumedAt.day.toString().padLeft(2, '0')} '
        '${_consumedAt.hour.toString().padLeft(2, '0')}:'
        '${_consumedAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit drink', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Text('Name', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              onChanged: _onNameChanged,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 16),
            Text('Volume (ml)', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _volumeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: 'ml',
              ),
            ),
            const SizedBox(height: 16),
            Text('ABV (%)', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _abvCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Price (optional, this entry only)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                // This field is money-only, so a token-priced entry can't be
                // shown here directly — leaving it blank keeps the existing
                // token price untouched (see _initialPriceText's doc).
                helperText: widget.entry.priceTokens != null
                    ? 'Currently priced in tokens — enter an amount to '
                        'switch this entry to a one-off money price'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text('Time', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text(dateLabel),
              onPressed: _pickDateTime,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
