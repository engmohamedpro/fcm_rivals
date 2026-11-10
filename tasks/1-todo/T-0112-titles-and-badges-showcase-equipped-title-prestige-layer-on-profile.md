---
id: T-0112
title: Titles & badges showcase + equipped title — the prestige layer on the Profile tab
priority: high
status: todo
attempts: 0
depends_on: [T-0111]
created: 2026-11-10
completed:
---

# T-0112: Titles & badges showcase + equipped title — the prestige layer on the Profile tab

## Goal
The Profile tab gains its prestige section: the full badge cabinet (every catalog badge by metal tier, earned glowing, unearned as engraved silhouettes — visible, aspirational, never hidden), the titles gallery with an equip flow (one title worn at a time, persisted, shown on the Profile header, the achievements header and wherever the manager is named), and the division-champion titles ("Div 1 Champion") that mark silverware, not just grind.

## Context
- Owner decision (2026-11-10): "info for user titles and badges won from achivments … titles won when he became 1st in any divitions."
- Data already in place by this task's dependencies: T-0105's title registry (achievement-tier titles + division-championship titles), T-0106's `UserSettings.equippedTitle` + `AchievementClaims.titleGranted`, T-0107's `titlesByDivision` metrics, T-0110's badge painter vocabulary (tier metals). This task is pure composition + the equip flow.
- Equip semantics (fixed here): ONE equipped title; equipping is free, unlimited and instant; an equipped title whose source tier was earned stays valid forever (titles are never revoked — even if a future catalog re-shape renames ids, T-0114-style graceful fallback applies); UNKNOWN ids in the settings column (renamed catalog entries, edited saves) fall back to unequipped with a debug log, never a crash.
- Where the equipped title surfaces: Profile identity header (T-0111's chip becomes live), Achievements screen header (T-0110 rendered it empty-safe — now it can show a real value). Match contexts (pre-match header, post-match report) are NOT in this task — the chip is exported as a reusable widget so a later task can drop it in; do not scatter ad-hoc title renders.
- Division-champion titles derive from SEASON outcomes, not claims: a title won by finishing 1st is EARNED the moment the season completes (T-0107 derives it); it needs no claim action and appears in the gallery as owned. Achievement titles need their tier CLAIMED (T-0108) to count as owned. This two-way ownership rule is the subtle part — encode it in ONE domain function (`ownedTitlesFor(metrics, claims, catalog)`), tested both ways.

## Requirements
1. `lib/features/profile/title_badge_showcase.dart` (or split if cleaner) — badges cabinet: grouped by category, every tier's metal badge rendered (earned: full-color painter art + tier name + earned glow; unearned: engraved silhouette at reduced opacity + progress hint "23/32"), `RepaintBoundary` per badge cell; lazy slivers (the cabinet grows with the catalog, not the save — but deep scrolling must stay 60fps).
2. Titles gallery: owned titles with their source line (which achievement tier / which division championship), equip action on owned ones, equipped one marked (the gold-pill treatment the nav uses); unowned titles listed greyed with their earning condition (aspirational visibility — nothing hidden).
3. Equip flow: tap owned title → `setEquippedTitle` (T-0106 repository) → providers invalidate → Profile header + Achievements header re-render with the new title chip. Un-equip affordance (wear none). No dialog needed if a direct toggle is cleaner — the repo favors direct manipulation; document the choice.
4. The two-way ownership rule as ONE tested domain function; the gallery, the chip and the achievements header all consume it — no duplicated logic.
5. `test/features/profile/titles_badges_test.dart` — domain tests for ownership (achievement title owned iff claimed; division title owned iff metric says champion; unknown equipped id falls back to none); widget tests: gallery renders owned/unowned states from fixtures, equip tap persists (in-memory db round-trip: set → reopen provider → chip shows), division title owned with zero claims (won by season outcome alone), unowned shows earning condition.
6. L10n: every title name, source line, earning condition, equip/un-equip label localized EN/AR; RTL verified.

## Out of Scope
- Match-context title displays (export the chip; wiring later).
- New catalog content (T-0105 owns it).
- Any coin flow — prestige is free by design.

## Acceptance Criteria
- [ ] Full cabinet + gallery from real data; the two-way ownership rule tested both ways; unknown-id fallback tested.
- [ ] Equip persists and surfaces on both headers; unequip works.
- [ ] EN/AR + RTL; `flutter analyze` zero warnings; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/profile/
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
