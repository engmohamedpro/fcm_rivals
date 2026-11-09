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
import '../squad/squad_engine.dart';
import 'season_ai_models.dart';

export 'season_ai_models.dart';

/// Tunable season parameters — pre-balance placeholders (GDD rule 14).
class SeasonConfig {
  const SeasonConfig({
    this.clubsPerDivision = 20,
    this.promotionSlots = 3,
    this.relegationSlots = 3,
    // Division 1 is the LOWEST league and must be winnable by a fresh
    // club (the starting squad sits around 52 OVR), so its AI squads
    // target ~54 — a gentle first season, not a wall. The previous 66
    // made every Division 1 side fourteen points stronger than the
    // player's first team.
    this.division1TargetAverageOverall = 54,
    // Three points per division: promotion steps up the ladder by
    // roughly one season of pack-driven squad growth, so divisions get
    // visibly harder but never hop more than a good transfer window.
    this.overallPerDivision = 3,
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
    'Hassan',
    'Karim',
    'Omar',
    'Youssef',
    'Mostafa',
    'Ahmed',
    'Tarek',
    'Sherif',
    'Khaled',
    'Waleed',
    'Mahmoud',
    'Amr',
    'Nabil',
    'Fathy',
    'Sami',
    'Rami',
    'Hany',
    'Farouk',
    'Galal',
    'Zaki',
    'Adel',
    'Mourad',
  ];
  static const List<String> defaultAiNamePrefixes = [
    'Al',
    'El',
    'Pyramid',
    'Nile',
    'Delta',
    'Cairo',
    'Alexandria',
    'Desert',
    'Oasis',
    'Pharaoh',
    'Sphinx',
    'Lotus',
    'Falcon',
    'Eagle',
    'Scorpion',
    'Cobra',
    'Ibis',
    'Storm',
    'Union',
    'Star',
  ];
  static const List<String> defaultAiNameSuffixes = [
    'SC',
    'FC',
    'United',
    'Rovers',
    'Athletic',
    'City',
    'Wanderers',
    'Dynamo',
    'Olympic',
    'Warriors',
    'Titans',
    'Legends',
    'Kings',
    'Giants',
    'Rangers',
    'Mariners',
  ];
}

const SeasonConfig defaultSeasonConfig = SeasonConfig();

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
  const SeasonEngine({
    this.config = defaultSeasonConfig,
    this.statsGenerator = const BaseStatsGenerator(),
  });

  final SeasonConfig config;
  final BaseStatsGenerator statsGenerator;

