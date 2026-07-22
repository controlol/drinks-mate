/// A single day's aggregated value for a History chart (F4).
///
/// [dayStart] is the local day-window start (`core`'s `dayWindow`), used as
/// the bucket key so History charts key off the same day boundary as the
/// daily goal and other aggregates (C1).
class DailyBucket {
  const DailyBucket({required this.dayStart, required this.value});

  final DateTime dayStart;
  final int value;
}
