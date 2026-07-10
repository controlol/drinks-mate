/// A single day's peak estimated BAC for the History "Max estimated BAC per
/// day" chart (F4/#26).
///
/// [maxGPerL] is null when no `PartySession` overlapped this day — the chart
/// must show **no bar** for that day, not a zero bar, so it never implies the
/// estimate ran and produced 0 g/L (features.md F4).
class BacDailyBucket {
  const BacDailyBucket({required this.dayStart, this.maxGPerL});

  final DateTime dayStart;
  final double? maxGPerL;
}
