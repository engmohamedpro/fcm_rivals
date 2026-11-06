---
id: T-0040
title: Split pack_effects.dart into the foil painter and the particle painters
priority: medium
status: todo
attempts: 0
depends_on: []
created: 2026-11-06
completed:
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
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes with zero test edits
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines; `pack_effects.dart` barrel keeps consumer imports stable
- [ ] `README.md` architecture table row for the packs UI family updated for the new module files

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

## Review Log
