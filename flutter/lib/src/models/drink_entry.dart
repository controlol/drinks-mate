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
    this.priceTokens,
    this.tokenValueMinor,
    this.tokenValueCurrency,
    this.iconKey,
    this.iconColor,
    this.partySessionId,
    this.presetId,
    this.manualPriceOverride = false,
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

  /// Snapshot of money price at log time. Mutually exclusive with
  /// [priceTokens] (data-model.md §DrinkEntry).
  final int? priceMinor;
  final String? currency;

  /// Snapshot of the token cost at log time (Party Session). Mutually
  /// exclusive with [priceMinor].
  final int? priceTokens;

  /// Snapshot of the token-to-money value at log time. Null when
  /// [priceTokens] is null.
  final int? tokenValueMinor;

  /// Snapshot of the currency [tokenValueMinor] was expressed in. Null when
  /// [priceTokens] is null.
  final String? tokenValueCurrency;
  final String? iconKey;
  final String? iconColor;

  /// FK to the owning Party Session. Null for non-alcoholic drinks and for
  /// alcoholic "orphan" drinks logged with no active session.
  final String? partySessionId;

  /// Preset this entry was logged from, or null when logged without one.
  /// Not authoritative for display (see the snapshot fields above) — only
  /// feeds the preset-usage ranking behind the sort modes (F14 §Sort modes).
  final String? presetId;

  /// True when [priceMinor]/[priceTokens] were set by a deliberate,
  /// this-entry-only price edit (the log-time price field on
  /// `PartyLogDrinkSheet`, or S9's per-entry price edit) rather than
  /// resolved from the preset's regular price or the session-wide
  /// `PartySessionPrice` table. A retroactive party-price edit skips entries
  /// with this set, so the one-off override always wins (party-session.md
  /// §Editing prices during a session).
  final bool manualPriceOverride;
  final DateTime consumedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}
