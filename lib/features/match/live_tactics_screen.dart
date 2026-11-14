/// FCM Rivals — live tactical changes screen (GDD 10.4/16).
///
/// The tactics button in the live match header opens THIS: the same
/// tactics surface the user knows from the pre-match phase and the
/// Team tab — control card with formation / custom tactics (with
/// their visible effects), the pitch with the CURRENT XI at formation
/// coordinates and live stamina bars, and the bench strip. No
/// reserves here: a live match only has the XI and the bench. The
/// mentality is edited on the live panel's own ladder, not here
/// (owner request 2026-11-13).
///
/// Every change queues for the next minute boundary; the match clock
/// is held while the editor is open. Substitutions run through the
/// same engine-enforced five windows as before.
library;

import 'package:flutter/material.dart';

import '../../core/domain/players.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/match_backdrop.dart';
import '../../l10n/l10n_context.dart';
import '../squad/formations.dart' show formationOfCode;
import '../squad/squad_engine.dart' show PlayerCard;
import '../squad/squad_view.dart' show TacticsSetupView;
import 'match_engine.dart';
import 'match_session.dart';
import 'tactics.dart';

/// Full-screen editor pushed over the frozen live match.
class LiveTacticsScreen extends StatefulWidget {
  const LiveTacticsScreen({
    super.key,
    required this.session,
    required this.minuteQueuedFrom,
  });

  final MatchSession session;

  /// Minute the queued commands apply at (next minute boundary).
  final int minuteQueuedFrom;

  @override
  State<LiveTacticsScreen> createState() => _LiveTacticsScreenState();
}

class _LiveTacticsScreenState extends State<LiveTacticsScreen> {
  MatchPlayer? _subOut;
  bool _queuedSomething = false;

  MatchSide get _side => widget.session.userSide;

