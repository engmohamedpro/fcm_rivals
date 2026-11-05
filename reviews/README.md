# Reviews

This folder contains the review workflow and task inbox.

- `tasks/` contains one Markdown file per task.
- `tasks/archive/` contains completed task files moved out of the active inbox.
- `tasks/_template.md` is the required template for every new task.

Files are never deleted. A task moves through one lifecycle from creation to archive.

**Core principle:** Validate the problem before assigning work, and independently verify the implementation before accepting it.

## 1. File structure and naming

Create exactly one file for each independently executable task. Do not put multiple tasks in one file, even when they belong to the same feature. Related tasks may link to one another through `Depends on`, `Follows`, or `Follow-up`.

All task files live directly in `reviews/tasks/` while active. Archived files live in `reviews/tasks/archive/`.

Use this naming format:

`YYYY-MM-DD_<feature>_<short-task-title>.md`

Example:

`2026-11-05_auth_login-validation.md`

Use `_template.md` as the source for every new task. Never overwrite an existing task file. A follow-up is a new task file with its own date and title, linked to the original task.

## 2. Task status lifecycle

| Status | Meaning | Who sets it | Developer picks it up? |
|---|---|---|---|
| OPEN | Validated task, not started | Reviewer | Yes |
| IN_PROGRESS | Implementation has started, or a reviewer corrected an invalid task through an amendment | Developer or reviewer as specified in section 6 | Yes |
| DONE | Implementation and developer-side completion checks are finished; waiting for independent verification | Developer | No |
| REJECTED_PARTIAL | Task could not be completed as written; evidence and an alternative are documented | Developer | Yes, until the reviewer decides |
| SPLIT | Remaining work has been moved to a linked follow-up task | Reviewer | No |
| CLOSED | Implementation has passed independent verification | Reviewer | No |

Allowed transitions:

```text
OPEN -> IN_PROGRESS -> DONE -> CLOSED
                     -> REJECTED_PARTIAL -> SPLIT -> CLOSED
                                         -> IN_PROGRESS (reviewer amendment)

DONE -> verification fails -> create a follow-up task; original -> SPLIT
```

No other transitions are allowed.

A reviewer must not close a task that they implemented themselves. If independent verification cannot be performed by a different person, leave the task in `DONE` and document the limitation; do not claim independent acceptance.

## 3. Task file structure

Every task file must be created from `_template.md` and contain:

- Header: Feature, Type, Priority, Created, Status, Completed on
- Context (1–3 lines)
- Investigation & Evidence
- Reproduction Steps (when applicable)
- Task: one clearly scoped unit of work
- Acceptance Criteria
- Developer Notes
- Reviewer Verification
- Links: `Depends on`, `Follows`, and `Follow-up` where applicable
- Amendments (reviewer-owned, append-only)

Do not add reviewer names, developer names, assignee names, or personal identity fields.

### Investigation & Evidence

Document why the task exists. Include, as applicable:

- What was investigated.
- Root cause or technical justification.
- Files/components involved, with exact `path:line` references where possible.
- Reproduction evidence.
- Relevant test results, measurements, logs, or profiler output.
- Why the proposed change is necessary.
- Known dependencies and potential side effects.
- For improvements, the measurable benefit expected.

## 4. Reviewer rules (before creating a task)

A reviewer must investigate and validate a potential task before creating its file. Follow this order:

### A. Understand the feature

1. Read the relevant implementation, architecture, and documentation.
2. Identify affected files, dependencies, and execution flow.
3. Understand the expected behavior.
4. Inspect related components and existing implementations.

### B. Reproduce the issue

1. Run the application or relevant feature whenever possible.
2. Reproduce the reported bug or unexpected behavior.
3. Record exact reproduction steps.
4. Capture relevant logs, screenshots, or test output when useful.
5. If the issue cannot be reproduced, investigate further before creating a task.

### C. Inspect the implementation

