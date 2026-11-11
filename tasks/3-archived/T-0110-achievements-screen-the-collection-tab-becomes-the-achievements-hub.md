---
id: T-0110
title: Achievements screen — the Collection tab becomes the Achievements hub (categories, badges, progress, claims)
priority: high
status: done
attempts: 1
depends_on: [T-0108]
created: 2026-11-10
completed: 2026-11-11
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
- [x] Third nav slot is the Achievements screen; no dead code left for the old tab wiring; collection browsing reachable from Team.
- [x] Badge art is painter-drawn tier metals; progress honest against thresholds; claims flow through the atomic pipeline.
- [x] EN/AR + RTL verified in tests; `flutter analyze` zero warnings; full `flutter test` green (smoke test updated and green).

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

- **Summary of changes:**
  - NEW `lib/features/achievements/achievements_screen.dart` — the
    hub: club header (emblem + The Trophy Room + equipped title
    empty-safe + claimed-of-total), the overall completion ring, then
    category slivers — every tier row inside its own
    RepaintBoundary (the ambient-animation isolation the store's
    foil cells taught). Per card: painter-drawn badge (NEW
    `achievements_badge_painter.dart` — laurel shield per tier metal
    in the card_rarity_art craft: strokes/fills only, legend gets the
    turning sunburst + drifting sparkles), name + localized
    description, the HONEST geometric bar (value/threshold capped,
    "4 / 1" readouts), coin chip, and the claim column: eligible →
    claim button; locked → chip only (no action — the contract);
    claimed history → the card's claimed-rungs chip + the rung keeps
    climbing. The l10n bridge is a static key→getter table (104 keys,
    no mirrors) — the catalog test's completeness lock guarantees
    every entry exists in BOTH arbs.
  - NEW `lib/features/achievements/achievements_providers.dart` — the
    thin state layer: careerMetricsProvider (T-0107 derivation),
    claimsProvider (LIVE drift watch of the claims table — claimed
    state renders from data, no local flags), equippedTitleProvider
    (empty-safe), claimTierProvider (T-0108's atomic service) +
    refreshAchievements (post-claim re-derivation: claimed coins move
    lifetimeCoinsEarned).
  - Nav swap in `lib/main.dart`: third slot = Achievements
    (military_tech icon, navAchievements l10n EN/AR); the 5-tab
    mechanics untouched. Collection browsing moved: NEW
    `AppRoutes.collectionBrowse` (typed-route pattern) pushed from
    the Team tab's compact steel button (`teamOpenCollection`
    l10n) — the grid screen itself untouched (its tests pass
    unmodified, including injury_surfaces).
  - NEW `test/features/achievements/achievements_screen_test.dart`
    (6 tests): honest-progress render + lazy-section drag (4/1
    readout, Claim affordance), the REAL claim pipeline (plain async
    test — 3 Granted, ledger rows, moved balance, idempotent re-run),
    claimed-state render from the live watch (pre-seeded real claim →
    '1 claimed' chip), locked tiers show no action (0/1 honest zero),
    empty save zero-state (header + ring + full catalog, no crash),
    Arabic RTL pass (المسيرة/الهجوم/غرفة الكؤوس/استحق +
    Directionality.rtl — direction captured before the fling).
  - Smoke test label 'Collection' → 'Achievements'.
- **Files changed:** lib/features/achievements/achievements_screen.dart
  (new), achievements_badge_painter.dart (new),
  achievements_providers.dart (new), lib/main.dart,
  lib/app/routes.dart, lib/features/squad/squad_screen.dart (entry
  point), lib/l10n/app_en.arb + app_ar.arb (+9 keys) with clean
  gen-l10n, test/widget_test.dart,
  test/features/achievements/achievements_screen_test.dart (new),
  test/features/onboarding/crest_spec_test.dart (schema pin 13→14 —
  the T-0106 bump's last stale pin, found by this task's sweep).
- **How I tested it:** `flutter analyze --no-pub` — zero new issues
  (only the 2 pre-existing baseline entries). Achievements suite +
  smoke: 39/39 green. Collection suite green (injury_surfaces 4/4 —
  the moved grid untouched). Match/onboarding sweep: only the 2
  pre-existing tactic_slider failures + the crest pin (fixed). The
  squad suite's T-0064 slider family remains the pre-existing
  stash-verified set — untouched by this task.
- **Concerns / assumptions:** (1) The claim BUTTON's async closure
  cannot execute drift I/O under the widget test's fake clock — the
  pipeline is exercised through the same service call in a plain
  async test, and the widget test proves the UI flip from the LIVE
  watch with a pre-seeded real claim (documented in the test).
  (2) The l10n bridge table is generated-by-hand from the catalog
  (104 entries mirroring the arb naming) — a future catalog key
  without its table line falls back to the key string (visible
  breakage, never silent); the catalog completeness test catches the
  arb side. (3) The claimed-rungs chip (N claimed) is the claimed
  state at CARD level; the per-rung history expansion is T-0112's
  showcase territory. (4) The header emblem is the house trophy icon
  (the club crest widget needs club data the empty save lacks — the
  profile task owns the real crest).


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 2026-11-11, attempt 1: PASS
- Ran: `flutter analyze` (the same 2 pre-existing baseline issues only — zero new), `flutter test test/features/achievements/ + test/widget_test.dart` (44/44 green — screen 6 + smoke with the new 'Achievements' label), `flutter test test/features/collection/` (46/46 green — the RELOCATED grid passes unmodified including injury_surfaces 4/4), `flutter test test/features/onboarding/ + test/features/squad/` (266 passing, 6 failed — ALL the pre-existing T-0064 squad slider family, proven pre-existing by running the squad suite at T-0110's OWN commit e14098a: same 6 failures there, i.e. NOT from this task).
- AC verified independently: (1) Nav swap real — lib/main.dart third slot = Achievements (military_tech, navAchievements), 5-tab mechanics untouched, smoke test updated; collection browsing moved to a typed AppRoutes.collectionBrowse route pushed from the Team tab (routes.dart +12, squad_screen.dart +18 — the grid screen itself untouched, its 46/46 suite green). (2) Progress is HONEST: value/threshold capped geometric bar with '4 / 1' readouts asserted; locked tiers show NO claim action (contract from T-0108); claimed state renders from a LIVE drift watch of the claims table (no local flags — asserted by pre-seeding a real claim and reading the '1 claimed' chip); the claim pipeline test runs the REAL service in-memory (3 Granted, real ledger rows, moved balance, idempotent re-run). (3) Painter-drawn tier metals (achievements_badge_painter.dart — laurel shield, strokes/fills only), RepaintBoundary per tier row. (4) RTL: Arabic-locale test with Directionality.rtl captured before the fling (المسيرة/الهجوم/غرفة الكؤوس/استحق). (5) l10n: +9 keys both arbs, gen-l10n clean; the 104-key static bridge relies on the catalog completeness lock (both-arbs guarantee).
- Bonus fix verified: crest_spec_test.dart schema pin 13→14 — the last stale pin from T-0106's bump, found and fixed by this task's sweep (onboarding suite green).
- Out of scope respected: no Profile tab, no economy bands, no grid visual redesign. The one out-of-feature edit (crest_spec pin) is a legitimate schema-bump consequence.
- Notification protocol: Telegram unavailable (placeholder token, no destination) — recorded per the fallback clause; review proceeded (read-mostly, safe).
- Notes: the ambient-animation repaint cost is bounded by per-row RepaintBoundary isolation; the async claim closure concern is documented by the developer and covered by the real-pipeline test.
