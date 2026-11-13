// The merge moment: two copies fly in, collide, and the upgraded card
// appears with its new level. Taps are ignored until the collision.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/player_card.dart' show FcmPlayerCard;
import 'package:fcm_rivals/features/collection/card_merge_animation.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;

const _base = BasePlayer(
  playerId: 1007,
  name: 'Karim Fouad',
  position: Position.st,
  nationality: 'Egypt',
  marketValueEur: 5_000_000,
  baseStats: BaseStats(
    overall: 80,
    attack: 82,
    support: 75,
    defence: 40,
    goalkeeping: 0,
  ),
);

PlayerCard _copy(int id, int level) =>
    PlayerCard(ownedId: id, base: _base, upgradeLevel: level);

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(onPressed: () {}, child: const Text('GO')),
        ),
      ),
    ),
  );
  final context = tester.element(find.text('GO'));
  showCardMergeAnimation(
    context,
    target: _copy(1, 1),
    duplicate: _copy(2, 0),
    newLevel: 2,
  );
  await tester.pump();
}

void main() {
  testWidgets('two cards fly in, then one merged card with the new level', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _open(tester);

    // Before the collision: both copies are on screen, no level banner.
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(FcmPlayerCard), findsNWidgets(2));
    expect(find.text('LEVEL +2'), findsNothing);

    // After the collision (impact at ~1.9s of 3.8s): one card, banner in.
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(FcmPlayerCard), findsOneWidget);
    expect(find.text('LEVEL +2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('taps are ignored before the collision, close after it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _open(tester);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.tapAt(const Offset(400, 800));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CardMergeAnimation), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2400));
    await tester.tapAt(const Offset(400, 800));
    // The tap pops the route: the 180ms reverse animation runs and the
    // overlay entry comes down on a following frame, so a single timed
    // pump is not enough — settle the teardown out instead.
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    expect(find.byType(CardMergeAnimation), findsNothing);
  });
}
