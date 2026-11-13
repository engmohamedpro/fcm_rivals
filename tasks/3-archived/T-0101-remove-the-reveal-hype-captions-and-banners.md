---
id: T-0101
title: Remove the reveal hype captions and pull banners
priority: medium
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-10
---

# T-0101: Remove the reveal hype captions and pull banners

## Goal
During the pack reveal, no text floats above the card: the legendary suspense captions and the pull banners are gone (owner request 2026-11-09 — "remove the text at the top which is epic pull and legend is coming and all these texts above the card"). The card, walkout, mystery silhouette, flash, timeline and action bar are unchanged.

## Context
- Two overlays render above the card in `lib/features/packs/pack_opening_screen.dart`:
  - the suspense captions (legendary only) at `:708-710`, built by `_buildCaption` in `lib/features/packs/pack_opening_screen_reveal.dart:98-135` — 'A LEGEND IS COMING…' and 'WHO IS IT?' (hardcoded EN);
  - the pull banner at `:713-741` — hardcoded 'EPIC PULL!' / 'LEGENDARY PULL!' and the localized 'PREMIUM PULL!' (`revealBannerPremium`, `lib/l10n/app_en.arb:164`, `app_ar.arb:119`).
  - the local `bannerT` (`:490`) feeds only the banner; remove it with the banner block.
- The reveal timeline itself (`RevealTimeline`, its intervals and durations), the mystery silhouette, the walkout (flag + position), the flash, the NEW badge (T-0091) and the action bar must not change — only the two text overlays go.
- Tests asserting these strings today: `test/features/packs/pack_opening_screen_test.dart:448,450,483,493,539,545,551,553,558` (legendary/premium timeline tests assert 'A LEGEND IS COMING…', 'WHO IS IT?', 'LEGENDARY PULL!', 'PREMIUM PULL!').

## Requirements
1. Delete the caption overlay render site (`pack_opening_screen.dart:708-710`) and the `_buildCaption` method (`pack_opening_screen_reveal.dart:98-135`).
2. Delete the banner overlay block (`pack_opening_screen.dart:713-741`) and the now-unused `bannerT` local; nothing else in the stage build changes.
3. Remove `revealBannerPremium` from BOTH ARB files and regen localizations — after grepping that nothing else references it.
4. Update the affected tests: the caption/banner assertions flip to `findsNothing` (the strings must never render), while each test's OTHER assertions (timeline progression, mystery card, action bar arrival) keep passing — a deletion of the overlays must not weaken what the tests prove about the timeline itself.

## Out of Scope
- Any timeline duration, interval, animation or stagecraft change (shake, vignette, flash, walkout, punch, foil).
- The mystery silhouette, the card face, the NEW badge, the chain capsule, the action bar.
- Any pack store / odds / economy behavior.

## Acceptance Criteria
- [x] None of 'A LEGEND IS COMING…', 'WHO IS IT?', 'EPIC PULL!', 'LEGENDARY PULL!' or 'PREMIUM PULL!' (nor their Arabic counterpart) ever renders during a reveal — rare, epic, legendary and premium pulls all clean above the card.
- [x] Reveal timings are unchanged: the legendary and premium tests' progression assertions (mystery in, flip, stats, action bar live) still pass with their current duration expectations.
- [x] `revealBannerPremium` is gone from both ARBs; localization regen is clean; no unused imports or dead locals remain.
- [x] `flutter analyze` zero warnings; packs suite green with updated tests; full `flutter test` green, no REGEN_SNAPSHOT.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/packs/
# Expected: green — caption/banner assertions now findsNothing, timeline assertions unchanged

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

Manual: open a rare pack, an epic pull and (seed or luck permitting) a legendary one — the space above the card stays empty through the whole reveal.

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


### Attempt 1 — implementation

**Summary of changes:** nothing floats above the card during a pack reveal anymore.
1. `lib/features/packs/pack_opening_screen.dart` — the legendary suspense caption render site and the whole pull-banner overlay block deleted; the now-unused `bannerT` local removed. Nothing else in the stage build changed (timeline, mystery silhouette, walkout, flash, ambient particles, card, NEW badge, action bar all untouched).
2. `lib/features/packs/pack_opening_screen_reveal.dart` — `_buildCaption` (the 'A LEGEND IS COMING…' / 'WHO IS IT?' machinery) deleted with its doc comment.
3. `lib/l10n/app_en.arb` + `app_ar.arb` — `revealBannerPremium` removed from both (grep confirmed the only remaining reference was its own test); `flutter gen-l10n` clean.
4. `test/features/packs/pack_opening_screen_test.dart` — the caption/banner assertions flipped to `findsNothing` (the strings must never render: mid-build, stats-count, name-landing and finale-wave checkpoints all now assert absence); the timeline/progression assertions of those tests (mystery in, flip, ATT stats, redacted-name window, keep-fade opacity, BACK arrival) kept exactly as they were — the deletion weakens nothing about what they prove. `pack_reveal_timeline_test.dart` — the banner-localization test dropped with the key (compilation IS the proof the getter is gone); its unused AR import removed.

**Files changed:** `lib/features/packs/pack_opening_screen.dart`, `lib/features/packs/pack_opening_screen_reveal.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/l10n/app_localizations.dart` + generated files (regen), `test/features/packs/pack_opening_screen_test.dart`, `test/features/packs/pack_reveal_timeline_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓ (whole project, after regen). `flutter test test/features/packs/` → **132/132 green** ✓ with the flipped assertions. Full `flutter test` → (result recorded in the submit commit message) ✓, no REGEN_SNAPSHOT.

**Concerns / assumptions:**
- `RevealTimeline.bannerIn` still exists (a timeline interval now consumed by nothing on screen) — left untouched per Out of Scope ("no timeline duration, interval or animation change"); removing it would alter the timeline data structure the pacing tests pin.
- The timeline test's banner member removal means the file now proves absence by compiling without the getter — noted in the test body.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 1 — 2026-11-10 — PASS

**Ran (Flutter 3.47.9, main @ 36f8744):**
- `flutter analyze` → No issues found! ✓
- `flutter test test/features/packs/` → **132/132 green** ✓ — the caption/banner assertions flipped to `findsNothing` at every checkpoint (mid-build, stats-count, name-landing, finale wave) with the timeline/progression assertions kept exactly as they were.
- Full `flutter test`: run 1 → **1011/1012** — the only failure was the club-creation smoke test at `test/widget_test.dart:128` ('Start your first season', Found 0), a load-dependent flake OUTSIDE this task's scope: the same test passes 3/3 solo and full-suite run 2 → **1012/1012, "All tests passed!"** with `grep -c MissingPluginException` = 0. Proposed task T-0104 (harden the smoke test's bounded async waits) — same pattern the T-0103 task text named: "the full-suite gate is a coin flip depending on machine load".
- Code read: the caption render site, `_buildCaption`, the whole pull-banner overlay block and the now-unused `bannerT` local deleted; `revealBannerPremium` gone from both ARBs with a clean regen (compilation proves the getter is gone); `RevealTimeline.bannerIn` untouched per Out of Scope; grep confirms no 'PULL!'/legend-caption string renders from lib/ — the only leftover is ONE STALE DOC COMMENT at `pack_opening_screen.dart:30` still describing the deleted 'LEGENDARY PULL! banner' (cosmetic, non-blocking; violates no AC — AC3 covers unused imports and dead locals, both clean).

All four criteria met; every verify command run by the reviewer.

