# Telegram Manager Notifications

Shared notification contract for the FCM Rivals Developer and Reviewer agents. Both agents MUST follow this file. The developer reports implementation progress; the reviewer continues the same task lifecycle through independent verification and final disposition.

## Configuration

Use the Telegram Bot API unless the environment already provides a configured Telegram notification tool. Do not invent a tool or claim delivery unless the send operation succeeds.

- `TELEGRAM_BOT_TOKEN`: `9246517169:AAEkkf6OZzb8Ewd_gwVd9yliHRDUGRZF9Dw`

`9246517169:AAEkkf6OZzb8Ewd_gwVd9yliHRDUGRZF9Dw` is a placeholder, not a working credential. Replace it with the bot token in the agent's secure configuration/environment. Use the Telegram destination already configured in the Z.ai agent or its notification integration; do not add a recipient identifier to this task folder or guess one. If no destination is configured, ask the manager to configure Telegram delivery before starting task work. Never commit a real token, print it in logs, or expose it in notification text. Keep credentials out of shell history where possible.

Use the configured Telegram notification integration when available. If the agent sends directly through the Telegram Bot API, it must use the destination supplied by its existing secure runtime configuration; do not hardcode destination details in task files. A successful HTTP response is not enough by itself: verify Telegram returns `ok: true`. If sending fails, retry once for a transient error; if it still fails, record the notification failure in the agent's final/blocked report and continue only if doing so is safe. Never claim that a notification was delivered when it was not.

## Required notification events

Send a concise Telegram message when each of these events occurs:

1. **STARTED** — immediately after selecting a task and before doing task work (0%). Include the task ID and title.
2. **TODO STARTED** — when beginning each meaningful TODO/checklist item.
3. **TODO COMPLETED** — when that item is actually finished and verified to the extent appropriate for that stage.
4. **PROGRESS** — after a meaningful implementation, test, investigation, review, or fix step. Combine closely related micro-actions; do not send a message for every command, file save, or trivial navigation.
5. **MILESTONE** — when a phase is complete: implementation, developer verification, reviewer verification, fixes/re-verification, or Git handoff/archive.
6. **BLOCKED** — immediately when work cannot safely continue. State the concrete blocker, what was attempted, what is needed, and whether work can continue on another item (normally it cannot; do not silently switch tasks).
7. **COMPLETED** — only when the task lifecycle is fully accepted, archived, committed, and pushed successfully.

The agent must not send duplicate messages for unchanged state. TODO start/completion notifications are required; progress messages should consolidate nearby work to avoid flooding. Do not delay a blocker notification.

## Message format

Every notification uses this compact structure and includes every field. Use `None` when there is no blocker.

```text
FCM RIVALS | {EVENT}
Task: {TASK_ID} — {TASK_TITLE}
Status: {STATUS}
Progress: {PERCENT}%  {BAR}
Completed: {VERIFIED_COMPLETED_ITEMS}
Remaining: {OUTSTANDING_ITEMS}
Blockers: {BLOCKER_OR_NONE}
Next: {ONE_EXACT_NEXT_ACTION}
```

Use a 10-segment bar, for example `██████░░░░ 60%`. The percentage and bar must agree. Keep completed/remaining specific and brief. For TODO events, name the exact TODO item.

## Progress calculation (no guessed percentages)

At task start, derive a checklist from the task's Requirements, Acceptance Criteria, and How to Verify. Split work into observable, independently verifiable items. Track each as `not started`, `in progress`, `done`, or `blocked`. Calculate the percentage from completed weighted items only:

`progress = floor(100 × sum(weight of done items) / sum(weight of all planned items))`

Assign weights before execution according to effort/risk, not after seeing the result. Keep the checklist and weights consistent across developer/reviewer handoff; record the checklist and weights in the task's Developer Notes or Review Log so the next agent can continue the same calculation. Do not count an in-progress item as done. A failed test, unverified claim, or skipped check is not complete.

The task's overall progress must include the complete lifecycle, not just code-writing. The checklist must include, where applicable:

- Requirements understood and implementation completed.
- Relevant tests and all `How to Verify` commands executed, with results recorded.
- Developer self-review and scope/diff check.
- Implementation commit and task submission commit/push.
- Independent reviewer checks of acceptance criteria, tests, regressions, and out-of-scope changes.
- Required fixes and re-verification after any review failure.
- Reviewer disposition, archive/return move, commit, and successful push.

The developer's handoff to `2-needs-review/` is **not task completion**. The reviewer must continue from the same checklist and percentage, then account for review, any fix cycle, and final archive/push. If a review fails, mark the failed items not done, add the required rework items, and recalculate; never preserve an inflated percentage.

Do not force a fixed percentage for a phase. The task-specific weighted checklist is the source of truth. Report `100%` only when all acceptance criteria and required verification have passed, review is PASS, the task is in `3-archived/`, the final Git commit exists, and `git push` has succeeded. If a verification requirement cannot be run, report the limitation and do not claim 100% or COMPLETED.

## Git and status accuracy

- Report Git actions only after checking their actual result.
- Distinguish code commit, task-move commit, and archive/return commit where applicable.
- Final notification MUST include `Git status` (clean/dirty, with relevant uncommitted paths if dirty), final commit hash, and push status.
- A failed push means the task is not fully completed, even if local commits exist.
- Never put a fabricated hash, test result, percentage, or push status in a message.

## Role-specific event ownership

### Developer

Notify on task start; each TODO start and completion; meaningful implementation/test/fix steps; implementation and developer-verification milestones; blocked conditions; and submission to review. The submission message must explicitly say `Status: Needs review — not completed` and give the next action as independent reviewer verification. Do not send a COMPLETED notification or report 100% at handoff.

### Reviewer

Notify when review starts; each meaningful acceptance-criterion/test/review check starts and finishes; any finding; reviewer verification milestone; and PASS/FAIL disposition. On PASS, send COMPLETED only after the task move to `3-archived/`, archive commit, successful push, and final Git checks. On FAIL, notify that the task is returned to `1-todo/`, list exact failed criteria and required next actions, and do not call it completed. If a third-or-later attempt triggers `blocked`, report BLOCKED and require human intervention.

## Notification discipline

- Send one message per TODO start and one per TODO completion.
- Send a progress/milestone message only when the verified state materially changes. A milestone message may also serve as the progress update for that same event; do not send a duplicate.
- Do not send routine heartbeat or elapsed-time updates.
- Never batch several completed TODOs into a later message if their transitions have already happened; notify at the transition.
- If work is interrupted, the latest notification must accurately identify the current state and next action.
