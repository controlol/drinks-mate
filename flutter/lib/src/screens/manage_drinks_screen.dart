import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository/providers.dart';
import '../utils/color_utils.dart';

/// Manage drinks screen (F14 "Manage drinks" section).
///
/// Reached from Settings → Drinks → "Manage drinks". Lists every non-deleted
/// preset (including hidden ones) so the user can see what exists.
///
/// NOTE: full create/edit/hide/delete/reorder actions are the scope of issue
/// #17, which was closed without landing any implementation (see the #18 PR
/// description). This screen intentionally ships read-only for now so
/// Settings has a real navigation target; the CRUD actions land when #17 is
/// re-queued.
class ManageDrinksScreen extends ConsumerWidget {
  const ManageDrinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(allPresetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage drinks')),
      body: presetsAsync.when(
        data: (presets) {
          if (presets.isEmpty) {
            return const Center(child: Text('No drink presets yet.'));
          }
          return ListView.builder(
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final preset = presets[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      parseIconColor(preset.iconColor) ?? Colors.grey,
                ),
                title: Text(preset.name),
                subtitle: Text('${preset.volumeMl} ml'),
                trailing: preset.isHidden
                    ? const Icon(Icons.visibility_off_outlined)
                    : null,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load presets: $e')),
      ),
    );
  }
}
