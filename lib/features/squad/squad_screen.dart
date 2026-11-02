import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/domain/players.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart';
import '../../features/squad/formations.dart';
import '../../features/squad/squad_engine.dart';
import '../collection/player_detail_sheet.dart';

/// Squad tab: pitch with the starting XI positioned by the current
/// formation, bench and reserves rows, formation switch and Auto Pick
/// (GDD 6.2/6.3/6.4).
class SquadScreen extends ConsumerWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squad = ref.watch(squadProvider);
    final club = ref.watch(clubProvider).valueOrNull;
    final formation = formationByCode(club?.formationCode ?? '4-3-3');

    return squad.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (squad) {
        final xi = {
          for (final e in squad.entries)
            if (e.key < Formation.startingXiSize) e.key: e.value,
        };
        final bench = {
          for (final e in squad.entries)
            if (e.key >= Formation.startingXiSize &&
                e.key < Formation.startingXiSize + Formation.benchSize)
              e.key: e.value,
        };
        final reserves = {
          for (final e in squad.entries)
            if (e.key >= Formation.startingXiSize + Formation.benchSize)
              e.key: e.value,
        };
        final teamRating = xi.isEmpty
            ? 0
            : (xi.values.fold<int>(0, (a, c) => a + c.overall) / xi.length)
                .round();

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FcmButton(
                            compact: true,
                            style: FcmButtonStyle.steel,
                            icon: Icons.grid_on_rounded,
                            label: formation.name,
                            onPressed: () => _pickFormation(context, ref),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FcmButton(
                            compact: true,
                            icon: Icons.auto_awesome,
                            label: 'Auto Pick',
                            onPressed: () => _autoPick(context, ref),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FcmEntrance(
              index: 1,
              child: _Pitch(formation: formation, assignments: xi),
            ),
            if (bench.isNotEmpty) ...[
              FcmSectionTitle('Bench (${bench.length}/7)'),
              _CardRow(cards: bench.values.toList()),
            ],
            if (reserves.isNotEmpty) ...[
              FcmSectionTitle('Reserves (${reserves.length}/5)'),
              _CardRow(cards: reserves.values.toList()),
            ],
            if (squad.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: FcmPanel(
                  child: Text(
                    'Open packs to collect players, then tap Auto Pick.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FcmColors.textDim),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _autoPick(BuildContext context, WidgetRef ref) async {
    final store = await ref.read(collectionStoreProvider.future);
    await store.autoPickSquad();
    ref.invalidate(squadProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Best squad selected')));
    }
  }

  Future<void> _pickFormation(BuildContext context, WidgetRef ref) async {
    final formations = ref.read(formationsProvider);
    final club = ref.read(clubProvider).valueOrNull;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text('Choose formation',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
              ),
              Flexible(
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.9,
                  children: [
                    for (final f in formations)
                      FcmPanel(
                        padding: const EdgeInsets.all(8),
                        radius: 14,
                        accent:
                            f.code == club?.formationCode ? FcmColors.gold : null,
                        glow: f.code == club?.formationCode,
                        onTap: () => Navigator.pop(sheetContext, f.code),
                        child: Center(
                          child: FitText(f.name,
                              align: Alignment.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || chosen == club?.formationCode) return;
    final store = await ref.read(collectionStoreProvider.future);
    await store.changeFormation(chosen);
    ref.invalidate(clubProvider);
    ref.invalidate(squadProvider);
  }
}

/// Horizontal strip of mini cards (bench / reserves).
class _CardRow extends StatelessWidget {
  const _CardRow({required this.cards});

  final List<PlayerCard> cards;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
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
              onTap: () => showPlayerDetail(context, card: c, inSquad: true),
              child: FcmMiniCard(
                overall: c.overall,
                position: c.position.code,
                name: c.base.name.split(' ').last,
                rarity: rarityOf(c),
                width: 56,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Renders the pitch with player cards at formation coordinates (GDD 6.2).
/// Cards glide to their new spots when the formation changes.
class _Pitch extends StatelessWidget {
  const _Pitch({required this.formation, required this.assignments});

  final Formation formation;
  final Map<int, PlayerCard> assignments;

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
                          ? _EmptySlot(
                              position: fs.position, width: cw)
                          : FcmPressable(
                              onTap: () => showPlayerDetail(context,
                                  card: card, inSquad: true),
                              child: FcmMiniCard(
                                overall: card.overall,
                                position: card.position.code,
                                name: card.base.name.split(' ').last,
                                rarity: rarityOf(card),
                                width: cw,
                                warn: fs.position != card.position,
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
