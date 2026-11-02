/// FCM Rivals — shared tactical setup surface (GDD 10/11).
///
/// One implementation of the tactics screen, used in two places:
///
///  * the Tactics tab — every change goes straight to the club's saved
///    setup and becomes the permanent default (GDD 10.4);
///  * the pre-match tactics phase — the same controls and the same pitch,
///    but the selection lives only for the match about to be played and
///    the saved setup is never touched.
///
/// The caller decides the semantics by what it does in [onFormation],
/// [onStyle] and [onMentality]; the view itself is stateless.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/players.dart' show Position;
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart';
import '../collection/player_detail_sheet.dart' show rarityOf;
import '../match/tactics.dart';
import 'formations.dart';
import 'squad_engine.dart';

/// The whole tactical setup column: team rating, the three tactic
/// dropdowns (formation, playing style, mentality — GDD 10), the pitch
/// with the starting XI and per-player stamina bars (GDD 11), then the
/// bench and reserves strips.
class TacticsSetupView extends StatelessWidget {
  const TacticsSetupView({
    super.key,
    required this.formationCode,
    required this.style,
    required this.mentality,
    required this.xi,
    required this.bench,
    required this.reserves,
    required this.onFormation,
    required this.onStyle,
    required this.onMentality,
    this.onAutoPick,
    this.onPlayerTap,
    this.modeNote,
  });

  /// Currently selected formation code (e.g. '4-3-3').
  final String formationCode;

  /// Current playing style / mentality selections (GDD 10.2/10.3).
  final PlayingStyle style;
  final Mentality mentality;

  /// Starting XI assignments: slot index → card.
  final Map<int, PlayerCard> xi;

  /// Bench and reserves cards, slot order.
  final List<PlayerCard> bench;
  final List<PlayerCard> reserves;

  /// Tactic change callbacks — the owner defines whether they persist
  /// (Tactics tab) or apply to one match only (pre-match phase).
  final ValueChanged<String> onFormation;
  final ValueChanged<PlayingStyle> onStyle;
  final ValueChanged<Mentality> onMentality;

  /// Shows the Auto Pick button (GDD 6.3) when non-null — the Tactics tab
  /// persists a re-picked squad; pre-match hides it.
  final VoidCallback? onAutoPick;

  /// Opens the player detail sheet; null makes the cards non-tappable.
  final void Function(PlayerCard card)? onPlayerTap;

  /// One-line note under the tactics panel explaining the persistence
  /// semantics of this surface (permanent default vs. this match only).
  final String? modeNote;

