/// FCM Rivals — season engine (GDD 9, GDD 18, FR-035..FR-039).
///
/// Pure Dart: division difficulty scaling, AI club and squad generation,
/// double round-robin fixture scheduling, standings computation and
/// promotion/relegation resolution. Persistence lives in the SeasonStore;
/// this file only decides (GDD rule 4: engines stay UI-free and portable).
library;

import 'dart:math' as math;

import '../../core/domain/base_stats_generator.dart';
import '../../core/domain/players.dart';
import '../match/tactics.dart';
import '../squad/formations.dart';

/// Tunable season parameters — pre-balance placeholders (GDD rule 14).
class SeasonConfig {
  const SeasonConfig({
    this.clubsPerDivision = 20,
    this.promotionSlots = 3,
    this.relegationSlots = 3,
    this.division1TargetAverageOverall = 66,
    this.overallPerDivision = 2,
    this.aiManagerNames = defaultAiManagerNames,
    this.aiNamePrefixes = defaultAiNamePrefixes,
    this.aiNameSuffixes = defaultAiNameSuffixes,
    this.winPoints = 3,
    this.drawPoints = 1,
    this.seasonBaseReward = 10_000,
    this.rewardPerDivisionStep = 0.25,
  });

  /// Clubs per division (GDD 9.2: 20 → 38 matches).
  final int clubsPerDivision;

  /// Promotion/relegation (GDD 9.3: top 3 up, bottom 3 down).
  final int promotionSlots;
  final int relegationSlots;

  /// Difficulty scaling (GDD 9.6): division 1 sits at this average overall
  /// and each higher division adds [overallPerDivision].
  final int division1TargetAverageOverall;
  final int overallPerDivision;

  final List<String> aiManagerNames;
  final List<String> aiNamePrefixes;
  final List<String> aiNameSuffixes;

  final int winPoints;
  final int drawPoints;

  /// Season reward curve (GDD 18): base coins at division 1, growing
  /// sub-linearly with division so reward growth stays under the economic
  /// cost curve.
  final int seasonBaseReward;
  final double rewardPerDivisionStep;

  int roundsPerSeason() => 2 * (clubsPerDivision - 1);

  /// Target average overall for AI squads in [division] (GDD 9.6).
  int targetAverageOverall(int division) =>
      division1TargetAverageOverall + (division - 1) * overallPerDivision;

  static const List<String> defaultAiManagerNames = [
    'Hassan', 'Karim', 'Omar', 'Youssef', 'Mostafa', 'Ahmed', 'Tarek',
    'Sherif', 'Khaled', 'Waleed', 'Mahmoud', 'Amr', 'Nabil', 'Fathy',
    'Sami', 'Rami', 'Hany', 'Farouk', 'Galal', 'Zaki', 'Adel', 'Mourad',
  ];
  static const List<String> defaultAiNamePrefixes = [
    'Al', 'El', 'Pyramid', 'Nile', 'Delta', 'Cairo', 'Alexandria',
    'Desert', 'Oasis', 'Pharaoh', 'Sphinx', 'Lotus', 'Falcon', 'Eagle',
    'Scorpion', 'Cobra', 'Ibis', 'Storm', 'Union', 'Star',
  ];
  static const List<String> defaultAiNameSuffixes = [
    'SC', 'FC', 'United', 'Rovers', 'Athletic', 'City', 'Wanderers',
    'Dynamo', 'Olympic', 'Warriors', 'Titans', 'Legends', 'Kings',
    'Giants', 'Rangers', 'Mariners',
  ];
}

const SeasonConfig defaultSeasonConfig = SeasonConfig();

/// A generated AI club definition (GDD 9.4): identity, tactics and squad
/// for one division, before persistence.
class AiClubDefinition {
  const AiClubDefinition({
    required this.name,
    required this.managerName,
    required this.crestIndex,
    required this.formationCode,
    required this.style,
    required this.mentality,
    required this.players,
    required this.targetAverageOverall,
  });

  final String name;
  final String managerName;
  final int crestIndex;
  final String formationCode;
  final PlayingStyle style;
  final Mentality mentality;

