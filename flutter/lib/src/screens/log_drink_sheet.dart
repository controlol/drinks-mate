import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../a11y/semantics_labels.dart';
import '../models/beverage_type.dart';
import '../models/drink_preset.dart';
import '../models/optional.dart';
import '../repository/providers.dart';
import '../utils/color_utils.dart';
import 'preset_editor_screen.dart';

/// Result popped by [LogDrinkSheet] on a successful log: the id of the
/// [DrinkEntry] just written (so a caller-shown toast can wire an Undo
/// action to the right row), the name it was logged under, [beverageType],
/// and whether it attached directly to an already-active Party Session
/// ([attachedToSession] — party-session.md §Logging from Today). An
/// alcoholic entry that did **not** attach to a session (a fresh orphan)
/// gets no Undo — the toast's one action slot instead offers "Start
/// session". Null if the sheet was dismissed without logging.
///
/// [pendingWrite] resolves when the [DrinkEntry] (and, for the "save and
/// confirm" / "save as copy" paths, the preset write it depends on) has
/// actually landed — C6 pops the sheet before that settles, so a caller
/// wiring Undo to [id] must await [pendingWrite] first, or a fast tap can
/// race the insert and silently no-op instead of deleting anything.
typedef LoggedDrinkResult = ({
  String id,
  String name,
  BeverageType beverageType,
  bool attachedToSession,
  Future<void> pendingWrite,
});

/// S2 — Log drink bottom sheet.
///
/// Two-phase flow per user-experience.md §S2:
///   Phase 1 — pick a preset from the scrollable list.
///   Phase 2 — adjust volume + time, then confirm.
///
/// Reachable in ≤ 2 taps: Today → "Log drink" opens phase 1; tapping a
/// preset moves to phase 2; "Confirm" logs the drink (total: 3 taps). The
/// quick-log tiles on Today bypass this sheet entirely and log in 1 tap.
class LogDrinkSheet extends ConsumerStatefulWidget {
  const LogDrinkSheet({super.key});

  @override
  ConsumerState<LogDrinkSheet> createState() => _LogDrinkSheetState();
}

