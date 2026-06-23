import 'package:flutter/material.dart';

// Design-system colour tokens — engineering/decisions/design-system.md §D1.
//
// Exact hex values for the three named accents and the semantic palette are
// **pending the designer's first pass** (flagged as open design questions in
// designer-brief.md). Seeds below produce a Material 3 scheme that reads
// correctly in light and dark mode; final values land when the designer
// delivers the token file.
//
// WCAG AA contrast (≥4.5:1 for normal text) should be verified against the
// designer's final background colours before shipping.

// ---------------------------------------------------------------------------
// Named accents — the three brand colours (C5, designer-brief §Colour)
// ---------------------------------------------------------------------------

/// Azure / sky — primary brand colour; owns the hydration UI identity
/// (progress bar on-pace fill, Today screen accents).
const Color kColorAzure = Color(0xFF4A90D9); // light
const Color kColorAzureDark = Color(0xFF60A5FA); // dark (pending designer)

/// Honey / amber — action accent; used for primary CTAs ("Log drink",
/// "Start party session") and the goal-met celebration.
/// Must be visually distinguishable from [kColorWarning] via label/icon
/// (designer-brief §Colour — "behind-pace amber must visibly differ").
const Color kColorHoney = Color(0xFFF5A623); // light
const Color kColorHoneyDark = Color(0xFFFBBF24); // dark (pending designer)

// Emerald / mint green — Party Mode accent. QUARANTINED: must never appear
// on Today, History, or Settings. Exposed in [PartyColorTokens] to make
// the namespace boundary explicit.
//
// Enforcement: a CI `emerald-quarantine` job should be added manually to
// .github/workflows/ci.yml (the GitHub App lacks `workflows` write permission,
// so it could not be added automatically). The job should grep all non-party
// source files and fail if any reference PartyColorTokens
// (design-system.md §Dark mode & emerald quarantine).
//
// Sanctioned exception — goal-met confetti: mint accents ARE permitted in the
// full-screen goal-met celebration confetti (designer-brief §Goal-met
// celebration: "azure + honey, with mint accents acceptable — not
// Party-exclusive in this moment"). The CI allowlist should include the
// confetti widget path when it is implemented.

/// Namespace for the Party-Mode-only emerald accent.
abstract final class PartyColorTokens {
  PartyColorTokens._();

  /// Emerald / mint — Party tab accent (replaces the earlier plum exploration).
  static const Color emerald = Color(0xFF059669); // light
  static const Color emeraldDark = Color(0xFF34D399); // dark (pending designer)
}

// ---------------------------------------------------------------------------
// Semantic palette (C5, designer-brief §Colour)
// ---------------------------------------------------------------------------

/// Goal-met / success state — green; always paired with an icon + text label
/// (colour is never the sole signal; see design-system.md §Non-colour-signal).
const Color kColorSuccess = Color(0xFF16A34A); // light
const Color kColorSuccessDark = Color(0xFF4ADE80); // dark (pending designer)

/// Behind-pace / warning state — orange-amber, pushed more orange than
/// [kColorHoney] so the two warm hues remain distinguishable at a glance.
/// Must be paired with a text label / icon (same non-colour-signal rule).
/// Dark-mode value is intentionally more orange than [kColorHoneyDark]
/// (yellow-amber) to preserve the hue distinction (designer-brief §Colour).
const Color kColorWarning = Color(0xFFD97706); // light — amber-600
const Color kColorWarningDark = Color(
  0xFFEA580C,
); // dark — orange-600, pending designer

/// Destructive / error state.
const Color kColorError = Color(0xFFDC2626); // light
const Color kColorErrorDark = Color(0xFFF87171); // dark (pending designer)
