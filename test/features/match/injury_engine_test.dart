// Engine injury wiring (T-0054, GDD 11.7): the engine rolls the T-0053
// risk model per minute for every on-pitch player of BOTH sides; an
// injury fires an event, removes the player and forces the best
// available substitute (or the team plays short). Persistence is
// T-0055, the UI banner is T-0056.
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/injury.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_report.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

/// Every roll fires and the per-team cap bites: minute 1 sees exactly
/// two injuries per side.
const _alwaysInjure = InjuryConfig(
  baseRiskPerMinuteAtFullStamina: 1,
  maxRiskPerMinute: 1,
);

const _positions = [
  Position.gk,
  Position.lb,
  Position.cb,
  Position.cb,
  Position.rb,
  Position.lm,
  Position.cm,
  Position.cm,
  Position.rm,
  Position.st,
  Position.st,
];

MatchPlayer _player(
  int id,
  String name,
  Position position, {
  double stamina = 100,
}) => MatchPlayer(
  playerId: id,
  name: name,
  position: position,
  attack: 60,
  support: 60,
  defence: 60,
  goalkeeping: position == Position.gk ? 60 : 10,
  stamina: stamina,
);

MatchTeamInput _team({
  required int teamId,
  required String name,
  double stamina = 100,
  List<MatchPlayer> bench = const [],
  int medicalCentreLevel = 0,
}) => MatchTeamInput(
  teamId: teamId,
  teamName: name,
  formationCode: '4-4-2',
  tactics: const TeamTactics(),
  mentality: Mentality.balanced,
  starters: [
    for (var i = 0; i < 11; i++)
      _player(teamId * 100 + i, '$name $i', _positions[i], stamina: stamina),
  ],
  bench: bench,
  aiControlled: true,
  medicalCentreLevel: medicalCentreLevel,
);

MatchEngine _engine(
  int seed, {
  InjuryConfig injuryConfig = _alwaysInjure,
  MatchTeamInput? home,
  MatchTeamInput? away,
}) => MatchEngine(
  seed: seed,
  config: MatchEngineConfig(injuryConfig: injuryConfig),
  home: home ?? _team(teamId: 1, name: 'Home'),
  away: away ?? _team(teamId: 2, name: 'Away'),
);

