/// FCM Rivals — matchday build-up screen (GDD 13 pre-match + 15.1 pep talk).
///
/// The full-screen experience before a fixture:
///
///   1. Opponent header — the rival under the microscope: crest, league
///      position and last-five form in one compact strip.
///   2. Analysis phase — win/draw/loss probabilities (a neutral
///      Monte-Carlo over BOTH full squad lists: starting XI, bench and
///      reserves, no tactics or condition), side-by-side strength bars
///      and the opponent's top three players as collection-style cards,
///      each staggering in.
///   3. Tactics phase  — the SAME tactics screen as the Team tab
///      (formation, playing style and mentality dropdowns with visible
///      percentage effects, pitch with stamina bars, bench and reserves),
///      except the changes apply to THIS MATCH ONLY: the club's saved
///      default setup is never touched (GDD 10.4 match-specific setup).
///   4. Pep talk phase — one motivational choice (GDD 15.1) with its
///      visible percentage effects; selecting one plays a short confirm
///      burst.
///   5. Kick-off       — hands the prepared selection to the caller.
///
/// The screen owns no session data: [onKickOff] receives the chosen talk
/// and the match-only tactic selection so the caller builds the session
/// exactly as before (FR-043: no ads).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/domain/players.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart';
import '../squad/formations.dart';
import '../squad/squad_engine.dart';
import '../squad/squad_view.dart';
import 'match_forecast.dart';
import 'tactics.dart';

/// Everything the analysis phase shows, pre-computed by the caller
/// (see [PreMatchData] in match_forecast.dart).

/// Full-screen matchday build-up: analysis → tactics → pep talk → kick-off.
class PreMatchScreen extends StatefulWidget {
  const PreMatchScreen({
    super.key,
    required this.data,
    required this.onKickOff,
    this.loading = false,
    this.error,
    this.onTacticsSelected,
    this.onExit,
  });

  final PreMatchData data;

  /// Receives the match-only tactic selection and the chosen pep talk
  /// (null = no talk), then pops.
  final void Function(MatchPepTalk? talk) onKickOff;

  /// True while the caller prepares the session (kick-off pressed).
  final bool loading;

  /// Error text from session preparation, shown inline.
  final String? error;

  /// Receives the tactic selections made in the tactics phase. The caller
  /// decides what they mean; on this screen they are match-only overrides
  /// that must NOT be persisted.
  final ValueChanged<PreMatchTacticSelection>? onTacticsSelected;

  /// Leaves the matchday build-up from the analysis phase before anything
  /// is committed — the fixture stays unplayed. Defaults to popping the
  /// route; hosts that wrap the screen pass their own pop.
  final VoidCallback? onExit;

  @override
  State<PreMatchScreen> createState() => _PreMatchScreenState();
}

/// The tactic choices made in the pre-match tactics phase (GDD 10.4):
/// MATCH-ONLY overrides — the session is built from them, and the club's
/// saved default setup stays exactly as it was.
class PreMatchTacticSelection {
  const PreMatchTacticSelection({
    required this.formationCode,
    required this.style,
    required this.mentality,
  });

  final String formationCode;
  final PlayingStyle style;
  final Mentality mentality;
}

class _PreMatchScreenState extends State<PreMatchScreen> {
  int _phase = 0; // 0 analysis, 1 tactics, 2 pep talk
  MatchPepTalk? _selectedTalk;
  late String _formationCode = widget.data.userFormationCode;
  late PlayingStyle _style = widget.data.userStyle;
  late Mentality _mentality = widget.data.userMentality;

  void _nextPhase() {
    HapticFeedback.selectionClick();
    setState(() => _phase++);
  }

  void _selectTalk(MatchPepTalk? talk) {
    HapticFeedback.mediumImpact();
    setState(() => _selectedTalk = talk);
  }

