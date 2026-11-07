/// FCM Rivals — match reporting (GDD 13, GDD 14, FR-031..FR-033).
///
/// Live statistics and player ratings are all derived from the same
/// recorded MatchEvents (GDD 26.4) — never from side calculations, so
/// they can never contradict the engine (GDD 13.1).
///
/// The commentary data model and its construction live in the sibling
/// `commentary.dart` (task `2026-11-05_app-structure_split-commentary`)
/// and are re-exported here, so consumer imports never churn.
library;

import '../../core/domain/players.dart';
import 'match_engine.dart';

export 'commentary.dart';

/// Per-team match statistics (GDD 13.2), accumulated from events.
///
/// BALANCE-HARNESS ONLY: the momentum bar replaced the stats UI (the
/// live strip and the post-match team-statistics table are gone), so
/// nothing in the app surfaces these numbers any more — [computeStats]
/// stays for the GDD 30–33 simulation & balance harness and its tests.
class TeamMatchStats {
  TeamMatchStats();

  int possessionMinutes = 0;
  int passesAttempted = 0;
  int passesCompleted = 0;
  int shots = 0;
  int shotsOnTarget = 0;
  int goals = 0;
  int assists = 0;
  double xg = 0;
  int bigChances = 0;
  int saves = 0;
  int corners = 0;
  int offsides = 0;
  int fouls = 0;
  int foulsWon = 0;
  int injuries = 0;
  int yellowCards = 0;
  int redCards = 0;
  int tackles = 0;
  int interceptions = 0;
  int crosses = 0;
  int dribbles = 0;
  int penaltiesAwarded = 0;

  double get passAccuracy =>
      passesAttempted == 0 ? 0 : passesCompleted / passesAttempted;

  double get averageXg => shots == 0 ? 0 : xg / shots;
}

/// Per-minute weighted pressure totals for both sides (index 0 = minute
/// 1), shared by [computeMomentum] and [computeMomentumSeries] so the
/// scalar reading and the timeline can never diverge (GDD 13.1).
///
/// Inputs are the events themselves, weighted by how loudly each one
/// says "this team is doing the pushing": a shot is worth more than a
/// corner, a big chance or a goal weighs heaviest, plain possession
/// minutes carry a small share so the bar keeps breathing in quiet
/// spells, and winning the ball back counts a little too — pressing is
/// momentum.
({List<double> home, List<double> away, int lastMinute}) _momentumPressure(
  List<MatchEvent> events, {
  required int homeTeamId,
  required int awayTeamId,
}) {
  // Weights: how strongly each event shouts "we are on top".
  const shotW = 4.0;
  const bigW = 6.0; // big chance / penalty won
  const goalW = 10.0;
  const cardAgainstW = 3.0; // a booking means the OTHER side pressed
  const cornerW = 2.0;
  const foulWonW = 1.0;
  const possW = 1.0;
  const pressW = 0.5; // winning the ball back

  var lastMinute = 0;
  for (final e in events) {
    if (e.minute > lastMinute) lastMinute = e.minute;
  }
  final home = List<double>.filled(lastMinute, 0);
  final away = List<double>.filled(lastMinute, 0);

  void credit(MatchEvent e, double w) {
    if (w <= 0 || lastMinute == 0) return;
    final i = e.minute.clamp(1, lastMinute) - 1;
    if (e.teamId == homeTeamId) {
      home[i] += w;
    } else {
      away[i] += w;
    }
  }

  // Credits [w] to the OPPONENT of the event's side — the press that
  // won the ball, the foul drawn, the booking the pressure forced.
  void creditOpponent(MatchEvent e, double w) {
    if (w <= 0 || lastMinute == 0) return;
    final i = e.minute.clamp(1, lastMinute) - 1;
    if (e.teamId == homeTeamId) {
      away[i] += w;
    } else {
      home[i] += w;
    }
  }

  for (final e in events) {
    switch (e.type) {
      // Possession and passes are one share per minute held.
      case MatchEventType.possession:
      case MatchEventType.passMove:
        credit(e, possW);
      // Dispossessed: e.teamId is the side that LOST the ball — the
      // other side's press gets the credit.
      case MatchEventType.dispossessed:
        creditOpponent(e, pressW);
      case MatchEventType.corner:
        credit(e, cornerW);
      // Foul: e.teamId is the fouler — the fouled side gets the share.
      case MatchEventType.foul:
        creditOpponent(e, foulWonW);
      case MatchEventType.penaltyAwarded:
      case MatchEventType.shot:
        var w = e.type == MatchEventType.penaltyAwarded ? bigW : shotW;
        if (e.metadata['isBigChance'] == true) w = bigW;
        credit(e, w);
      case MatchEventType.goal:
        credit(e, goalW);
      // A card is usually shown to the side under the cosh.
      case MatchEventType.card:
        creditOpponent(e, cardAgainstW);
      // Structural moments carry no momentum signal.
      case MatchEventType.kickoff:
      case MatchEventType.halfTime:
      case MatchEventType.fullTime:
      case MatchEventType.injury:
      case MatchEventType.offside:
      case MatchEventType.substitution:
      case MatchEventType.tacticalChange:
      case MatchEventType.liveAction:
        break;
    }
  }
  return (home: home, away: away, lastMinute: lastMinute);
}

