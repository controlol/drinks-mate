import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/drink_entry.dart';
import '../models/optional.dart';

/// Shared bottom-sheet editor for a [DrinkEntry] — used by S6 (Today Drinks
/// Log), S9 (Party Session Log, active-mode), and S3 (History day
/// drill-down). Each screen supplies [onSave] (wired to its own repository
/// call — [DrinksRepository.updateDrinkEntry] for S6/S3,
/// [PartySessionRepository.updateAlcoholicEntry] for S9) and [datePicker]
/// (see [DateEditPicker]).
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
    required this.datePicker,
    this.showName = false,
    this.defaultCurrency,
  });

  final DrinkEntry entry;
  final bool showName;

  /// Governs the time button's label and what the picker it opens allows —
  /// see [DateEditPicker].
  final DateEditPicker datePicker;

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

  @override
  State<EntryEditSheet> createState() => _EntryEditSheetState();
}

/// Bundles how [EntryEditSheet]'s time button behaves: whether its label
/// includes the date (not just the time-of-day) and what range the
/// underlying picker allows. The two were previously separate,
/// independently-settable parameters (a label flag plus a picker callback)
/// that a caller had to keep in sync by hand — this collapses them into one
/// value so a screen states its date-editing policy once.
///
/// - [DateEditPicker.dayLocked] — S6 (Today Drinks Log): the entry's day is
///   fixed (today), so the label is time-only and the picker maps the
///   chosen time back into the same day window rather than letting the user
///   cross into a different day.
/// - [DateEditPicker.free] — S3 (History day drill-down): the whole point is
///   correcting which day an entry was logged on, so the label includes the
///   date and the picker allows any day (bounded to `[2000-01-01, now]` by
///   default — never the future — unless [minDate]/[maxDate] override it).
///   S9 (Party Session Log) also uses this, but bounded to the session's own
///   window (`[session.startedAt, now]`) — a session-attached entry moving
///   outside its session's window would break that session's BAC/duration
///   math, so unlike S3 it is never left unbounded.
sealed class DateEditPicker {
  const DateEditPicker._();

  const factory DateEditPicker.dayLocked({required int boundaryHour}) =
      _DayLockedDateEditPicker;

  const factory DateEditPicker.free({DateTime? minDate, DateTime? maxDate}) =
      _FreeDateEditPicker;

  /// Whether the time button's label includes the date.
  bool get showDate;

  Future<DateTime?> pick(BuildContext context, DateTime current);
}

class _DayLockedDateEditPicker extends DateEditPicker {
  const _DayLockedDateEditPicker({required this.boundaryHour}) : super._();

  final int boundaryHour;

  @override
  bool get showDate => false;

  @override
  Future<DateTime?> pick(BuildContext context, DateTime current) =>
      _pickDayWindowTime(context, current, boundaryHour: boundaryHour);
}

class _FreeDateEditPicker extends DateEditPicker {
  const _FreeDateEditPicker({this.minDate, this.maxDate}) : super._();

  final DateTime? minDate;
  final DateTime? maxDate;

  @override
  bool get showDate => true;

  @override
  Future<DateTime?> pick(BuildContext context, DateTime current) =>
      _pickFreeDateTime(context, current, minDate: minDate, maxDate: maxDate);
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
    final picked = await widget.datePicker.pick(context, _consumedAt);
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
    final timeLabel = widget.datePicker.showDate
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

/// `YYYY-MM-DD` prefix for the time-button label when
/// [DateEditPicker.showDate] is true — a plain ISO date, not
/// locale-formatted, matching what S9 showed before this widget was
/// extracted.
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
// Pickers behind DateEditPicker
// ---------------------------------------------------------------------------

/// Time picker behind [DateEditPicker.dayLocked]: maps the picked time back
/// into the same day window as [current] rather than allowing an arbitrary
/// date.
///
/// With `dayBoundaryHour = B`, the window spans `[B:00 day D, B:00 day
/// D+1)`. Times >= B belong to calendar day D (the window start); times < B
/// belong to calendar day D+1 (the window end). This avoids the
/// midnight-straddling trap where naively combining the picked time with
/// `current`'s calendar day produces a `DateTime` outside the window.
Future<DateTime?> _pickDayWindowTime(
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

/// Date+time picker behind [DateEditPicker.free]: lets the user move an
/// entry to any date within `[minDate, maxDate]` (defaulting to
/// `[2000-01-01, now]` — never the future — when either bound is omitted).
///
/// [current] itself is clamped into the resolved bounds before being used
/// as the date picker's `initialDate`, since `showDatePicker` asserts that
/// `initialDate` falls within `[firstDate, lastDate]` — relevant when an
/// entry predates a newly-narrowed bound (e.g. a session's `startedAt`
/// moved, in a hypothetical future edit path) rather than in the common
/// case, where a live entry's own `consumedAt` is already in range.
Future<DateTime?> _pickFreeDateTime(
  BuildContext context,
  DateTime current, {
  DateTime? minDate,
  DateTime? maxDate,
}) async {
  final local = current.toLocal();
  final first = minDate?.toLocal() ?? DateTime(2000);
  final last = maxDate?.toLocal() ?? DateTime.now();
  final initialDate = clampDateTime(local, first, last);

  final date = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: first,
    lastDate: last,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(local),
  );
  if (time == null) return null;

  final result =
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
  // The date picker only constrains the calendar day — the time-of-day
  // picker can still push the combined instant outside [first, last] (e.g.
  // picking `last`'s calendar day but a time-of-day later than "now").
  return clampDateTime(result, first, last);
}

/// Clamps [value] into `[first, last]` — the pure bounding math behind
/// [_pickFreeDateTime], extracted so it's unit-testable without driving the
/// Material date/time picker dialogs.
DateTime clampDateTime(DateTime value, DateTime first, DateTime last) {
  if (value.isBefore(first)) return first;
  if (value.isAfter(last)) return last;
  return value;
}
