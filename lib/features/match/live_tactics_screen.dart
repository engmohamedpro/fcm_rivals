/// FCM Rivals — live tactical changes screen (GDD 10.4/16).
///
/// The tactics button in the live match header opens THIS: the full
/// pitch editor — the same surface the user knows from before the
/// match (pre-match tactics phase / Team tab): a live pitch with the
/// current XI at formation coordinates, formation / playing style /
/// mentality with their visible effects, the 10-minute live actions
/// and the substitution picker. Every change queues for the next
/// minute boundary; the match clock is held while the editor is open.
library;

import 'package:flutter/material.dart';

import '../../core/domain/players.dart' show Position;
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart';
import '../../core/ui/match_backdrop.dart';
import '../squad/formations.dart';
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
    final formation = formationByCode(formationCode);
    final onPitch = engine.onPitchOf(_side);
    final style = engine.styleOf(_side);
    final mentality = engine.mentalityOf(_side);
    final nextMinute = widget.minuteQueuedFrom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Touchline'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            color: FcmColors.success, size: 16),
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
              _TacticsDropdownRow(
                label: 'Formation',
                child: FcmDropdown<String>(
                  icon: Icons.grid_on_rounded,
                  items: [
                    for (final f in formations)
                      FcmDropdownItem(value: f.code, label: f.name),
                  ],
                  selected: formationCode,
                  onChanged: (code) => _queue(ChangeFormationCommand(
                    atMinute: nextMinute,
                    side: _side,
                    formationCode: code,
                  )),
                ),
              ),
              const SizedBox(height: 10),
              _TacticsDropdownRow(
                label: 'Playing style',
                child: FcmDropdown<PlayingStyle>(
                  icon: Icons.directions_run_rounded,
                  items: [
                    for (final s in PlayingStyle.values)
                      FcmDropdownItem(
                          value: s, label: s.displayName, subtitle: s.effectSummary),
                  ],
                  selected: style,
                  onChanged: (s) => _queue(ChangeStyleCommand(
                    atMinute: nextMinute,
                    side: _side,
                    style: s,
                  )),
                ),
              ),
              const SizedBox(height: 10),
              _TacticsDropdownRow(
                label: 'Mentality',
                child: FcmDropdown<Mentality>(
                  icon: Icons.psychology_rounded,
                  items: [
                    for (final m in Mentality.values)
                      FcmDropdownItem(
                          value: m, label: m.displayName, subtitle: m.effectSummary),
                  ],
                  selected: mentality,
                  onChanged: (m) => _queue(ChangeMentalityCommand(
                    atMinute: nextMinute,
                    side: _side,
                    mentality: m,
                  )),
                ),
              ),
              const SizedBox(height: 14),
              FcmSectionTitle('Starting XI'),
              _LivePitch(formation: formation, players: onPitch),
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
                        onTap: () => _queue(LiveActionCommand(
                          atMinute: nextMinute,
                          side: _side,
                          action: a,
                        )),
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
                      color: FcmColors.textDim, fontSize: 11, height: 1.4),
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
}

class _TacticsDropdownRow extends StatelessWidget {
  const _TacticsDropdownRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: FcmColors.textDim,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// The live pitch: engine players at formation coordinates — the same
/// slot layout as the pre-match editor, with live stamina bars.
class _LivePitch extends StatelessWidget {
  const _LivePitch({required this.formation, required this.players});

  final Formation formation;
  final List<MatchPlayer> players;

  @override
  Widget build(BuildContext context) {
    // onPitchOf returns players in slot order (0 = keeper).
    final bySlot = <int, MatchPlayer>{
      for (var i = 0; i < players.length; i++) i: players[i],
    };
    return AspectRatio(
      aspectRatio: 1.05,
      child: LayoutBuilder(builder: (context, c) {
        final pw = c.maxWidth, ph = c.maxHeight;
        const cardW = 52.0;
        final slotW = cardW + 10;
        final slotH = cardW / kPlayerCardAspect + 40;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Same mown-grass base as the squad pitch.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF41502F), Color(0xFF57683F)],
                      ),
                    ),
                  ),
                ),
                for (var slot = 0; slot < formation.slots.length; slot++)
                  () {
                    final fs = formation.slots[slot];
                    final p = bySlot[slot];
                    return Positioned(
                      key: ValueKey('live-slot-$slot'),
                      left: 6 + (fs.x / 100) * (pw - slotW - 12),
                      top: 6 + (1 - fs.y / 100) * (ph - slotH - 12),
                      width: slotW,
                      child: p == null
                          ? const SizedBox.shrink()
                          : FcmMiniCard(
                              overall: _overallOf(p),
                              position: p.position.code,
                              name: p.name.split(' ').last,
                              rarity: CardRarity.rare,
                              width: cardW,
                              warn: fs.position != p.position,
                              stamina: p.stamina.round(),
                            ),
                    );
                  }(),
              ],
            ),
          ),
        );
      }),
    );
  }

  static int _overallOf(MatchPlayer p) {
    final gk = p.position == Position.gk;
    final best = gk
        ? [p.goalkeeping, p.defence, p.support]
        : [p.attack, p.support, p.defence];
    return best.reduce((a, b) => a > b ? a : b);
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
              const Icon(Icons.swap_horiz_rounded,
                  color: FcmColors.gold, size: 18),
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
              style:
                  TextStyle(color: FcmColors.textDim, fontSize: 12),
            )
          else ...[
            Text(
              _selectedOutLabel(),
              style: const TextStyle(
                  color: FcmColors.textDim, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (selectedOut == null)
                  for (final p in onPitch)
                    _PlayerChip(
                      player: p,
                      onTap: () => onSelectOut(p),
                    )
                else
                  for (final p in bench)
                    _PlayerChip(
                      player: p,
                      onTap: () {
                        session.queueCommand(SubstitutionCommand(
                          atMinute: session.engine.state.minute + 1,
                          side: side,
                          outPlayerId: selectedOut!.playerId,
                          inPlayerId: p.playerId,
                        ));
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
                          orElse: () => selectedOut!)),
                  child: const Text('Cancel selection'),
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

/// One substitution candidate: stamina avatar, name and position.
class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.player, required this.onTap});

  final MatchPlayer player;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          '${player.stamina.round()}%',
          style: theme.textTheme.labelSmall,
        ),
      ),
      label: Text('${player.name} (${player.position.code})'),
      onPressed: onTap,
    );
  }
}