/// Live momentum share 0..1 for the HOME side over the trailing
/// [window] minutes of pressure (default ~15 minutes — the "who is on
/// top RIGHT NOW" reading a pundit gives, not a whole-match average).
///
/// Events age out of the window, so a red-hot start fades if the other
/// side takes over. Before any weighted events the match is dead level:
/// exactly 0.5, the bar's kick-off 50/50 split.
double computeMomentum(
  List<MatchEvent> events, {
  required int homeTeamId,
  required int awayTeamId,
  int window = 15,
}) {
  final pressure = _momentumPressure(
    events,
    homeTeamId: homeTeamId,
    awayTeamId: awayTeamId,
  );
  if (pressure.lastMinute == 0) return 0.5;
  final start = pressure.lastMinute - window < 0
      ? 0
      : pressure.lastMinute - window;
  var home = 0.0;
  var away = 0.0;
  for (var i = start; i < pressure.lastMinute; i++) {
    home += pressure.home[i];
    away += pressure.away[i];
  }
  if (home + away <= 0) return 0.5;
  return home / (home + away);
}

/// Momentum timeline for the live match (GDD 13.2): one HOME momentum
/// share (0..1, 0.5 = dead level) per minute played, index 0 = minute 1.
/// Each minute carries the same trailing-[window] reading
/// [computeMomentum] gives, ending at that minute — the momentum bar
/// draws a vertical line per entry, rising ABOVE the baseline for home
/// pressure and hanging BELOW it for away pressure, so the match flow
/// and the team on top read at a glance. Empty list before any minute
/// has been played.
List<double> computeMomentumSeries(
  List<MatchEvent> events, {
  required int homeTeamId,
  required int awayTeamId,
  int window = 15,
}) {
  final pressure = _momentumPressure(
    events,
    homeTeamId: homeTeamId,
    awayTeamId: awayTeamId,
  );
  if (pressure.lastMinute == 0) return const [];
  final series = List<double>.filled(pressure.lastMinute, 0.5);
  var home = 0.0;
  var away = 0.0;
  for (var m = 0; m < pressure.lastMinute; m++) {
    home += pressure.home[m];
    away += pressure.away[m];
    final drop = m - window;
    if (drop >= 0) {
      home -= pressure.home[drop];
      away -= pressure.away[drop];
    }
    final total = home + away;
    series[m] = total <= 0 ? 0.5 : home / total;
  }
  return series;
}

/// Derives per-team statistics from the event timeline (FR-032).
MatchStatsReport computeStats(
  List<MatchEvent> events, {
  required int homeTeamId,
  required int awayTeamId,
}) {
  final home = TeamMatchStats();
  final away = TeamMatchStats();

  TeamMatchStats of(MatchEvent e) => e.teamId == homeTeamId ? home : away;
  TeamMatchStats other(MatchEvent e) => e.teamId == homeTeamId ? away : home;

  for (final e in events) {
    final s = of(e);
    switch (e.type) {
      case MatchEventType.possession:
        s.possessionMinutes++;
        // Every counted attempt needs its completions: a possession-kept
        // pocket completes its passes at the team's real accuracy, not
        // zero (the old asymmetry dragged reported accuracy to ~15%).
        s.passesAttempted += (e.metadata['passesAttempted'] as int? ?? 0);
        s.passesCompleted += (e.metadata['passesCompleted'] as int? ?? 0);
      case MatchEventType.passMove:
        s.passesAttempted += (e.metadata['passesAttempted'] as int? ?? 0);
        s.passesCompleted += (e.metadata['passesCompleted'] as int? ?? 0);
        if (e.metadata['cross'] == true) s.crosses++;
        if (e.metadata['dribble'] == true) s.dribbles++;
      case MatchEventType.dispossessed:
        other(e).tackles += e.metadata['tackle'] == true ? 1 : 0;
        other(e).interceptions += e.metadata['interception'] == true ? 1 : 0;
      case MatchEventType.foul:
        s.fouls++;
        other(e).foulsWon++;
      case MatchEventType.offside:
        s.offsides++;
      case MatchEventType.corner:
        s.corners++;
      case MatchEventType.penaltyAwarded:
        s.penaltiesAwarded++;
      case MatchEventType.card:
        if (e.metadata['card'] == 'red') {
          s.redCards++;
        } else {
          s.yellowCards++;
        }
      case MatchEventType.injury:
        s.injuries++;
      case MatchEventType.shot:
        s.shots++;
        s.xg += e.xg ?? 0;
        if (e.metadata['isBigChance'] == true) s.bigChances++;
        switch (e.shotOutcome) {
          case ShotOutcome.goal:
          case ShotOutcome.saved:
            s.shotsOnTarget++;
          case ShotOutcome.offTarget:
          case ShotOutcome.blocked:
            break;
          case null:
            break;
        }
        if (e.shotOutcome == ShotOutcome.saved) other(e).saves++;
      case MatchEventType.goal:
        s.goals++;
        if (e.secondaryPlayerId != null) s.assists++;
      case MatchEventType.kickoff:
      case MatchEventType.halfTime:
      case MatchEventType.fullTime:
      case MatchEventType.substitution:
      case MatchEventType.tacticalChange:
      case MatchEventType.liveAction:
        break;
    }
  }
  return MatchStatsReport(home: home, away: away);
}

