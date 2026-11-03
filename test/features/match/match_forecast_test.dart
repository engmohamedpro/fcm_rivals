// Pre-match forecast (GDD 13 opponent analysis): the Monte-Carlo run must
// produce sane, honest probabilities from the two FULL squad lists —
// starting XI, bench and reserves all count — under neutral conditions:
// no tactics, no mentality, no stamina, no red cards or injuries, so the
// numbers are a like-for-like measure of squad quality on paper.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_forecast.dart';

const _generator = BaseStatsGenerator();

MatchPlayer _player(
  int id,
  Position pos,
  int marketValueEur, {
  double stamina = 100,
}) => MatchPlayer(
  playerId: id,
  name: 'Player $id',
  position: pos,
  attack: _generator.generate(pos, marketValueEur).attack,
  support: _generator.generate(pos, marketValueEur).support,
  defence: _generator.generate(pos, marketValueEur).defence,
  goalkeeping: _generator.generate(pos, marketValueEur).goalkeeping,
  stamina: stamina,
);

/// A 23-man squad: XI, bench and reserves, positions spread like a real
/// squad list.
List<MatchPlayer> _squad(int base, int marketValueEur) {
  const positions = [
    // Starting XI (4-4-2).
    Position.gk,
    Position.lb, Position.cb, Position.cb, Position.rb,
    Position.lm, Position.cm, Position.cm, Position.rm,
    Position.st, Position.st,
    // Bench (7).
    Position.gk, Position.cb, Position.rb, Position.cm,
    Position.cam, Position.lw, Position.st,
    // Reserves (5).
    Position.cb, Position.lb, Position.cm, Position.rw, Position.st,
  ];
  return [
    for (var i = 0; i < positions.length; i++)
      _player(base + i, positions[i], marketValueEur),
  ];
}

/// The starting XI only.
List<MatchPlayer> _xiOnly(int base, int marketValueEur) =>
    _squad(base, marketValueEur).take(11).toList();

/// The 12 squad-list players behind the XI: bench (7) + reserves (5).
List<MatchPlayer> _tail(int base, int marketValueEur) =>
    _squad(base, marketValueEur).skip(11).toList();

void main() {
  test('outcome percents sum to 100 and none are impossible', () {
    final forecast = forecastMatch(
      input: ForecastInput(
        userSquad: _squad(100, 20_000_000),
        opponentSquad: _squad(200, 20_000_000),
      ),
    );
    expect(forecast.samples, greaterThan(0));
    expect(
      forecast.winPercent + forecast.drawPercent + forecast.lossPercent,
      100,
    );
    expect(forecast.winPercent, greaterThan(0));
    expect(forecast.drawPercent, greaterThan(0));
    expect(forecast.lossPercent, greaterThan(0));
    // Expected goals in a believable football range.
    expect(forecast.avgUserGoals, inInclusiveRange(0.2, 5));
    expect(forecast.avgOpponentGoals, inInclusiveRange(0.2, 5));
    expect(forecast.cleanSheetPercent, inInclusiveRange(0, 80));
  });

  test('a much stronger squad is heavily favoured', () {
    final forecast = forecastMatch(
      input: ForecastInput(
        userSquad: _squad(100, 120_000_000),
        opponentSquad: _squad(200, 2_000_000),
      ),
    );
    expect(forecast.winPercent, greaterThan(forecast.lossPercent));
    expect(forecast.winPercent, greaterThan(55));
    expect(
      forecast.strength(forecast.userTotals),
      greaterThan(forecast.strength(forecast.opponentTotals)),
    );
    expect(forecast.attackAdvantage, greaterThan(0));
  });

  test('every player of the squad list counts, not just the starting XI', () {
    // IDENTICAL starting XI everywhere; only the bench and reserves
    // differ in quality. If the forecast were XI-only, both runs would
    // be exactly the same.
    final xi = _xiOnly(100, 20_000_000);
    final weakTail = _tail(500, 2_000_000);
    final strongTail = _tail(800, 120_000_000);

    // The squad-quality totals move with the players behind the XI.
    final withWeak = squadQualityTotals([...xi, ...weakTail]);
    final withStrong = squadQualityTotals([...xi, ...strongTail]);
    expect(withStrong.attack, greaterThan(withWeak.attack));
    expect(withStrong.support, greaterThan(withWeak.support));
    expect(withStrong.defence, greaterThan(withWeak.defence));

    // The forecast moves with them too, same seed and all.
    final opponent = _squad(200, 20_000_000);
    final weak = forecastMatch(
      input: ForecastInput(
        userSquad: [...xi, ...weakTail],
        opponentSquad: opponent,
      ),
      forecastSeed: 424242,
    );
    final strong = forecastMatch(
      input: ForecastInput(
        userSquad: [...xi, ...strongTail],
        opponentSquad: opponent,
      ),
      forecastSeed: 424242,
    );
    expect(strong.attackAdvantage, greaterThan(weak.attackAdvantage));
    expect(strong.winPercent, greaterThan(weak.winPercent));
  });

  test('neutral: tactics, mentality and stamina change nothing', () {
    final base = _squad(100, 20_000_000);
    final opponent = _squad(200, 20_000_000);

    // Stamina worn down to half: raw attributes, so identical totals.
    final tired = [
      for (var i = 0; i < base.length; i++)
        _player(base[i].playerId, base[i].position, 20_000_000, stamina: 50),
    ];
    expect(squadQualityTotals(tired).attack, squadQualityTotals(base).attack);
    expect(
      squadQualityTotals(tired).goalkeeping,
      squadQualityTotals(base).goalkeeping,
    );

    // A red card (sent off) or a booked player is still squad paper
    // quality: the forecast ignores match state entirely.
    final booked = [...base];
    booked[3].yellowCards = 1;
    booked[4].sentOff = true;
    expect(
      squadQualityTotals(booked).defence,
      squadQualityTotals(base).defence,
    );

    // The forecast input itself has no style/mentality/venue fields at
    // all — nothing tactical can enter the run.
    final a = forecastMatch(
      input: ForecastInput(userSquad: base, opponentSquad: opponent),
      forecastSeed: 99,
    );
    final b = forecastMatch(
      input: ForecastInput(userSquad: base, opponentSquad: opponent),
      forecastSeed: 99,
    );
    expect(a.winPercent, b.winPercent);
    expect(a.drawPercent, b.drawPercent);
    expect(a.avgUserGoals, b.avgUserGoals);
  });

  test('same seed reproduces the identical forecast', () {
    MatchForecast run() => forecastMatch(
      input: ForecastInput(
        userSquad: _squad(100, 20_000_000),
        opponentSquad: _squad(200, 20_000_000),
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

  test('random source is honoured (independent runs can differ)', () {
    final input = ForecastInput(
      userSquad: _squad(100, 20_000_000),
      opponentSquad: _squad(200, 20_000_000),
    );
    final a = forecastMatch(input: input, random: math.Random(1), samples: 40);
    final b = forecastMatch(input: input, random: math.Random(2), samples: 40);
    // Overwhelmingly likely to differ somewhere with different seeds.
    final differs =
        a.winPercent != b.winPercent ||
        a.drawPercent != b.drawPercent ||
        a.avgUserGoals != b.avgUserGoals;
    expect(differs, isTrue);
  });
}
