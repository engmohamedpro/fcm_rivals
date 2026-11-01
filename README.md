# fcm_rivals

**FCM Rivals** — a football management / player collection / strategy game
built with Flutter. Offline single-player first, online-ready architecture.

The full game design and requirements live in [`docs/fcm_rivals_GDD_SRS.md`](docs/fcm_rivals_GDD_SRS.md).

## Current state (development build)

Two iterations are complete — the foundation engines and the collection
layer. The GDD's development rules (§36) are followed: data model first,
engines as pure Dart with no UI dependencies, atomic coin transactions.

| Module | Path | Covers |
| --- | --- | --- |
| Domain model | `lib/core/domain/` | `Position` (12 codes), `BasePlayer`, `BaseStats`, `OwnedPlayer`, league metadata |
| Base Stats generation | `lib/core/domain/base_stats_generator.dart` | non-linear Market Value curve, position-specific attribute weightings (GDD 4.5) |
| Player Database Engine | `lib/features/player_database/` | dataset validation, import, update rules, removal detection (GDD 4.6–4.8, FR-002..FR-008) |
| Economy Engine | `lib/features/economy/` | economic value curve, selling (incl. upgraded), upgrade costs, match rewards (GDD 17) |
| Pack Engine | `lib/features/packs/` | five categories, 3-player tier draws, value-weighted odds, dynamic pricing (GDD 5) |
| Squad Engine | `lib/features/squad/` | 10 data-driven formations, compatibility matrix, position-sensitive ratings, Auto Pick (GDD 6/7) |
| Upgrade Engine | `lib/features/upgrades/` | duplicate-merge progression, controlled attribute allocation (GDD 8) |
| Collection Store | `lib/features/collection/` | atomic pack open/sell/merge, club creation with 36 starting packs, dataset-update compensation, coin ledger (FR-012..FR-016) |
| Persistence | `lib/core/database/` | Drift/SQLite schema: players, dataset versions, clubs, owned players, packs, coin transactions (SRS 25) |
| App UI | `lib/app/`, `lib/features/*/` screens | Riverpod providers, club creation, pack opening with reveal, pitch squad view, collection management |

All engines are pure Dart with no Flutter UI dependencies, ready for the
future authoritative server port (GDD §29). All balancing constants live in
one configuration class per engine (`BaseStatsConfig`, `EconomyConfig`) as
pre-balance placeholders per GDD rule 14.

## Player database

`assets/data/players_v1.json` — 20,876 real players with:

- `playerId` — stable permanent identity (Transfermarkt player id, GDD 4.4)
- name, position (12 GDD codes), age, nationality, club, domestic league
  code, Market Value in EUR

Built from the open **player-scores** dataset (Transfermarkt-derived,
originally by dcaribou, mirrored on HuggingFace), filtered to players active
in 2024+ seasons with a positive market value. The shipped asset embeds
dataset version, as-of date, league table and a content digest for integrity
checking. Example rows (top by Market Value): Erling Haaland (ST, 200M),
Lamine Yamal (RW, 200M), Kylian Mbappé (ST, 180M).

Player facts follow the GDD update rules on re-import: Base Stats regenerate
only when Market Value or Position changed; unchanged players keep their
stats byte-for-byte; upgrades live on owned instances and survive updates.

## Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # regenerate drift code
flutter analyze
flutter test     # 100 tests: engines, update rules, store integration, UI flow
flutter run
```

Requires Flutter 3.47.9 stable / Dart 3.13.7 (`sdk: ^3.13.7`).

## Roadmap

Next per the GDD's Definition of Done (§37): the Match Engine (deterministic
seeded event pipeline, §12/§26) with divisions, seasons, fixtures and AI
clubs (§9), then stamina, pep talks and live match actions.
