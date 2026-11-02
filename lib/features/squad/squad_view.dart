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
/// The screen itself is dominated by the pitch: a single compact control
/// card at the top carries the team rating and opens the tactic options
/// (formation / playing style / mentality dropdowns) in a bottom sheet,
/// so no option walls eat screen space.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/players.dart' show Position, PlayerAttribute;
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart';
import '../collection/player_detail_sheet.dart' show rarityOf;
import '../match/tactics.dart';
import 'formations.dart';
import 'squad_engine.dart';

/// The whole tactical setup column: the control card (the setup row —
/// formation, playing style, mentality — closed by the team rating, with
/// the Auto Pick and TACTICS actions under it), the pitch with the
/// starting XI and per-player stats (stamina bars when [showStamina]),
/// then the bench and reserves strips.
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
    this.showStamina = true,
    this.onPlayerTap,
  });

  /// Currently selected formation code (e.g. '4-3-3').
  final String formationCode;

  /// Current playing style / mentality selections (GDD 10.2/10.3).
  final PlayingStyle style;
  final Mentality mentality;

  /// Starting XI assignments: slot index → card.
  final Map<int, PlayerCard> xi;

  /// Bench and reserves cards, best-first.
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

  /// Whether cards carry their stamina bar. The pre-match phase shows
  /// match-day fitness; the Tactics tab hides it — the saved setup is
  /// about identity, not current match state.
  final bool showStamina;

  /// Opens the player detail sheet; null makes the cards non-tappable.
  final void Function(PlayerCard card)? onPlayerTap;

  @override
  Widget build(BuildContext context) {
    final teamRating = xi.isEmpty
        ? 0
        : (xi.values.fold<int>(0, (a, c) => a + c.overall) / xi.length)
            .round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FcmEntrance(
          child: _ControlCard(
            teamRating: teamRating,
            formationCode: formationCode,
            style: style,
            mentality: mentality,
            onAutoPick: onAutoPick,
            onTactics: () => showTacticsOptionsSheet(
              context,
              formationCode: formationCode,
              style: style,
              mentality: mentality,
              onFormation: onFormation,
              onStyle: onStyle,
              onMentality: onMentality,
            ),
          ),
        ),
        const SizedBox(height: 14),
        FcmEntrance(
          index: 1,
          child: SquadPitch(
            formation: formationByCode(formationCode),
            assignments: xi,
            showStamina: showStamina,
            onPlayerTap: onPlayerTap,
          ),
        ),
        if (bench.isNotEmpty) ...[
          FcmSectionTitle('Bench (${bench.length}/${Formation.benchSize})'),
          SquadCardRow(
              cards: bench, showStamina: showStamina, onPlayerTap: onPlayerTap),
        ],
        if (reserves.isNotEmpty) ...[
          FcmSectionTitle(
              'Reserves (${reserves.length}/${Formation.reservesSize})'),
          SquadCardRow(
              cards: reserves,
              showStamina: showStamina,
              onPlayerTap: onPlayerTap),
        ],
      ],
    );
  }
}

