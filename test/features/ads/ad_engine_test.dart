import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/ads/ad_engine.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

/// Builds an XI with generator-derived attributes at [marketValueEur].
List<MatchPlayer> makeTeam(
  int base,
  String name, {
  int marketValueEur = 20_000_000,
}) {
  const gen = BaseStatsGenerator();
  final positions = [
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
  return [
    for (var i = 0; i < positions.length; i++)
      MatchPlayer(
        playerId: base + i,
        name: '$name $i',
        position: positions[i],
        attack: gen.generate(positions[i], marketValueEur).attack,
        support: gen.generate(positions[i], marketValueEur).support,
        defence: gen.generate(positions[i], marketValueEur).defence,
        goalkeeping: gen.generate(positions[i], marketValueEur).goalkeeping,
      ),
  ];
}

MatchEngine buildEngine(int seed) {
  return MatchEngine(
    seed: seed,
    home: MatchTeamInput(
      teamId: 1,
      teamName: 'Home FC',
      formationCode: '4-4-2',
      tactics: const TeamTactics(),
      mentality: Mentality.balanced,
      starters: makeTeam(100, 'Home'),
      bench: makeTeam(200, 'HomeB', marketValueEur: 7_000_000).sublist(0, 5),
    ),
    away: MatchTeamInput(
      teamId: 2,
      teamName: 'Away FC',
      formationCode: '4-3-3',
      tactics: const TeamTactics(),
      mentality: Mentality.balanced,
      starters: makeTeam(300, 'Away'),
      bench: makeTeam(400, 'AwayB', marketValueEur: 7_000_000).sublist(0, 5),
      aiControlled: true,
    ),
  );
}

void main() {
  group('Rewarded ads (GDD 19, FR-040..FR-042)', () {
    const engine = AdEngine();

    test('rewards granted only after successful completion (FR-041)', () {
      final now = DateTime(2026, 11, 1, 15);
      final ad = CompletedAd(
        kind: AdRewardKind.boostedRecovery,
        rewardKey: 'match:1',
        clubId: 1,
        completedAt: now,
      );
      final notCompleted = engine.validateReward(
        ad: ad,
        usageToday: const [],
        playbackCompleted: false,
      );
      expect(notCompleted.allowed, isFalse);
      expect(notCompleted.reason, contains('did not complete'));

      final completed = engine.validateReward(
        ad: ad,
        usageToday: const [],
        playbackCompleted: true,
      );
      expect(completed.allowed, isTrue);
      expect(completed.rewardKind, AdRewardKind.boostedRecovery);
    });

    test('duplicate callbacks are rejected (FR-042)', () {
      final now = DateTime(2026, 11, 1, 15);
      final ad = CompletedAd(
        kind: AdRewardKind.matchReplay,
        rewardKey: 'match:5',
        clubId: 1,
        completedAt: now,
      );
      final usage = [
        AdUsageRecord(
          rewardKind: 'matchReplay',
          rewardKey: 'match:5',
          completedAt: now,
        ),
      ];
      final result = engine.validateReward(
        ad: ad,
        usageToday: usage,
        playbackCompleted: true,
      );
      expect(result.allowed, isFalse);
      expect(result.reason, contains('already granted'));
    });

    test('daily limits are enforced per kind and globally', () {
      final now = DateTime(2026, 11, 1, 15);
      final ad = CompletedAd(
        kind: AdRewardKind.boostedRecovery,
        rewardKey: 'match:9',
        clubId: 1,
        completedAt: now,
      );

      // Per-kind limit: 3 boosted-recovery ads already used today.
      final usageSameKind = [
        for (var i = 0; i < 3; i++)
          AdUsageRecord(
            rewardKind: 'boostedRecovery',
            rewardKey: 'match:$i',
            completedAt: now,
          ),
      ];
      final kindLimit = engine.validateReward(
        ad: ad,
        usageToday: usageSameKind,
        playbackCompleted: true,
      );
      expect(kindLimit.allowed, isFalse);
      expect(kindLimit.reason, contains('Daily limit reached for'));

      // Global limit: 8 mixed ads used today, no single kind at its
      // limit (4 replay + 4 boosted would trip the kind limit, so use
      // kinds the new ad doesn't count toward).
      final usageMixed = [
        for (var i = 0; i < 8; i++)
          AdUsageRecord(
            rewardKind: 'matchReplay',
            rewardKey: 'k:$i',
            completedAt: now,
          ),
      ];
      final globalLimit = engine.validateReward(
        ad: ad,
        usageToday: usageMixed,
        playbackCompleted: true,
      );
      expect(globalLimit.allowed, isFalse);
      expect(globalLimit.reason, contains('Daily ad limit reached'));
    });

    test('match replay offered only after draw/defeat in the window', () {
      final fullTime = DateTime(2026, 11, 1, 15);
      final within = fullTime.add(const Duration(hours: 2));
      final beyond = fullTime.add(const Duration(hours: 30));

      expect(
        engine
            .validateMatchReplayOffer(
              won: true,
              fullTimeAt: fullTime,
              now: within,
            )
            .allowed,
        isFalse,
      );
      expect(
        engine
            .validateMatchReplayOffer(
              won: false,
              fullTimeAt: fullTime,
              now: within,
            )
            .allowed,
        isTrue,
      );
      expect(
        engine
            .validateMatchReplayOffer(
              won: false,
              fullTimeAt: fullTime,
              now: beyond,
            )
            .allowed,
        isFalse,
      );
    });

    test('boosted recovery adds +15% of natural recovery, capped at 100', () {
      // Natural recovery of 20 from 60 → boosted 63 (60 + 20*0.15).
      expect(
        engine.boostedRecovery(
          staminaAfterNaturalRecovery: 80,
          naturalRecovery: 20,
        ),
        83,
      );
      // Cap: 95 + 20 natural → 98 → capped at 100? 95+3=98 < 100; make a
      // case that clearly exceeds: 90 + 15 recovery → 92.25, fine; and a
      // hard cap case:
      expect(
        engine.boostedRecovery(
          staminaAfterNaturalRecovery: 99,
          naturalRecovery: 10,
        ),
        lessThanOrEqualTo(100),
      );
      expect(
        engine.boostedRecovery(
          staminaAfterNaturalRecovery: 99,
          naturalRecovery: 10,
        ),
        greaterThan(99),
      );
      // No natural recovery → no bonus.
      expect(
        engine.boostedRecovery(
          staminaAfterNaturalRecovery: 70,
          naturalRecovery: 0,
        ),
        70,
      );
    });

    test('config exposes the GDD 19.3 proposed values', () {
      expect(engine.config.boostedRecoveryBonus, 0.15);
      expect(engine.config.dailyLimitPerKind, greaterThanOrEqualTo(1));
    });
  });
}
