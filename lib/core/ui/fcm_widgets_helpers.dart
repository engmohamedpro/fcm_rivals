/// FCM Rivals — shared UI helpers used across the widget kit.
///
/// Rating and stamina colour ramps plus the safe haptic tick —
/// they serve bars, pills and cards alike, so they live apart from
/// any single widget family.
library;

import 'package:flutter/services.dart';

import 'fcm_style.dart';


/// Rating → colour used by bars and pills (champagne elite → ember weak),
/// desaturated to sit inside the brand's gold-on-black palette.
Color ratingColor(num v) {
  if (v >= 80) return FcmColors.success;
  if (v >= 65) return FcmColors.gold;
  if (v >= 45) return const Color(0xFFC89A5B);
  return FcmColors.danger;
}

/// Stamina percent → colour (GDD 11): fresh legs green, tiring gold, heavy
/// legs amber, exhausted red. Used by the stamina bars under player cards.
Color staminaColor(num v) {
  if (v >= 75) return FcmColors.success;
  if (v >= 50) return FcmColors.gold;
  if (v >= 30) return const Color(0xFFE08A2E);
  return FcmColors.danger;
}

/// Light haptic that can never throw.
void fcmTick() {
  try {
    HapticFeedback.selectionClick().catchError((Object _) {});
  } catch (_) {}
}
