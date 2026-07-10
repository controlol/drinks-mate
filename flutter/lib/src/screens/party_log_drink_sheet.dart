import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drink_preset.dart';
import '../repository/providers.dart';
import '../utils/color_utils.dart';

/// A confirmed alcoholic-drink pick from [PartyLogDrinkSheet] — volume and
/// ABV may have been overridden from the preset's defaults.
class AlcoholicDrinkSelection {
  const AlcoholicDrinkSelection({
    required this.preset,
    required this.volumeMl,
    required this.abvPercent,
    required this.consumedAt,
  });

  final DrinkPreset preset;
  final int volumeMl;
  final double abvPercent;
  final DateTime consumedAt;
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
  DateTime _consumedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _volumeCtrl = TextEditingController();
    _abvCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _volumeCtrl.dispose();
    _abvCtrl.dispose();
    super.dispose();
  }

  void _pickPreset(DrinkPreset preset) {
    setState(() {
      _selected = preset;
      _volumeCtrl.text = preset.volumeMl.toString();
      _abvCtrl.text = preset.abvPercent?.toString() ?? '';
      _consumedAt = DateTime.now();
    });
  }

  void _back() => setState(() => _selected = null);

  void _confirm() {
    final preset = _selected;
    if (preset == null) return;
    final volume = int.tryParse(_volumeCtrl.text);
    final abv = double.tryParse(_abvCtrl.text);
    if (volume == null || volume <= 0 || abv == null || abv <= 0) return;
    Navigator.of(context).pop(
      AlcoholicDrinkSelection(
        preset: preset,
        volumeMl: volume,
        abvPercent: abv,
        consumedAt: _consumedAt,
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
              consumedAt: _consumedAt,
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
    required this.consumedAt,
    required this.onTimeChanged,
    required this.onBack,
    required this.onConfirm,
  });

  final DrinkPreset preset;
  final TextEditingController volumeCtrl;
  final TextEditingController abvCtrl;
  final DateTime consumedAt;
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
            onPressed: onConfirm,
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
