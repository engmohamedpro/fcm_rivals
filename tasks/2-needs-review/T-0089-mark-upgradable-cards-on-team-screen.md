---
id: T-0089
title: Mark upgradable cards on the team screen when a duplicate exists
priority: high
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-09
completed:
---

# T-0089: Mark upgradable cards on the team screen when a duplicate exists

## Goal
Every player card on the team screen — pitch XI, bench and reserves — that owns a duplicate available for merging shows a small upgradable mark, so the user can see merge opportunities directly from the team view.

## Context
- Owner wording: "a mark that shows this card is upgradable if user has more than two of this card". Interpreted as **two or more owned copies** — a merge consumes exactly one duplicate (`UpgradeEngine.mergedLevel`, `lib/features/upgrades/upgrade_engine.dart:27`: target + duplicate → +1 level), and the Collection sheet already offers Merge as soon as another copy exists (`lib/features/collection/collection_collection_screen.dart:205-210`). If the owner literally meant ≥ 3, that is a one-predicate change — note it in the dev notes, do not block on it.
- Team screen: `lib/features/squad/squad_screen.dart` — today watches only `squadProvider` + `clubProvider`. Cards are `FcmMiniCard` (`lib/core/ui/mini_card.dart:20-204`), rendered by the pitch (`lib/features/squad/squad_pitch_view.dart:159-208`) and the bench/reserve `SquadCardRow` strips (`squad_pitch_view.dart:296-331`); `onPlayerTap` is threaded through `TacticsSetupView` (`lib/features/squad/tactics_setup_view.dart:89`).
- Owned counts: `collectionProvider` (`lib/app/providers.dart:179-182`) lists one entry per owned row; duplicates are grouped client-side by `base.playerId` — the established pattern is `lib/features/collection/collection_collection_screen.dart:70-74`. Only rows with status `'owned'` count (merged duplicates are status `'merged'`).
- Existing card badges (do not collide): injury badge top-start on `FcmMiniCard` (`mini_card.dart:108-118`), out-of-position warn stroke. Collection-grid badge precedent: `FcmPill('×N')` bronze at bottom-left (`collection_collection_screen.dart:396-418`).
- Tests: `test/features/squad/squad_screen_test.dart` (real-DB harness), plus `pitch_layout_test.dart`, `squad_drag_test.dart` — drag-and-drop must keep working.

## Requirements
1. `lib/features/squad/squad_screen.dart` — also watch `collectionProvider`, group owned rows by `base.playerId`, and derive the set of playerIds with count ≥ 2 ("upgradable").
2. Thread an `upgradable` boolean through `TacticsSetupView` → `SquadPitch`/`SquadCardRow` → `FcmMiniCard` (new parameter, default `false`, so every other `FcmMiniCard` consumer is untouched).
3. The mark: a small gold pill with an up-arrow or merge icon (icon-only — no text, so no l10n is needed), placed clear of the injury badge (bottom-start suggested), rendered identically on pitch, bench and reserve cards. Visual only — it must not affect drag-and-drop or hit-testing of the card.
4. Reactivity: merging or selling from the Collection tab already invalidates `collectionProvider`; the team screen must re-derive the marks on the next build (no stale mark after a merge).
5. Tests (real-DB harness):
   - a squad player with 2 owned copies shows the mark (cover both a pitch card and a bench card);
   - a squad player with 1 copy shows no mark;
   - after merging the duplicate (count back to 1) the mark disappears.

## Out of Scope
- Actions on the full-card view (T-0090 owns those).
- The Collection screen, the merge engine, `FcmMiniCard` consumers outside the squad feature.
- Any text label on the mark (icon-only keeps it l10n-free).

## Acceptance Criteria
- [ ] Cards with ≥ 2 owned copies show the mark on the pitch XI and both bench/reserve strips.
- [ ] Cards with 1 copy show no mark; the mark disappears right after a merge consumes the duplicate.
- [ ] No other `FcmMiniCard` consumer renders the mark (default false).
- [ ] Drag-and-drop and existing squad tests unaffected.
- [ ] `flutter analyze` zero warnings; `flutter test test/features/squad/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/squad/
# Expected: squad suite green including the new mark tests

flutter test
# Expected: full suite green
```

