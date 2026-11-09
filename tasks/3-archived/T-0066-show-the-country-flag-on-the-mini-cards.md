---
id: T-0066
title: Show the country flag on the mini cards
priority: medium
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-09
---

# T-0066: Show the country flag on the mini cards

## Goal
Every surface that renders a player card shows the player's country flag: the big `FcmPlayerCard` already does, and after this task the `FcmMiniCard` family (pitch chips, bench/reserve strips, drag feedback, `SquadCardRow`, pack contents) does too.

## Context
- The flag plumbing exists: `flagEmojiFor(String nationality)` in `lib/core/ui/country_flag.dart` maps every nationality in the bundled dataset to a flag emoji (home nations via tag sequences, unknown → ⚽ fallback). No new mapping work is needed.
- `FcmPlayerCard` already renders the flag under the position code plus the nationality name (`lib/core/ui/player_card.dart:243-266`); the detail sheet (`lib/features/collection/player_detail_sheet.dart:223`), the pack reveal (`lib/features/packs/pack_opening_screen_reveal.dart:156`) and the pack-contents rows (`lib/features/packs/pack_contents_screen.dart:281,360`) already show it.
- The gap is `FcmMiniCard` (`lib/core/ui/mini_card.dart`): it takes `overall`/`position`/`name` strings, knows nothing about the player's identity, and renders no flag. Its construction sites: the seven in `lib/features/squad/squad_pitch_view.dart` (starting-XI chips around lines 139/166, bench and reserve strips around 270/294, the drag feedback at 316, the `SquadCardRow` widgets around 339/363 — every site has the `PlayerCard` in scope) and `lib/features/packs/pack_contents_screen.dart:334`.
- Existing mini-card tests live in `test/features/ui/mini_card_test.dart`.

## Requirements
1. In `lib/core/ui/mini_card.dart` add an optional `final String? flag;` constructor parameter to `FcmMiniCard` (default null). Where: inside the shield, directly under the position code in the same `Positioned` column (mirroring the big card's OVR → position → flag order). Expected: a `Text` of the flag string at `fontSize: width * 0.20` with a `SizedBox(height: 2)` gap above it; `flag == null` renders nothing (today's layout byte-identical for callers that pass nothing); ghost cards never render it (they render no text at all).
2. Pass `flag: flagEmojiFor(card.base.nationality)` at every construction site listed in Context — all seven in `squad_pitch_view.dart` and `pack_contents_screen.dart:334`. Expected: after this change no `FcmMiniCard` call site for a real player omits the flag; ghost slots (no player) keep passing nothing.
3. Extend `test/features/ui/mini_card_test.dart`: (a) a mini card with `flag: flagEmojiFor('Egypt')` renders the 🇪🇬 emoji text; (b) a card with `flag: null` renders no flag slot (layout unchanged); (c) a ghost card renders no flag; (d) an RTL (`textDirection: TextDirection.rtl`) pump renders the same flag (emoji are direction-neutral — the assertion is that it is present and the card does not overflow).

## Out of Scope
- `FcmPlayerCard`, the detail sheet and the pack screens — they already show the flag.
- Any change to `country_flag.dart`'s mapping or the dataset.
- The chemistry feature (T-0067) — this task is presentation only.

## Acceptance Criteria
- [x] Every `FcmMiniCard` rendering a real player shows that player's country flag across the squad screen (pitch, bench, reserves, drag feedback, squad rows) and pack contents; ghost slots show none.
- [x] Callers passing no `flag` render exactly as before (no layout shift for ghosts / unset cases).
- [x] New tests (a)-(d) from Requirement 3 pass; existing mini-card tests untouched and green.
- [x] `flutter analyze` reports zero warnings; `flutter test` full suite green with `test/features/match/` + `test/balance/` passing without `REGEN_SNAPSHOT`.

