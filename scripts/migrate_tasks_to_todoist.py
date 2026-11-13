#!/usr/bin/env python3
"""Migrate the 8 active task files from tasks/ to Todoist sections.

Section mapping (verified live on 2026-11-13):
  Tasks        6j28h7QfJCCxGMFV   — backlog / rework
  Doing        6j28h8Pj5MpQC7V3   — developer actively working
  Needs Review 6j28h9XGxm733MhV   — developer finished, awaiting QA pickup
  In Review    6j28hCQ8CgvxH6J3   — QA actively verifying
  Done         6j28hGRq3mqqmPF3   — QA passed (task completed)

Mapping decision per task (from the Review Logs):
  T-0082  Needs Review file but it is an umbrella/decision record whose
          executable work moved to T-0114..T-0116 and closed. -> Done
          (decision record, no remaining action) — with a note.
  T-0116  REJECTED, bounded fix list open                  -> Tasks (rework)
  T-0119  finished, no review yet                          -> Needs Review
  T-0120  PASS with follow-ups                             -> Done
  T-0121  PASS                                             -> Done
  T-0122  PARTIAL, 4 deviations, owner decision needed     -> Tasks (rework)
  T-0123  PASS with one low note                           -> Done
  T-0124  PARTIAL, migration incomplete                    -> Tasks (rework)
  T-0125  todo, never started                              -> Tasks
"""
import json
import os
import sys
import urllib.request

API = "https://api.todoist.com/api/v1"
TOKEN = os.environ["TODOIST_TOKEN"]
PROJECT_ID = "6j28cCv8XPqPMhpV"

SECTIONS = {
    "Tasks": "6j28h7QfJCCxGMFV",
    "Doing": "6j28h8Pj5MpQC7V3",
    "Needs Review": "6j28h9XGxm733MhV",
    "In Review": "6j28hCQ8CgvxH6J3",
    "Done": "6j28hGRq3mqqmPF3",
}

PRIORITY_MAP = {  # task-file priority -> Todoist priority (4 = P1 highest)
    "critical": 4,
    "high": 3,
    "medium": 2,
    "low": 1,
}

