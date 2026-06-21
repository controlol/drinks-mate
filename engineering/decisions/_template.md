# Decision record template

Copy this block per decision. Keep it tight — a paragraph per field, not an essay.

---

## D{n} — {short decision title}

- **Status:** Proposed | Accepted | Superseded
- **Area:** persistence | notifications | charts | icons | architecture | design-system | shared-computation
- **Constraint(s) addressed:** {link to phase-1-constraints.md anchors, e.g. C1, C2}

**Decision.** {The choice, stated in one or two sentences. Name the specific library/API/version.}

**Options considered.**

| Option | Verdict | Why |
| ------ | ------- | --- |
| {chosen} | ✅ chosen | {1-line reason} |
| {alt}  | ❌ rejected | {1-line reason} |

**Rationale.** {Why this is the right call for *this* app's Phase 1 constraints specifically — not generic praise. Tie it to a concrete requirement.}

**Parity implication.** {Will iOS and Android users get the same experience from this choice? If the platforms diverge here, what keeps the user-visible outcome identical? If parity is not affected, say "none".}

**Phase-2 forward-constraint.** {Does this choice keep Phase 2 — accounts/sync/social — open, or does it risk a destructive migration / rewrite? "none" if N/A.}

**Confidence & evidence.** {High/Medium/Low + the basis: official docs, current maintenance status, version, known production use. Flag anything assumed rather than verified.}

---
