---
id: T-0066
title: Show the country flag on the mini cards
priority: medium
status: todo
attempts: 0
depends_on: []
created: 2026-11-09
completed:
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
- [ ] Every `FcmMiniCard` rendering a real player shows that player's country flag across the squad screen (pitch, bench, reserves, drag feedback, squad rows) and pack contents; ghost slots show none.
- [ ] Callers passing no `flag` render exactly as before (no layout shift for ghosts / unset cases).
- [ ] New tests (a)-(d) from Requirement 3 pass; existing mini-card tests untouched and green.
- [ ] `flutter analyze` reports zero warnings; `flutter test` full suite green with `test/features/match/` + `test/balance/` passing without `REGEN_SNAPSHOT`.

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

## Review Log
