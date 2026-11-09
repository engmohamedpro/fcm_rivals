/// Reviewer probe (T-0072): byte-identity of generateAiClubs across
/// divisions between the pre-lift parent and the lifted HEAD.
///
/// Prints, for divisions 1..16 x seeds {5, 42, 77, 1234} x both paths
/// (synthetic no-pool and a full realistic pool), every club and every
/// player's four attributes in generation order. Run under both commits
/// and diff: divisions whose target the pool supplies must be identical.
library;

import 'dart:math' as math;

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/season/season_engine.dart';

/// Same pool the season engine tests use (test buildPool mirrored).
List<AiPoolPlayer> probePool() {
  final pool = <AiPoolPlayer>[];
  var id = 1;
  for (final position in Position.values) {
    for (var overall = 36; overall <= 94; overall++) {
      for (var copy = 0; copy < 6; copy++) {
        pool.add(
          AiPoolPlayer(
            playerId: id,
            name:
                '${position.code.toUpperCase()} ${overall.toString().padLeft(2, '0')} $copy',
            position: position,
            overall: overall,
            attack: overall,
            support: overall,
            defence: overall,
            goalkeeping: overall,
          ),
        );
        id++;
      }
    }
  }
  return pool;
}

void main() {
  const engine = SeasonEngine();
  final pool = probePool();
  for (var division = 1; division <= 16; division++) {
    final target = engine.config.targetAverageOverall(division);
    for (final seed in [5, 42, 77, 1234]) {
      for (final path in ['synthetic', 'pool']) {
        final clubs = engine.generateAiClubs(
          division,
          random: math.Random(seed),
          pool: path == 'pool' ? pool : null,
        );
        for (final club in clubs) {
          // ignore: avoid_print
          print('div $division target $target seed $seed $path ${club.name}');
          for (final p in club.players) {
            // ignore: avoid_print
            print(
              '  ${p.name} ${p.position.code} '
              '${p.attack} ${p.support} ${p.defence} ${p.goalkeeping}',
            );
          }
        }
      }
    }
  }
}
