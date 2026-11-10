import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/stamina.dart';

void main() {
  group('stamina drain (GDD 11.2–11.4)', () {
    test('workload differs by position and tactics', () {
      const config = StaminaConfig();
      final gkDrain = staminaDrainForMinute(
        config: config,
        position: Position.gk,
        styleStamina: 1,
        mentalityStamina: 1,
      );
      final cmDrain = staminaDrainForMinute(
        config: config,
        position: Position.cm,
        styleStamina: 1,
        mentalityStamina: 1,
      );
      expect(cmDrain, greaterThan(gkDrain));

      // Gegenpressing multiplies consumption (GDD 11.3).
      final gegenDrain = staminaDrainForMinute(
        config: config,
        position: Position.cm,
        styleStamina: 1.30,
        mentalityStamina: 1,
      );
      expect(gegenDrain, greaterThan(cmDrain));

      // Low block reduces it.
      final lowBlockDrain = staminaDrainForMinute(
        config: config,
        position: Position.cm,
        styleStamina: 0.85,
        mentalityStamina: 1,
      );
      expect(lowBlockDrain, lessThan(cmDrain));
    });

    test('event involvement adds dynamic workload (GDD 11.4)', () {
      const config = StaminaConfig();
      final quiet = staminaDrainForMinute(
        config: config,
        position: Position.st,
        styleStamina: 1,
        mentalityStamina: 1,
      );
      final busy = staminaDrainForMinute(
        config: config,
        position: Position.st,
        styleStamina: 1,
        mentalityStamina: 1,
        involvedInEvent: true,
      );
      expect(busy, greaterThan(quiet));
      expect(busy - quiet, closeTo(config.eventActivityDrain, 1e-9));
    });
  });

  group('natural recovery (GDD 11.5)', () {
    test('full-match players recover more slowly than substitutes', () {
      const config = StaminaConfig();
      final fullMatch = recoverStamina(
        config: config,
        currentStamina: 40,
        minutesPlayed: 90,
        restDays: 3,
      );
      final sub15 = recoverStamina(
        config: config,
        currentStamina: 40,
        minutesPlayed: 15,
        restDays: 3,
      );
      expect(sub15, greaterThan(fullMatch));
    });

    test('longer rest recovers more', () {
      const config = StaminaConfig();
      final shortRest = recoverStamina(
        config: config,
        currentStamina: 50,
        minutesPlayed: 90,
        restDays: 1,
      );
      final longRest = recoverStamina(
        config: config,
        currentStamina: 50,
        minutesPlayed: 90,
        restDays: 5,
      );
      expect(longRest, greaterThan(shortRest));
    });

    test('stamina never resets straight to 100 from deep fatigue', () {
      const config = StaminaConfig();
      final recovered = recoverStamina(
        config: config,
        currentStamina: 20,
        minutesPlayed: 90,
        restDays: 2,
      );
      expect(recovered, lessThan(100));
      expect(recovered, greaterThan(20));
    });

    test('nearly fresh players with a long rest reach full', () {
      const config = StaminaConfig();
      final recovered = recoverStamina(
        config: config,
        currentStamina: 80,
        minutesPlayed: 90,
        restDays: 7,
      );
      expect(recovered, 100);
    });

    test('recovery stays within bounds', () {
      const config = StaminaConfig();
      for (final stamina in [0, 25, 50, 75, 99]) {
        for (final minutes in [0, 15, 45, 90]) {
          for (final rest in [1, 3, 7]) {
            final next = recoverStamina(
              config: config,
              currentStamina: stamina.toDouble(),
              minutesPlayed: minutes,
              restDays: rest,
            );
            expect(next, greaterThanOrEqualTo(0));
            expect(next, lessThanOrEqualTo(100));
          }
        }
      }
    });
  });
}