  /// 18 synthetic players: starting XI in formation slot order plus 7
  /// bench players (a smaller squad than the user's 23 — AI clubs don't
  /// open packs).
  final List<AiPlayerDefinition> players;

  final int targetAverageOverall;
}

/// One synthetic AI player (GDD 9.4: squads are generated through the same
/// BaseStatsGenerator curve as real players — inverted from the target
/// overall — so AI teams have exact attribute parity with user squads).
class AiPlayerDefinition {
  const AiPlayerDefinition({
    required this.name,
    required this.position,
    required this.attack,
    required this.support,
    required this.defence,
    required this.goalkeeping,
  });

  final String name;
  final Position position;
  final int attack;
  final int support;
  final int defence;
  final int goalkeeping;
}

/// Fixture scheduling result for one round.
class FixturePairing {
  const FixturePairing({
    required this.round,
    required this.homeIndex,
    required this.awayIndex,
  });

  /// 0-based round (0..37).
  final int round;

  /// Index into the participating club list (0-based).
  final int homeIndex;
  final int awayIndex;
}

/// Standings entry (GDD 9.3 tiebreak: points, goal difference, goals for,
/// then name for stability).
class StandingEntry {
  const StandingEntry({
    required this.clubIndex,
    required this.clubId,
    required this.name,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.points,
    required this.position,
  });

  final int clubIndex;
  final int clubId;
  final String name;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;

  int get goalDifference => goalsFor - goalsAgainst;
  final int points;
  final int position;
}

/// Season outcome for one club (GDD 9.3).
enum SeasonOutcome { promoted, stayed, relegated }

/// The pure season engine.
class SeasonEngine {
  const SeasonEngine({this.config = defaultSeasonConfig, this.statsGenerator = const BaseStatsGenerator()});

  final SeasonConfig config;
  final BaseStatsGenerator statsGenerator;

  /// Generates 19 AI clubs (GDD 9.2) for a division, with unique names.
  List<AiClubDefinition> generateAiClubs(
    int division, {
    required math.Random random,
    int count = 19,
    Set<String>? excludeNames,
  }) {
    final target = config.targetAverageOverall(division);
    final names = <String>{...(excludeNames ?? const {})};
    final clubs = <AiClubDefinition>[];
    var prefixCursor = random.nextInt(config.aiNamePrefixes.length);
    var suffixCursor = random.nextInt(config.aiNameSuffixes.length);
    var managerCursor = random.nextInt(config.aiManagerNames.length);

    for (var i = 0; i < count; i++) {
      String name;
      var attempts = 0;
      do {
        name =
            '${config.aiNamePrefixes[prefixCursor++ % config.aiNamePrefixes.length]} '
            '${config.aiNameSuffixes[suffixCursor++ % config.aiNameSuffixes.length]}';
        attempts++;
      } while (names.contains(name) && attempts < 200);
      names.add(name);

      final formation = _pickFormation(random);
      clubs.add(AiClubDefinition(
        name: name,
        managerName:
            config.aiManagerNames[managerCursor++ % config.aiManagerNames.length],
        crestIndex: random.nextInt(8),
        formationCode: formation.code,
        style: PlayingStyle.values[random.nextInt(PlayingStyle.values.length)],
        mentality: _pickMentality(random),
        players: _generateSquad(target, formation, random),
        targetAverageOverall: target,
      ));
    }
    return clubs;
  }

  /// An AI squad: exact XI by formation slot + 7 bench players covering
  /// common positions (GDD 10.5: substitutions need bodies).
  List<AiPlayerDefinition> _generateSquad(
      int targetOverall, Formation formation, math.Random random) {
    final slots = formation.slots.map((s) => s.position).toList();
    final benchPositions = [
      Position.gk,
      Position.cb, Position.cb,
      Position.lb, Position.rb,
      Position.cm,
      Position.st,
    ];
    final all = [...slots, ...benchPositions];
    return [
      for (final position in all)
        _generatePlayer(position, targetOverall, random),
    ];
  }

