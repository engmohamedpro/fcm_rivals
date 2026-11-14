/// T-0056: the injury UI surfaces — badge, pre-match medical room, live
/// banner and the report's injuries row — machine-checked in EN (the
/// l10nOf fallback) and AR (delegates scoped in), LTR and RTL.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/fcm_style.dart' show CardRarity;
import 'package:fcm_rivals/core/ui/injury_badge.dart';
import 'package:fcm_rivals/core/ui/mini_card.dart';
import 'package:fcm_rivals/features/match/commentary.dart';
import 'package:fcm_rivals/features/match/injury.dart';
import 'package:fcm_rivals/features/match/injury_live_banner.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_forecast.dart';
import 'package:fcm_rivals/features/match/match_report.dart';
import 'package:fcm_rivals/features/match/match_report_view.dart';
import 'package:fcm_rivals/features/match/match_session.dart';
import 'package:fcm_rivals/features/match/pre_match_analysis.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart';
import 'package:fcm_rivals/l10n/app_localizations.dart';
import 'package:fcm_rivals/l10n/app_localizations_ar.dart';

BasePlayer _player(int id) => BasePlayer(
  playerId: id,
  name: 'Test Striker',
  position: Position.st,
  nationality: 'Egypt',
  marketValueEur: 5_000_000,
  baseStats: const BaseStats(
    overall: 78,
    attack: 80,
    support: 76,
    defence: 60,
    goalkeeping: 0,
  ),
);

PlayerCard _card({required int ownedId, int matchesOut = 0}) => PlayerCard(
  ownedId: ownedId,
  base: _player(ownedId),
  upgradeLevel: 0,
  staminaPercent: 100,
  injuryMatchesRemaining: matchesOut,
  injuryKind: matchesOut > 0 ? InjuryKind.serious.name : null,
);

MatchForecast _forecast() => const MatchForecast(
  samples: 1000,
  winPercent: 45,
  drawPercent: 25,
  lossPercent: 30,
  avgUserGoals: 1.4,
  avgOpponentGoals: 1.1,
  cleanSheetPercent: 25,
  userTotals: TeamTotals(
    attack: 70,
    support: 68,
    defence: 66,
    goalkeeping: 60,
  ),
  opponentTotals: TeamTotals(
    attack: 67,
    support: 65,
    defence: 64,
    goalkeeping: 58,
  ),
);

PreMatchData _data(List<PlayerCard> squad) => PreMatchData(
  fixtureLabel: 'League · Round 3',
  userClubName: 'Pyramid United',
  opponentClubName: 'Rivers United',
  userAtHome: true,
  forecast: _forecast(),
  opponentForm: const [],
  opponentPosition: 4,
  userPosition: 2,
  opponentSquad: const [],
  userSquad: {for (final c in squad) c.ownedId: c},
);

CommentaryLine _injuryLine({String? detail}) => CommentaryLine(
  minute: 63,
  second: 12,
  text: 'Test Striker suffers a serious injury. That doesn\'t look good.',
  importance: 2,
  kind: CommentaryKind.injury,
  detail: detail,
);

