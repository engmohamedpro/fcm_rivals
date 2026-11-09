---
id: T-0079
title: Strip the tactic options sheet down to option names
priority: high
status: todo
attempts: 0
depends_on: []
created: 2026-11-09
completed:
---

# T-0079: Strip the tactic options sheet down to option names

## Goal
The tactics surfaces show option NAMES only: every always-on explanation/effect text is gone — sections, rows, sliders and chips read clean in the Team tab sheet, the pre-match phase and the live tactics screen (owner decision 2026-11-09: the current text walls confuse users).

## Context
- Owner decision (2026-11-09): the tactic options carry too much unneeded text. This overrides GDD 10.3's "effects must be visible" for the UI — update the GDD accordingly (see Requirements).
- `TacticsGroupScaffold` (`lib/features/match/tactics_sections.dart`) serves THREE hosts: the tactic options sheet (Team tab, `showTacticsOptionsSheet` in `lib/features/squad/tactics_setup_view.dart`), the pre-match tactics phase and the live tactics screen (`lib/features/match/live_tactics_screen.dart`). Removing texts there simplifies all three at once.
- Always-on texts to REMOVE:
  - Section subtitles — `l10n.tacticsInPossessionSubtitle` / `tacticsOutOfPossessionSubtitle` / `tacticsTransitionsSubtitle` (tactics_sections.dart ~121-128).
  - Section effect summaries — `tactics.<group>.effectSummary` (~129-137).
  - Per-option effect summaries under EVERY row — the `summary(selected)` texts in `_SegmentedRow` (~288-295) and `_SliderRow` (~390-397), the `v.modifiers.effectSummary` lambdas (~172, 187, 201, 216, 474, 489, 504, 589, 604, 619), and the mentality `effectSummary` under the mentality slider (tactics_setup_view.dart ~537-547).
  - Estimated-possession readout — `l10n.tacticsEstPossession(...)` (tactics_sections.dart ~222-234).
  - Rest-defence hint — `l10n.restDefenceHint` (tactics_sections.dart ~624-632).
- KEEP (decision, do not remove): the conditional offside-trap deep-line warning `l10n.trapDeepWarning` (~535-558) — it only appears for a genuinely bad combination (deep line + trap on) and prevents a trap; section titles, row labels, option names (slider pills, chips, min/max end labels) — those ARE the names.
- Engine APIs stay: `effectSummary` getters and `modifiers` in `lib/features/match/tactics.dart` remain (engine-facing); the UI simply stops rendering them.
- l10n: after removal the keys `tacticsInPossessionSubtitle`, `tacticsOutOfPossessionSubtitle`, `tacticsTransitionsSubtitle`, `tacticsEstPossession`, `restDefenceHint` become unused — delete them from BOTH `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb` and regenerate (`flutter gen-l10n`; generated files live in `lib/l10n/`). `test/core/ui/l10n_test.dart` guards EN/AR parity — keep it green.
- Tests referencing the sheet: `test/features/squad/squad_view_test.dart` (~lines 280-345: asserts section titles, `FcmScaleSlider` count 10, option names, the 'Balanced' count scoped to the scaffold — those all survive since names stay). Update anything asserting the removed texts and ADD absence assertions.

## Requirements
1. `lib/features/match/tactics_sections.dart` — remove every text listed in Context (subtitles, section summaries, per-row summaries + the `summary` parameters of `_SegmentedRow`/`_SliderRow`, possession estimate, rest-defence hint). The layout tightens accordingly (no empty gaps).
2. `lib/features/squad/tactics_setup_view.dart` — remove the mentality effect-summary text under the mentality slider; the slider, its pill and end labels stay.
3. Keep the conditional `trapDeepWarning` rendering and the offside-trap toggle behavior unchanged.
4. Delete the five now-unused l10n keys from both ARB files and regenerate localizations; no unused-key warnings.
5. `docs/fcm_rivals_GDD_SRS.md` §10.3 — record the owner decision 2026-11-09: tactic options show localized names only; effect percentages live in the engine, not the UI (replaces "effects must be visible" for these surfaces).
6. Tests: update `test/features/squad/squad_view_test.dart` (and any other test asserting the removed strings — run the full suite to find them); add assertions that the sheet renders no effect summary (e.g. the possession estimate and a known summary text are `findsNothing`) in EN, and one AR render of the sheet.

## Out of Scope
- Changing any tactic option's semantics, defaults, or the engine's modifiers.
- The mentality slider control itself, the formation dropdown, Auto Pick, or the sheet's DONE button.
- The pre-match forecast screens' own numbers (win probability etc.) — only the shared tactics scaffold and the sheet's mentality summary change.
- Moving texts to a tooltip/info button — the owner wants them gone, not relocated.

## Acceptance Criteria
- [ ] No always-on effect/subtitle/hint text renders in any of the three hosts; the offside-trap deep warning still appears only for deep line + trap on.
- [ ] Option names, section titles, row labels, slider pills and end labels render in EN and AR exactly as before (RTL unaffected).
- [ ] The five l10n keys are gone from both ARB files, generation is clean, and `test/core/ui/l10n_test.dart` passes.
- [ ] GDD 10.3 documents the names-only decision (dated 2026-11-09).
- [ ] `flutter analyze` zero warnings; `flutter test test/features/squad/ test/core/ui/l10n_test.dart` green; full `flutter test` green.

## How to Verify
```bash
flutter gen-l10n && flutter analyze
# Expected: generation clean, No issues found!

flutter test test/features/squad/squad_view_test.dart test/core/ui/l10n_test.dart
# Expected: all pass, including new absence assertions for the removed texts

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```
