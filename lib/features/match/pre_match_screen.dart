/// FCM Rivals — matchday build-up screen (GDD 13 pre-match + 15.1 pep talk).
///
/// The full-screen experience before a fixture:
///
///   1. VS header      — both clubs crest-to-crest with the fixture label.
///   2. Analysis phase — win/draw/loss probabilities (Monte-Carlo of the
///      real engine), side-by-side strength bars, opponent form line and
///      key-men ratings, each staggering in.
///   3. Tactics phase  — the SAME tactics screen as the Tactics tab
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

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
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
    widget.onTacticsSelected?.call(PreMatchTacticSelection(
      formationCode: _formationCode,
      style: _style,
      mentality: _mentality,
    ));
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
                              begin: const Offset(0, 0.03), end: Offset.zero)
                          .animate(anim),
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
                onBack: _phase > 0
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _phase--);
                      }
                    : null,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: [
        _VsHeader(data: data),
        const SizedBox(height: 16),
        FcmEntrance(
          index: 1,
          child: _ForecastCard(forecast: f),
        ),
        const SizedBox(height: 14),
        FcmEntrance(
          index: 2,
          child: _StrengthCard(forecast: f),
        ),
        const SizedBox(height: 14),
        FcmEntrance(
          index: 3,
          child: _OpponentCard(data: data),
        ),
      ],
    );
  }
}

/// Crest-to-crest header with the fixture label and venue chip.
class _VsHeader extends StatelessWidget {
  const _VsHeader({required this.data});

