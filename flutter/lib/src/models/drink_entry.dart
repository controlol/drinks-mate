import 'beverage_type.dart';

/// Pure-Dart domain model for a logged drink entry — no Drift types (D2).
///
/// All preset fields are snapshotted at log time (log immutability).
class DrinkEntry {
  const DrinkEntry({
    required this.id,
    this.name,
    required this.beverageType,
    required this.volumeMl,
    this.abvPercent,
    this.priceMinor,
    this.currency,
    this.iconKey,
    this.iconColor,
    required this.consumedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String? name;
  final BeverageType beverageType;
  final int volumeMl;
  final double? abvPercent;
  final int? priceMinor;
  final String? currency;
  final String? iconKey;
  final String? iconColor;
  final DateTime consumedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}