1. Trace the actual execution path.
2. Inspect related services, state management, data flow, and dependencies.
3. Check whether existing code already solves the problem.
4. Identify the actual root cause rather than treating symptoms.
5. Check whether another feature or shared dependency is responsible.

### D. Run relevant tests

1. Run existing tests related to the affected functionality.
2. Add temporary experiments or test cases when necessary to validate the suspected issue.
3. Run relevant commands and inspect their output.
4. Distinguish existing failures from failures caused by the investigated issue.
5. Record the results.

Never assume a problem exists based only on reading code.

### E. Validate the proposed solution

1. Confirm that the proposed change addresses the actual root cause.
2. Check that it follows project architecture.
3. Consider performance, memory, and application size.
4. Consider backward compatibility.
5. Identify potential side effects and dependencies.
6. Determine whether a smaller or safer solution exists.

### F. Define measurable expectations

Before creating the task:

1. Define the expected behavior.
2. Define measurable acceptance criteria.
3. Identify exact affected files or components.
4. Define how implementation and completion will be verified.
5. Identify prerequisites and dependencies.
6. Define relevant edge cases.

### G. Create the task file

Create the file only after completing the investigation.

Rules:

1. Create one file per independently executable task from `_template.md`.
2. Every task states WHAT, WHERE (`path:line`), and the EXPECTED result. Include measurable targets when relevant (numbers, bands, thresholds, test names).
3. Set Priority to `Critical`, `Major`, or `Minor`.
4. Include evidence for every finding (file:line, profiler data, size analysis, reproduction steps, or failing test output).
5. Keep unrelated work in separate task files.
6. Do not create speculative tasks.
7. Do not request a rewrite or refactor without evidence that it is necessary.
8. Do not duplicate existing tasks or implementations.
9. If testing is impossible, document exactly why and what evidence supports the task.
10. Commit using `review(<feature>): add <file-name-without-extension>`. Stage only the new task file(s).

**Quality rule:** The task must explain WHY the work exists, WHAT must change, and HOW completion will be verified.

## 5. Task ordering and prioritization

When multiple task files exist, execute them in this order:

1. Blockers and prerequisites.
2. Critical bugs: crashes, data corruption, security issues, and broken core functionality.
3. Major bugs affecting important functionality.
4. Architecture and structural issues required by other features.
5. Proven performance and resource problems.
6. Minor bugs and UX issues.
7. Optional improvements.

Additional rules:

- Tasks with dependencies must identify prerequisite task files explicitly.
- Do not start a dependent task before its prerequisites are complete.
- Within the same priority, execute the oldest task first, unless a dependency requires otherwise.
- Keep unrelated features in separate files.
- Never prioritize cosmetic improvements over blocking architectural or functional issues.

## 6. Reviewer rules (handling results)

### A. Task is DONE: independently verify

A developer marking a task `DONE` does not mean the work is accepted. The reviewer must independently verify the implementation.

Follow this order:

1. Read the implementation notes in Developer Notes.
2. Inspect the actual Git diff and commit history.
3. Verify that the task was implemented as specified.
4. Confirm that no unrelated changes were introduced.
5. Run the application and manually test the affected functionality whenever possible.
6. Execute the original reproduction steps to confirm the issue is resolved.
7. Test every Acceptance Criteria item individually.
8. Test relevant edge cases, invalid inputs, empty states, and failure scenarios.
9. Check for regressions in related functionality.
10. Run `flutter analyze`.
11. Run `flutter test` (full suite).
12. Verify EN/AR localization and Arabic RTL where applicable.
13. Verify performance and application size where relevant.
14. Record the verification date, tested commit hash, exact tests performed, results, and remaining limitations.

Important:

- A passing test suite does not automatically mean the task is accepted.
- Code inspection alone is not sufficient when runtime testing is possible.
- Do not rely exclusively on the developer's claims.
- Never mark a task `CLOSED` just because its implementation looks correct.
- If manual testing is impossible, document the limitation and use the strongest available alternative verification.
- Any failed Acceptance Criteria item prevents closure.

