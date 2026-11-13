/// T-0130: season statistics aggregation — contributionsOf folds the
/// event timeline into per-player tallies that exactly match what
/// computePlayerRatings sees, and persistMatchContributions upserts
/// them into the PlayerSeasonStats table (schema v18).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/season/season_stats.dart';

MatchPlayer _player(
  int id,
  String name,
  Position position, {
  int minutes = 90,
}) => MatchPlayer(
  playerId: id,
  name: name,
  position: position,
  attack: 80,
  support: 70,
  defence: 60,
  goalkeeping: position == Position.gk ? 80 : 10,
)..minutesPlayed = minutes;

MatchEvent _goal(int teamId, int scorer, int? assister, int minute) =>
    MatchEvent(
      eventId: 0,
      minute: minute,
      second: 0,
      type: MatchEventType.goal,
      side: MatchSide.home,
      teamId: teamId,
      primaryPlayerId: scorer,
      secondaryPlayerId: assister,
    );

MatchEvent _shot(int teamId, int shooter, int gkId, int minute) => MatchEvent(
  eventId: 0,
  minute: minute,
  second: 0,
  type: MatchEventType.shot,
  side: MatchSide.home,
  teamId: teamId,
  primaryPlayerId: shooter,
  shotOutcome: ShotOutcome.saved,
  metadata: {'gkPlayerId': gkId},
);

void main() {
  test('contributionsOf tallies goals, assists, shots and saves from '
      'the timeline', () {
    final teamId = 1;
    final players = [
      _player(10, 'Striker One', Position.st),
      _player(7, 'Winger', Position.rw),
      _player(1, 'Keeper', Position.gk),
      _player(5, 'Unused Sub', Position.cm, minutes: 0),
    ];
    final events = <MatchEvent>[
      _goal(teamId, 10, 7, 12), // striker scores, winger assists
      _goal(teamId, 10, null, 30), // striker again
      _shot(teamId, 10, 1, 45), // saved by their keeper
      _shot(teamId, 7, 1, 60),
    ];
    final contributions = contributionsOf(
      events: events,
      players: players,
      teamId: teamId,
      teamGoalsConceded: 0,
    );
    final byId = {for (final c in contributions) c.playerId: c};

    expect(byId[10]!.goals, 2);
    expect(byId[10]!.shots, 2);
    expect(byId[7]!.assists, 1);
    expect(byId[1]!.saves, 2);
    // Clean sheet with a full match played (the rating's own rule).
    expect(byId[10]!.cleanSheet, 1);
    expect(byId[1]!.cleanSheet, 1);
    // Unused sub: no appearance, no goalsConceded booking.
    expect(byId[5]!.played, isFalse);
    expect(byId[5]!.goalsConceded, 0);
    // Ratings come from computePlayerRatings — a scorer outranks the
    // baseline here, the unused sub sits exactly on it.
    expect(byId[10]!.rating, greaterThan(6.0));
    expect(byId[5]!.rating, 6.0);
  });

  test('events of the OTHER team are ignored', () {
    final players = [_player(9, 'Striker', Position.st)];
    final events = <MatchEvent>[
      _goal(2, 99, null, 10), // opponent scores — not our event
      _goal(1, 9, null, 20),
    ];
    final contributions = contributionsOf(
      events: events,
      players: players,
      teamId: 1,
      teamGoalsConceded: 1,
    );
    expect(contributions.single.goals, 1);
    expect(contributions.single.goalsConceded, 1);
  });

  test('persistMatchContributions inserts then accumulates across two '
      'matches', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    MatchEvent goal(int scorer, int minute) => _goal(1, scorer, null, minute);
    final players = [_player(10, 'Striker', Position.st)];

    // Match 1: one goal, clean sheet, 90 minutes.
    await persistMatchContributions(
      db,
      seasonId: 1,
      clubId: 1,
      contributions: contributionsOf(
        events: [goal(10, 15)],
        players: players,
        teamId: 1,
        teamGoalsConceded: 0,
      ),
    );
    // Match 2: two more goals, one conceded.
    await persistMatchContributions(
      db,
      seasonId: 1,
      clubId: 1,
      contributions: contributionsOf(
        events: [goal(10, 20), goal(10, 70)],
        players: players,
        teamId: 1,
        teamGoalsConceded: 1,
      ),
    );

    final rows = await db.select(db.playerSeasonStats).get();
    expect(rows, hasLength(1), reason: 'same player upserts, never re-inserts');
    final row = rows.single;
    expect(row.seasonId, 1);
    expect(row.clubId, 1);
    expect(row.playerId, 10);
    expect(row.playerName, 'Striker');
    expect(row.goals, 3);
    expect(row.appearances, 2);
    expect(row.minutesPlayed, 180);
    expect(row.cleanSheets, 1);
    expect(row.goalsConceded, 1);
    // ratingSum accumulates both matches; average stays within the
    // engine's 1..10 clamp bounds.
    expect(row.ratingSum, greaterThan(12.0));
    expect(row.ratingSum / row.appearances, lessThanOrEqualTo(10.0));
  });

  test('unused players never enter the table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await persistMatchContributions(
      db,
      seasonId: 1,
      clubId: 1,
      contributions: [
        PlayerMatchContribution(
          playerId: 99,
          playerName: 'Bench',
          position: 'CM',
          goals: 0,
          assists: 0,
          shots: 0,
          saves: 0,
          cleanSheet: 0,
          goalsConceded: 0,
          minutesPlayed: 0,
          rating: 6.0,
        ),
      ],
    );
    expect(await db.select(db.playerSeasonStats).get(), isEmpty);
  });

  test('fresh install creates the v18 table and reads it back through '
      'the companion', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 18);

    await db
        .into(db.playerSeasonStats)
        .insert(
          PlayerSeasonStatsCompanion.insert(
            seasonId: 1,
            clubId: 7,
            playerId: 10,
            playerName: 'Striker',
            position: 'ST',
            goals: const Value(5),
          ),
        );
    final row = (await db.select(db.playerSeasonStats).get()).single;
    expect(row.goals, 5);
    expect(row.assists, 0, reason: 'DEFAULT 0 columns read back');
    expect(row.ratingSum, 0.0);
  });
}