  @override
  Widget build(BuildContext context) {
    final formation = formationByCode(formationCode);
    final teamRating = xi.isEmpty
        ? 0
        : (xi.values.fold<int>(0, (a, c) => a + c.overall) / xi.length)
            .round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FcmEntrance(
          child: FcmPanel(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TEAM RATING',
                    style: TextStyle(
                        color: FcmColors.textDim,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2)),
                FcmCountUp(
                  value: teamRating,
                  style: TextStyle(
                    color: ratingColor(teamRating),
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                if (onAutoPick != null) ...[
                  const SizedBox(height: 12),
                  FcmButton(
                    compact: true,
                    style: FcmButtonStyle.steel,
                    icon: Icons.auto_awesome,
                    label: 'Auto Pick',
                    onPressed: onAutoPick,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FcmEntrance(
          index: 1,
          child: _TacticsPanel(
            formationCode: formationCode,
            style: style,
            mentality: mentality,
            onFormation: onFormation,
            onStyle: onStyle,
            onMentality: onMentality,
            modeNote: modeNote,
          ),
        ),
        const SizedBox(height: 14),
        FcmEntrance(
          index: 2,
          child: SquadPitch(
            formation: formation,
            assignments: xi,
            onPlayerTap: onPlayerTap,
          ),
        ),
        if (bench.isNotEmpty) ...[
          FcmSectionTitle('Bench (${bench.length}/${Formation.benchSize})'),
          SquadCardRow(cards: bench, onPlayerTap: onPlayerTap),
        ],
        if (reserves.isNotEmpty) ...[
          FcmSectionTitle(
              'Reserves (${reserves.length}/${Formation.squadSize - Formation.startingXiSize - Formation.benchSize})'),
          SquadCardRow(cards: reserves, onPlayerTap: onPlayerTap),
        ],
      ],
    );
  }
}

/// The three tactic selectors (GDD 10) as dropdowns — formation, playing
/// style and mentality — each opening a bottom sheet that lists every
/// option with its visible percentage effects (GDD 10.3).
class _TacticsPanel extends StatelessWidget {
  const _TacticsPanel({
    required this.formationCode,
    required this.style,
    required this.mentality,
    required this.onFormation,
    required this.onStyle,
    required this.onMentality,
    this.modeNote,
  });

  final String formationCode;
  final PlayingStyle style;
  final Mentality mentality;
  final ValueChanged<String> onFormation;
  final ValueChanged<PlayingStyle> onStyle;
  final ValueChanged<Mentality> onMentality;
  final String? modeNote;

  @override
  Widget build(BuildContext context) {
    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TACTICS',
              style: TextStyle(
                  color: FcmColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2)),
          const SizedBox(height: 12),
          _dropdownRow(
            label: 'FORMATION',
            child: FcmDropdown<String>(
              icon: Icons.grid_on_rounded,
              items: [
                for (final f in formations)
                  FcmDropdownItem(value: f.code, label: f.name),
              ],
              selected: formationCode,
              onChanged: onFormation,
            ),
          ),
          const SizedBox(height: 12),
          _dropdownRow(
            label: 'PLAYING STYLE',
            child: FcmDropdown<PlayingStyle>(
              icon: Icons.directions_run_rounded,
              items: [
                for (final s in PlayingStyle.values)
                  FcmDropdownItem(
                      value: s, label: s.displayName, subtitle: s.effectSummary),
              ],
              selected: style,
              onChanged: onStyle,
            ),
          ),
          const SizedBox(height: 12),
          _dropdownRow(
            label: 'MENTALITY',
            child: FcmDropdown<Mentality>(
              icon: Icons.psychology_rounded,
              items: [
                for (final m in Mentality.values)
                  FcmDropdownItem(
                      value: m, label: m.displayName, subtitle: m.effectSummary),
              ],
              selected: mentality,
              onChanged: onMentality,
            ),
          ),
          if (modeNote != null) ...[
            const SizedBox(height: 12),
            Text(
              modeNote!,
              style:
                  const TextStyle(color: FcmColors.textDim, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dropdownRow({required String label, required Widget child}) {
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

/// Renders the pitch with player cards at formation coordinates (GDD 6.2),
/// each card carrying a colour-coded stamina bar. Cards glide to their
/// new spots when the formation changes.
class SquadPitch extends StatelessWidget {
  const SquadPitch({
    super.key,
    required this.formation,
    required this.assignments,
    this.onPlayerTap,
  });

  final Formation formation;

  /// Slot index → card for the starting XI.
  final Map<int, PlayerCard> assignments;

  /// Optional card tap (player detail sheet).
  final void Function(PlayerCard card)? onPlayerTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.68,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: LayoutBuilder(builder: (context, constraints) {
            final pw = constraints.maxWidth;
            final ph = constraints.maxHeight;
            final cw = (pw * 0.145).clamp(42.0, 62.0);
            final slotW = cw + 12;
            final slotH = cw / kPlayerCardAspect + 20;
            return Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _PitchPainter()),
                ),
                for (var slot = 0; slot < formation.slots.length; slot++)
                  () {
                    final fs = formation.slots[slot];
                    final card = assignments[slot];
                    return AnimatedPositioned(
                      key: ValueKey('slot-$slot'),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      left: (fs.x / 100) * (pw - slotW),
                      top: (1 - fs.y / 100) * (ph - slotH),
                      width: slotW,
                      child: card == null
                          ? _EmptySlot(position: fs.position, width: cw)
                          : FcmPressable(
                              onTap: onPlayerTap == null
                                  ? null
                                  : () => onPlayerTap!(card),
                              child: FcmMiniCard(
                                overall: card.overall,
                                position: card.position.code,
                                name: card.base.name.split(' ').last,
                                rarity: rarityOf(card),
                                width: cw,
                                warn: fs.position != card.position,
                                stamina: card.staminaPercent,
                              ),
                            ),
                    );
                  }(),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Horizontal strip of mini cards (bench / reserves), each with its
/// stamina bar.
class SquadCardRow extends StatelessWidget {
  const SquadCardRow({super.key, required this.cards, this.onPlayerTap});

  final List<PlayerCard> cards;

  /// Optional card tap (player detail sheet).
  final void Function(PlayerCard card)? onPlayerTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = cards[i];
          return FcmEntrance(
            index: i,
            dx: 20,
            dy: 0,
            child: FcmPressable(
              onTap:
                  onPlayerTap == null ? null : () => onPlayerTap!(c),
              child: FcmMiniCard(
                overall: c.overall,
                position: c.position.code,
                name: c.base.name.split(' ').last,
                rarity: rarityOf(c),
                width: 56,
                stamina: c.staminaPercent,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.position, required this.width});

  final Position position;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width / kPlayerCardAspect;
    return SizedBox(
      height: h,
      child: Center(
        child: Container(
          width: width * 0.9,
          height: width * 0.9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.28),
            border: Border.all(color: Colors.white38, width: 1.5),
          ),
          alignment: Alignment.center,
          child: FitText(position.code,
              align: Alignment.center,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

/// Mown-grass stripes, white markings and a soft floodlight vignette.
class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    // Grass with alternating mown bands.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF41502F), Color(0xFF57683F)],
        ).createShader(rect),
    );
    const bands = 10;
    for (var i = 0; i < bands; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, h / bands * i, w, h / bands),
        Paint()..color = Colors.white.withValues(alpha: 0.045),
      );
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.6);
    final m = w * 0.05;
    final field = Rect.fromLTRB(m, m, w - m, h - m);
    canvas.drawRect(field, line);
    canvas.drawLine(Offset(m, h / 2), Offset(w - m, h / 2), line);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.14, line);
    canvas.drawCircle(
        Offset(w / 2, h / 2), 3, Paint()..color = line.color);

    // Penalty and goal areas, top and bottom.
    final boxW = w * 0.56, boxH = h * 0.14;
    final goalW = w * 0.28, goalH = h * 0.055;
    for (final top in [true, false]) {
      final y0 = top ? m : h - m - boxH;
      canvas.drawRect(
          Rect.fromLTWH((w - boxW) / 2, y0, boxW, boxH), line);
      final gy = top ? m : h - m - goalH;
      canvas.drawRect(
          Rect.fromLTWH((w - goalW) / 2, gy, goalW, goalH), line);
      // penalty arc
      final arcCenter =
          Offset(w / 2, top ? m + boxH * 0.72 : h - m - boxH * 0.72);
      final arcRect = Rect.fromCircle(center: arcCenter, radius: w * 0.11);
      canvas.drawArc(
          arcRect, top ? 0.45 : math.pi + 0.45, math.pi - 0.9, false, line);
    }

    // Floodlight vignette.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.35),
          ],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PitchPainter old) => false;
}
