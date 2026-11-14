/// FCM Rivals — pre-match analysis phase (GDD 13 pre-match).
///
/// Everything the analysis phase shows, pre-computed by the caller (see
/// [PreMatchData] in match_forecast.dart): the opponent header, the
/// win/draw/loss forecast, and the opponent's starting XI on a pitch —
/// the same pitch surface the Team tab renders the user's shape on
/// (owner request 2026-11-13: it replaced the side-by-side strength
/// bars and the top-player cards).
///
/// Split out of `pre_match_screen.dart` (task
/// `2026-11-05_app-structure_split-pre-match-screen`); the screen
/// imports this file directly.
library;

import 'package:flutter/material.dart';

import '../squad/formations.dart' show formationOfCode;
import '../squad/squad_engine.dart' show PlayerCard;
import '../squad/squad_pitch_view.dart' show SquadPitch;
import '../../core/domain/players.dart';
import '../../core/ui/fcm_club_badge.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/injury_badge.dart';
import '../../l10n/l10n_context.dart';
import 'match_event.dart' show MatchPlayer;
import 'match_forecast.dart';

/// The analysis phase: the opponent under the microscope — win/draw/loss
/// probabilities (a neutral Monte-Carlo over BOTH full squad lists:
/// starting XI, bench and reserves, no tactics or condition), and the
/// opponent's starting XI standing in their own formation on the Team
/// tab's pitch, each section staggering in.
class AnalysisPhase extends StatelessWidget {
  const AnalysisPhase({super.key, required this.data});

  final PreMatchData data;

  @override
  Widget build(BuildContext context) {
    final f = data.forecast;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      children: [
        _OpponentHeader(data: data),
        const SizedBox(height: 14),
        FcmEntrance(index: 1, child: _ForecastCard(forecast: f)),
        const SizedBox(height: 12),
        // The opponent's starting XI on the Team tab's pitch surface
        // (owner request 2026-11-13) — replaced the strength bars and
        // the top-player cards. Read-only: no drag host wraps it, so
        // the cards are tappable details at most; the flags mirror the
        // Team tab's own management view.
        FcmEntrance(index: 2, child: _OpponentFormationCard(data: data)),
        // The medical room (T-0056): who is out and for how long, before
        // the user commits a lineup. Hidden entirely when everyone fits —
        // no empty section.
        if (data.userSquad.values.any((c) => c.injuryMatchesRemaining > 0))
          ...[
            const SizedBox(height: 12),
            FcmEntrance(index: 3, child: _MedicalRoomCard(data: data)),
          ],
      ],
    );
  }
}

/// The pre-match availability section (T-0056): every injured player of
/// the user's squad with his badge and matches-out count, EN and AR.
class _MedicalRoomCard extends StatelessWidget {
  const _MedicalRoomCard({required this.data});

  final PreMatchData data;

