// The GOAL announcement moment (T-0116): the banner's own contracts —
// what shows, when it clears, what it never does.
//
// The banner is the LOUD channel (the commentary card stays the
// informative one) and is deliberately minimal: the word "GOAL!" and the
// scorer's small player card flipping into view, ~2.4s, then a
// rise-and-fade exit. No crest, team name, scorer name or score. It never
// blocks input (IgnorePointer), restarts on a second goal instead of
// queueing, and tells the host once when it completes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/core/ui/player_card.dart';
import 'package:fcm_rivals/features/match/goal_banner.dart';

Widget _host(GoalBanner banner) => MaterialApp(
  home: Scaffold(body: Center(child: banner)),
);

const _card = GoalScorerCard(rating: 91, position: 'ST', flag: '🇪🇬');

void main() {
  testWidgets('a goal shows only the GOAL! text, then clears', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      _host(
        GoalBanner(
          scorerName: 'P 9',
          scoreline: '2 - 1',
          color: FcmColors.gold,
          onFinished: () => finished++,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('GOAL!'), findsOneWidget);
    // Identity only: the scorer name and score are NOT drawn.
    expect(find.text('P 9'), findsNothing);
    expect(find.text('2 - 1'), findsNothing);

    // The full lifetime passes: the banner completes and reports once.
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(finished, 1, reason: 'the host is told exactly once');
  });

  testWidgets('the scorer card flips from its back into the face', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        GoalBanner(
          scorerName: 'Striker',
          scoreline: '1 - 0',
          color: FcmColors.gold,
          scorerCard: _card,
        ),
      ),
    );
    // Right after mount the card is face-down (back showing).
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('GOAL!'), findsOneWidget);
    expect(find.byType(PlayerCardBackWidget), findsOneWidget);
    expect(find.byType(PlayerCardWidget), findsNothing);

    // Past the flip (it ends at 46% of the 2.4s run): the face is up.
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.byType(PlayerCardWidget), findsOneWidget);
    expect(find.byType(PlayerCardBackWidget), findsNothing);
    // Still no extra text: just the wordmark (the card paints its own
    // rating/position inside the widget).
    expect(find.text('Striker'), findsNothing);
    expect(find.text('1 - 0'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('the banner never blocks input', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              GestureDetector(
                onTap: () => taps++,
                // A coloured child: an empty SizedBox.expand is
                // transparent to hit tests (hitTestSelf false), which
                // would fail the tap for the wrong reason.
                child: Container(color: Colors.blueGrey),
              ),
              Center(
                child: GoalBanner(
                  scorerName: 'P 9',
                  scoreline: '1 - 0',
                  color: FcmColors.gold,
                  scorerCard: _card,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Tap THROUGH the banner: IgnorePointer means the tap lands on the
    // GestureDetector underneath.
    await tester.tap(find.byType(GoalBanner));
    expect(taps, 1, reason: 'IgnorePointer: celebrations never block play');
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('a second goal restarts the banner, never queues', (
    tester,
  ) async {
    Widget banner(String scorer, String score) => _host(
      GoalBanner(
        scorerName: scorer,
        scoreline: score,
        color: FcmColors.gold,
        scorerCard: _card,
      ),
    );
    await tester.pumpWidget(banner('P 9', '1 - 0'));
    // Past the flip: the card is face-up.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(PlayerCardWidget), findsOneWidget);

    // A second goal lands mid-flight: the run restarts from the top, so
    // the card is face-down again.
    await tester.pumpWidget(banner('P 4', '2 - 0'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PlayerCardBackWidget), findsOneWidget);
    expect(find.byType(PlayerCardWidget), findsNothing);
    // Two banners never stack: one wordmark on the screen.
    expect(find.text('GOAL!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('an opponent goal renders the reduced-intensity variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        GoalBanner(
          scorerName: 'P 7',
          scoreline: '0 - 1',
          color: FcmColors.danger,
          isUserGoal: false,
          scorerCard: _card,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    // Same announcement, same content — the intensity is in the styling
    // (card size, glow, sparks), not in missing content.
    expect(find.text('GOAL!'), findsOneWidget);
    expect(find.byType(PlayerCardWidget), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('the late portrait lookup enriches the card, never restarts', (
    tester,
  ) async {
    Widget banner(GoalScorerCard card) => _host(
      GoalBanner(
        scorerName: 'Striker',
        scoreline: '1 - 0',
        color: FcmColors.gold,
        scorerCard: card,
      ),
    );
    await tester.pumpWidget(
      banner(const GoalScorerCard(rating: 80, position: 'ST')),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(PlayerCardWidget), findsOneWidget);

    // Same goal (same scorer + score), richer card data: the run goes on
    // face-up — a restart would flip the card back over.
    await tester.pumpWidget(
      banner(const GoalScorerCard(rating: 84, position: 'ST', flag: '🇪🇬')),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PlayerCardWidget), findsOneWidget);
    expect(find.byType(PlayerCardBackWidget), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('the controller is disposed with the widget', (tester) async {
    await tester.pumpWidget(
      _host(
        GoalBanner(
          scorerName: 'P 9',
          scoreline: '1 - 0',
          color: FcmColors.gold,
          scorerCard: _card,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Unmount: no leaked-controller errors surface in the test output.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