  void _queue(MatchCommand command) {
    fcmTick();
    setState(() {
      widget.session.queueCommand(command);
      _queuedSomething = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.session.engine;
    final formationCode = engine.formationOf(_side);
    final onPitch = engine.onPitchOf(_side);
    final bench = engine.benchOf(_side);
    final tactics = engine.tacticsOf(_side);
    final nextMinute = widget.minuteQueuedFrom;

    // The live XI as display cards: real overall, live stamina — what
    // the user sees is the team that is actually on the pitch.
    final xiCards = <int, PlayerCard>{
      for (var slot = 0; slot < onPitch.length; slot++)
        slot: _cardOf(onPitch[slot]),
    };
    final benchCards = [for (final p in bench) _cardOf(p)];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10nOf(context).liveTacticsTitle),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: FcmButton(
              compact: true,
              icon: Icons.check_rounded,
              label: 'DONE',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
      body: FcmMatchBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (_queuedSomething)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FcmPanel(
                    accent: FcmColors.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: FcmColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Queued — takes effect in the '
                            "$nextMinute' minute. The match resumes when "
                            'you close this screen.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: const Text(
                    'Changes apply from the next minute. The match clock is '
                    'held while you set up.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FcmColors.textDim, fontSize: 12),
                  ),
                ),
              // The SAME surface as the Team tab, with match-day fitness
              // on: control card + pitch with stamina + bench (no stat
              // rows, no reserves — a live match has nobody beyond the
              // bench).
              TacticsSetupView(
                formation: formationOfCode(formationCode),
                tactics: tactics,
                xi: xiCards,
                bench: benchCards,
                reserves: const [],
                onFormation: (code) => _queue(
                  ChangeFormationCommand(
                    atMinute: nextMinute,
                    side: _side,
                    formationCode: code,
                  ),
                ),
                onTactics: (t) => _queue(
                  ChangeTacticsCommand(
                    atMinute: nextMinute,
                    side: _side,
                    tactics: t,
                  ),
                ),
                showStats: false,
                showReserves: false,
                onPlayerTap: _onPlayerTap,
              ),
              const SizedBox(height: 14),
              FcmSectionTitle('Live action · 10 minutes'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in LiveMatchAction.values)
                      FcmOptionChip(
                        label: a.displayName,
                        selected: false,
                        onTap: () => _queue(
                          LiveActionCommand(
                            atMinute: nextMinute,
                            side: _side,
                            action: a,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  'Live actions apply explicit Attack/Defence/Stamina '
                  'modifiers for 10 minutes and can be replaced any time. '
                  'Mentality shifts Attack and Defence by up to ±20%.',
                  style: TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _LiveSubstitutions(
                session: widget.session,
                side: _side,
                selectedOut: _subOut,
                onSelectOut: (p) => setState(() => _subOut = p),
                onQueued: () => setState(() {
                  _subOut = null;
                  _queuedSomething = true;
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tapping an on-pitch or bench card starts a substitution: the tapped
  /// player is the one coming off, the next tap on the bench confirms.
  /// The engine still enforces the five windows; tapping a bench player
  /// with nobody selected does nothing.
  void _onPlayerTap(PlayerCard card) {
    final engine = widget.session.engine;
    final onPitch = engine.onPitchOf(_side);
    final isOnPitch = onPitch.any((p) => p.playerId == card.base.playerId);
    if (isOnPitch) {
      fcmTick();
      setState(
        () => _subOut = onPitch.firstWhere(
          (p) => p.playerId == card.base.playerId,
        ),
      );
    } else if (_subOut != null) {
      final bench = engine.benchOf(_side);
      final sub = bench
          .where((p) => p.playerId == card.base.playerId)
          .firstOrNull;
      if (sub != null) {
        widget.session.queueCommand(
          SubstitutionCommand(
            atMinute: engine.state.minute + 1,
            side: _side,
            outPlayerId: _subOut!.playerId,
            inPlayerId: sub.playerId,
          ),
        );
        fcmTick();
        setState(() {
          _subOut = null;
          _queuedSomething = true;
        });
      }
    }
  }

  /// Display card for a live engine player: overall from his best live
  /// attributes (stamina is gone — owner request 2026-11-14).
  PlayerCard _cardOf(MatchPlayer p) {
    final gk = p.position == Position.gk;
    final overall = gk
        ? [p.goalkeeping, p.defence, p.support].reduce((a, b) => a > b ? a : b)
        : [p.attack, p.support, p.defence].reduce((a, b) => a > b ? a : b);
    return PlayerCard(
      ownedId: p.playerId,
      upgradeLevel: 0,
      base: BasePlayer(
        playerId: p.playerId,
        name: p.name,
        position: p.position,
        nationality: '',
        marketValueEur: 0,
        baseStats: BaseStats(
          overall: overall,
          attack: p.attack,
          support: p.support,
          defence: p.defence,
          goalkeeping: p.goalkeeping,
        ),
      ),
    );
  }
}

/// Substitution picker over the LIVE squad: tap the tiring player,
/// then the substitute. Five windows, engine-enforced.
class _LiveSubstitutions extends StatelessWidget {
  const _LiveSubstitutions({
    required this.session,
    required this.side,
    required this.selectedOut,
    required this.onSelectOut,
    required this.onQueued,
  });

  final MatchSession session;
  final MatchSide side;
  final MatchPlayer? selectedOut;
  final ValueChanged<MatchPlayer> onSelectOut;
  final VoidCallback onQueued;

  @override
  Widget build(BuildContext context) {
    final engine = session.engine;
    final used = engine.substitutionsUsedOf(side);
    final max = engine.config.maxSubstitutions;
    final onPitch = engine.onPitchOf(side);
    final bench = engine.benchOf(side);
    final remaining = max - used;

    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                color: FcmColors.gold,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Substitutions ($used/$max used)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (remaining <= 0 || bench.isEmpty)
            const Text(
              'No substitution windows remaining.',
              style: TextStyle(color: FcmColors.textDim, fontSize: 12),
            )
          else ...[
            Text(
              _selectedOutLabel(),
              style: const TextStyle(
                color: FcmColors.textDim,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (selectedOut == null)
                  for (final p in onPitch)
                    _PlayerChip(player: p, onTap: () => onSelectOut(p))
                else
                  for (final p in bench)
                    _PlayerChip(
                      player: p,
                      onTap: () {
                        session.queueCommand(
                          SubstitutionCommand(
                            atMinute: session.engine.state.minute + 1,
                            side: side,
                            outPlayerId: selectedOut!.playerId,
                            inPlayerId: p.playerId,
                          ),
                        );
                        fcmTick();
                        onQueued();
                      },
                    ),
              ],
            ),
            if (selectedOut != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton(
                  onPressed: () => onSelectOut(
                    onPitch.firstWhere(
                      (p) => p.playerId == selectedOut!.playerId,
                      orElse: () => selectedOut!,
                    ),
                  ),
                  child: Text(l10nOf(context).liveTacticsCancelSelection),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _selectedOutLabel() => selectedOut == null
      ? 'Tap the player coming off:'
      : 'Coming off: ${selectedOut!.name} — pick the substitute:';
}

/// One substitution candidate: name and position (the stamina avatar is
/// gone with the stamina system — owner request 2026-11-14).
class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.player, required this.onTap});

  final MatchPlayer player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text('${player.name} (${player.position.code})'),
      onPressed: onTap,
    );
  }
}
