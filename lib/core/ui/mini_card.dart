/// FCM Rivals — mini player card family (GDD 5.6 / 7.1).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fcm_style.dart';
import 'fcm_widgets.dart' show staminaColor;
import 'injury_badge.dart';
import 'player_card.dart';

/// Compact card for the pitch and bench: uses the new premium [PlayerCardWidget]
/// in [CardSize.small] style without attributes, with surname, stamina bar,
/// and badge overlays.
class FcmMiniCard extends StatelessWidget {
  const FcmMiniCard({
    super.key,
    required this.overall,
    required this.position,
    required this.name,
    required this.rarity,
    this.width = 56,
    this.flag,
    this.imageUrl,
    this.clubCrestUrl,
    this.warn = false,
    this.stamina,
    this.stats,
    this.ghost = false,
    this.injuryMatchesOut,
    this.upgradable = false,
    this.upgradeLevel = 0,
    this.isIcon = false,
  });

  final int overall;
  final String position;
  final String name;
  final CardRarity rarity;
  final double width;

  /// Icon players (owner request 2026-11-12): the mini card paints the
  /// holo icon treatment regardless of the OVR band.
  final bool isIcon;

  /// Country flag emoji (T-0066).
  final String? flag;

  /// Player portrait (dataset v3).
  final String? imageUrl;

  /// Club crest (dataset v3).
  final String? clubCrestUrl;

  final bool warn;
  final int? stamina;
  final List<({String label, int value})>? stats;
  final bool ghost;
  final int? injuryMatchesOut;
  final bool upgradable;
  final int upgradeLevel;

  @override
  Widget build(BuildContext context) {
    final h = width / kPlayerCardAspect;
    final playerCardRarity = isIcon
        ? PlayerCardRarity.icon
        : (overall >= 90
            ? PlayerCardRarity.premium
            : (overall >= 80 || rarity == CardRarity.legendary
                ? PlayerCardRarity.legendary
                : (overall >= 70 || rarity == CardRarity.epic
                    ? PlayerCardRarity.epic
                    : PlayerCardRarity.rare)));

    final effectiveUpgrade = upgradeLevel > 0 ? upgradeLevel : (upgradable ? 1 : 0);

    if (ghost) {
      return SizedBox(
        width: width + 12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width,
              height: h,
              child: CustomPaint(
                painter: PlayerCardPainter(rarity: playerCardRarity),
                foregroundPainter: _GhostPainter(),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(height: math.max(9, width * 0.19) * 1.0),
          ],
        ),
      );
    }

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: width + 12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PlayerCardWidget(
                  rarity: playerCardRarity,
                  rating: overall,
                  position: position,
                  flag: flag ?? '⚽',
                  teamLogo: clubCrestUrl != null && clubCrestUrl!.isNotEmpty
                      ? NetworkImage(clubCrestUrl!)
                      : const AssetImage('assets/images/logo_full.webp'),
                  playerImage: imageUrl != null && imageUrl!.isNotEmpty
                      ? NetworkImage(imageUrl!)
                      : null,
                  size: CardSize.small,
                  width: width,
                  upgradeLevel: effectiveUpgrade,
                ),
                if (warn)
                  Positioned.fill(
                    child: CustomPaint(painter: _WarnPainter()),
                  ),
                if (injuryMatchesOut != null && injuryMatchesOut! > 0)
                  PositionedDirectional(
                    top: 2,
                    start: 2,
                    child: InjuryBadge(
                      matchesOut: injuryMatchesOut!,
                      size: math.max(10, width * 0.18),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatMiniCardName(name),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: math.max(9, width * 0.19),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ),
            if (stamina != null) ...[
              const SizedBox(height: 3),
              _StaminaBar(percent: stamina!, width: width),
            ],
          ],
        ),
      ),
    );
  }
}

/// Formats full player names for mini cards (e.g. "Lamine Yamal" -> "L. Yamal").
String formatMiniCardName(String fullName) {
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) return '';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length <= 1) {
    return trimmed.toUpperCase();
  }
  final firstInitial = '${parts.first[0].toUpperCase()}.';
  final lastName = parts.sublist(1).join(' ');
  return '$firstInitial $lastName';
}

/// Overlay for ghost mini cards.
class _GhostPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = buildCardPath(size);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF121014).withValues(alpha: 0.82),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.save();
    canvas.translate(size.width * 0.03, size.height * 0.02);
    canvas.scale(0.94, 0.96);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.006
        ..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Colour-coded stamina strip under a mini card.
class _StaminaBar extends StatelessWidget {
  const _StaminaBar({required this.percent, required this.width});

  final int percent;
  final double width;

  static const double trackHeight = 5;

  @override
  Widget build(BuildContext context) {
    final color = staminaColor(percent);
    final fill = (percent / 100).clamp(0.0, 1.0);
    return Container(
      width: width,
      height: trackHeight,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(trackHeight / 2),
        border: Border.all(color: Colors.black.withValues(alpha: 0.4)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(trackHeight / 2),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: width * fill,
              child: DecoratedBox(
                key: const Key('stamina_fill'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.75), color],
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

class _WarnPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      buildCardPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.06
        ..color = FcmColors.danger,
    );
  }

  @override
  bool shouldRepaint(_WarnPainter old) => false;
}

/// Convenience: sin-based 0..1 pulse for idle glows.
double pulse(double t, {double cycles = 1}) =>
    0.5 + 0.5 * math.sin(t * 2 * math.pi * cycles);