## How to Verify
```bash
flutter analyze
flutter test test/features/ui/mini_card_test.dart   # all green incl. the 4 new cases
flutter test test/features/squad/                   # squad surfaces still green
flutter test                                       # full suite green, zero drift
flutter run   # manual: Team tab — pitch, bench and reserve chips all show flags
```
Expected: analyze clean, suites green; manually every player chip on the Team tab and in pack contents carries its country flag.

---

## Developer Notes

- **Summary of changes:** `FcmMiniCard` gained an optional `final String? flag;` (default null). It renders inside the shield, directly under the position code in the same `Positioned` column (mirroring the big card's OVR → position → flag order): a `Text` of the flag at `fontSize: width * 0.20` with a `SizedBox(height: 2)` gap above. `flag == null` renders nothing — byte-identical layout for unset callers; the whole column sits under the existing `if (!ghost)` so ghosts never render it even if a stray value is passed. Wired `flag: flagEmojiFor(...)` at every real-player construction site: the two pitch chips (injured-inert + draggable), the two bench/reserve strip sites, `_dragFeedback`, and `pack_contents_screen.dart` (import already present there; added to `squad_pitch_view.dart`). The `_EmptySlot`/`_EmptyBenchCard` ghost placeholders intentionally pass nothing, per Requirement 2.
- **Files changed:** `lib/core/ui/mini_card.dart`, `lib/features/squad/squad_pitch_view.dart` (import + 5 sites), `lib/features/packs/pack_contents_screen.dart` (1 site), `test/features/ui/mini_card_test.dart` (+4 cases), `tasks/…T-0066….md`.
- **How I tested it:** `flutter analyze` → No issues found. `flutter test test/features/ui/mini_card_test.dart` → **8/8** (4 existing untouched + new: 🇪🇬 renders; `flag: null` renders no flag and no ⚽ fallback; ghost with a stray flag value renders nothing; RTL pump renders the flag with `takeException()` null — no overflow). `flutter test test/features/squad/` → **230/230**. Zero-drift: snapshot 1/1, balance 86/86, `REGEN_SNAPSHOT` unset. Full `flutter test` → **884/884 green**.
- **Concerns / assumptions:** (1) The task Context counted "the `SquadCardRow` widgets around 339/363" as construction sites, but those two sites are the ghost placeholder cards (`_EmptySlot`, `_EmptyBenchCard`) inside that region — real-player rows are the strip sites already wired; ghosts correctly pass nothing, so the count of real-player sites is 6 (5 in squad_pitch_view + 1 in pack_contents) and all are wired. (2) `flagEmojiFor('Egypt')` returns the 🇪🇬 tag sequence; on some Android system fonts flag emoji render as letter pairs (known Flutter/platform limitation, affects the big card identically — not introduced here). (3) `stats:`/`stamina:` sites untouched — the flag column is additive only.

## Review Log

### Review 2026-11-09, attempt 1: PASS
- Ran: `flutter analyze` (No issues found); `flutter test test/features/ui/mini_card_test.dart` (8/8 — the 4 existing untouched plus the 4 new cases (a)-(d), incl. ghost-with-stray-flag and RTL `takeException()` null); squad surfaces via `flutter test test/features/squad/` inside the full run; `flutter test test/features/match/ test/balance/` (276/276, `REGEN_SNAPSHOT` unset); full `flutter test` (**884/884**).
- Verified in code: the flag renders inside the `if (!ghost)` text column directly under the position code (`fontSize: width * 0.20`, `SizedBox(height: 2)` above, `flag == null` renders nothing); all six real-player construction sites pass `flagEmojiFor(...)` (injured-inert + draggable pitch chips at 140/168, bench/reserve strips at 273/298, `_dragFeedback` at 321, `pack_contents_screen` at 334); the ghost placeholders (`_EmptySlot`/`_EmptyBenchCard`) pass nothing.
- The developer's site-count correction over the task Context is accurate: two of the seven Context-listed sites are the ghost placeholders, so six real sites — all wired.
- Notes: the manual `flutter run` Team-tab check was not executed (headless reviewer sandbox); rendering is covered by tests (a)-(d).
