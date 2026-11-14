# Task Management — Todoist

This project no longer uses file-based task boards. **All task tracking lives in
Todoist** (project *Inbox*, five sections). The agent instructions in this folder
tell planner, developer and reviewer agents exactly how to use it.

## Layout

```
tasks/
├── README.md                    ← you are here (system overview)
├── TODOIST_GUIDE.md             ← the agent manual: auth, API calls, task format, workflow
└── agents/
    ├── PLANNER_AGENT.md         ← instructions for the planner (creates tasks)
    ├── DEVELOPER_AGENT.md       ← instructions for the developer agent
    └── REVIEWER_AGENT.md        ← instructions for the reviewer (QA) agent
```

## The board

| Todoist section | Meaning | Who moves a task **out** |
|---|---|---|
| **Tasks** | Backlog: new work, rework sent back by QA, owner-decision items | Developer → moves to *Doing* when starting |
| **Doing** | The developer is actively working on it | Developer → moves to *Needs Review* when done, **or when blocked with a partial result / a needed input** |
| **Needs Review** | Implementation finished (or flagged by the dev), waiting for QA to pick it up | Reviewer → moves to *In Review* when starting |
| **In Review** | QA is actively verifying | Reviewer → *Done* (pass) or *Tasks* (fail, or blocked on the owner) |
| **Done** | QA passed and the task is completed/closed | Nobody. Final. |

Lifecycle (one task, one ticket — moves happen **only** in this order):

```
Tasks ──(dev starts)──► Doing ──(dev done / dev blocked-with-input)──► Needs Review
  ▲                                                                     │
  │                                                             (QA picks up)
  └────────────────────── QA: FAIL / needs owner ──────► In Review ◄───┘
                                                               │ QA: PASS
                                                               ▼
                                                             Done
```

Roles: the **planner** creates and sizes tasks (from owner requests, QA
findings and owner rulings); the **developer** implements exactly one task at
a time and hands off with an honest handoff comment (work is never left
parked in *Doing*); the **reviewer** independently verifies, triages flagged
problems, and owns the PASS/FAIL decision. See [`agents/`](agents/).

## Task format

- Title: `[T-NNNN] short imperative title` (never reuse a number; pick max + 1
  from *all* sections including Done).
- Description: Goal, Context, Requirements, Out of Scope, Acceptance Criteria,
  How to Verify — same structure the old task files used.
- Progress and review outcomes go in **comments** (one per event), never by
  editing the description silently.
- Labels: `blocked` marks a task that needs human input.

## Rules for everyone

1. Todoist is the single source of truth. Do not track work in files, branch
   names or commit messages alone.
2. A task moves forward **only** with its state actually verified — no
   pre-moving.
3. Git discipline stays: code commits are separate from the repo, the task ID
   goes in the commit message (for example `T-0126: implement icon pack fix`),
   `git pull --rebase` before starting, `git push` after finishing work.
4. Never claim a task Done that you did not verify.
5. Owner-decision items get the `blocked` label and stay in **Tasks** until the
   owner rules.

## History

The 124 archived file-based tasks (T-0001..T-0125) live in git history up to
the commit that introduced this file. The eight active tasks at cutover were
migrated into Todoist on 2026-11-13 with their full context in the description.

## Where to start

- Agent manual: [`TODOIST_GUIDE.md`](TODOIST_GUIDE.md)
- Planner agent: [`agents/PLANNER_AGENT.md`](agents/PLANNER_AGENT.md)
- Developer agent: [`agents/DEVELOPER_AGENT.md`](agents/DEVELOPER_AGENT.md)
- Reviewer agent: [`agents/REVIEWER_AGENT.md`](agents/REVIEWER_AGENT.md)