class MatchStatsReport {
  const MatchStatsReport({required this.home, required this.away});

  final TeamMatchStats home;
  final TeamMatchStats away;

  /// Possession percentage estimate from possession-minute shares.
  double possessionPercent(TeamMatchStats team) {
    final total = home.possessionMinutes + away.possessionMinutes;
    if (total == 0) return 50;
    return 100 * team.possessionMinutes / total;
  }
}

/// Individual match rating inputs (GDD 14 table).
class PlayerMatchRating {
  const PlayerMatchRating({
    required this.playerId,
    required this.name,
    required this.position,
    required this.rating,
    required this.minutesPlayed,
    required this.goals,
    required this.assists,
    required this.saves,
    required this.goalsConceded,
    required this.shots,
    required this.keyPasses,
    required this.tackles,
    required this.interceptions,
    required this.yellowCards,
    required this.redCard,
    required this.teamGoals,
    required this.teamGoalsConceded,
  });

  final int playerId;
  final String name;
  final Position position;
  final double rating;
  final int minutesPlayed;

  final int goals;
  final int assists;
  final int saves;
  final int goalsConceded;

  final int shots;
  final int keyPasses;
  final int tackles;
  final int interceptions;
  final int yellowCards;
  final bool redCard;

  final int teamGoals;
  final int teamGoalsConceded;

  bool get played => minutesPlayed > 0;
}

