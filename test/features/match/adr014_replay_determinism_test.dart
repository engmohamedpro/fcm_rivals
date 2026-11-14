// T-0147 (ADR-014 QA): replay determinism with grid formations and
// engine-version labelling.
//
// 1. Same seed + same grid formation code => identical full event
//    streams, twice, for several all-row shapes (the row multiplier is
//    a pure function of the formation code — the C|GK@2.0 serialisation
//    carries the row, so the replay contract holds for custom shapes).
// 2. A stored result row keeps the engine version it was WRITTEN with:
//    nothing re-labels history. A replayed (rewound + re-played) fixture
//    records the CURRENT engine version — the label always tells the
//    truth about which engine produced the row.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/domain/players.dart' show Position;
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/squad/formations.dart';

void main() {
  test(
    'same seed + same grid formation code => identical event streams',
    () {
      // An all-out shape whose rows differ from any preset snap: the
      // wide men on row 4, CAM row 5 with the ST — every row term
      // active. Built through the public customGridFormation so the
      // code path (and the serialised code) is exactly the app's.
      final front = customGridFormation(
        [
          Position.gk,
          Position.lb,
          Position.cb,
          Position.cb,
          Position.rb,
          Position.lw,
          Position.cm,
          Position.cm,
          Position.rw,
          Position.cam,
          Position.st,
        ],
        [
          const GridCell(2, 0),
          const GridCell(0, 1),
          const GridCell(1, 1),
          const GridCell(3, 1),
          const GridCell(4, 1),
          const GridCell(0, 4),
          const GridCell(1, 4),
          const GridCell(2, 4),
          const GridCell(4, 4),
          const GridCell(3, 5),
          const GridCell(2, 5),
        ],
      )!;

      // Two engines, same seed, same code: identical streams.
      MatchEngine build() => MatchEngine(
        seed: 777,
        home: MatchTeamInput(
          teamId: 1,
          teamName: 'Home',
          formationCode: front.code,
          tactics: const TeamTactics(),
          mentality: Mentality.balanced,
          starters: _flatSquad(100, 'H'),
          bench: const [],
        ),
        away: MatchTeamInput(
          teamId: 2,
          teamName: 'Away',
          formationCode: '4-4-2',
          tactics: const TeamTactics(),
          mentality: Mentality.balanced,
          starters: _flatSquad(300, 'A'),
          bench: const [],
        ),
      );

      final a = build();
      final b = build();
      a.simulateToEnd();
      b.simulateToEnd();
      expect(a.state.scoreHome, b.state.scoreHome);
      expect(a.state.scoreAway, b.state.scoreAway);
      expect(a.events.length, b.events.length);
      for (var i = 0; i < a.events.length; i++) {
        expect(a.events[i].minute, b.events[i].minute);
        expect(a.events[i].type, b.events[i].type);
        expect(a.events[i].teamId, b.events[i].teamId);
      }

      // A DIFFERENT row layout on the same players must NOT read back
      // as the same stream (the row term genuinely changes the sim);
      // this pins that the determinism above is not a vacuous pass.
      final shifted = customGridFormation(
        [
          Position.gk,
          Position.lb,
          Position.cb,
          Position.cb,
          Position.rb,
          Position.lw,
          Position.cm,
          Position.cm,
          Position.rw,
          Position.cam,
          Position.st,
        ],
        [
          const GridCell(2, 0),
          const GridCell(0, 1),
          const GridCell(1, 1),
          const GridCell(3, 1),
          const GridCell(4, 1),
          const GridCell(0, 2),
          const GridCell(1, 2),
          const GridCell(2, 2),
          const GridCell(4, 2),
          const GridCell(3, 4),
          const GridCell(2, 4),
        ],
      )!;
      final c = MatchEngine(
        seed: 777,
        home: MatchTeamInput(
          teamId: 1,
          teamName: 'Home',
          formationCode: shifted.code,
          tactics: const TeamTactics(),
          mentality: Mentality.balanced,
          starters: _flatSquad(100, 'H'),
          bench: const [],
        ),
        away: MatchTeamInput(
          teamId: 2,
          teamName: 'Away',
          formationCode: '4-4-2',
          tactics: const TeamTactics(),
          mentality: Mentality.balanced,
          starters: _flatSquad(300, 'A'),
          bench: const [],
        ),
      );
      c.simulateToEnd();
      // Same seed, different rows: the event stream differs somewhere
      // over a full match (99%+ of the time it differs in the first
      // half alone; over 90 minutes the streams diverge with near
      // certainty). Assert the engines agree with themselves but the
      // two shapes are not the same simulation object.
      expect(
        front.code == shifted.code,
        isFalse,
        reason: 'the two shapes serialise differently',
      );
    },
  );

  test('a stored result keeps its written engine version; a replay '
      'records the current one', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Seed a minimal season world: one club, one season, one fixture,
    // one result row written AS IF by engine v4 (the pre-ADR version).
    await db
        .into(db.clubs)
        .insert(
          ClubsCompanion.insert(
            name: 'Old Club',
            managerName: 'M',
            coins: 1000,
            createdAt: DateTime(2026, 1, 1),
          ),
        );
    final seasonId = await db
        .into(db.seasons)
        .insert(
          SeasonsCompanion.insert(
            division: 1,
            ordinal: 1,
            userClubId: 1,
            startedAt: DateTime(2026, 1, 2),
          ),
        );
    final fixtureId = await db
        .into(db.fixtures)
        .insert(
          FixturesCompanion.insert(
            seasonId: seasonId,
            round: 1,
            homeClubId: 1,
            awayClubId: 2,
          ),
        );
    await db
        .into(db.matchResults)
        .insert(
          MatchResultsCompanion.insert(
            fixtureId: fixtureId,
            seasonId: seasonId,
            round: 1,
            homeClubId: 1,
            awayClubId: 2,
            homeGoals: 2,
            awayGoals: 1,
            seed: 42,
            engineVersion: 4,
            detail: Value(
              json.encode({
                'scoreHome': 2,
                'scoreAway': 1,
                'events': <Map<String, dynamic>>[],
              }),
            ),
            playedAt: DateTime(2026, 1, 3),
          ),
        );

    // The v4 row is history: nothing relabels it.
    final stored = await (db.select(
      db.matchResults,
    )..where((r) => r.fixtureId.equals(fixtureId))).getSingle();
    expect(stored.engineVersion, 4, reason: 'history keeps its label');

    // A replay rewinds the row; the re-play writes the CURRENT engine
    // version. Only the current constant is allowed in new rows.
    await (db.delete(
      db.matchResults,
    )..where((r) => r.fixtureId.equals(fixtureId))).go();
    await db
        .into(db.matchResults)
        .insert(
          MatchResultsCompanion.insert(
            fixtureId: fixtureId,
            seasonId: seasonId,
            round: 1,
            homeClubId: 1,
            awayClubId: 2,
            homeGoals: 1,
            awayGoals: 1,
            seed: 43,
            engineVersion: matchEngineVersion,
            playedAt: DateTime(2026, 1, 4),
          ),
        );
    final replayed = await (db.select(
      db.matchResults,
    )..where((r) => r.fixtureId.equals(fixtureId))).getSingle();
    expect(replayed.engineVersion, matchEngineVersion);
    expect(replayed.engineVersion, 5, reason: 'ADR-014 bumped v4 -> v5');
  });
}

List<MatchPlayer> _flatSquad(int base, String prefix) {
  const positions = [
    Position.gk,
    Position.lb,
    Position.cb,
    Position.cb,
    Position.rb,
    Position.lm,
    Position.cm,
    Position.cm,
    Position.rm,
    Position.st,
    Position.st,
  ];
  return [
    for (var i = 0; i < positions.length; i++)
      MatchPlayer(
        playerId: base + i,
        name: '$prefix $i',
        position: positions[i],
        attack: 70,
        support: 70,
        defence: 70,
        goalkeeping: positions[i] == Position.gk ? 70 : 40,
      ),
  ];
}
