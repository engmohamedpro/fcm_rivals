---
id: T-0119
title: Club chemistry — the second dimension, and white/golden links on the pitch
priority: high
status: needs-review
attempts: 1
created: 2026-11-11
---

# T-0119: Club chemistry — the second dimension, and white/golden links on the pitch

## Goal
Chemistry grows a second dimension: players sharing a real-world CLUB gel exactly like players sharing a nationality (same owner formula: every group of n ≥ 2 on-pitch players is worth n − 1 points). The total chemistry is the combination of both dimensions, and the pitch links change from per-nationality colours to a two-colour reading: a line between two players is WHITE when the pair shares one chemistry type (nationality or club) and GOLDEN when it shares both.

## Context
- Owner request 2026-11-11: "right now nationality chemistry is right, I want to add team chemistry, same idea… so the total chemistry is combination of both", plus the line colour spec (1 type → white, 2 types → golden).
- "Team chemistry" here means the player's real-world CLUB (the request's own words: "whether it is nationality or club") — the dataset already carries `clubId`/`clubName` on every player row (dataset v3, schema v12 migration).
- The +10% ceiling STAYS for the combined total: the T-0068 gate locked a 10% chemistry edge at 0.616 win rate against a hard 0.62 band. Letting each dimension add up to 10 (max +20%) would break that locked envelope, so the combined sum is clamped to 10 — the club dimension widens the ways to build chemistry without raising the maximum edge. (If the owner later wants a +20% ceiling, it is a one-line change in `totalChemistryPercentOf` PLUS a balance re-lock — never a silent edit.)
- The links keep the MST-per-group design (n − 1 lines per group per dimension, no clutter); a pair linked by both dimensions is drawn once.

## Requirements
1. `lib/features/match/chemistry.dart`: `chemistryPercentOf` becomes the single-dimension formula (any grouping keys); new `clubChemistryKeyOf(clubId, clubName)` normalizes a club to one grouping key (id wins, name fallback, '' unknown); new `totalChemistryPercentOf({nationalities, clubs})` = min(10, nationality points + club points).
2. `lib/features/match/chemistry_links.dart`: `ChemistryLink` carries the pair's shared-kind set (`ChemistryLinkKind.nationality | club`) instead of the nationality string; `chemistryLinks` merges the two dimensions' spanning trees, dedups pairs, and derives kinds from the PAIR'S ATTRIBUTES (so a pair sharing both is golden even when only one tree picked its edge).
3. Engine: `MatchPlayer` carries `clubId`/`clubName` (defaults 0/'' keep every existing fixture synthetic-neutral); `_TeamRuntime.computeTotals` uses `totalChemistryPercentOf` over the live on-pitch list.
4. Wiring: user cards (`match_session._toMatchPlayer`, `season_store._userMatchPlayer`), AI opponents (`season_store_opponent` club lookup by realPlayerId, `AiSquadPlayer.clubId/clubName`), the tactics chemistry reading (`tactics_setup_view`), the forecast (`match_forecast.chemistryOf`).
5. UI: `squad_pitch_view` passes both key maps; the links painter draws white (`0xFFFFFFFF`) for one-type pairs and gold (`0xFFFFD54F`, the house gold from the retired per-nationality palette) for both-type pairs, same stroke widths and dark under-stroke as before.
6. Tests: chemistry unit tests for the combined formula and the club key normalization; links tests for kind derivation, dedup and the tree invariants; an engine-level club-only sweep (distinct nationalities, one shared club → +10%) mirroring the nationality sweep.

