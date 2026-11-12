// The GOAL announcement moment (T-0116): the banner's own contracts —
// what shows, when it clears, what it never does.
//
// The banner is the LOUD channel (the commentary card stays the
// informative one): scoring team's crest + name, the scorer's small
// player card flipping into view, the new score, ~2.6s, a rise-and-fade
// exit. It never blocks input (IgnorePointer), restarts on a second goal
// instead of queueing, and tells the host once when it completes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/crest.dart';
import 'package:fcm_rivals/core/ui/fcm_crest.dart';
import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/core/ui/player_card.dart';
import 'package:fcm_rivals/features/match/goal_banner.dart';

Widget _host(GoalBanner banner) => MaterialApp(
  home: Scaffold(body: Center(child: banner)),
);

void main() {
  testWidgets('a goal announces: wordmark + scorer + score, then clears', (
    tester,
  ) async {
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

    // Entrance is mid-flight right after mount.
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('GOAL!'), findsOneWidget);
    expect(find.text('P 9'), findsOneWidget);
    expect(find.text('2 - 1'), findsOneWidget);

    // The full lifetime passes: the banner completes and reports once.
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(finished, 1, reason: 'the host is told exactly once');
  });

  testWidgets('the banner never blocks input', (tester) async {
    var taps = 0;
    // ONE tree: the tappable surface under the celebrating banner.
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
  });

  testWidgets('a second goal restarts the banner, never queues', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        GoalBanner(
          scorerName: 'P 9',
          scoreline: '1 - 0',
          color: FcmColors.gold,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // A second goal lands mid-flight: the banner restarts from the top
    // with the NEW scorer and score.
    await tester.pumpWidget(
      _host(
        GoalBanner(
          scorerName: 'P 4',
          scoreline: '2 - 0',
          color: FcmColors.gold,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('GOAL!'), findsOneWidget);
    expect(find.text('P 4'), findsOneWidget);
    expect(find.text('2 - 0'), findsOneWidget);
    expect(find.text('P 9'), findsNothing, reason: 'the old moment is gone');
    // Two banners never stack: one wordmark on the screen.
    final marks = find.text('GOAL!');
    expect(tester.widgetList<Text>(marks).length, 1);
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
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    // Same announcement, same fields — the intensity is in the styling
    // (scale/glow), not in missing content.
    expect(find.text('GOAL!'), findsOneWidget);
    expect(find.text('P 7'), findsOneWidget);
    expect(find.text('0 - 1'), findsOneWidget);
  });

  testWidgets('a goal names the scoring team: crest + upper-case name', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        GoalBanner(
          scorerName: 'P 9',
          scoreline: '1 - 0',
          color: FcmColors.gold,
          teamName: 'Nile Falcons',
          crest: CrestSpec.derived('Nile Falcons'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FcmCrest), findsOneWidget);
    expect(find.text('NILE FALCONS'), findsOneWidget);
    // No scorer card data: the card never mounts, the name still shows.
    expect(find.byType(PlayerCardWidget), findsNothing);
    expect(find.text('P 9'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
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
          scorerCard: const GoalScorerCard(rating: 91, position: 'ST'),
        ),
      ),
    );
    // Right after mount the card is face-down (back showing).
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PlayerCardBackWidget), findsOneWidget);
    expect(find.byType(PlayerCardWidget), findsNothing);

    // Past the flip (it ends at 52% of the 2.6s run): the face is up.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(PlayerCardWidget), findsOneWidget);
    expect(find.byType(PlayerCardBackWidget), findsNothing);
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
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byType(PlayerCardWidget), findsOneWidget);

    // Same goal (same scorer + score), richer card data: the run goes on
    // face-up — a restart would flip the card back over.
    await tester.pumpWidget(
      banner(
        const GoalScorerCard(
          rating: 84,
          position: 'ST',
          flag: '🇪🇬',
        ),
      ),
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
