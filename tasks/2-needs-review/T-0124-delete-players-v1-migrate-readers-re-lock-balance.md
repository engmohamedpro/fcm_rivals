---
id: T-0124
title: Delete players_v1.json — migrate direct-reader tests and re-lock balance gates
priority: high
status: needs-review
attempts: 1
depends_on: [T-0120, T-0121, T-0122, T-0123]
created: 2026-11-12
completed:
---

# T-0124: Delete players_v1.json — migrate direct-reader tests and re-lock balance gates

## Goal
`assets/data/players_v1.json` is deleted for good: every test and tool that reads it directly is migrated to the new dataset, and the balance gates that hard-locked numbers measured on the old 20,876-row world are re-measured and re-locked against the new 39,023-row + 73-icon world.

## Context
**Owner request 2026-11-12:** "what i want is to delete players_v1.json and put in replace of it the files i sent you … before deleting players_v1.json study first how it works so that you do the right thing." T-0120 kept the old file alive deliberately: **11 test files and 2 tools read it by path**, and several balance tests assert numbers measured on it. Deleting it without migrating them breaks CI blindly. This task runs LAST, after the game itself (T-0120/0121/0122/0123) no longer needs it.

**Direct readers to migrate (verified by grep, 2026-11-12):**
- `test/features/player_database/real_dataset_test.dart` (asserts `count > 20_000`, Haaland MV ≥ 100M, top MV = 200M, 12 positions, ratio bounds) — rewrite against the new loader's output: 39,023 + 73 icons, Haaland MV 244,483,140, top active MV 244,483,140 (Haaland & Yamal tie), top icon MV 305,603,925 (Pelé/Messi/Maradona/Ronaldo).
- `test/features/packs/pack_tier_bands_test.dart`, `pack_rarity_test.dart`, `legendary_regrade_audit_test.dart`, `pack_reveal_timeline_test.dart` — band populations changed (new shares: rare 92.30% / epic 6.20% / legendary 1.34% / premium 0.16%).
- `test/balance/pack_probability_calibration_test.dart`, `economy_balance_test.dart`, `packs_and_generation_balance_test.dart` — calibration locks measured on the old pools.
- `test/core/ui/card_class_test.dart`, `test/core/domain/base_stats_generator_test.dart` (line 750), `test/core/domain/player_dataset_band_test.dart`.
- `tool/pack_probability_probe.dart`, `tool/dataset_v3_probe.dart` — point at the new files (the dataset_v3 probe's club/league-resolution checks map naturally onto tm-clubs/tm-leagues).
- `lib/features/packs/pack_rarity.dart` doc comment already updated by T-0120; the measured-pool numbers in that comment are refreshed here.

**Balance facts to re-measure (from T-0120 analysis):** rarity shares shift toward rare (92.30% vs 87.64%) because the new scrape includes far more low-MV rows; legendary shrinks to 1.34%, premium grows to 0.16% (62 players ≥ OVR 90 + later the 71 premium icons, which are excluded from normal pools per T-0121). Pack prices re-derive automatically (`packPriceFor`); the GATES that assert price ranges/band rates need new measured locks. The chemistry T-0068 gate and match-engine gates use synthetic fixtures — unaffected. The economy simulator (`lib/features/simulation/economy_simulator.dart`) reads the dataset via the loader; its report numbers shift with the new pools — re-run and record.

**Order matters:** run AFTER T-0121 (icons exist, excluded from normal pools), T-0122 (icon packs priced into the store economy) and T-0123 (chemistry wildcard live) so the re-lock covers the full final world.

## Requirements
1. Migrate every listed test/tool to the new dataset (path constants → the T-0120 loader or direct file reads of `assets/data/new/`), re-basing each hard-locked number on freshly measured values. For every gate that changes, record old lock → new lock in the Developer Notes (auditable trail, the house convention from T-0047/T-0068).
2. Re-measure and re-lock: pack band populations, per-position pool sizes, price ladder sanity (rare < epic < legendary per position where pools exist), EV calibration, economy simulator baseline. Use the existing probe tools (`tool/pack_probability_probe.dart`) to generate the numbers — don't hand-wave.
3. Delete `assets/data/players_v1.json` (git rm). Confirm `pubspec.yaml` needs no change (`assets/data/` directory declaration covers the survivors).
4. Repo-wide zero references: `grep -rn "players_v1" lib/ test/ tool/ docs/` returns nothing except historical task files in `tasks/3-archived/` (history is never edited) — task docs in `1-todo`/`2-needs-review` written before this change keep their mentions and that is acceptable.
5. Full suite green accounting: the 25 pre-existing main failures documented in T-0119's notes stay out of scope (list them again in the review if they still fail); ZERO new failures from this task.

## Out of Scope
- Fixing the 25 pre-existing test failures from the card-regalia/crest commits (separate follow-up).
- Any gameplay/balance tuning beyond re-locking gates to the new measured values.
- Changing the new dataset files themselves.

## Acceptance Criteria
- [ ] `git ls-files assets/data/players_v1.json` is empty; the file is gone from the repo.
- [ ] `grep -rn "players_v1" lib/ test/ tool/` returns nothing.
- [ ] Every migrated balance test passes with its new measured locks; old→new values recorded in Developer Notes.
- [ ] `flutter test` shows no NEW failures vs the pre-task baseline (same 25 or fewer pre-existing failures).
- [ ] `flutter analyze` clean.

## How to Verify
```bash
grep -rn "players_v1" lib/ test/ tool/ docs/ || echo "CLEAN"
git ls-files assets/data/
flutter analyze
flutter test
```
Expected: CLEAN echo; only `new/` files listed under assets/data; analyze clean; full suite with no new failures.

---

## Developer Notes

## Review Log

**Review 2026-11-12 (QA, commit 5925017 implemented before reading):** PARTIAL — file deleted, migration incomplete.
players_v1.json deleted; tools (dataset probe, probability probe) and most tests migrated to
the shared tm_bundle_io loader; several band locks re-measured (rare 92.14/epic 6.19/legendary
1.34/premium 0.34% incl. icons). BUT six deterministic failures remain on main (F6, MED):
real_dataset_test.dart:54 pins old top MV 200,000,000 (now 305,603,925) and :226 expects
top-100 hits from rare-pack opens (top 100 now all premium-band, rare table has 0% premium —
deterministically 0); pack_tier_bands_test.dart:29 and pack_reveal_timeline_test.dart:171
still call legacy `importDatasetFromJson` on the list-format bundle (type-cast crash);
pack_reveal_timeline_test.dart:223 pins PackTier count 3 (now 6); pack_rarity_test.dart:66
pins premium 20–45 (now 133); schema_v10_migration_test.dart:205 pins schemaVersion 16
(now 17). The commit message claims the sweep was completed — it was not. Verdict: fix
required before release; exact fix list in QA_Review_tm-bundle_icon_players.docx §5.1 F6.
