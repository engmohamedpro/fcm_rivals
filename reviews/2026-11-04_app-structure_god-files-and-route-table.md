# App structure: god files in core/ui and collection, no central route table
- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Reviewer: Kareem
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
The codebase is healthy overall (Riverpod-only state, atomic `CoinOps`, transactions in both stores, analyzer clean, 657 green tests) but three structural debts compound: `fcm_widgets.dart` is a 1,785-line god file mixing the design system with dropdowns, sheets, nav bars and the coin chip; `collection_store.dart` is a 1,437-line store owning club, squad, packs, campus and dataset import; and navigation is 33 ad-hoc `Navigator.push` call sites with no central route table, so transitions/deep links/restoration are unmanageable.

## Tasks
- [ ] Task 1: Split `fcm_widgets.dart` into cohesive files under `lib/core/ui/` | Where: `lib/core/ui/fcm_widgets.dart` (1,785 lines; contains FcmEntrance, FcmPanel, FcmButton, FcmPill, FcmDropdown + sheet, FcmBottomNav, FcmCoinChip, FcmEmptyState, etc.) | Expected: one widget family per file (suggested: `fcm_panel.dart`, `fcm_button.dart`, `fcm_dropdown.dart`, `fcm_nav.dart`, `fcm_feedback.dart`, `fcm_chip.dart`); `fcm_widgets.dart` may remain as a barrel `export` file so no feature import changes; `flutter analyze` clean; full test suite green with zero import-path churn outside `core/ui`.
- [ ] Task 2: Extract the club/squad/campus concerns out of `CollectionStore` | Where: `lib/features/collection/collection_store.dart` (1,437 lines; mixes `createClub`, `saveSquad`, pack open/sell/merge, campus levels, dataset import, match persistence) | Expected: new `ClubStore`, `SquadStore`, `CampusStore` (or equivalent) each under 400 lines with single-purpose APIs; `collectionStoreProvider` (`lib/app/providers.dart:99-106`) composes them; existing database schema and behaviour unchanged — the full test suite and the calibration/balance suites run green with no test edits beyond construction wiring.
- [ ] Task 3: Centralise navigation behind a route table | Where: the 33 `Navigator.of(context).push`/`MaterialPageRoute` sites (see `lib/features/packs/packs_screen.dart:164/:322`, `lib/features/season/season_screen.dart:70/:92`, `lib/features/match/match_screen.dart:671`, `lib/features/squad/player_card_reveal.dart:47`, `lib/features/collection/player_detail_sheet.dart:114` and the pops in `lib/core/ui/fcm_widgets.dart:1173`, `lib/features/match/live_match_views.dart:924`) | Expected: either a typed `AppRoutes` enum/class wrapping `MaterialPageRoute` creation in ONE file (minimal, no new dependency) or `go_router` if deep links / URL state become requirements; every push/pop site routes through it; no behavioural change (transitions identical); a smoke test walks pre-match → match → report → continue and pack buy → open → contents through the new table.
- [ ] Task 4: Document the layering decision in the README | Where: `README.md` architecture table (currently lists features without a state/layout convention) | Expected: README states the feature layout convention (flat feature folders with `core/` shared), the Riverpod-only rule, the store split from Task 2, and the routing approach chosen in Task 3 — so the next contributor does not reintroduce god files.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] No file in `lib/` exceeds 1,000 lines (excluding generated `*.g.dart`)
- [ ] Full suite (657+ tests) green with no skipped tests
- [ ] README architecture section matches the post-refactor tree

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
