import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/drink_entry.dart';
import '../models/optional.dart';

/// Shared bottom-sheet editor for a [DrinkEntry] — used by S6 (Today Drinks
/// Log), S9 (Party Session Log, active-mode), and S3 (History day
/// drill-down). Each screen supplies [onSave] (wired to its own repository
/// call — [DrinksRepository.updateDrinkEntry] for S6/S3,
/// [PartySessionRepository.updateAlcoholicEntry] for S9) and [onPickTime]
/// (day-window-clamped for S6/S3, since both are scoped to a single day;
/// free date+time for S9, since a session can span multiple calendar days).
///
/// Fields shown: volume (always); name (only when [showName] is true — S3
/// only, design/user-experience.md §S3); ABV (only when
/// `entry.beverageType.isAlcoholic` — never shown/edited for a hydration
/// entry); price (always, a one-off, this-entry-only money override —
/// data-model.md §DrinkEntry).
class EntryEditSheet extends StatefulWidget {
  const EntryEditSheet({
    super.key,
    required this.entry,
    required this.onSave,
    required this.onPickTime,
    this.showName = false,
    this.showDate = false,
    this.defaultCurrency,
  });

  final DrinkEntry entry;
  final bool showName;

  /// Whether the time button's label includes the date, not just the
  /// time-of-day. S9 sets this — its [onPickTime] lets the user move an
  /// entry across calendar days (a session can span midnight), so the
  /// button must show which day, not just which time. S6/S3 leave this
  /// false: both are scoped to a single, already-known day, so a bare
  /// time-of-day label is unambiguous.
  final bool showDate;

  /// Fallback currency when setting a first-time price on an entry that has
  /// none of its own — the user's current currency preference, so the
  /// caller passes `UserPreferences.currency`. Falls back to `'EUR'` if
  /// null (preferences unavailable).
  final String? defaultCurrency;

  final Future<void> Function({
    required int volumeMl,
    String? name,
    double? abvPercent,
    required Optional<int?> priceMinor,
    required Optional<String?> currency,
    required DateTime consumedAt,
  }) onSave;

  final Future<DateTime?> Function(BuildContext context, DateTime current)
      onPickTime;

  @override
  State<EntryEditSheet> createState() => _EntryEditSheetState();
}

class _EntryEditSheetState extends State<EntryEditSheet> {
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

  bool get _isAlcoholic => widget.entry.beverageType.isAlcoholic;

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
    _consumedAt = entry.consumedAt;
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

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickTime() async {
    final picked = await widget.onPickTime(context, _consumedAt);
    if (picked == null || !mounted) return;
    setState(() => _consumedAt = picked);
  }

  Future<void> _save() async {
    if (_submitting) return;
    final volume = int.tryParse(_volumeCtrl.text.trim());
    if (volume == null || volume < 1) {
      _showError('Volume must be at least 1 ml');
      return;
    }

    double? abv;
    if (_isAlcoholic) {
      abv = double.tryParse(_abvCtrl.text.trim());
      if (abv == null || abv <= 0) {
        _showError('ABV must be greater than 0%');
        return;
      }
    }

    if (widget.showName && _nameError != null) return;

    // Only send a price change if the field was actually touched — this
    // field is money-only, so an entry priced in tokens renders it blank;
    // leaving it untouched must not clear that token price as a side
    // effect of an unrelated volume/ABV/time edit.
    final priceTouched = _priceCtrl.text.trim() != _initialPriceText;
    var priceMinor = const Optional<int?>.absent();
    var currency = const Optional<String?>.absent();
    if (priceTouched) {
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
          : (widget.entry.currency ?? widget.defaultCurrency ?? 'EUR');
      priceMinor = Optional.value(priceMinorValue);
      currency = Optional.value(currencyValue);
    }

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await widget.onSave(
        volumeMl: volume,
        name: widget.showName ? _nameCtrl.text : null,
        abvPercent: abv,
        priceMinor: priceMinor,
        currency: currency,
        consumedAt: _consumedAt,
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to save changes')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = _consumedAt.toLocal();
    // Source: Parity Rulebook — "Time-of-day display format" (honours the
    // device's 12h/24h preference rather than a hardcoded format).
    final timeOfDayLabel = TimeOfDay.fromDateTime(local).format(context);
    final timeLabel = widget.showDate
        ? '${_formatDate(local)} $timeOfDayLabel'
        : timeOfDayLabel;

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
            _SheetHandle(),
            const SizedBox(height: 8),
            Text('Edit drink', style: Theme.of(context).textTheme.titleLarge),
            if (widget.showName) ...[
              const SizedBox(height: 16),
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
            ] else if (widget.entry.name != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.entry.name!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
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
            if (_isAlcoholic) ...[
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
            ],
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
            Row(
              children: [
                Text('Time', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(timeLabel),
                  onPressed: _pickTime,
                ),
              ],
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

/// `YYYY-MM-DD` prefix for [EntryEditSheet.showDate]'s time-button label
/// (S9 only) — a plain ISO date, not locale-formatted, matching what the
/// screen showed before this widget was extracted.
String _formatDate(DateTime local) {
  return '${local.year}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Sheet handle
// ---------------------------------------------------------------------------

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day-window-clamped time picker (S6, S3)
// ---------------------------------------------------------------------------

/// Time picker for day-scoped editors (S6 Today Drinks Log, S3 History day
/// drill-down): maps the picked time back into the same day window as
/// [current] rather than allowing an arbitrary date, since neither screen
/// lets a user move an entry to a different day. S9 (Party Session Log)
/// uses its own free date+time picker instead, since a session can span
/// multiple calendar days.
///
/// With `dayBoundaryHour = B`, the window spans `[B:00 day D, B:00 day
/// D+1)`. Times >= B belong to calendar day D (the window start); times < B
/// belong to calendar day D+1 (the window end). This avoids the
/// midnight-straddling trap where naively combining the picked time with
/// `current`'s calendar day produces a `DateTime` outside the window.
Future<DateTime?> pickDayWindowTime(
  BuildContext context,
  DateTime current, {
  required int boundaryHour,
}) async {
  final local = current.toLocal();
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(local),
  );
  if (picked == null) return null;

  final window = dayWindow(now: local, boundaryHour: boundaryHour);
  final dayStart = window.$1.toLocal();
  final dayEnd = window.$2.toLocal();

  if (picked.hour >= boundaryHour) {
    return DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day,
      picked.hour,
      picked.minute,
    );
  }
  return DateTime(
    dayEnd.year,
    dayEnd.month,
    dayEnd.day,
    picked.hour,
    picked.minute,
  );
}
