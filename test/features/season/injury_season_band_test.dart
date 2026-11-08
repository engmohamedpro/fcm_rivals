// Season injury-rate calibration band (T-0055, requirement 6): the
// end-to-end injury flow measured through the REAL store pipeline —
// a full simulated save (all 38 user fixtures through the real session
// + every AI round through the store) — printed and band-locked.
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/simulation/economy_simulator.dart';
import 'package:fcm_rivals/features/simulation/economy_simulator_dataset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the user club sustains a season-realistic number of injuries — '
      'printed and band-locked', () async {
    final sim = EconomySimulator(seed: 5700);
    final report = await sim.run(
      label: 'injury-band',
      seasonCount: 2,
      valueBand: SimValueBand.medium,
      datasetSize: 160,
    );
    final counts = report.seasons.map((s) => s.injuriesSustained).toList();
    // ignore: avoid_print
    print('T-0055 injuries per club per season (user club, full 38-round '
        'seasons through the real pipeline): $counts');
    // The band was MEASURED first (this print: [12, 19] over two
    // simulated seasons) and then locked to the task's documented
    // placeholder window 8-30: a rotated 23-man squad under the shipped
    // risk constants loses roughly one player every 2-3 fixtures when
    // the manager runs the naive simulation rotation. A dead zero (the
    // layer silently unwired) or a blowout beyond the documented window
    // both fail.
    for (final count in counts) {
      expect(count, greaterThanOrEqualTo(8),
          reason: 'the injury layer must be live end-to-end');
      expect(count, lessThanOrEqualTo(30),
          reason: 'a blowout season means the rates are mis-wired high');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
