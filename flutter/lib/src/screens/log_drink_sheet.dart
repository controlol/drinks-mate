import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drink_preset.dart';
import '../models/optional.dart';
import '../repository/providers.dart';
import '../utils/color_utils.dart';

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

    // C6: close immediately; write settles in background.
    final repo = ref.read(drinksRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await repo.logDrink(
        preset: preset,
        volumeMl: volume,
        consumedAt: _consumedAt,
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to log drink')),
      );
    }
  }

  /// Opens the S2 Advanced editor (user-experience.md §S2: "an additional
  /// editor for name, ABV (alcoholic drinks only), and price").
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

    // C6: close immediately; writes settle in background.
    final repo = ref.read(drinksRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      switch (result.action) {
        case _AdvancedAction.confirmOnly:
          // "Confirm — logs the drink with the entered values for this
          // entry only. The underlying preset is unchanged."
          await repo.logDrink(
            preset: preset,
            name: result.name,
            volumeMl: volume,
            abvPercent: result.abvPercent,
            // Explicit Optional.value (not the Optional.absent default) so
            // a cleared price field logs this entry with no price instead
            // of silently falling back to the preset's stored price.
            priceMinor: Optional.value(result.priceMinor),
            currency: Optional.value(result.currency),
            consumedAt: _consumedAt,
          );
        case _AdvancedAction.saveAndConfirm:
          // "Save and confirm — writes the advanced values back to the
          // preset (overwriting it), then logs the drink."
          await repo.updatePreset(
            id: preset.id,
            name: result.name,
            abvPercent: Optional.value(result.abvPercent),
            regularPriceMinor: Optional.value(result.priceMinor),
            regularCurrency: Optional.value(result.currency),
          );
          final updated = await repo.getPresetById(preset.id) ?? preset;
          await repo.logDrink(
            preset: updated,
            volumeMl: volume,
            consumedAt: _consumedAt,
          );
        case _AdvancedAction.saveAsCopyAndConfirm:
          // "Save as copy and confirm — creates a new preset with the
          // advanced values ..., then logs the drink against the new
          // preset."
          final existingCount =
              ref.read(allPresetsProvider).valueOrNull?.length ?? 0;
          final copy = await repo.createPreset(
            name: result.newPresetName ?? result.name,
            beverageType: preset.beverageType,
            volumeMl: volume,
            abvPercent: result.abvPercent,
            regularPriceMinor: result.priceMinor,
            regularCurrency: result.currency,
            iconKey: preset.iconKey,
            iconColor: preset.iconColor,
            sortOrder: existingCount + 1,
          );
          await repo.logDrink(
            preset: copy,
            volumeMl: volume,
            consumedAt: _consumedAt,
          );
      }
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

class _PickPhase extends ConsumerWidget {
  const _PickPhase({required this.scrollController, required this.onPick});

  final ScrollController scrollController;
  final ValueChanged<DrinkPreset> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(visiblePresetsProvider);
    return Column(
      children: [
        _SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Log a drink',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: presetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (presets) => ListView.builder(
              controller: scrollController,
              itemCount: presets.length,
              itemBuilder: (context, i) => _PresetTile(
                preset: presets[i],
                onTap: () => onPick(presets[i]),
              ),
            ),
          ),
        ),
      ],
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
    final label =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
// S2 Advanced editor — name, ABV (alcoholic only), price
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
    this.priceMinor,
    this.currency,
    this.newPresetName,
  });

  final _AdvancedAction action;
  final String name;
  final double? abvPercent;
  final int? priceMinor;
  final String? currency;

  /// User-confirmed name for the new preset — only set for
  /// [_AdvancedAction.saveAsCopyAndConfirm].
  final String? newPresetName;
}

/// user-experience.md §S2 Advanced editor: "an additional editor for name,
/// ABV (alcoholic drinks only), and price ... the icon and colour are not
/// editable here."
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
  late final TextEditingController _priceCtrl;
  String? _nameError;

  bool get _isAlcoholic => widget.preset.beverageType.isAlcoholic;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    _nameCtrl = TextEditingController(text: preset.name);
    _abvCtrl = TextEditingController(text: preset.abvPercent?.toString() ?? '');
    _priceCtrl = TextEditingController(
      text: preset.regularPriceMinor != null
          ? (preset.regularPriceMinor! / 100).toStringAsFixed(2)
          : '',
    );
    _nameError = _validateName(_nameCtrl.text);
    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _abvCtrl.dispose();
    _priceCtrl.dispose();
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
    if (_priceCtrl.text.isNotEmpty) {
      final price = double.tryParse(_priceCtrl.text);
      if (price == null || price < 0) return false;
    }
    return true;
  }

  double? get _abvPercent =>
      _isAlcoholic ? double.tryParse(_abvCtrl.text) : null;

  int? get _priceMinor {
    final major = double.tryParse(_priceCtrl.text);
    return major == null ? null : (major * 100).round();
  }

  String? get _currency {
    if (_priceMinor == null) return null;
    return widget.preset.regularCurrency ??
        ref.read(userPreferencesProvider).valueOrNull?.currency;
  }

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
        priceMinor: _priceMinor,
        currency: _currency,
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
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('advanced_editor_price_field'),
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Price (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
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
