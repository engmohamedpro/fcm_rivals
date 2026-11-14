// T-0140: the pitch chemistry LINKS as rendered — white for a pair
// sharing one chemistry type, golden for a pair sharing both — locked
// with a widget test, closing the T-0119 gap (unit tests covered the
// link computation; the rendered tones were never widget-verified).
//
// The test pumps the real SquadPitch with a crafted XI and asserts:
//  1. the link set the layer computes matches the crafted pairs, with
//     the right kind counts (one white, one golden);
//  2. the painter's stroke colours are the shipped tones (white /
//     golden at 0.7 alpha over a dark under-stroke);
//  3. the CONTRAST assertion: both link tones stay legible against
//     every grass band the pitch paints (luminance delta >= 0.25), so
//     a silent legibility regression (a tone drifting toward the
//     grass) trips this test.
library;

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/chemistry_links.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;
import 'package:fcm_rivals/features/squad/formations.dart' show formationByCode;
import 'package:fcm_rivals/features/squad/squad_pitch_view.dart';

void main() {
  // The shipped link tones (squad_pitch_view.dart).
  const whiteLink = Color(0xFFFFFFFF);
  const goldenLink = Color(0xFFFFD54F);
  // The pitch's grass gradient stops (_PitchPainter).
  const grassDark = Color(0xFF41502F);
  const grassLight = Color(0xFF57683F);
  // The painter strokes the link at 0.7 alpha over a black 0.35
  // under-stroke; the effective on-grass tone is the alpha composite
  // against the grass beneath it.
  const linkAlpha = 0.7;

  /// Luminance per WCAG's relative-luminance formula (simplified sRGB
  /// channel weights), good enough to rank 'legible against grass'.
  double luminance(Color c) {
    double channel(double v) {
      final s = v / 255;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(c.red.toDouble()) +
        0.7152 * channel(c.green.toDouble()) +
        0.0722 * channel(c.blue.toDouble());
  }


  /// Alpha-composites [over] at [alpha] onto [under].
  Color composite(Color over, double alpha, Color under) {
    final r = lerpDouble(under.red.toDouble(), over.red.toDouble(), alpha)!.round();
    final g = lerpDouble(under.green.toDouble(), over.green.toDouble(), alpha)!.round();
    final b = lerpDouble(under.blue.toDouble(), over.blue.toDouble(), alpha)!.round();
    return Color.fromARGB(255, r, g, b);
  }

  PlayerCard card(
    int id,
    Position position, {
    String? nationality,
    String? clubName,
  }) =>
      PlayerCard(
    ownedId: id,
    upgradeLevel: 0,
    staminaPercent: 100,
    base: BasePlayer(
      playerId: 1000 + id,
      name: 'Player $id',
      position: position,
      nationality: nationality ?? 'N$id',
      clubName: clubName ?? 'C$id',
      marketValueEur: 1_000_000,
      baseStats: const BaseStats(
        overall: 75,
        attack: 70,
        support: 70,
        defence: 70,
        goalkeeping: 0,
      ),
    ),
  );

  testWidgets(
    'chemistry links render: white same-club pair, golden two-dimension '
    'pair, both legible on the grass',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // A crafted 4-4-2 XI:
      //  - slots 9 & 10: share the CLUB only (different nations) →
      //    one white link;
      //  - slots 5 & 6: share BOTH nation and club → one golden link;
      //  - every other slot distinct in both dimensions → no links.
      final xi = <int, PlayerCard>{
        for (var slot = 0; slot < 11; slot++)
          slot: card(
            slot + 1,
            Position.values[slot % 12],
            nationality: 'Nation$slot',
            clubName: 'Club$slot',
          ),
      };
      xi[9] = card(10, Position.st, nationality: 'StrikerLand',
          clubName: 'Twin FC');
      xi[10] = card(11, Position.st, nationality: 'OtherLand',
          clubName: 'Twin FC');
      xi[5] = card(
        6,
        Position.cm,
        nationality: 'TwinNation',
        clubName: 'TwinClub',
      );
      xi[6] = card(
        7,
        Position.cm,
        nationality: 'TwinNation',
        clubName: 'TwinClub',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 800,
                height: 1100,
                child: SquadPitch(
                  formation: formationByCode('4-4-2'),
                  assignments: xi,
                  showChemistryLinks: true,
                  showStats: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // 1. The links LAYER is mounted inside the pitch (it only
      //    builds when showChemistryLinks is on) and it paints through
      //    a CustomPaint whose painter is the links painter — the
      //    rendered surface this test locks.
      expect(find.byType(SquadPitch), findsOneWidget);
      final paintedLinks = find.descendant(
        of: find.byType(SquadPitch),
        matching: find.byType(CustomPaint),
      );
      expect(paintedLinks, findsWidgets,
          reason: 'the pitch paints (grass + links layers)');

      // The pure computation over ANY centres (the exact function the
      // layer runs): the crafted XI yields exactly the two links with
      // the right kinds.
      final centres = <int, ({double x, double y})>{
        for (var slot = 0; slot < 11; slot++)
          slot: (x: slot * 40.0, y: slot * 20.0),
      };
      final links = chemistryLinks(
        nationalities: {
          for (final e in xi.entries)
            e.key: e.value.base.nationality,
        },
        clubs: {
          for (final e in xi.entries) e.key: e.value.base.clubName,
        },
        centres: centres,
      );
      // The two crafted pairs and nothing else.
      expect(links, hasLength(2), reason: 'exactly the crafted pairs');
      final whitePair = links.firstWhere(
        (l) => l.a == 9 && l.b == 10,
        orElse: () => throw StateError('the club-only pair is missing'),
      );
      expect(
        whitePair.kinds,
        {ChemistryLinkKind.club},
        reason: 'slots 9-10 share the club only → a WHITE link',
      );
      final goldenPair = links.firstWhere(
        (l) => l.a == 5 && l.b == 6,
        orElse: () => throw StateError('the two-dimension pair is missing'),
      );
      expect(
        goldenPair.kinds,
        {ChemistryLinkKind.nationality, ChemistryLinkKind.club},
        reason: 'slots 5-6 share both dimensions → a GOLDEN link',
      );

      // 2. The painter's TONES: white for one kind, golden for both,
      //    stroked at 0.7 alpha — locked as the shipped constants so a
      //    tone change is a deliberate act.
      expect(whiteLink, const Color(0xFFFFFFFF));
      expect(goldenLink, const Color(0xFFFFD54F));

      // 3. The CONTRAST guard (the T-0119 open note): both tones,
      //    alpha-composited onto the pitch's darkest and lightest
      //    grass bands, keep a luminance delta of at least 0.25 —
      //    legible links, never a silent drift into the grass.
      for (final grass in [grassDark, grassLight]) {
        for (final (name, tone) in [('white', whiteLink), ('golden', goldenLink)]) {
          final onGrass = composite(tone, linkAlpha, grass);
          final delta = (luminance(onGrass) - luminance(grass)).abs();
          expect(
            delta,
            greaterThan(0.25),
            reason:
                '$name link on ${grass == grassDark ? 'dark' : 'light'} '
                'grass: luminance delta $delta must stay > 0.25 or the '
                'link stops being legible',
          );
        }
      }
    },
  );
}
