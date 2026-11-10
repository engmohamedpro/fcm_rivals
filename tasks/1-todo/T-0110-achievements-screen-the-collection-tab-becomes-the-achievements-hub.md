---
id: T-0110
title: Achievements screen — the Collection tab becomes the Achievements hub (categories, badges, progress, claims)
priority: high
status: todo
attempts: 0
depends_on: [T-0108]
created: 2026-11-10
completed:
---

# T-0110: Achievements screen — the Collection tab becomes the Achievements hub (categories, badges, progress, claims)

## Goal
The Collection tab is REPLACED in-place by a production-grade Achievements screen: category sections, badge art per tier metal, geometric progress bars, claim affordances wired to T-0108's pipeline, and the premium visual language the rest of the game already speaks (gold seams, foil art, FcmPressable motion, EN/AR with full RTL). The player-collection browsing itself is NOT lost — it moves to the Team tab's entry points (the squad already shows the full club).

## Context
- Owner decision (2026-11-10): "remove collections screen as it not needed we have team screen — we will replace it into achievements where user win coins."
- What the Collection screen actually holds today (`lib/features/collection/collection_collection_screen.dart`, 471 lines): the owned-cards grid + sort menu. Its dependencies (`player_detail_sheet.dart`, `card_merge_animation.dart`) are HEAVILY reused outside it — the squad pitch, the card reveal and merge flows all import from the collection feature (`lib/features/squad/squad_pitch_view.dart:19`, `lib/features/squad/player_card_reveal.dart:23`). So the feature DIRECTORY survives; only the tab's screen is replaced.
- Where browsing goes: the squad view already opens `PlayerDetailSheet` for every squad player. For the FULL collection (bench + reserves beyond the pitch), add the grid as a second-tier surface reached from the Team tab — NOT a new bottom tab; reuse the existing screen file as the pushed route (rename/keep `CollectionScreen`, invoke it from Team's app-bar action or an equivalent entry point — pick what fits the Team tab's existing layout and document the choice).
- The nav shell (`lib/main.dart` GameShell, items at ~line 146): the third `FcmNavItem` (label `navCollection`, icon `collections_bookmark_rounded`) becomes the Achievements item — new l10n key `navAchievements` (EN "Achievements" / AR "الإنجازات"), icon `Icons.military_tech_rounded`, positioned where Collection sat. The smoke test (`test/widget_test.dart`) asserts `find.text('Collection')` on the shell — that assertion updates to the new label.
- Screen content structure (category → achievements → tiers): lazy — the catalog has ≥40 definitions × tiers; build category sections with slivers, each tier row a lightweight `RepaintBoundary` (the always-on ambient animation means every rebuild is hot; keep per-row painters isolated like the store's foil cells do).
- The claim UX contract was fixed by T-0108: unclaimed-eligible tiers get the claim action; claimed tiers render claimed from the claims table; `AlreadyClaimed` results re-render silently.

## Requirements
1. `lib/features/achievements/achievements_screen.dart` — the new tab screen: header (club crest + coach name + equipped title if any — T-0112's column, render empty-safe here), overall completion ring (claimed tiers / total tiers visible), then category sections. Per tier: badge art (metal-tiered CustomPainter following `card_rarity_art.dart`'s craft — bronze/silver/gold/plat tones, NOT emoji), tier name + localized description, geometric progress bar (current metric value vs threshold, `value / threshold` capped at 1.0 — the geometry is honest: "9 / 16 wins"), coin reward chip (FcmCoin style), claim/claimed state.
2. Progress + claims via riverpod providers over T-0107's derivation and T-0106's claims repository — thin widgets, no business logic in UI (the repo's standing architecture rule).
3. Nav swap in `lib/main.dart` + `navAchievements` key in both arb files + smoke-test label update. The 5-tab layout and FcmBottomNav mechanics stay untouched.
4. Collection browsing relocation: the owned-cards grid reachable from the Team tab (pushed route through `AppRoutes` following its typed-method pattern); every collection test that referenced `CollectionScreen` directly (`test/features/collection/injury_surfaces_test.dart` uses it) keeps passing via the new entry path.
5. `test/features/achievements/achievements_screen_test.dart` — widget tests: renders categories from a catalog fixture; progress bar values correct for derived metrics; claim tap on an eligible tier flips it to claimed and credits through the real service (in-memory db); ineligible tiers show no claim action; claimed tiers show the claimed state; empty save renders zero-state gracefully (no crash, no fake progress).
6. RTL: the screen passes in Arabic locale (directional insets, no hardcoded left/right); l10n for every visible string — zero hardcoded text.

## Out of Scope
- The Profile tab (T-0111/T-0112) — this task touches ONLY the third nav slot.
- Economy bands (T-0109 runs against the real claim path this screen uses).
- Redesigning the collection grid's visuals — it moves as-is.

## Acceptance Criteria
- [ ] Third nav slot is the Achievements screen; no dead code left for the old tab wiring; collection browsing reachable from Team.
- [ ] Badge art is painter-drawn tier metals; progress honest against thresholds; claims flow through the atomic pipeline.
- [ ] EN/AR + RTL verified in tests; `flutter analyze` zero warnings; full `flutter test` green (smoke test updated and green).

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/achievements/ test/widget_test.dart
# Expected: green

flutter test
# Expected: full suite green
```

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