# (task_id, title, priority, section, description, blocked?)
TASKS = [
    (
        "T-0116",
        "Ceiling lock both directions — turn on income layer and re-lock ladder",
        "high",
        "Tasks",
        "REJECTED at review (attempt 1) — bounded rework list open. Fix list: "
        "(1) re-anchor combined state so engine_calibration real-football bands hold "
        "(goals 2.4-2.9, 6+ thrillers <0.075, big chances 1.3-1.9, low-scoring >0.18) via "
        "onTargetBase/onTargetScale/goalDiffScale/setPieceIncome levers; "
        "(2) investigate compatibility_gate ratings stability (elite 6.1196 reads below mid 6.1253); "
        "(3) explicit owner decision on the 0.88 ceiling (accept 0.891/0.948 or extend fallback levers); "
        "(4) replace knife-edge boundary assertions with tolerance margins.\n\n"
        "Full evidence and passed-items credit in the Review Log of the old task file "
        "(git history: tasks/2-needs-review/T-0116-*.md before this refactor).",
        True,
    ),
    (
        "T-0122",
        "Icon packs — fix 4 QA deviations (rare 30% in pack I, odds strip, AR labels, price ladder)",
        "high",
        "Tasks",
        "PARTIAL at review — 4 deviations: (F1 HIGH) pack I carries rare 30%, spec said "
        "epic+icons only — release blocked on F1; (F2 MED) pool is ALL positions, owner "
        "ruling needed on 'on top of ST packs' scope; (F3 MED) contents-screen odds strip "
        "shows no icon line, icon labels hardcoded EN (no ARB keys); (F4 MED) price ladder "
        "flat 11,000/24,000/24,000 — must be strictly ascending above ST Legendary.\n\n"
        "100k-draw calibration +/-4sigma passes for shipped values. Full evidence in the old "
        "task file (git history: tasks/2-needs-review/T-0122-*.md).",
        False,
    ),
    (
        "T-0124",
        "Delete players_v1 — finish test migration and re-lock balance gates (6 failures)",
        "high",
        "Tasks",
        "PARTIAL at review — file deleted and tools migrated, BUT six deterministic failures "
        "remain on main (F6 MED): real_dataset_test.dart:54 pins old top MV 200,000,000 (now "
        "305,603,925) and :226 expects top-100 hits from rare-pack opens (deterministically 0 "
        "now); pack_tier_bands_test.dart:29 and pack_reveal_timeline_test.dart:171 call legacy "
        "importDatasetFromJson (type-cast crash); pack_reveal_timeline_test.dart:223 pins "
        "PackTier count 3 (now 6); pack_rarity_test.dart:66 pins premium 20-45 (now 133); "
        "schema_v10_migration_test.dart:205 pins schemaVersion 16 (now 17).\n\n"
        "Fix list also in docs/QA_Review_tm-bundle_icon_players.docx section 5.1 F6.",
        False,
    ),
    (
        "T-0125",
        "E2E smoke pass — new dataset world with icons, icon packs and wildcard chemistry",
        "medium",
        "Tasks",
        "Acceptance gate over T-0120..T-0124 as one product change. Never started (QA 2026-11-12: "
        "the developer's commit covers code + unit/widget tests only; no on-device smoke pass).\n\n"
        "Flow: fresh install -> onboarding -> club creation (22 starting packs yield new-dataset "
        "players) -> ST store section shows Icon I/II/III above ST tier cells (EN+AR) -> buy/open "
        "each icon pack type, odds sheet shows icon chance line, icon reveal works -> field an icon: "
        "golden links to every teammate, tactics badge + pre-match forecast read wildcard-inclusive "
        "chemistry, engine totals reflect it -> collection/campus/profile render new-dataset names, "
        "fallback portraits (19,083 players have null images), crests and league logos -> sell an "
        "icon, buy squad slots, run a full season match -> EN/AR language toggle over store and pitch.\n\n"
        "Capture PASS/FAIL checklist + screenshots (ST store, odds sheet, icon reveal, icon-in-XI "
        "golden links) + cold-start delta (~12 MB file must parse off the UI thread). Execute only "
        "after T-0124 F6 fixes land.",
        False,
    ),
    (
        "T-0119",
        "Club chemistry — second dimension and white/golden links on the pitch",
        "high",
        "Needs Review",
        "Implementation finished (attempt 1), no review yet. Summary: chemistryPercentOf "
        "generalized to grouping keys, clubChemistryKeyOf (id wins over name, '' never groups), "
        "totalChemistryPercentOf sum clamped at 10 (T-0068 ceiling); ChemistryLinkKind kinds, "
        "pair-union dedup, golden = pair shares both dimensions; four computation sites icon-aware; "
        "balance suite 109/109, chemistry suites 31/31.\n\n"
        "Open notes: (1) club = real-world club reading assumed; (2) golden tone legibility on "
        "dark grass not visually verified on a device; (3) 25 pre-existing full-suite failures on "
        "main (card-regalia commits) are out of scope.\n\n"
        "Full Developer Notes in the old task file (git history: "
        "tasks/2-needs-review/T-0119-*.md).",
        False,
    ),
    (
        "T-0082",
        "Chance-creation curve scale-free — umbrella decision record (shipped via T-0114..T-0116)",
        "high",
        "Done",
        "PASS as a decision record. The scale-free property SHIPPED across three commits "
        "(T-0114 4b94310, T-0115 57b3322, T-0116): symmetric growth structurally neutral "
        "forever (home-win drift 0.003, was 0.518), +50% stomp dead (0.950->0.891 away-lift, "
        "0.970->0.948 home-lift), every existing ladder band green with zero edits. The "
        "0.88-both-directions ceiling remains open and is tracked by T-0116's rework item (3).\n\n"
        "Executable requirements live in the old task file (git history: "
        "tasks/2-needs-review/T-0082-*.md).",
        False,
    ),
    (
        "T-0120",
        "Replace players_v1 core data with the new four-file TM dataset",
        "critical",
        "Done",
        "PASS (QA 2026-11-12, commit 5925017). Loader PlayerDataset.fromTmBundle, pure parse of "
        "the 4 files as sent; version 4, isolate parse in providers.dart; survivor math verified "
        "(39,017 regulars + 73 icons = 39,090); old file deleted.\n\n"
        "Follow-ups (not blockers): assets/data/new/ duplicate ~12 MB could be removed; stale "
        "players_v1 doc refs in pack_rarity.dart:8 and the deprecated refresh script.",
        False,
    ),
    (
        "T-0121",
        "Import the 73 icons from tm-icons.json as icon players (schema + ownership)",
        "critical",
        "Done",
        "PASS (QA 2026-11-12, commit 5925017). Schema v17 players.is_icon with guarded migration "
        "(also fixes a latent v16-step ALTER crash); 73 icons imported, club-less; 5 dual-file ids "
        "resolve icon-wins; regular pack scopes and AI opponent pool exclude icons (60,000-draw "
        "exclusivity test); icon holo rarity renders on big card, mini card and goal scorer. "
        "Icon suite 15/15 green.",
        False,
    ),
    (
        "T-0123",
        "Icon players fulfill both chemistry types with every player on the pitch",
        "high",
        "Done",
        "PASS with one low-severity note (QA 2026-11-12). Wildcards at the grouping-key layer "
        "(chemistryPercentWithIcons); icons' own keys never form ordinary groups; all four "
        "computation sites icon-aware; links layer draws the icon's golden thread to every slot; "
        "10% ceiling intact; T-0068 balance gate re-ran green (109/109).\n\n"
        "Note (F5, LOW): with 2+ icons the [rest of the original note is in the old task file — "
        "git history: tasks/2-needs-review/T-0123-*.md].",
        False,
    ),
]

BLOCKED_LABEL_ID = "2186362765"


def call(method, path, body=None):
    req = urllib.request.Request(
        API + path,
        data=json.dumps(body).encode() if body is not None else None,
        headers={
            "Authorization": "Bearer " + TOKEN,
            "Content-Type": "application/json",
        },
        method=method,
    )
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read().decode()
            return r.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")


def main():
    # Safety: refuse to run twice (idempotency guard)
    status, data = call("GET", "/tasks?project_id=" + PROJECT_ID)
    if status != 200:
        sys.exit("cannot list tasks: %s %s" % (status, data))
    existing = [t for t in data.get("results", []) if "[T-" in t.get("content", "")]
    if existing:
        print("Existing migrated tasks found, aborting to avoid duplicates:")
        for t in existing:
            print(" -", t["content"][:70])
        sys.exit(1)

    for tid, title, prio, section, desc, blocked in TASKS:
        body = {
            "content": "[%s] %s" % (tid, title),
            "description": desc[:16383],  # API limit safety
            "project_id": PROJECT_ID,
            "section_id": SECTIONS[section],
            "priority": PRIORITY_MAP[prio],
        }
        if blocked:
            body["label_ids"] = [BLOCKED_LABEL_ID]
        status, resp = call("POST", "/tasks", body)
        if status != 200:
            print("FAIL %s: %s %s" % (tid, status, resp))
            sys.exit(1)
        print("OK   %-7s -> %-13s (todoist %s)" % (tid, section, resp["id"]))

    print("\nMigration complete: %d tasks" % len(TASKS))


if __name__ == "__main__":
    main()
