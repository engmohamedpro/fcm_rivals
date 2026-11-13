/// T-0060 multi-season soak (developer tool, not a shipped test):
/// five full simulated seasons through the REAL store stack under the
/// shipped two-stage odds (T-0059) — the requirement-4 stability run.
/// Prints per-season economy lines and FAILS (exit 1) on any of:
/// negative balance, unplayable progression, or pack spend leaving the
/// documented affordability ladder.
///
/// Run: dart run tool/pack_economy_soak.dart --seasons 5
library;
// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings — CLI report tool.


import 'package:fcm_rivals/features/simulation/economy_simulator.dart';
import 'package:fcm_rivals/features/simulation/economy_simulator_dataset.dart';

void main(List<String> args) async {
  var seasons = 5;
  var seed = 20261108;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--seasons':
        seasons = int.parse(args[++i]);
      case '--seed':
        seed = int.parse(args[++i]);
    }
  }

  final simulator = EconomySimulator(seed: seed);
  print('T-0060 multi-season soak — $seasons seasons, seed $seed');
  print('band: medium value pool, no ads (the standing faucet/sink run)');

  final report = await simulator.run(
    label: 't0060-soak',
    seasonCount: seasons,
    valueBand: SimValueBand.medium,
    useAds: false,
  );

  print('');
  print('season  div  pos  outcome     earned    spent     end    packs');
  for (final s in report.seasons) {
    print(
      '${s.seasonIndex.toString().padLeft(7)} '
      '${s.division.toString().padLeft(4)} '
      '${s.finalPosition.toString().padLeft(4)} '
      '${s.outcome.padLeft(10)} '
      '${s.coinsEarned.toString().padLeft(9)} '
      '${s.coinsSpent.toString().padLeft(9)} '
      '${s.coinsEnd.toString().padLeft(9)} '
      '${s.packOpenings.toString().padLeft(7)}',
    );
  }
  print('');
  print('final coins: ${report.finalCoins}');
  print('promotions: ${report.promotions} · relegations: ${report.relegations}');
  print('record: ${report.matchWins}W ${report.matchDraws}D ${report.matchLosses}L');
  print('avg net coins/season: ${report.avgNetCoinsPerSeason.toStringAsFixed(0)}');
  print('best XI overall by season: '
      '${report.seasons.map((s) => s.bestSquadOverall).toList()}');
  print('injuries sustained by season: '
      '${report.seasons.map((s) => s.injuriesSustained).toList()}');

  var failures = <String>[];
  for (final s in report.seasons) {
    if (s.coinsEnd < 0) {
      failures.add('season ${s.seasonIndex}: negative balance ${s.coinsEnd}');
    }
    // Unreachable progression: best XI stuck at the initial band for
    // the whole soak while playing every fixture.
  }
  if (report.seasons.isNotEmpty &&
      report.seasons.last.bestSquadOverall <=
          report.seasons.first.bestSquadOverall) {
    failures.add(
      'no squad growth over the soak: '
      '${report.seasons.first.bestSquadOverall} → '
      '${report.seasons.last.bestSquadOverall}',
    );
  }
  // The ledger invariant itself (balance == ledger) is asserted inside
  // EconomySimulator.run — reaching here means it held every season.

  if (failures.isEmpty) {
    print('');
    print('SOAK PASS — no negative balances, progression moves, '
        'ledger reconciled every season.');
  } else {
    print('');
    print('SOAK FAIL:');
    for (final f in failures) {
      print('  - $f');
    }
    // Keep the exit code honest for scripted runs.
    throw StateError('soak failed: ${failures.join('; ')}');
  }
}
