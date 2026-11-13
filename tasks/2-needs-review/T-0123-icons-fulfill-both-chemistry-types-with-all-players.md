---
id: T-0123
title: Icon players fulfill both chemistry types with every player on the pitch
priority: high
status: needs-review
attempts: 1
depends_on: [T-0121]
created: 2026-11-12
completed:
---

# T-0123: Icon players fulfill both chemistry types with every player on the pitch

## Goal
When an icon player is in the formation (or comes on), he counts as sharing BOTH chemistry types — nationality AND club — with every other player in the formation. In the owner's words: "icon players in the formation fulfills the two types chemistry with all players in the formation."

## Context
**Owner request 2026-11-12.** Icons are chemistry wildcards: whatever the other ten players are, the icon links with each of them on both dimensions.

**How chemistry works today (studied):**
- `lib/features/match/chemistry.dart` — `chemistryPercentOf(keys)`: every group of n ≥ 2 equal keys is worth n − 1 points, clamped per dimension; `totalChemistryPercentOf({nationalities, clubs})` = min(10, nationality points + club points). The 10% ceiling is locked by the T-0068 balance gate (0.616 win rate vs a 0.62 band) — **the ceiling must stay 10**.
- `lib/features/match/chemistry_links.dart` — `ChemistryLink(a, b, kinds)` with `ChemistryLinkKind.nationality | club`; spanning trees per dimension over pitch centres; pair sharing one type → white line, both types → golden line.
- Computation sites (all must agree): `match_engine_runtime.dart:223` (`_TeamRuntime.computeTotals` — live, re-evaluated on subs/red cards), `match_forecast.dart:183` (pre-match forecast), `tactics_setup_view.dart:153` (tactics badge), `squad_pitch_view.dart:147` (pitch link drawing, passes both key maps).

**Design decision (implementer must follow):** implement the wildcard in the GROUPING-KEY layer, not as special cases at each of the four sites. Concretely: the icon's nationality key and club key are made UNIQUE PER PAIR — the cleanest exact way is to treat icons via a dedicated expansion at the single shared helper level. Two options, pick ONE and record it in Developer Notes:
- **Option A (recommended):** a shared `iconAwareKeys` helper in `chemistry.dart` that transforms the slot→key maps before `chemistryPercentOf`: for each non-icon player, add one synthetic group of {icon, that player} per dimension (n = 2 → +1 point each). Icons never group with each other via this path (two icons share only the real wildcard with everyone — including each other — so a formation of K icons yields K × 10 other-slots wildcard points pre-clamp; the clamp still bounds the total at 10).
- **Option B:** model icons as a "matches-any" key and make `chemistryPercentOf` pair-aware — more invasive, touches the pure function's contract.

Do NOT multiply icons' keys into every group (that would let one icon join e.g. a 4-man Egypt group as a 5th member — +4 points instead of +1 per pairing — and inflate chemistry). The owner's spec is per-PAIR fulfillment: the icon pairs with EACH player, worth exactly one point per pair per dimension.

