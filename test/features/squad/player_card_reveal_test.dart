// Regression tests for the Tactics-tab full-card reveal: tapping a
// player opens a full-screen moment where the card back flips into the
// full-size card, the rating and attributes count up, the name lands
// LAST (masked as dashes until then) and a tap anywhere dismisses it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/player_card.dart'
    show FcmPlayerCard, FcmPlayerCardBack;
import 'package:fcm_rivals/features/squad/player_card_reveal.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;

PlayerCard _card() => PlayerCard(
      ownedId: 7,
      upgradeLevel: 2,
      base: BasePlayer(
        playerId: 1007,
        name: 'Karim Fouad',
        position: Position.st,
        age: 27,
        nationality: 'Egypt',
        club: 'Al Ahly',
        leagueCode: 'EG1',
        marketValueEur: 5_000_000,
        baseStats: const BaseStats(
            overall: 80, attack: 82, support: 75, defence: 40, goalkeeping: 0),
      ),
    );

Widget _host() => MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('REVEAL'),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(_host());
  final context = tester.element(find.text('REVEAL'));
  showPlayerCardReveal(context, card: _card());
  await tester.pump(); // first frame of the route + timeline
}

void main() {
  testWidgets('the back flips into the full card, name lands last',
      (WidgetTester tester) async {
    await _open(tester);

    // Early: the card BACK is showing, the face is still hidden.
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(FcmPlayerCardBack), findsOneWidget);
    expect(find.byType(FcmPlayerCard), findsNothing);

    // Flip finished (0.40 of 2200ms): the full card face is up, but the
    // identity is still masked — the stats are counting.
    await tester.pump(const Duration(milliseconds: 1050));
    expect(find.byType(FcmPlayerCardBack), findsNothing);
    expect(find.byType(FcmPlayerCard), findsOneWidget);
    expect(find.text('— — —'), findsOneWidget);

    // Done: name revealed, upgrade badge and hint in place.
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('KARIM FOUAD'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('TAP TO CLOSE'), findsOneWidget);
    expect(find.byType(FcmPlayerCard), findsOneWidget);
  });

  testWidgets('a tap anywhere dismisses the reveal',
      (WidgetTester tester) async {
    await _open(tester);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.byType(FcmPlayerCard), findsOneWidget);

    // Corner AND centre both close it: the whole overlay is tappable.
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FcmPlayerCard), findsNothing);
    expect(find.byType(FcmPlayerCardBack), findsNothing);
    expect(find.text('TAP TO CLOSE'), findsNothing);

    // Re-open and close from the centre (over the card) too.
    final context = tester.element(find.text('REVEAL'));
    showPlayerCardReveal(context, card: _card());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.byType(FcmPlayerCard), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(FcmPlayerCard)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FcmPlayerCard), findsNothing);
  });
}
