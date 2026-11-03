import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/simulation/economy_simulator.dart';
import 'package:fcm_rivals/features/simulation/economy_simulator_dataset.dart';
import 'package:fcm_rivals/features/simulation/match_simulator.dart';
import 'package:fcm_rivals/features/simulation/simulation_report.dart';

void main() {
  // Skipped in the normal suite: heavy balance run. Execute explicitly
  // with `flutter test tool/simulation_report_test.dart` (or via the
  // run_simulations.sh helper) to regenerate the report.
  test('generate simulation report', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final outPath =
        Platform.environment['FCM_SIM_OUTPUT'] ?? 'simulation_report.md';

    final matcher = MatchSimulator();
    final control = matcher.runBatch(label: 'even (control)', matches: 400);
    final tactics = matcher.runBatch(
      label: 'even + Push Forward @60',
      matches: 400,
      tacticsAtMinute60: true,
      controlHomeWins: control.homeWins,
      controlAwayWins: control.awayWins,
    );
    final stacked = matcher.runBatch(
      label: 'high vs low value',
      matches: 400,
      homeValueEur: MatchSimulator.highValueEur,
      awayValueEur: MatchSimulator.lowValueEur,
    );
    final div1 = matcher.runBatch(label: 'division 1', matches: 300);
    final div4 = matcher.runBatch(
      label: 'division 4',
      matches: 300,
      homeDivision: 4,
    );
    final lowBand = matcher.runBatch(
      label: 'low value band',
      matches: 200,
      homeValueEur: MatchSimulator.lowValueEur,
      awayValueEur: MatchSimulator.lowValueEur,
    );
    final highBand = matcher.runBatch(
      label: 'high value band',
      matches: 200,
      homeValueEur: MatchSimulator.highValueEur,
      awayValueEur: MatchSimulator.highValueEur,
    );

    final replayOk =
        matcher.replaysDeterministically(seed: 20261101) &&
        matcher.replaysDeterministically(seed: 999) &&
        matcher.replaysDeterministically(
          seed: 4242,
          commandFactories: [
            () => const ChangeMentalityCommand(
              atMinute: 60,
              side: MatchSide.home,
              mentality: Mentality.attacking,
            ),
          ],
        );
    final divergence = matcher.minute60ChangeAffectsFutureOnly(
      seed: 700,
      sampleMatches: 48,
    );

    final economy = EconomySimulator(seed: 20261101);
    final saves = <EconomySimReport>[
      await economy.run(
        label: 'medium band · 3 seasons',
        seasonCount: 3,
        valueBand: SimValueBand.medium,
        datasetSize: 160,
      ),
      await economy.run(
        label: 'low band · 2 seasons',
        seasonCount: 2,
        valueBand: SimValueBand.low,
        datasetSize: 160,
      ),
      await economy.run(
        label: 'high band · 2 seasons',
        seasonCount: 2,
        valueBand: SimValueBand.high,
        datasetSize: 160,
      ),
      await economy.run(
        label: 'medium band · ads · 2 seasons',
        seasonCount: 2,
        valueBand: SimValueBand.medium,
        useAds: true,
        datasetSize: 160,
      ),
    ];

    final report = renderSimulationReport(
      matchBatches: [control, tactics, stacked, div1, div4, lowBand, highBand],
      economySims: saves,
      deterministicReplay: replayOk,
      minute60Divergence: divergence != false,
    );

    await File(outPath).writeAsString(report);
    // ignore: avoid_print
    print('REPORT_WRITTEN: $outPath');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
