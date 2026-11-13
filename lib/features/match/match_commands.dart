/// FCM Rivals — match commands (GDD 26.4): timestamped user (or AI)
/// actions applied in chronological order. Extracted from
/// `match_engine.dart` (app-structure review, task
/// `2026-11-05_app-structure_split-match-engine`).
library;

import 'match_event.dart';
import 'tactics.dart';

/// Match commands (GDD 26.4): timestamped user (or AI) actions, applied in
/// chronological order. [atMinute] is the match minute at which the change
/// takes effect; commands queued mid-match take effect from the next
/// simulated minute onward and never recalculate past events (FR-029).
abstract class MatchCommand {
  const MatchCommand({required this.atMinute, required this.side});

  final int atMinute;
  final MatchSide side;
}

class ChangeFormationCommand extends MatchCommand {
  const ChangeFormationCommand({
    required super.atMinute,
    required super.side,
    required this.formationCode,
  });

  final String formationCode;
}

class ChangeTacticsCommand extends MatchCommand {
  const ChangeTacticsCommand({
    required super.atMinute,
    required super.side,
    required this.tactics,
  });

  final TeamTactics tactics;
}

class ChangeMentalityCommand extends MatchCommand {
  const ChangeMentalityCommand({
    required super.atMinute,
    required super.side,
    required this.mentality,
  });

  final Mentality mentality;
}

class SubstitutionCommand extends MatchCommand {
  const SubstitutionCommand({
    required super.atMinute,
    required super.side,
    required this.outPlayerId,
    required this.inPlayerId,
  });

  final int outPlayerId;
  final int inPlayerId;
}

class LiveActionCommand extends MatchCommand {
  const LiveActionCommand({
    required super.atMinute,
    required super.side,
    required this.action,
  });

  final LiveMatchAction action;
}

/// A pre-match or half-time pep talk (GDD 15): team-wide multipliers that
/// never expire — a pre-match talk runs from kick-off, a half-time talk
/// from the second half. Replaces any earlier talk (no stacking), and
/// like every command it affects future events only.
class PepTalkCommand extends MatchCommand {
  const PepTalkCommand({
    required super.atMinute,
    required super.side,
    required this.talk,
  });

  final MatchPepTalk talk;
}

