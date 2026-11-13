---
id: T-0125
title: End-to-end smoke pass — new dataset world with icons, icon packs and wildcard chemistry
priority: medium
status: todo
attempts: 0
depends_on: [T-0124]
created: 2026-11-12
completed:
---

# T-0125: End-to-end smoke pass — new dataset world with icons, icon packs and wildcard chemistry

## Goal
One fresh-install manual + automated smoke pass over the whole delivered feature set, verifying the four owner requests work together on a real device/emulator flow: the new core data, the icon packs in the ST store section, the tiny icon chance, and the icon wildcard chemistry on the pitch.

## Context
This is the acceptance gate over T-0120..T-0124 as one product change. The owner's four asks (2026-11-12):
1. players_v1.json replaced by the pushed files as-is;
2. 3 icon packs on top of the ST packs, each with a tiny icon chance (epic+icons / epic+legendary+icons / epic+legendary+premium+icons);
3. icons fulfill both chemistry types with all players in the formation;
4. the game "works right" on the new database core structure.

**Suggested flow (adapt as screens allow):**
- Fresh install → onboarding → create club (formation choice) → confirm the 22 starting packs open and yield new-dataset players.
- Store: ST section shows Icon I/II/III above the ST tier cells with EN+AR labels; prices ascending and above the ST Legendary pack; other sections untouched.
- Buy/open each icon pack type; contents/odds sheet shows the icon chance line; reveal works; icon pulls show the icon badge (use a dev hook or seeded RNG to force one icon pull for visual check — do not rely on the 0.2–1.0% roll).
- Squad: field the icon → golden links to every teammate; tactics badge and pre-match forecast read the wildcard-inclusive chemistry; match engine totals reflect it (compare an icon XI vs icon-free XI forecast).
- Collection/campus/profile surfaces render new-dataset names, portraits (19,083 players have null images — verify the fallback portrait renders), club crests and league logos (all resolve per T-0120).
- Sell an icon (MV-driven price), buy squad slots, run a full season match — no crashes, no missing data, no blank portraits.
- Language toggle EN↔AR over the store and pitch screens.

## Requirements
1. Run the flow above on an emulator/device; capture a short checklist with PASS/FAIL per item and screenshots of: ST store section, icon pack odds sheet, an icon reveal moment, the icon-in-XI pitch with golden links.
2. Any crash, blank image, mis-rendered crest/league or broken layout becomes a new task file (do NOT fix in this task beyond trivial blockers like a missing asset declaration).
3. Confirm performance is acceptable on first launch: the ~12 MB players file parses off the UI thread (T-0120 R4) — note cold-start time before/after on the same device.
4. Update this file's Developer Notes with the checklist result; move to needs-review with the screenshots referenced.

## Out of Scope
- New features; balance tuning; fixing anything non-trivial (file tasks instead).

## Acceptance Criteria
- [ ] Checklist executed with every item PASS, or a follow-up task filed for each FAIL.
- [ ] Screenshots captured for the four moments listed in R1.
- [ ] Cold-start delta recorded.

## How to Verify
Manual pass per the flow in Context; `flutter test` full suite immediately before the pass (no new failures vs the T-0124 baseline).

---

## Developer Notes

## Review Log

**Review 2026-11-12 (QA):** NOT DONE — remains todo. The developer's commit covers code +
unit/widget tests only; no on-device smoke pass was performed (store visuals, reveal
animation, cold start, physical v16→v17 upgrade, AR/RTL layout all "not verified" in the QA
report §6). Execute per the task's checklist after F1/F4/F6 are fixed.
