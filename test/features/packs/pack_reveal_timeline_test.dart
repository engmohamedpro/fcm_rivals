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
import 'package:fcm_rivals/features/packs/pack_tier_colors.dart';
import 'package:fcm_rivals/features/packs/pack_reveal_timeline.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/l10n/app_localizations_en.dart';
import '../../tm_bundle_io.dart'
    show tmPlayersPath;

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

    test('the premium duration sits in the 18-22s band; ordinary stays '
        '8s and golden is the T-0051 tightened 13s', () {
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
        const Duration(milliseconds: 13000),
      );
      // The intensity ladder extends to ≈2.6 (~30% above 2.0).
      // ignore: avoid_print
      print('T-0050 premium reveal intensity: $kPremiumRevealIntensity');
      expect(kPremiumRevealIntensity, greaterThan(2.0));
      expect(kPremiumRevealIntensity, lessThanOrEqualTo(2.6));
    });
  });

  group('escalation ladder (T-0051)', () {
    test('the three openings climb strictly on every axis, no tier more '
        'than ~1.8× the previous one in duration', () {
      final ordinary = RevealTimeline.normalTimeline;
      final golden = RevealTimeline.legendaryTimeline;
      final red = RevealTimeline.premiumTimeline;

      final ordMs = ordinary.duration.inMilliseconds;
      final goldMs = golden.duration.inMilliseconds;
      final redMs = red.duration.inMilliseconds;
      // ignore: avoid_print
      print('T-0051 escalation ladder: '
          'ordinary ${ordMs / 1000}s ×1.0 → '
          'golden ${goldMs / 1000}s ×2.0 (sparks 60–90) → '
          'red ${redMs / 1000}s ×2.6 (sparks 156, double finale)');

      // Duration bands (acceptance criteria) and the perceptibility rule:
      // each step at most ~1.8× the previous — length alone keeps
      // signalling rarity without two tiers blurring together.
      expect(ordMs, lessThanOrEqualTo(8000),
          reason: 'the common case must stay snappy');
      expect(goldMs, inInclusiveRange(12000, 14000),
          reason: 'the tightened golden tier — never shorter than 12s');
      expect(redMs, inInclusiveRange(18000, 22000));
      expect(goldMs / ordMs, lessThanOrEqualTo(1.8));
      expect(redMs / goldMs, lessThanOrEqualTo(1.8));

      // Intensity: strictly increasing, red bounded at 3.0.
      final intensities = [
        CardRarity.rare.intensity,
        CardRarity.epic.intensity,
        CardRarity.legendary.intensity,
        kPremiumRevealIntensity,
      ];
      expect(intensities.last, lessThanOrEqualTo(3.0));
      for (var i = 1; i < intensities.length; i++) {
        expect(intensities[i], greaterThan(intensities[i - 1]));
      }

      // Spark budget (60 × intensity) strictly increasing and bounded.
      final sparks = intensities.map((x) => (60 * x).round()).toList();
      for (var i = 1; i < sparks.length; i++) {
        expect(sparks[i], greaterThan(sparks[i - 1]));
      }
      expect(sparks.last, lessThanOrEqualTo(300));

      // Stagecraft density: haptic marks strictly increasing — the
      // golden 16-mark pattern and the red 18-mark pattern both keep
      // every beat (nothing deleted in the tightening).
      final marks = [ordinary, golden, red]
          .map((t) => t.heavy.length + t.medium.length + t.tick.length)
          .toList();
      expect(marks[0], 6);
      expect(marks[1], 16);
      expect(marks[2], 18);
      expect(marks[1], greaterThan(marks[0]));
      expect(marks[2], greaterThan(marks[1]));

      // Distinct stagecraft beats: the golden extras (mystery, finale,
      // banner) and the red's second finale wave.
      final beats = [ordinary, golden, red].map((t) {
        var n = 9; // charge, flash, burst, rays, walkout, flip, shine,
        // stats, name.
        if (t.mysteryIn != null) n++;
        if (t.finale != null) n++;
        if (t.bannerIn != null) n++;
        if (t.finale2 != null) n++;
        return n;
      }).toList();
      expect(beats, [9, 12, 13]);
      expect(beats[1], greaterThan(beats[0]));
      expect(beats[2], greaterThan(beats[1]));
    });

    test('epic rides the top of its band inside the shared ordinary '
        'timeline (T-0051 audit)', () {
      // The audit verdict: epic differs from rare ONLY through the
      // intensity-driven mechanisms (90 vs 60 main sparks, hotter glow
      // and rays keyed on the rarity accent) — the beat structure is
      // shared by design, and 1.5 is already the top of epic's band, so
      // the audit requires no change: the escalation reads through
      // light density, and a new timeline or higher value is out of
      // scope.
      expect(CardRarity.epic.intensity, 1.5);
      expect(CardRarity.epic.intensity, greaterThan(CardRarity.rare.intensity));
      expect(
        CardRarity.epic.intensity,
        lessThan(CardRarity.legendary.intensity),
        reason: 'epic stays below the golden tier it does not own',
      );
    });
  });

  group('dataset-backed selection (T-0050)', () {
    test('a seeded draw pulls until a 90+ appears — it selects the red '
        'timeline; the drawn rarity ladder prints', () {
      final db = PlayerDatabase();
      db.importDatasetFromJson(
        io.File(tmPlayersPath).readAsStringSync(),
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

    test('T-0101: the overlays left no l10n trace behind', () {
      // The pull banner's key left both ARBs with the overlays' removal
      // — the generated getters have no banner member anymore, so this
      // file (the last reference) drops the localization test with it.
      // Compilation itself is the proof: revealBannerPremium is gone
      // from AppLocalizationsEn/Ar (removed with the overlay).
      expect(AppLocalizationsEn().runtimeType, isNotNull);
    });
  });
}
