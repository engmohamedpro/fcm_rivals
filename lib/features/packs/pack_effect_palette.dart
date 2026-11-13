/// FCM Rivals — shared pack effect spec and priming.
///
/// The pack silhouette aspect, the once-decoded brand logo the
/// foil painter stamps, and the foil silhouette geometry helpers
/// — split verbatim out of `pack_effects.dart` (T-0040). The
/// overview lives on the `pack_effects.dart` barrel.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/ui/fcm_logo.dart' show kFcmWordmarkAsset;

/// Pack width : height.
const double kPackAspect = 0.62;

/// The transparent brand logo, decoded once for canvas painting (the
/// foil packs' metal band). Null until [precachePackLogo] resolves;
/// painters stamp the text wordmark until then.
ui.Image? packLogo;
bool _packLogoRequested = false;

/// Decodes the logo art off the asset bundle once — every later
/// [FoilPackPainter] stroke reuses the cached [ui.Image]. Called at
/// app start so the store's static cells never fall back to text.
Future<void> precachePackLogo() async {
  if (_packLogoRequested) return;
  _packLogoRequested = true;
  try {
    final data = await rootBundle.load(kFcmWordmarkAsset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    packLogo = frame.image;
  } catch (_) {
    // A missing/undecodable asset must never break the packs: the
    // text wordmark fallback stays in place.
  }
}

/// Pack silhouette: a foil wrapper with crimped (zig-zag) top and bottom
/// seals. Crimp depth and tooth width scale with the pack's width, so the
/// sealed edge looks identical on the store shelf and in the opening scene.
Path packPath(Size s) {
  final w = s.width, h = s.height;
  final crimp = w * 0.075;
  final tooth = w * 0.05;
  final p = Path()..moveTo(0, crimp);
  // Top crimp (zig-zag), left → right.
  var x = 0.0;
  var up = true;
  while (x < w) {
    final nx = math.min(x + tooth, w);
    p.lineTo(nx, up ? 0 : crimp);
    x = nx;
    up = !up;
  }
  p.lineTo(w, h - crimp);
  // Bottom crimp, right → left.
  x = w;
  up = true;
  while (x > 0) {
    final nx = math.max(x - tooth, 0.0);
    p.lineTo(nx, up ? h : h - crimp);
    x = nx;
    up = !up;
  }
  p.close();
  return p;
}

/// A rectangle with its four corners cut at 45° — the badge silhouette of
/// the brand's crest, used for the pack's print frame and wordmark band.
Path chamfered(Rect r, double c) => Path()
  ..moveTo(r.left + c, r.top)
  ..lineTo(r.right - c, r.top)
  ..lineTo(r.right, r.top + c)
  ..lineTo(r.right, r.bottom - c)
  ..lineTo(r.right - c, r.bottom)
  ..lineTo(r.left + c, r.bottom)
  ..lineTo(r.left, r.bottom - c)
  ..lineTo(r.left, r.top + c)
  ..close();
