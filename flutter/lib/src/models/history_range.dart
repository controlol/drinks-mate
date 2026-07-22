/// Weekly (ISO Mon–Sun) or monthly (calendar month) range mode for the
/// History screen's range selector (F4 / S3).
enum HistoryRangeMode { weekly, monthly }

/// The History screen's current range selection: a [mode] and how many
/// whole weeks/months back from the current one to page (`offset = 0` is
/// the current week/month; `offset = 1` is the previous one, etc.).
///
/// `offset` never goes negative — paging cannot move into the future past
/// the current period (design/user-experience.md S3: "step backwards and
/// forwards through past periods").
class HistoryRangeSelection {
  const HistoryRangeSelection({
    this.mode = HistoryRangeMode.weekly,
    this.offset = 0,
  });

  final HistoryRangeMode mode;
  final int offset;

  HistoryRangeSelection copyWith({HistoryRangeMode? mode, int? offset}) {
    return HistoryRangeSelection(
      mode: mode ?? this.mode,
      offset: offset ?? this.offset,
    );
  }
}