  /// Generates 19 AI clubs (GDD 9.2) for a division, with unique names.
  ///
  /// When [pool] carries the imported real-player database, every squad is
  /// drawn from REAL players banded around the division's target overall
  /// (GDD 9.6 difficulty ladder — Division 1 is the easiest), each player
  /// usable by at most one club per division and never one the user owns
  /// ([excludePlayerIds]). A club whose positions cannot be filled from
  /// the pool (tiny test datasets) falls back to synthetic generation
  /// through the same attribute curve, so behavior degrades gracefully.
  List<AiClubDefinition> generateAiClubs(
    int division, {
    required math.Random random,
    int count = 19,
    Set<String>? excludeNames,
    List<AiPoolPlayer>? pool,
    Set<int> excludePlayerIds = const {},
  }) {
    final target = config.targetAverageOverall(division);
    final names = <String>{...(excludeNames ?? const {})};
    final clubs = <AiClubDefinition>[];
    var prefixCursor = random.nextInt(config.aiNamePrefixes.length);
    var suffixCursor = random.nextInt(config.aiNameSuffixes.length);
    var managerCursor = random.nextInt(config.aiManagerNames.length);
    final tracker = pool == null
        ? null
        : _PoolTracker(pool: pool, exclude: excludePlayerIds, random: random);
    // The lift's structural gate, computed ONCE from the pristine pool
    // before any club consumes it: whether the division's target is
    // reachable without lifting at all.
    final poolSuppliesTarget = _poolSuppliesTarget(target, tracker);

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
      // RNG consumption order matches the pre-lift parent EXACTLY
      // (review attempt 1, failure 1) — the parent had a hybrid order:
      // the pool-path squad is drawn in this local BEFORE the crest and
      // mentality draws, while the synthetic fallback runs inside the
      // constructor's argument list AFTER them. Both paths are
      // reproduced verbatim; only the lift is added at the end.
      final realSquad = tracker == null
          ? null
          : _generateRealSquad(formation, target, tracker);
      clubs.add(
        AiClubDefinition(
          name: name,
          managerName: config
              .aiManagerNames[managerCursor++ % config.aiManagerNames.length],
          crestIndex: random.nextInt(8),
          formationCode: formation.code,
          tactics: const TeamTactics(),
          mentality: _pickMentality(random),
          // Past the dataset ceiling the ladder keeps climbing: squads
          // below the division target are lifted onto it with the shared
          // +N% upgrade math (GDD 9.6, owner decision 2026-11-09). The
          // gate is structural (see _liftToTarget): divisions whose
          // ceiling the generator can reach are never lifted.
          players: _liftToTarget(
            realSquad ?? _generateSquad(target, formation, random),
            target,
            lift: !poolSuppliesTarget,
          ),
          targetAverageOverall: target,
        ),
      );
    }
    return clubs;
  }

  /// The synthetic generator's hard attribute ceiling (review attempt 1,
  /// failure 2): _generatePlayer clamps every overall at 94, so any
  /// target above ~91 (94 minus the ±3 spread) is unreachable by
  /// generation alone — the ladder has genuinely hit the dataset
  /// ceiling and the lift is the only way forward.
  static const int _syntheticCeiling = 94;

  /// Whether the division [target] is one the generator can supply
  /// WITHOUT the lift (review attempt 1, failure 2). Structural, not
  /// variance-based. Synthetic path: supplies while the target sits at
  /// or below the 94 clamp. Pool path: judged from the PRISTINE pool
  /// (every position has a player in the natural ±3 band of the target,
  /// ignoring what generation has already consumed) — mid-generation
  /// band exhaustion is normal banding-widening for a 19-club division,
  /// NOT a ceiling. Variance shortfalls at supplied divisions (gaps of
  /// 1.6–3.0 points occur at division 1 itself) never lift: those clubs
  /// stay exactly as generated, byte-identical to pre-lift behavior.
  bool _poolSuppliesTarget(int target, _PoolTracker? tracker) {
    if (tracker == null) return target <= _syntheticCeiling;
    return tracker.pristinePoolSupplies(target);
  }

  /// Lifts a whole club onto the division [target] average overall with a
  /// uniform upgrade level (GDD 9.6, owner decision 2026-11-09): when the
  /// division's target exceeds what the generator can supply (see
  /// [_poolSuppliesTarget] — the dataset ceiling), every player's four
  /// attributes become `upgradedValue(attr, N)` with
  /// N = ceil((target / avg − 1) × 100). Per-club N: weaker bases get a
  /// bigger lift, every club lands on the target — the same
  /// band-around-target intent the pool tracker has. Divisions the
  /// generator supplies are returned UNCHANGED, whatever the per-club
  /// variance (byte-identical to pre-lift generation). Deterministic:
  /// derives from the already-seeded squad, no new RNG draws.
  List<AiPlayerDefinition> _liftToTarget(
    List<AiPlayerDefinition> squad,
    int target, {
    required bool lift,
  }) {
    if (squad.isEmpty || !lift) return squad;
    // Average over the outfield attributes (ATT/SUP/DEF) — the same
    // three the generation tests and the existing near-target band
    // measure. Counting GK (0 for every outfield player) or the
    // keeper's own 0-ATT would read a synthetic XI ~12 points below
    // its true strength and misread the gap.
    var sum = 0.0;
    for (final p in squad) {
      sum += (p.attack + p.support + p.defence) / 3;
    }
    final avg = sum / squad.length;
    if (avg <= 0 || avg >= target) return squad;
    final level = ((target / avg - 1) * 100).ceil();
    if (level <= 0) return squad;
    return [
      for (final p in squad)
        AiPlayerDefinition(
          name: p.name,
          position: p.position,
          attack: upgradedValue(p.attack, level),
          support: upgradedValue(p.support, level),
          defence: upgradedValue(p.defence, level),
          goalkeeping: upgradedValue(p.goalkeeping, level),
          realPlayerId: p.realPlayerId,
          upgradeLevel: level,
        ),
    ];
  }

  /// Draws a full 18-man squad of REAL pool players banded around
  /// [targetOverall]: the starting XI by formation slot positions plus
  /// seven bench players covering the common positions (GDD 10.5:
  /// substitutions need bodies). Returns null when any needed position
  /// has no candidate left in the pool — the caller then generates a
  /// synthetic squad instead.
  List<AiPlayerDefinition>? _generateRealSquad(
    Formation formation,
    int targetOverall,
    _PoolTracker tracker,
  ) {
    final positions = [
      ...formation.slots.map((s) => s.position),
      ..._benchPositions,
    ];
    final squad = <AiPlayerDefinition>[];
    for (final position in positions) {
      final p = tracker.take(position, targetOverall);
      if (p == null) return null;
      squad.add(
        AiPlayerDefinition(
          name: p.name,
          position: p.position,
          attack: p.attack,
          support: p.support,
          defence: p.defence,
          goalkeeping: p.goalkeeping,
          realPlayerId: p.playerId,
        ),
      );
    }
    return squad;
  }

  /// An AI squad: exact XI by formation slot + 7 bench players covering
  /// common positions (GDD 10.5: substitutions need bodies).
  List<AiPlayerDefinition> _generateSquad(
    int targetOverall,
    Formation formation,
    math.Random random,
  ) {
    final slots = formation.slots.map((s) => s.position).toList();
    final all = [...slots, ..._benchPositions];
    return [
      for (final position in all)
        _generatePlayer(position, targetOverall, random),
    ];
  }

  static const List<Position> _benchPositions = [
    Position.gk,
    Position.cb,
    Position.cb,
    Position.lb,
    Position.rb,
    Position.cm,
    Position.st,
  ];

  /// Picks the AI club's starting XI and bench from its full squad at
  /// CURRENT condition (GDD 11 rotation, GDD 9.4 persisted squads):
  /// every formation slot takes the best unassigned player by
  /// compatibility × slot-role rating × fitness, where fitness discounts
  /// tired bodies — so a fresh backup displaces a tired starter only
  /// when the quality gap is small, and a clearly better player still
  /// starts unless he is genuinely exhausted. AI clubs rotate when
  /// fitness demands it, not every match. Starters return in formation
  /// slot order; the remaining players form the bench (GDD 10.5).
  ({List<AiSquadPlayer> starters, List<AiSquadPlayer> bench}) pickAiLineup(
    List<AiSquadPlayer> squad,
    String formationCode,
  ) {
    final formation = formationByCode(formationCode);
    final available = [...squad];
    final assigned = List<AiSquadPlayer?>.filled(formation.slots.length, null);

    // Rarest slot first (GK, then fewest natural fits) for stable picks.
    final slotOrder = List.generate(formation.slots.length, (i) => i)
      ..sort((a, b) {
        final pa = _naturalFits(formation.slots[a].position, available);
        final pb = _naturalFits(formation.slots[b].position, available);
        return pa != pb ? pa.compareTo(pb) : a.compareTo(b);
      });

    for (final slotIndex in slotOrder) {
      final slotPosition = formation.slots[slotIndex].position;
      AiSquadPlayer? best;
      var bestScore = -1.0;
      for (final p in available) {
        final score = _aiSlotScore(p, slotPosition);
        if (score > bestScore) {
          bestScore = score;
          best = p;
        }
      }
      if (best == null) continue;
      assigned[slotIndex] = best;
      available.remove(best);
    }

    // Defensive fill: a squad too small or too lopsided for the formation
    // still fields eleven bodies (mirrors the engine's own fallback).
    for (var slotIndex = 0; slotIndex < assigned.length; slotIndex++) {
      if (assigned[slotIndex] == null && available.isNotEmpty) {
        assigned[slotIndex] = available.removeAt(0);
      }
    }

    final starters = [for (final p in assigned) p!];
    final bench = [...available]
      ..sort((a, b) => _aiOverallOf(b).compareTo(_aiOverallOf(a)));
    return (starters: starters, bench: bench);
  }

  /// Slot-role score of one squad player: compatibility × position-weighted
  /// attributes × condition. The fitness factor runs 1.0 at full stamina
  /// down to 0.65 at zero, which is what makes the AI rest tired legs
  /// when the backup is close enough in quality.
  double _aiSlotScore(AiSquadPlayer p, Position slotPosition) {
    final compat = const SquadEngine().compatibilityOf(
      p.position,
      slotPosition,
    );
    if (compat <= 0.1) return 0;
    final weights = positionWeights[slotPosition]!;
    var base = 0.0;
    for (final e in weights.entries) {
      base +=
          switch (e.key) {
            PlayerAttribute.attack => p.attack,
            PlayerAttribute.support => p.support,
            PlayerAttribute.defence => p.defence,
            PlayerAttribute.goalkeeping => p.goalkeeping,
          } *
          e.value;
    }
    final fitness = 0.65 + 0.35 * (p.stamina.clamp(0, 100) / 100);
    return compat * base * fitness;
  }

  static int _aiOverallOf(AiSquadPlayer p) =>
      ((p.attack + p.support + p.defence) / 3).round();

  int _naturalFits(Position slotPosition, List<AiSquadPlayer> players) =>
      players
          .where(
            (p) =>
                const SquadEngine().compatibilityOf(p.position, slotPosition) >
                0.5,
          )
          .length;

  /// Inverts the BaseStatsGenerator value curve to the market value that
  /// yields [overall], then generates through the same position weights —
  /// guaranteeing AI attribute parity with real players of the same level.
  AiPlayerDefinition _generatePlayer(
    Position position,
    int targetOverall,
    math.Random random,
  ) {
    final spread = random.nextInt(7) - 3;
    final overall = (targetOverall + spread).clamp(35, 94);
    final c = statsGenerator.config;
    final doublings = (overall - c.valueAtReference) / c.ratingPerDoubling;
    final marketValue = (c.referenceValueEur * math.pow(2, doublings)).round();
    // Seeded from the squad RNG: AI players get the same probabilistic
    // stat shapes as real players, while a seeded season still rebuilds
    // the identical squad (GDD 12.5 determinism).
    final stats = statsGenerator.generate(
      position,
      marketValue,
      seed: random.nextInt(1 << 31),
    );
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
      'ha',
      'sa',
      'ma',
      'ra',
      'ka',
      'la',
      'na',
      'ta',
      'za',
      'fa',
      'heb',
      'med',
      'rid',
      'sam',
      'ham',
      'mor',
      'sal',
      'far',
      'nas',
      'eid',
    ];
    final parts = [
      syllables[random.nextInt(syllables.length)].toUpperCase(),
      for (var i = 0; i < 2; i++) syllables[random.nextInt(syllables.length)],
    ];
    return parts.join();
  }

  Formation _pickFormation(math.Random random) {
    const codes = [
      '4-4-2',
      '4-3-3',
      '4-2-3-1',
      '3-5-2',
      '5-3-2',
      '4-5-1',
      '4-1-4-1',
    ];
    return formationByCode(codes[random.nextInt(codes.length)]);
  }

  Mentality _pickMentality(math.Random random) {
    // Most AI sides play balanced-ish; extremes are rarer.
    const pool = [
      Mentality.veryDefensive,
      Mentality.defensive,
      Mentality.cautious,
      Mentality.balanced,
      Mentality.balanced,
      Mentality.positive,
      Mentality.positive,
      Mentality.attacking,
      Mentality.veryAttacking,
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
        if (i != anchorIndex) i,
    ];
    final pairings = <FixturePairing>[];

    for (var round = 0; round < rounds; round++) {
      final isFirstHalf = round < teamCount - 1;
      // Round position within this half of the season.
      final r = round % (teamCount - 1);
      // Circle: anchor vs others[r]; others[(r+i)] vs others[(r-i)] mod.
      int mod(int x) => x % others.length;

      void add(int home, int away, {bool flip = false}) {
        pairings.add(
          FixturePairing(
            round: round,
            homeIndex: flip ? away : home,
            awayIndex: flip ? home : away,
          ),
        );
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
    required List<
      ({int round, int homeIndex, int awayIndex, int homeGoals, int awayGoals})
    >
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
        ),
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
        ),
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

  /// Position-based season coin rewards (GDD 18, owner decision
  /// 2026-11-09: strictly graduated — 1st pays the most, 20th the least,
  /// every step down pays strictly less). Pack grants are decided by the
  /// store (they need persistence context).
  int seasonRewardCoins({required int division, required int position}) {
    final divisionFactor = 1.0 + config.rewardPerDivisionStep * (division - 1);
    final base = config.seasonBaseReward * divisionFactor;
    final multiplier = switch (outcomeForPosition(position)) {
      SeasonOutcome.promoted => switch (position) {
        1 => _rewardMultiplierChampion,
        2 => _rewardMultiplierRunnerUp,
        _ => _rewardMultiplierThird,
      },
      SeasonOutcome.relegated => switch (position) {
        _ when position == config.clubsPerDivision =>
          _rewardMultiplierLastPlace,
        _ when position == config.clubsPerDivision - 1 =>
          _rewardMultiplierSecondLast,
        _ => _rewardMultiplierThirdLast,
      },
      SeasonOutcome.stayed => (1.0 - (position - 4) * 0.03).clamp(0.6, 1.0),
    };
    return (base * multiplier).round();
  }

  /// Season-reward multipliers (GDD 18): one named constant per step of
  /// the graduated curve so the ladder is auditable in one place. The
  /// champion multiplier × the div-1 base (10_000) is the 20_000 anchor
  /// the ad-economy delta test rides on; the stayed band's slope (0.03)
  /// lives in the clamp expression above and was already strictly
  /// decreasing — it is untouched.
  static const double _rewardMultiplierChampion = 2.0;
  static const double _rewardMultiplierRunnerUp = 1.6;
  static const double _rewardMultiplierThird = 1.5;

  /// Relegation graduates downward from the stayed band: 18th keeps a
  /// soft landing, 19th less, 20th the participation floor (0.5 ×
  /// base = 5_000 at division 1).
  static const double _rewardMultiplierThirdLast = 0.55;
  static const double _rewardMultiplierSecondLast = 0.52;
  static const double _rewardMultiplierLastPlace = 0.50;
}

