/// FCM Rivals — shared injury badge (T-0056, GDD 11.7).
///
/// One visual language for "this player is unavailable": a red medical
/// cross with the matches-out count, rendered on every card surface that
/// can carry an injured player — squad pitch mini cards, collection grid
/// cards, the player detail sheet, pre-match analysis rows and the
/// bench/reserves strips. The count is locale-neutral (a digit, not a
/// sentence), so the badge itself needs no directionality; the
/// accessibility label and the row-level sentences localize via ARB.
library;

import 'package:flutter/material.dart';

import '../../l10n/l10n_context.dart';
import 'fcm_style.dart';

/// The red cross + matches-out pill. [size] scales to its surface: 14 on
/// mini cards, 18 on full cards and sheets.
class InjuryBadge extends StatelessWidget {
  const InjuryBadge({super.key, required this.matchesOut, this.size = 14});

  /// Matches the player still misses (0 renders nothing — fit players
  /// carry no badge).
  final int matchesOut;

  final double size;

  @override
  Widget build(BuildContext context) {
    if (matchesOut <= 0) return const SizedBox.shrink();
    return Semantics(
      label: l10nOf(context).injuryBadgeSemantics(matchesOut),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: size * 0.30,
          vertical: size * 0.14,
        ),
        decoration: BoxDecoration(
          color: FcmColors.danger.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(size * 0.55),
          border: Border.all(color: Colors.black.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medical_services_outlined, size: size, color: Colors.white),
            SizedBox(width: size * 0.22),
            Text(
              '$matchesOut',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.82,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
