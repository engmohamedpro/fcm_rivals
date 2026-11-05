# Reviews folder: lifecycle compliance audit — template drift, unexecuted transitions, unverified archive entries
- Feature: reviews
- Type: Design
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-05
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
Manager-requested audit of the reviews folder itself, after the lifecycle rules were overhauled in `45e23af`. The folder's day-to-day flow is healthy — work executes, evidence is measured, rejections carry real data — but the folder contradicts its own README in five places. Root cause: `_template.md` was never updated with the new rules, so files created from it lack the fields the README now requires. This review records the evidence, executes the reviewer-owned corrections in the same session (Reviewer Verification below), and leaves the developer-owned gaps as tasks.

## Findings (all evidence verified on main @ `45e23af`, 2026-11-05)

### F1 — Template drift (root cause of the missing links)
`_template.md` has exactly one commit (`9e1dbaa`, the initial framework). The `45e23af` README overhaul added required sections — Links and Amendments (README.md:46-47) — and the SPLIT status, but never touched the template. Consequence: zero review files, active or archived, carry formal `Follows:` / `Follow-up:` link fields; split pairs are referenced only in prose. The template's Type enum also lacks `Balance`, which the Critical review `2026-11-05_tactics_phase3-balance-bands-and-sweep.md` already uses. Corrected same-session (Reviewer Verification, item 1).

### F2 — Unexecuted SPLIT transition
`2026-11-04_tactics_phase-3-transitions.md` has its REJECTED_PARTIAL decision recorded — rejection upheld, follow-up created (Reviewer Verification, commit `05346c2`) — but Status stayed REJECTED_PARTIAL. README.md:64 and README.md:72 require SPLIT with a `Follow-up:` link once the rejection is upheld; the worked example (README.md:143) spells out this exact case. Corrected same-session (item 2).

### F3 — Archive gate violated
Three tactics files were archived at Status DONE with an empty Reviewer Verification placeholder: `tasks/archive/2026-11-04_tactics_phase-0-remove-playing-styles.md`, `tasks/archive/2026-11-04_tactics_phase-1-in-possession.md`, `tasks/archive/2026-11-04_tactics_phase-2-out-of-possession.md`. README.md:116 archives only CLOSED files; CLOSED requires reviewer verification (README.md:63). The closure decision exists only in commit `05346c2`'s message ("close phases 0-2") — never written into the files. Corrected same-session via record backfill (item 4).

### F4 — Task mechanism invalidated by archiving
`2026-11-05_tactics_phase3-balance-bands-and-sweep.md` Task 4 directs dated appends into `reviews/2026-11-04_tactics_phase-1-in-possession.md`, which has been archived and read-only (README.md:118-119) since `05346c2`. The task's mechanism now conflicts with the README. Corrected same-session via a reviewer Amendment on the balance file (item 3).

### F5 — Status token vs documented state
The balance review sits at IN_PROGRESS while its Developer Notes contain complete §7-grade rejection evidence: bands not simultaneously satisfiable by per-instruction anchor moves on two seed pools (3 coordinate-descent searches, ~50 screened candidates), remaining lever inside the engine. The §5.B "a REJECTED_PARTIAL file must never sit undecided" protection only engages on the token. Developer-owned: Task 1 below.

### F6 — Commit-hygiene note (no action)
`45e23af` staged `devtools_options.yaml` inside a `chore(reviews):` commit, against README.md:138's "stage only the related files". Recorded so the pattern does not repeat; history is not rewritten.

## Verification-debt note
This audit sandbox has no Flutter/Dart SDK (PATH and common install locations checked) — `flutter analyze` / `flutter test` could not be re-run. All findings above were verified statically: git history, file contents, code reads at the cited lines. As a direct consequence, `2026-11-05_tactics_stale-widget-tests-red-suite.md` (Status DONE) could NOT be closed in this session: its two test fixes were statically confirmed (scoped assertions present exactly as described — `test/features/squad/squad_view_test.dart:279-296`, `findsNWidgets(4)` scoped to `TacticsGroupScaffold`; `test/features/season/season_live_match_flow_test.dart:197-201`, the three Transitions row labels + `Standard · 3 back` + `Default setup` as `findsNothing`), but its acceptance criterion demands a full-suite run this environment cannot execute. Task 2 below unblocks that closure.