/// Draw tracker over the real-player pool for one division: hands out
/// each player at most once across the division's clubs (a player cannot
/// appear in two AI squads of the same league) and never hands out a
/// player the user owns. Candidates for a position are drawn from an
/// overall band around the division target that widens when the band
/// runs dry, so a deep dataset is used precisely while a thin one still
/// fills every slot. Selection inside the band is a reservoir-style
/// random pick — squads feel scouted, not sorted.
class _PoolTracker {
  _PoolTracker({
    required List<AiPoolPlayer> pool,
    required Set<int> exclude,
    required this.random,
  }) : _byPosition = {
         for (final position in Position.values)
           position: [
             ...pool
                 .where(
                   (p) =>
                       p.position == position && !exclude.contains(p.playerId),
                 )
                 .toList()
               ..sort((a, b) => a.overall.compareTo(b.overall)),
           ],
       };

  final Map<Position, List<AiPoolPlayer>> _byPosition;
  final math.Random random;
  final Set<int> _used = {};

  /// Whether every position has ANY player (used or not) within ±3 of
  /// [targetOverall] — the pristine capacity judgment for the lift
  /// gate: generation may exhaust a band mid-division, but the pool
  /// still supplies that quality level, so lifting is off.
  bool pristinePoolSupplies(int targetOverall) {
    for (final candidates in _byPosition.values) {
      final inBand = candidates.any(
        (p) => (p.overall - targetOverall).abs() <= 3,
      );
      if (!inBand) return false;
    }
    return true;
  }

  /// Takes one unused pool player for [position] near [targetOverall],
  /// or null when the position is exhausted. Banding starts at ±3 and
  /// widens by 3 until a candidate is found or the whole position is
  /// used up — Div 1 (easiest) and the top divisions (elite bands) both
  /// stay populated even where the dataset is thin.
  AiPoolPlayer? take(Position position, int targetOverall) {
    final candidates = _byPosition[position] ?? const <AiPoolPlayer>[];
    final unused = candidates
        .where((p) => !_used.contains(p.playerId))
        .toList();
    if (unused.isEmpty) return null;
    var halfWidth = 3;
    while (true) {
      final inBand = unused
          .where((p) => (p.overall - targetOverall).abs() <= halfWidth)
          .toList();
      if (inBand.isNotEmpty) {
        final picked = inBand[random.nextInt(inBand.length)];
        _used.add(picked.playerId);
        return picked;
      }
      if (halfWidth >= 100) {
        // Band covers everything: take any unused candidate.
        final picked = unused[random.nextInt(unused.length)];
        _used.add(picked.playerId);
        return picked;
      }
      halfWidth += 3;
    }
  }
}
