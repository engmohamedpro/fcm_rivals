// Live commentary ticker (FM-style one-moment lower third): the bar
// shows ONE line at a time in a fixed uniform — same height, same text
// size, one line of text (ellipsis) — and differs only in dressing:
// per-team background tint from the line's side, per-kind icon, and a
// goal-only flash (light sweep + pulse + glow). These tests pin each
// of those rules down, plus the RTL mirror and the no-flash-on-any-
// other-kind rule.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/features/match/commentary_style.dart';
import 'package:fcm_rivals/features/match/commentary_ticker.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_report.dart';

const _homeColor = Color(0xFF22C55E);
const _awayColor = Color(0xFFEF4444);

CommentaryLine _line(
  String text, {
  required CommentaryKind kind,
  MatchSide? side,
  int minute = 23,
  String? detail,
  int importance = 1,
}) => CommentaryLine(
  minute: minute,
  second: 10,
  text: text,
  importance: importance,
  kind: kind,
  detail: detail,
  side: side,
);

Widget _host(CommentaryLine line) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: CommentaryTicker(
        line: line,
        homeColor: _homeColor,
        awayColor: _awayColor,
      ),
    ),
  ),
);

void main() {
  testWidgets('one line of text, ellipsized — never wraps, never grows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _line(
          'GOAL! A very long scorer name scores a screamer from the edge '
          'of the box with a header and the crowd goes absolutely wild!',
          kind: CommentaryKind.goal,
          side: MatchSide.home,
          detail: 'Home 1 - 0 Away',
          importance: 2,
        ),
      ),
    );

    final text = tester.widget<Text>(
      find.textContaining('GOAL! A very long scorer'),
    );
    expect(text.maxLines, 1, reason: 'the moment is one line, always');
    expect(text.overflow, TextOverflow.ellipsis);

    // Fixed uniform height for every moment: goal (the tallest case)
    // stays a single bar — no wrap growth.
    final bar = tester.getSize(find.byType(CommentaryTicker));
    expect(bar.height, lessThan(50), reason: 'one fixed-height bar');
    expect(bar.height, greaterThan(40));
  });

  testWidgets('every kind renders in the same uniform height and size', (
    tester,
  ) async {
    const kinds = [
      (CommentaryKind.goal, 'GOAL! P 9 scores for Home!'),
      (CommentaryKind.penalty, 'PENALTY to Home! P 9 steps up.'),
      (CommentaryKind.redCard, 'RED CARD! P 4 is sent off!'),
      (CommentaryKind.yellowCard, 'P 4 is booked.'),
      (CommentaryKind.save, 'Save! P 10 forces a stop from P 0.'),
      (CommentaryKind.substitution, 'Substitution for Home.'),
      (CommentaryKind.kickoff, 'Kick-off! Home vs Away.'),
      (CommentaryKind.halfTime, 'Half time. Home and Away rest.'),
      (CommentaryKind.fullTime, 'Full time! The referee blows.'),
    ];
    Size? firstSize;
    double? firstFontSize;
    for (final (kind, text) in kinds) {
      await tester.pumpWidget(_host(_line(text, kind: kind, minute: 30)));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      final size = tester.getSize(find.byType(CommentaryTicker));
      final style = tester.widget<Text>(find.text(text)).style!;
      if (firstSize == null) {
        firstSize = size;
        firstFontSize = style.fontSize;
      } else {
        expect(
          size.height,
          firstSize.height,
          reason: '$kind must be the same height as the first kind',
        );
        expect(
          style.fontSize,
          firstFontSize,
          reason: '$kind must be the same text size',
        );
      }
    }
  });

  testWidgets('home and away moments wear their own team background', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _line(
          'P 9 scores for Home!',
          kind: CommentaryKind.goal,
          side: MatchSide.home,
          importance: 2,
        ),
      ),
    );
    // The home tint: a gradient DecoratedBox starting with the home
    // colour washes into the dark bar. Find the bar's gradient and
    // check its first stop is the home colour.
    final homeGradient = _barGradient(tester);
    expect(
      homeGradient.colors.first.withValues(alpha: 1.0),
      _homeColor,
      reason: 'home moments tint the bar with the home colour',
    );

    await tester.pumpWidget(
      _host(
        _line(
          'P 7 scores for Away!',
          kind: CommentaryKind.goal,
          side: MatchSide.away,
          importance: 2,
        ),
      ),
    );
    final awayGradient = _barGradient(tester);
    expect(
      awayGradient.colors.first.withValues(alpha: 1.0),
      _awayColor,
      reason: 'away moments tint the bar with the away colour',
    );

    // Whistle moments belong to neither side: neutral bronze tint.
    await tester.pumpWidget(
      _host(_line('Full time!', kind: CommentaryKind.fullTime, minute: 90)),
    );
    final neutralGradient = _barGradient(tester);
    expect(
      neutralGradient.colors.first.withValues(alpha: 1.0),
      FcmColors.gold,
      reason: 'the referee\'s moments stay neutral gold',
    );
  });

  testWidgets('each kind carries its own icon in the badge', (tester) async {
    await tester.pumpWidget(
      _host(_line('Save! P 10 forces a stop.', kind: CommentaryKind.save)),
    );
    expect(find.byIcon(Icons.sports_handball_rounded), findsOneWidget);

    await tester.pumpWidget(
      _host(
        _line(
          'RED CARD! P 4 is sent off!',
          kind: CommentaryKind.redCard,
          importance: 2,
        ),
      ),
    );
    // T-0115: a red card is a literal red card chip, not an icon.
    expect(find.byType(CardChip), findsOneWidget);
    final sentOff = tester.widget<CardChip>(find.byType(CardChip));
    expect(sentOff.color, FcmColors.cardRed);

    await tester.pumpWidget(
      _host(_line('P 4 is booked.', kind: CommentaryKind.yellowCard)),
    );
    // T-0115: a booking renders a literal card chip, not an icon.
    expect(find.byType(CardChip), findsOneWidget);
    final booked = tester.widget<CardChip>(find.byType(CardChip));
    expect(booked.color, FcmColors.cardYellow);

    await tester.pumpWidget(
      _host(_line('Corner for Home.', kind: CommentaryKind.corner)),
    );
    // T-0115: corners wear their own flag icon, distinct from goals.
    expect(find.byIcon(Icons.crop_free_rounded), findsOneWidget);
  });

  testWidgets('a goal flashes: sweep + pulse + glow, then rests', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _line(
          'GOAL! P 9 scores!',
          kind: CommentaryKind.goal,
          side: MatchSide.home,
          importance: 2,
          detail: 'Home 1 - 0 Away',
        ),
      ),
    );
    // Frame 1: the flash is running — the bar casts a glow shadow and
    // the sweep painter exists.
    await tester.pump(const Duration(milliseconds: 120));
    final glow = _glowShadow(tester);
    expect(glow, isNotNull, reason: 'the goal glows');
    expect(
      _sweepPaints(),
      findsOneWidget,
      reason: 'the light sweep is painting',
    );

    // After the flash lifetime the bar rests: no shadow, no sweep.
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(_sweepPaints(), findsNothing);
    expect(_glowShadow(tester), isNull, reason: 'the glow retired too');
  });

  testWidgets('no other kind flashes', (tester) async {
    await tester.pumpWidget(
      _host(
        _line(
          'RED CARD! P 4 is sent off!',
          kind: CommentaryKind.redCard,
          importance: 2,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(_sweepPaints(), findsNothing, reason: 'only a goal gets the flash');

    // Swap from a goal mid-flash to a save: the flash retires.
    await tester.pumpWidget(
      _host(
        _line(
          'GOAL! P 9 scores!',
          kind: CommentaryKind.goal,
          side: MatchSide.home,
          importance: 2,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(_sweepPaints(), findsOneWidget);
    await tester.pumpWidget(
      _host(_line('Save! P 10 stops it.', kind: CommentaryKind.save)),
    );
    await tester.pump();
    expect(
      _sweepPaints(),
      findsNothing,
      reason: 'a new non-goal moment retires the flash immediately',
    );
  });

  testWidgets('two goals in a row each get their own flash', (tester) async {
    await tester.pumpWidget(
      _host(
        _line(
          'GOAL! P 9 scores!',
          kind: CommentaryKind.goal,
          side: MatchSide.home,
          importance: 2,
          minute: 23,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // The same goal kept on screen does not restart; a NEW goal does.
    await tester.pumpWidget(
      _host(
        _line(
          'GOAL! P 7 scores again!',
          kind: CommentaryKind.goal,
          side: MatchSide.home,
          importance: 2,
          minute: 24,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(_sweepPaints(), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(_sweepPaints(), findsNothing);
  });

  testWidgets('the goal detail scoreline rides at the reading edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _line(
          'GOAL! P 9 scores!',
          kind: CommentaryKind.goal,
          side: MatchSide.home,
          importance: 2,
          detail: 'Home 1 - 0 Away',
        ),
      ),
    );
    expect(find.text('Home 1 - 0 Away'), findsOneWidget);
  });

  testWidgets('RTL: the bar mirrors without throwing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: CommentaryTicker(
                line: _line(
                  'GOAL! P 9 scores!',
                  kind: CommentaryKind.goal,
                  side: MatchSide.home,
                  importance: 2,
                  detail: 'Home 1 - 0 Away',
                ),
                homeColor: _homeColor,
                awayColor: _awayColor,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Minute chip sits at the start (right in RTL) — just assert the
    // tree lays out both directions without error and the text exists.
    expect(find.textContaining('GOAL!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// CustomPaints INSIDE the ticker subtree only — the goal sweep layer.
/// Scoped so Material's own ink painters never count. Always returns a
/// Finder; evaluate() has already been forced by the callers' expects.
Finder _sweepPaints() {
  return find.descendant(
    of: find.byType(CommentaryTicker),
    matching: find.byType(CustomPaint),
  );
}

/// The team-wash gradient of the bar's background: the BoxDecoration
/// whose gradient has the team-wash shape (three stops fading into the
/// dark bar). The glow shadow's DecoratedBox carries no gradient, so
/// filter by gradient presence.
LinearGradient _barGradient(WidgetTester tester) {
  final decorators = tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(CommentaryTicker),
      matching: find.byType(DecoratedBox),
    ),
  );
  for (final d in decorators) {
    final box = d.decoration as BoxDecoration;
    final gradient = box.gradient;
    if (gradient is LinearGradient && gradient.stops!.length == 3) {
      return gradient;
    }
  }
  throw StateError('no team-wash gradient found in the ticker');
}

/// The goal flash's glow shadow while it runs; null when no glow is
/// cast (flash off or retired).
List<BoxShadow>? _glowShadow(WidgetTester tester) {
  final decorators = tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(CommentaryTicker),
      matching: find.byType(DecoratedBox),
    ),
  );
  for (final d in decorators) {
    final box = d.decoration as BoxDecoration;
    if (box.boxShadow != null && box.boxShadow!.isNotEmpty) {
      return box.boxShadow;
    }
  }
  return null;
}
