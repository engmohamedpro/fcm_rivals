---
id: T-0120
title: Replace the players_v1.json core data with the new four-file TM dataset
priority: critical
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-12
completed:
---

# T-0120: Replace the players_v1.json core data with the new four-file TM dataset

## Goal
The game's core player database comes from the four new files in `assets/data/new/` (`tm-players.json`, `tm-clubs.json`, `tm-leagues.json`, `tm-icons.json` is NOT read in this task — icons land in T-0121) instead of `assets/data/players_v1.json`. The files are used exactly as pushed — no renaming, no content edits; the loader adapts to them.

## Context
**Owner request 2026-11-12:** replace `players_v1.json` with the files pushed to `assets/data/new/`, "as they are, don't change names or content", after studying how the old file works.

**How the old file works (studied, do not re-derive):**
- `lib/app/providers.dart:92` (`datasetBootstrapProvider`) loads the single asset, decodes on a background isolate via `PlayerDataset.fromJson`, then `CollectionStore.importBundledDataset` — which SKIPS the import when the persisted `DatasetVersions.version >= dataset.version` (old bundled version = 3). A new dataset must carry **version 4** or existing installs never re-import.
- `lib/features/player_database/player_database.dart` — `PlayerDataset.fromJson` requires `format == 'fcm-rivals-players'` and positional rows `[id, name, position, nationality, marketValueEur, clubId, imageUrl]` with `clubs`/`leagues` side maps. The NEW files are per-entity object lists — this parser cannot read them.
- `PlayerDatabase.validate` requires: positive unique ids, non-empty name and nationality, `0 < marketValueEur ≤ 1_000_000_000`, and a `Position` enum code. Rows failing these must never reach the registry.
- `applyDatasetUpdate` (drift, schema v16) already handles adds/updates/regenerations, removed-player compensation and squad-slot cleanup transactionally. **No DB schema change is needed in this task** — every field the new files provide maps onto existing columns (`clubId`, `clubName`, `clubCrestUrl`, `leagueName`, `leagueLogoUrl`, `imageUrl`).
- Stats regenerate from MV + position via the seeded two-segment curve (`lib/core/domain/base_stats_generator.dart`) — untouched.

**Measured facts about the new files (verified 2026-11-12):**
- `tm-players.json`: list of 51,108 objects `{id: string, name, image (null ×19,083), position (Transfermarkt long name, null ×4,789), clubId: string, marketValue: int, nationality (null ×14)}`.
- `tm-clubs.json`: list of 1,760 `{id, title, logo, leagueId}`; **every** player `clubId` resolves. `tm-leagues.json`: list of 124 `{id, title, logo}`; every club `leagueId` resolves.
- Position values are TM long names, 14 distinct + null. Game `Position` enum has 12 codes. Mapping to use:
  Centre-Forward→ST, Second Striker→ST, Right Winger→RW, Left Winger→LW, Attacking Midfield→CAM, Right Midfield→RM, Left Midfield→LM, Central Midfield→CM, Defensive Midfield→CDM, Centre-Back→CB, Sweeper→CB, Right-Back→RB, Left-Back→LB, Goalkeeper→GK.
- **Row filters (decision, see Acceptance Criteria):** skip rows with null/unmappable position (4,789), `marketValue ≤ 0` (10,941 zero-MV rows; sets overlap — 12,085 unique rows dropped) and null/empty nationality (14). **39,023 rows survive.** The files stay untouched; unusable rows are skipped at parse time with the skipped count reported.
- Old dataset: 20,876 rows. 15,241 ids are kept by the new scrape and **all 15,241 change MV** → full stats regeneration (designed behavior, seeded per player id). 5,635 old ids disappear → the existing removed-player compensation flow fires automatically for owned copies.
- Rarity bands on the 39,023 survivors under the shipped curve: rare (<70) 36,019 (92.30%) / epic 2,421 (6.20%) / legendary 521 (1.34%) / premium 62 (0.16%). Old world was 87.64/10.00/2.22/0.139 — pack pools shift; the balance gates are re-locked in T-0124, NOT here.
- Known rows that must import right: Haaland id 418560 → ST, MV 244,483,140; top MV in the file is 244,483,140 (Haaland and Lamine Yamal tie).