/// Position-sensitive rating weights (GDD 14). Each event category is
/// worth a different amount of rating delta per position group.
const Map<Position, Map<String, double>> _ratingWeights = {
  Position.gk: {
    'save': 0.22,
    'goalConceded': -0.18,
    'cleanSheet': 0.35,
    'goal': 0.5,
    'assist': 0.2,
    'pass': 0.004,
    'tackle': 0.05,
    'interception': 0.05,
    'shot': 0.02,
    'keyPass': 0.05,
    'foul': -0.06,
    'yellow': -0.25,
    'red': -1.4,
    'teamGoal': 0.06,
    'teamConceded': -0.08,
  },
  Position.cb: {
    'save': 0.0,
    'goalConceded': -0.10,
    'cleanSheet': 0.30,
    'goal': 0.5,
    'assist': 0.3,
    'pass': 0.006,
    'tackle': 0.16,
    'interception': 0.14,
    'shot': 0.02,
    'keyPass': 0.06,
    'foul': -0.08,
    'yellow': -0.3,
    'red': -1.4,
    'teamGoal': 0.05,
    'teamConceded': -0.12,
  },
  Position.lb: {
    'save': 0.0,
    'goalConceded': -0.09,
    'cleanSheet': 0.24,
    'goal': 0.5,
    'assist': 0.4,
    'pass': 0.007,
    'tackle': 0.15,
    'interception': 0.12,
    'shot': 0.02,
    'keyPass': 0.08,
    'foul': -0.07,
    'yellow': -0.3,
    'red': -1.4,
    'teamGoal': 0.05,
    'teamConceded': -0.10,
  },
  Position.rb: {
    'save': 0.0,
    'goalConceded': -0.09,
    'cleanSheet': 0.24,
    'goal': 0.5,
    'assist': 0.4,
    'pass': 0.007,
    'tackle': 0.15,
    'interception': 0.12,
    'shot': 0.02,
    'keyPass': 0.08,
    'foul': -0.07,
    'yellow': -0.3,
    'red': -1.4,
    'teamGoal': 0.05,
    'teamConceded': -0.10,
  },
  Position.cdm: {
    'save': 0.0,
    'goalConceded': -0.08,
    'cleanSheet': 0.20,
    'goal': 0.5,
    'assist': 0.35,
    'pass': 0.008,
    'tackle': 0.18,
    'interception': 0.16,
    'shot': 0.03,
    'keyPass': 0.08,
    'foul': -0.08,
    'yellow': -0.3,
    'red': -1.4,
    'teamGoal': 0.05,
    'teamConceded': -0.09,
  },
  Position.cm: {
    'save': 0.0,
    'goalConceded': -0.06,
    'cleanSheet': 0.12,
    'goal': 0.55,
    'assist': 0.45,
    'pass': 0.010,
    'tackle': 0.12,
    'interception': 0.12,
    'shot': 0.05,
    'keyPass': 0.10,
    'foul': -0.07,
    'yellow': -0.28,
    'red': -1.4,
    'teamGoal': 0.06,
    'teamConceded': -0.06,
  },
  Position.cam: {
    'save': 0.0,
    'goalConceded': -0.04,
    'cleanSheet': 0.06,
    'goal': 0.6,
    'assist': 0.55,
    'pass': 0.010,
    'tackle': 0.06,
    'interception': 0.06,
    'shot': 0.08,
    'keyPass': 0.14,
    'foul': -0.06,
    'yellow': -0.26,
    'red': -1.4,
    'teamGoal': 0.07,
    'teamConceded': -0.04,
  },
  Position.lm: {
    'save': 0.0,
    'goalConceded': -0.05,
    'cleanSheet': 0.08,
    'goal': 0.55,
    'assist': 0.5,
    'pass': 0.009,
    'tackle': 0.08,
    'interception': 0.08,
    'shot': 0.06,
    'keyPass': 0.12,
    'foul': -0.06,
    'yellow': -0.26,
    'red': -1.4,
    'teamGoal': 0.06,
    'teamConceded': -0.05,
  },
  Position.rm: {
    'save': 0.0,
    'goalConceded': -0.05,
    'cleanSheet': 0.08,
    'goal': 0.55,
    'assist': 0.5,
    'pass': 0.009,
    'tackle': 0.08,
    'interception': 0.08,
    'shot': 0.06,
    'keyPass': 0.12,
    'foul': -0.06,
    'yellow': -0.26,
    'red': -1.4,
    'teamGoal': 0.06,
    'teamConceded': -0.05,
  },
  Position.lw: {
    'save': 0.0,
    'goalConceded': -0.03,
    'cleanSheet': 0.04,
    'goal': 0.6,
    'assist': 0.55,
    'pass': 0.008,
    'tackle': 0.04,
    'interception': 0.04,
    'shot': 0.09,
    'keyPass': 0.14,
    'foul': -0.05,
    'yellow': -0.26,
    'red': -1.4,
    'teamGoal': 0.07,
    'teamConceded': -0.03,
  },
  Position.rw: {
    'save': 0.0,
    'goalConceded': -0.03,
    'cleanSheet': 0.04,
    'goal': 0.6,
    'assist': 0.55,
    'pass': 0.008,
    'tackle': 0.04,
    'interception': 0.04,
    'shot': 0.09,
    'keyPass': 0.14,
    'foul': -0.05,
    'yellow': -0.26,
    'red': -1.4,
    'teamGoal': 0.07,
    'teamConceded': -0.03,
  },
  Position.st: {
    'save': 0.0,
    'goalConceded': -0.02,
    'cleanSheet': 0.02,
    'goal': 0.7,
    'assist': 0.45,
    'pass': 0.005,
    'tackle': 0.03,
    'interception': 0.03,
    'shot': 0.10,
    'keyPass': 0.12,
    'foul': -0.05,
    'yellow': -0.24,
    'red': -1.4,
    'teamGoal': 0.08,
    'teamConceded': -0.02,
  },
};

