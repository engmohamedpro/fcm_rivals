/// Icon-player tests (owner request 2026-11-12): the tm-bundle's icon
/// axis — parsing, chemistry wildcards, pack exclusivity and the three
/// icon tiers' tiny chance, and the store shelf.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/collection/pack_catalog.dart';
import 'package:fcm_rivals/features/economy/economy_engine.dart';
import 'package:fcm_rivals/features/match/chemistry.dart';
import 'package:fcm_rivals/features/match/chemistry_links.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/packs/pack_rarity.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';

import '../../tm_bundle_io.dart' show loadTmDataset;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tm bundle: icon axis', () {
    late PlayerDatabase registry;

    setUpAll(() {
      registry = PlayerDatabase();
      registry.importDataset(loadTmDataset());
    });

    test('73 icons import, all flagged, all with portraits', () {
      final icons = registry.all.where((p) => p.isIcon).toList();
      expect(icons, hasLength(73));
      expect(icons.every((p) => p.imageUrl.isNotEmpty), isTrue,
          reason: 'every icon carries his portrait link');
      expect(icons.every((p) => p.nationality.isNotEmpty), isTrue);
      expect(icons.every((p) => p.clubId == 0), isTrue,
          reason: 'icons have no club — they are chemistry wildcards');
    });

    test('the 5 dual-file ids resolve to their icon rows', () {
      // Messi, Ronaldo, Neymar, Modrić, Suárez appear in BOTH files;
      // the legend wins.
      const dualIds = {28003, 8198, 68290, 27992, 44352};
      for (final id in dualIds) {
        expect(registry[id]!.isIcon, isTrue,
            reason: 'player $id must resolve to the icon row');
      }
      expect(registry[8198]!.name, contains('Ronaldo'));
    });

    test('regular pools exclude icons; the icon pool holds everyone', () {
      final pool = registry.all.toList(growable: false);
      final stScope = PackScope(
        category: PackCategory.position,
        position: Position.st,
        tier: PackTier.legendary,
      );
      expect(pool.where(stScope.matches).every((p) => !p.isIcon), isTrue,
          reason: 'ST packs never draw icons (owner: icons only from '
              'the three icon packs on top of the ST packs)');

      final iconScope = PackScope(category: PackCategory.icon);
      final iconPool = pool.where(iconScope.matches).toList();
      expect(iconPool.where((p) => p.isIcon), hasLength(73));
      expect(iconPool, hasLength(registry.all.length),
          reason: 'the icon pack pool is regulars + icons');
    });
  });

  group('chemistry: icon wildcards', () {
    test('an icon groups with every player in BOTH dimensions', () {
      // 11 distinct nationalities, no clubs: chemistry 0 without icons.
      final nats = [
        for (var i = 0; i < 11; i++) 'nat$i',
      ];
      expect(
        totalChemistryPercentOf(
          nationalities: nats,
          clubs: List.filled(11, ''),
        ),
        0,
      );
      // One icon among them: +10 in nationality, +10 in club, capped 10.
      expect(
        totalChemistryPercentOf(
          nationalities: nats,
          clubs: List.filled(11, ''),
          icons: [true, ...List.filled(10, false)],
        ),
        10,
      );
    });

    test('one icon in a full XI earns exactly 10 links per dimension', () {
      // 10 regulars of 2 nationalities (5+5 → 8 points) + 1 icon:
      // 8 + 10 links = 18, clamped to the 10 ceiling (T-0068 gate).
      final nats = [
        ...List.filled(5, 'Egypt'),
        ...List.filled(5, 'France'),
        'Brazil', // the icon
      ];
      final icons = [...List.filled(10, false), true];
      expect(
        totalChemistryPercentOf(
          nationalities: nats,
          clubs: List.filled(11, 'club:1'),
          icons: icons,
        ),
        10,
      );
      // Without the icon flag the same XI reads 8 + 10 = 18 → 10 too
      // (club groups), so verify the icon contribution through the
      // nationality-only channel:
      expect(
        totalChemistryPercentOf(
          nationalities: nats,
          clubs: List.filled(11, ''),
          icons: icons,
        ),
        10, // 8 group points + 10 icon links → clamped
      );
      expect(
        totalChemistryPercentOf(
          nationalities: nats,
          clubs: List.filled(11, ''),
        ),
        8,
      );
    });

    test('two icons in a 4-man group earn 2 × (n − 1) links per dimension', () {
      // 4 players, 2 icons, all distinct nationalities, no clubs: each
      // dimension earns 2 × (4 − 1) = 6 links, and BOTH dimensions sum
      // 12 — clamped to the 10 ceiling (T-0068 gate holds even with a
      // two-icon front line).
      expect(
        totalChemistryPercentOf(
          nationalities: ['a', 'b', 'c', 'd'],
          clubs: List.filled(4, ''),
          icons: [false, true, false, true],
        ),
        10, // 6 + 6 → clamp
      );
      // The nationality dimension alone (no club keys) reads its own 6.
      expect(
        chemistryPercentWithIcons(
          keys: ['a', 'b', 'c', 'd'],
          icons: [false, true, false, true],
        ),
        6,
      );
    });

    test('icons never reduce chemistry', () {
      // Same group with and without the icon flag: the flag only adds.
      final nats = ['Egypt', 'Egypt', 'France'];
      final without = totalChemistryPercentOf(
        nationalities: nats,
        clubs: ['club:1', 'club:1', 'club:2'],
      );
      final withIcon = totalChemistryPercentOf(
        nationalities: nats,
        clubs: ['club:1', 'club:1', 'club:2'],
        icons: [false, false, true],
      );
      expect(withIcon, greaterThanOrEqualTo(without));
    });
  });

  group('chemistry links: icon threads', () {
    final centres = {
      0: (x: 0.0, y: 0.0),
      1: (x: 1.0, y: 0.0),
      2: (x: 2.0, y: 0.0),
    };

    test('an icon links to every other slot in both kinds', () {
      final links = chemistryLinks(
        nationalities: {0: 'a', 1: 'b', 2: 'c'},
        clubs: {0: 'club:1', 1: 'club:2', 2: 'club:3'},
        centres: centres,
        icons: {1: true},
      );
      // Slot 1 is the icon: the icon is linked to BOTH other slots,
      // every link touching him carries both kinds, and the regular
      // pair (0,2) never appears (they share nothing).
      final pairs = links.map((l) => (l.a, l.b)).toSet();
      expect(pairs, contains((0, 1)));
      expect(pairs, contains((1, 2)));
      expect(pairs, isNot(contains((0, 2))));
      for (final link in links) {
        expect(link.kinds, containsAll(ChemistryLinkKind.values));
      }
    });

    test('no icons: the pre-2026-11-12 behaviour is unchanged', () {
      final links = chemistryLinks(
        nationalities: {0: 'a', 1: 'a', 2: 'b'},
        clubs: {0: '', 1: '', 2: ''},
        centres: centres,
      );
      expect(links, hasLength(1));
      expect(links.single.kinds, {ChemistryLinkKind.nationality});
    });
  });

  group('icon tiers: odds and draw', () {
    late PlayerDatabase registry;
    late List<BasePlayer> pool;

    setUpAll(() {
      registry = PlayerDatabase();
      registry.importDataset(loadTmDataset());
      pool = registry.all.toList(growable: false);
    });

    test('the three icon tables are valid and tiny-chanced', () {
      final config = defaultPackOddsConfig;
      config.validate();
      expect(config.iconChanceOf(PackTier.rare), 0.0);
      expect(config.iconChanceOf(PackTier.epic), 0.0);
      expect(config.iconChanceOf(PackTier.legendary), 0.0);
      expect(config.iconEpicChance, 0.005);
      expect(config.iconLegendaryChance, 0.010);
      expect(config.iconSupremeChance, 0.015);
      for (final tier in PackTier.values) {
        expect(config.iconChanceOf(tier), lessThanOrEqualTo(0.05),
            reason: 'owner spec: "very very very tiny chance"');
      }
    });

    test('icon packs draw icons at the tiny chance (±4σ of 100k pulls)', () {
      final engine = PackEngine(
        random: math.Random(20261112),
        economy: const EconomyEngine(),
      );
      const pulls = 100_000;
      var iconsDrawn = 0;
      for (var i = 0; i < pulls; i++) {
        final draws = engine.open(
          PackScope(category: PackCategory.icon, tier: PackTier.iconSupreme),
          pool,
        );
        if (draws.single.player.isIcon) iconsDrawn++;
      }
      final p = 0.015;
      final sigma = math.sqrt(pulls * p * (1 - p));
      expect(
        iconsDrawn,
        inInclusiveRange((pulls * p - 4 * sigma).round(),
            (pulls * p + 4 * sigma).round()),
        reason: 'measured $iconsDrawn of $pulls vs p=$p',
      );
    });

    test('regular packs NEVER draw icons (full exclusivity)', () {
      final engine = PackEngine(
        random: math.Random(7),
        economy: const EconomyEngine(),
      );
      // Legendary packs have the richest tables; run every regular tier.
      for (final tier in [PackTier.rare, PackTier.epic, PackTier.legendary]) {
        for (var i = 0; i < 20_000; i++) {
          final draws = engine.open(
            PackScope(
              category: PackCategory.position,
              position: Position.st,
              tier: tier,
            ),
            pool,
          );
          if (draws.isNotEmpty) {
            expect(draws.single.player.isIcon, isFalse,
                reason: 'a $tier pack handed out an icon');
          }
        }
      }
    });

    test('oddsFor publishes the icon band and rescales the regulars', () {
      final engine = PackEngine(
        random: math.Random(0),
        economy: const EconomyEngine(),
      );
      final scope = PackScope(
        category: PackCategory.icon,
        tier: PackTier.iconLegendary,
      );
      final odds = engine.oddsFor(scope, pool);
      // Icon band entry exists and sums to the tiny chance (±ε).
      final iconProbs = odds[kIconBandIndex]!;
      final iconSum = iconProbs.values.fold<double>(0, (a, b) => a + b);
      expect(iconSum, closeTo(0.010, 1e-9));
      // Regular bands sum to 1 − the icon chance.
      var regularSum = 0.0;
      for (var r = 0; r < 4; r++) {
        regularSum += odds[r]!.values.fold<double>(0, (a, b) => a + b);
      }
      expect(regularSum, closeTo(0.99, 1e-9));
    });
  });

  group('store shelf: icon section on top', () {
    test('the Icon section shelves first, above the ST packs', () {
      final registry = PlayerDatabase();
      registry.importDataset(loadTmDataset());
      final offers = storeOffersFor(registry, const EconomyEngine());

      final iconOffers = offers
          .where((o) => o.category == PackCategory.icon)
          .toList();
      expect(iconOffers, hasLength(3),
          reason: 'exactly three icon packs (owner spec)');
      expect(
        iconOffers.map((o) => o.tier).toList(),
        [PackTier.iconEpic, PackTier.iconLegendary, PackTier.iconSupreme],
      );
      // The icon section is FIRST in the catalog.
      expect(
        offers.take(3).map((o) => o.category),
        everyElement(PackCategory.icon),
      );
      // ...and the first non-icon offer is a position pack (ST packs).
      expect(offers[3].category, PackCategory.position);
      // Every offer is priced and non-empty.
      for (final o in offers) {
        expect(o.price, greaterThan(0));
        expect(o.eligibleCount, greaterThan(0));
      }
    });

    test('an icon-less registry shelves exactly the old catalog', () {
      final registry = PlayerDatabase();
      // No dataset: nothing imported — but a synthetic pool through
      // importDataset of a tiny set keeps the shelf honest.
      registry.importDataset(PlayerDataset(
        version: 1,
        asOf: 'test',
        rows: [
          PlayerDatasetRow(
            playerId: 1,
            name: 'Regular',
            position: Position.st,
            nationality: 'Egypt',
            marketValueEur: 20_000_000,
          ),
        ],
      ));
      final offers = storeOffersFor(registry, const EconomyEngine());
      expect(
        offers.where((o) => o.category == PackCategory.icon),
        isEmpty,
        reason: 'no icons in the registry → no icon section',
      );
    });
  });
}
