import 'package:flutter/material.dart';

import '../a11y/semantics_labels.dart';
import '../models/drink_entry.dart';
import '../services/format_service.dart';
import '../utils/color_utils.dart';

/// Shared entry-list row for S6 (Today Drinks Log), S9 (Party Session Log),
/// and S3 (History day drill-down) — the app's three editing surfaces
/// (design/user-experience.md).
///
/// Tapping the row opens the edit sheet directly ([onTap]); a trailing
/// delete button ([onDelete]) is the only other affordance — there is no
/// separate "Edit" button and no intermediate action menu. Passing both as
/// null renders the row fully read-only (no tap target, no delete button):
/// the caller decides read-only-ness — S6/S3 key it off `partySessionId`
/// (a session-attached alcoholic entry is read-only there; S9 Party Session
/// Log is authoritative for those), S9 keys it off whether the session has
/// ended.
class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.entry,
    this.fmt,
    this.onTap,
    this.onDelete,
  });

  final DrinkEntry entry;

  /// Formats [entry.volumeMl] per the user's unit preference. Falls back to
  /// a raw `'$volumeMl ml'` string when null (preferences unavailable).
  final FormatService? fmt;

  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final local = entry.consumedAt.toLocal();
    // Source: Parity Rulebook — "Time-of-day display format" (honours the
    // device's 12h/24h preference rather than a hardcoded format).
    final timeLabel = TimeOfDay.fromDateTime(local).format(context);
    final volumeText =
        fmt?.formatVolume(entry.volumeMl.toDouble()) ?? '${entry.volumeMl} ml';
    final abvText = entry.beverageType.isAlcoholic && entry.abvPercent != null
        ? ' · ${entry.abvPercent}% ABV'
        : '';
    final name = entry.name ?? entry.beverageType.displayName;
    final iconColor = entry.iconColor != null
        ? parseIconColor(entry.iconColor!) ??
            Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.primary;
    final icon = entry.beverageType.isAlcoholic
        ? Icons.local_bar_outlined
        : Icons.local_drink_outlined;

    return Semantics(
      label: '$name, $volumeText$abvText, $timeLabel',
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withAlpha(38),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(name),
        subtitle: Text('$volumeText$abvText · $timeLabel'),
        onTap: onTap,
        trailing: onDelete == null
            ? null
            : Semantics(
                label: SemanticsLabels.deleteEntryButton,
                button: true,
                excludeSemantics: true,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ),
      ),
    );
  }
}