/// Computes individual match ratings from the event timeline and the
/// final player states (FR-033, GDD 14). Baseline 6.0, clamped 1.0..10.0.
List<PlayerMatchRating> computePlayerRatings({
  required List<MatchEvent> events,
  required List<MatchPlayer> players,
  required int teamId,
  required int teamGoals,
  required int teamGoalsConceded,
}) {
  final goals = <int, int>{};
  final assists = <int, int>{};
  final shots = <int, int>{};
  final keyPasses = <int, int>{};
  final tackles = <int, int>{};
  final interceptions = <int, int>{};
  final saves = <int, int>{};
  final fouls = <int, int>{};
  final yellows = <int, int>{};
  final reds = <int>{};
  final passes = <int, int>{};

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
        if (e.secondaryPlayerId != null) {
          keyPasses[e.secondaryPlayerId!] =
              (keyPasses[e.secondaryPlayerId!] ?? 0) + 1;
        }
        if (e.shotOutcome == ShotOutcome.saved) {
          final gkId = e.metadata['gkPlayerId'] as int?;
          if (gkId != null) saves[gkId] = (saves[gkId] ?? 0) + 1;
        }
      case MatchEventType.dispossessed:
        if (e.primaryPlayerId != null) {
          if (e.metadata['tackle'] == true) {
            tackles[e.primaryPlayerId!] =
                (tackles[e.primaryPlayerId!] ?? 0) + 1;
          } else {
            interceptions[e.primaryPlayerId!] =
                (interceptions[e.primaryPlayerId!] ?? 0) + 1;
          }
        }
      case MatchEventType.foul:
        if (e.primaryPlayerId != null) {
          fouls[e.primaryPlayerId!] = (fouls[e.primaryPlayerId!] ?? 0) + 1;
        }
      case MatchEventType.card:
        if (e.metadata['card'] == 'red') {
          if (e.primaryPlayerId != null) reds.add(e.primaryPlayerId!);
        } else if (e.primaryPlayerId != null) {
          yellows[e.primaryPlayerId!] = (yellows[e.primaryPlayerId!] ?? 0) + 1;
        }
      case MatchEventType.passMove:
        if (e.primaryPlayerId != null) {
          passes[e.primaryPlayerId!] = (passes[e.primaryPlayerId!] ?? 0) + 1;
        }
      default:
        break;
    }
  }

  final ratings = <PlayerMatchRating>[];
  for (final p in players) {
    final w = _ratingWeights[p.position]!;
    var score = 6.0;
    score += (goals[p.playerId] ?? 0) * w['goal']!;
    score += (assists[p.playerId] ?? 0) * w['assist']!;
    score += (saves[p.playerId] ?? 0) * w['save']!;
    score += (shots[p.playerId] ?? 0) * w['shot']!;
    score += (keyPasses[p.playerId] ?? 0) * w['keyPass']!;
    score += (tackles[p.playerId] ?? 0) * w['tackle']!;
    score += (interceptions[p.playerId] ?? 0) * w['interception']!;
    score += (passes[p.playerId] ?? 0) * w['pass']!;
    score += (fouls[p.playerId] ?? 0) * w['foul']!;
    score += (yellows[p.playerId] ?? 0) * w['yellow']!;
    if (reds.contains(p.playerId)) score += w['red']!;
    score += teamGoals * w['teamGoal']!;
    score += teamGoalsConceded * w['teamConceded']!;
    // Goalkeepers feel clean sheets; outfield defenders get a smaller
    // bonus (GDD 14 CB row: defensive actions and errors).
    final isKeeper = p.position == Position.gk;
    final concededWhilePlaying = teamGoalsConceded > 0 && p.minutesPlayed > 0;
    if (teamGoalsConceded == 0 && p.minutesPlayed >= 60) {
      score += isKeeper ? w['cleanSheet']! : w['cleanSheet']! * 0.6;
    }
    if (concededWhilePlaying) {
      score +=
          teamGoalsConceded *
          (isKeeper ? w['goalConceded']! : w['goalConceded']! * 0.7);
    }
    if (p.minutesPlayed == 0) {
      // Unused players keep the neutral baseline.
      score = 6.0;
    }
    ratings.add(
      PlayerMatchRating(
        playerId: p.playerId,
        name: p.name,
        position: p.position,
        rating: score.clamp(1.0, 10.0).toDouble(),
        minutesPlayed: p.minutesPlayed,
        goals: goals[p.playerId] ?? 0,
        assists: assists[p.playerId] ?? 0,
        saves: saves[p.playerId] ?? 0,
        goalsConceded: p.minutesPlayed > 0 && isKeeper ? teamGoalsConceded : 0,
        shots: shots[p.playerId] ?? 0,
        keyPasses: keyPasses[p.playerId] ?? 0,
        tackles: tackles[p.playerId] ?? 0,
        interceptions: interceptions[p.playerId] ?? 0,
        yellowCards: yellows[p.playerId] ?? 0,
        redCard: reds.contains(p.playerId),
        teamGoals: teamGoals,
        teamGoalsConceded: teamGoalsConceded,
      ),
    );
  }
  ratings.sort((a, b) => b.rating.compareTo(a.rating));
  return ratings;
}
