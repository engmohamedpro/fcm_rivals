/// FCM Rivals — logo widgets.
library;

import 'package:flutter/material.dart';

import 'fcm_style.dart';

/// Asset path of the transparent brand wordmark art ('FCM 27 Rivals').
const String kFcmWordmarkAsset = 'assets/images/logo.webp';

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
          errorBuilder: (_, __, ___) => const FcmWordmark(size: 40),
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
      errorBuilder: (_, __, ___) => _FcmTextWordmark(size: size),
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
