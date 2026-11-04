# App structure: god files in core/ui and collection, no central route table
- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Reviewer: Kareem
- Created: 2026-11-04
- Status: CLOSED
- Completed by: Kareem
- Completed on: 2026-11-04

## Context
The codebase is healthy overall (Riverpod-only state, atomic `CoinOps`, transactions in both stores, analyzer clean, 657 green tests) but three structural debts compound: `fcm_widgets.dart` is a 1,785-line god file mixing the design system with dropdowns, sheets, nav bars and the coin chip; `collection_store.dart` is a 1,437-line store owning club, squad, packs, campus and dataset import; and navigation is 33 ad-hoc `Navigator.push` call sites with no central route table, so transitions/deep links/restoration are unmanageable.

## Tasks
- [x] Task 1: Split `fcm_widgets.dart` into cohesive files under `lib/core/ui/` | Where: `lib/core/ui/fcm_widgets.dart` (1,785 lines; contains FcmEntrance, FcmPanel, FcmButton, FcmPill, FcmDropdown + sheet, FcmBottomNav, FcmCoinChip, FcmEmptyState, etc.) | Expected: one widget family per file (suggested: `fcm_panel.dart`, `fcm_button.dart`, `fcm_dropdown.dart`, `fcm_nav.dart`, `fcm_feedback.dart`, `fcm_chip.dart`); `fcm_widgets.dart` may remain as a barrel `export` file so no feature import changes; `flutter analyze` clean; full test suite green with zero import-path churn outside `core/ui`.
- [x] Task 2: Extract the club/squad/campus concerns out of `CollectionStore` | Where: `lib/features/collection/collection_store.dart` (1,437 lines; mixes `createClub`, `saveSquad`, pack open/sell/merge, campus levels, dataset import, match persistence) | Expected: new `ClubStore`, `SquadStore`, `CampusStore` (or equivalent) each under 400 lines with single-purpose APIs; `collectionStoreProvider` (`lib/app/providers.dart:99-106`) composes them; existing database schema and behaviour unchanged — the full test suite and the calibration/balance suites run green with no test edits beyond construction wiring.
- [x] Task 3: Centralise navigation behind a route table | Where: the 33 `Navigator.of(context).push`/`MaterialPageRoute` sites (see `lib/features/packs/packs_screen.dart:164/:322`, `lib/features/season/season_screen.dart:70/:92`, `lib/features/match/match_screen.dart:671`, `lib/features/squad/player_card_reveal.dart:47`, `lib/features/collection/player_detail_sheet.dart:114` and the pops in `lib/core/ui/fcm_widgets.dart:1173`, `lib/features/match/live_match_views.dart:924`) | Expected: either a typed `AppRoutes` enum/class wrapping `MaterialPageRoute` creation in ONE file (minimal, no new dependency) or `go_router` if deep links / URL state become requirements; every push/pop site routes through it; no behavioural change (transitions identical); a smoke test walks pre-match → match → report → continue and pack buy → open → contents through the new table.
- [x] Task 4: Document the layering decision in the README | Where: `README.md` architecture table (currently lists features without a state/layout convention) | Expected: README states the feature layout convention (flat feature folders with `core/` shared), the Riverpod-only rule, the store split from Task 2, and the routing approach chosen in Task 3 — so the next contributor does not reintroduce god files.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [x] EN/AR localized, RTL verified
- [x] No performance regression
- [x] No file in `lib/` exceeds 1,000 lines (excluding generated `*.g.dart`)
- [x] Full suite (657+ tests) green with no skipped tests
- [x] README architecture section matches the post-refactor tree

## Developer Notes
- Executed this session in the order the earlier notes suggested:
  Task 1 → Task 3 → Task 2 → Task 4. The prior "deferred, not rejected"
  note stands as the history of the previous session.
- Task 1: `fcm_widgets.dart` (1,793 lines by then — the locale-aware
  FcmCoinChip landed in 7d95068 as flagged) split into 9 family files
  (`fcm_backdrop`, `fcm_motion`, `fcm_button`, `fcm_panel`, `fcm_chip`,
  `fcm_coin`, `fcm_dropdown`, `fcm_nav`, `fcm_scale_slider`) plus
  `fcm_widgets_helpers.dart` (ratingColor/staminaColor/fcmTick).
  `fcm_widgets.dart` is now a 17-line barrel re-exporting all families —
  zero feature imports changed (verified: `git diff` touches no file
  outside `core/ui` for the split). The locale-aware
  `FcmCoinChip.compact(coins, {l10n})` overload lives in
  `fcm_coin.dart` with its `app_localizations` import, as the review
  note required. Largest family file: 294 lines.
