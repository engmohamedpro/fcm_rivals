---
id: T-0098
title: Build the advanced crest picker in club creation
priority: high
status: todo
attempts: 0
depends_on: [T-0097]
created: 2026-11-09
completed:
---

# T-0098: Build the advanced crest picker in club creation

## Goal
The CLUB CREST section of club creation becomes an advanced crest builder: a live preview plus shape, primary colour, secondary colour and icon pickers with a randomize action — the built `CrestSpec` is what gets saved with the new club.

## Context
- Depends on T-0097 (`CrestSpec`, `FcmCrest`, the `clubs.crest` column and `createClub(spec:)` plumbing — all in `3-archived` before this starts).
- Today's section (`lib/features/onboarding/club_creation_screen.dart:156-182`): a label, then a `Wrap` of six colour-only `_CrestOption` shield swatches (`:257-310`); `_submit` persists `crestIndex` (`:48-53`); the backdrop tint follows the selected colour (`:69,72`).
- The picker must work inside the existing `SingleChildScrollView` form (`:76-77`) — the screen already scrolls; no fixed-height constraint may be added.
- l10n: `lib/l10n/app_en.arb` / `app_ar.arb` (template `app_en.arb`, `l10n.yaml`); section keys like `clubCrestSection` already exist. New UI labels need both locales + `flutter gen-l10n` regen.

## Requirements
1. Rework the CLUB CREST section in `club_creation_screen.dart`: a live `FcmCrest` preview (about 80-96px wide, centered), then compact pickers — SHAPE (all shapes from T-0097), PRIMARY COLOUR (swatch row over the palette), SECONDARY COLOUR (same swatch row), ICON (all icons from T-0097). Selected options highlight in gold like the existing swatch behaviour (`_CrestOption`'s selected border/glow). Primary and secondary may not be the same palette index — the picker falls back to a different default instead.
2. A RANDOMIZE action (dice or shuffle icon) next to the preview that jumps to a random valid combination in one tap.
3. `_submit` persists the built `CrestSpec` through the T-0097 store API, and still writes `crestIndex` as the primary colour's palette index (legacy consumers keep working).
4. The backdrop tint follows the primary colour live, exactly as it follows the selection today.
5. New l10n keys for the visible labels (shape / primary / secondary / icon / randomize — the project's naming style) in EN and AR; regen localizations. RTL: pickers mirror via the file's existing Row/Wrap directionality, no hardcoded left/right.
6. Tests (extend `test/features/onboarding/club_creation_test.dart`): the builder renders with a live preview; changing shape/colour/icon updates the preview and the submitted spec (assert through the store: the saved club's `crest` column matches the last picks); the randomize tap lands on a valid spec (primary ≠ secondary, all fields valid); submitting with defaults saves the default spec; EN and AR pumps both render every label; an RTL pump mirrors without overflow.

## Out of Scope
- Crest editing after creation (no settings screen exists — a later task if wanted).
- AI club crests (T-0099), the crest model/renderer/DB (T-0097), crest display in match screens.
- New palette colours or per-club uploaded images.

## Acceptance Criteria
- [ ] The crest section offers shape, primary, secondary and icon choices with a live preview; every combination renders in the preview without overflow.
- [ ] Randomize produces a valid spec in one tap; the submitted club carries exactly the shown spec (verified through the store round-trip), with `crestIndex` = primary index.
- [ ] Primary and secondary can never collide (picker prevents or auto-corrects).
- [ ] Labels localized EN/AR; RTL mirrors; the screen still scrolls and submits with validation unchanged.
- [ ] `flutter analyze` zero warnings; onboarding suite green with the new tests; full `flutter test` green, no REGEN_SNAPSHOT.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/onboarding/
# Expected: green, including the new picker tests

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

Manual: fresh install → build a shield/crown crest in red+gold, randomize a few times, create the club → the saved club is the crest last shown.

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
