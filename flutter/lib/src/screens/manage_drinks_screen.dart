import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drink_icons.dart';
import '../models/drink_preset.dart';
import '../repository/providers.dart';
import '../services/format_service.dart';
import '../widgets/tinted_icon.dart';
import 'preset_editor_screen.dart';

/// Manage drinks screen (F14 "Manage drinks" section).
///
/// Reached from Settings → Drinks → "Manage drinks". Lists every non-deleted
/// preset (including hidden ones), with reorder (drag handle), hide/unhide,
/// delete (user-created presets only), and create/edit via
/// [PresetEditorScreen].
///
/// Alcoholic presets are shown only when Party Mode is active
/// ([UserPreferences.bacCapGramsPerL] set) — features.md F14: "alcoholic
/// presets visible only when Party Mode active".
class ManageDrinksScreen extends ConsumerWidget {
  const ManageDrinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(allPresetsProvider);
    final partyModeActive =
        ref.watch(userPreferencesProvider).valueOrNull?.bacCapGramsPerL != null;
    final fmt = ref.watch(formatServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage drinks')),
      body: presetsAsync.when(
        data: (allPresets) {
          final presets = partyModeActive
              ? allPresets
              : allPresets.where((p) => !p.beverageType.isAlcoholic).toList();
          if (presets.isEmpty) {
            return const Center(child: Text('No drink presets yet.'));
          }
          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: presets.length,
            onReorderItem: (oldIndex, newIndex) =>
                _onReorder(ref, allPresets, presets, oldIndex, newIndex),
            itemBuilder: (context, index) => _PresetTile(
              key: ValueKey(presets[index].id),
              preset: presets[index],
              index: index,
              fmt: fmt,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load presets: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('manage_drinks_add_fab'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PresetEditorScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// [reorderPresets] appends any id *not* passed in after the entire
  /// passed-in list (AppDatabase.reorderPresets: "finalOrder = [...orderedIds,
  /// ...remainingIds]"), so passing only the Party-Mode-filtered [presets]
  /// subset would push every hidden alcoholic preset to the tail of
  /// [allPresets]'s sortOrder on every reorder. Instead, this builds the
  /// *complete* [allPresets] id list: filtered-out presets keep their
  /// absolute position, and filtered-in ones are replaced in place with
  /// their new drag order — so `orderedIds` covers every non-deleted preset
  /// and `remainingIds` is always empty.
  void _onReorder(
    WidgetRef ref,
    List<DrinkPreset> allPresets,
    List<DrinkPreset> presets,
    int oldIndex,
    int newIndex,
  ) {
    final reordered = [...presets];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final newOrderIds = reordered.map((p) => p.id).toList();

    final visibleIds = presets.map((p) => p.id).toSet();
    var i = 0;
    final finalIds = [
      for (final preset in allPresets)
        if (visibleIds.contains(preset.id)) newOrderIds[i++] else preset.id,
    ];
    ref.read(drinksRepositoryProvider).reorderPresets(finalIds);
  }
}

class _PresetTile extends ConsumerWidget {
  const _PresetTile({
    required super.key,
    required this.preset,
    required this.index,
    required this.fmt,
  });

  final DrinkPreset preset;
  final int index;
  final FormatService? fmt;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${preset.name}"?'),
        content: const Text('This preset will no longer be available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(drinksRepositoryProvider).deletePreset(preset.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleParts = <String>[
      fmt?.formatVolume(preset.volumeMl.toDouble()) ?? '${preset.volumeMl} ml',
      if (preset.regularPriceMinor != null && preset.regularCurrency != null)
        fmt?.formatPrice(preset.regularPriceMinor!, preset.regularCurrency!) ??
            '',
    ]..removeWhere((s) => s.isEmpty);

    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PresetEditorScreen(preset: preset),
        ),
      ),
      leading: TintedIcon(
        assetPath: drinkIconAssetPath(preset.iconKey),
        iconColor: preset.iconColor,
        size: 32,
      ),
      title: Text(preset.name),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('manage_drinks_visibility_${preset.id}'),
            icon: Icon(
              preset.isHidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            tooltip: preset.isHidden ? 'Unhide' : 'Hide',
            onPressed: () {
              final repo = ref.read(drinksRepositoryProvider);
              if (preset.isHidden) {
                repo.unhidePreset(preset.id);
              } else {
                repo.hidePreset(preset.id);
              }
            },
          ),
          if (preset.isUserCreated)
            IconButton(
              key: Key('manage_drinks_delete_${preset.id}'),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }
}
