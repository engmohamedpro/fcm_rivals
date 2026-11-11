/// FCM Rivals — the club badge used wherever a team is shown beside its
/// name (pre-match analysis, live match header).
///
/// Draws the club's real crest ([FcmCrest]) when its spec is known. Only a
/// club without a crest (a synthetic friendly opponent) falls back to the
/// old initials circle, so a team never shows letters when it has a crest.
library;

import 'package:flutter/material.dart';

import '../domain/crest.dart';
import 'fcm_crest.dart';
import 'fcm_style.dart';
import 'fcm_widgets.dart';

class FcmClubBadge extends StatelessWidget {
  const FcmClubBadge({
    super.key,
    required this.name,
    required this.crest,
    this.size = 32,
    this.isUser = false,
  });

  /// The club's name — used only for the initials fallback.
  final String name;

  /// The club's crest; null falls back to the initials circle.
  final CrestSpec? crest;

  /// Width and height (the badge is square).
  final double size;

  /// Whether this is the user's club (tints the initials fallback gold).
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final spec = crest;
    if (spec != null) return FcmCrest(spec: spec, width: size);
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUser ? FcmColors.goldGradient : FcmColors.steelGradient,
        border: Border.all(color: Colors.white24),
      ),
      child: FitText(
        initials,
        align: Alignment.center,
        style: TextStyle(
          color: isUser ? FcmColors.ink : FcmColors.goldSoft,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
