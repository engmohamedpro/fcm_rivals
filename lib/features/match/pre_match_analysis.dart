/// FCM Rivals — pre-match analysis phase (GDD 13 pre-match).
///
/// Everything the analysis phase shows, pre-computed by the caller (see
/// [PreMatchData] in match_forecast.dart): the opponent header, the
/// win/draw/loss forecast, the side-by-side strength bars and the
/// opponent's top players.
///
/// Split out of `pre_match_screen.dart` (task
/// `2026-11-05_app-structure_split-pre-match-screen`); the screen
/// imports this file directly.
library;

import 'package:flutter/material.dart';

import '../squad/squad_engine.dart' show PlayerCard;
import '../../core/domain/players.dart';
import '../../core/domain/crest.dart' show CrestSpec;
import '../../core/ui/fcm_club_badge.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/injury_badge.dart';
import '../../l10n/l10n_context.dart';
import '../../core/ui/player_card.dart';
import 'match_forecast.dart';

/// The analysis phase: the opponent under the microscope — win/draw/loss
/// probabilities (a neutral Monte-Carlo over BOTH full squad lists:
/// starting XI, bench and reserves, no tactics or condition),
/// side-by-side strength bars and the opponent's top three players as
/// collection-style cards, each staggering in.
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
        FcmEntrance(index: 2, child: _StrengthCard(forecast: f)),
        const SizedBox(height: 12),
        FcmEntrance(index: 3, child: _TopPlayersCard(data: data)),
        // The medical room (T-0056): who is out and for how long, before
        // the user commits a lineup. Hidden entirely when everyone fits —
        // no empty section.
        if (data.userSquad.values.any((c) => c.injuryMatchesRemaining > 0))
          ...[
            const SizedBox(height: 12),
            FcmEntrance(index: 4, child: _MedicalRoomCard(data: data)),
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
          // T-0102: team vs team — the fixture's HOME club at the
          // start, AWAY at the end, regardless of the user's side; the
          // user's chip carries the gold accent so their side is
          // obvious. Row order mirrors with the text direction.
          Container(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  FcmColors.bronze.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
              border: Border.all(
                color: FcmColors.bronze.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TeamChip(
                    clubName: d.userAtHome
                        ? d.userClubName
                        : d.opponentClubName,
                    position: d.userAtHome
                        ? d.userPosition
                        : d.opponentPosition,
                    crest: d.userAtHome ? d.userCrest : d.opponentCrest,
                    isUser: d.userAtHome,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: FcmColors.gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: _TeamChip(
                    clubName: d.userAtHome
                        ? d.opponentClubName
                        : d.userClubName,
                    position: d.userAtHome
                        ? d.opponentPosition
                        : d.userPosition,
                    crest: d.userAtHome ? d.opponentCrest : d.userCrest,
                    isUser: !d.userAtHome,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // The opponent's recent form and the league-positions
          // comparison stay as they were (T-0102 out of scope).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${ordinalOf(d.userPosition)} vs '
                '${ordinalOf(d.opponentPosition)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FcmColors.goldSoft,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
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

/// One side of the team-vs-team header (T-0102): the club's crest,
/// name and table position stacked — compact, gold-accented when it is
/// the user's club, steel otherwise.
class _TeamChip extends StatelessWidget {
  const _TeamChip({
    required this.clubName,
    required this.position,
    required this.crest,
    required this.isUser,
  });

  final String clubName;
  final int position;
  final CrestSpec? crest;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FcmClubBadge(name: clubName, crest: crest, size: 54, isUser: isUser),
        const SizedBox(height: 6),
        Text(
          clubName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isUser ? FcmColors.gold : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${ordinalOf(position)} in the table',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: FcmColors.goldSoft,
            fontWeight: FontWeight.w800,
            fontSize: 10.5,
          ),
        ),
      ],
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

/// Side-by-side strength bars: overall, attack, defence.
class _StrengthCard extends StatelessWidget {
  const _StrengthCard({required this.forecast});

  final MatchForecast forecast;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    Widget row(
      String label,
      double user,
      double opponent, {
      String Function(double v)? format,
    }) {
      final uMax = user >= opponent;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FitText(
                  format != null ? format(user) : '${user.round()}',
                  style: TextStyle(
                    color: uMax ? FcmColors.gold : Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                FitText(
                  format != null ? format(opponent) : '${opponent.round()}',
                  style: TextStyle(
                    color: !uMax ? FcmColors.gold : Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: _MirrorBar(
                    value: user,
                    color: uMax ? FcmColors.gold : FcmColors.bronze,
                    mirror: true,
                  ),
                ),
                const SizedBox(width: 26),
                Expanded(
                  child: _MirrorBar(
                    value: opponent,
                    color: !uMax ? FcmColors.gold : FcmColors.bronze,
                    mirror: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'STRENGTH',
                style: TextStyle(
                  color: FcmColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              Row(
                children: [
                  Icon(
                    f.attackAdvantage >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 14,
                    color: f.attackAdvantage >= 0
                        ? FcmColors.success
                        : FcmColors.danger,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${f.attackAdvantage >= 0 ? '+' : ''}${f.attackAdvantage} attack edge',
                    style: TextStyle(
                      color: f.attackAdvantage >= 0
                          ? FcmColors.success
                          : FcmColors.danger,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          row(
            'OVERALL',
            f.strength(f.userTotals).toDouble(),
            f.strength(f.opponentTotals).toDouble(),
          ),
          row('ATTACK', f.userTotals.attack, f.opponentTotals.attack),
          row('SUPPORT', f.userTotals.support, f.opponentTotals.support),
          row('DEFENCE', f.userTotals.defence, f.opponentTotals.defence),
          row(
            'GOALKEEPING',
            f.userTotals.goalkeeping,
            f.opponentTotals.goalkeeping,
          ),
          // Chemistry comparison (T-0069; nationality + club since
          // 2026-11-11): the engine applies +N% to both sides' totals,
          // so the pre-match sheet shows it beside them — '+N%' per
          // side, same row shape.
          row(
            l10nOf(context).teamChemistry.toUpperCase(),
            f.userChemistry.toDouble(),
            f.opponentChemistry.toDouble(),
            format: (v) => '+${v.round()}%',
          ),
        ],
      ),
    );
  }
}

/// Half bar that grows leftwards (mirror) or rightwards.
class _MirrorBar extends StatelessWidget {
  const _MirrorBar({
    required this.value,
    required this.color,
    required this.mirror,
  });

  final double value;
  final Color color;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 9,
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.07)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value / 99).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: mirror
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.5), color],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The opponent's three highest-rated players, rendered as collection
/// player cards (same shield face, rarity metals and stat columns as the
/// Collection tab) side by side in one row.
class _TopPlayersCard extends StatelessWidget {
  const _TopPlayersCard({required this.data});

  final PreMatchData data;

  @override
  Widget build(BuildContext context) {
    final d = data;

    // T-0102: the best player of EACH side, ordered like the header
    // (the home side's best first). The user's best comes from his
    // full squad with the key-men formula ((attack + support +
    // defence) / 3 — the producer's own sort), the opponent's is the
    // already-sorted key-men list's head.
    final userBest = _bestOfSquad(d.userSquad.values.toList());
    final opponentBest = d.opponentKeyMen.isEmpty ? null : (
      name: d.opponentKeyMen.first.name,
      position: d.opponentKeyMen.first.position,
      overall: d.opponentKeyMen.first.overall,
      attack: d.opponentKeyMen.first.attack,
      support: d.opponentKeyMen.first.support,
      defence: d.opponentKeyMen.first.defence,
      goalkeeping: d.opponentKeyMen.first.goalkeeping,
    );

    // Empty-squad edge (the medical room's conditional pattern): hide
    // the whole section when either side has nobody to show.
    if (userBest == null || opponentBest == null) return const SizedBox();

    final sides = d.userAtHome ? [userBest, opponentBest] : [opponentBest, userBest];
    final width = (MediaQuery.of(context).size.width - 28 - 12) / 2;
    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP PLAYER',
            style: TextStyle(
              color: FcmColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < sides.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: FcmEntrance(
                    index: i,
                    dx: 22,
                    dy: 0,
                    duration: const Duration(milliseconds: 380),
                    child: FcmPlayerCard(
                      player: _basePlayerOf(sides[i]),
                      rarity: CardRarity.fromOverall(sides[i].overall),
                      overall: sides[i].overall,
                      width: width,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// The squad's best player by the key-men formula — identical math
  /// to the producer's sort (`(attack + support + defence) / 3`
  /// rounded), computed here from the persisted card list so
  /// [PreMatchData]'s contract stays untouched.
  static ({
    String name,
    String position,
    int overall,
    int attack,
    int support,
    int defence,
    int goalkeeping,
  })? _bestOfSquad(List<PlayerCard> squad) {
    ({
      String name,
      String position,
      int overall,
      int attack,
      int support,
      int defence,
      int goalkeeping,
    })? best;
    var bestScore = -1;
    for (final card in squad) {
      final attack = card.attribute(PlayerAttribute.attack);
      final support = card.attribute(PlayerAttribute.support);
      final defence = card.attribute(PlayerAttribute.defence);
      final score = ((attack + support + defence) / 3).round();
      if (score > bestScore) {
        bestScore = score;
        best = (
          name: card.base.name,
          position: card.position.code,
          overall: card.overall,
          attack: attack,
          support: support,
          defence: defence,
          goalkeeping: card.attribute(PlayerAttribute.goalkeeping),
        );
      }
    }
    return best;
  }

  /// The key-man record mapped onto a [BasePlayer] so the real collection
  /// card face renders it; identity fields the analysis does not know
  /// stay neutral (the flag falls back to a football glyph).
  static BasePlayer _basePlayerOf(
    ({
      String name,
      String position,
      int overall,
      int attack,
      int support,
      int defence,
      int goalkeeping,
    })
    m,
  ) {
    final stats = BaseStats(
      overall: m.overall,
      attack: m.attack,
      support: m.support,
      defence: m.defence,
      goalkeeping: m.goalkeeping,
    );
    return BasePlayer(
      playerId: -1 - m.overall,
      name: m.name,
      position: Position.fromCode(m.position),
      nationality: '',
      marketValueEur: 0,
      baseStats: stats,
    );
  }
}