**If all checks pass:** Fill Reviewer Verification with the date, commit hash, tests performed, and results. Set Status to `CLOSED`.

**If something is wrong or missing:** Do not reopen or rewrite the original task. Record failure evidence in Reviewer Verification, create a new correction task with `Follows:` pointing to the original file, set the original task to `SPLIT`, and add `Follow-up:` pointing to the new file.

### B. Task is REJECTED_PARTIAL: decide

Read the rejection reason and proposed alternative in Developer Notes, inspect the evidence, and record one decision in Reviewer Verification:

| Decision | When | Action |
|---|---|---|
| Rejection upheld; work still needed | The task is valid but blocked by something outside its scope | Create a new task for the blocked work (and a prerequisite task if needed), link the files, and set the original to `SPLIT`. |
| Task was wrong or infeasible | The task text is incorrect, contradictory, or impossible | Do not edit the original task text. Append a dated correction under Amendments, then set Status to `IN_PROGRESS` so implementation continues in the same file. |
| Rejection not accepted | The task is feasible as written and the reason is unsupported | Record counter-evidence, set Status to `OPEN`, and request another attempt. |
| More information needed | The reason is unclear or lacks measurements | Record exact questions and keep Status as `REJECTED_PARTIAL`. |

Rules:

1. Decide within the same working session in which the task is reviewed.
2. A `REJECTED_PARTIAL` task must not sit undecided.
3. Never leave the same blocked work active in two files.
4. Move blocked work to exactly one follow-up task.
5. A follow-up must be independently executable. Copy all relevant requirements, targets, reproduction steps, and evidence into it.
6. Allow at most two rejection rounds on the same task. On the third, escalate to the engineering manager for a scope or priority decision and record the decision in Reviewer Verification.

## 7. Linking and follow-ups

- A follow-up task uses `Follows: <old-file-name>`; the old task uses `Follow-up: <new-file-name>`.
- Use `Depends on: <task-file-name>` when another task must be completed first.
- A `SPLIT` task closes only when its handed-over work is complete in follow-up task files that are themselves `CLOSED`.
- When all follow-ups are `CLOSED`, set the original `SPLIT` task to `CLOSED` and record the closing commit in Reviewer Verification.
- Chains are allowed (A → B → C). Each file records only its direct predecessor, successor, and prerequisites.
- Copy all relevant requirements and evidence into follow-up files; do not require the developer to reconstruct the task from an old file.

## 8. Developer rules (executing tasks)

1. At the start of every session, inspect all task files with Status `OPEN`, `IN_PROGRESS`, or `REJECTED_PARTIAL`.
2. A `REJECTED_PARTIAL` task with a reviewer decision is handled according to that decision. Without a decision, do not redo the rejected work; wait for the reviewer.
3. Execute by priority: Critical, then Major, then Minor. Oldest first within the same priority, respecting dependencies.
4. Set Status to `IN_PROGRESS` when starting.
5. Work on exactly ONE task file at a time. Do not implement multiple task files in parallel or combine multiple tasks into one commit.
6. Mark the task checkbox `[x]` only when that task is fully implemented and all applicable completion checks pass.
7. Never edit the reviewer's Context, Investigation & Evidence, Reproduction Steps, Task, or Acceptance Criteria text. Only update the task checkbox and write in Developer Notes.
8. Run the required checks for the current task. Before any commit that changes UI or engine behavior, run the full suite (`flutter test`), not only feature tests. A failing suite blocks claims that tests are green.
9. Update only the current task file: set Status to `DONE` after implementation and developer-side checks pass, fill `Completed on`, and record concise implementation notes plus exact test commands and results.
10. Create exactly ONE task-specific commit containing the current task's implementation changes and its task-file update. Do not include changes belonging to another task.
11. Push that commit immediately after committing. Do not start, implement, or commit the next task until the current task's push succeeds.
12. After a successful push, move to the next eligible task using the priority and dependency rules. Repeat the same one-task cycle.
13. If the push fails, STOP. Report the exact error and the local commit hash. Do not start another task, create another task commit, or retry with destructive Git operations. Wait for instructions or a safe resolution.
14. Never delete task files.
15. Ignore files with Status `DONE`, `SPLIT`, or `CLOSED` for new implementation work, and ignore everything in `tasks/archive/`.

