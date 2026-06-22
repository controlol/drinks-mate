import 'package:flutter/material.dart';

/// Parses a 6-digit hex colour string (e.g. `#3b82f6`) to a [Color].
/// Returns null on malformed input rather than throwing.
Color? parseIconColor(String hex) {
  try {
    final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | value);
  } catch (_) {
    return null;
  }
}