  void _kickOff() {
    HapticFeedback.heavyImpact();
    widget.onTacticsSelected?.call(
      PreMatchTacticSelection(
        formationCode: _formationCode,
        style: _style,
        mentality: _mentality,
      ),
    );
    widget.onKickOff(_selectedTalk);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final phase = _phase;
    return Scaffold(
      backgroundColor: FcmColors.night,
      body: FcmBackdrop(
        tint: FcmColors.gold,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: switch (phase) {
                    0 => _AnalysisPhase(
                      key: const ValueKey('analysis'),
                      data: d,
                    ),
                    1 => _TacticsPhase(
                      key: const ValueKey('tactics'),
                      data: d,
                      formationCode: _formationCode,
                      style: _style,
                      mentality: _mentality,
                      onFormation: (code) =>
                          setState(() => _formationCode = code),
                      onStyle: (s) => setState(() => _style = s),
                      onMentality: (m) => setState(() => _mentality = m),
                    ),
                    _ => _PepTalkPhase(
                      key: const ValueKey('pep'),
                      selected: _selectedTalk,
                      onSelect: _selectTalk,
                    ),
                  },
                ),
              ),
              _BottomBar(
                phase: phase,
                selectedTalk: _selectedTalk,
                loading: widget.loading,
                error: widget.error,
                onPrimary: phase == 2 ? _kickOff : _nextPhase,
                // Later phases step back through the build-up; the
                // analysis phase's BACK leaves the matchday (and the
                // fixture unplayed) via onExit — defaulting to a plain
                // pop when no host callback is given.
                onBack: _phase > 0
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _phase--);
                      }
                    : (widget.onExit ?? () => Navigator.of(context).maybePop()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Analysis phase
// -----------------------------------------------------------------------------

class _AnalysisPhase extends StatelessWidget {
  const _AnalysisPhase({super.key, required this.data});

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
      ],
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
    final initials = d.opponentClubName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
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
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
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
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: FcmColors.steelGradient,
                    border: Border.all(
                      color: FcmColors.bronze.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: FcmColors.bronze.withValues(alpha: 0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: FitText(
                    initials,
                    align: Alignment.center,
                    style: const TextStyle(
                      color: FcmColors.goldSoft,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.opponentClubName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${ordinalOf(d.opponentPosition)} in the table',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FcmColors.goldSoft,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
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
                          margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
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

/// Side-by-side strength bars: overall, attack, defence.
class _StrengthCard extends StatelessWidget {
  const _StrengthCard({required this.forecast});

  final MatchForecast forecast;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    Widget row(String label, double user, double opponent) {
      final uMax = user >= opponent;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FitText(
                  '${user.round()}',
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
                  '${opponent.round()}',
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
    final width = (MediaQuery.of(context).size.width - 28 - 16) / 3;
    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP PLAYERS',
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
              for (var i = 0; i < d.opponentKeyMen.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: FcmEntrance(
                    index: i,
                    dx: 22,
                    dy: 0,
                    duration: const Duration(milliseconds: 380),
                    child: FcmPlayerCard(
                      player: _basePlayerOf(d.opponentKeyMen[i]),
                      rarity: CardRarity.fromOverall(
                        d.opponentKeyMen[i].overall,
                      ),
                      overall: d.opponentKeyMen[i].overall,
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

// -----------------------------------------------------------------------------
// Tactics phase
// -----------------------------------------------------------------------------

/// Set up how this match is played (GDD 10.4): the SAME tactics screen as
/// the Team tab — formation, playing style and mentality dropdowns
/// with their visible percentage effects, the pitch with per-player
/// stamina bars (GDD 11), bench and reserves — with one difference: the
/// changes apply to THIS MATCH ONLY and never touch the club's saved
/// default setup. The starting XI is re-picked for the chosen shape in
/// memory, so the pitch previews the exact team that kicks off.
class _TacticsPhase extends StatelessWidget {
  const _TacticsPhase({
    super.key,
    required this.data,
    required this.formationCode,
    required this.style,
    required this.mentality,
    required this.onFormation,
    required this.onStyle,
    required this.onMentality,
  });

  final PreMatchData data;
  final String formationCode;
  final PlayingStyle style;
  final Mentality mentality;
  final ValueChanged<String> onFormation;
  final ValueChanged<PlayingStyle> onStyle;
  final ValueChanged<Mentality> onMentality;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final squad = d.userSquad;

    // Starting XI, bench and reserves for the SELECTED shape: a changed
    // formation re-picks the XI in memory (same rules as the Team tab's
    // Auto Pick) so what the user sees is the team that will kick off.
    final (xi, bench, reserves) = _squadFor(formationCode, squad);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: [
        FcmEntrance(
          child: Column(
            children: [
              const SizedBox(height: 4),
              const Text(
                'Set up for this match',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Same as your Team tab — but these changes last only '
                'until the final whistle. Your saved default setup is '
                'untouched.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FcmColors.textDim,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TacticsSetupView(
          formationCode: formationCode,
          style: style,
          mentality: mentality,
          xi: xi,
          bench: bench,
          reserves: reserves,
          onFormation: onFormation,
          onStyle: onStyle,
          onMentality: onMentality,
        ),
      ],
    );
  }
}

/// XI / bench / reserves for the selected formation: the persisted squad
/// re-projected onto the new shape with the Squad Engine's Auto Pick
/// rules (GDD 6.3), purely in memory — nothing is written back. Natural
/// positions land in their slots, the rest rank the bench and reserves
/// best-first, so what the user sees is the team that will kick off.
(Map<int, PlayerCard>, List<PlayerCard>, List<PlayerCard>) _squadFor(
  String formationCode,
  Map<int, PlayerCard> squad,
) {
  final cards = squad.values.toList();
  final assignment = const SquadEngine().autoPick(
    cards,
    formationByCode(formationCode),
  );
  final byId = {for (final c in cards) c.ownedId: c};

  final xi = <int, PlayerCard>{};
  final bench = <PlayerCard>[];
  final reserves = <PlayerCard>[];
  for (final e in assignment.entries) {
    final card = byId[e.value]!;
    if (e.key < Formation.startingXiSize) {
      xi[e.key] = card;
    } else if (e.key < Formation.startingXiSize + Formation.benchSize) {
      bench.add(card);
    } else {
      reserves.add(card);
    }
  }
  return (xi, bench, reserves);
}

// -----------------------------------------------------------------------------
// Pep talk phase
// -----------------------------------------------------------------------------

class _PepTalkPhase extends StatelessWidget {
  const _PepTalkPhase({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final MatchPepTalk? selected;
  final ValueChanged<MatchPepTalk?> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: [
        FcmEntrance(
          child: Column(
            children: [
              const SizedBox(height: 10),
              const FcmIconBadge(
                icon: Icons.record_voice_over_rounded,
                size: 76,
              ),
              const SizedBox(height: 16),
              const Text(
                'DRESSING ROOM',
                style: TextStyle(
                  color: FcmColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Deliver your team talk',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'One motivational choice — its effects last the whole match '
                'and are shown as percentages (GDD 15.1).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FcmColors.textDim,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < preMatchPepTalks.length; i++)
          FcmEntrance(
            index: i,
            duration: const Duration(milliseconds: 420),
            child: _PepTalkTile(
              talk: preMatchPepTalks[i],
              selected: selected?.id == preMatchPepTalks[i].id,
              onTap: () => onSelect(preMatchPepTalks[i]),
            ),
          ),
        const SizedBox(height: 8),
        FcmEntrance(
          index: preMatchPepTalks.length,
          duration: const Duration(milliseconds: 420),
          child: _PepTalkTile(
            talk: null,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
        ),
      ],
    );
  }
}

/// One selectable talk tile, or the "no talk" tile when [talk] is null.
class _PepTalkTile extends StatelessWidget {
  const _PepTalkTile({
    required this.talk,
    required this.selected,
    required this.onTap,
  });

  final MatchPepTalk? talk;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = talk;
    final effects = t == null ? 'No modifiers' : t.effectSummary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FcmPressable(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      Color.lerp(FcmColors.surfaceHigh, FcmColors.gold, 0.22)!,
                      FcmColors.surface,
                    ]
                  : [FcmColors.surfaceHigh, FcmColors.surface],
            ),
            border: Border.all(
              color: selected
                  ? FcmColors.gold.withValues(alpha: 0.8)
                  : FcmColors.bronze.withValues(alpha: 0.3),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: FcmColors.gold.withValues(alpha: 0.28),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? FcmColors.gold
                      : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: selected
                        ? FcmColors.goldSoft
                        : FcmColors.bronze.withValues(alpha: 0.5),
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: FcmColors.ink,
                        size: 20,
                      )
                    : const Icon(
                        Icons.record_voice_over_rounded,
                        color: FcmColors.textDim,
                        size: 17,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t?.label ?? 'No team talk',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      effects,
                      style: TextStyle(
                        color: t == null
                            ? FcmColors.textDim
                            : FcmColors.goldSoft,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (t != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        t.description,
                        style: const TextStyle(
                          color: FcmColors.textDim,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Bottom bar
// -----------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.phase,
    required this.selectedTalk,
    required this.loading,
    required this.error,
    required this.onPrimary,
    this.onBack,
  });

  /// 0 analysis, 1 tactics, 2 pep talk.
  final int phase;
  final MatchPepTalk? selectedTalk;
  final bool loading;
  final String? error;
  final VoidCallback onPrimary;

  /// Steps back one phase; on the analysis phase it leaves the matchday
  /// build-up (the fixture stays unplayed).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = switch (phase) {
      0 => 'CONTINUE',
      1 => 'TO DRESSING ROOM',
      _ => 'KICK OFF',
    };
    final primaryIcon = switch (phase) {
      0 => Icons.groups_rounded,
      1 => Icons.record_voice_over_rounded,
      _ => Icons.play_circle_fill_rounded,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: FcmColors.danger, fontSize: 12),
              ),
            ),
          Row(
            children: [
              if (onBack != null) ...[
                Expanded(
                  flex: 2,
                  child: FcmButton(
                    style: FcmButtonStyle.ghost,
                    label: 'BACK',
                    icon: Icons.arrow_back_rounded,
                    onPressed: onBack,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 3,
                child: FcmButton(
                  label: primaryLabel,
                  icon: primaryIcon,
                  loading: loading,
                  onPressed: onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