/// The single control card of the tactics screen. Its top row carries the
/// whole setup as labelled values — formation, playing style, mentality —
/// and closes with the team rating on the right; every block shrinks to
/// fit, so the row never overflows. The Auto Pick (when the surface owns
/// squad persistence) and TACTICS buttons sit on a full-width row below.
class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.teamRating,
    required this.formationCode,
    required this.style,
    required this.mentality,
    required this.onTactics,
    this.onAutoPick,
  });

  final int teamRating;
  final String formationCode;
  final PlayingStyle style;
  final Mentality mentality;
  final VoidCallback onTactics;
  final VoidCallback? onAutoPick;

  @override
  Widget build(BuildContext context) {
    final formation = formationByCode(formationCode);
    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: _info('FORMATION', formation.name)),
              const SizedBox(width: 12),
              Flexible(child: _info('STYLE', style.displayName)),
              const SizedBox(width: 12),
              Flexible(child: _info('MENTALITY', mentality.displayName)),
              const Spacer(),
              _rating(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (onAutoPick != null) ...[
                Expanded(
                  child: FcmButton(
                    compact: true,
                    style: FcmButtonStyle.steel,
                    icon: Icons.auto_awesome,
                    label: 'Auto Pick',
                    onPressed: onAutoPick,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FcmButton(
                  compact: true,
                  icon: Icons.tune_rounded,
                  label: 'TACTICS',
                  onPressed: onTactics,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One labelled setup value of the control card's top row: a dim
  /// mini-label over the value, shrinking to fit its share of the row.
  Widget _info(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FitText(label,
              style: const TextStyle(
                  color: FcmColors.textDim,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(height: 2),
          FitText(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ],
      );

  /// The team rating closing the setup row: dim label over the big
  /// colour-coded number, right-aligned.
  Widget _rating() => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('TEAM RATING',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: FcmColors.textDim,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(height: 2),
          FcmCountUp(
            value: teamRating,
            style: TextStyle(
              color: ratingColor(teamRating),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      );
}

/// Opens the tactic options sheet (GDD 10): the three dropdowns —
/// formation, playing style and mentality — each listing every option
/// with its visible percentage effects. Selections apply immediately
/// through the owner's callbacks; DONE closes the sheet.
Future<void> showTacticsOptionsSheet(
  BuildContext context, {
  required String formationCode,
  required PlayingStyle style,
  required Mentality mentality,
  required ValueChanged<String> onFormation,
  required ValueChanged<PlayingStyle> onStyle,
  required ValueChanged<Mentality> onMentality,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: FcmColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TacticsOptionsSheet(
      initialFormationCode: formationCode,
      initialStyle: style,
      initialMentality: mentality,
      onFormation: onFormation,
      onStyle: onStyle,
      onMentality: onMentality,
    ),
  );
}

class _TacticsOptionsSheet extends StatefulWidget {
  const _TacticsOptionsSheet({
    required this.initialFormationCode,
    required this.initialStyle,
    required this.initialMentality,
    required this.onFormation,
    required this.onStyle,
    required this.onMentality,
  });

  final String initialFormationCode;
  final PlayingStyle initialStyle;
  final Mentality initialMentality;
  final ValueChanged<String> onFormation;
  final ValueChanged<PlayingStyle> onStyle;
  final ValueChanged<Mentality> onMentality;

  @override
  State<_TacticsOptionsSheet> createState() => _TacticsOptionsSheetState();
}

class _TacticsOptionsSheetState extends State<_TacticsOptionsSheet> {
  late String _formationCode = widget.initialFormationCode;
  late PlayingStyle _style = widget.initialStyle;
  late Mentality _mentality = widget.initialMentality;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: FcmColors.bronze.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text('TACTIC OPTIONS',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: FcmColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
            const SizedBox(height: 14),
            _dropdownRow(
              label: 'FORMATION',
              child: FcmDropdown<String>(
                icon: Icons.grid_on_rounded,
                items: [
                  for (final f in formations)
                    FcmDropdownItem(value: f.code, label: f.name),
                ],
                selected: _formationCode,
                onChanged: (v) => setState(() {
                  _formationCode = v;
                  widget.onFormation(v);
                }),
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
                        value: s,
                        label: s.displayName,
                        subtitle: s.effectSummary),
                ],
                selected: _style,
                onChanged: (v) => setState(() {
                  _style = v;
                  widget.onStyle(v);
                }),
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
                        value: m,
                        label: m.displayName,
                        subtitle: m.effectSummary),
                ],
                selected: _mentality,
                onChanged: (v) => setState(() {
                  _mentality = v;
                  widget.onMentality(v);
                }),
              ),
            ),
            const SizedBox(height: 16),
            FcmButton(
              icon: Icons.check_rounded,
              label: 'DONE',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
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

/// The visible stat triple of a squad card: outfield players show
/// ATT / SUP / DEF, keepers GK / DEF / SUP — upgraded values included.
List<({String label, int value})> statsOf(PlayerCard c) =>
    c.position.isGoalkeeper
        ? [
            (label: 'GK', value: c.attribute(PlayerAttribute.goalkeeping)),
            (label: 'DEF', value: c.attribute(PlayerAttribute.defence)),
            (label: 'SUP', value: c.attribute(PlayerAttribute.support)),
          ]
        : [
            (label: 'ATT', value: c.attribute(PlayerAttribute.attack)),
            (label: 'SUP', value: c.attribute(PlayerAttribute.support)),
            (label: 'DEF', value: c.attribute(PlayerAttribute.defence)),
          ];

/// Renders the pitch with player cards at formation coordinates (GDD 6.2).
/// Card size adapts to the formation: the widest line and the number of
/// lines bound the shield size, so every card gets the most space the
/// shape allows without neighbours overlapping. Cards glide to their new
/// spots when the formation changes. Each card carries its stats and,
/// when [showStamina] is set, a colour-coded stamina bar.
class SquadPitch extends StatelessWidget {
  const SquadPitch({
    super.key,
    required this.formation,
    required this.assignments,
    this.showStamina = true,
    this.onPlayerTap,
  });

  final Formation formation;

  /// Slot index → card for the starting XI.
  final Map<int, PlayerCard> assignments;

  /// Whether cards carry their stamina bar (hidden in the Tactics tab).
  final bool showStamina;

  /// Optional card tap (player detail sheet).
  final void Function(PlayerCard card)? onPlayerTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.66,
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

            // Size the cards to the shape. Slots cluster into horizontal
            // bands (slots within 10 pitch-percent of each other in y —
            // e.g. a back four at y 18/24 is one band); the keeper is
            // excluded because it never shares a band or a column.
            final fieldSlots = formation.slots.skip(1).toList();
            final ys = [...fieldSlots.map((s) => s.y)]..sort();
            final bands = <double>[ys.first];
            for (final y in ys.skip(1)) {
              if (y - bands.last > 10) bands.add(y);
            }
            final gkY = formation.slots.first.y;
            final maxAcross = fieldSlots.fold<int>(
                0,
                (a, s) => math.max(a,
                    fieldSlots.where((o) => (o.y - s.y).abs() <= 10).length));

            // The card must fit the widest band horizontally, the stacked
            // bands vertically, and the tightest gap between adjacent
            // bands (keeper band included) without its shield colliding.
            final byWidth = (pw - 16) / maxAcross - 12;
            final byHeight = ((ph - 24) / (bands.length + 1) - 46) *
                kPlayerCardAspect;
            final gaps = [
              bands.first - gkY,
              for (var i = 1; i < bands.length; i++)
                bands[i] - bands[i - 1],
            ];
            final minGap = gaps.fold<double>(double.infinity, math.min);
            final byGap = (minGap / 100) * (ph - 140) * kPlayerCardAspect * 1.3;
            final cardW =
                math.min(byWidth, math.min(byHeight, byGap)).clamp(38.0, 60.0);
            final slotW = cardW + 12;
            final slotH = cardW / kPlayerCardAspect + 46;

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
                      left: 8 + (fs.x / 100) * (pw - slotW - 16),
                      top: 8 + (1 - fs.y / 100) * (ph - slotH - 16),
                      width: slotW,
                      child: card == null
                          ? _EmptySlot(position: fs.position, width: cardW)
                          : FcmPressable(
                              onTap: onPlayerTap == null
                                  ? null
                                  : () => onPlayerTap!(card),
                              child: FcmMiniCard(
                                overall: card.overall,
                                position: card.position.code,
                                name: card.base.name.split(' ').last,
                                rarity: rarityOf(card),
                                width: cardW,
                                warn: fs.position != card.position,
                                stamina:
                                    showStamina ? card.staminaPercent : null,
                                stats: statsOf(card),
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

/// Horizontal strip of mini cards (bench / reserves): stats, the surname
/// under each shield and — when [showStamina] is set — the stamina bar.
class SquadCardRow extends StatelessWidget {
  const SquadCardRow({
    super.key,
    required this.cards,
    this.showStamina = true,
    this.onPlayerTap,
  });

  final List<PlayerCard> cards;

  /// Whether cards carry their stamina bar (hidden in the Tactics tab).
  final bool showStamina;

  /// Optional card tap (player detail sheet).
  final void Function(PlayerCard card)? onPlayerTap;

  static const double cardWidth = 64;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardWidth / kPlayerCardAspect + 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final c = cards[i];
          return FcmEntrance(
            index: i,
            dx: 20,
            dy: 0,
            child: FcmPressable(
              onTap: onPlayerTap == null ? null : () => onPlayerTap!(c),
              child: FcmMiniCard(
                overall: c.overall,
                position: c.position.code,
                name: c.base.name.split(' ').last,
                rarity: rarityOf(c),
                width: cardWidth,
                stamina: showStamina ? c.staminaPercent : null,
                stats: statsOf(c),
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
