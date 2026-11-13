# Localization phase 2 — string migration checklist

Tracks the remaining hardcoded English UI literals until zero. Phase 1
(shell, onboarding, squad, season core) landed in commit `7d95068`; this
checklist picks up the leftovers across the feature files.

## Rules

1. The count below is the baseline recorded on **2026-11-04**. Re-run the
   audit command after every migration commit and update the table.
2. The tracked total must move **down, never up** — a new feature with a
   hardcoded string is a review-time reject, not a checklist edit.
3. `Text('$e')` runtime-error surfaces are counted separately: localizing
   raw exception text is out of scope (it is developer diagnostics, not
   user copy); wrap the known failure modes with localized copy instead.
4. Engine/data strings (see "Not UI literals" below) are rendered as data
   and stay in English by design unless a separate review says otherwise.

## Audit command

```bash
python3 - <<'EOF'
import re, glob
lit = re.compile(r"Text\(\s*'([^']+)'|Text\(\s*\"([^\"]+)\"")
files = sorted(glob.glob('lib/features/**/*.dart', recursive=True)) + \
        sorted(glob.glob('lib/core/**/*.dart', recursive=True)) + ['lib/main.dart']
total = 0
for f in files:
    if f.endswith('.g.dart'): continue
    ui = [m for line in open(f) if (m := lit.search(line))
          and (m.group(1) or m.group(2)).strip()
          and not (m.group(1) or m.group(2)).strip().startswith('$')]
    if ui: print(f"{len(ui):3}  {f}"); total += len(ui)
print("TOTAL", total)
EOF
```

## Baseline (2026-11-04)

UI literals rendered to the user with a hardcoded English string:

| File | UI literals | Status |
|---|---:|---|
| `lib/features/collection/collection_collection_screen.dart` | 13 | OPEN — sale/upgrade confirmations (`Boost this sale?`, `No thanks`, `Watch ad`, `Sell player?`, `Cancel`, `Sell`, `Upgrade`, sold/upgrade confirmations), sort menu (`Highest rating`, `Newest first`, `Market value`), `Next division: {n}` interpolation |
| `lib/features/season/season_screen.dart` | 1 | OPEN — `Next division: {completion.nextDivision}` (season completion card) |

**Tracked total: 14 → 0.**

Migrated this pass (2026-11-04, review
`2026-11-04_localization_skip-hint-rtl-test-and-phase2-tracking`):

| File | Was | Now |
|---|---:|---:|
| `lib/features/packs/packs_screen.dart` | 3 | 0 (`packsSoldFor`, `packsNotEnoughCoins`) |
| `lib/features/match/live_tactics_screen.dart` | 2 | 0 (`liveTacticsTitle`, `liveTacticsCancelSelection`) |
| `lib/features/match/match_screen.dart` | 9 | 0 (recovery card + half-time confirmation row, 12 ARB keys) |

## Not UI literals — explicitly out of scope

These render **engine/data strings**, not screen chrome; the review asked
for the split to be stated:

- `lib/features/match/tactics.dart:364-417` — `MatchPepTalk.label`,
  `.description`, `.effectSummary` (`'Fear no one!'`, `'Attack +4%'`, …)
  and the `halfTimePepTalks`/`preMatchPepTalks` lists. Rendered through
  `TouchlinePepTalkCard`/`SheetOption` in
  `lib/features/match/live_match_views.dart:921/:1114/:1123` and the
  pre-match sheet. These are content the way commentary lines are content;
  migrating them means ARB keys per talk id (12 keys) — a separate,
  content-level task (filed below).
- `lib/features/match/live_match_views.dart:308/:549-561/:1068` —
  broadcast chrome labels (`MOMENTUM`, `GOAL`, `PENALTY`, `RED CARD`,
  `EDIT TACTICS`). Stadium-broadcast styling is intentionally English
  (broadcast graphics convention); revisit only if product wants Arabic
  broadcast overlays.
- `lib/features/match/stamina.dart:137-160` — `PepTalk.displayName`:
  already bridged for UI through `lib/l10n/pep_talk_l10n.dart`
  (`pepTalkName`); the raw `displayName` remains for logs/debug.
- `Text('$e')` error surfaces in `packs_screen` (5), `campus_screen` (1),
  `live_tactics_screen` (1), `pack_contents_screen` (1), `squad_screen` (1),
  `club_creation_screen` (1), `season_screen` (1), `main.dart` (1):
  raw exception text, developer diagnostics — not localizable copy.

## Next step (to be filed as its own review when picked up)

`2026-11-04_localization_match-talk-content.md` — 12 ARB keys for the
`MatchPepTalk` labels/descriptions keyed by talk `id`, effect summary via a
parameterized key (`Attack +{n}%` style), plus an extension mirroring
`pep_talk_l10n.dart`. That closes the last user-visible English block in
the match flow.
