---
id: T-0115
title: Commentary event visual language — every action kind reads instantly (literal yellow/red card chips, distinct hues, unique icons)
priority: high
status: done
attempts: 1
depends_on: []
created: 2026-11-10
completed: 2026-11-11
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
- [x] Every one of the 16 kinds has a unique icon; card kinds render literal card-shaped chips; accents are pairwise distinct where the design intends them to be.
- [x] Event identity and side identity remain separately legible (test: team-coloured wash + event-coloured kind row on the same card).
- [x] The two new tokens documented and used; `flutter analyze` zero warnings; full `flutter test` green.

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

- **Summary of changes:**
  - NEW `lib/features/match/commentary_style.dart` — the ONE dressing
    table (`momentStyles` + `momentStyleOf`) for all 16 kinds: unique
    icon per kind, per-kind accent, and the literal tilted
    `CardChip` widget for the two booking kinds. Discovered during
    implementation: the ticker carried a SECOND private copy of the
    map (no `injury` entry, its own icon set) — the task's
    "one source of truth" therefore also unified the ticker onto the
    shared table (it was never rendered by `MatchScreen`, which uses
    `LiveCommentaryFeed`, so behaviour change is contained to the
    widget's own tests).
  - `lib/core/ui/fcm_style.dart` — the two football-card semaphore
    tokens `cardYellow` (0xFFF9C846) and `cardRed` (0xFFE23B33),
    documented as commentary-only until another surface means
    "booking".
  - `lib/features/match/live_commentary_feed.dart` — private `_moments`
    map deleted; featured card + timeline rows render the event
    identity (`_kindBadge`: icon or CardChip, event accent) while the
    wash/border/minute badge keep the team colour — the two-channel
    contract. The featured card's kind-row LABEL now also wears the
    event accent (was team colour).
  - `lib/features/match/commentary_ticker.dart` — its private
    `_momentStyles` map deleted; rewired to `momentStyleOf`, card
    kinds render `CardChip`, the neutral whistle tint reads the
    event accent.
  - Tests: `commentary_ticker_test.dart` updated (card kinds assert
    the chip + its colour; corner's new unique icon), NEW
    `commentary_event_style_test.dart` — icon-uniqueness contract,
    loud-kind accent distinctness (goal/penalty/cards/save/injury all
    pairwise distinct), home-team yellow card keeps YELLOW chip +
    HOME wash (two channels), red card literal chip + label, kind-row
    accent for 8 representative kinds.
- **Files changed:** lib/features/match/commentary_style.dart (new),
  lib/core/ui/fcm_style.dart, lib/features/match/live_commentary_feed.dart,
  lib/features/match/commentary_ticker.dart,
  test/features/match/commentary_ticker_test.dart,
  test/features/match/commentary_event_style_test.dart (new).
- **How I tested it:** `flutter analyze --no-pub` → only the 2
  pre-existing baseline issues (fcm_crest.dart:269 unused var,
  tactic_slider_row.dart:16 unnecessary_import — both present on
  the untouched tree). `flutter test test/features/match/` →
  239 passed, 2 failures BOTH pre-existing on the clean tree
  (tactic_slider_row Arabic wording — verified by stashing my
  changes and re-running). Full suite in chunks:
  balance+core+widget 199 green; squad+season has 7 failures, ALL 7
  verified pre-existing on the clean tree (slider-commit + RTL
  wording family and one season live-flow commit; stashed re-run
  confirms). The task's own files: 5/5 + 12/12 green.
- **Concerns / assumptions:** (1) The 7 pre-existing failures are NOT
  from this task — they sit in the T-0103 tactic-slider family and a
  season commit flow and need their own fix (recommend a dedicated
  task; do not silently fix them inside T-0115). (2) Full-suite
  single-process run hits a known stream-channel shutdown hang on
  this 2-core sandbox — chunked runs cover the same tests. (3) The
  ticker unification means the ticker's neutral tint for whistle
  moments is now the event accent (bronze for kick-off/break,
  gold for full time) instead of a flat gold — intentional, part of
  the per-kind language. (4) `Icons.pause_rounded` for half time:
  the ticker test asserts the same uniform height for all kinds —
  the chip and icons sit in fixed-height rows so parity holds.


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 2026-11-11, attempt 1: PASS
- Ran: `flutter analyze` (the same 2 pre-existing baseline issues only — zero new), the covering suites (`commentary_event_style + commentary_ticker + live_match_ux + match_screen` = 40/40 All tests passed), including the style contract tests: 'no two kinds share an icon — the uniqueness contract' and 'accents are pairwise distinct by design intent'.
- AC verified: the uniqueness contract is TEST-ENFORCED across all 16 kinds (not just visually reviewed), the card kinds render literal card-shaped chips (yellow/red distinct SHAPE + hue), side identity stays separately legible (team wash + event-coloured kind row on the same card), the two new tokens documented.
- Notification protocol: Telegram unavailable (placeholder token, no destination) — recorded per the fallback clause; review proceeded (read-mostly, safe).