Manual: seed two copies of a squad player — the card carries the gold mark on the team screen; merge the duplicate from the Collection tab and return — the mark is gone.

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


### Attempt 1 — implementation

**Summary of changes:** every squad card with an owned duplicate now carries a small gold up-arrow pill on its bottom-start corner — pitch XI, bench and reserves alike. `SquadScreen` watches `collectionProvider`, counts owned rows per `base.playerId`, and derives the upgradable set (count ≥ 2 — the task's own interpretation: a merge consumes exactly one duplicate, matching the Collection sheet's Merge rule); a predicate threads through `TacticsSetupView` → `SquadPitch`/`SquadCardRow` → `FcmMiniCard` (new `upgradable` param, default `false`, so no other consumer changes). The mark is icon-only (no l10n surface), rendered by a new `_UpgradableMark` pill — gold with the ink-colored `upload_rounded` icon, sized like the injury badge (max(10, width×0.18)) and pinned bottom-start so it never collides with the top-start injury badge. Visual only: it rides the card's Stack above the face paint, below nothing interactive — drag-and-drop and hit-testing untouched (the full drag suite re-ran green).

1. `lib/core/ui/mini_card.dart` — the `upgradable` field, the `PositionedDirectional(bottom: 2, start: 2)` mark slot, and the `_UpgradableMark` widget (Container + Semantics('Upgradable') like InjuryBadge's pattern).
2. `lib/features/squad/squad_screen.dart` — `ref.watch(collectionProvider).valueOrNull`, the owned-counts map, the `upgradableIds` set, and `upgradable: (playerId) => upgradableIds.contains(playerId)` passed to the view. `getCollection()` already filters `status = 'owned'` (merged duplicates excluded) — a plain count is the truth.
3. `lib/features/squad/tactics_setup_view.dart` + `squad_pitch_view.dart` — the nullable predicate param threaded to all four `FcmMiniCard` sites (pitch injured/draggable, strip injured/draggable); null (pre-match/live surfaces) shows no mark anywhere.
4. `test/features/squad/squad_screen_test.dart` — `seedMarkSquad`: a club with a hand-seeded deterministic squad (GK×2 in XI slot 0, CM×2 in bench slot 11, ST×1 in XI slot 9) placed through the REAL `saveSquad` path. Test 1: exactly the two duplicated members carry the mark (one pitch, one bench), single-copy members none. Test 2: `mergeDuplicates` through the store consumes the GK's duplicate — his mark disappears, the CM's stays.

**Files changed:** `lib/core/ui/mini_card.dart`, `lib/features/squad/squad_screen.dart`, `lib/features/squad/tactics_setup_view.dart`, `lib/features/squad/squad_pitch_view.dart`, `test/features/squad/squad_screen_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/squad/` → **236/236 green** — the drag-and-drop suite (`squad_drag_test`, `pitch_layout_test`) included, proving the mark changes nothing for swapping ✓. Full `flutter test --concurrency=1` → **952/952 green**, no REGEN_SNAPSHOT ✓.

**Concerns / assumptions:**
- "More than two" interpreted as **≥ 2 owned copies** per the task's own reading (a merge consumes one duplicate; the Collection sheet already offers Merge with one spare copy). If the owner literally meant ≥ 3, the change is the single `e.value >= 2` threshold in `squad_screen.dart` — flagged, not blocking, exactly as the task instructs.
- Test-side iteration worth recording: the first approach opened the starter packs and asserted on counts, but the seeded position-pool draws pair nearly every player naturally (baseline 16/16 duplicated), and FutureProvider cache semantics make mid-test mutations invisible without invalidating through the LIVE container — the final tests seed a deterministic squad instead and invalidate `collectionProvider` on the live container before re-entering the screen, which is exactly the state the real app reaches (Collection-tab merge invalidates; Team-tab watch re-derives).
- The mark renders identically in LTR/RTL via `PositionedDirectional` (bottom-start); the icon has no directional glyph so no mirroring artifact.
- `_UpgradableMark` adds one `Semantics` node per marked card (label 'Upgradable', EN hardcoded like the file's other labels) — screen-reader users get the same signal; a localized label can ride the future l10n sweep of this file.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
