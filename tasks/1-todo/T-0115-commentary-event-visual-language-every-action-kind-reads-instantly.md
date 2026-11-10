---
id: T-0115
title: Commentary event visual language — every action kind reads instantly (literal yellow/red card chips, distinct hues, unique icons)
priority: high
status: todo
attempts: 0
depends_on: []
created: 2026-11-10
completed:
---

# T-0115: Commentary event visual language — every action kind reads instantly (literal yellow/red card chips, distinct hues, unique icons)

## Goal
The live commentary feed's 16 event kinds stop dressing alike: a yellow card looks like a literal small YELLOW card, a red card a literal RED card, goals carry the gold burst, saves the glove green — every kind gets its own icon AND its own hue AND (for the two card kinds) its own SHAPE, so a glance answers "what just happened" without reading. Side identity (which team) stays legible through the featured card's team-coloured wash and border.

## Context
- Owner decision (2026-11-10): "commentary colors and icons feel the same and same colors … for example yellow cards to be yellow like real yellow cards and red cards to be like real red cards and so on."
- The current dressing is one map (`_moments`, `lib/features/match/live_commentary_feed.dart:54-140`): icon + label + ONE neutral accent per kind — but the featured card's actual colour comes from the TEAM side (`_colorOf`, line ~168: home/away colour, neutral only when the side is null), so in practice every featured moment of the same team wears the same colour regardless of kind. Icons repeat too: `Icons.sports_rounded` appears for kickoff/foul, `Icons.flag_rounded` for offside/full-time, `Icons.style_rounded` for BOTH cards, `Icons.sports_soccer_rounded` for goal/corner.
- Palette discipline: `FcmColors` (`lib/core/ui/fcm_style.dart`) has no true football yellow (`goldSoft` is cream) and `danger` is a soft red. Add TWO tokens — `cardYellow` (a saturated football yellow, e.g. 0xFFF9C846 family) and `cardRed` (a decisive red, e.g. 0xFFE23B33 family) — following the file's token doc-comment style. Do not repurpose `gold`/`danger`: they carry existing semantics across the app.
- Design contract (the rule that keeps this readable): the EVENT identity (icon, label, badge/tier colour) is per-kind and never the team colour; the SIDE identity stays on the featured card's wash gradient + border + minute badge (already team-coloured) and on the timeline rows' side stripe. Two channels, two questions, two visual systems.
- Shape contract: the two card kinds render a literal card — a small rounded rectangle (≈10×14px) tilted ~8°, filled with the card colour — replacing the generic icon in BOTH the featured card's kind row and the timeline rows. It is the strongest possible "yellow card = yellow card" read and it also serves colour-blind users (shape + hue + label = three signals).

## Requirements
1. Redesign `_moments` in `lib/features/match/live_commentary_feed.dart` — per kind: a UNIQUE icon (no icon reused across kinds — pick from Material rounded set for visual weight parity at 13px), a distinct accent hue, and for `yellowCard`/`redCard` the literal card-chip widget instead of an icon. Proposed accents (tune while implementing, keep every kind distinct): goal = gold burst (`Icons.sports_soccer_rounded` + gold + a radiating-spark treatment), penalty = goldSoft with `Icons.adjust_rounded`, yellowCard = `cardYellow` chip, redCard = `cardRed` chip, save = success green, injury = danger + cross icon, substitution = silver double-arrow, tactical = silver sliders icon, order = gold megaphone, kickoff = bronze whistle, halfTime = bronze → pause bars, fullTime = gold flag, foul = textDim with a distinct icon, offside = textDim flag-off icon, corner = pitch-green corner flag, none/update = textDim dot. Every kind's label keeps its current text (label strings are unchanged — see Out of Scope for their localization).
2. `_FeaturedMoment` (featured card) + `_Timeline` rows + `_MinuteBadge` — event identity from the new per-kind accent (NOT the team colour); the card's wash/border/minute badge keep the team colour. The injury banner (`InjuryLiveBanner`) keeps its own system — do not restyle it here.
3. The two new colour tokens in `lib/core/ui/fcm_style.dart` with doc comments naming their meaning (football-card semaphore), used by the feed ONLY until another surface legitimately needs them.
4. `test/features/match/commentary_ticker_test.dart` (+ a new `commentary_event_style_test.dart` if cleaner) — for a representative set of kinds (goal, yellowCard, redCard, save, injury, substitution at minimum): the featured card's kind-row icon/colour reflects the EVENT kind regardless of side; a home-team yellow card shows `cardYellow` (NOT the team colour) while its wash/border still show the home colour; the card-chip widget renders for both card kinds (find by Key or type); no two kinds share an icon (a test iterating the dressing map asserting icon uniqueness — the regression this task exists for).
5. Perf discipline unchanged: the feed rebuilds every moment; the card-chip is a plain `CustomPaint`/`Container` — no shaders, no controllers; `RepaintBoundary` usage follows the file's existing pattern.

## Out of Scope
- The goal FLASH animation (T-0116 builds on this task's dressing).
- Localizing the 16 kind labels (they are stylistic small-caps English constants today; a separate l10n task owns them if the owner wants it — do not silently change label text).
- The injury live banner and the half-time/report surfaces.
- The momentum bar and scoreboard colours.

## Acceptance Criteria
- [ ] Every one of the 16 kinds has a unique icon; card kinds render literal card-shaped chips; accents are pairwise distinct where the design intends them to be.
- [ ] Event identity and side identity remain separately legible (test: team-coloured wash + event-coloured kind row on the same card).
- [ ] The two new tokens documented and used; `flutter analyze` zero warnings; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/match/commentary_ticker_test.dart test/features/match/commentary_event_style_test.dart
# Expected: green

flutter test
# Expected: full suite green
```

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
