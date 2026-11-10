---
id: T-0111
title: Profile tab — sixth bottom-nav destination with career stats (W/D/L, win rate, goals, silverware)
priority: high
status: todo
attempts: 0
depends_on: [T-0107]
created: 2026-11-10
completed:
---

# T-0111: Profile tab — sixth bottom-nav destination with career stats (W/D/L, win rate, goals, silverware)

## Goal
A new bottom-navigation Profile tab: the manager's career card — club identity, career W/D/L with win rate, goals for/against, clean sheets, streak records, season history with promotion/relegation outcomes, division titles and trophies. One glance answers "who am I as a manager" — the numbers the owner explicitly listed, composed from the derivation engine that already exists.

## Context
- Owner decision (2026-11-10): a profile tab with "info for user … and win rate and match won number and drawn and lost and titles won when he became 1st in any divisions and so on."
- ALL of these numbers are already derived by T-0107's `CareerMetrics` (MatchResults → W/D/L and goals; Seasons/LeagueTeams → final positions, titles, promotions; streaks career-scoped). This screen COMPOSES; it does not re-query. If a stat the design needs is missing from the metrics model, the change goes into T-0107's derivation file (with tests), not into a private query in the screen — one derivation, many surfaces.
- Six tabs in the bottom nav (`lib/main.dart` GameShell, items at ~line 146): Season, Team, Achievements, Campus, Store, Profile. Six destinations in a 5-slot-wide phone nav is tight but viable at the existing typography/spacing (labels ~11.5px, icons 24px, 48px touch targets — the FcmBottomNav row is `Expanded` per item, so 6 × ~62px ≈ 372px minimum width, safe on a 360dp phone; VERIFY on the smallest supported width and if cramped, the Profile icon's label can use the compact one-word form — document the decision). Position: Profile LAST (after Store) — the "self" destination conventionally closes the row; it also keeps the mid-session tabs (Season/Team) adjacent, which matters for the hot path.
- Win rate precision: `wins / matchesManaged` with locale-aware number formatting (percent, one decimal, AR digits per the app's locale-aware number convention — no hardcoded `%` concatenation).
- Empty save (fresh club, zero matches): the screen renders an inviting zero-state ("Your career starts now" tone), never NaN/0.0% crashes — every division is a fresh install's first screen after onboarding.

## Requirements
1. `lib/features/profile/profile_screen.dart` — the tab screen, thin widgets over providers: (a) identity header — crest (the real club crest widget), club name, coach name, joined date (earliest `acquiredAt` or club creation, T-0107's `joinedAt`), equipped title chip (T-0112's column, empty-safe here); (b) career stat panel — matches, W/D/L, win rate, goals for/against, clean sheets, longest win & unbeaten streaks (localized labels, locale-aware numbers); (c) silverware section — division titles grouped by division (the trophy count + per-division plates, "Div 1 ×2, Div 3 ×1" reading); (d) season history list — ordinal, division, final position, outcome (promoted/stayed/relegated) with the outcome color language already used in the standings.
2. `lib/main.dart` — sixth `FcmNavItem` (label `navProfile`, EN "Profile" / AR "الملف الشخصي", icon `Icons.person_rounded` or `Icons.badge_rounded` — pick the one reading best at 24px) appended after Store; GameShell's body switch extended; the existing per-tab scroll-to-top-on-reselect behavior applies.
3. `navProfile` in both arb files; every visible string localized; RTL verified (stat panel grid mirrors; streak records use directional insets).
4. `test/features/profile/profile_screen_test.dart` — widget tests over a synthetic-career fixture (reuse T-0107's helpers): exact W/D/L and win-rate rendering (e.g. 14W-9D-15L ⇒ 37.5% — assert the formatted string in BOTH locales if the harness sets locale, else EN + an AR formatting unit); zero-state (fresh save: no NaN, no crash, inviting copy); season history rows match the fixture; titles grouped by division; six nav items render with Profile last; smoke test (`test/widget_test.dart`) extended: after the game shell appears, `find.text('Profile')` findsWidgets.
5. Performance: the screen is list/sliver-based (season history grows forever — an endless career must scroll at 60fps); stat panel and identity header in `RepaintBoundary`s (ambient animation again).

## Out of Scope
- Badges showcase + title equip flow (T-0112) — the chip here renders whatever is equipped, empty-safe.
- Any achievements-screen changes (T-0110).
- Editing club/coach names (exists elsewhere if at all — not this feature).

## Acceptance Criteria
- [ ] Six-tab nav with Profile last; verified non-cramped at 360dp width (decision documented if compacted).
- [ ] Career stats exact against fixtures; win rate locale-aware; zero-state safe.
- [ ] Season history + titles from real derived data; EN/AR + RTL tested; `flutter analyze` zero warnings; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/profile/ test/widget_test.dart
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
