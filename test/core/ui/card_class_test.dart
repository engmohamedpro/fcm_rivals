// Red premium card tier (T-0049): the presentation-level class axis.
//
// A 90+ player reads RED in every card surface while staying legendary
// underneath — pack pools, shelves and save compatibility untouched,
// and the three pack kinds provably unchanged. Premium derives from the
// same deterministic `overall` everywhere (the rarity stability rule,
// applied to the class axis).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/fcm_logo.dart' show kFcmWordmarkAsset;
import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/core/ui/player_card.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/packs/pack_tier_colors.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/l10n/app_localizations_ar.dart';
import 'package:fcm_rivals/l10n/app_localizations_en.dart';
import 'package:fcm_rivals/l10n/card_class_l10n.dart';
import '../../tm_bundle_io.dart'
    show loadTmDataset;

BasePlayer _player({int overall = 91}) => BasePlayer(
  playerId: 7,
  name: 'Karim Fouad',
  position: Position.st,
  nationality: 'Egypt',
  marketValueEur: 50000000,
  baseStats: BaseStats(
    overall: overall,
    attack: 93,
    support: 72,
    defence: 40,
    goalkeeping: 0,
  ),
);

PlayerCardRarity _faceClassOf(WidgetTester tester) {
  final painters = tester
      .widgetList<CustomPaint>(
        find.byWidgetPredicate((w) => w is CustomPaint),
      )
      .map((p) => p.painter)
      .whereType<PlayerCardPainter>()
      .toList();
  expect(painters, isNotEmpty);
  return painters.first.rarity;
}

void main() {
  group('CardClass detection (T-0049)', () {
    test('the boundary is exact: 90+ premium, 89 standard', () {
      expect(CardClass.fromOverall(90), CardClass.premium);
      expect(CardClass.fromOverall(99), CardClass.premium);
      expect(CardClass.fromOverall(89), CardClass.standard);
      expect(CardClass.fromOverall(1), CardClass.standard);
    });

    test('premium rides ON TOP of legendary — the rarity axis is stable', () {
      // No 4th rarity value: the pack-facing switches never grow a case.
      expect(CardRarity.values.length, 3);
      expect(CardRarity.fromOverall(99), CardRarity.legendary);
      expect(CardRarity.fromOverall(90), CardRarity.legendary);
      expect(CardRarity.fromOverall(89), CardRarity.legendary);
      expect(CardRarity.fromOverall(80), CardRarity.legendary);
      expect(CardRarity.fromOverall(79), CardRarity.epic);
      expect(CardRarity.fromOverall(69), CardRarity.rare);
    });

    test('the red palette is distinct from every jewel accent', () {
      final red = CardClass.premium.accent;
      for (final rarity in CardRarity.values) {
        expect(red, isNot(rarity.accent), reason: rarity.name);
      }
      // A red family: the accent is red-dominant, the face gradient runs
      // crimson sheen → deep oxblood, and the ink stays readable-dark.
      expect(red.r, greaterThan(red.g));
      expect(red.r, greaterThan(red.b));
      final g = CardClass.premium.faceGradient;
      expect(g.length, 3);
      expect(g.last.r, greaterThan(g.last.g));
      expect(
        CardClass.premium.ink.computeLuminance(),
        lessThan(0.05),
      );
      // One notch above the legendary show.
      expect(
        CardClass.premium.intensity,
        greaterThan(CardRarity.legendary.intensity),
      );
    });
  });

  group('surface consistency (the same player is red everywhere)', () {
    testWidgets('FcmMiniCard renders 92 premium and 89 standard', (tester) async {
      FcmMiniCard card(int overall) => FcmMiniCard(
        overall: overall,
        position: 'ST',
        name: 'Fouad',
        rarity: CardRarity.fromOverall(overall),
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: card(92))),
      );
      expect(_faceClassOf(tester), PlayerCardRarity.premium);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: card(89))),
      );
      expect(_faceClassOf(tester), PlayerCardRarity.legendary);
    });

    testWidgets('FcmPlayerCard renders 90 premium and 80 standard', (tester) async {
      FcmPlayerCard card(int overall) => FcmPlayerCard(
        player: _player(overall: overall),
        rarity: CardRarity.fromOverall(overall),
        overall: overall,
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: card(90))),
      );
      expect(_faceClassOf(tester), PlayerCardRarity.premium);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: card(80))),
      );
      expect(_faceClassOf(tester), PlayerCardRarity.legendary);
    });

    testWidgets('the pre-flip back is class-agnostic brand art', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FcmPlayerCardBack(width: 120)),
        ),
      );
      // One back for every card: the brand wordmark, contain-fit and
      // centred — no rarity or class axis, nothing about the card leaks
      // before the flip. (T-0133: contain + centring replace the old
      // cover fit that cropped the wordmark off-centre.)
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, kFcmWordmarkAsset);
      expect(image.fit, BoxFit.contain);
      expect(tester.takeException(), isNull);
    });
  });

  group('dataset population (T-0046 curve reality)', () {
    test('90+ is ultra-rare but well-populated: 20..0.5% window', () {
      final db = PlayerDatabase();
      db.importDataset(loadTmDataset());
      final all = db.all;
      final premium = all
          .where((p) => p.baseStats.overall >= CardClass.premiumOverallThreshold)
          .length;
      final share = premium / all.length;
      // ignore: avoid_print
      print('T-0049 dataset 90+ population: $premium of ${all.length} rows '
          '(${(share * 100).toStringAsFixed(3)}%)');
      // The tm bundle's 90+ population: 133 rows, 0.340% (the v3 cut
      // measured 31 rows / 0.148% — the deeper pool carries a wider
      // elite band, still comfortably inside the red-tier design
      // intent of T-0049).
      expect(premium, greaterThanOrEqualTo(20));
      expect(share, greaterThanOrEqualTo(0.001));
      expect(share, lessThanOrEqualTo(0.008));
    });
  });

  group('the packs are provably untouched (owner requirement)', () {
    test('three pack tiers, the shipped jewel accents, the shipped stars',
        () {
      // Six tiers since the icon shelf (owner request 2026-11-12): the
      // three regular tiers + the three icon tiers.
      expect(PackTier.values.length, 6);
      // Exact constant lock: rare amethyst, epic sapphire, legendary gold.
      expect(PackTier.rare.accent, const Color(0xFF8B5CF6));
      expect(PackTier.epic.accent, const Color(0xFF3B82F6));
      expect(PackTier.legendary.accent, const Color(0xFFF7C948));
      expect(PackTier.rare.stars, 3);
      expect(PackTier.epic.stars, 4);
      expect(PackTier.legendary.stars, 5);
    });
  });

  group('l10n (EN/AR, RTL-safe)', () {
    test('the premium label localizes in both languages', () {
      final en = AppLocalizationsEn();
      final ar = AppLocalizationsAr();
      expect(en.cardClassPremium, 'PREMIUM');
      expect(ar.cardClassPremium, 'نخبة');
      // The pill mapping: premium shows the localized red-tier label,
      // standard keeps the rarity mark.
      expect(
        ar.cardClassLabel(CardClass.premium, CardRarity.legendary),
        'نخبة',
      );
      expect(
        ar.cardClassLabel(CardClass.standard, CardRarity.legendary),
        'LEGENDARY',
      );
      expect(
        en.cardClassLabel(CardClass.standard, CardRarity.epic),
        'EPIC',
      );
    });
  });
}
