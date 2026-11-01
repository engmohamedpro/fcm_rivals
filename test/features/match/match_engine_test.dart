import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_report.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

/// Builds an XI with generator-derived attributes at [marketValueEur].
List<MatchPlayer> makeTeam(int base, String name, {int marketValueEur = 20_000_000}) {
  const gen = BaseStatsGenerator();
  final positions = [
    Position.gk,
    Position.lb, Position.cb, Position.cb, Position.rb,
    Position.lm, Position.cm, Position.cm, Position.rm,
    Position.st, Position.st,
  ];
  return [
    for (var i = 0; i < positions.length; i++)
      MatchPlayer(
        playerId: base + i,
        name: '$name $i',
        position: positions[i],
        attack: gen.generate(positions[i], marketValueEur).attack,
        support: gen.generate(positions[i], marketValueEur).support,
        defence: gen.generate(positions[i], marketValueEur).defence,
        goalkeeping: gen.generate(positions[i], marketValueEur).goalkeeping,
      ),
  ];
}

MatchEngine buildEngine(int seed,
    {int homeValue = 20_000_000, int awayValue = 20_000_000}) {
  return MatchEngine(
    seed: seed,
    home: MatchTeamInput(
      teamId: 1,
      teamName: 'Home FC',
      formationCode: '4-4-2',
      style: PlayingStyle.balanced,
      mentality: Mentality.balanced,
      starters: makeTeam(100, 'Home', marketValueEur: homeValue),
      bench: makeTeam(200, 'HomeB', marketValueEur: homeValue ~/ 3)
          .sublist(0, 5),
    ),
    away: MatchTeamInput(
      teamId: 2,
      teamName: 'Away FC',
      formationCode: '4-3-3',
      style: PlayingStyle.balanced,
      mentality: Mentality.balanced,
      starters: makeTeam(300, 'Away', marketValueEur: awayValue),
      bench: makeTeam(400, 'AwayB', marketValueEur: awayValue ~/ 3)
          .sublist(0, 5),
      aiControlled: true,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MatchEngine determinism (GDD 12.5, FR-027/FR-028)', () {
    test('same seed and inputs reproduce the identical event stream', () {
      final a = buildEngine(42);
      final b = buildEngine(42);
      final ea = a.simulateToEnd();
      final eb = b.simulateToEnd();
      expect(ea.length, eb.length);
      for (var i = 0; i < ea.length; i++) {
        final x = ea[i], y = eb[i];
        expect(x.minute, y.minute, reason: 'event $i minute');
        expect(x.second, y.second, reason: 'event $i second');
        expect(x.type, y.type, reason: 'event $i type');
        expect(x.primaryPlayerId, y.primaryPlayerId, reason: 'event $i p1');
        expect(x.secondaryPlayerId, y.secondaryPlayerId, reason: 'event $i p2');
        expect(x.shotOutcome, y.shotOutcome, reason: 'event $i outcome');
        expect(x.xg, y.xg, reason: 'event $i xg');
      }
      expect(b.state.scoreHome, a.state.scoreHome);
      expect(b.state.scoreAway, a.state.scoreAway);
    });

    test('different seeds produce different matches (usually)', () {
      var differ = 0;
      for (var s = 0; s < 20; s++) {
        final a = buildEngine(s);
        final b = buildEngine(s + 1000);
        a.simulateToEnd();
        b.simulateToEnd();
        if (a.state.scoreHome != b.state.scoreHome ||
            a.state.scoreAway != b.state.scoreAway) {
          differ++;
        }
      }
      expect(differ, greaterThan(10));
    });

    test('replay with recorded commands reproduces the same result', () {
      // Baseline with a mentality change at minute 60.
      final a = buildEngine(7);
      final halfA = a.simulateToEnd().length;
      expect(halfA, greaterThan(0));

      final b = buildEngine(7);
      var minute = 0;
      final events = <MatchEvent>[];
      while (!b.isFinished) {
        minute++;
        if (minute == 60) {
          b.queueCommand(const ChangeMentalityCommand(
              atMinute: 60, side: MatchSide.home, mentality: Mentality.attacking));
        }
        events.addAll(b.advanceMinute());
      }
      // Replay: same seed, same command at the same minute.
      final c = buildEngine(7);
      var minute2 = 0;
      while (!c.isFinished) {
        minute2++;
        if (minute2 == 60) {
          c.queueCommand(const ChangeMentalityCommand(
              atMinute: 60, side: MatchSide.home, mentality: Mentality.attacking));
        }
        c.advanceMinute();
      }
      expect(c.state.scoreHome, b.state.scoreHome);
      expect(c.state.scoreAway, b.state.scoreAway);
      expect(c.appliedCommands.length, 1);
    });
  });

  group('MatchEngine tactical changes (GDD 12.5 example, FR-029)', () {
    test('a minute-60 mentality change affects only future events', () {
      // Run to minute 60 recording events; then continue with a change.
      final engine = buildEngine(11);
      final before60 = <MatchEvent>[];
      for (var m = 0; m < 60; m++) {
        before60.addAll(engine.advanceMinute());
      }
      engine.queueCommand(const ChangeMentalityCommand(
          atMinute: 60, side: MatchSide.home, mentality: Mentality.veryAttacking));
      final after60 = engine.simulateToEnd();

      // The events before minute 60 are untouched: same prefix as an
      // untouched engine with the same seed.
      final untouched = buildEngine(11);
      final untouchedBefore = <MatchEvent>[];
      for (var m = 0; m < 60; m++) {
        untouchedBefore.addAll(untouched.advanceMinute());
      }
      expect(before60.length, untouchedBefore.length);
      for (var i = 0; i < before60.length; i++) {
        expect(before60[i].type, untouchedBefore[i].type);
        expect(before60[i].minute, untouchedBefore[i].minute);
        expect(before60[i].primaryPlayerId, untouchedBefore[i].primaryPlayerId);
        expect(before60[i].shotOutcome, untouchedBefore[i].shotOutcome);
      }
      // The change was recorded and affected the remaining match.
      final changeEvents = after60
          .where((e) => e.type == MatchEventType.tacticalChange)
          .toList();
      expect(changeEvents, isNotEmpty);
      expect(after60, isNotEmpty);
    });

    test('mentalities shift team totals in the documented direction', () {
      final engine = buildEngine(3);
      final balanced = engine.totalsOf(MatchSide.home);
      engine.queueCommand(const ChangeMentalityCommand(
          atMinute: 1, side: MatchSide.home, mentality: Mentality.veryAttacking));
      engine.advanceMinute(); // applies the command
      final attacking = engine.totalsOf(MatchSide.home);
      expect(attacking.attack, greaterThan(balanced.attack));
      expect(attacking.defence, lessThan(balanced.defence));
    });

    test('home advantage boosts the home side (GDD 12.2 step 4)', () {
      final engine = buildEngine(5);
      final home = engine.totalsOf(MatchSide.home);
      final away = engine.totalsOf(MatchSide.away);
      // Identical squads: the home team must come out ahead on attack.
      expect(home.attack, greaterThan(away.attack));
    });

    test('stamina loss reduces team totals (GDD 12.2 step 1)', () {
      final engine = buildEngine(5);
      final start = engine.totalsOf(MatchSide.home);
      for (final p in engine.playersOf(MatchSide.home)) {
        p.stamina = 50;
      }
      final drained = engine.totalsOf(MatchSide.home);
      expect(drained.attack, lessThan(start.attack));
      expect(drained.support, lessThan(start.support));
      expect(drained.defence, lessThan(start.defence));
    });
  });

  group('MatchEngine substitutions and cards (FR-023, GDD 10.5)', () {
    test('substitution swaps the player and increments the counter', () {
      final engine = buildEngine(9);
      for (var m = 0; m < 10; m++) {
        engine.advanceMinute();
      }
      expect(engine.state.substitutionsHome, 0);
      engine.queueCommand(SubstitutionCommand(
          atMinute: 11,
          side: MatchSide.home,
          outPlayerId: 100 + 10, // ST
          inPlayerId: 200)); // bench ST
      engine.advanceMinute();
      expect(engine.state.substitutionsHome, 1);
      // The substitute is on the pitch accumulating minutes; the outgoing
      // player's minutes are frozen (GDD 10.5).
      for (var m = 0; m < 5; m++) {
        engine.advanceMinute();
      }
      final inPlayer = engine
          .playersOf(MatchSide.home)
          .firstWhere((p) => p.playerId == 200);
      final outPlayer = engine
          .playersOf(MatchSide.home)
          .firstWhere((p) => p.playerId == 110);
      expect(inPlayer.minutesPlayed, greaterThan(0));
      expect(outPlayer.minutesPlayed, 10);
      final subEvents =
          engine.events.where((e) => e.type == MatchEventType.substitution).toList();
      expect(subEvents.length, 1);
      expect(subEvents.first.primaryPlayerId, 110);
      expect(subEvents.first.secondaryPlayerId, 200);
    });

    test('more than five substitutions are rejected (FR-023)', () {
      final engine = buildEngine(9);
      for (var m = 0; m < 3; m++) {
        engine.advanceMinute();
      }
      // five legal substitutions
      for (var i = 0; i < 5; i++) {
        engine.queueCommand(SubstitutionCommand(
            atMinute: 4 + i,
            side: MatchSide.home,
            outPlayerId: 100 + i,
            inPlayerId: 200 + i));
        engine.advanceMinute();
      }
      expect(engine.state.substitutionsHome, 5);
      // The sixth is only due at minute 20: run until it is applied.
      engine.queueCommand(SubstitutionCommand(
          atMinute: 20,
          side: MatchSide.home,
          outPlayerId: 100 + 5,
          inPlayerId: 200));
      expect(() {
        while (!engine.isFinished) {
          engine.advanceMinute();
        }
      }, throwsStateError);
    });

    test('red cards reduce the team on the pitch over many matches', () {
      // With ~0.8% straight red + second yellows, some matches in 300
      // should contain one. The on-pitch count must drop when they do.
      var redSeen = false;
      for (var s = 0; s < 300 && !redSeen; s++) {
        final engine = buildEngine(s);
        final events = engine.simulateToEnd();
        final reds = events
            .where((e) =>
                e.type == MatchEventType.card && e.metadata['card'] == 'red')
            .toList();
        if (reds.isNotEmpty) {
          redSeen = true;
          final sentOffId = reds.first.primaryPlayerId!;
          final homePlayer = engine
              .playersOf(MatchSide.home)
              .firstWhere((p) => p.playerId == sentOffId, orElse: () => engine.playersOf(MatchSide.home).first);
          if (homePlayer.playerId == sentOffId) {
            expect(homePlayer.sentOff, isTrue);
          }
        }
      }
      expect(redSeen, isTrue, reason: 'no red card in 300 seeded matches');
    });
  });

  group('MatchEngine simulation sanity (GDD 31 metrics)', () {
    test('goals, shots and stamina land in plausible ranges', () {
      const matches = 200;
      var totalGoals = 0, homeWins = 0, draws = 0;
      var totalShots = 0, totalOnTarget = 0;
      var totalStamina = 0.0;
      var staminaSamples = 0;
      var totalXg = 0.0;

      for (var m = 0; m < matches; m++) {
        final engine = buildEngine(m);
        final events = engine.simulateToEnd();
        final state = engine.state;
        totalGoals += state.scoreHome + state.scoreAway;
        if (state.scoreHome > state.scoreAway) {
          homeWins++;
        } else if (state.scoreHome == state.scoreAway) {
          draws++;
        }
        final stats = computeStats(events, homeTeamId: 1, awayTeamId: 2);
        totalShots += stats.home.shots + stats.away.shots;
        totalOnTarget +=
            stats.home.shotsOnTarget + stats.away.shotsOnTarget;
        totalXg += stats.home.xg + stats.away.xg;
        for (final p in [
          ...engine.playersOf(MatchSide.home),
          ...engine.playersOf(MatchSide.away),
        ]) {
          if (p.minutesPlayed >= 90) {
            totalStamina += p.stamina;
            staminaSamples++;
          }
        }
      }

      final avgGoals = totalGoals / matches;
      expect(avgGoals, greaterThan(1.8), reason: 'too few goals');
      expect(avgGoals, lessThan(4.5), reason: 'too many goals');
      final homeRate = homeWins / matches;
      expect(homeRate, greaterThan(0.34), reason: 'home advantage too weak');
      expect(homeRate, lessThan(0.62), reason: 'home advantage too strong');
      final drawRate = draws / matches;
      expect(drawRate, greaterThan(0.12), reason: 'implausibly few draws');
      expect(drawRate, lessThan(0.45), reason: 'implausibly many draws');
      final avgShots = totalShots / (matches * 2);
      expect(avgShots, greaterThan(6), reason: 'too few shots');
      expect(avgShots, lessThan(25), reason: 'too many shots');
      final onTargetRatio = totalOnTarget / totalShots;
      expect(onTargetRatio, greaterThan(0.25));
      expect(onTargetRatio, lessThan(0.75));
      final avgStamina = totalStamina / staminaSamples;
      expect(avgStamina, greaterThan(15), reason: 'stamina drains too fast');
      expect(avgStamina, lessThan(75), reason: 'stamina barely drains');
      final avgXg = totalXg / matches;
      expect(avgXg, greaterThan(0.5), reason: 'xG implausibly low');
      expect(avgXg, lessThan(6.0), reason: 'xG implausibly high');
    });

    test('stronger teams win more often (GDD 12.4 player attributes)', () {
      var strongWins = 0;
      const matches = 100;
      for (var m = 0; m < matches; m++) {
        final engine = buildEngine(m,
            homeValue: 80_000_000, awayValue: 2_000_000);
        engine.simulateToEnd();
        final s = engine.state;
        if (s.scoreHome > s.scoreAway) strongWins++;
      }
      expect(strongWins / matches, greaterThan(0.70),
          reason: 'attributes barely matter');
    });

    test('every goal has a shooter and a matching commentary line', () {
      final engine = buildEngine(13);
      final events = engine.simulateToEnd();
      final goals = events.where((e) => e.type == MatchEventType.goal).toList();
      final lines = generateCommentary(events,
          playerNames: {
            for (final p in [
              ...engine.playersOf(MatchSide.home),
              ...engine.playersOf(MatchSide.away),
            ])
              p.playerId: p.name,
          },
          homeTeamName: 'Home FC',
          awayTeamName: 'Away FC');
      final goalLines = lines.where((l) => l.text.startsWith('GOAL!')).length;
      expect(goalLines, goals.length);
      for (final g in goals) {
        expect(g.primaryPlayerId, isNotNull);
        // The goal count matches the score.
      }
      final s = engine.state;
      expect(
          events
              .where((e) =>
                  e.type == MatchEventType.goal && e.side == MatchSide.home)
              .length,
          s.scoreHome);
      expect(
          events
              .where((e) =>
                  e.type == MatchEventType.goal && e.side == MatchSide.away)
              .length,
          s.scoreAway);
    });
  });

  group('Match statistics (FR-032, GDD 13.2)', () {
    test('statistics derive from events consistently', () {
      final engine = buildEngine(21);
      final events = engine.simulateToEnd();
      final stats = computeStats(events, homeTeamId: 1, awayTeamId: 2);

      for (final e in events) {
        if (e.type == MatchEventType.shot) {
          final s = e.teamId == 1 ? stats.home : stats.away;
          expect(s.shots, greaterThanOrEqualTo(1));
        }
      }
      // possession shares sum to 100%.
      final homePoss = stats.possessionPercent(stats.home);
      expect(homePoss + stats.possessionPercent(stats.away), closeTo(100, 0.01));
      expect(homePoss, greaterThan(0));
      // saves match saved shots conceded by the other team.
      final savedAgainstHome = events
          .where((e) =>
              e.type == MatchEventType.shot &&
              e.teamId == 2 &&
              e.shotOutcome == ShotOutcome.saved)
          .length;
      expect(stats.home.saves, savedAgainstHome);
      // goals match the final score.
      expect(stats.home.goals, engine.state.scoreHome);
      expect(stats.away.goals, engine.state.scoreAway);
      expect(stats.home.assists + stats.away.assists,
          lessThanOrEqualTo(stats.home.goals + stats.away.goals));
    });
  });

  group('Player ratings (FR-033, GDD 14)', () {
    test('ratings are position-sensitive and score-driven', () {
      final engine = buildEngine(31);
      final events = engine.simulateToEnd();
      final state = engine.state;

      final homeRatings = computePlayerRatings(
        events: events,
        players: engine.playersOf(MatchSide.home),
        teamId: 1,
        teamGoals: state.scoreHome,
        teamGoalsConceded: state.scoreAway,
      );
      expect(homeRatings.length, 16); // XI + 5 bench
      expect(homeRatings.every((r) => r.rating >= 1.0 && r.rating <= 10.0),
          isTrue);

      // Scorers rate above the 6.0 baseline.
      for (final r in homeRatings) {
        if (r.goals > 0) {
          expect(r.rating, greaterThan(6.0));
        }
      }
      // Unused players stay neutral.
      for (final r in homeRatings.where((r) => r.minutesPlayed == 0)) {
        expect(r.rating, 6.0);
      }
      // Sorted for the post-match screen (Man of the Match first).
      for (var i = 1; i < homeRatings.length; i++) {
        expect(homeRatings[i - 1].rating,
            greaterThanOrEqualTo(homeRatings[i].rating));
      }
    });

    test('clean-sheet goalkeepers rate above baseline', () {
      // Find a seed where the away team fails to score.
      for (var s = 0; s < 50; s++) {
        final engine = buildEngine(s);
        final events = engine.simulateToEnd();
        if (engine.state.scoreAway != 0) continue;
        final homeRatings = computePlayerRatings(
          events: events,
          players: engine.playersOf(MatchSide.home),
          teamId: 1,
          teamGoals: engine.state.scoreHome,
          teamGoalsConceded: 0,
        );
        final gk = homeRatings.firstWhere((r) => r.position == Position.gk);
        expect(gk.rating, greaterThan(6.0));
        return;
      }
      fail('no clean sheet in 50 seeded matches');
    });
  });

  group('Stamina (GDD 11)', () {
    test('bench players do not consume match stamina', () {
      final engine = buildEngine(17);
      engine.simulateToEnd();
      final bench = engine.playersOf(MatchSide.home)
          .where((p) => p.playerId >= 200 && p.playerId < 300)
          .toList();
      // No substitutions were queued: bench stamina unchanged.
      for (final p in bench) {
        expect(p.stamina, 100);
        expect(p.minutesPlayed, 0);
      }
    });

    test('on-pitch players end the match below full stamina', () {
      final engine = buildEngine(17);
      engine.simulateToEnd();
      final starters = engine
          .playersOf(MatchSide.home)
          .where((p) => p.playerId >= 100 && p.playerId < 110)
          .where((p) => p.minutesPlayed >= 85);
      expect(starters, isNotEmpty);
      for (final p in starters) {
        expect(p.stamina, lessThan(90));
      }
    });

    test('playing style affects consumption (Gegenpressing drains more)', () {
      double avgStamina(PlayingStyle style) {
        final engine = MatchEngine(
          seed: 55,
          home: MatchTeamInput(
            teamId: 1,
            teamName: 'A',
            formationCode: '4-4-2',
            style: style,
            mentality: Mentality.balanced,
            starters: makeTeam(100, 'H'),
            bench: makeTeam(200, 'HB').sublist(0, 5),
          ),
          away: MatchTeamInput(
            teamId: 2,
            teamName: 'B',
            formationCode: '4-4-2',
            style: PlayingStyle.balanced,
            mentality: Mentality.balanced,
            starters: makeTeam(300, 'A'),
            bench: makeTeam(400, 'AB').sublist(0, 5),
          ),
        );
        engine.simulateToEnd();
        final players = engine
            .playersOf(MatchSide.home)
            .where((p) => p.minutesPlayed >= 85)
            .toList();
        return players.fold<double>(0, (a, p) => a + p.stamina) /
            players.length;
      }

      // Average across multiple seeds for stability.
      var gegen = 0.0, lowBlock = 0.0;
      for (var s = 0; s < 5; s++) {
        gegen += avgStamina(PlayingStyle.gegenpressing);
        lowBlock += avgStamina(PlayingStyle.lowBlock);
      }
      expect(gegen / 5, lessThan(lowBlock / 5));
    });
  });

  group('Commentary (FR-031, GDD 13.1)', () {
    test('commentary derives from events and names players', () {
      final engine = buildEngine(23);
      final events = engine.simulateToEnd();
      final names = {
        for (final p in [
          ...engine.playersOf(MatchSide.home),
          ...engine.playersOf(MatchSide.away),
        ])
          p.playerId: p.name,
      };
      final lines = generateCommentary(events,
          playerNames: names,
          homeTeamName: 'Home FC',
          awayTeamName: 'Away FC');

      expect(lines.first.text, contains('Kick-off'));
      expect(lines.last.text, contains('Full time'));
      final saves = lines.where((l) => l.text.startsWith('Save!')).length;
      final savedEvents = events
          .where((e) =>
              e.type == MatchEventType.shot &&
              e.shotOutcome == ShotOutcome.saved)
          .length;
      expect(saves, savedEvents);

      // Kickoff, half time and full time are present exactly once each.
      expect(
          lines.where((l) => l.text.contains('Kick-off')).length, 1);
      expect(
          lines.where((l) => l.text.startsWith('Half time')).length, 1);
      expect(
          lines.where((l) => l.text.startsWith('Full time')).length, 1);

      // Goal lines name the scorer.
      for (final g in events.where((e) => e.type == MatchEventType.goal)) {
        final line = lines.firstWhere((l) =>
            l.text.startsWith('GOAL!') && l.minute == g.minute);
        expect(line.text, contains(names[g.primaryPlayerId!]!));
      }
    });
  });

  group('AI adaptation (GDD 12.6)', () {
    test('AI changes tactics with recorded reasons and bounded frequency',
        () {
      var aiChangesSeen = 0;
      for (var s = 0; s < 100; s++) {
        final engine = buildEngine(s);
        final events = engine.simulateToEnd();
        final aiChanges = events
            .where((e) =>
                e.type == MatchEventType.tacticalChange &&
                e.metadata['ai'] == true)
            .toList();
        // bounded per team (only away is AI-controlled)
        expect(aiChanges.length, lessThanOrEqualTo(2));
        for (final c in aiChanges) {
          expect(c.metadata['reason'], isNotNull);
        }
        aiChangesSeen += aiChanges.length;
      }
      // AI is not inert, but it is also not maxing out every match.
      expect(aiChangesSeen, greaterThan(0));
      expect(aiChangesSeen / 100, lessThan(2.0));
    });
  });
}
