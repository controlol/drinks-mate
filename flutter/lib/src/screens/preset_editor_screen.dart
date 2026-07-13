import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/beverage_type.dart';
import '../models/drink_icons.dart';
import '../models/drink_preset.dart';
import '../models/optional.dart';
import '../repository/providers.dart';
import '../widgets/tinted_icon.dart';

/// A small brand-friendly swatch palette offered alongside each beverage
/// type's default colour — designer-brief.md §Iconography: "a small
/// brand-friendly palette or an 'any colour' picker".
const List<String> _kColorSwatches = [
  '#3b82f6',
  '#15803d',
  '#92400e',
  '#ea580c',
  '#7c3aed',
  '#be185d',
  '#0369a1',
  '#d97706',
  '#0d9488',
  '#6b7280',
];

final _hexPattern = RegExp(r'^#?[0-9a-fA-F]{6}$');

/// F14 preset editor — create or edit a [DrinkPreset].
///
/// Pass [preset] to edit an existing preset; omit it to create a new one.
/// Fields: name (live-validated), beverage type, volume (ml), ABV (alcoholic
/// types only), optional price, icon, and icon colour. Icon and colour are
/// rendered via [TintedIcon] for a live two-shade preview.
class PresetEditorScreen extends ConsumerStatefulWidget {
  const PresetEditorScreen({super.key, this.preset});

  /// Null when creating a new preset; non-null when editing an existing one.
  final DrinkPreset? preset;

  @override
  ConsumerState<PresetEditorScreen> createState() => _PresetEditorScreenState();
}

