/// FCM Rivals — live injury banner (T-0056, GDD 11.7/13).
///
/// The red lower-third that takes over the commentary ticker for an
/// injury moment: the T-0054 commentary line (player + kind, localized,
/// "plays short" included) plus the matches-out chip from the line's
/// detail payload. Purely derived from the line the ticker already
/// holds — no timers, no post-frame callbacks — so the banner lives and
/// dies with the ticker's own swap cycle (the T-0013
/// no-unmounted-setstate rule by construction).
library;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../l10n/l10n_context.dart';
import 'commentary.dart';

class InjuryLiveBanner extends StatelessWidget {
  const InjuryLiveBanner({super.key, required this.line});

  /// The injury commentary line the ticker was about to show — its
  /// [CommentaryLine.text] carries the localized player + kind sentence
  /// and its [CommentaryLine.detail] carries the matches-out count.
  final CommentaryLine line;

  @override
  Widget build(BuildContext context) {
    final matchesOut = line.detail == null
        ? null
        : int.tryParse(line.detail!);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FcmColors.danger, width: 1.4),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.medical_services_outlined,
            color: FcmColors.danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
          if (matchesOut != null && matchesOut > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: FcmColors.danger.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10nOf(context).injuryChipOut(matchesOut),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