### Mandatory task-by-task commit and push cycle

```text
Select ONE eligible task
  -> set IN_PROGRESS
  -> implement ONLY that task
  -> run required checks
  -> update that task file and set DONE
  -> create ONE commit for that task
  -> push immediately
  -> confirm push succeeded
  -> only then select the next task
```

Additional rules:

- One task file must correspond to one implementation commit. Never batch two task files into one implementation commit, even when they share a feature.
- The commit may contain the source, tests, localization, and the current task file needed to complete that single task.
- Do not commit unrelated formatting, cleanup, refactoring, or changes for another task.
- A task is not ready for the next task cycle until its push succeeds.
- If a task becomes `REJECTED_PARTIAL`, record the evidence and alternative, commit and push only the partial work for that task, then STOP and wait for the reviewer decision. Do not proceed to another task while this task is undecided.
- If a push fails after the task commit, leave the commit intact, keep the task from being treated as successfully delivered, and stop. Do not amend, reset, force-push, or stack later task commits on top of the failed push.

### Rejecting a task

If a task is wrong, infeasible, or blocked, do not tick its checkbox. In Developer Notes, record:

1. Which task is blocked and why (one or two lines).
2. Evidence: measured numbers, failing test names, commit hashes, or reproduction commands.
3. What was attempted and why it did not work.
4. A concrete alternative or exact next step, with estimated scope.
5. What is already done and verified, so it does not need to be checked again.

Then set Status to `REJECTED_PARTIAL`, create one commit containing only the partial work for this task and its task-file update, push it immediately, and flag it for review. After that push succeeds, stop task execution and wait for the reviewer decision; do not pick up another task.

Never tick a checkbox to make a status look better, and never lower a band or threshold to make a test pass. Propose the change in Developer Notes instead.

## 9. Definition of Done

A task is implemented only when all applicable conditions are satisfied:

- Compiles with zero analyzer warnings.
- Tests are added or updated.
- Full test suite is green.
- EN/AR localization is complete where applicable.
- RTL is verified where applicable.
- No performance or application-size regression is introduced.
- Project architecture is respected.
- All Acceptance Criteria are satisfied.
- Relevant edge cases are handled.

A task is `CLOSED` only after independent reviewer verification.

## 10. Archive

1. Move a task to `reviews/tasks/archive/` only when its Status is `CLOSED` and all its follow-ups, if any, are also `CLOSED`.
2. Use `git mv` to preserve history. Never delete.
3. Archive when the active task folder becomes crowded or at the end of a milestone.
4. Archived files are read-only. Corrections always go into a new task file in `reviews/tasks/`.

## 11. Commit messages

| Case | Message |
|---|---|
| Reviewer creates a task | `review(<feature>): add <file-name-without-extension>` |
| Developer implements a task | `fix(<feature>): address review <file-name-without-extension>` (use `perf`, `refactor`, `test`, or `feat` when appropriate to the Type) |
| Reviewer verifies, decides, or closes | `review(<feature>): verify <file-name-without-extension>` |
| Task is archived | `chore(reviews): archive <file-name-without-extension>` |

Stage only the source changes, tests, localization, and current task file required for that single task. Each task gets its own implementation commit and immediate push; never batch tasks. Never force-push or rewrite history. If a push fails, report the exact error and local commit hash, then stop all further task execution until resolved.

## 12. Final rule

Reviewers are responsible for validating the problem before assigning work and validating the solution before accepting it. Developers are responsible for implementing the agreed requirement and providing reproducible evidence of completion.
