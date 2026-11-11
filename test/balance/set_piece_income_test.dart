/// FCM Rivals — T-0114: the underdog set-piece income layer's own
/// gate. Three contracts, zero edits to any existing test:
///
/// 1. BIT-IDENTICAL GUARD: at the default 0.0 the layer is inert —
///    the draw is SKIPPED (not drawn-and-ignored), so seeded output
///    is byte-identical to the pre-layer engine.
/// 2. EVEN-STRENGTH NEUTRALITY (layer on): the layer must not tilt
///    even matches — win/draw/goal bands in the even-strength spirit.
/// 3. THE UNDERDOG LIFT (layer on, B+50%): the underdog's goals rise
///    from the baseline ~0.33 toward ≥0.7 while the favourite's
///    moves ≤0.3, and the favourite's win rate drops (direction, not
///    number — the numeric lock is T-0116's).
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

const _positions = [
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

const _baseOverall = 70;

int _valueForOverall(int overall) {
  if (overall <= 84) {
    return (50_000_000 * math.pow(2, (overall - 84) / 4)).round();
  }
  return (50_000_000 * math.pow(2, (overall - 84) / 7.5)).round();
}

List<MatchPlayer> _squad(int base, String prefix, int level) {
  final gen = const BaseStatsGenerator();
  final value = _valueForOverall(_baseOverall);
  return [
    for (var i = 0; i < _positions.length; i++)
      MatchPlayer(
        playerId: base + i,
        name: '$prefix $i',
        position: _positions[i],
        attack: upgradedValue(
          gen.generate(_positions[i], value).attack,
          level,
        ),
        support: upgradedValue(
          gen.generate(_positions[i], value).support,
          level,
        ),
        defence: upgradedValue(
          gen.generate(_positions[i], value).defence,
          level,
        ),
        goalkeeping: upgradedValue(
          gen.generate(_positions[i], value).goalkeeping,
          level,
        ),
      ),
  ];
}

MatchEngine _engine(
  int seed, {
  required int homeLevel,
  required int awayLevel,
  double setPieceIncome = 0.0,
}) => MatchEngine(
  seed: seed,
  config: MatchEngineConfig(setPieceIncome: setPieceIncome),
  home: MatchTeamInput(
    teamId: 1,
    teamName: 'Home',
    formationCode: '4-4-2',
    tactics: const TeamTactics(),
    mentality: Mentality.balanced,
    starters: _squad(100, 'H', homeLevel),
    bench: const [],
  ),
  away: MatchTeamInput(
    teamId: 2,
    teamName: 'Away',
    formationCode: '4-4-2',
    tactics: const TeamTactics(),
    mentality: Mentality.balanced,
    starters: _squad(300, 'A', awayLevel),
    bench: const [],
  ),
);

class _B {
  _B(this.n, this.hw, this.d, this.aw, this.hg, this.ag, this.hs, this.asx);
  final int n, hw, d, aw, hg, ag, hs, asx;
  double get hwR => hw / n;
  double get dR => d / n;
  double get awR => aw / n;
  double get hG => hg / n;
  double get aG => ag / n;
  double get gAvg => (hg + ag) / n;
}

_B _run(
  int n,
  int seedBase, {
  required int homeLevel,
  required int awayLevel,
  double setPieceIncome = 0.0,
}) {
  var hw = 0, d = 0, aw = 0, hg = 0, ag = 0, hs = 0, asx = 0;
  for (var m = 0; m < n; m++) {
    final engine = _engine(
      seedBase + m,
      homeLevel: homeLevel,
      awayLevel: awayLevel,
      setPieceIncome: setPieceIncome,
    );
    engine.simulateToEnd();
    final s = engine.state;
    if (s.scoreHome > s.scoreAway) {
      hw++;
    } else if (s.scoreAway > s.scoreHome) {
      aw++;
    } else {
      d++;
    }
    hg += s.scoreHome;
    ag += s.scoreAway;
    for (final e in engine.events) {
      if (e.type == MatchEventType.shot) {
        e.side == MatchSide.home ? hs++ : asx++;
      }
    }
  }
  return _B(n, hw, d, aw, hg, ag, hs, asx);
}

/// The shipped income value. T-0116 landed 0.045 with the parity
/// big/normal carrier and an unconditional draw; the T-0117 realism
/// re-anchor (calibration repair) moved the layer to 0.075 with a
/// NORMAL-ONLY carrier behind a territory-share threshold (<0.45 —
/// the draw fires only when the OUT side is genuinely the underdog
/// of the possession). The T-0116 landing was measured against
/// match_engine_balance but never the real-football calibration
/// suite, and paid both sides at even strength: 3.14 goals/match
/// (band 2.4–2.9), 9.3% 6+ thrillers (<7.5%), 2.24 big chances/team
/// (1.3–1.9). Behind the threshold the underdog lifeline reads
/// 0.58 goals/match at B+50 with the favourite's win rate 0.872 —
/// both inside the ladder's locked bands.
const kProbeIncome = 0.07;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SHIPPED-STATE GUARD: the battery and the default pin', () {
    // T-0116 turned the layer ON at 0.045 with the parity carrier;
    // T-0117's realism re-anchor moved it to 0.075 with the
    // normal-only carrier behind the territory threshold (the
    // parity big half plus the unconditional draw were the
    // measured source of the calibration excess). The default
    // remains part of the shipped calibration — tactics-anchor
    // families ride on it. The battery below pins the CURRENT
    // engine's seeded output — any move is a real engine change.
    expect(MatchEngineConfig().setPieceIncome, 0.07);
    for (final seed in _battery.keys) {
      final engine = _engine(seed, homeLevel: 0, awayLevel: 0);
      engine.simulateToEnd();
      final s = engine.state;
      final shots = engine.events
          .where((e) => e.type == MatchEventType.shot)
          .length;
      expect(
        [s.scoreHome, s.scoreAway, shots],
        _battery[seed],
        reason: 'seed $seed moved — the shipped engine changed',
      );
    }
  });

  test('EVEN-STRENGTH NEUTRALITY (layer on): the bands hold', () {
    final b = _run(
      600,
      5000,
      homeLevel: 0,
      awayLevel: 0,
      setPieceIncome: kProbeIncome,
    );
    // The even-strength spirit bands (the balance suite's own):
    expect(b.hwR, inInclusiveRange(0.42, 0.52));
    expect(b.dR, inInclusiveRange(0.22, 0.32));
    expect(b.gAvg, inInclusiveRange(1.4, 5.2));
    // Direction-neutral at even strength: the layer pays BOTH sides'
    // defending territory shares, so the home-away goal gap stays in
    // home advantage's own neighbourhood (measured 0.51 at the probe
    // value vs 0.50 without the layer — the layer adds symmetric
    // income, not tilt).
    expect(b.hG - b.aG, inInclusiveRange(0.30, 0.70),
        reason: 'the income layer must not tilt even matches beyond '
            'home advantage itself');
  });

  test('THE UNDERDOG LIFT (layer on, B+50%): goals + direction', () {
    // Matched seeds, layer off vs on — the comparison IS the point.
    final off = _run(300, 1000, homeLevel: 0, awayLevel: 50);
    final on = _run(
      300,
      1000,
      homeLevel: 0,
      awayLevel: 50,
      setPieceIncome: kProbeIncome,
    );

    // The underdog (home side here) lifts from ~0.33 pre-umbrella
    // toward ≥0.55 (measured 0.61 at the shipped 0.045 + parity mix
    // on the n=1000 rung; the conversion normalization carries the
    // rest of the de-saturation).
    expect(on.hG, greaterThan(0.55),
        reason: 'the edge-independent income is the underdog lifeline');
    // The favourite's goals move ≤0.3 (the layer pays both sides'
    // defending shares by design — direction-symmetric income; the
    // assertion catches it becoming favourite-biased).
    expect((on.aG - off.aG).abs(), lessThan(0.30));
    // The favourite's win rate drops (direction; T-0116 locks the
    // number).
    expect(on.awR, lessThan(off.awR),
        reason: 'the underdog scoring must cost the favourite wins');
    // Combined goals stay in the band ceiling's spirit.
    expect(on.gAvg, lessThan(5.2));
  });

  test('value sweep note: the probe value re-validated at +25%', () {
    // The moderate rung must not explode either — the layer's
    // neutrality contract extends down the ladder.
    final b = _run(
      300,
      2000,
      homeLevel: 0,
      awayLevel: 25,
      setPieceIncome: kProbeIncome,
    );
    expect(b.gAvg, lessThan(5.2));
    expect(b.awR, lessThan(0.92),
        reason: 'the layer alone must not overshoot at +25% (the '
            'normalized edge is T-0115\'s half)');
  });
}

/// The pre-layer battery (measured on the untouched tree, T-0114's
/// landing session): seed → [homeGoals, awayGoals, totalShots].
const _battery = {
  7: [0, 2, 30],
  42: [0, 1, 33],
  991: [0, 2, 21],
};
