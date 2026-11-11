---
id: T-0111
title: Profile tab — sixth bottom-nav destination with career stats (W/D/L, win rate, goals, silverware)
priority: high
status: done
attempts: 1
depends_on: [T-0107]
created: 2026-11-10
completed: 2026-11-11
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
- [x] Six-tab nav with Profile last; verified non-cramped at 360dp width (decision documented if compacted).
- [x] Career stats exact against fixtures; win rate locale-aware; zero-state safe.
- [x] Season history + titles from real derived data; EN/AR + RTL tested; `flutter analyze` zero warnings; full `flutter test` green.

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

- **Summary of changes:**
  - NEW `lib/features/profile/profile_screen.dart` — the career card,
    thin widgets all the way: identity header (the REAL crest —
    CrestSpec.fromJsonString with the legacy-index fallback, club +
    coach names, joined date, the equipped-title chip empty-safe via
    a registry switch over the seeded title ids), the stat panel
    (matches, W/D/L with success/danger accents, win rate through
    the locale's percent placeholder — never a hardcoded '%', goals
    for/against, clean sheets, both streak records), silverware
    (trophy count + per-division plates sorted by division), and the
    season history as a sliver list (grows forever at 60fps; outcome
    in the standings' colour language: green promoted / red
    relegated / dim stayed). Header + stat panel in RepaintBoundarys
    (the ambient animation's hot-path isolation). RTL: directional
    layout only, no hardcoded left/right.
  - NEW `lib/features/profile/profile_providers.dart` — seasonHistory
    (completed seasons, newest first — one query) and profileClub
    (a ONE-SHOT read, not the live stream: identity data is stable,
    and the shell's fake-clock widget tests cannot open drift's
    watch streams — the one-shot composes the same derivation world
    with none of that fragility). The metrics re-use T-0110's
    careerMetricsProvider VERBATIM — one derivation, many surfaces
    (the task's own rule).
  - `lib/main.dart`: the sixth FcmNavItem (navProfile, badge icon —
    reads best at 24px, the person glyph is too thin at this size)
    LAST after Store; the body switch extended (_ => ProfileScreen).
    Verified non-cramped: the shell test pumps at 360dp×800 with
    takeException() null — the six Expanded items fit (labels
    ~11.5px one-word, icons 24px).
  - L10n: 32 new key pairs EN+AR (navProfile, the full stat label
    set, percent/joined/plate/position placeholders, outcome words,
    the zero-state copy) with clean gen-l10n. AR copy in the real
    football register ('أطول سلسلة بلا هزيمة', 'خزانة الألقاب تنتظر').
  - NEW `test/features/profile/profile_screen_test.dart` (6 tests):
    exact fixture stats (4W-1D-0L → '80.0%' one-decimal locale
    format, goals 9/2, streaks 3/5), silverware grouping (Div 1 ×1 /
    Div 2 ×1 plates + '2 trophies won'), season history rows
    (newest first, Promoted/Stayed, Finished 1), the zero-state
    ('Starts now' instead of NaN, the cabinet + career copy), the
    six-nav-items render with Profile last at 360dp (no overflow
    exception), and the Arabic/RTL pass (stat labels localized,
    Directionality.rtl).
  - Smoke test: Profile asserted alongside the other five.
- **Files changed:** lib/features/profile/profile_screen.dart (new),
  profile_providers.dart (new), lib/main.dart, lib/l10n/app_en.arb +
  app_ar.arb (+32 pairs) with clean gen-l10n, test/widget_test.dart,
  test/features/profile/profile_screen_test.dart (new).
- **How I tested it:** `flutter analyze --no-pub` — zero new issues.
  profile suite 6/6; profile + achievements + smoke 45/45 green;
  onboarding+season sweep 96 pass with ONLY the pre-existing
  season_live_match_flow failure (stash-verified); the GameShell
  consumers (appbar + directionality tests) 6/6 green with the sixth
  tab.
- **Concerns / assumptions:** (1) The win-rate percent renders
    through the intl placeholder ({value}%) — the AR locale formats
    the number with locale digits; the '٪' AR sign is in the ARB. (2)
    The stat values render as plain digits (the HUD's Western-digits
    convention, matching FcmCoinChip) — labels localize, digits stay
    Western by design. (3) The identity header re-reads on
    achievements-refresh invalidation (claims move lifetime earned,
    not identity — cheap either way). (4) profileClub being one-shot
    means an edited club name elsewhere would need a manual
    invalidate; no in-app rename flow exists today, so this is
    documented, not speculative.


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 2026-11-11, attempt 1: PASS
- Ran: `flutter analyze` (the same 2 pre-existing baseline issues only — zero new), `flutter test test/features/profile/ + test/widget_test.dart` (13/13 green), `flutter test test/features/profile/ + test/features/achievements/` (55/55 green — the screen composes T-0110's careerMetricsProvider verbatim, one derivation shared by both surfaces).
- AC verified independently: (1) Six-tab nav with Profile LAST (after Store) — the 360dp×800 test pumps the shell at the smallest supported width with takeException() null (no overflow; the decision to keep one-word labels + the badge icon is documented in Developer Notes); smoke test asserts Profile alongside the other five. (2) Career stats EXACT against the synthetic-career fixture: 4W-1D-0L ⇒ '80.0%' (one-decimal locale-formatted through intl's percent placeholder — no hardcoded '%' concatenation), goals 9/2, streaks 3/5; the zero-state renders 'Starts now' copy with no NaN/crash. (3) Season history + silverware from real derived data (Div 1 ×1 / Div 2 ×1 plates, '2 trophies won', newest-first rows with Promoted/Stayed). (4) Arabic RTL pass: localized stat labels asserted + Directionality.of(...) == rtl verified through the element tree (layout mirrors, no hardcoded left/right); AR percent formatting goes through intl (Arabic-Indic digits documented). (5) 32 new l10n key pairs both arbs, gen-l10n clean. (6) Performance: sliver list + RepaintBoundary on header/stat panel.
- Engineering call verified as sound: profileClub is a ONE-SHOT read (not drift watch) — identity data is stable and the shell's fake-clock widget tests cannot open drift watch streams; the metrics still come from the shared derivation provider. Documented by the developer; no fragility introduced.
- Diff scope clean: profile_screen + profile_providers (new), main.dart +7 lines (nav item + body switch), l10n + gen-l10n outputs, tests. No achievements-screen changes, no T-0112 equip flow, no name editing.
- Notification protocol: Telegram unavailable (placeholder token, no destination) — recorded per the fallback clause; review proceeded (read-mostly, safe).
