// T-0116 final measurement: the re-lock run at the T-0073 protocol
// (n=1000, consecutive seeds 0..999 per cell) — BOTH directions,
// every level the drift bands need. This prints the numbers that go
// into the re-locked test (and the BLOCK record for the A direction).
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

int _valueForOverall(int overall) =>
    (50_000_000 * math.pow(2, (overall - 84) / 4)).round();

List<MatchPlayer> _squad(int base, String prefix, int level) {
  final gen = const BaseStatsGenerator();
  final value = _valueForOverall(_baseOverall);
  return [
    for (var i = 0; i < _positions.length; i++)
      MatchPlayer(
        playerId: base + i,
        name: '$prefix $i',
        position: _positions[i],
        attack: upgradedValue(gen.generate(_positions[i], value).attack, level),
        support: upgradedValue(gen.generate(_positions[i], value).support, level),
        defence: upgradedValue(gen.generate(_positions[i], value).defence, level),
        goalkeeping:
            upgradedValue(gen.generate(_positions[i], value).goalkeeping, level),
      ),
  ];
}

MatchEngine _engine(
  int seed, {
  required int homeLevel,
  required int awayLevel,
}) => MatchEngine(
  seed: seed,
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
  _B(this.hw, this.d, this.aw, this.hg, this.ag, this.hs, this.asx);
  final int hw, d, aw, hg, ag, hs, asx;
  static const n = 1000;
  double get hwR => hw / n;
  double get dR => d / n;
  double get awR => aw / n;
  double get hG => hg / n;
  double get aG => ag / n;
  double get gAvg => (hg + ag) / n;
}

_B _run(int seedBase, int homeLevel, int awayLevel) {
  var hw = 0, d = 0, aw = 0, hg = 0, ag = 0, hs = 0, asx = 0;
  for (var m = 0; m < 1000; m++) {
    final e = _engine(seedBase + m, homeLevel: homeLevel, awayLevel: awayLevel);
    e.simulateToEnd();
    final s = e.state;
    if (s.scoreHome > s.scoreAway) {
      hw++;
    } else if (s.scoreAway > s.scoreHome) {
      aw++;
    } else {
      d++;
    }
    hg += s.scoreHome;
    ag += s.scoreAway;
    for (final ev in e.events) {
      if (ev.type.name == 'shot') {
        ev.side.name == 'home' ? hs++ : asx++;
      }
    }
  }
  return _B(hw, d, aw, hg, ag, hs, asx);
}

void _row(String label, _B b) {
  // ignore: avoid_print
  print(
    '$label | hW ${b.hwR.toStringAsFixed(3)} d ${b.dR.toStringAsFixed(3)} '
    'aW ${b.awR.toStringAsFixed(3)} | goals ${b.hG.toStringAsFixed(2)}-'
    '${b.aG.toStringAsFixed(2)} (${b.gAvg.toStringAsFixed(2)}) | '
    'shots ${b.hs / 1000} ${b.asx / 1000}',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('T-0116 final measurement run', () {
    // B direction (away lifted) — the suite's existing seeds 0..999.
    _row('B+10', _run(0, 0, 10));
    _row('B+25', _run(0, 0, 25));
    _row('B+50', _run(0, 0, 50));
    // A direction (home lifted) — the new rung, same seeds.
    _row('A+10', _run(0, 10, 0));
    _row('A+25', _run(0, 25, 0));
    _row('A+50', _run(0, 50, 0));
    // Symmetric — the existing lock's seeds.
    _row('SYM 0', _run(0, 0, 0));
    _row('SYM+10', _run(0, 10, 10));
    _row('SYM+25', _run(0, 25, 25));
    _row('SYM+50', _run(0, 50, 50));
  });
}
