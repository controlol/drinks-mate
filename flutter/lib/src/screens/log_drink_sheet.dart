import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drink_preset.dart';
import '../repository/providers.dart';

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
  bool _logging = false;

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
    final preset = _selected;
    if (preset == null) return;
    final volume = int.tryParse(_volumeCtrl.text);
    if (volume == null || volume <= 0) return;

    setState(() => _logging = true);
    try {
      await ref.read(drinksRepositoryProvider).logDrink(
            preset: preset,
            volumeMl: volume,
            consumedAt: _consumedAt,
          );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _logging = false);
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
          ? _PickPhase(
              scrollController: scrollController,
              onPick: _pickPreset,
            )
          : _ConfirmPhase(
              preset: _selected!,
              volumeCtrl: _volumeCtrl,
              consumedAt: _consumedAt,
              onTimeChanged: (dt) => setState(() => _consumedAt = dt),
              onBack: _back,
              onConfirm: _logging ? null : _confirm,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase 1 — Preset picker
// ---------------------------------------------------------------------------

class _PickPhase extends ConsumerWidget {
  const _PickPhase({
    required this.scrollController,
    required this.onPick,
  });

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
        color: _parseColor(preset.iconColor),
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
  });

  final DrinkPreset preset;
  final TextEditingController volumeCtrl;
  final DateTime consumedAt;
  final ValueChanged<DateTime> onTimeChanged;
  final VoidCallback onBack;
  final VoidCallback? onConfirm;

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
          title:
              Text(preset.name, style: Theme.of(context).textTheme.titleLarge),
          subtitle: Text(preset.beverageType.displayName),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(height: 8),
              Text('Volume (ml)',
                  style: Theme.of(context).textTheme.labelLarge),
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
              _TimeButton(
                consumedAt: consumedAt,
                onChanged: onTimeChanged,
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
          child: FilledButton(
            onPressed: onConfirm,
            child: onConfirm == null
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirm'),
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
              local.year, local.month, local.day, picked.hour, picked.minute);
          onChanged(updated);
        }
      },
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

Color? _parseColor(String hex) {
  try {
    final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | value);
  } catch (_) {
    return null;
  }
}