void main() {
  group('engine injury wiring (T-0054)', () {
    test('an injury fires an event and forces the best-fit substitute in '
        'the same minute', () {
      // A full mirror bench: every formation slot has a perfect-fit
      // candidate, so the FIRST injury of the match is always replaced
      // regardless of which slot the seeded stream hits.
      final bench = [
        for (var i = 0; i < 11; i++)
          _player(50 + i, 'Bench $i', _positions[i], stamina: 90),
      ];
      final eng = _engine(
        1,
        home: _team(teamId: 1, name: 'Home', bench: bench),
      );
      final events = eng.simulateToEnd();
      final injuries = events
          .where((e) => e.type == MatchEventType.injury)
          .where((e) => e.side == MatchSide.home)
          .toList();
      expect(injuries, isNotEmpty);
      final first = injuries.first;
      expect(first.metadata['kind'], isIn(['knock', 'muscle', 'serious']));
      expect(first.metadata['matchesOut'], greaterThanOrEqualTo(1));
      // The substitution event follows the injury event in the same
      // minute and is marked as the injury-forced swap.
      final forced = events
          .where((e) => e.type == MatchEventType.substitution)
          .where((e) => e.primaryPlayerId == first.primaryPlayerId)
          .where((e) => e.metadata['reason'] == 'injury')
          .toList();
      expect(forced.length, 1);
      expect(forced.first.eventId, greaterThan(first.eventId));
      expect(forced.first.secondaryPlayerId, isIn(bench.map((p) => p.playerId)));
      // The forced swap consumes the shared substitution budget but is
      // no AI tactical decision (event reason, not 'tired'/'chasing').
      expect(eng.substitutionsUsedOf(MatchSide.home), greaterThanOrEqualTo(1));
      expect(eng.substitutionsUsedOf(MatchSide.home), lessThanOrEqualTo(5));
      // The injured player keeps his earned minutes but is off.
      final injured = eng.playersOf(
        MatchSide.home,
      ).firstWhere((p) => p.playerId == first.primaryPlayerId);
      expect(injured.minutesPlayed, 1);
    });

    test('the per-match injury cap is never exceeded and the substitution '
        'cap is shared', () {
      final bench = [
        for (var i = 0; i < 5; i++)
          _player(50 + i, 'Bench $i', _positions[i + 1], stamina: 90),
      ];
      final eng = _engine(
        7,
        home: _team(teamId: 1, name: 'Home', bench: bench),
      );
      final events = eng.simulateToEnd();
      final homeInjuries = events
          .where((e) => e.type == MatchEventType.injury)
          .where((e) => e.side == MatchSide.home)
          .length;
      expect(homeInjuries, _alwaysInjure.maxInjuriesPerTeamPerMatch);
      expect(eng.substitutionsUsedOf(MatchSide.home), lessThanOrEqualTo(5));
    });

    test('with no bench candidate the team plays short (red-card mechanism)',
        () {
      final eng = _engine(3);
      final events = eng.simulateToEnd();
      final injuries = events
          .where((e) => e.type == MatchEventType.injury)
          .where((e) => e.side == MatchSide.home)
          .toList();
      expect(injuries, isNotEmpty);
      expect(injuries.first.metadata['playsShort'], isTrue);
      expect(
        events
            .where((e) => e.type == MatchEventType.substitution)
            .where((e) => e.side == MatchSide.home)
            .where((e) => e.metadata['reason'] == 'injury'),
        isEmpty,
      );
      // Both injuries leave empty slots (plays short); a red card in the
      // same match would remove one more, hence the upper bound.
      expect(eng.onPitchOf(MatchSide.home).length, lessThanOrEqualTo(9));
    });

    test('AI squads suffer identical rolls (no asymmetric protection)', () {
      final eng = _engine(5);
      final events = eng.simulateToEnd();
      expect(
        events
            .where((e) => e.type == MatchEventType.injury)
            .where((e) => e.side == MatchSide.away)
            .length,
        _alwaysInjure.maxInjuriesPerTeamPerMatch,
      );
    });

    test('the same seed reproduces identical injuries', () {
      List<MatchEvent> injuriesOf(MatchEngine eng) => eng
          .simulateToEnd()
          .where((e) => e.type == MatchEventType.injury)
          .toList();
      final a = injuriesOf(_engine(11));
      final b = injuriesOf(_engine(11));
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].minute, b[i].minute);
        expect(a[i].side, b[i].side);
        expect(a[i].primaryPlayerId, b[i].primaryPlayerId);
        expect(a[i].metadata['kind'], b[i].metadata['kind']);
        expect(a[i].metadata['matchesOut'], b[i].metadata['matchesOut']);
        expect(a[i].metadata['playsShort'], b[i].metadata['playsShort']);
      }
    });

    test('a maxed Medical Centre with full reduction eliminates injuries '
        'while the unprotected side still loses players', () {
      // 0.25 × level 5 = 125% reduction → risk clamps to exactly 0 for
      // the protected side, even under the always-injure config.
      final config = const InjuryConfig(
        baseRiskPerMinuteAtFullStamina: 1,
        maxRiskPerMinute: 1,
        medicalRiskReductionPerLevel: 0.25,
      );
      final eng = _engine(
        21,
        injuryConfig: config,
        home: _team(teamId: 1, name: 'Home', medicalCentreLevel: 5),
      );
      final events = eng.simulateToEnd();
      expect(
        events
            .where((e) => e.type == MatchEventType.injury)
            .where((e) => e.side == MatchSide.home),
        isEmpty,
      );
      expect(
        events
            .where((e) => e.type == MatchEventType.injury)
            .where((e) => e.side == MatchSide.away),
        isNotEmpty,
      );
    });

    test('commentary carries the injury line (EN default + localizer seam) '
        'and the report counts an injuries row per team', () {
      final eng = _engine(31);
      final events = eng.simulateToEnd();
      final injuries = events
          .where((e) => e.type == MatchEventType.injury)
          .toList();
      final names = {
        for (final p in [
          ...eng.playersOf(MatchSide.home),
          ...eng.playersOf(MatchSide.away),
        ])
          p.playerId: p.name,
      };

      final localizedKinds = <InjuryKind>[];
      var playsShortCalls = 0;
      final localized = generateCommentary(
        events,
        playerNames: names,
        homeTeamName: 'Home',
        awayTeamName: 'Away',
        injuryText: (kind, player, playsShort) {
          localizedKinds.add(kind);
          if (playsShort) playsShortCalls++;
          return 'AR:${kind.name}:$player';
        },
      );
      final localizedInjuryLines = localized
          .where((l) => l.kind == CommentaryKind.injury)
          .toList();
      expect(localizedInjuryLines.length, injuries.length);
      expect(localizedKinds.length, injuries.length);
      expect(localizedInjuryLines.first.text, startsWith('AR:'));
      // The default-config engine has no bench: at least one of its
      // injuries exercises the plays-short branch of the localizer.
      expect(playsShortCalls, greaterThanOrEqualTo(1));

      final english = generateCommentary(
        events,
        playerNames: names,
        homeTeamName: 'Home',
        awayTeamName: 'Away',
      );
      final englishInjuryLines = english
          .where((l) => l.kind == CommentaryKind.injury)
          .toList();
      expect(englishInjuryLines.length, injuries.length);
      expect(
        englishInjuryLines.first.text,
        contains(names[injuries.first.primaryPlayerId]!),
      );

      final stats = computeStats(events, homeTeamId: 1, awayTeamId: 2);
      expect(stats.home.injuries + stats.away.injuries, injuries.length);
      expect(stats.home.injuries, lessThanOrEqualTo(2));
      expect(stats.away.injuries, lessThanOrEqualTo(2));
    });
  });
}
