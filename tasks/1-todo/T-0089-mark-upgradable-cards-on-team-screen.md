---
id: T-0089
title: Mark upgradable cards on the team screen when a duplicate exists
priority: high
status: todo
attempts: 0
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

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
