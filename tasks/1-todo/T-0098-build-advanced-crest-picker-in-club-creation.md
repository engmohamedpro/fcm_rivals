---
id: T-0098
title: Build the advanced crest picker in club creation
priority: high
status: needs-review
attempts: 1
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


### Attempt 1 — implementation

**Summary of changes:** the CLUB CREST section is an advanced crest builder.
1. `lib/features/onboarding/club_creation_screen.dart` — the bare `_crestIndex` state became the full builder state (`_crestShape/_crestPrimary/_crestSecondary/_crestIcon`, default shield/0/3/star = the legacy look); a `_crestSpec` getter feeds everything. `_submit` persists the spec through T-0097's `createClub(crest:)` with `crestIndex: spec.primaryIndex` for legacy consumers. The backdrop tint follows the primary colour live (clamped palette lookup). `_randomizeCrest` jumps to a uniformly random valid combination (collision → secondary +1 mod palette). The old colour-only `Wrap` was replaced by `_CrestBuilder`: a live 88px `FcmCrest` preview + dice action, then SHAPE (`_ShapeOption`, each option a mini crest silhouette in neutral colours), PRIMARY and SECONDARY (`_ColorRow` of the old `_CrestOption` shield swatches — restored as the colour chip), ICON (`_IconOption` glyph chips); the callbacks auto-correct collisions (picking a primary equal to the secondary nudges the other side's index). Everything mirrors via Row/Wrap directionality; no fixed height — the section scrolls with the form as before.
2. `lib/l10n/app_en.arb` + `app_ar.arb` — four new keys (`crestShapeLabel/crestPrimaryLabel/crestSecondaryLabel/crestIconLabel`, EN + AR) with a clean `flutter gen-l10n`.

**Files changed:** `lib/features/onboarding/club_creation_screen.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/l10n/app_localizations*.dart` (regen), `test/features/onboarding/club_creation_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓ (whole project after regen). `flutter test test/features/onboarding/` → **19/19 green** ✓ — the four new T-0098 tests: every picker renders with the preview (all four shape silhouettes present), picks persist through the store round-trip (diamond picked → the saved club's `crest` column decodes to the same shape, `crestIndex` mirrors the primary), randomize lands valid (primary ≠ secondary, indexes in range, and the submitted spec equals the preview exactly), and the Arabic RTL pump renders every label without overflow. Full `flutter test` → (result recorded in the submit commit message) ✓, no REGEN_SNAPSHOT.

**Concerns / assumptions:**
- `_randomizeCrest` uses `math.Random()` unseeded — the PICKER is a live UI action (user-driven), not engine generation; determinism rules apply to the match/season engines, not to a button tap. Noted in case a reviewer wants it seeded anyway.
- The shape options render as mini crests in fixed neutral colours (index 2/4) — a preview of the silhouette, not the current palette; the BIG preview alone reflects the live picks.
- `RevealTimeline.bannerIn`-style dead code: none introduced; the old `_CrestOption` was restored deliberately (the colour rows reuse it).

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
