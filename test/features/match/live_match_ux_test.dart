// The four live-match UX behaviours shipped together:
//
//  1. Commentary carries KEY EVENTS only — the broadcast track, not
//     every pass, tackle and offside (FR-031 refinement).
//  2. The chosen match speed persists forever (user_settings row,
//     GDD 26.2): a fresh store reads back the written speed.
//  3. The live tactics editor uses the SAME surface as the pre-match
//     phase — control card, XI pitch with live stamina, bench — and
//     NO reserves section (a live match has nobody beyond the bench).
//  4. The half-time card is unmistakably half time: a score banner,
//     and an Edit Tactics button that opens the live editor without
//     dismissing the pending pep-talk choice.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/fcm_widgets.dart' show FcmDropdown;
import 'package:fcm_rivals/features/match/live_match_views.dart';
import 'package:fcm_rivals/features/match/live_tactics_screen.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_report.dart';
import 'package:fcm_rivals/features/match/match_session.dart';
import 'package:fcm_rivals/features/squad/formations.dart';
import 'package:fcm_rivals/features/settings/user_settings_store.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('key-events-only commentary (FR-031)', () {
    MatchEngine buildEngine(int seed) {
      const positions = [
        Position.gk, Position.lb, Position.cb, Position.cb, Position.rb,
        Position.lm, Position.cm, Position.cm, Position.rm,
        Position.st, Position.st,
      ];
      List<MatchPlayer> team(int base, {int value = 20_000_000}) => [
            for (var i = 0; i < 11; i++)
              MatchPlayer(
                playerId: base + i,
                name: 'P $i',
                position: positions[i],
                attack: 60 + i,
                support: 60 + i,
                defence: 60 + i,
                goalkeeping: positions[i] == Position.gk ? 70 : 20,
              ),
          ];
      return MatchEngine(
        seed: seed,
        home: MatchTeamInput(
          teamId: 1,
          teamName: 'Home',
          formationCode: '4-4-2',
          style: PlayingStyle.balanced,
          mentality: Mentality.balanced,
          starters: team(100),
          bench: const [],
          aiControlled: true,
        ),
        away: MatchTeamInput(
          teamId: 2,
          teamName: 'Away',
          formationCode: '4-3-3',
          style: PlayingStyle.balanced,
          mentality: Mentality.balanced,
          starters: team(300),
          bench: const [],
          aiControlled: true,
        ),
      );
    }

    test('keyEventsOnly keeps goals/cards/saves, drops the filler', () {
      final engine = buildEngine(7);
      final events = engine.simulateToEnd();
      final names = {
        for (final p in [
          ...engine.playersOf(MatchSide.home),
          ...engine.playersOf(MatchSide.away),
        ])
          p.playerId: p.name,
      };
      final full = generateCommentary(events,
          playerNames: names, homeTeamName: 'Home', awayTeamName: 'Away');
      final key = generateCommentary(events,
          playerNames: names,
          homeTeamName: 'Home',
          awayTeamName: 'Away',
          keyEventsOnly: true);

      // Nothing important is lost: every importance-2 line survives.
      final fullKey = full.where((l) => l.importance > 0).toList();
      expect(key.length, fullKey.length);
      expect(
          key.where((l) => l.importance > 0).length, key.length,
          reason: 'filtered feed must contain only notable/key lines');
      // The full track still exists and is strictly richer.
      expect(full.length, greaterThan(key.length));
      // Goals are never dropped.
      expect(
          key.where((l) => l.text.startsWith('GOAL!')).length,
          full.where((l) => l.text.startsWith('GOAL!')).length);
    });

    test('a typical match yields a readable feed, not a wall of text',
        () {
      // Aggregate over several seeds: the broadcast track should stay
      // in the tens of lines for a 90-minute match.
      var totalKey = 0, totalFull = 0;
      const matches = 5;
      for (var m = 0; m < matches; m++) {
        final engine = buildEngine(m + 40);
        final events = engine.simulateToEnd();
        final names = {
          for (final p in [
            ...engine.playersOf(MatchSide.home),
            ...engine.playersOf(MatchSide.away),
          ])
            p.playerId: p.name,
        };
        totalFull += generateCommentary(events,
                playerNames: names,
                homeTeamName: 'Home',
                awayTeamName: 'Away')
            .length;
        totalKey += generateCommentary(events,
                playerNames: names,
                homeTeamName: 'Home',
                awayTeamName: 'Away',
                keyEventsOnly: true)
            .length;
      }
      expect(totalKey / matches, lessThan(60));
      expect(totalFull / matches, greaterThan(totalKey / matches));
    });

    test('every key moment knows its kind and goals carry the scoreline',
        () {
      final engine = buildEngine(11);
      final events = engine.simulateToEnd();
      final names = {
        for (final p in [
          ...engine.playersOf(MatchSide.home),
          ...engine.playersOf(MatchSide.away),
        ])
          p.playerId: p.name,
      };
      final feed = generateCommentary(events,
          playerNames: names,
          homeTeamName: 'Home',
          awayTeamName: 'Away',
          keyEventsOnly: true);

      // The feed's key moments are TYPED: goals, cards, saves and
      // penalties carry their broadcast identity, not just importance.
      expect(feed.where((l) => l.kind == CommentaryKind.goal).length,
          events.where((e) => e.type == MatchEventType.goal).length);
      expect(feed.any((l) => l.kind == CommentaryKind.yellowCard), isTrue);
      expect(feed.any((l) => l.kind == CommentaryKind.save), isTrue);
      expect(feed.first.kind, CommentaryKind.kickoff);
      expect(feed.last.kind, CommentaryKind.fullTime);

      // Every goal line tells the running score after the goal.
      final goals = feed.where((l) => l.kind == CommentaryKind.goal);
      for (final g in goals) {
        expect(g.detail, isNotNull);
        expect(g.detail, contains('Home'));
        expect(g.detail, contains('Away'));
        expect(RegExp(r'Home \d+ - \d+ Away').hasMatch(g.detail!),
            isTrue,
            reason: 'detail must be a running scoreline: ${g.detail}');
      }
      // And the last goal's detail matches the final score.
      if (goals.isNotEmpty) {
        final last = goals.last;
        final match = RegExp(r'Home (\d+) - (\d+) Away').firstMatch(last.detail!)!;
        expect(int.parse(match.group(1)!), engine.state.scoreHome);
        expect(int.parse(match.group(2)!), engine.state.scoreAway);
      }
    });
  });

  group('match speed persists forever (GDD 26.2)', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('default is 1x before any choice', () async {
      final store = UserSettingsStore(database: db);
      expect(await store.matchSpeed(), 1);
    });

    test('the written speed reads back from a fresh store', () async {
      await UserSettingsStore(database: db).setMatchSpeed(3);
      // A NEW store over the SAME database — i.e. the next match after
      // an app restart: the choice sticks.
      final store = UserSettingsStore(database: db);
      expect(await store.matchSpeed(), 3);
    });

    test('updating the speed overwrites the row (not duplicated)', () async {
      final store = UserSettingsStore(database: db);
      await store.setMatchSpeed(2);
      await store.setMatchSpeed(3);
      expect(await store.matchSpeed(), 3);
      final rows = await db.select(db.userSettings).get();
      expect(rows.length, 1);
    });

    test('out-of-range speeds are ignored, corrupt rows fall back', () async {
      final store = UserSettingsStore(database: db);
      // 4x no longer exists — the ladder stops at 3x.
      await store.setMatchSpeed(4);
      expect(await store.matchSpeed(), 1);
      await store.setMatchSpeed(9);
      expect(await store.matchSpeed(), 1);
      await db.into(db.userSettings).insert(
          UserSettingsCompanion.insert(id: 2, matchSpeed: Value(42)));
      // Row 2 is not THE row (id 1); the store must not read it.
      expect(await store.matchSpeed(), 1);
    });
  });

  group('live tactics editor mirrors the pre-match surface (GDD 10.4/16)',
      () {
    testWidgets('shows XI pitch, bench strip and no reserves section',
        (tester) async {
      const positions = [
        Position.gk, Position.lb, Position.cb, Position.cb, Position.rb,
        Position.cm, Position.cm, Position.cam,
        Position.lw, Position.st, Position.rw,
      ];
      List<MatchPlayer> team(int base) => [
            for (var i = 0; i < 11; i++)
              MatchPlayer(
                playerId: base + i,
                name: 'Player $i',
                position: positions[i],
                attack: 70,
                support: 70,
                defence: 70,
                goalkeeping: positions[i] == Position.gk ? 75 : 20,
              ),
          ];
      final engine = MatchEngine(
        seed: 3,
        home: MatchTeamInput(
          teamId: 1,
          teamName: 'Home',
          formationCode: '4-3-3',
          style: PlayingStyle.balanced,
          mentality: Mentality.balanced,
          starters: team(100),
          bench: [
            MatchPlayer(
                playerId: 200,
                name: 'Sub One',
                position: Position.st,
                attack: 68,
                support: 60,
                defence: 40,
                goalkeeping: 0),
            MatchPlayer(
                playerId: 201,
                name: 'Sub Two',
                position: Position.cm,
                attack: 60,
                support: 66,
                defence: 55,
                goalkeeping: 0),
          ],
        ),
        away: MatchTeamInput(
          teamId: 2,
          teamName: 'Away',
          formationCode: '4-4-2',
          style: PlayingStyle.balanced,
          mentality: Mentality.balanced,
          starters: team(300),
          bench: const [],
          aiControlled: true,
        ),
      );
      final session = _FakeSession(engine);
      engine.simulateToEnd();

      await tester.pumpWidget(MaterialApp(
        home: LiveTacticsScreen(session: session, minuteQueuedFrom: 46),
      ));
      // Entrance animations: two frames render the whole surface; there
      // is no need (and no finite end) to settling them.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The pre-match surface pieces are all there: the setup row
      // (STYLE / MENTALITY + team rating) and the formation dropdown
      // DIRECTLY on the control card, showing the user side's shape.
      expect(find.byType(FcmDropdown<String>), findsOneWidget);
      expect(find.text('4-3-3'), findsOneWidget);
      expect(find.text('STYLE'), findsOneWidget);
      expect(find.text('MENTALITY'), findsOneWidget);
      expect(find.text('Bench (2/${Formation.benchSize})'), findsOneWidget);
      // Card strips render uppercased surnames ('Sub One' → 'ONE').
      expect(find.text('ONE'), findsOneWidget);
      expect(find.text('TWO'), findsOneWidget);
      // ...and the reserves section is NOT part of the live editor.
      expect(find.textContaining('Reserves'), findsNothing);
    });
  });

  group('broadcast commentary design', () {
    testWidgets('a goal renders as an elevated GOAL card with the '
        'scoreline badge; cards and saves get icon chips', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [
              CommentaryRow(
                  line: CommentaryLine(
                      minute: 1,
                      second: 0,
                      text: 'Kick-off! Home vs Away.',
                      importance: 1,
                      kind: CommentaryKind.kickoff)),
              CommentaryRow(
                  line: CommentaryLine(
                      minute: 23,
                      second: 10,
                      text: 'GOAL! P 9 scores for Home! Assist: P 7.',
                      importance: 2,
                      kind: CommentaryKind.goal,
                      detail: 'Home 1 - 0 Away')),
              CommentaryRow(
                  line: CommentaryLine(
                      minute: 61,
                      second: 5,
                      text: 'P 4 is booked.',
                      importance: 1,
                      kind: CommentaryKind.yellowCard)),
              CommentaryRow(
                  line: CommentaryLine(
                      minute: 72,
                      second: 30,
                      text: 'Save! P 10 forces a stop from P 0.',
                      importance: 1,
                      kind: CommentaryKind.save)),
              CommentaryRow(
                  line: CommentaryLine(
                      minute: 90,
                      second: 0,
                      text: 'Full time! The referee blows the final whistle.',
                      importance: 1,
                      kind: CommentaryKind.fullTime)),
            ],
          ),
        ),
      ));
      await tester.pump();

      // The goal is a full card: GOAL header, gold football badge and
      // the running score under the line.
      expect(find.text('GOAL'), findsOneWidget);
      expect(find.text('Home 1 - 0 Away'), findsOneWidget);
      expect(find.byIcon(Icons.sports_soccer_rounded), findsOneWidget);
      // Yellow card + save rows carry their icon chips.
      expect(find.byIcon(Icons.style_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sports_handball_rounded), findsOneWidget);
    });
  });

  group('live momentum (GDD 13.2)', () {
    // Minimal synthetic event over a chosen minute/team.
    MatchEvent ev(int minute, MatchEventType type, int teamId,
            {Map<String, dynamic> metadata = const {}}) =>
        MatchEvent(
          eventId: minute * 10 + type.index,
          minute: minute,
          second: 0,
          type: type,
          side: teamId == 1 ? MatchSide.home : MatchSide.away,
          teamId: teamId,
          metadata: metadata,
        );

    test('dead level before any events, and with only structural ones',
        () {
      expect(
          computeMomentum(const [], homeTeamId: 1, awayTeamId: 2), 0.5);
      // Kick-off/whistle moments carry no momentum signal.
      expect(
          computeMomentum([
            ev(1, MatchEventType.kickoff, 1),
            ev(45, MatchEventType.halfTime, 1),
          ], homeTeamId: 1, awayTeamId: 2),
          0.5);
    });

    test('shots and goals push the share to the attacking side', () {
      final events = [
        ev(80, MatchEventType.possession, 1),
        ev(82, MatchEventType.shot, 2),
        ev(84, MatchEventType.shot, 2),
        ev(86, MatchEventType.goal, 2),
      ];
      final share =
          computeMomentum(events, homeTeamId: 1, awayTeamId: 2);
      expect(share, lessThan(0.4));
      // Mirror: home does the same, the share mirrors with it.
      final mirrored = computeMomentum([
        ev(80, MatchEventType.possession, 2),
        ev(82, MatchEventType.shot, 1),
        ev(84, MatchEventType.shot, 1),
        ev(86, MatchEventType.goal, 1),
      ], homeTeamId: 1, awayTeamId: 2);
      expect(mirrored, greaterThan(0.6));
      expect(mirrored + share, closeTo(1.0, 0.0001));
    });

    test('events age out of the trailing window', () {
      // A home goal 30 minutes ago vs an away shot just now: the old
      // goal counts for nothing — the window keeps the reading live.
      final events = [
        ev(50, MatchEventType.goal, 1),
        ev(80, MatchEventType.shot, 2),
      ];
      final share =
          computeMomentum(events, homeTeamId: 1, awayTeamId: 2);
      expect(share, lessThan(0.3));
    });

    test('the per-minute series ends on the scalar reading', () {
      final events = [
        ev(50, MatchEventType.goal, 1),
        ev(80, MatchEventType.shot, 2),
      ];
      final series = computeMomentumSeries(
        events,
        homeTeamId: 1,
        awayTeamId: 2,
      );
      // One entry per played minute (last event at minute 80).
      expect(series, hasLength(80));
      // Dead level until the goal's minute: nothing to weigh.
      expect(series[0], 0.5);
      // The goal's minute reads home-heavy…
      expect(series[49], greaterThan(0.5));
      // …and the final minute is the scalar trailing share, away-heavy
      // now that the goal has aged out of the window.
      expect(series.last, lessThan(0.3));
      expect(
        series.last,
        computeMomentum(events, homeTeamId: 1, awayTeamId: 2),
      );
    });

    test('empty timeline → empty series', () {
      expect(
        computeMomentumSeries(const [], homeTeamId: 1, awayTeamId: 2),
        isEmpty,
      );
    });

    test("a booked side's opponent gains: cards read as pressure", () {
      final events = [
        ev(80, MatchEventType.card, 1, metadata: {'card': 'yellow'}),
        ev(81, MatchEventType.shot, 2),
      ];
      final share =
          computeMomentum(events, homeTeamId: 1, awayTeamId: 2);
      expect(share, lessThan(0.4));
    });

    test('realistic matches keep the share inside believable bounds',
        () {
      // Across seeds and lop-sided strengths (85 vs 45 overall), the
      // trailing momentum share stays in football's believable band —
      // the dominant side can own long spells, but a 15-minute window
      // with shots, saves and clearances never pins the bar to its end.
      const positions = [
        Position.gk, Position.lb, Position.cb, Position.cb, Position.rb,
        Position.lm, Position.cm, Position.cm, Position.rm,
        Position.st, Position.st,
      ];
      List<MatchPlayer> team(int base, int strength) => [
            for (var i = 0; i < 11; i++)
              MatchPlayer(
                playerId: base + i,
                name: 'P $i',
                position: positions[i],
                attack: strength,
                support: strength,
                defence: strength,
                goalkeeping: positions[i] == Position.gk ? 70 : 20,
              ),
          ];
      for (var seed = 1; seed <= 8; seed++) {
        final engine = MatchEngine(
          seed: seed,
          home: MatchTeamInput(
            teamId: 1,
            teamName: 'Home',
            formationCode: '4-4-2',
            style: PlayingStyle.balanced,
            mentality: Mentality.balanced,
            starters: team(100, 85),
            bench: const [],
            aiControlled: true,
          ),
          away: MatchTeamInput(
            teamId: 2,
            teamName: 'Away',
            formationCode: '4-3-3',
            style: PlayingStyle.balanced,
            mentality: Mentality.balanced,
            starters: team(300, 45),
            bench: const [],
            aiControlled: true,
          ),
        );
        final events = engine.simulateToEnd();
        final share =
            computeMomentum(events, homeTeamId: 1, awayTeamId: 2);
        // Even a 40-point strength gap can only NEAR-pin the bar: the
        // trailing window still contains the underdog's clearances,
        // fouls won and throw-in spells.
        expect(share, greaterThan(0.10));
        expect(share, lessThan(1.0));
      }
    });
  });

  group('the half-time card reads as half time (GDD 15.2)', () {
    testWidgets('score banner + edit-tactics entry are present', (tester) async {
      MatchPepTalk? chosen;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TouchlinePepTalkCard(
                title: 'HALF TIME',
                scoreHeader: 'Home FC 1 – 0 Away FC',
                subtitle: 'Pep talk for the second half.',
                talks: halfTimePepTalks,
                onChoose: (t) => chosen = t,
                onSkip: () {},
                onEditTactics: () {},
              ),
            ],
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('HALF TIME'), findsOneWidget);
      expect(find.text('Home FC 1 – 0 Away FC'), findsOneWidget);
      expect(find.text('EDIT TACTICS'), findsOneWidget);
      // The pep-talk options still render next to the banner.
      expect(find.byType(TextButton), findsOneWidget);
      expect(chosen, isNull); // nothing chosen yet
    });

    testWidgets('no score banner on non-half-time uses (post-match)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TouchlinePepTalkCard(
                title: 'Post-match talk',
                subtitle: 'Recovery choice.',
                talks: halfTimePepTalks,
                onChoose: (_) {},
                onSkip: () {},
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Post-match talk'), findsOneWidget);
      expect(find.text('EDIT TACTICS'), findsNothing);
    });

    testWidgets('the card is NOT dismissible by tapping outside it',
        (tester) async {
      var skipped = false;
      MatchPepTalk? chosen;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TouchlinePepTalkCard(
                title: 'HALF TIME',
                scoreHeader: 'Home FC 1 – 0 Away FC',
                subtitle: 'Pep talk for the second half.',
                talks: halfTimePepTalks,
                onChoose: (t) => chosen = t,
                onSkip: () => skipped = true,
                onEditTactics: () {},
              ),
            ],
          ),
        ),
      ));
      await tester.pump();

      // Tapping the scrim around the card does nothing — the manager
      // must pick a talk or 'say nothing'; no accidental dismissal.
      await tester.tapAt(const Offset(20, 40));
      await tester.pump();
      expect(skipped, isFalse);
      expect(chosen, isNull);
      // The card is still up.
      expect(find.text('HALF TIME'), findsOneWidget);

      // 'Say nothing' is the explicit escape — that still works.
      await tester.tap(find.text('Say nothing — back to the match'));
      await tester.pump();
      expect(skipped, isTrue);
    });
  });

  group('momentum bar widget', () {
    testWidgets('renders the spike bar: label row, played and empty series',
        (tester) async {
      // A few played minutes with pushes both ways: the bar renders
      // with its label row — team names at the ends, MOMENTUM centred.
      await tester.pumpWidget(MaterialApp(
        home: const Scaffold(
          body: MomentumBar(
            series: [0.5, 0.62, 0.38],
            homeTeamName: 'FC Rivals',
            awayTeamName: 'Al Ahly',
            homeColor: Color(0xFF7A3B36),
          ),
        ),
      ));
      expect(find.byType(MomentumBar), findsOneWidget);
      expect(find.text('MOMENTUM'), findsOneWidget);
      expect(find.text('FC Rivals'), findsOneWidget);
      expect(find.text('Al Ahly'), findsOneWidget);

      // A full-match dead-level series (every minute 0.5): renders —
      // the painter draws only the baseline.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MomentumBar(
            series: List<double>.filled(90, 0.5),
            homeTeamName: 'FC Rivals',
            awayTeamName: 'Al Ahly',
          ),
        ),
      ));
      expect(find.byType(MomentumBar), findsOneWidget);

      // Pre-kick-off (empty series): still renders, baseline only.
      await tester.pumpWidget(MaterialApp(
        home: const Scaffold(
          body: MomentumBar(
            series: [],
            homeTeamName: 'FC Rivals',
            awayTeamName: 'Al Ahly',
          ),
        ),
      ));
      expect(find.byType(MomentumBar), findsOneWidget);
    });
  });
}

/// Minimal MatchSession stand-in: the live editor only needs the engine
/// plus the accessors, and a real session requires a database-backed
/// club. Construction stays in one place for the widget test.
class _FakeSession implements MatchSession {
  _FakeSession(this._engine);

  final MatchEngine _engine;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #engine) return _engine;
    if (invocation.memberName == #userSide) return MatchSide.home;
    throw UnsupportedError(
        'Unhandled member: ${invocation.memberName}');
  }
}