  @override
  Widget build(BuildContext context) {
    final injured =
        data.userSquad.values
            .where((c) => c.injuryMatchesRemaining > 0)
            .toList()
          ..sort((a, b) => a.injuryMatchesRemaining.compareTo(
            b.injuryMatchesRemaining,
          ));
    return FcmPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.medical_services_outlined,
                size: 16,
                color: FcmColors.danger,
              ),
              const SizedBox(width: 6),
              Text(
                l10nOf(context).prematchMedicalTitle,
                style: const TextStyle(
                  color: FcmColors.danger,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final c in injured)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  InjuryBadge(
                    matchesOut: c.injuryMatchesRemaining,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.base.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    l10nOf(
                      context,
                    ).injuryOutForMatches(c.injuryMatchesRemaining),
                    style: const TextStyle(
                      color: FcmColors.textDim,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The opponent under the microscope, in one compact strip: crest, club
/// name with league position, and the last-five form pips (W/D/L) — the
/// user's own club stays out of the analysis.
class _OpponentHeader extends StatelessWidget {
  const _OpponentHeader({required this.data});

  final PreMatchData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final formPip = {
      'W': FcmColors.success,
      'D': FcmColors.silver,
      'L': FcmColors.danger,
    };
    return FcmEntrance(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    d.fixtureLabel.toUpperCase(),
                    maxLines: 1,
                    style: const TextStyle(
                      color: FcmColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FcmPill(
                d.userAtHome ? 'HOME' : 'AWAY',
                color: d.userAtHome ? FcmColors.gold : FcmColors.silver,
                filled: false,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // T-0131: the team-vs-team card is GONE (owner request
          // 2026-11-13) — the analysis is about the opponent, so the
          // header carries the fixture line and the opponent's form
          // only; the opponent's crest, name and table position now
          // lead THEIR STARTING XI card below.
          // The opponent's recent form and the league-positions
          // comparison stay as they were (T-0102 out of scope).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Builder(
                builder: (context) {
                  final l10n = l10nOf(context);
                  final localized = l10n.localeName == 'ar';
                  final user = localized
                      ? _arabicPositionOf(d.userPosition)
                      : ordinalOf(d.userPosition);
                  final opp = localized
                      ? _arabicPositionOf(d.opponentPosition)
                      : ordinalOf(d.opponentPosition);
                  return Text(
                    l10n.prematchPositionsVersus(
                      user,
                      opp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FcmColors.goldSoft,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              if (d.opponentForm.isEmpty)
                const Text(
                  'First round',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: FcmColors.textDim, fontSize: 11),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < d.opponentForm.length; i++)
                      Container(
                        width: 20,
                        height: 20,
                        margin: EdgeInsetsDirectional.only(
                          start: i == 0 ? 0 : 4,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: formPip[d.opponentForm[i]]!.withValues(
                            alpha: 0.18,
                          ),
                          border: Border.all(
                            color: formPip[d.opponentForm[i]]!.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        child: FcmEntrance(
                          index: i,
                          dy: 0,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            d.opponentForm[i],
                            style: TextStyle(
                              color: formPip[d.opponentForm[i]],
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Loss/draw/win share of the simulated matches, one row, one line.
class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});

  final MatchForecast forecast;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    return FcmPanel(
      accent: FcmColors.gold,
      glow: true,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: _OutcomeStat(
              label: 'LOSS',
              percent: f.lossPercent,
              color: FcmColors.danger,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _OutcomeStat(
              label: 'DRAW',
              percent: f.drawPercent,
              color: FcmColors.silver,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _OutcomeStat(
              label: 'WIN',
              percent: f.winPercent,
              color: FcmColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

/// One loss/draw/win stat: caps label over an animated count-up percent.
class _OutcomeStat extends StatelessWidget {
  const _OutcomeStat({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.85),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 3),
        FcmCountUp(
          value: percent,
          format: (n) => '$n%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}

/// The opponent's starting XI on the Team tab's pitch surface (owner
/// request 2026-11-13 — replaced the strength bars and top-player
/// cards). Each man stands in his own formation slot, exactly where
/// the match will place him: [PreMatchData.opponentSquad] arrives in
/// slot order, [formationOfCode] resolves the club's persisted shape
/// (preset or custom), and [SquadPitch] renders it with the same
/// painter, card faces, chemistry links and sizing solver the Team
/// tab uses.
///
/// Read-only by construction: no [SquadDragHost] wraps the pitch, so
/// the drag scope is absent, cards render without pickup/drop targets,
/// and taps lead nowhere (the analysis is scouting, not management).
/// The flags mirror the Team tab's own management view — no stamina
/// bars, no stat rows, no match-day condition chrome — with one
/// deliberate difference: the CHEMISTRY LINKS stay on, so the user
/// can read the opponent's national/club pairs the way the Team tab
/// reads his own.
class _OpponentFormationCard extends StatelessWidget {
  const _OpponentFormationCard({required this.data});

  final PreMatchData data;

  @override
  Widget build(BuildContext context) {
    final formation = formationOfCode(data.opponentFormationCode);
    // Slot i ← man i: opponentSquad arrives in formation-slot order
    // (GK first), the same convention as the user's squad map.
    final assignments = <int, PlayerCard>{
      for (var i = 0; i < data.opponentSquad.length; i++)
        if (i < formation.slots.length)
          i: _cardOf(data.opponentSquad[i]),
    };
    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // T-0131 (owner request 2026-11-13): the card's header IS the
          // opponent now — crest, club name and table position replace
          // the old "Their starting XI" label. The formation code pill
          // stays on the end.
          Row(
            children: [
              FcmClubBadge(
                name: data.opponentClubName,
                crest: data.opponentCrest,
                size: 40,
                isUser: false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.opponentClubName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FcmColors.gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Builder(
                      builder: (context) {
                        final l10n = l10nOf(context);
                        final localized = l10n.localeName == 'ar';
                        final position = localized
                            ? _arabicPositionOf(data.opponentPosition)
                            : ordinalOf(data.opponentPosition);
                        return Text(
                          l10n.prematchTablePosition(position),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FcmColors.goldSoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // The shape's own code ('4-3-3') — the identifier the
              // match will play, next to the section it explains.
              FcmPill(
                formation.code,
                color: FcmColors.silver,
                filled: false,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SquadPitch(
            formation: formation,
            assignments: assignments,
            showChemistryLinks: true,
            showStamina: false,
            showStats: false,
            showCondition: false,
          ),
        ],
      ),
    );
  }

  /// Maps one opponent [MatchPlayer] onto a [PlayerCard] for the pitch
  /// surface: identity fields ride (nationality and club feed the
  /// chemistry links), overall and attributes come straight from the
  /// engine's pre-upgrade values. Market value and image URLs are facts
  /// the analysis does not know — they stay neutral, matching how the
  /// old top-player cards bridged the same gap.
  static PlayerCard _cardOf(MatchPlayer p) => PlayerCard(
    ownedId: p.playerId,
    upgradeLevel: 0,
    base: BasePlayer(
      playerId: p.playerId,
      name: p.name,
      position: p.position,
      nationality: p.nationality,
      marketValueEur: 0,
      clubId: p.clubId,
      clubName: p.clubName,
      isIcon: p.isIcon,
      baseStats: BaseStats(
        overall: ((p.attack + p.support + p.defence) / 3).round(),
        attack: p.attack,
        support: p.support,
        defence: p.defence,
        goalkeeping: p.goalkeeping,
      ),
    ),
    staminaPercent: p.stamina.round(),
  );
}

/// Natural-Arabic league position for the pre-match lines (T-0139):
/// 'الأول' .. 'العشرون' for the positions a table actually holds, and
/// the plain 'المركز N' beyond — no transliterated EN suffixes.
String _arabicPositionOf(int n) {
  const words = [
    'الأول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الخامس',
    'السادس',
    'السابع',
    'الثامن',
    'التاسع',
    'العاشر',
    'الحادي عشر',
    'الثاني عشر',
    'الثالث عشر',
    'الرابع عشر',
    'الخامس عشر',
    'السادس عشر',
    'السابع عشر',
    'الثامن عشر',
    'التاسع عشر',
    'العشرون',
  ];
  return n >= 1 && n <= words.length ? words[n - 1] : 'المركز $n';
}
