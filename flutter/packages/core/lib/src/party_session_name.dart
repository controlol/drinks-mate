/// `PartySession.name` sanitisation.
///
/// Source: Parity Rulebook → "PartySession name" row (data-model.md
/// §PartySession).
///
/// Deliberately **not** a [validateUsername]-style whitelist — a
/// natural-language session name (e.g. "Sarah's birthday") needs spaces and
/// apostrophes, which that whitelist rejects. Every rule here transforms the
/// input into the value to store, rather than rejecting it: control
/// characters (`Cc`) are stripped, the result is trimmed, and it is capped at
/// [partySessionNameMaxLength] characters (Unicode runes, not UTF-16 code
/// units, so a multi-unit character such as an emoji is never split). Empty
/// after trimming stores as `null`, not an empty string.
library;

/// Max length of a stored `PartySession.name`, measured after trimming.
const int partySessionNameMaxLength = 40;

final RegExp _controlCharPattern = RegExp(r'\p{Cc}', unicode: true);

/// Returns the value to store for a `PartySession.name` input, or `null` for
/// a null/empty-after-trim input.
String? normalizePartySessionName(String? input) {
  if (input == null) return null;
  final stripped = input.replaceAll(_controlCharPattern, '');
  final trimmed = stripped.trim();
  if (trimmed.isEmpty) return null;

  final runes = trimmed.runes.toList();
  if (runes.length <= partySessionNameMaxLength) return trimmed;
  return String.fromCharCodes(runes.take(partySessionNameMaxLength)).trim();
}
