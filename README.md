# fcm_rivals

**FCM Rivals** — a football management / player collection / strategy game
built with Flutter. Offline single-player first, online-ready architecture.

The full game design and requirements live in [`docs/fcm_rivals_GDD_SRS.md`](docs/fcm_rivals_GDD_SRS.md).

## Current state (development build)

Six iterations are complete — the foundation engines, the collection
layer, the Match Engine with live tactics, the Division & Season system,
Pep Talks with rewarded advertisements, and the simulation & balance
harness (GDD §30–33) that calibrates them. The GDD's development rules (§36) are followed: data model first,
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
| Match Engine | `lib/features/match/` | deterministic seeded event pipeline, team totals with stamina/mentality/style/home-advantage modifiers, live tactical commands, substitutions, red cards, AI adaptation (GDD 12/26) |
| Match Reporting | `lib/features/match/` | commentary, statistics and position-sensitive player ratings derived from the same event records (GDD 13/14) |
| Stamina | `lib/features/match/` | dynamic workload-based consumption, post-match recovery, pep talk bonuses (GDD 11) |
| Tactics | `lib/features/match/` | 10 playing styles, 7 mentalities, 5 live actions with explicit percentage modifiers (GDD 10/16) |
| Pep Talks | `lib/features/match/` | pre-match and half-time motivational choices with visible percentage modifiers applied through the engine command pipeline, post-match recovery choice (GDD 15) |
| Rewarded Ads | `lib/features/ads/` | pure validation engine (completion, duplicate prevention, daily limits, replay window) + AdUsage ledger; ad-boosted +15% recovery and match replay (GDD 19, FR-040..FR-043) |
| Simulation Harness | `lib/features/simulation/` | MatchSimulator (GDD 31 metrics + determinism checks) and EconomySimulator (GDD 30/32/33 multi-season saves through the real stores); `tool/simulation_report_test.dart` regenerates the balance report |
| Season Engine | `lib/features/season/` | division difficulty scaling, AI club + squad generation through the stats curve, double round-robin fixtures, standings, promotion/relegation, position-based rewards (GDD 9/18, FR-035..FR-039) |
| Season Store | `lib/features/season/` | season lifecycle over Drift: 20-club divisions, fixture play through the MatchEngine, quick simulation, history preservation, rewards with ledger |
| Collection Store | `lib/features/collection/` | atomic pack open/sell/merge, club creation with 36 starting packs, dataset-update compensation, coin ledger, match result persistence (FR-012..FR-016) |
| Persistence | `lib/core/database/` | Drift/SQLite schema v3: players, dataset versions, clubs (user + AI), owned players, packs, coin transactions, seasons, league teams, fixtures, match results, AI players, ad usages (SRS 25) |
| App UI | `lib/app/`, `lib/features/*/` screens | Riverpod providers, club creation, pack opening with reveal, pitch squad view, collection management, live match screen with tactics and post-match report |

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
flutter test     # 194 tests: engines, match engine, season system, pep talks, rewarded ads, simulation harness invariants, update rules, store integration, UI flow
flutter run
```

Requires Flutter 3.47.9 stable / Dart 3.13.7 (`sdk: ^3.13.7`).

## Roadmap

The simulation harness (§30–33) is in place and has already driven three
balance fixes (economy anchor, stamina recovery curve, away-fixture
result inversion). Next per the GDD's Definition of Done (§37): tune
promotion rates from the harness data, additional ad reward surfaces
(free pack, upgrade discount, multipliers — GDD 19.3), and carrying over
promoted/relegated clubs between divisions (GDD 9.5).
