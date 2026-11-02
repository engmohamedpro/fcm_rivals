// Pre-match forecast (GDD 13 opponent analysis): the Monte-Carlo run must
// produce sane, honest probabilities from the real engine — outcomes sum
// to 100%, a stronger side is clearly favoured, home advantage shows, and
// the same seed reproduces the same forecast exactly.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_forecast.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

List<MatchPlayer> _squad(int base, String prefix, int marketValueEur) {
  const generator = BaseStatsGenerator();
  const positions = [
    Position.gk,
    Position.lb, Position.cb, Position.cb, Position.rb,
    Position.lm, Position.cm, Position.cm, Position.rm,
    Position.st, Position.st,
  ];
  return [
    for (var i = 0; i < positions.length; i++)
      () {
        final gen = generator.generate(positions[i], marketValueEur);
        return MatchPlayer(
          playerId: base + i,
          name: '$prefix $i',
          position: positions[i],
          attack: gen.attack,
          support: gen.support,
          defence: gen.defence,
          goalkeeping: gen.goalkeeping,
        );
      }(),
  ];
}

MatchTeamInput _team(int teamId, String name, int value) =>
    MatchTeamInput(
      teamId: teamId,
      teamName: name,
      formationCode: '4-4-2',
      style: PlayingStyle.balanced,
      mentality: Mentality.balanced,
      starters: _squad(teamId * 100, name, value),
      bench: const [],
    );

void main() {
  test('outcome percents sum to 100 and none are impossible', () {
    final forecast = forecastMatch(
      input: ForecastInput(
        userTeam: _team(1, 'User FC', 20_000_000),
        opponentTeam: _team(2, 'Rival FC', 20_000_000),
        userAtHome: true,
      ),
    );
    expect(forecast.samples, greaterThan(0));
    expect(
        forecast.winPercent + forecast.drawPercent + forecast.lossPercent,
        100);
    expect(forecast.winPercent, greaterThan(0));
    expect(forecast.drawPercent, greaterThan(0));
    expect(forecast.lossPercent, greaterThan(0));
    // Expected goals in a believable football range.
    expect(forecast.avgUserGoals, inInclusiveRange(0.2, 5));
    expect(forecast.avgOpponentGoals, inInclusiveRange(0.2, 5));
    expect(forecast.cleanSheetPercent, inInclusiveRange(0, 80));
  });

  test('a much stronger side is heavily favoured', () {
    final forecast = forecastMatch(
      input: ForecastInput(
        userTeam: _team(1, 'Giants', 120_000_000),
        opponentTeam: _team(2, 'Minnows', 2_000_000),
        userAtHome: true,
      ),
    );
    expect(forecast.winPercent, greaterThan(forecast.lossPercent));
    expect(forecast.winPercent, greaterThan(55));
    expect(forecast.strength(forecast.userTotals),
        greaterThan(forecast.strength(forecast.opponentTotals)));
    expect(forecast.attackAdvantage, greaterThan(0));
  });

  test('same seed reproduces the identical forecast', () {
    MatchForecast run() => forecastMatch(
          input: ForecastInput(
            userTeam: _team(1, 'User FC', 20_000_000),
            opponentTeam: _team(2, 'Rival FC', 20_000_000),
            userAtHome: false,
          ),
          forecastSeed: 424242,
        );
    final a = run();
    final b = run();
    expect(a.winPercent, b.winPercent);
    expect(a.drawPercent, b.drawPercent);
    expect(a.lossPercent, b.lossPercent);
    expect(a.avgUserGoals, b.avgUserGoals);
  });

  test('totals reflect the exact engine pipeline incl. home advantage', () {
    final user = _team(1, 'User FC', 20_000_000);
    final opponent = _team(2, 'Rival FC', 20_000_000);
    final home = forecastMatch(
      input: ForecastInput(
          userTeam: user, opponentTeam: opponent, userAtHome: true),
    );
    final away = forecastMatch(
      input: ForecastInput(
          userTeam: user, opponentTeam: opponent, userAtHome: false),
    );
    // Same squads: the home run's totals must carry the home edge.
    expect(home.userTotals.attack, greaterThan(away.userTotals.attack));
    expect(away.opponentTotals.attack, greaterThan(home.opponentTotals.attack));
  });

  test('random source is honoured (independent runs can differ)', () {
    final input = ForecastInput(
      userTeam: _team(1, 'User FC', 20_000_000),
      opponentTeam: _team(2, 'Rival FC', 20_000_000),
      userAtHome: true,
    );
    final a = forecastMatch(
        input: input, random: math.Random(1), samples: 40);
    final b = forecastMatch(
        input: input, random: math.Random(2), samples: 40);
    // Overwhelmingly likely to differ somewhere with different seeds.
    final differs = a.winPercent != b.winPercent ||
        a.drawPercent != b.drawPercent ||
        a.avgUserGoals != b.avgUserGoals;
    expect(differs, isTrue);
  });
}