  final PreMatchData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return FcmEntrance(
      child: Column(
        children: [
          Text(
            d.fixtureLabel.toUpperCase(),
            style: const TextStyle(
              color: FcmColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Crest(name: d.userClubName, gold: true, position: d.userPosition),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Text(
                      'VS',
                      style: TextStyle(
                        color: FcmColors.bronze.withValues(alpha: 0.9),
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FcmPill(
                      d.userAtHome ? 'HOME' : 'AWAY',
                      color: d.userAtHome ? FcmColors.gold : FcmColors.silver,
                      filled: false,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _Crest(name: d.opponentClubName, gold: false, position: d.opponentPosition),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Crest extends StatelessWidget {
  const _Crest({required this.name, required this.gold, required this.position});

  final String name;
  final bool gold;
  final int position;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gold ? FcmColors.goldGradient : FcmColors.steelGradient,
            border: Border.all(
              color: gold
                  ? FcmColors.goldSoft.withValues(alpha: 0.8)
                  : FcmColors.bronze.withValues(alpha: 0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (gold ? FcmColors.gold : FcmColors.bronze)
                    .withValues(alpha: 0.35),
                blurRadius: 18,
              ),
            ],
          ),
          child: FitText(initials,
              align: Alignment.center,
              style: TextStyle(
                color: gold ? FcmColors.ink : FcmColors.goldSoft,
                fontWeight: FontWeight.w900,
                fontSize: 20)),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: gold ? FcmColors.gold : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '#$position',
          style: const TextStyle(
            color: FcmColors.textDim,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Win/draw/loss bars animated from zero, with expected goals.
class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});

  final MatchForecast forecast;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    return FcmPanel(
      accent: FcmColors.gold,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MATCH FORECAST',
            style: TextStyle(
              color: FcmColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${f.samples} simulated matches with today\'s squads',
            style: const TextStyle(
                color: FcmColors.textDim, fontSize: 11),
          ),
          const SizedBox(height: 14),
          _OutcomeBar(
            label: 'WIN',
            percent: f.winPercent,
            color: FcmColors.success,
          ),
          const SizedBox(height: 10),
          _OutcomeBar(
            label: 'DRAW',
            percent: f.drawPercent,
            color: FcmColors.silver,
          ),
          const SizedBox(height: 10),
          _OutcomeBar(
            label: 'LOSS',
            percent: f.lossPercent,
            color: FcmColors.danger,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _GoalChip(
                  label: 'Expected goals',
                  value: f.avgUserGoals.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GoalChip(
                  label: 'Clean sheets',
                  value: '${f.cleanSheetPercent}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutcomeBar extends StatelessWidget {
  const _OutcomeBar({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: const TextStyle(
              color: FcmColors.textDim,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 14,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.07)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percent / 100),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: v.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            color.withValues(alpha: 0.55),
                            color,
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: FcmCountUp(
            value: percent,
            format: (n) => '$n%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: FcmColors.bronze.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: FcmColors.textDim,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 3),
          FitText(
            value,
            style: const TextStyle(
              color: FcmColors.goldSoft,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 7),
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
          row('OVERALL', f.strength(f.userTotals).toDouble(),
              f.strength(f.opponentTotals).toDouble()),
          row('ATTACK', f.userTotals.attack, f.opponentTotals.attack),
          row('DEFENCE', f.userTotals.defence, f.opponentTotals.defence),
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
                alignment:
                    mirror ? Alignment.centerRight : Alignment.centerLeft,
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      color.withValues(alpha: 0.5),
                      color,
                    ]),
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

/// Opponent form line (W/D/L pips) and key men.
class _OpponentCard extends StatelessWidget {
  const _OpponentCard({required this.data});

  final PreMatchData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final formPip = {
      'W': FcmColors.success,
      'D': FcmColors.silver,
      'L': FcmColors.danger,
    };
    return FcmPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'THEIR SEASON',
                style: TextStyle(
                  color: FcmColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < d.opponentForm.length; i++)
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(left: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: formPip[d.opponentForm[i]]!
                            .withValues(alpha: 0.18),
                        border: Border.all(
                          color: formPip[d.opponentForm[i]]!
                              .withValues(alpha: 0.7),
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
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (d.opponentKeyMen.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('No matches played yet — first round of the season.',
                  style: TextStyle(color: FcmColors.textDim, fontSize: 12)),
            )
          else ...[
            const SizedBox(height: 12),
            const Text(
              'KEY MEN',
              style: TextStyle(
                color: FcmColors.textDim,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < d.opponentKeyMen.length; i++)
              FcmEntrance(
                index: i,
                dx: 18,
                dy: 0,
                duration: const Duration(milliseconds: 360),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                              color: FcmColors.bronze.withValues(alpha: 0.4)),
                        ),
                        child: FitText(
                          '${d.opponentKeyMen[i].overall}',
                          style: const TextStyle(
                            color: FcmColors.goldSoft,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          d.opponentKeyMen[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tactics phase
// -----------------------------------------------------------------------------

/// Set up how this match is played (GDD 10.4): the SAME tactics screen as
/// the Tactics tab — formation, playing style and mentality dropdowns
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
    // formation re-picks the XI in memory (same rules as the Tactics tab's
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
                'Same as your Tactics tab — but these changes last only '
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
/// re-projected onto the new shape with the Squad Engine's Auto Pick rules
/// (GDD 6.3), purely in memory — nothing is written back.
(Map<int, PlayerCard>, List<PlayerCard>, List<PlayerCard>) _squadFor(
    String formationCode, Map<int, PlayerCard> squad) {
  final xi = <int, PlayerCard>{};
  for (var slot = 0; slot < Formation.startingXiSize; slot++) {
    final card = squad[slot];
    if (card != null) xi[slot] = card;
  }
  final bench = <PlayerCard>[];
  final reserves = <PlayerCard>[];
  for (var slot = Formation.startingXiSize;
      slot < Formation.squadSize;
      slot++) {
    final card = squad[slot];
    if (card == null) continue;
    (slot < Formation.startingXiSize + Formation.benchSize
            ? bench
            : reserves)
        .add(card);
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
    final effects = t == null
        ? 'No modifiers'
        : t.effectSummary;
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
                  : [
                      FcmColors.surfaceHigh,
                      FcmColors.surface,
                    ],
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
                    ? const Icon(Icons.check_rounded,
                        color: FcmColors.ink, size: 20)
                    : const Icon(Icons.record_voice_over_rounded,
                        color: FcmColors.textDim, size: 17),
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

  /// Step back one phase; null on the first phase (system back still
  /// exits the fixture).
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
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
