// The third reveal timeline (T-0050): the red premium pack opening.
//
// Three escalating openings: ordinary (rare/epic), golden (legendary
// 80-89), red (premium 90+). The selection keys on the same deterministic
// overall both axes derive from; the sealed pack itself stays exactly as
// it is — the red is discovered at the reveal moment.
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/packs/pack_reveal_timeline.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/l10n/app_localizations_ar.dart';
import 'package:fcm_rivals/l10n/app_localizations_en.dart';

RevealTimeline timelineFor(int overall) => RevealTimeline.revealTimelineFor(
  CardRarity.fromOverall(overall),
  CardClass.fromOverall(overall),
);

void main() {
  group('three-way timeline selection (T-0050)', () {
    test('premium 90+ → the red timeline; legendary 80-89 → golden; '
        'rare/epic → ordinary', () {
      final premium = timelineFor(92);
      final golden = timelineFor(85);
      final ordinaryEpic = timelineFor(75);
      final ordinaryRare = timelineFor(65);

      expect(premium, RevealTimeline.premiumTimeline);
      expect(golden, RevealTimeline.legendaryTimeline);
      expect(ordinaryEpic, RevealTimeline.normalTimeline);
      expect(ordinaryRare, RevealTimeline.normalTimeline);

      // The red escalation beat: a second finale wave the golden
      // timeline does not have, on top of the full legendary stagecraft.
      expect(premium.finale2, isNotNull);
      expect(golden.finale2, isNull);
      expect(ordinaryEpic.finale2, isNull);
      expect(premium.isLegend, isTrue,
          reason: 'the premium reveal runs the whole golden stagecraft');
    });

    test('the premium duration sits in the 18-22s band; the other two '
        'timelines are unchanged from the T-0049 state', () {
      final ms = RevealTimeline.premiumTimeline.duration.inMilliseconds;
      // ignore: avoid_print
      print('T-0050 premium reveal duration: ${ms / 1000}s');
      expect(ms, greaterThanOrEqualTo(18000));
      expect(ms, lessThanOrEqualTo(22000));
      expect(
        RevealTimeline.normalTimeline.duration,
        const Duration(milliseconds: 8000),
      );
      expect(
        RevealTimeline.legendaryTimeline.duration,
        const Duration(milliseconds: 17000),
      );
      // The intensity ladder extends to ≈2.6 (~30% above 2.0).
      // ignore: avoid_print
      print('T-0050 premium reveal intensity: $kPremiumRevealIntensity');
      expect(kPremiumRevealIntensity, greaterThan(2.0));
      expect(kPremiumRevealIntensity, lessThanOrEqualTo(2.6));
    });
  });

  group('dataset-backed selection (T-0050)', () {
    test('a seeded draw pulls until a 90+ appears — it selects the red '
        'timeline; the drawn rarity ladder prints', () {
      final db = PlayerDatabase();
      db.importDatasetFromJson(
        io.File('assets/data/players_v1.json').readAsStringSync(),
      );
      final players = db.all.toList();
      expect(players, isNotEmpty);
      final random = math.Random(20261107);
      BasePlayer? premium;
      final pulledRarities = <String, String>{};
      for (var i = 0; i < players.length && premium == null; i++) {
        final p = players[random.nextInt(players.length)];
        final rarity = CardRarity.fromOverall(p.baseStats.overall);
        final cardClass = CardClass.fromOverall(p.baseStats.overall);
        final timeline = RevealTimeline.revealTimelineFor(rarity, cardClass);
        pulledRarities[rarity.name] = timeline == RevealTimeline.premiumTimeline
            ? 'red'
            : timeline == RevealTimeline.legendaryTimeline
            ? 'golden'
            : 'ordinary';
        if (cardClass == CardClass.premium) premium = p;
      }
      expect(premium, isNotNull,
          reason: 'the dataset has 31 players at 90+ (T-0049) — a seeded '
              'sweep over 20,876 rows must meet one');
      // ignore: avoid_print
      print('T-0050 seeded draw: first 90+ is ${premium!.name} '
          '(OVR ${premium.baseStats.overall}) → red timeline; '
          'selected timelines per rarity so far: $pulledRarities');
      expect(
        RevealTimeline.revealTimelineFor(
          CardRarity.fromOverall(premium.baseStats.overall),
          CardClass.fromOverall(premium.baseStats.overall),
        ),
        RevealTimeline.premiumTimeline,
      );
    });

    test('the worst-case particle budget is bounded and printed', () {
      // 60 × premium intensity main sparks + the richer finale set —
      // the reveal paints at most this many particles at once.
      final mainSparks = (60 * kPremiumRevealIntensity).round();
      const finaleSparks = 120;
      final budget = mainSparks + finaleSparks;
      // ignore: avoid_print
      print('T-0050 particle budget, premium reveal worst case: $budget '
          '($mainSparks main + $finaleSparks finale)');
      expect(budget, lessThanOrEqualTo(300));
      expect(mainSparks, 156);
    });
  });

  group('the sealed pack provably unchanged (T-0050)', () {
    test('three pack tiers, the shipped accents, the shipped stars', () {
      expect(PackTier.values.length, 3);
      expect(PackTier.rare.accent, const Color(0xFF8B5CF6));
      expect(PackTier.epic.accent, const Color(0xFF3B82F6));
      expect(PackTier.legendary.accent, const Color(0xFFF7C948));
      expect(PackTier.rare.stars, 3);
      expect(PackTier.epic.stars, 4);
      expect(PackTier.legendary.stars, 5);
    });

    test('the premium banner localizes in both languages', () {
      expect(AppLocalizationsEn().revealBannerPremium, 'PREMIUM PULL!');
      expect(AppLocalizationsAr().revealBannerPremium, 'سحب النخبة!');
    });
  });
}
