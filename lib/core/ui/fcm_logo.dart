/// FCM Rivals — logo widgets.
library;

import 'package:flutter/material.dart';

import 'fcm_style.dart';

/// Asset path of the transparent brand wordmark art ('FCM 27 Rivals').
const String kFcmWordmarkAsset = 'assets/images/logo.webp';

/// Asset path of the full brand badge ('FCM 27 Rivals' crest on its dark
/// carbon backdrop). Square art; it carries its own near-black background,
/// so [FcmFullLogo] feathers the edges into the app's night colour.
const String kFcmFullLogoAsset = 'assets/images/logo_full.webp';

/// The full badge, feathered into the night background: a radial mask
/// fades the square art's edges to transparent so the crest floats on any
/// dark surface instead of showing a visible box. [size] is the square's
/// side; the crest itself fills roughly the middle 55%.
class FcmFullLogo extends StatelessWidget {
  const FcmFullLogo({super.key, this.size = 150});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        // Opaque through the crest, fading to fully clear exactly at the
        // square's edge midpoints (radius 0.5 of the side), so no box edge
        // is ever visible.
        shaderCallback: (bounds) => const RadialGradient(
          radius: 0.5,
          colors: [Colors.white, Colors.white, Color(0x00FFFFFF)],
          stops: [0.0, 0.72, 1.0],
        ).createShader(bounds),
        child: Image.asset(
          kFcmFullLogoAsset,
          width: size,
          height: size,
          cacheWidth: 512,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          // A missing asset must never break the store: fall back to the
          // transparent wordmark.
          errorBuilder: (_, _, _) => FcmWordmark(size: size * 0.3),
        ),
      ),
    );
  }
}

/// The transparent brand wordmark, fading and scaling in once. Used as
/// the loading screen: the art floats directly on the night background —
/// it has no backdrop of its own. [cacheWidth] keeps the source cheap
/// to decode.
class FcmLogoLoading extends StatelessWidget {
  const FcmLogoLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FcmColors.night,
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => Opacity(
          opacity: v,
          child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
        ),
        child: Image.asset(
          kFcmWordmarkAsset,
          width: 300,
          cacheWidth: 600,
          fit: BoxFit.contain,
          // Never let a missing/undecodable asset break startup.
          errorBuilder: (_, _, _) => const FcmWordmark(size: 40),
        ),
      ),
    );
  }
}

/// The brand wordmark: the transparent logo art, used wherever 'FCM
/// Rivals' titles a surface — the app bar, the loading screen, club
/// creation. [size] is the mark's height; the width follows the art's
/// own aspect. If the art cannot be decoded the metal text wordmark
/// stands in, so a broken asset never blanks a title.
class FcmWordmark extends StatelessWidget {
  const FcmWordmark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kFcmWordmarkAsset,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _FcmTextWordmark(size: size),
    );
  }
}

/// Text fallback for [FcmWordmark]: silver "FCM" + champagne "RIVALS",
/// matching the logo's metal-on-black signature.
class _FcmTextWordmark extends StatelessWidget {
  const _FcmTextWordmark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'FCM',
          style: TextStyle(
            color: FcmColors.silver,
            fontSize: size,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'RIVALS',
          style: TextStyle(
            color: FcmColors.gold,
            fontSize: size,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