  /// Inverts the BaseStatsGenerator value curve to the market value that
  /// yields [overall], then generates through the same position weights —
  /// guaranteeing AI attribute parity with real players of the same level.
  AiPlayerDefinition _generatePlayer(
      Position position, int targetOverall, math.Random random) {
    final spread = random.nextInt(7) - 3;
    final overall = (targetOverall + spread).clamp(35, 94);
    final c = statsGenerator.config;
    final doublings = (overall - c.valueAtReference) / c.ratingPerDoubling;
    final marketValue = (c.referenceValueEur * math.pow(2, doublings)).round();
    final stats = statsGenerator.generate(position, marketValue);
    return AiPlayerDefinition(
      name: _surname(random),
      position: position,
      attack: stats.attack,
      support: stats.support,
      defence: stats.defence,
      goalkeeping: stats.goalkeeping,
    );
  }

  String _surname(math.Random random) {
    const syllables = [
      'ha', 'sa', 'ma', 'ra', 'ka', 'la', 'na', 'ta', 'za', 'fa',
      'heb', 'med', 'rid', 'sam', 'ham', 'mor', 'sal', 'far', 'nas', 'eid',
    ];
    final parts = [
      syllables[random.nextInt(syllables.length)].toUpperCase(),
      for (var i = 0; i < 2; i++) syllables[random.nextInt(syllables.length)],
    ];
    return parts.join();
  }

  Formation _pickFormation(math.Random random) {
    const codes = [
      '4-4-2', '4-3-3', '4-2-3-1', '3-5-2', '5-3-2', '4-5-1', '4-1-4-1',
    ];
    return formationByCode(codes[random.nextInt(codes.length)]);
  }

  Mentality _pickMentality(math.Random random) {
    // Most AI sides play balanced-ish; extremes are rarer.
    const pool = [
      Mentality.veryDefensive, Mentality.defensive,
      Mentality.cautious, Mentality.balanced, Mentality.balanced,
      Mentality.positive, Mentality.positive,
      Mentality.attacking, Mentality.veryAttacking,
    ];
    return pool[random.nextInt(pool.length)];
  }

  /// Double round-robin schedule (FR-036: 2×(N−1) rounds) via the circle
  /// method. Team [anchorIndex] is the fixed rotation anchor; the second
  /// half mirrors the first with home/away flipped, so every pair meets
  /// once home and once away (GDD 9.2 "all other teams twice").
  List<FixturePairing> generateFixtures(int teamCount, {int anchorIndex = 0}) {
    assert(teamCount >= 2, 'need at least two teams');
    assert(teamCount % 2 == 0, 'even team count required by the circle method');
    final rounds = 2 * (teamCount - 1);
    final others = [
      for (var i = 0; i < teamCount; i++)
        if (i != anchorIndex) i
    ];
    final pairings = <FixturePairing>[];

    for (var round = 0; round < rounds; round++) {
      final isFirstHalf = round < teamCount - 1;
      // Round position within this half of the season.
      final r = round % (teamCount - 1);
      // Circle: anchor vs others[r]; others[(r+i)] vs others[(r-i)] mod.
      int mod(int x) => x % others.length;

      void add(int home, int away, {bool flip = false}) {
        pairings.add(FixturePairing(
          round: round,
          homeIndex: flip ? away : home,
          awayIndex: flip ? home : away,
        ));
      }

      // Anchor pairing: home in the first half, away in the mirror.
      add(anchorIndex, others[r], flip: !isFirstHalf);
      for (var i = 1; i <= others.length ~/ 2; i++) {
        final a = others[mod(r + i)];
        final b = others[mod(r - i)];
        // Alternate home advantage across the pair's two meetings.
        add(a, b, flip: !isFirstHalf);
      }
    }
    return pairings;
  }