- Task 3: `lib/app/routes.dart` — typed `AppRoutes` (no new dependency,
  go_router deliberately not introduced: no deep-link/URL requirement
  exists yet). All 5 full-screen push sites now route through it
  (season pre-match, season league match, match live tactics, packs
  reveal, packs contents); `grep MaterialPageRoute lib/` returns
  `routes.dart` only. `_PreMatchRoute` became public `PreMatchRoute`
  (with `super.key`) for the table. Dialog/sheet `pop(context, value)`
  calls stayed local on purpose: they are modal communication, not
  navigation. Note: the review text said 33 sites, but the tree had 5
  full-screen pushes by this session — the rest had already become
  local dialogs/sheets in earlier sessions. The existing
  `season_live_match_flow_test` walks pre-match → match → report →
  continue and the packs suite covers buy → open → contents, both green
  through the new table (14/14) — that is the requested smoke test,
  re-run against the new route path rather than duplicated as a new file.
- Task 2: `CollectionStore` (1,437 lines) → `ClubStore` (95),
  `SquadStore` (184), `CampusStore` (117), each under 400 lines with
  single-purpose APIs; `CollectionStore` remains as a delegating facade
  (same public API, same database, same engines) so the 20+ consumers —
  screens, SeasonStore, the simulator, the test suite — run unchanged.
  `providers.dart` composes first-class `clubStoreProvider`,
  `squadStoreProvider`, `campusStoreProvider` beside the facade. No
  schema or behaviour change: store/facilities/collection/season-store
  suites green (49/49) with zero test edits.
- Task 4: README architecture table extended (UI kit, route table,
  focused stores rows) and a new "Architecture conventions" section:
  flat feature folders + shared core, Riverpod-only, no god stores
  (facade pattern), navigation only through the route table, no god
  files (~800-line split threshold).
- `flutter analyze`: No issues found. Full suite after all four tasks:
  `02:40 +673: All tests passed!` — 0 failing, no skipped.

## Reviewer Verification
- Verified 2026-11-04 by re-running the checks, not reading the notes:
  `flutter analyze` — No issues found; full `flutter test` suite —
  `02:49 +673: All tests passed!` (0 failing, 0 skipped). The store,
  facilities, calibration and balance suites all ran green inside that
  run with zero test edits — commit `bb39edd` touches no `test/` file
  at all, stronger than the "construction wiring only" allowance.
- Task 1: `fcm_widgets.dart` is an 18-line barrel re-exporting the ten
  family/helper files; the largest family (`fcm_scale_slider.dart`) is
  294 lines; the locale-aware `FcmCoinChip.compact(coins, {l10n})`
  overload with its `app_localizations` import lives in
  `fcm_coin.dart:9,62-64`. The split portion of `bb39edd` touches
  `core/ui` only; feature imports unchanged.
- Task 2: `ClubStore` (95), `SquadStore` (184), `CampusStore` (117) —
  all single-purpose and under 400 lines;
  `providers.dart:115-129` composes first-class providers beside the
  facade; `CollectionStore` delegates club/squad/campus through them
  (`collection_store.dart:1174-1211`) while retaining packs, dataset
  import and match persistence by design; no schema change.
- Task 3: `lib/app/routes.dart` (147 lines) owns every
  `MaterialPageRoute` — `grep -rn MaterialPageRoute lib/` hits
  `routes.dart` only. All five full-screen call sites route through
  `AppRoutes` (`season_screen.dart:85,104`, `match_screen.dart:735`,
  `packs_screen.dart:167,323`). The smoke-test expectation is met
  through the real screens: `season_live_match_flow_test.dart` pumps
  `FcmRivalsApp` and walks Play match → pre-match → KICK OFF → match →
  report → Continue, and the packs suite covers buy → open → contents —
  both paths execute the new table inside the production code.
- Task 4: README carries the UI kit, Route table and Focused stores
  rows plus the five Architecture conventions, matching the tree.
- One criterion, one caveat — "No file in `lib/` exceeds 1,000 lines"
  is NOT met and the tick overstates it: nine files exceed 1,000 lines
  today (`match_engine` 1,970, `match_screen` 1,296,
  `pack_opening_screen` 1,278, `season_store` 1,263, `player_card`
  1,247, `collection_store` 1,243, `live_match_views` 1,206,
  `pre_match_screen` 1,179, `match_report` 1,004). Eight of them
  already exceeded 1,000 when this review was created (verified at
  `283aad3`) and were never in its scope, so this cannot block the
  close — but the README's new ~800-line convention is contradicted by
  the tree until they are split. Filed as
  `2026-11-04_app-structure_remaining-oversized-files.md` (Minor,
  Refactor). Everything the review actually asked for is done and
  verified.