## Out of Scope
- Any change to the T-0068 balance gate or engine constants (the combined clamp keeps the locked envelope; the gate's fixtures are club-less so their numbers are untouched).
- Raising the chemistry ceiling above 10 (see Context).
- Club crests on cards, club-based filters/search, league chemistry.
- l10n: the badge already reads "Chemistry"/"الكيمياء" — it covers the combined reading.

## Acceptance Criteria
- [x] A pair sharing a nationality only → one WHITE line; a pair sharing a club only → one WHITE line; a pair sharing both → ONE golden line (never two stacked).
- [x] The tactics badge, the pre-match chemistry row and the forecast all read the COMBINED nationality + club percentage.
- [x] Engine totals multiply by (1 + combinedPercent / 100), re-evaluated live with substitutions/red cards.
- [x] 11 same nationality AND 11 same club reads +10%, not +20%.
- [x] Existing club-less fixtures (synthetic squads, engine tests, UI tests, the T-0068 gate) behave identically to before.
- [x] `flutter analyze` clean (only the pre-existing `dart:ui` info in `tactic_slider_row.dart` remains, untouched by this task).

## How to Verify
```bash
flutter analyze
flutter test test/features/match/chemistry_test.dart test/features/match/chemistry_links_test.dart
flutter test   # full suite
```

---

## Developer Notes

- **Summary of changes:**
  - `lib/features/match/chemistry.dart` — `chemistryPercentOf` generalized to grouping keys (behavior for nationalities unchanged); new `clubChemistryKeyOf` (id wins over name so one club never splits or double-counts; '' never groups) and `totalChemistryPercentOf` (sum clamped at 10, T-0068 ceiling).
  - `lib/features/match/chemistry_links.dart` — `ChemistryLinkKind` enum, `ChemistryLink.kinds` (Set) replaces the nationality string, `chemistryLinks` takes `clubs:` too, one shared `_treePairs` Prim helper per dimension, pair-union dedup, kinds derived from the pair's attributes (the golden reading is the pair's relationship, not which tree happened to draw it).
  - `lib/features/match/match_event.dart` — `MatchPlayer.clubId` / `clubName` (+ `clone()`).
  - `lib/features/match/match_engine_runtime.dart` — `computeTotals` uses `totalChemistryPercentOf` (nationalities + club keys of the live onPitch list).
  - `lib/features/match/match_forecast.dart` — `chemistryOf(starters)` computes the combined percent per side.
  - `lib/features/squad/tactics_setup_view.dart` — the XI chemistry reading is combined.
  - `lib/features/squad/squad_pitch_view.dart` — passes nationality AND club key maps to the links layer; painter colours by kind count (white/gold), the six-colour per-nationality palette retired.
  - `lib/features/season/season_ai_models.dart` + `season_store_opponent.dart` — `AiSquadPlayer` carries club; the opponent store looks clubs up from the dataset Players table by realPlayerId (same pattern as nationalities; synthetic rows stay club-less).
  - `lib/features/season/season_store.dart` + `match_session.dart` — user cards carry their base club into `MatchPlayer`.
  - `lib/features/simulation/match_simulator.dart` — comment only (synthetic squads stay chemistry-free).
  - Tests: `chemistry_test.dart` (+ club key group, + combined-formula group, + a 200-seed CLUB-only engine sweep alongside the nationality one), `chemistry_links_test.dart` rewritten for the kinds API (9 tests incl. the both-attributes-golden case and overlap dedup).
- **Design decisions worth recording:**
  - Combined clamp at 10, not 20 — locked by T-0068 (0.616 vs the 0.62 band); the one-line lever to change it is documented above.
  - Kinds are attribute-derived, not tree-derived: a pair sharing both types reads golden even if only one dimension's spanning tree drew its edge — this is what the owner's words describe ("two players have the two types of chemistry between each other").
  - Lines vs points: per dimension, lines still equal that dimension's points (n − 1 per group); across dimensions the union can only shrink through dedup. The DISPLAYED percent additionally clamps at 10, so in the extreme (raw 11+) the badge can read 10 while 11 lines show — accepted: the cap bounds the engine effect, not the geometry.
  - Club grouping key: `club:<id>` when the dataset id is known, `club:<name>` fallback, '' unknown — two rows of one club always group; a different club sharing a name never merges into an id-keyed club.
- **How I tested it:** `flutter analyze` → only the pre-existing `dart:ui` info. `flutter test test/features/match/chemistry_test.dart test/features/match/chemistry_links_test.dart` → 31/31 (first run caught two miscounted expectations in my own new tests — fixed, production code unchanged). `flutter test test/features/match/ test/features/season/ test/balance/ test/features/simulation/` → **478/478 green** on this branch (includes the T-0068 chemistry gate, the engine snapshot — untouched because its fixtures are club-less — forecast, season stores, simulator). `flutter test test/features/squad/` → 13 failures; verified **identical 13 fail on clean HEAD** (stash + re-run): pre-existing from the card-regalia commits, NOT from this task. Full-suite comparison: HEAD 1175 pass / 25 fail vs this branch 1192 pass / 25 fail — the same 25 pre-existing failures, plus 17 new passing chemistry tests, zero regressions.
- **Concerns / assumptions:** (1) "Team chemistry" = real-world club, per the request's own wording; if the owner meant the user's own club (all owned players share it), the club half would be a flat constant and the feature would be meaningless — the club reading is the only interpretation that adds a real squad-building axis. (2) The golden tone is the palette's existing `0xFFFFD54F`; on the dark grass with the shared black under-stroke both colours stay legible — not visually verified on a device (headless sandbox), worth a quick look on the owner's screen. (3) The 25 pre-existing full-suite failures on main (schema v12/v14 byte-for-byte, card_class brand-art back, pack opening timeline, squad screen/view UI assertions — the recent card-regalia commits changed rendering without updating these tests) are out of this task's scope and remain open; worth a follow-up task.