Future<void> pumpLocalized(
  WidgetTester tester,
  Widget child, {
  Locale? locale,
  TextDirection? direction,
}) async {
  // The analysis ListView is lazy: off-screen cards are never built, so
  // the sheet must fit on one screen (T-0069 added the chemistry row —
  // the medical room fell below the fold of the default 600x800).
  tester.view.physicalSize = const Size(2400, 3600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: locale == null
          ? null
          : AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Directionality(
        // An explicit direction on top of MaterialApp's own — the RTL run
        // forces the layout, not the locale.
        textDirection: direction ?? TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('the shared injury badge', () {
    testWidgets('renders the count and the semantics label, LTR and RTL',
        (tester) async {
      for (final direction in [
        TextDirection.ltr,
        TextDirection.rtl,
      ]) {
        await pumpLocalized(
          tester,
          const FcmMiniCard(
            overall: 78,
            position: 'ST',
            name: 'Striker',
            rarity: CardRarity.epic,
            injuryMatchesOut: 3,
          ),
          direction: direction,
        );
        expect(find.byType(InjuryBadge), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Injured, out for 3 matches')),
          findsOneWidget,
        );
      }
    });

    testWidgets('a fit player carries no badge', (tester) async {
      await pumpLocalized(
        tester,
        const FcmMiniCard(
          overall: 78,
          position: 'ST',
          name: 'Striker',
          rarity: CardRarity.epic,
          injuryMatchesOut: 0,
        ),
      );
      expect(find.byType(InjuryBadge), findsNothing);
    });
  });

  group('pre-match medical room (requirement 2)', () {
    testWidgets('the analysis lists injured players with their count '
        '(EN, LTR)', (tester) async {
      await pumpLocalized(
        tester,
        AnalysisPhase(
          data: _data([
            _card(ownedId: 1, matchesOut: 3),
            _card(ownedId: 2),
          ]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      // 2026-11-13: the formation pitch replaced the strength and
      // top-player cards, so the medical room sits lower — drag it
      // into view before asserting (the real user scrolls too).
      await tester.dragUntilVisible(
        find.text('Medical room'),
        find.byType(Scrollable),
        const Offset(0, -180),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Medical room'), findsOneWidget);
      expect(find.text('Test Striker'), findsOneWidget);
      expect(find.text('Out for 3 matches'), findsOneWidget);
    });

    testWidgets('hidden entirely when everyone fits', (tester) async {
      await pumpLocalized(
        tester,
        AnalysisPhase(data: _data([_card(ownedId: 1)])),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Medical room'), findsNothing);
    });

    testWidgets('Arabic renders the localized room (RTL)', (tester) async {
      await pumpLocalized(
        tester,
        AnalysisPhase(
          data: _data([_card(ownedId: 1, matchesOut: 2)]),
        ),
        locale: const Locale('ar'),
        direction: TextDirection.rtl,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.dragUntilVisible(
        find.text('الغرفة الطبية'),
        find.byType(Scrollable),
        const Offset(0, -180),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('الغرفة الطبية'), findsOneWidget);
      expect(find.text('خارج 2 مباراة'), findsOneWidget);
    });

    // T-0139: the injuryStaminaRiskHint ARB key was removed — it was
    // orphaned (zero UI consumers since the phases screen dropped the
    // hint); the medical-room surface itself keeps its localized
    // title above.
  });

  group('live injury banner (requirement 3)', () {
    testWidgets('the injury line takes the lower third with the '
        'matches-out chip (EN)', (tester) async {
      await pumpLocalized(
        tester,
        InjuryLiveBanner(line: _injuryLine(detail: '4')),
      );
      expect(
        find.textContaining('serious injury'),
        findsOneWidget,
        reason: 'the T-0054 commentary text rides the banner',
      );
      expect(find.text('OUT 4'), findsOneWidget);
    });

    testWidgets('Arabic chip + the plays-short line end to end',
        (tester) async {
      await pumpLocalized(
        tester,
        InjuryLiveBanner(
          line: CommentaryLine(
            minute: 63,
            second: 0,
            text: AppLocalizationsAr().injuryCommentarySerious('Test Striker'),
            importance: 2,
            kind: CommentaryKind.injury,
            detail: '2',
          ),
        ),
        locale: const Locale('ar'),
        direction: TextDirection.rtl,
      );
      expect(find.text('خارج 2'), findsOneWidget);
      expect(find.textContaining('إصابة خطيرة'), findsOneWidget);
    });

    testWidgets('no chip when the count payload is absent', (tester) async {
      await pumpLocalized(
        tester,
        InjuryLiveBanner(line: _injuryLine()),
      );
      expect(find.textContaining('OUT'), findsNothing);
    });
  });

  group('report injuries row (requirement 4)', () {
    testWidgets('the report states the injury count', (tester) async {
      const state = MatchState(
        minute: 90,
        scoreHome: 2,
        scoreAway: 1,
        isFinished: true,
        isHalfTime: false,
        substitutionsHome: 0,
        substitutionsAway: 0,
      );
      await pumpLocalized(
        tester,
        MatchReportView(
          report: MatchReportResult(
            state: state,
            homeRatings: const [],
            awayRatings: const [],
            commentary: [_injuryLine(detail: '3')],
            rewardCoins: 1200,
          ),
          homeTeamName: 'Pyramid United',
          awayTeamName: 'Rivers United',
          onContinue: () {},
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('1 player(s) injured'), findsOneWidget);
    });

    testWidgets('no row on an injury-free match', (tester) async {
      const state = MatchState(
        minute: 90,
        scoreHome: 0,
        scoreAway: 0,
        isFinished: true,
        isHalfTime: false,
        substitutionsHome: 0,
        substitutionsAway: 0,
      );
      await pumpLocalized(
        tester,
        MatchReportView(
          report: MatchReportResult(
            state: state,
            homeRatings: const [],
            awayRatings: const [],
            commentary: const [],
            rewardCoins: 500,
          ),
          homeTeamName: 'Pyramid United',
          awayTeamName: 'Rivers United',
          onContinue: () {},
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('injured'), findsNothing);
    });
  });
}
