---
id: T-0040
title: Split pack_effects.dart into the foil painter and the particle painters
priority: medium
status: done
attempts: 1
depends_on: []
created: 2026-11-06
completed: 2026-11-06
---

# T-0040: Split pack_effects.dart into the foil painter and the particle painters

## Goal
Bring `lib/features/packs/pack_effects.dart` (980 lines) under the ~800-line convention by separating the giant foil painter from the particle-family painters, with frame-identical visuals.

## Context
Measured on main `b2c0a27` (2026-11-06): `pack_effects.dart` = 980 lines. Top-level map:
- Shared header (effect palette/spec used by every painter): lines 1-94 (≈94 lines).
- `FoilPackPainter` :95-833 (≈739 lines — fan, wordmark band, holo sheen, growing crack).
- Particle family: `LightRaysPainter` :834, `Spark` :885, `ParticleBurstPainter` :901, `ShockwavePainter` :943 (≈147 lines).
If the shared header moves with `FoilPackPainter` the file would measure ≈833 (>800), so the palette/spec must land in its own file consumed by both sides. Follow the barrel pattern so `pack_effects.dart` imports keep working.

## Requirements
1. Split into: `pack_effect_palette.dart` (shared header palette/spec), `foil_pack_painter.dart` (`FoilPackPainter`), `pack_particles.dart` (`LightRaysPainter`, `Spark`, `ParticleBurstPainter`, `ShockwavePainter`); `pack_effects.dart` remains as a barrel re-exporting everything. Pure verbatim relocation, no behaviour change.
2. Every resulting file ≤800 lines; reveal animations frame-identical; `flutter analyze` clean; full `flutter test` green with zero test edits.

## Out of Scope
- Any change to painter geometry, colours, timing curves or animation drivers.
- Splitting `pack_opening_screen.dart` or any other file.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated; full `flutter test` suite passes with zero test edits
- [x] EN/AR localization complete and RTL verified where applicable
- [x] No performance or application-size regression
- [x] Every resulting file ≤800 lines; `pack_effects.dart` barrel keeps consumer imports stable
- [x] `README.md` architecture table row for the packs UI family updated for the new module files

## How to Verify
```bash
wc -l lib/features/packs/pack_effects.dart lib/features/packs/pack_effect_palette.dart lib/features/packs/foil_pack_painter.dart lib/features/packs/pack_particles.dart
flutter analyze
flutter test test/features/packs/
flutter test
```
Expected: every listed file ≤800 lines; analyzer clean; packs suite and full suite green with zero test edits.

---

## Developer Notes
- **Summary of changes:** Split `pack_effects.dart` (980 lines) verbatim into three family libraries — `pack_effect_palette.dart` (85: `kPackAspect`, the once-decoded brand-logo cache + `precachePackLogo`, and the silhouette geometry helpers), `foil_pack_painter.dart` (757: `FoilPackPainter` + its private helpers `_paintCardFan`/`_paintSunburst`/`_starPath`) and `pack_particles.dart` (161: `LightRaysPainter`, `Spark`, `ParticleBurstPainter`, `ShockwavePainter`) — with `pack_effects.dart` kept as a 16-line barrel so every existing consumer import (`main.dart`, `packs_screen.dart`, `pack_opening_screen*.dart`, `player_card_reveal.dart`, `pack_effects_test.dart`) works unchanged. Relocation done by a one-time line-slice script kept outside the repo with a multiset verifier proving every original code/doc line relocated exactly once; the only new content is per-file library docs and import/export lines. Three visibility renames were forced by Dart library privacy (same pattern as T-0039): `_packPath`→`packPath`, `_chamfered`→`chamfered`, `_packLogo`→`packLogo` (negative-lookahead rename kept `_packLogoRequested` private to the palette library). The palette allocation follows the measured evidence: the particle family uses nothing from the old header, and header+foil together measured ≈811 lines (>800), so the header could not ride with the foil painter — the task Context's warning was numerically correct.
- **Files changed:** `lib/features/packs/pack_effects.dart` (now barrel), `lib/features/packs/pack_effect_palette.dart` (new), `lib/features/packs/foil_pack_painter.dart` (new), `lib/features/packs/pack_particles.dart` (new), `README.md` (new "Pack visual effects" row after the UI kit row).
- **How I tested it:** Baseline on the unmodified tree (commit `791a312`, the same tree that passed the post-T-0039 full suite `+709: All tests passed!` exit 0 ~40 min earlier on this machine): `flutter analyze` No issues found + packs/reveal/mini-card smoke (`test/features/packs/`, `player_card_reveal_test.dart`, `mini_card_test.dart`) 53/53 passed. After the split: the `wc -l` gate lists all four files ≤800 (max 757); `flutter analyze` No issues found; the same smoke again 53/53 passed; full `flutter test` → `+709: All tests passed!` exit 0 (~5m20s) — identical test count to the baseline, zero test edits.
- **Concerns / assumptions:** (1) `packLogo` is now a public mutable global read by `FoilPackPainter` — matches the codebase's existing pattern (`TuningOverrides.current` is a public mutable static); writing to it stays the palette library's job via `precachePackLogo`. (2) The full-suite baseline was not re-run pre-split: the tree is byte-identical to the one that passed +709 on this machine earlier in the session, so the post-split run against the same suite count is the meaningful comparison. (3) No Drift codegen involved. None blocking.

## Review Log

### Review 2026-11-06, attempt 1: PASS
- Independent verbatim-relocation check (multiset of all lines, original `791a312:lib/features/packs/pack_effects.dart` vs. the four HEAD files): only-in-original = the 10 lines containing `_packLogo`/`_packPath`/`_chamfered`; only-in-new executable lines = the same 10 renamed to `packLogo`/`packPath`/`chamfered`. Everything else is imports/exports/`library;`/doc comments. `_packLogoRequested` appears in neither diff set — unchanged and still private, as declared.
- Rename scope: `grep -rn` confirms zero remaining private-name references and no `packLogo`/`packPath`/`chamfered` usages outside the palette (declaration) and foil painter (consumption); the extra "chamfered" grep hits are the English word in pre-existing comments/tests of `player_card_painters.dart` / `player_card_test.dart`.
- Ran: `wc -l` on all four files → 16/85/757/161, all ≤800.
- Ran: `flutter analyze` (Flutter 3.47.9 stable / Dart 3.13.7, README pin) → No issues found.
- Ran: `flutter test test/features/packs/` → `+47: All tests passed!`.
- Ran: `flutter test` → `+709: All tests passed!`, exit 0 — identical count to the archived baseline; `git diff 791a312..HEAD` touches no `test/` or `tool/` file, so zero test edits confirmed.
- Scope: only the four lib files + README + this task file changed; no consumer edits, so the 16-line barrel kept all `pack_effects.dart` imports stable. README gained the "Pack visual effects" row after the UI kit row.
- Notes: no localization strings in the diff and the multiset proves no string literal changed, so the EN/AR criterion is met vacuously; no determinism gate in this task's How to Verify (painter code, not engine) — consistent with the task text.