class _PresetEditorScreenState extends ConsumerState<PresetEditorScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _volumeCtrl;
  late final TextEditingController _abvCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _customColorCtrl;
  late BeverageType _beverageType;
  late String _iconKey;
  late String _iconColor;
  String? _nameError;
  bool _saving = false;

  bool get _isEditing => widget.preset != null;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    _nameCtrl = TextEditingController(text: preset?.name ?? '');
    _beverageType = preset?.beverageType ?? BeverageType.water;
    _volumeCtrl = TextEditingController(
      text: preset != null ? preset.volumeMl.toString() : '',
    );
    _abvCtrl = TextEditingController(
      text: preset?.abvPercent?.toString() ?? '',
    );
    _priceCtrl = TextEditingController(
      text: preset?.regularPriceMinor != null
          ? (preset!.regularPriceMinor! / 100).toStringAsFixed(2)
          : '',
    );
    _iconKey = preset?.iconKey ?? kDrinkIconKeys.first;
    _iconColor = preset?.iconColor ?? _beverageType.defaultIconColor;
    _customColorCtrl = TextEditingController(
      text: _iconColor.replaceFirst('#', ''),
    );
    _nameError = _validateName(_nameCtrl.text);
    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _volumeCtrl.dispose();
    _abvCtrl.dispose();
    _priceCtrl.dispose();
    _customColorCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    setState(() => _nameError = _validateName(_nameCtrl.text));
  }

  /// Live name validation via `core`'s [validatePresetName] — Parity
  /// Rulebook §DrinkPreset name.
  String? _validateName(String value) {
    if (value.isEmpty) return 'Name is required';
    final result = validatePresetName(value);
    return result.isValid ? null : result.error;
  }

  void _onTypeChanged(BeverageType? type) {
    if (type == null) return;
    setState(() {
      _beverageType = type;
      if (!type.isAlcoholic) _abvCtrl.clear();
    });
  }

  void _selectIcon(String key) => setState(() => _iconKey = key);

  void _selectColor(String hex) {
    setState(() {
      _iconColor = hex;
      _customColorCtrl.text = hex.replaceFirst('#', '');
    });
  }

  void _onCustomColorSubmitted(String value) {
    if (!_hexPattern.hasMatch(value)) return;
    final hex = value.startsWith('#') ? value : '#$value';
    _selectColor(hex.toLowerCase());
  }

  bool get _canSave {
    if (_nameError != null) return false;
    final volume = int.tryParse(_volumeCtrl.text);
    if (volume == null || volume <= 0) return false;
    if (_beverageType.isAlcoholic) {
      final abv = double.tryParse(_abvCtrl.text);
      if (abv == null || abv < 0) return false;
    }
    if (_priceCtrl.text.isNotEmpty) {
      final price = double.tryParse(_priceCtrl.text);
      if (price == null || price < 0) return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);

    final repo = ref.read(drinksRepositoryProvider);
    final prefs = ref.read(userPreferencesProvider).valueOrNull;
    final name = _nameCtrl.text;
    final volumeMl = int.parse(_volumeCtrl.text);
    final abvPercent =
        _beverageType.isAlcoholic ? double.parse(_abvCtrl.text) : null;
    final priceMajor = double.tryParse(_priceCtrl.text);
    final priceMinor = priceMajor == null ? null : (priceMajor * 100).round();
    // Preserve the preset's own currency on edit — only fall back to the
    // user's current preference for a preset that never had a price before
    // (Parity Rulebook §No FX conversion: never silently relabel a stored
    // amount under a different currency).
    final currency = priceMinor == null
        ? null
        : (widget.preset?.regularCurrency ?? prefs?.currency);

    try {
      if (_isEditing) {
        await repo.updatePreset(
          id: widget.preset!.id,
          name: name,
          volumeMl: volumeMl,
          abvPercent: Optional.value(abvPercent),
          regularPriceMinor: Optional.value(priceMinor),
          regularCurrency: Optional.value(currency),
          iconKey: _iconKey,
          iconColor: _iconColor,
        );
      } else {
        final existing = ref.read(allPresetsProvider).valueOrNull ?? [];
        await repo.createPreset(
          name: name,
          beverageType: _beverageType,
          volumeMl: volumeMl,
          abvPercent: abvPercent,
          regularPriceMinor: priceMinor,
          regularCurrency: currency,
          iconKey: _iconKey,
          iconColor: _iconColor,
          sortOrder: existing.length + 1,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save preset: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit drink' : 'Add drink'),
        actions: [
          TextButton(
            key: const Key('preset_editor_save_button'),
            onPressed: _canSave && !_saving ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('preset_editor_name_field'),
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Name',
              border: const OutlineInputBorder(),
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<BeverageType>(
            key: const Key('preset_editor_type_field'),
            initialValue: _beverageType,
            decoration: InputDecoration(
              labelText: 'Beverage type',
              border: const OutlineInputBorder(),
              // updatePreset has no beverageType parameter — the type is
              // fixed once a preset exists (create a new preset instead).
              helperText: _isEditing
                  ? 'Beverage type can\'t be changed after creation'
                  : null,
            ),
            items: [
              for (final type in BeverageType.values)
                DropdownMenuItem(value: type, child: Text(type.displayName)),
            ],
            onChanged: _isEditing ? null : _onTypeChanged,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('preset_editor_volume_field'),
            controller: _volumeCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Volume',
              suffixText: 'ml',
              border: OutlineInputBorder(),
            ),
          ),
          if (_beverageType.isAlcoholic) ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('preset_editor_abv_field'),
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
            key: const Key('preset_editor_price_field'),
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Regular price (optional)',
              prefixText: _currency != null ? '$_currency ' : null,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Icon', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in kDrinkIconKeys)
                _IconChoice(
                  iconKey: key,
                  iconColor: _iconColor,
                  selected: key == _iconKey,
                  onTap: () => _selectIcon(key),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Colour', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hex in _colorOptions())
                _ColorSwatch(
                  hex: hex,
                  selected: _sameHex(hex, _iconColor),
                  onTap: () => _selectColor(hex),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('preset_editor_custom_color_field'),
            controller: _customColorCtrl,
            decoration: const InputDecoration(
              labelText: 'Custom colour (hex)',
              prefixText: '#',
              border: OutlineInputBorder(),
            ),
            onSubmitted: _onCustomColorSubmitted,
            onEditingComplete: () =>
                _onCustomColorSubmitted(_customColorCtrl.text),
          ),
        ],
      ),
    );
  }

  String? get _currency =>
      widget.preset?.regularCurrency ??
      ref.watch(userPreferencesProvider).valueOrNull?.currency;

  List<String> _colorOptions() {
    final defaultColor = _beverageType.defaultIconColor;
    return [
      defaultColor,
      for (final hex in _kColorSwatches)
        if (!_sameHex(hex, defaultColor)) hex,
    ];
  }

  bool _sameHex(String a, String b) =>
      a.toLowerCase().replaceFirst('#', '') ==
      b.toLowerCase().replaceFirst('#', '');
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.iconKey,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final String iconKey;
  final String iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('preset_editor_icon_$iconKey'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TintedIcon(
          assetPath: drinkIconAssetPath(iconKey),
          iconColor: iconColor,
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(
      0xFF000000 | int.parse(hex.replaceFirst('#', ''), radix: 16),
    );
    return InkWell(
      key: Key('preset_editor_color_$hex'),
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
    );
  }
}
