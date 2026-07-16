import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drink_preset.dart';
import '../repository/providers.dart';
import '../utils/color_utils.dart';

/// A confirmed alcoholic-drink pick from [PartyLogDrinkSheet] — volume, ABV,
/// name and price may have been overridden from the preset's defaults.
///
/// [name] and [priceMinor]/[currency] are one-off, this-entry-only
/// overrides (party-session.md §Logging an alcoholic drink (during a
/// session)) — they never write back to the preset or to the session-wide
/// `PartySessionPrice` table. [priceMinor] is null when the user left the
/// price field blank, meaning "resolve the usual way" (session price, else
/// the preset's regular price) — the caller decides that resolution, not
/// this sheet.
class AlcoholicDrinkSelection {
  const AlcoholicDrinkSelection({
    required this.preset,
    required this.name,
    required this.volumeMl,
    required this.abvPercent,
    required this.consumedAt,
    this.priceMinor,
    this.currency,
  });

  final DrinkPreset preset;
  final String name;
  final int volumeMl;
  final double abvPercent;
  final DateTime consumedAt;
  final int? priceMinor;
  final String? currency;
}

/// Party Mode's log-drink sheet, filtered to alcoholic presets
/// (party-session.md §Logging an alcoholic drink). Two-phase flow mirroring
/// [LogDrinkSheet]: pick a preset, then confirm volume / ABV / time.
///
/// Does not itself decide whether the drink joins a session or becomes an
/// orphan — the caller (Party screen) handles that with the returned
/// [AlcoholicDrinkSelection], since the "start a session?" prompt needs
/// context (birthday collection, etc.) that doesn't belong in this sheet.
class PartyLogDrinkSheet extends ConsumerStatefulWidget {
  const PartyLogDrinkSheet({super.key});

  @override
  ConsumerState<PartyLogDrinkSheet> createState() => _PartyLogDrinkSheetState();
}

class _PartyLogDrinkSheetState extends ConsumerState<PartyLogDrinkSheet> {
  DrinkPreset? _selected;
  late TextEditingController _volumeCtrl;
  late TextEditingController _abvCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  DateTime _consumedAt = DateTime.now();
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _volumeCtrl = TextEditingController();
    _abvCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _volumeCtrl.dispose();
    _abvCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _pickPreset(DrinkPreset preset) {
    setState(() {
      _selected = preset;
      _volumeCtrl.text = preset.volumeMl.toString();
      _abvCtrl.text = preset.abvPercent?.toString() ?? '';
      _nameCtrl.text = preset.name;
      _priceCtrl.text = '';
      _nameError = null;
      _consumedAt = DateTime.now();
    });
  }

  void _back() => setState(() => _selected = null);

  void _onNameChanged(String value) {
    final result = value.isEmpty
        ? const UsernameValidation.invalid('Name is required')
        : validatePresetName(value);
    setState(() => _nameError = result.isValid ? null : result.error);
  }

  /// One-off, this-entry-only price override (party-session.md §Logging an
  /// alcoholic drink (during a session)) — null when the field is left
  /// blank, meaning the caller should resolve the price the usual way
  /// instead (session price, else the preset's regular price).
  int? get _priceMinor {
    if (_priceCtrl.text.isEmpty) return null;
    final major = double.tryParse(_priceCtrl.text);
    return major == null ? null : (major * 100).round();
  }

  String? get _currency {
    final preset = _selected;
    if (_priceMinor == null || preset == null) return null;
    return preset.regularCurrency ??
        ref.read(userPreferencesProvider).valueOrNull?.currency;
  }

  void _confirm() {
    final preset = _selected;
    if (preset == null) return;
    final volume = int.tryParse(_volumeCtrl.text);
    final abv = double.tryParse(_abvCtrl.text);
    if (volume == null || volume <= 0 || abv == null || abv <= 0) return;
    if (_nameError != null) return;
    if (_priceCtrl.text.isNotEmpty) {
      final price = double.tryParse(_priceCtrl.text);
      if (price == null || price < 0) return;
    }
    Navigator.of(context).pop(
      AlcoholicDrinkSelection(
        preset: preset,
        name: _nameCtrl.text,
        volumeMl: volume,
        abvPercent: abv,
        consumedAt: _consumedAt,
        priceMinor: _priceMinor,
        currency: _currency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => _selected == null
          ? _AlcoholicPickPhase(
              scrollController: scrollController,
              onPick: _pickPreset,
            )
          : _AlcoholicConfirmPhase(
              preset: _selected!,
              volumeCtrl: _volumeCtrl,
              abvCtrl: _abvCtrl,
              nameCtrl: _nameCtrl,
              nameError: _nameError,
              priceCtrl: _priceCtrl,
              consumedAt: _consumedAt,
              onNameChanged: _onNameChanged,
              onTimeChanged: (dt) => setState(() => _consumedAt = dt),
              onBack: _back,
              onConfirm: _confirm,
            ),
    );
  }
}

class _AlcoholicPickPhase extends ConsumerWidget {
  const _AlcoholicPickPhase({
    required this.scrollController,
    required this.onPick,
  });

  final ScrollController scrollController;
  final ValueChanged<DrinkPreset> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(visibleAlcoholicPresetsProvider);
    return Column(
      children: [
        _SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Log alcohol',
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
              itemBuilder: (context, i) => ListTile(
                leading: Icon(
                  Icons.local_bar_outlined,
                  color: parseIconColor(presets[i].iconColor),
                ),
                title: Text(presets[i].name),
                subtitle: Text(
                  '${presets[i].volumeMl} ml'
                  '${presets[i].abvPercent != null ? ' · ${presets[i].abvPercent}% ABV' : ''}',
                ),
                onTap: () => onPick(presets[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlcoholicConfirmPhase extends StatelessWidget {
  const _AlcoholicConfirmPhase({
    required this.preset,
    required this.volumeCtrl,
    required this.abvCtrl,
    required this.nameCtrl,
    required this.nameError,
    required this.priceCtrl,
    required this.consumedAt,
    required this.onNameChanged,
    required this.onTimeChanged,
    required this.onBack,
    required this.onConfirm,
  });

  final DrinkPreset preset;
  final TextEditingController volumeCtrl;
  final TextEditingController abvCtrl;
  final TextEditingController nameCtrl;
  final String? nameError;
  final TextEditingController priceCtrl;
  final DateTime consumedAt;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<DateTime> onTimeChanged;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

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
              Text('Name', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                key: const Key('party_log_drink_name_field'),
                controller: nameCtrl,
                onChanged: onNameChanged,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  errorText: nameError,
                ),
              ),
              const SizedBox(height: 20),
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
              Text('ABV (%)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: abvCtrl,
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
              const SizedBox(height: 20),
              Text(
                'Price (optional, this entry only)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('party_log_drink_price_field'),
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
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
          child: FilledButton(
            onPressed: nameError == null ? onConfirm : null,
            child: const Text('Confirm'),
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
          onChanged(
            DateTime(
              local.year,
              local.month,
              local.day,
              picked.hour,
              picked.minute,
            ),
          );
        }
      },
    );
  }
}

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