class _LogDrinkSheetState extends ConsumerState<LogDrinkSheet> {
  DrinkPreset? _selected;
  late TextEditingController _volumeCtrl;
  DateTime _consumedAt = DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _volumeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _volumeCtrl.dispose();
    super.dispose();
  }

  void _pickPreset(DrinkPreset preset) {
    setState(() {
      _selected = preset;
      _volumeCtrl.text = preset.volumeMl.toString();
      _consumedAt = DateTime.now();
    });
  }

  void _back() => setState(() => _selected = null);

  Future<void> _confirm() async {
    if (_submitting) return;

    final preset = _selected;
    if (preset == null) return;
    final volume = int.tryParse(_volumeCtrl.text);
    if (volume == null || volume <= 0) return;
    _submitting = true;

    // party-session.md §Logging from Today: an alcoholic drink attaches to
    // an already-active session directly, instead of logging as an orphan.
    final activeSession = preset.beverageType.isAlcoholic
        ? ref.read(activePartySessionProvider).valueOrNull
        : null;

    // C6: close immediately; write settles in background. The id is
    // generated up front (not returned by logDrink) so it's available for
    // the pop *before* the write completes. `write()` is invoked (not
    // awaited) before the pop so its Future can ride along in the popped
    // result — a caller wiring Undo to `entryId` must await it first, or a
    // fast tap could race the insert.
    final entryId = const Uuid().v4();
    final repo = ref.read(drinksRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    Future<void> write() async {
      if (activeSession != null) {
        final partyRepo = ref.read(partySessionRepositoryProvider);
        final resolved = await partyRepo.resolvePrice(
          session: activeSession,
          preset: preset,
        );
        await partyRepo.logAlcoholicDrink(
          id: entryId,
          preset: preset,
          sessionId: activeSession.id,
          volumeMl: volume,
          consumedAt: _consumedAt,
          priceMinor: resolved.priceMinor,
          currency: resolved.currency,
          priceTokens: resolved.priceTokens,
          tokenValueMinor: resolved.tokenValueMinor,
          tokenValueCurrency: resolved.tokenValueCurrency,
        );
      } else {
        await repo.logDrink(
          id: entryId,
          preset: preset,
          volumeMl: volume,
          consumedAt: _consumedAt,
        );
      }
    }

    final pendingWrite = write();
    Navigator.of(context).pop<LoggedDrinkResult>((
      id: entryId,
      name: preset.name,
      beverageType: preset.beverageType,
      attachedToSession: activeSession != null,
      pendingWrite: pendingWrite,
    ));
    try {
      await pendingWrite;
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to log drink')),
      );
    }
  }

  /// Opens the S2 Advanced editor (user-experience.md §S2 Phase 2: "an
  /// additional editor for `name` and `ABV` (alcoholic drinks only)" — price
  /// is not set here at log time, for any drink type).
  Future<void> _openAdvanced() async {
    final preset = _selected;
    if (preset == null) return;
    final result = await showModalBottomSheet<_AdvancedEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AdvancedEditorSheet(preset: preset),
    );
    // "Back" — discard, stay in phase 2.
    if (result == null || !mounted) return;
    await _applyAdvancedResult(preset, result);
  }

  /// Executes one of the three S2 Advanced exit paths (user-experience.md
  /// §S2). Snapshot-immutability (data-model.md §Snapshot semantics): only
  /// [DrinksRepository.updatePreset]/[createPreset] touch the preset row;
  /// existing [DrinkEntry] rows are never modified.
  Future<void> _applyAdvancedResult(
    DrinkPreset preset,
    _AdvancedEditResult result,
  ) async {
    if (_submitting) return;

    final volume = int.tryParse(_volumeCtrl.text);
    if (volume == null || volume <= 0) return;
    _submitting = true;

    // party-session.md §Logging from Today: an alcoholic drink attaches to
    // an already-active session directly, instead of logging as an orphan.
    final activeSession = preset.beverageType.isAlcoholic
        ? ref.read(activePartySessionProvider).valueOrNull
        : null;

    // C6: close immediately; writes settle in background. The id and the
    // effective logged name are both knowable synchronously from [result]
    // (every branch below logs under `result.name`, or
    // `result.newPresetName ?? result.name` for the copy path) — no need to
    // await the write to pop a useful result. `write()` runs the whole
    // branch (which for saveAndConfirm/saveAsCopyAndConfirm is itself a
    // multi-step preset write *then* the entry write) as a single Future,
    // invoked before the pop so a caller wiring Undo to `entryId` can await
    // it and not race the insert.
    final entryId = const Uuid().v4();
    final loggedName = result.action == _AdvancedAction.saveAsCopyAndConfirm
        ? (result.newPresetName ?? result.name)
        : result.name;
    final repo = ref.read(drinksRepositoryProvider);
    final partyRepo = ref.read(partySessionRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    // Logs the entry against [loggedPreset] — through the active session
    // when one is active (resolving that session's price, party-session.md
    // §Logging an alcoholic drink), or as a plain/orphan entry at
    // [loggedPreset]'s regular price otherwise. Price is no longer set here
    // at log time for any drink type (user-experience.md §S2 Phase 2).
    Future<void> logEntry(DrinkPreset loggedPreset, {String? name}) async {
      if (activeSession != null) {
        final resolved = await partyRepo.resolvePrice(
          session: activeSession,
          preset: loggedPreset,
        );
        await partyRepo.logAlcoholicDrink(
          id: entryId,
          preset: loggedPreset,
          sessionId: activeSession.id,
          name: name,
          volumeMl: volume,
          abvPercent: result.abvPercent,
          consumedAt: _consumedAt,
          priceMinor: resolved.priceMinor,
          currency: resolved.currency,
          priceTokens: resolved.priceTokens,
          tokenValueMinor: resolved.tokenValueMinor,
          tokenValueCurrency: resolved.tokenValueCurrency,
        );
      } else {
        await repo.logDrink(
          id: entryId,
          preset: loggedPreset,
          name: name,
          volumeMl: volume,
          abvPercent: result.abvPercent,
          consumedAt: _consumedAt,
        );
      }
    }

    Future<void> write() async {
      switch (result.action) {
        case _AdvancedAction.confirmOnly:
          // "Confirm — logs the drink with the entered values for this
          // entry only. The underlying preset is unchanged."
          await logEntry(preset, name: result.name);
        case _AdvancedAction.saveAndConfirm:
          // "Save and confirm — writes the advanced values back to the
          // preset (overwriting it), then logs the drink." Price is left
          // untouched (Optional.absent, not Optional.value(null)) — it's no
          // longer editable from this editor.
          await repo.updatePreset(
            id: preset.id,
            name: result.name,
            abvPercent: Optional.value(result.abvPercent),
          );
          final updated = await repo.getPresetById(preset.id) ?? preset;
          await logEntry(updated);
        case _AdvancedAction.saveAsCopyAndConfirm:
          // "Save as copy and confirm — creates a new preset with the
          // advanced values ..., then logs the drink against the new
          // preset." The copy inherits the source preset's price — price
          // isn't one of the advanced values edited here anymore.
          final copy = await repo.createPreset(
            name: result.newPresetName ?? result.name,
            beverageType: preset.beverageType,
            volumeMl: volume,
            abvPercent: result.abvPercent,
            regularPriceMinor: preset.regularPriceMinor,
            regularCurrency: preset.regularCurrency,
            iconKey: preset.iconKey,
            iconColor: preset.iconColor,
            sortOrder: await repo.nextSortOrder(),
          );
          await logEntry(copy);
      }
    }

    final pendingWrite = write();
    Navigator.of(context).pop<LoggedDrinkResult>((
      id: entryId,
      name: loggedName,
      beverageType: preset.beverageType,
      attachedToSession: activeSession != null,
      pendingWrite: pendingWrite,
    ));
    try {
      await pendingWrite;
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to log drink')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => _selected == null
          ? _PickPhase(scrollController: scrollController, onPick: _pickPreset)
          : _ConfirmPhase(
              preset: _selected!,
              volumeCtrl: _volumeCtrl,
              consumedAt: _consumedAt,
              onTimeChanged: (dt) => setState(() => _consumedAt = dt),
              onBack: _back,
              onConfirm: _confirm,
              onAdvanced: _openAdvanced,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase 1 — Preset picker
// ---------------------------------------------------------------------------

class _PickPhase extends ConsumerStatefulWidget {
  const _PickPhase({required this.scrollController, required this.onPick});

  final ScrollController scrollController;
  final ValueChanged<DrinkPreset> onPick;

  @override
  ConsumerState<_PickPhase> createState() => _PickPhaseState();
}

class _PickPhaseState extends ConsumerState<_PickPhase> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _createPreset() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const PresetEditorScreen()),
    );
    // No further action needed: visiblePresetsProvider is a reactive stream,
    // so the list below already refreshes with the new preset once created.
  }

  @override
  Widget build(BuildContext context) {
    final presets = ref.watch(rankedVisiblePresetsProvider);
    final mode =
        ref.watch(userPreferencesProvider).valueOrNull?.drinkSortMode ??
            PresetSortMode.recentlyUsed;
    final filtered = _query.isEmpty
        ? presets
        : presets.where((p) => p.name.toLowerCase().contains(_query)).toList();

    return Column(
      children: [
        _SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Log a drink',
                  style: Theme.of(context).textTheme.titleLarge,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            key: const Key('log_drink_search_field'),
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search drinks',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: filtered.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Semantics(
                  label: SemanticsLabels.createPresetEntry,
                  button: true,
                  child: ListTile(
                    key: const Key('log_drink_create_preset_tile'),
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('Create new preset'),
                    onTap: _createPreset,
                  ),
                );
              }
              final preset = filtered[i - 1];
              return _PresetTile(
                preset: preset,
                onTap: () => widget.onPick(preset),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Sort-mode dropdown shared by the Today grid and this picker (F14 §Sort
/// modes) — same three modes, same label text.
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

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, required this.onTap});

  final DrinkPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.local_drink_outlined,
        color: parseIconColor(preset.iconColor),
      ),
      title: Text(preset.name),
      subtitle: Text('${preset.volumeMl} ml'),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Phase 2 — Edit & confirm
// ---------------------------------------------------------------------------

class _ConfirmPhase extends StatelessWidget {
  const _ConfirmPhase({
    required this.preset,
    required this.volumeCtrl,
    required this.consumedAt,
    required this.onTimeChanged,
    required this.onBack,
    required this.onConfirm,
    required this.onAdvanced,
  });

  final DrinkPreset preset;
  final TextEditingController volumeCtrl;
  final DateTime consumedAt;
  final ValueChanged<DateTime> onTimeChanged;
  final VoidCallback onBack;
  final VoidCallback onConfirm;
  final VoidCallback onAdvanced;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHandle(),
        ListTile(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
            tooltip: 'Back to preset list',
          ),
          title: Text(
            preset.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          subtitle: Text(preset.beverageType.displayName),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(height: 8),
              Text(
                'Volume (ml)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: volumeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: 'ml',
                ),
              ),
              const SizedBox(height: 20),
              Text('Time', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              _TimeButton(consumedAt: consumedAt, onChanged: onTimeChanged),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Row(
            children: [
              OutlinedButton(
                key: const Key('log_drink_advanced_button'),
                onPressed: onAdvanced,
                child: const Text('Advanced'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: const Key('log_drink_confirm_button'),
                  onPressed: onConfirm,
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.consumedAt, required this.onChanged});

  final DateTime consumedAt;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final local = consumedAt.toLocal();
    // Source: Parity Rulebook — "Time-of-day display format" (honours the
    // device's 12h/24h preference rather than a hardcoded format).
    final label = TimeOfDay.fromDateTime(local).format(context);
    return OutlinedButton.icon(
      icon: const Icon(Icons.schedule),
      label: Text(label),
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(local),
        );
        if (picked != null) {
          final updated = DateTime(
            local.year,
            local.month,
            local.day,
            picked.hour,
            picked.minute,
          );
          onChanged(updated);
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// S2 Advanced editor — name, ABV (alcoholic only)
// ---------------------------------------------------------------------------

/// The three exit paths of the Advanced editor (user-experience.md §S2).
/// "Back" is not represented here — it pops the sheet with a null result.
enum _AdvancedAction { confirmOnly, saveAndConfirm, saveAsCopyAndConfirm }

/// Result of the Advanced editor — the edited values plus which of the three
/// save paths the user chose.
class _AdvancedEditResult {
  const _AdvancedEditResult({
    required this.action,
    required this.name,
    this.abvPercent,
    this.newPresetName,
  });

  final _AdvancedAction action;
  final String name;
  final double? abvPercent;

  /// User-confirmed name for the new preset — only set for
  /// [_AdvancedAction.saveAsCopyAndConfirm].
  final String? newPresetName;
}

/// user-experience.md §S2 Advanced editor: "an additional editor for `name`
/// and `ABV` (alcoholic drinks only) ... the icon and colour are not
/// editable here. Price is not set here at log time, for any drink type —
/// the entry logs at the preset's regular price ... It can still be
/// overridden afterwards on a per-entry basis" (from S6, or S9 for
/// session-attached alcoholic drinks).
class _AdvancedEditorSheet extends ConsumerStatefulWidget {
  const _AdvancedEditorSheet({required this.preset});

  final DrinkPreset preset;

  @override
  ConsumerState<_AdvancedEditorSheet> createState() =>
      _AdvancedEditorSheetState();
}

class _AdvancedEditorSheetState extends ConsumerState<_AdvancedEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _abvCtrl;
  String? _nameError;

  bool get _isAlcoholic => widget.preset.beverageType.isAlcoholic;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    _nameCtrl = TextEditingController(text: preset.name);
    _abvCtrl = TextEditingController(text: preset.abvPercent?.toString() ?? '');
    _nameError = _validateName(_nameCtrl.text);
    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _abvCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged() =>
      setState(() => _nameError = _validateName(_nameCtrl.text));

  String? _validateName(String value) {
    if (value.isEmpty) return 'Name is required';
    final result = validatePresetName(value);
    return result.isValid ? null : result.error;
  }

  bool get _canConfirm {
    if (_nameError != null) return false;
    if (_isAlcoholic) {
      final abv = double.tryParse(_abvCtrl.text);
      if (abv == null || abv < 0) return false;
    }
    return true;
  }

  double? get _abvPercent =>
      _isAlcoholic ? double.tryParse(_abvCtrl.text) : null;

  Future<void> _finish(_AdvancedAction action) async {
    if (!_canConfirm) return;
    String? newPresetName;
    if (action == _AdvancedAction.saveAsCopyAndConfirm) {
      newPresetName = await _promptCopyName();
      if (newPresetName == null || !mounted) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      _AdvancedEditResult(
        action: action,
        name: _nameCtrl.text,
        abvPercent: _abvPercent,
        newPresetName: newPresetName,
      ),
    );
  }

  /// "Save as copy and confirm ... the user is asked to confirm the new
  /// name" (user-experience.md §S2). Returns null if the user cancels.
  ///
  /// The default `'$name (copy)'` value can itself exceed `validatePresetName`'s
  /// 30-rune limit (a 24–30 char base name + " (copy)"), so this field is
  /// live-validated the same way `_AdvancedEditorSheetState._validateName`
  /// validates the main name field — `Create` is disabled until valid,
  /// instead of letting an invalid name reach `repo.createPreset` only to
  /// throw after the sheet has already been popped (C6).
  Future<String?> _promptCopyName() {
    final ctrl = TextEditingController(text: '${_nameCtrl.text} (copy)');
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final error = _validateName(ctrl.text);
          return AlertDialog(
            title: const Text('New preset name'),
            content: TextField(
              key: const Key('advanced_editor_copy_name_field'),
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(errorText: error),
              onChanged: (_) => setDialogState(() {}),
            ),
            actions: [
              TextButton(
                key: const Key('advanced_editor_copy_cancel_button'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                key: const Key('advanced_editor_copy_confirm_button'),
                onPressed: error == null
                    ? () => Navigator.of(context).pop(ctrl.text)
                    : null,
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Advanced',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextField(
                    key: const Key('advanced_editor_name_field'),
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: const OutlineInputBorder(),
                      errorText: _nameError,
                    ),
                  ),
                  if (_isAlcoholic) ...[
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('advanced_editor_abv_field'),
                      controller: _abvCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'ABV',
                        suffixText: '%',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Row(
                children: [
                  TextButton(
                    key: const Key('advanced_editor_back_button'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                  const Spacer(),
                  PopupMenuButton<_AdvancedAction>(
                    key: const Key('advanced_editor_menu_button'),
                    enabled: _canConfirm,
                    onSelected: _finish,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _AdvancedAction.saveAndConfirm,
                        child: Text('Save and confirm'),
                      ),
                      PopupMenuItem(
                        value: _AdvancedAction.saveAsCopyAndConfirm,
                        child: Text('Save as copy and confirm'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('advanced_editor_confirm_button'),
                    onPressed: _canConfirm
                        ? () => _finish(_AdvancedAction.confirmOnly)
                        : null,
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
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
