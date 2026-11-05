/// FCM Rivals — season data models (extracted from
/// `season_store.dart`, app-structure review task
/// `2026-11-05_app-structure_split-season-models`): the season error
/// type and the summary / fixture / completion / AI-squad snapshots
/// the store produces and the UI consumes. Pure relocation.
library;

import '../../core/database/app_database.dart';
import '../match/match_engine.dart' show MatchPlayer;

/// Season-specific errors.
class SeasonException implements Exception {
  const SeasonException(this.message);
  final String message;
  @override
  String toString() => 'SeasonException: $message';
}

/// Snapshot of the active (or last) season for the UI.
class SeasonSummary {
  const SeasonSummary({
    required this.seasonId,
    required this.division,
    required this.ordinal,
    required this.status,
    required this.roundsPlayed,
    required this.roundsTotal,
    this.finalPosition,
    this.outcome,
  });

  final int seasonId;
  final int division;
  final int ordinal;

  /// active | completed.
  final String status;
  final int roundsPlayed;
  final int roundsTotal;
  final int? finalPosition;
  final String? outcome;

  bool get isCompleted => status == 'completed';
}

/// The user's next fixture, if any.
class NextFixture {
  const NextFixture({
    required this.fixtureId,
    required this.round,
    required this.isHome,
    required this.opponentClubId,
    required this.opponentName,
  });

  final int fixtureId;
  final int round;

  /// Whether the user hosts this fixture.
  final bool isHome;
  final int opponentClubId;
  final String opponentName;
}

/// Season completion outcome for the user (GDD 18 rewards).
class SeasonCompletion {
  const SeasonCompletion({
    required this.seasonId,
    required this.division,
    required this.finalPosition,
    required this.outcome,
    required this.nextDivision,
    required this.rewardCoins,
    required this.rewardPackCategory,
  });

  final int seasonId;
  final int division;
  final int finalPosition;

  /// promoted | stayed | relegated.
  final String outcome;
  final int nextDivision;
  final int rewardCoins;

  /// GDD 18 pack reward: 'premium' for 1st, 'normal' for 2nd–3rd,
  /// 'choice' for other promotions, null when staying/relegated.
  final String? rewardPackCategory;
}

/// AI opponent squad loaded for a fixture.
class AiOpponentSquad {
  const AiOpponentSquad({
    required this.club,
    required this.starters,
    required this.bench,
  });

  final Club club;
  final List<MatchPlayer> starters;
  final List<MatchPlayer> bench;
}
