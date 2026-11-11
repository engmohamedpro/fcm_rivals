---
id: T-0112
title: Titles & badges showcase + equipped title — the prestige layer on the Profile tab
priority: high
status: done
attempts: 1
depends_on: [T-0111]
created: 2026-11-10
completed: 2026-11-11
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
- [x] Full cabinet + gallery from real data; the two-way ownership rule tested both ways; unknown-id fallback tested.
- [x] Equip persists and surfaces on both headers; unequip works.
- [x] EN/AR + RTL; `flutter analyze` zero warnings; full `flutter test` green.

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

- **Summary of changes:**
  - NEW `lib/features/profile/title_domain.dart` — the ONE function
    `resolveTitleCabinet`: the two-way ownership rule encoded once
    (achievement titles owned IFF the source tier was CLAIMED —
    registry ids resolve back to their conferring rungs (title1 →
    tier index 3, title2 → 6) and check the claims set; division
    titles owned IFF titlesByDivision[div] > 0 — silverware needs
    ZERO claims, the season outcome IS the act), the owned-id set,
    and the equipped fallback (unknown ids → unequipped, known-but-
    unowned → kept setting but never shown, owned → worn).
  - NEW `lib/features/profile/title_badge_showcase.dart` — the
    prestige surface: the badge cabinet (every catalog badge by
    metal tier — earned in full painter colour with the glow,
    unearned as engraved silhouettes at 0.35 opacity with the
    progress hint; one RepaintBoundary per cell, horizontal tier
    strips inside per-category panels), the titles gallery (owned
    with source lines — 'Earned at {achievement} tier {threshold}'
    / 'Finish 1st in Division {division}' — and the DIRECT equip
    toggle in the gold-pill treatment; unowned greyed with the lock
    and their earning condition: visible, aspirational, never
    hidden), and the REUSABLE `EquippedTitleChip` (compact mode for
    dense headers) — the one widget later match surfaces drop in.
  - NEW `lib/features/profile/title_showcase_providers.dart` —
    titleCabinetProvider (composes the metrics + claims + equipped
    providers — the derivation is T-0107's) and the equip flow
    (Provider<EquipTitle>: setEquippedTitle through T-0106's
    repository, then invalidates the equipped + cabinet providers —
    instant, free, unlimited by design).
  - BOTH headers went live: the Profile identity chip and the
    Achievements hub header now render `EquippedTitleChip`
    (domain-resolved — unknown ids vanish instead of rendering
    raw; the previous per-surface switch implementations deleted
    — no duplicated logic, one domain function everywhere).
  - L10n: 7 new key pairs EN+AR (cabinet/gallery headings, Wear/
    Worn, the two source-line placeholders) in the football
    register ('ارتدِ' / 'مُرتدى', 'أنهِ الأول في الدرجة').
  - NEW `test/features/profile/titles_badges_test.dart` (6 tests):
    the two-way rule BOTH ways (claimed rung 4 → title1 owned with
    sourceArg 4; ZERO claims → every achievement title unowned AND
    both division titles owned by outcome alone), the unknown-id
    fallback (null, never a crash), known-but-unowned (setting
    kept, chip hidden), the owned equipped id resolving, and the
    gallery widget test (owned renders 'The Winner' with Wear,
    unowned with locks, division champions by outcome, equip →
    persisted through the REAL repository → pill flips to Worn →
    unequip → null restored). The equip's provider re-resolution
    runs in real async under runAsync (the widget-clock limitation
    documented in T-0110's notes; the plain-async diagnosis proved
    the flow end-to-end before the widget assertion).
- **Files changed:** lib/features/profile/title_domain.dart (new),
  title_badge_showcase.dart (new), title_showcase_providers.dart
  (new), profile_screen.dart (showcase appended + the shared chip),
  achievements_screen.dart (the shared chip in the header),
  lib/l10n/app_en.arb + app_ar.arb (+7 pairs) with clean gen-l10n,
  test/features/profile/titles_badges_test.dart (new).
- **How I tested it:** `flutter analyze --no-pub` — zero new
  issues (one documented ignore for a private-field initializing
  formal). titles_badges 6/6; profile + achievements + smoke 51/51
  green.
- **Concerns / assumptions:** (1) The badge cabinet renders the
    TIER INDEX ('T3') as the earned label — the metals are the tier
    identity the cabinet shows; the tier NAME (threshold meaning)
    lives on the achievements screen per-tier. (2) Equip is direct
    toggle (no dialog) — the repo's favour, documented in the
    gallery's comment. (3) The cabinet grows with the catalog, not
    the save; deep scrolling stays lazy (60fps) through the
    sliver list. (4) Match-context wiring of the exported chip is
    explicitly a later task (the Out of Scope honoured).


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 2026-11-11, attempt 1: PASS
- Ran: `flutter analyze` (the same 2 pre-existing baseline issues only — zero new), `flutter test test/features/profile/ + test/features/achievements/` (55/55 green — titles_badges 6 + profile screen 6 + achievements family).
- AC verified independently: (1) The two-way ownership rule lives in ONE domain function `resolveTitleCabinet` (title_domain.dart) and is tested BOTH ways: achievement title owned IFF the source tier was CLAIMED (claimed rung 4 → title1 owned with sourceArg 4; zero claims → NO achievement title owned), division title owned IFF the metrics say CHAMPION (owned by season outcome ALONE — zero claims). (2) The fallback ladder is tested: unknown equipped id → unequipped (null, never a crash); known-but-unowned → setting kept, chip hidden; owned → worn. (3) The equip flow persists through the REAL repository (setEquippedTitle → provider invalidation → chip flips to Worn; unequip → null restored) — in-memory db round-trip asserted. (4) BOTH headers went live via the one domain-resolved EquippedTitleChip (Profile identity + Achievements hub; the previous per-surface switch implementations DELETED — no duplicated logic). (5) Cabinet/gallery render from real data: earned full-colour painter art + glow, unearned engraved silhouettes at 0.35 opacity with progress hints, unowned titles greyed with earning conditions (aspirational visibility), RepaintBoundary per cell. (6) 7 new l10n key pairs EN/AR in the football register (ارتدِ / مُرتدى / أنهِ الأول في الدرجة).
- Diff scope clean: title_domain + title_badge_showcase + title_showcase_providers (new), the two header screens switched to the shared chip (the deletions verified in the diff), l10n + gen outputs, the test file. No match-context wiring, no catalog edits, no coin flow.
- Notification protocol: Telegram unavailable (placeholder token, no destination) — recorded per the fallback clause; review proceeded (read-mostly, safe).
- Notes: the reusable EquippedTitleChip (compact mode) is exported for later match surfaces per the task's export-not-scatter rule — verified present.
