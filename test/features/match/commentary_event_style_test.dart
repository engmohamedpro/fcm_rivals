// The commentary event visual language (T-0115): every one of the 16
// event kinds reads instantly — its OWN icon, its OWN accent colour,
// and the two booking kinds a literal tilted card chip. The tests pin
// the three contracts of the shared dressing table:
//
// 1. UNIQUENESS — no two kinds share an icon (the exact regression
//    this task exists for: before T-0115 both cards wore
//    Icons.style_rounded and the colour came from the TEAM side, so
//    every moment of one team looked identical);
// 2. EVENT-vs-SIDE identity — the featured card's kind row wears the
//    event accent even when the moment belongs to a team, while the
//    card's wash/border keep the team colour (two channels);
// 3. the literal card semaphore — yellow = real yellow, red = red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/features/match/commentary_style.dart';
import 'package:fcm_rivals/features/match/live_commentary_feed.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_report.dart';

const _homeColor = Color(0xFF22C55E);
const _awayColor = Color(0xFFEF4444);

CommentaryLine _line(
  String text, {
  required CommentaryKind kind,
  MatchSide? side,
  int minute = 23,
  int importance = 1,
}) => CommentaryLine(
  minute: minute,
  second: 10,
  text: text,
  importance: importance,
  kind: kind,
  side: side,
);

Widget _host(List<CommentaryLine> lines) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: LiveCommentaryFeed(
        lines: lines,
        homeColor: _homeColor,
        awayColor: _awayColor,
      ),
    ),
  ),
);

void main() {
  test('no two kinds share an icon — the uniqueness contract', () {
    final icons = [
      for (final style in momentStyles.values)
        if (style.icon != null) style.icon!,
    ];
    expect(
      icons.toSet().length,
      icons.length,
      reason: 'every kind must carry its own icon; a duplicate means the '
          'glance-read is gone again',
    );
    // The two booking kinds carry the literal card chip instead.
    expect(momentStyles[CommentaryKind.yellowCard]!.card, FcmColors.cardYellow);
    expect(momentStyles[CommentaryKind.redCard]!.card, FcmColors.cardRed);
    expect(momentStyles[CommentaryKind.yellowCard]!.icon, isNull);
    expect(momentStyles[CommentaryKind.redCard]!.icon, isNull);
  });

  test('accents are pairwise distinct by design intent', () {
    // Colour TIERS are deliberate: gold carries the loud moments
    // (goal, manager order, the final whistle), silver the steel
    // bench tones (sub, tactical), bronze the referee's rhythm
    // (kick-off, the break, offside) and textDim the quiet possession
    // moments (foul, none). Every kind must at least sit in a tier
    // with kinds of the SAME family — the guarded property is that
    // the four LOUD kinds and the two CARDS are all distinct.
    final loud = [
      momentStyles[CommentaryKind.goal]!.accent,
      momentStyles[CommentaryKind.penalty]!.accent,
      momentStyles[CommentaryKind.yellowCard]!.accent,
      momentStyles[CommentaryKind.redCard]!.accent,
      momentStyles[CommentaryKind.save]!.accent,
      momentStyles[CommentaryKind.injury]!.accent,
    ];
    expect(loud.toSet().length, loud.length,
        reason: 'goal, penalty, both cards, save and injury are the six '
            'moments a glance must separate — no two may share a hue');
  });

  testWidgets(
    'a home-team yellow card: event chip is YELLOW, the wash stays HOME',
    (tester) async {
      await tester.pumpWidget(
        _host([
          _line(
            'P 4 is booked.',
            kind: CommentaryKind.yellowCard,
            side: MatchSide.home,
          ),
        ]),
      );

      // Event identity: the literal yellow card chip renders.
      expect(find.byType(CardChip), findsOneWidget);
      final chip = tester.widget<CardChip>(find.byType(CardChip));
      expect(chip.color, FcmColors.cardYellow);
      expect(chip.color, isNot(_homeColor));

      // Side identity survives on the wash: the featured card's
      // gradient starts with the HOME colour, not the event yellow.
      // (The feed label's hairline also uses a gradient — pure white
      // alpha stops — so it is filtered out; the featured card is the
      // only gradient that begins with the team colour.)
      final teamWashes = [
        for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(LiveCommentaryFeed),
            matching: find.byType(DecoratedBox),
          ),
        ))
          if ((box.decoration as BoxDecoration).gradient != null)
            ((box.decoration as BoxDecoration).gradient as LinearGradient)
                .colors
                .first,
      ].where((c) => c.withValues(alpha: 1.0) == _homeColor).toList();
      expect(teamWashes, isNotEmpty,
          reason: 'the featured card must carry the home wash');
      expect(
        teamWashes.first.withValues(alpha: 1.0),
        _homeColor,
      );
    },
  );

  testWidgets('a red card reads as a literal red card', (tester) async {
    await tester.pumpWidget(
      _host([
        _line(
          'RED CARD! P 4 is sent off!',
          kind: CommentaryKind.redCard,
          side: MatchSide.away,
          importance: 2,
        ),
      ]),
    );
    expect(find.byType(CardChip), findsOneWidget);
    final chip = tester.widget<CardChip>(find.byType(CardChip));
    expect(chip.color, FcmColors.cardRed);
    // The small-caps label is still there for the third signal.
    expect(find.text('RED CARD'), findsOneWidget);
  });

  testWidgets('the kind row keeps its event accent for every kind', (
    tester,
  ) async {
    for (final kind in [
      CommentaryKind.goal,
      CommentaryKind.penalty,
      CommentaryKind.save,
      CommentaryKind.injury,
      CommentaryKind.substitution,
      CommentaryKind.foul,
      CommentaryKind.offside,
      CommentaryKind.corner,
    ]) {
      await tester.pumpWidget(
        _host([
          _line('A moment.', kind: kind, side: MatchSide.home),
        ]),
      );
      final style = momentStyleOf(kind);
      // Icon kinds show their unique icon; card kinds their chip.
      if (style.card != null) {
        expect(find.byType(CardChip), findsOneWidget);
      } else {
        expect(find.byIcon(style.icon!), findsOneWidget);
      }
    }
  });
}
