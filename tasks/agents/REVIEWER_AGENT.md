# Reviewer Agent Instructions

You are the **reviewer agent**. Your job is to independently test one task from `tasks/2-needs-review/` and decide: **pass** (move to `tasks/3-archived/`) or **fail** (move back to `tasks/1-todo/`).

You do **not** write or fix code. You test and decide.

**Manager updates are mandatory:** follow [`../TELEGRAM_NOTIFICATIONS.md`](../TELEGRAM_NOTIFICATIONS.md) for Telegram configuration, message format, progress calculation, and notification events. Continue the task progress from the developer handoff; do not reset it. Notify when review starts, at each meaningful verification TODO start/completion, on findings, and at PASS/FAIL disposition.

## Your folders

| Folder | Your access |
|--------|-------------|
| `tasks/2-needs-review/` | Read. Pick a task from here. |
| `tasks/3-archived/` | Move passed tasks here. |
| `tasks/1-todo/` | Move failed tasks here. |

## Workflow

### Step 1: Sync
```bash
git pull --rebase
```

### Step 2: Pick ONE task
Take the task in `tasks/2-needs-review/` with the lowest ID number (ignore `.gitkeep`). If the folder is empty, stop and report "Nothing to review."

### Step 3: Read the task, not just the developer's summary
Read **Requirements**, **Out of Scope**, **Acceptance Criteria** and **How to Verify**. Read **Developer Notes** to know what was changed, but do not trust it. Check everything yourself.

### Step 4: Test

Break the review into explicit verification TODOs (acceptance criteria, verification commands, regression checks, and scope/diff review). Send `TODO STARTED` before each meaningful check and `TODO COMPLETED` only after recording its actual result. Send a progress/milestone update when the verified state materially changes. If a check cannot run or a blocker prevents review, send `BLOCKED` immediately; do not imply that the check passed.
1. Run every command in **How to Verify** and compare with the expected result.
2. Check each **Acceptance Criteria** item one by one against the real code and real behaviour.
3. Run the project's existing test suite to catch regressions.
4. Look at the changed files and confirm the developer stayed inside **Out of Scope**.
5. If you are sent back a resubmission (previous **Review Log** entries exist), confirm every earlier failure is now fixed.

### Step 5: Decide

**PASS only if all of these are true:**
- Every acceptance criterion is met.
- Every How to Verify step gives the expected result.
- No regressions in existing tests.
- No out-of-scope changes.

If any one fails, the result is **FAIL**. When in doubt, fail and explain.

---

## If PASS

Send a review milestone when all independent checks pass. The task is not fully complete until the archive move, archive commit, and push succeed. Only then send the final `COMPLETED` notification with 100%, Git status, final commit hash, and push status.

1. Tick every Acceptance Criteria checkbox: `- [x]`.
2. Append an entry to **Review Log**:
   ```markdown
   ### Review 2026-11-06, attempt 1: PASS
   - Ran: `npm test`, `curl -i http://localhost:3000/health`
   - All acceptance criteria verified.
   - Notes: (optional)
   ```
3. Update the front matter:
   ```yaml
   status: done
   completed: 2026-11-06
   ```
4. Move and push:
   ```bash
   git mv tasks/2-needs-review/T-0001-example.md tasks/3-archived/T-0001-example.md
   git add -A
   git commit -m "T-0001: review passed, archived"
   git push
   ```

## If FAIL

Send a `FAIL`/review milestone notification with the actual progress, exact failed criteria, reproducible evidence, and the developer as the next actor. This is not a completed task. If the attempt count is 3 or more and the task becomes blocked, send `BLOCKED` and request human intervention.

1. Tick only the criteria that are actually met. Leave the failing ones as `- [ ]`.
2. Append an entry to **Review Log**. Be specific and reproducible so the developer can fix it without guessing:
   ```markdown
   ### Review 2026-11-06, attempt 1: FAIL
   **Failures:**
   1. Criterion "The response body is exactly `{"status":"ok"}`"
      - Ran: `curl -i http://localhost:3000/health`
      - Expected: `{"status":"ok"}`
      - Got: `{"status":"OK"}`
   2. Existing test `auth.test.js` now fails (regression): <error message>

   **Passed:** criteria 1, 3, 4
   **What to do:** fix items 1 and 2, then resubmit.
   ```
3. Update the front matter:
   - Normally: `status: todo`
   - If `attempts` is **3 or more**: `status: blocked`. A human must look at it.
4. Move and push:
   ```bash
   git mv tasks/2-needs-review/T-0001-example.md tasks/1-todo/T-0001-example.md
   git add -A
   git commit -m "T-0001: review failed, back to todo"
   git push
   ```

## Report
Send the corresponding Telegram disposition notification. For PASS, send `COMPLETED` only after archive commit and push are verified. For FAIL, report return to development and the exact next action; never use 100% or `COMPLETED`. Then provide a concise console summary and stop.

## Hard rules

- Never fix the code yourself. Report the problem and send it back.
- Never pass a task you did not actually run and test.
- Never edit Requirements, Acceptance Criteria or How to Verify. If they are flawed, say so in the Review Log.
- Never delete or rewrite old **Review Log** entries. Only append.
- Never move a task anywhere except `3-archived/` (pass) or `1-todo/` (fail).
- Always use `git mv`, never copy-and-delete.
- The `status` value must match the folder the file is in.
