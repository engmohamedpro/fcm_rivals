/// FCM Rivals — match commentary (GDD 13.1, FR-031).
///
/// The commentary data model ([CommentaryKind], [CommentaryLine]) and
/// its construction from the recorded MatchEvents (GDD 26.4), split
/// out of `match_report.dart` (task
/// `2026-11-05_app-structure_split-commentary`). Commentary is derived
/// from the same event records as the report's statistics and ratings
/// — never from side calculations, so it can never contradict the
/// engine (GDD 13.1). `match_report.dart` re-exports this library so
/// consumer imports never churn.
library;

import 'injury.dart';
import 'match_event.dart';

/// Localizes the injury commentary family (T-0054): the only engine-chain
/// strings that resolve through l10n. Pure callers omit it and get the
/// English default; UI call sites pass a closure built from
/// [AppLocalizations] so Arabic renders natively (see
/// `lib/l10n/injury_l10n.dart`).
typedef InjuryCommentaryLocalizer =
    String Function(InjuryKind kind, String playerName, bool playsShort);

/// Commentary line generated from one event (GDD 13.1): includes the
/// contextual player names and event information.
///
/// [kind] drives the broadcast presentation: every key moment knows what
/// it is (goal, penalty, card, save...) so the feed can badge it with the
/// right icon and colour instead of a wall of samey text.
enum CommentaryKind {
  /// Filler narration — no icon, no badge.
  none,

  /// Referee's whistle moments.
  kickoff,
  halfTime,
  fullTime,

  /// The moments that get the crowd up.
  goal,
  penalty,
  redCard,
  yellowCard,
  save,
  injury,

  /// The manager's board and shouts.
  substitution,
  tactical,
  order,

  /// Supporting match beats.
  foul,
  offside,
  corner,
}

class CommentaryLine {
  const CommentaryLine({
    required this.minute,
    required this.second,
    required this.text,
    required this.importance,
    this.kind = CommentaryKind.none,
    this.detail,
    this.side,
  });

  final int minute;
  final int second;
  final String text;

  /// Timeline importance (GDD 13.3): 0 = filler, 1 = notable, 2 = key.
  final int importance;

  /// What this line IS — icon and accent in the feed come from here.
  final CommentaryKind kind;

  /// Secondary broadcast line: the running score after a goal
  /// ('Rivers United 1 - 0 Al Ahly').
  final String? detail;

  /// The team this line is about — the side whose colours the live
  /// moment card wears. Null on the referee's whistle moments
  /// (kick-off, half time, full time): those belong to the match, not
  /// to either team.
  final MatchSide? side;
}