  /// Standings from played results (GDD 9.3). [clubIds] and [names] are
  /// indexed by club index; [results] carries home/away indices and goals.
  List<StandingEntry> computeStandings({
    required List<int> clubIds,
    required List<String> names,
    required List<({int round, int homeIndex, int awayIndex, int homeGoals, int awayGoals})>
        results,
  }) {
    final n = clubIds.length;
    final played = List.filled(n, 0);
    final won = List.filled(n, 0);
    final drawn = List.filled(n, 0);
    final lost = List.filled(n, 0);
    final goalsFor = List.filled(n, 0);
    final goalsAgainst = List.filled(n, 0);
    final points = List.filled(n, 0);

    for (final r in results) {
      final h = r.homeIndex;
      final a = r.awayIndex;
      played[h]++;
      played[a]++;
      goalsFor[h] += r.homeGoals;
      goalsFor[a] += r.awayGoals;
      goalsAgainst[h] += r.awayGoals;
      goalsAgainst[a] += r.homeGoals;
      if (r.homeGoals > r.awayGoals) {
        won[h]++;
        lost[a]++;
        points[h] += config.winPoints;
      } else if (r.homeGoals < r.awayGoals) {
        won[a]++;
        lost[h]++;
        points[a] += config.winPoints;
      } else {
        drawn[h]++;
        drawn[a]++;
        points[h] += config.drawPoints;
        points[a] += config.drawPoints;
      }
    }

    final entries = [
      for (var i = 0; i < n; i++)
        StandingEntry(
          clubIndex: i,
          clubId: clubIds[i],
          name: names[i],
          played: played[i],
          won: won[i],
          drawn: drawn[i],
          lost: lost[i],
          goalsFor: goalsFor[i],
          goalsAgainst: goalsAgainst[i],
          points: points[i],
          position: 0,
        )
    ];
    entries.sort((a, b) {
      if (a.points != b.points) return b.points.compareTo(a.points);
      final aGd = a.goalDifference;
      final bGd = b.goalDifference;
      if (aGd != bGd) return bGd.compareTo(aGd);
      if (a.goalsFor != b.goalsFor) return b.goalsFor.compareTo(a.goalsFor);
      return a.name.compareTo(b.name);
    });
    return [
      for (var i = 0; i < entries.length; i++)
        StandingEntry(
          clubIndex: entries[i].clubIndex,
          clubId: entries[i].clubId,
          name: entries[i].name,
          played: entries[i].played,
          won: entries[i].won,
          drawn: entries[i].drawn,
          lost: entries[i].lost,
          goalsFor: entries[i].goalsFor,
          goalsAgainst: entries[i].goalsAgainst,
          points: entries[i].points,
          position: i + 1,
        )
    ];
  }

  /// Outcome for a final [position] (GDD 9.3: 1–3 promote, 18–20 relegate).
  SeasonOutcome outcomeForPosition(int position) {
    if (position <= config.promotionSlots) return SeasonOutcome.promoted;
    if (position > config.clubsPerDivision - config.relegationSlots) {
      return SeasonOutcome.relegated;
    }
    return SeasonOutcome.stayed;
  }

  /// The user club's next division after a season. Division 1 is the
  /// starting division and higher numbers are progressively harder
  /// (GDD 9.1), so promotion climbs the ladder and relegation descends
  /// with a floor at division 1.
  int nextDivisionFor(int division, SeasonOutcome outcome) {
    switch (outcome) {
      case SeasonOutcome.promoted:
        return division + 1;
      case SeasonOutcome.relegated:
        return division > 1 ? division - 1 : 1;
      case SeasonOutcome.stayed:
        return division;
    }
  }

  /// Position-based season coin rewards (GDD 18). Pack grants are decided
  /// by the store (they need persistence context).
  int seasonRewardCoins({required int division, required int position}) {
    final divisionFactor = 1.0 + config.rewardPerDivisionStep * (division - 1);
    final base = config.seasonBaseReward * divisionFactor;
    final multiplier = switch (outcomeForPosition(position)) {
      SeasonOutcome.promoted => position == 1 ? 2.0 : 1.5,
      SeasonOutcome.relegated => 0.5,
      SeasonOutcome.stayed => (1.0 - (position - 4) * 0.03).clamp(0.6, 1.0),
    };
    return (base * multiplier).round();
  }
}
