---
id: T-0000
title: Short imperative title
priority: medium          # critical | high | medium | low
status: todo              # todo | needs-review | done | blocked
attempts: 0               # developer increments on every submission for review
depends_on: []            # task IDs that must be in 3-archived first, e.g. [T-0002]
created: YYYY-MM-DD
completed:                # reviewer fills this in on pass
---

# T-0000: Short imperative title

## Goal
One or two sentences: what should be true when this task is done, and why it matters.

## Context
Background the agent needs: relevant files, modules, links, decisions already made.
Write "None" if there is nothing.

## Requirements
Concrete things to build or change.

1. ...
2. ...

## Out of Scope
Things the agent must NOT do in this task.

- ...

## Acceptance Criteria
Each item must be checkable by someone who did not write the code. The reviewer ticks these, not the developer.

- [ ] ...
- [ ] ...

## How to Verify
Exact commands or steps the reviewer will run, with the expected result.

```bash
# example
npm test
```

Expected: ...

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