/// Generates commentary lines from the event timeline (FR-031).
///
/// Player names are resolved through [playerNames]; unknown ids fall back
/// to role descriptions so commentary never contradicts events.
///
/// [keyEventsOnly] filters to the broadcast track: goals, penalties, red
/// cards, saves, bookings, kick-off/half-time/full-time and tactical
/// changes — the moments a real commentator raises his voice for. The
/// default keeps every line (filler included) for the full record.
List<CommentaryLine> generateCommentary(
  List<MatchEvent> events, {
  required Map<int, String> playerNames,
  required String homeTeamName,
  required String awayTeamName,
  bool keyEventsOnly = false,
  InjuryCommentaryLocalizer? injuryText,
}) {
  final lines = <CommentaryLine>[];
  String name(int? id) =>
      id == null ? 'a player' : (playerNames[id] ?? 'an opponent');
  String team(MatchEvent e) =>
      e.side == MatchSide.home ? homeTeamName : awayTeamName;

  // Running score, so every goal line can carry the broadcast detail
  // 'Rivers United 1 - 0 Al Ahly' — the moment needs the scoreline.
  var goalsHome = 0;
  var goalsAway = 0;

  for (final e in events) {
    switch (e.type) {
      case MatchEventType.kickoff:
        lines.add(
          CommentaryLine(
            minute: e.minute,
            second: e.second,
            text: e.metadata['secondHalf'] == true
                ? 'The second half is under way.'
                : 'Kick-off! $homeTeamName vs $awayTeamName.',
            importance: 1,
            kind: CommentaryKind.kickoff,
          ),
        );
      case MatchEventType.halfTime:
        lines.add(
          CommentaryLine(
            minute: 45,
            second: e.second,
            text:
                'Half time. $homeTeamName and $awayTeamName head to the dressing rooms.',
            importance: 1,
            kind: CommentaryKind.halfTime,
          ),
        );
      case MatchEventType.fullTime:
        lines.add(
          CommentaryLine(
            minute: 90,
            second: e.second,
            text: 'Full time! The referee blows the final whistle.',
            importance: 1,
            kind: CommentaryKind.fullTime,
          ),
        );
      case MatchEventType.possession:
        // Filler possession lines only for the first ones — avoids spam.
        if (lines.where((l) => l.importance == 0).length < 12) {
          lines.add(
            CommentaryLine(
              minute: e.minute,
              second: e.second,
              text: '${team(e)} keep the ball and look for an opening.',
              importance: 0,
              side: e.side,
            ),
          );
        }
      case MatchEventType.passMove:
        final extras = <String>[];
        if (e.metadata['cross'] == true) extras.add('whips in a cross');
        if (e.metadata['dribble'] == true) extras.add('beats his man');
        if (extras.isEmpty) break;
        lines.add(
          CommentaryLine(
            minute: e.minute,
            second: e.second,
            text:
                '${name(e.primaryPlayerId)} ${extras.join(' and ')} for ${team(e)}.',
            importance: 0,
            side: e.side,
          ),
        );
      case MatchEventType.dispossessed:
        final action = e.metadata['interception'] == true
            ? 'reads the pass and intercepts'
            : 'wins the ball with a firm tackle';
        lines.add(
          CommentaryLine(
            minute: e.minute,
            second: e.second,
            text:
                '${name(e.primaryPlayerId)} $action against ${name(e.secondaryPlayerId)}.',
            importance: 0,
            side: e.side,
          ),
        );
      case MatchEventType.offside:
        lines.add(
          CommentaryLine(
            minute: e.minute,
            second: e.second,
            text: '${name(e.primaryPlayerId)} is caught offside.',
            importance: 0,
            kind: CommentaryKind.offside,
            side: e.side,
          ),
        );
      case MatchEventType.foul:
        final inBox = e.metadata['inBox'] == true;
        final where = inBox
            ? 'in the box — the referee points to the spot!'
            : (e.metadata['finalThird'] == true
                  ? 'in a dangerous area'
                  : 'in midfield');
        lines.add(
          CommentaryLine(
            minute: e.minute,
            second: e.second,
            text:
                '${name(e.primaryPlayerId)} brings down ${name(e.secondaryPlayerId)} $where.',
            importance: inBox ? 2 : 0,
            kind: inBox ? CommentaryKind.penalty : CommentaryKind.foul,
            side: e.side,
          ),
        );
      case MatchEventType.penaltyAwarded:
        lines.add(
          CommentaryLine(
            minute: e.minute,
            second: e.second,
            text: 'PENALTY to ${team(e)}! ${name(e.primaryPlayerId)} steps up.',
            importance: 2,
            kind: CommentaryKind.penalty,
            side: e.side,
          ),
        );
      case MatchEventType.corner:
        lines.add(
          CommentaryLine(
            minute: e.minute,
            second: e.second,
            text: 'Corner for ${team(e)}, taken by ${name(e.primaryPlayerId)}.',
            importance: 0,
            kind: CommentaryKind.corner,
            side: e.side,
          ),
        );
      case MatchEventType.shot:
        if (e.shotOutcome == ShotOutcome.offTarget) {
          lines.add(
            CommentaryLine(
              minute: e.minute,
              second: e.second,
              text: '${name(e.primaryPlayerId)} shoots — off target.',
              importance: 0,
              side: e.side,
            ),
          );
        } else if (e.shotOutcome == ShotOutcome.blocked) {
          lines.add(
            CommentaryLine(
              minute: e.minute,
              second: e.second,
              text: '${name(e.primaryPlayerId)}\u2019s effort is blocked.',
              importance: 0,
              side: e.side,
            ),
          );
        } else if (e.shotOutcome == ShotOutcome.saved) {
          lines.add(
            CommentaryLine(
              minute: e.minute,
              second: e.second,
              text:
                  'Save! ${name(e.primaryPlayerId)} forces a stop from ${name(e.metadata['gkPlayerId'] as int?)}${e.metadata['isBigChance'] == true ? ' from a big chance' : ''}.',
              importance: 1,
              kind: CommentaryKind.save,
              side: e.side,
            ),
          );
        }
      case MatchEventType.goal:
        if (e.side == MatchSide.home) {
          goalsHome++;
        } else {
          goalsAway++;
        }
        final assist = e.secondaryPlayerId != null
            ? ' Assist: ${name(e.secondaryPlayerId)}.'
            : '';
        final qualityNote = switch (e.quality) {
          ChanceQuality.penalty => ' from the spot',
          ChanceQuality.freeKick => ' from the free kick',
          ChanceQuality.header => ' with a header',
          _ => '',
        };
        lines.add(
          CommentaryLine(
            minute: e.minute,
            second: e.second,
            text:
                'GOAL! ${name(e.primaryPlayerId)} scores$qualityNote for ${team(e)}!$assist',
            importance: 2,
            kind: CommentaryKind.goal,
            detail: '$homeTeamName $goalsHome - $goalsAway $awayTeamName',
            side: e.side,
          ),
        );
      case MatchEventType.card:
        final red = e.metadata['card'] == 'red';
        lines.add(
          CommentaryLine(
            minute: e.minute,
            second: e.second,
            text: red
                ? 'RED CARD! ${name(e.primaryPlayerId)} is sent off${e.metadata['secondYellow'] == true ? ' (second yellow)' : ''}!'
                : '${name(e.primaryPlayerId)} is booked.',
            importance: red ? 2 : 1,
            kind: red ? CommentaryKind.redCard : CommentaryKind.yellowCard,
            side: e.side,
          ),
        );
      case MatchEventType.injury:
        final kindName = e.metadata['kind'] as String?;
        final kind = InjuryKind.values.firstWhere(
          (k) => k.name == kindName,
          orElse: () => InjuryKind.knock,
        );
        final playsShort = e.metadata['playsShort'] == true;
        final playerName = name(e.primaryPlayerId);
        final base =
            injuryText?.call(kind, playerName, playsShort) ??
            (switch (kind) {
              InjuryKind.knock =>
                "$playerName picks up a knock and can't continue.",
              InjuryKind.muscle =>
                '$playerName pulls up with a muscle injury — his day is done.',
              InjuryKind.serious =>
                "$playerName suffers a serious injury. That doesn't look good.",
            });
        final text =
            base +
            (playsShort
                ? ' They have no replacement and play a man short.'
                : '');
        final matchesOut = e.metadata['matchesOut'];
        lines.add(
          CommentaryLine(
            minute: e.minute,
            second: e.second,
            text: text,
            importance: 2,
            kind: CommentaryKind.injury,
            side: e.side,
            // T-0056: the live banner renders the matches-out chip from
            // this payload — the ticker ignores it (it prints detail
            // only for goal score lines).
            detail: matchesOut == null ? null : '$matchesOut',
          ),
        );
      case MatchEventType.substitution:
        lines.add(
          CommentaryLine(
            minute: e.minute,
            second: e.second,
            text:
                'Substitution for ${team(e)}: ${name(e.secondaryPlayerId)} replaces ${name(e.primaryPlayerId)}.',
            importance: 1,
            kind: CommentaryKind.substitution,
            side: e.side,
          ),
        );
      case MatchEventType.tacticalChange:
        final change = e.metadata['change'] as String;
        final value = e.metadata['value'] as String;
        lines.add(
          CommentaryLine(
            minute: e.minute,
            second: e.second,
            text: e.metadata['ai'] == true
                ? '${team(e)} react — their manager switches to $value (${e.metadata['reason']}).'
                : '${team(e)} change their $change to $value.',
            importance: 1,
            kind: CommentaryKind.tactical,
            side: e.side,
          ),
        );
      case MatchEventType.liveAction:
        final action = e.metadata['action'] as String;
        lines.add(
          CommentaryLine(
            minute: e.minute,
            second: e.second,
            text: '${team(e)} are told to $action.',
            importance: 1,
            kind: CommentaryKind.order,
            side: e.side,
          ),
        );
    }
  }
  if (keyEventsOnly) {
    return lines.where((l) => l.importance > 0).toList();
  }
  return lines;
}
