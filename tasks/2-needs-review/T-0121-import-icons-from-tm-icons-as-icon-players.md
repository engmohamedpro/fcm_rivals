---
id: T-0121
title: Import the 73 icons from tm-icons.json as icon players (schema + ownership)
priority: critical
status: needs-review
attempts: 1
depends_on: [T-0120]
created: 2026-11-12
completed:
---

# T-0121: Import the 73 icons from tm-icons.json as icon players (schema + ownership)

## Goal
The 73 players in `assets/data/new/tm-icons.json` exist in the game as **icon players**: first-class players that can be owned, upgraded, played and sold, with their own visual identity (card/mini-card badge) and a persistent `isIcon` flag. This task delivers the data foundation: schema, import, validation, display flag — NOT the icon packs (T-0122) and NOT the icon chemistry wildcard (T-0123).

## Context
**Owner request 2026-11-12:** add icons players from the icons file; they are the rarest cards in the game (tiny chance in the new packs), and on the pitch they fulfill both chemistry types with everyone (T-0123).

**Measured facts about `tm-icons.json` (verified 2026-11-12):**
- 73 objects `{id: string, name, image (never null), position (TM long name, never null), marketValue: int, nationality (never null)}` — **no `clubId`**: icons have no club, so they never form club-chemistry groups (they are wildcards, not club members).
- MV range 77,790,090 – 305,603,925. Under the shipped curve (`baseRatingFor`): 71 icons land OVR 90–99 (16 at 99, 45 at 96, …), 2 land 89. Icons are premium/legendary cards by the existing OVR bands — no band changes needed.
- Position mapping (same table as T-0120): after mapping, all 12 game positions are covered except RM; ST-heavy (27 ST, 17 CAM, 6 RW, 6 GK, …).
- **ID collisions (5):** Messi 28003, Cristiano Ronaldo 8198, Neymar 68290, Modrić 27992, Luis Suárez 44352 appear BOTH in `tm-players.json` (as low-MV active players) and `tm-icons.json` (as icons with 20–100× MV). Transfermarkt reuses the id. **Decision required by this task: the icon record wins** — the icon version of these players replaces the active-player row (an "icon Messi" and an "active Messi" as two different cards would break the one-row-per-id registry, pack pools, and the owned-copies FK). The active versions of exactly these 5 ids are simply absent from the player import (document this in the loader).

**Where the schema lives:** `lib/core/database/app_database.dart` — `Players` table (schema v16), `schemaVersion` getter at line 396, `MigrationStrategy` at 399. Drift generated code in `app_database.g.dart` (regenerate with `dart run build_runner build`). Registry/domain: `lib/core/domain/players.dart` (`BasePlayer`), `lib/features/player_database/player_database.dart` (`PlayerDatabase`, `PlayerDatasetRow`).

**Card/mini-card rendering:** `lib/core/ui/player_card.dart`, `lib/core/ui/card_rarity.dart` (`CardRarity`, 3 values, test-locked `values.length == 3`), `lib/core/ui/card_class.dart` (premium `CardClass`). Icons are NOT a fifth rarity and NOT a fourth CardRarity — they are premium/legendary cards that additionally carry an icon badge (the T-0049 pattern: premium is a probability band + `CardClass` render, not a CardRarity value).

## Requirements
1. Schema v17: `Players.isIcon` boolean, default false (drift `BoolColumn ... withDefault(const Constant(false))`; v16→v17 migration adds the column; bump `schemaVersion` to 17 and regenerate `.g.dart`).
2. Domain: `BasePlayer.isIcon` (default false) + `PlayerDatasetRow.isIcon` (default false). The T-0120 loader imports icons with `isIcon: true`; the 5 colliding ids come ONLY from the icons file (icon record wins, active rows for those ids are dropped from the player import).
3. `PlayerDatabase.validate`: icon rows follow the same rules (positive unique id, non-empty name/nationality, MV in range, mappable position); the club fields stay at their defaults (0/'' — icons never resolve a club).
4. `applyDatasetUpdate` / import path persists `isIcon` on the Players rows (extend the upsert companion). Existing installs: all rows already present read back with `isIcon = false`, then the re-import writes the icon flags — no data migration beyond the column.
5. Ownership/collection paths carry the flag end-to-end: `PlayerCard` (`lib/features/squad/squad_engine.dart`), collection query results (`collection_store.dart` → `PlayerCard(...)` at ~line 545), pack-open insert path, and the sell flow treats icons as normal cards (their MV drives the price formula — no special pricing here).
6. Visual identity: an ICON BADGE on the big card and the mini card (small crown/star glyph or the `ICONS` label) whenever `isIcon` is true, using the existing regalia/painter system in `lib/core/ui/player_card.dart`. Keep it subtle and consistent with the current card design; no new rarity colour.
7. Icons are EXCLUDED from every existing draw pool and store offer (T-0120's pools must not silently include them once isIcon lands): `pack_catalog.dart` `storeOffersFor` filters `isIcon == false`; the registry's pack-drawing pool (collection_store pack open path) excludes icons until T-0122 introduces the icon packs. Add a regression test proving a Rare/Epic/Legendary position pack can never yield an icon.
8. Tests: schema v17 migration test (v16 DB with a row → isIcon false preserved); import test (73 icons present, 5 collisions resolved icon-wins, 0 icons in normal packs); a widget test showing the icon badge on an icon card and its absence on a normal card.

## Out of Scope
- Icon packs in the store and their odds (T-0122).
- Icon wildcard chemistry (T-0123).
- Deleting players_v1.json / test migration / balance re-lock (T-0124).
- Icon-specific stats curve or special upgrade rules.

## Acceptance Criteria
- [ ] Schema v17 opens a v16 database without data loss; every pre-existing players row reads `isIcon = false`.
- [ ] After import, exactly 73 rows have `isIcon = true`; ids 28003/8198/68290/27992/44352 exist ONCE each, as icons with their icon MVs (305,603,925 for Messi/Ronaldo, etc.).
- [ ] No icon can be drawn from any Rare/Epic/Legendary pack or appear in any store offer (regression test).
- [ ] An owned icon card renders the icon badge on the big card and the mini card; a non-icon card renders none.
- [ ] `flutter analyze` clean; schema migration test + new tests pass; existing suite has no NEW failures (25 pre-existing failures on main are documented in T-0119's notes — do not fix them here).

## How to Verify
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test test/features/player_database/ test/features/squad/ test/features/packs/
flutter test test/features/season/schema_v11_migration_test.dart   # migration family still green
```
Expected: analyze clean; new tests pass; icons importable, purchasable-only-via-T-0122 packs (none yet), badge visible.

---

## Developer Notes

## Review Log

**Review 2026-11-12 (QA, commit 5925017 implemented before reading):** PASS.
Schema v17 `players.is_icon` with guarded migration (also fixes a latent v16-step ALTER
crash on pre-players databases); 73 icons imported, all isIcon=true, club-less; the 5
dual-file ids (28003/8198/68290/27992/44352) resolve icon-wins; regular pack scopes and the
AI opponent pool exclude icons (locked by a 60,000-draw exclusivity test); icon holo rarity
renders on big card, mini card and goal scorer. Icon suite 15/15 green. Verdict: accepted.
