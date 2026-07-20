/// Why a session ended. Stored as the canonical string in [PartySessionEndReason.stored].
///
/// Source: data-model.md §PartySession — "`endReason` ... `manual` or
/// `auto_timeout`."
enum PartySessionEndReason {
  manual,
  autoTimeout;

  String get stored => switch (this) {
        manual => 'manual',
        autoTimeout => 'auto_timeout',
      };

  static PartySessionEndReason fromStored(String value) => switch (value) {
        'manual' => manual,
        'auto_timeout' => autoTimeout,
        _ => throw ArgumentError.value(value, 'value', 'Unknown endReason'),
      };
}

/// Pure-Dart domain model for a Party Session — no Drift types (D2).
///
/// data-model.md §PartySession. Deliberately has **no** `bacCapGramsPerL`
/// field — the cap is a single persistent setting on `UserPreferences`, not
/// per-session (party-session.md §BAC goal: "not per-session").
class PartySession {
  const PartySession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.endReason,
    required this.useSessionPrices,
    this.tokenName,
    this.tokenValueMinor,
    this.tokenValueCurrency,
    this.name,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final DateTime startedAt;

  /// Null while active.
  final DateTime? endedAt;

  /// Null while active.
  final PartySessionEndReason? endReason;

  /// Whether to apply this session's [PartySessionPrice] overrides when
  /// logging drinks.
  final bool useSessionPrices;

  /// Display label for the session's tokens. Null when tokens are unused.
  final String? tokenName;

  /// What one token is worth, in the minor unit of [tokenValueCurrency].
  final int? tokenValueMinor;

  /// 'EUR' | 'USD' | 'GBP'. Required when [tokenValueMinor] is set.
  final String? tokenValueCurrency;

  /// Optional, user-set freeform label (e.g. "Sarah's birthday"). Already
  /// normalised (control chars stripped, trimmed, ≤40 chars) — see
  /// `normalizePartySessionName` (Parity Rulebook → "PartySession name").
  final String? name;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Soft-delete marker; null means the record is live.
  final DateTime? deletedAt;

  /// True while the session has not ended.
  bool get isActive => endedAt == null;
}