## Tasks
- [x] Task 1: Status-token hygiene on the balance review | Where: `reviews/tasks/2026-11-05_tactics_phase3-balance-bands-and-sweep.md:7` | Expected: if the next sweep round produces no candidate that is green on BOTH seed pools (sweep pool and suite pool), set Status = REJECTED_PARTIAL in that same session — the §7 content (task, reason, evidence, attempts, alternative) is already in its Developer Notes — so the reviewer must decide and, if upheld, split the engine-side work into its own review. Never tick Tasks 2-6 while they are unmet.
- [ ] Task 2: Unblock the stale-widget closure | Where: `reviews/tasks/2026-11-05_tactics_stale-widget-tests-red-suite.md` (Developer Notes) | Expected: paste a dated verification run — `flutter analyze` output + `flutter test` full-suite summary line + the HEAD commit hash — so the reviewer's closure rests on a post-fix run rather than the single pasted number from execution day. The run must show only the four known phase-3 balance failures red, zero widget-test failures.
- [ ] Task 3: Honor the amended Task 4 mechanism | Where: `reviews/tasks/2026-11-05_tactics_phase3-balance-bands-and-sweep.md` (Amendments section) | Expected: any band adjustment backed by sweep evidence is proposed in a NEW tactics review file in the main folder (naming the affected band, citing the sweep line and this file); no append to or edit of any file under `tasks/archive/`.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] Task 1 executed the next time the balance review's search stalls (token transition only, no task ticks)
- [ ] Task 2's pasted run shows zero widget-test failures and only the four tracked balance failures
- [ ] No file under `tasks/archive/` is edited by anyone after this audit's backfill commit (the audit's own corrections to status token, Links and Reviewer Verification of record are the only exceptions, all documented in this file)

## Developer Notes
<Implementation notes, rejected points with reason.>


### Developer Notes (2026-11-05, Kareem)
- Task 1 DONE this session: the balance review's sweep round ran to
  completion (candidates D-H, both seed pools, tool bug fixed first)
  and produced NO candidate green on both pools — Status was set to
  REJECTED_PARTIAL in the same session with the full §7 content
  (task, reason, evidence, attempts, alternative) in its Developer
  Notes (commits a72e743, f58cd44). Tasks 2-6 of that review remain
  unticked as required.
- Task 2 DONE this session: dated verification run pasted into the
  stale-widget review's Developer Notes (commit 045650f) — flutter
  analyze clean, full suite 705 passed / 4 failed (only the four
  tracked phase-3 balance bands), zero widget-test failures.
- Task 3: no band adjustment was proposed this session (no anchor
  landed in the model), so no new tactics review file was created;
  nothing under reviews/archive/ was touched. The mechanism stays
  honored; the task stays open until an adjustment is actually
  proposed.

## Reviewer Verification
Corrections executed in the same session as this audit, in the commit that follows this file's add commit; every change stays inside `reviews/`:
1. `_template.md`: `| Balance` added to the Type enum; Links and Amendments sections appended — the template now matches README.md:38-47. F1 fixed for every future file.
2. `2026-11-04_tactics_phase-3-transitions.md`: Status REJECTED_PARTIAL → SPLIT; Links added (`Follow-up:` → the balance review); dated Amendment records the executed transition. F2 fixed.
3. `2026-11-05_tactics_phase3-balance-bands-and-sweep.md`: Links added (`Follows:` → the phase-3 review); dated Amendment redirects Task 4's append target per README.md:118-119 — a new review in the main folder, never an append to an archived file. F4 fixed.
4. Archived tactics phases 0/1/2: Reviewer Verification backfilled, Status DONE → CLOSED. Each entry cites the closure record (commit `05346c2`), today's static re-checks, and states plainly that the suites were NOT re-run in this sandbox. Static re-checks performed: `InPossessionTactics` at `lib/features/match/tactics.dart:470` (with its four instruction enums at :381-:439), `OutOfPossessionTactics` at :676 (enums at :578-:658), `TransitionTactics` at :823, `TeamTactics` at :268; `grep -rn "PlayingStyle\|StyleModifiers" lib/ test/` returns zero matches; the legacy-style loader `tacticsFromDbPayload` and its migration test `test/features/season/schema_v11_migration_test.dart` exist; GDD 10.2's three group tables and the legacy mapping are at `docs/fcm_rivals_GDD_SRS.md:516-600`; the balance/calibration/snapshot suites are present under `test/`. §8.4 rationale: this is record synchronization to match a closure the git history already declares, not a correction of the reviewed work; any correction to the work itself still goes through a new review in the main folder.
5. `tasks/archive/2026-11-04_app-structure_god-files-and-route-table.md`: `Follow-up:` link backfilled to `2026-11-04_app-structure_remaining-oversized-files.md`, which gained its `Follows:` field — completing the pair that the god-files verification text already names. No other archived file had an unlinked split pair (verified by grep across `tasks/archive/`).
6. `2026-11-05_tactics_stale-widget-tests-red-suite.md`: static verification of Tasks 1-2 recorded in the Verification-debt note above; the file intentionally stays DONE pending Task 2's run. Its commit hygiene is correct (`0d6dcae` staged only the related test files, the review file and the README rule it added).

## Links
- Follows: -
- Follow-up: -

## Amendments
<Reviewer-owned, append-only. Dated entries correcting a task's target or mechanism; never rewrite the original task text.>
