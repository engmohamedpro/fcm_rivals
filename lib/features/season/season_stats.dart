/// FCM Rivals — season statistics aggregation (T-0130, GDD 9.6).
///
/// Accumulates per-player season statistics from the SAME MatchEvents
/// the ratings and commentary derive from (GDD 26.4 — statistics never
/// come from side calculations). Called at match-commit time for every
/// fixture (user matches AND the AI-vs-AI quick sims), upserting into
/// the [PlayerSeasonStats] table (schema v18).
///
/// Aggregation rules (documented once, applied everywhere):
///  * goals / assists — goal events of the player's team, scorer and
///    assister ids straight off the event.
///  * shots — shot events (the shooter).
///  * saves — shot events saved by this keeper (metadata.gkPlayerId).
///  * clean sheets — a match with 0 goals conceded and >= 60 minutes
///    on the pitch, keepers and outfield alike (the rating's own rule).
///  * goals conceded — while the player was on the pitch.
///  * appearances / minutes / ratingSum — from the final player state
///    and computePlayerRatings, so the leaderboard's average rating is
///    exactly the rating the player earned match by match.
library;

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../match/match_engine.dart'
    show MatchEvent, MatchPlayer, MatchEventType, ShotOutcome;
import '../match/match_report.dart' show computePlayerRatings;

/// One player's per-match contribution, ready to fold into the season
/// row. Built from the event timeline; [rating] comes from
/// [computePlayerRatings] so the two can never disagree.
class PlayerMatchContribution {
  const PlayerMatchContribution({
    required this.playerId,
    required this.playerName,
    required this.position,
    required this.goals,
    required this.assists,
    required this.shots,
    required this.saves,
    required this.cleanSheet,
    required this.goalsConceded,
    required this.minutesPlayed,
    required this.rating,
  });

  final int playerId;
  final String playerName;
  final String position;
  final int goals;
  final int assists;
  final int shots;
  final int saves;
  final int cleanSheet;
  final int goalsConceded;
  final int minutesPlayed;
  final double rating;

  bool get played => minutesPlayed > 0;
}

/// Folds one match's events into per-player contributions for ONE team.
///
/// [events] is the full match timeline (both sides); [players] is the
/// team's final player list; [teamId] filters the timeline to this
/// team's events; [teamGoalsConceded] is what this team's keeper and
/// defenders conceded overall.
List<PlayerMatchContribution> contributionsOf({
  required List<MatchEvent> events,
  required List<MatchPlayer> players,
  required int teamId,
  required int teamGoalsConceded,
}) {
  // Per-player tallies from the timeline — the same field extraction
  // computePlayerRatings performs, kept in sync by the tests.
  final goals = <int, int>{};
  final assists = <int, int>{};
  final shots = <int, int>{};
  final saves = <int, int>{};

  for (final e in events) {
    if (e.teamId != teamId) continue;
    switch (e.type) {
      case MatchEventType.goal:
        if (e.primaryPlayerId != null) {
          goals[e.primaryPlayerId!] = (goals[e.primaryPlayerId!] ?? 0) + 1;
        }
        if (e.secondaryPlayerId != null) {
          assists[e.secondaryPlayerId!] =
              (assists[e.secondaryPlayerId!] ?? 0) + 1;
        }
      case MatchEventType.shot:
        if (e.primaryPlayerId != null) {
          shots[e.primaryPlayerId!] = (shots[e.primaryPlayerId!] ?? 0) + 1;
        }
        if (e.shotOutcome == ShotOutcome.saved) {
          final gkId = e.metadata['gkPlayerId'] as int?;
          if (gkId != null) saves[gkId] = (saves[gkId] ?? 0) + 1;
        }
      default:
        break;
    }
  }

  // Ratings: the exact same call the post-match report makes.
  final ratings = computePlayerRatings(
    events: events,
    players: players,
    teamId: teamId,
    teamGoals: events
        .where((e) => e.type == MatchEventType.goal && e.teamId == teamId)
        .length,
    teamGoalsConceded: teamGoalsConceded,
  );
  final ratingById = {
    for (final r in ratings) r.playerId: r.rating,
  };

  return [
    for (final p in players)
      PlayerMatchContribution(
        playerId: p.playerId,
        playerName: p.name,
        position: p.position.code,
        goals: goals[p.playerId] ?? 0,
        assists: assists[p.playerId] ?? 0,
        shots: shots[p.playerId] ?? 0,
        saves: saves[p.playerId] ?? 0,
        cleanSheet: (teamGoalsConceded == 0 && p.minutesPlayed >= 60)
            ? 1
            : 0,
        goalsConceded: p.minutesPlayed > 0 ? teamGoalsConceded : 0,
        minutesPlayed: p.minutesPlayed,
        rating: ratingById[p.playerId] ?? 6.0,
      ),
  ];
}

/// Upserts one match's contributions into [PlayerSeasonStats] inside
/// the caller's transaction. First appearance inserts; later ones add.
Future<void> persistMatchContributions(
  AppDatabase db, {
  required int seasonId,
  required int clubId,
  required Iterable<PlayerMatchContribution> contributions,
}) async {
  for (final c in contributions) {
    if (!c.played) continue; // unused players stay out of the table
    final existing = await (db.select(db.playerSeasonStats)
          ..where(
            (s) =>
                s.seasonId.equals(seasonId) &
                s.clubId.equals(clubId) &
                s.playerId.equals(c.playerId),
          ))
        .getSingleOrNull();
    if (existing == null) {
      await db
          .into(db.playerSeasonStats)
          .insert(
            PlayerSeasonStatsCompanion.insert(
              seasonId: seasonId,
              clubId: clubId,
              playerId: c.playerId,
              playerName: c.playerName,
              position: c.position,
              goals: Value(c.goals),
              assists: Value(c.assists),
              shots: Value(c.shots),
              saves: Value(c.saves),
              cleanSheets: Value(c.cleanSheet),
              goalsConceded: Value(c.goalsConceded),
              appearances: const Value(1),
              minutesPlayed: Value(c.minutesPlayed),
              ratingSum: Value(c.rating),
            ),
          );
    } else {
      await (db.update(db.playerSeasonStats)
            ..where((s) => s.id.equals(existing.id)))
          .write(
            PlayerSeasonStatsCompanion(
              goals: Value(existing.goals + c.goals),
              assists: Value(existing.assists + c.assists),
              shots: Value(existing.shots + c.shots),
              saves: Value(existing.saves + c.saves),
              cleanSheets: Value(existing.cleanSheets + c.cleanSheet),
              goalsConceded: Value(existing.goalsConceded + c.goalsConceded),
              appearances: Value(existing.appearances + 1),
              minutesPlayed: Value(existing.minutesPlayed + c.minutesPlayed),
              ratingSum: Value(existing.ratingSum + c.rating),
            ),
          );
    }
  }
}
