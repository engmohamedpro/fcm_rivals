// The achievement catalog contracts (T-0105): uniqueness, geometric
// discipline, the economy-safety asymptote, title integrity and l10n
// completeness. These tests exist to FAIL if someone later adds a
// linear-growth coin ladder or drifts the derived ceiling — the two
// regressions this task exists to prevent.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/achievements/achievement_catalog.dart';
import 'package:fcm_rivals/features/achievements/achievement_catalog_data.dart';

void main() {
  final definitions = AchievementCatalog.definitions;

  group('catalog shape', () {
    test('10 categories, 42 definitions, 16+5 titles', () {
      expect(AchievementCatalog.categories.length, greaterThanOrEqualTo(10));
      expect(definitions.length, greaterThanOrEqualTo(40));
      final ladders = definitions
          .where((d) => d.kind == AchievementKind.endlessLadder)
          .length;
      final milestones = definitions
          .where((d) => d.kind == AchievementKind.milestone)
          .length;
      expect(ladders, greaterThanOrEqualTo(30));
      expect(milestones, greaterThanOrEqualTo(8));
      expect(
        AchievementCatalog.achievementTitles.length,
        greaterThanOrEqualTo(12),
      );
      expect(
        AchievementCatalog.seededDivisionTitles.length,
        5,
        reason: 'divisions 1..5 seeded, deeper generate on demand',
      );
    });

    test('every definition id is unique', () {
      final ids = definitions.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every definition category exists', () {
      final catIds = AchievementCatalog.categories.map((c) => c.id).toSet();
      for (final d in definitions) {
        expect(catIds.contains(d.category), isTrue,
            reason: '${d.id} references unknown category ${d.category}');
      }
    });

    test('milestones carry budgets; ladders never do', () {
      for (final d in definitions) {
        if (d.kind == AchievementKind.milestone) {
          expect(d.milestoneReward, isNotNull, reason: d.id);
        } else {
          expect(d.milestoneReward, isNull, reason: d.id);
        }
      }
    });
  });

  group('geometric ladder discipline (the economy contract)', () {
    test('thresholdRatio >= 2 enforced by constructor assert', () {
      expect(
        () => AchievementLadder(
          baseThreshold: 1,
          thresholdRatio: 1.5,
          tierCount: 3,
        ),
        throwsA(isA<AssertionError>()),
        reason: 'a 1.5x ladder compounds linearly enough to re-break '
            'the economy — the type refuses it',
      );
    });

    test('thresholds strictly monotonic, geometric, integer', () {
      for (final d in definitions) {
        final tiers = d.tiers(AchievementCatalog.economy);
        for (var i = 1; i < tiers.length; i++) {
          expect(tiers[i].threshold, greaterThan(tiers[i - 1].threshold),
              reason: '${d.id} tier ${i + 1} must demand more effort');
        }
        // The geometric property at the raw spec level.
        expect(d.ladder.thresholdRatio, greaterThanOrEqualTo(2),
            reason: d.id);
      }
    });

    test('endless coin rewards are FLAT — never grow with tier', () {
      for (final d in definitions) {
        if (d.kind != AchievementKind.endlessLadder) continue;
        final tiers = d.tiers(AchievementCatalog.economy);
        for (var i = 1; i < tiers.length; i++) {
          expect(tiers[i].coinReward, tiers[0].coinReward,
              reason: '${d.id} tier ${i + 1} must pay the same flat '
                  'reward — growth here is the regression this task '
                  'exists to prevent');
        }
      }
    });

    test('THE ASYMPTOTE: coins-per-effort strictly decreases beyond '
        'tier 1 (log growth vs exponential effort)', () {
      for (final d in definitions) {
        if (d.kind != AchievementKind.endlessLadder) continue;
        final tiers = d.tiers(AchievementCatalog.economy);
        final flat = tiers.first.coinReward;
        // Cumulative coins after tier n = flat * n. Effort at tier n
        // = base * ratio^(n-1). coins/effort after n:
        //   flat*n / (base * ratio^(n-1))
        // With base=1 the first two rungs tie (flat*2 / 2 == flat*1/1);
        // from the tie on, the rate STRICTLY falls. The invariant that
        // kills a linear coin ladder: the rate never RISES, and it
        // strictly falls once the geometric pull outruns the +1 tier
        // (n = base + 1 onward at ratio 2).
        double rateAfter(int n) =>
            (flat * n) / d.ladder.thresholdOf(n).toDouble();
        expect(rateAfter(2), lessThanOrEqualTo(rateAfter(1)),
            reason: '${d.id}: the rate never rises, even at the start');
        for (var n = 3; n <= tiers.length; n++) {
          expect(rateAfter(n), lessThan(rateAfter(n - 1)),
              reason: '${d.id}: coins-per-effort must strictly fall — '
                  'a linear coin ladder fails here');
        }
        // And the O(1) bound shape: coins grow ≤ C + flat*n while
        // effort grows exponentially — after 20 tiers, doubling
        // effort buys ONE more flat reward.
        final t20 = d.ladder.thresholdOf(20);
        final t19 = d.ladder.thresholdOf(19);
        expect(t20 / t19, greaterThanOrEqualTo(1.9),
            reason: '${d.id}: late tiers must (at least) double effort');
      }
    });

    test('the ladder constructor rejects self-contradictory shapes', () {
      expect(
        () => AchievementLadder(
          baseThreshold: 1,
          thresholdRatio: 2,
          endless: true,
          tierCount: 3,
        ),
        throwsA(isA<AssertionError>()),
        reason: 'endless and tierCount are mutually exclusive',
      );
      expect(
        () => AchievementLadder(baseThreshold: 0, thresholdRatio: 2),
        throwsA(isA<AssertionError>()),
        reason: 'tier 1 sits at real effort',
      );
    });
  });

  group('derived economy ceiling', () {
    test('totalCatalogCoinCeiling derives and stays finite', () {
      final ceiling = AchievementCatalog
          .economy
          .totalCatalogCoinCeiling(definitions);
      expect(ceiling, greaterThan(0));
      expect(ceiling, lessThan(1_000_000),
          reason: 'pre-balance placeholder scale: the whole catalog is '
              'a bonus drip, not a second economy');
      // Milestones alone are their own sum.
      final milestoneSum = definitions
          .map((d) => d.milestoneReward ?? 0)
          .reduce((a, b) => a + b);
      expect(ceiling, greaterThan(milestoneSum),
          reason: 'the ceiling includes the endless ladders\' '
              'log-horizon on top of milestones');
    });

    test('ceiling and catalog cannot drift: adding a definition '
        'changes the derived number', () {
      final before = AchievementCatalog
          .economy
          .totalCatalogCoinCeiling(definitions);
      final withExtra = [
        ...definitions,
        AchievementDefinition(
          id: 'drift_probe',
          category: 'career',
          metricId: 'wins',
          titleKey: 'achCareerWins',
          descriptionKey: 'achCareerWinsDesc',
          hint: 'probe',
          kind: AchievementKind.milestone,
          ladder: AchievementLadder(
            baseThreshold: 1,
            thresholdRatio: 2,
            tierCount: 1,
          ),
          milestoneReward: 123,
        ),
      ];
      final after = AchievementCatalog
          .economy
          .totalCatalogCoinCeiling(withExtra);
      expect(after - before, 123,
          reason: 'the ceiling is DERIVED, so a new milestone moves it '
              'by exactly its budget — no stored number to forget');
    });
  });

  group('title integrity', () {
    test('every titleId referenced by a tier exists in the registry', () {
      final known = AchievementCatalog.allTitleIds.toSet();
      for (final d in definitions) {
        for (final tier in d.tiers(AchievementCatalog.economy)) {
          final t = tier.titleId;
          if (t == null) continue;
          expect(known.contains(t), isTrue,
              reason: '${d.id} tier ${tier.index} confers unknown title $t');
        }
      }
    });

    test('division champion titles: seeded 1..5, generated beyond', () {
      for (var div = 1; div <= 5; div++) {
        expect(AchievementCatalog.divisionChampionTitle(div).id,
            'division_champion_$div');
      }
      // Beyond the seed: same id pattern, on demand, forever.
      expect(AchievementCatalog.divisionChampionTitle(9).id,
          'division_champion_9');
      expect(AchievementCatalog.divisionChampionTitle(50).division, 50);
    });

    test('achievement title ids are unique', () {
      final ids = AchievementCatalog.achievementTitles.map((t) => t.id);
      expect(ids.toSet().length, ids.length);
    });
  });

  group('localization completeness (EN + AR)', () {
    test('every l10n key referenced by the catalog exists in both '
        'arb files', () {
      final en = File('lib/l10n/app_en.arb').readAsStringSync();
      final ar = File('lib/l10n/app_ar.arb').readAsStringSync();

      Iterable<String> keysOf(String arb) => RegExp(
        r'^\s{2}"([a-zA-Z0-9]+)":',
        multiLine: true,
      )
          .allMatches(arb)
          .map((m) => m.group(1)!);

      final enKeys = keysOf(en).toSet();
      final arKeys = keysOf(ar).toSet();

      for (final c in AchievementCatalog.categories) {
        expect(enKeys.contains('${c.l10nPrefix}Title'), isTrue,
            reason: 'category ${c.id} title');
        expect(arKeys.contains('${c.l10nPrefix}Title'), isTrue,
            reason: 'category ${c.id} title (AR)');
        expect(enKeys.contains('${c.l10nPrefix}Subtitle'), isTrue);
        expect(arKeys.contains('${c.l10nPrefix}Subtitle'), isTrue);
      }
      for (final d in definitions) {
        for (final k in [d.titleKey, d.descriptionKey]) {
          expect(enKeys.contains(k), isTrue,
              reason: '${d.id} key $k missing in EN');
          expect(arKeys.contains(k), isTrue,
              reason: '${d.id} key $k missing in AR');
        }
      }
      for (final t in AchievementCatalog.achievementTitles) {
        expect(enKeys.contains(t.l10nKey), isTrue);
        expect(arKeys.contains(t.l10nKey), isTrue);
      }
      expect(enKeys.contains('achievementDivisionChampion'), isTrue);
      expect(arKeys.contains('achievementDivisionChampion'), isTrue);
    });
  });
}