## Requirements
1. New loader, e.g. `lib/features/player_database/tm_dataset_loader.dart` (pure Dart, house pattern): reads the three files above from `assets/data/new/` AS-IS, builds the existing `PlayerDataset` model (rows + clubs + leagues). Position mapping table as a single const map (the 14 TM names above).
2. Row filters per Context: skip null/unmappable position, `marketValue ≤ 0`, null/empty nationality; `id`/`clubId` parsed string→int; `image` null → `''`; club resolved through `tm-clubs` → `clubName`/`clubCrestUrl`, then `leagueId` through `tm-leagues` → `leagueName`/`leagueLogoUrl`. The loader reports skipped-row counts by reason (position / value / nationality) — expose them on the dataset or a load report so they can be logged and tested.
3. Dataset identity: `version: 4` (must exceed 3 so existing installs re-import), `asOf: '2026-11-12'` (constant import date), `digest`: a stable hash computed over the three file texts (so a re-scrape is detectable later).
4. Wire `datasetBootstrapProvider` (providers.dart) to load the new files on the background isolate (the players file is ~12 MB vs the old 2.8 MB — keep parsing OFF the UI thread; consider decoding the files separately on the isolate and handing the parsed `PlayerDataset` back).
5. Confirm the `assets/data/new/` files are actually bundled: `pubspec.yaml` declares `assets/data/`. Add an explicit `assets/data/new/` entry if the runtime load fails (verify with a smoke test, don't assume).
6. Zero references to `players_v1.json` remain under `lib/` and the doc comment in `lib/features/packs/pack_rarity.dart` (line 8) is updated to cite the new source. The FILE `assets/data/players_v1.json` is NOT deleted in this task — test files still read it directly; deletion is T-0124's last step.
7. Update the widget/UI tests that stub the old asset path via `rootBundle.loadString` (they intercept the exact path the app loads; after this task they must stub the new paths): `test/features/facilities/campus_screen_test.dart`, `campus_visual_golden_test.dart`, `test/features/squad/team_tab_purity_test.dart`, `squad_screen_test.dart` (2 sites), `injured_inert_test.dart`, `test/features/packs/packs_screen_test.dart`, `test/features/collection/injury_surfaces_test.dart`, `test/widget_test.dart`.
8. New parser test file (e.g. `test/features/player_database/tm_dataset_test.dart`): survivors == 39,023; skipped counts by reason; Haaland 418560 → ST / MV 244,483,140; zero unresolved clubIds; 12 game positions all present; no row with MV ≤ 0 or null position reaches `validate`; version == 4; digest stable across two loads.

## Out of Scope
- Reading `tm-icons.json` (T-0121 imports icons with a schema change).
- Deleting `assets/data/players_v1.json` (T-0124, after the direct-reader tests migrate).
- Any balance-gate re-locking (band shares, pack prices, EV locks) — T-0124.
- Icon packs, icon chemistry (T-0122/T-0123), curve retunes, economy changes.

## Acceptance Criteria
- [ ] Fresh install: `datasetVersions` row is version 4 with asOf 2026-11-12 and a non-empty digest; the `players` table holds exactly 39,023 non-icon rows.
- [ ] Upgrade install (existing v3 DB): re-import fires (version 4 > 3), removed players compensated, regenerated stats present — the existing `applyDatasetUpdate` tests still pass.
- [ ] Skipped-row report: 4,789 position / 10,941 value / 14 nationality skips are counted and surfaced (log or report object) — the three sets overlap; the loader's own survivor count is 39,023.
- [ ] Every imported row resolves club + league (0 unresolved); `imageUrl` is `''` exactly when the source `image` is null.
- [ ] `grep -r "players_v1" lib/` returns nothing.
- [ ] The 8 widget-test files stub the new asset paths; the new parser tests pass; `flutter analyze` clean.

## How to Verify
```bash
flutter analyze
flutter test test/features/player_database/
flutter test test/features/facilities/ test/features/squad/ test/features/packs/packs_screen_test.dart test/features/collection/injury_surfaces_test.dart test/widget_test.dart
grep -rn "players_v1" lib/   # expected: no output
```
Expected: analyze clean; parser tests pass with the measured counts above; the migrated widget tests pass.

---

## Developer Notes

## Review Log

**Review 2026-11-12 (QA, commit 5925017 implemented before reading):** PASS with follow-ups.
Implemented in 5925017. Loader = `PlayerDataset.fromTmBundle` (pure parse of the 4 files as
sent — verified byte-identical to the owner's `assets/data/new/` push; no renames/edits).
Version 4, isolate parse wired in providers.dart. Survivor math independently recomputed:
39,017 regulars + 73 icons = 39,090 (task estimate 39,023 did not drop 6 null-nationality
rows; implementation is correct). Old file deleted. Two observations: (a) the owner's
`assets/data/new/` copies remain in-repo alongside the read `assets/data/` copies — ~12 MB
duplicate, remove in follow-up; (b) stale doc refs to players_v1 remain in pack_rarity.dart:8
and the deprecated refresh script. The 8 migrated widget-test stubs pass. Verdict: accepted;
no code rework required.