**Wire the pitch links to match:** an icon pairs with every other on-pitch player on BOTH kinds → golden line icon↔everyone (the links layer needs the icon's pair-explicit edges; spanning trees are per-group, so icons need their own pair-edge pass, n−1 tree edges do not apply to wildcard pairs — one golden line icon→each teammate).

## Requirements
1. `chemistry.dart`: the wildcard logic (Option A helper or equivalent) with the icon input (slot → isIcon map alongside nationalities/clubs); icons' OWN nationality/club keys are ignored for grouping (an icon's real nationality must not ALSO form a normal group with same-nation players — the wildcard replaces his grouping identity).
2. `totalChemistryPercentOf` gains the icon-aware form (or a wrapper used by all four sites); the combined clamp STAYS at 10 (T-0068 lock).
3. All four computation sites switch to the icon-aware call: `match_engine_runtime.computeTotals`, `match_forecast.chemistryOf`, `tactics_setup_view` XI badge, `squad_pitch_view` link maps. No site is left with the plain call (a grep test locks this).
4. `chemistry_links.dart`: icon slots produce one link to EVERY other on-pitch slot with `kinds = {nationality, club}` (golden); non-icon pairs unchanged. The pitch painter needs no new colour — golden already exists (0xFFFFD54F).
5. `MatchPlayer` carries `isIcon` (default false) — wire it from `PlayerCard.base.isIcon` through `match_session._toMatchPlayer`, `season_store._userMatchPlayer`, and the AI opponent path only if AI squads can ever hold icons (today they cannot — leave synthetic rows icon-free).
6. Chemistry effect magnitude: an icon in an otherwise zero-chemistry XI reads +10% (10 pairs × 1 point × 2 dimensions, clamped) — i.e. one icon alone maxes chemistry. That is a DIRECT consequence of the owner's spec; keep it, and record it in the task notes so the balance gate owner is aware (the T-0068 gate's fixtures are icon-free and stay green).
7. Tests: unit — one icon + 10 chemistry-less players → 10 points pre-clamp, badge reads 10; icon + same-nationality pair (2 Egypt + icon + 8 strangers) → nationality group (1) + icon pairs (2×1 nationality-side) + club side, computed exactly per the spec; two icons → they pair with each other too; no icon → identical to today (regression). Links — icon gets a golden edge to every teammate; two icons get exactly one edge between them. Engine sweep — icon-in-XI vs icon-free XI over seeded matches shows the expected chemistry lift, T-0068 fixtures unchanged.

## Out of Scope
- Raising the 10% ceiling (locked; a raise needs its own balance task).
- AI squads fielding icons; icon-specific match-engine attributes.
- The store/packs side (T-0122) and dataset/balance work (T-0120/T-0124).

## Acceptance Criteria
- [ ] An icon in the XI pairs with all 10 others on both types: pitch shows golden lines icon→each teammate; badge/forecast/engine read the wildcard-inclusive percent.
- [ ] Icon-free formations behave byte-identically to today (all existing chemistry tests green, T-0068 gate green).
- [ ] The icon's real nationality no longer forms a normal nationality group (test: icon of nationality X + one player of nationality X + 9 strangers → the pair does NOT read as a 2-man X group; only the wildcard pairs count).
- [ ] Chemistry still clamps at 10 with an icon present (test: icon + 10 same-club players → 10, not 20+).
- [ ] `grep -rn "totalChemistryPercentOf(" lib/ | grep -v icon` shows every call site is icon-aware (or the plain form is only called from inside chemistry.dart itself).

## How to Verify
```bash
flutter analyze
flutter test test/features/match/chemistry_test.dart test/features/match/chemistry_links_test.dart test/balance/chemistry_balance_test.dart
flutter run -d <device>   # put an icon in the XI (dev seed or DB edit): golden links to everyone, badge reads the combined percent
```
Expected: analyze clean; new + existing chemistry tests pass; manual pitch check shows golden icon links.

---

## Developer Notes

## Review Log

**Review 2026-11-12 (QA, commit 5925017 implemented before reading):** PASS with one low-severity note.
Wildcards implemented at the grouping-key layer (`chemistryPercentWithIcons`); icons' own
nationality/club keys never form ordinary groups; all four computation sites icon-aware
(engine runtime, forecast, tactics badge, pitch links); links layer draws the icon's golden
thread to every other slot; 10% ceiling intact and the T-0068 balance gate re-ran green
(balance suite 109/109; chemistry suites 31/31). Note (F5, LOW): with i ≥ 2 icons the
formula books i×(n−1) links/dimension, double-counting each icon–icon pair by C(i,2) before
the clamp — unreachable in 11-a-side (one icon already caps), but correct it if the ceiling
is ever raised. Verdict: accepted.
