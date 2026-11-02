import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/simulation/economy_simulator.dart';
import 'package:fcm_rivals/features/simulation/economy_simulator_dataset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('economy simulator smoke: one season runs end to end', () async {
    final sim = EconomySimulator(seed: 7);
    final report = await sim.run(
      label: 'smoke',
      seasonCount: 1,
      valueBand: SimValueBand.medium,
      datasetSize: 120,
    );
    expect(report.seasons, hasLength(1));
    final s = report.seasons.first;
    expect(s.coinsEarned, greaterThan(0));
    expect(s.packOpenings, greaterThan(0));
    expect(s.finalPosition, inInclusiveRange(1, 20));
    expect(report.startingCoins, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
