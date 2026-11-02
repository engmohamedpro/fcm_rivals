/// FCM Rivals — logo widgets.
library;

import 'package:flutter/material.dart';

import 'fcm_style.dart';

/// Asset path of the brand art.
const String kFcmLogoAsset = 'assets/images/fcm_rivals_logo.jpg';

/// The full brand art, fading and scaling in once. Used as the loading
/// screen. [cacheWidth] keeps the 2.8 MB source PNG cheap to decode.
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.asset(
            kFcmLogoAsset,
            width: 300,
            height: 300,
            cacheWidth: 600,
            fit: BoxFit.cover,
            // Never let a missing/undecodable asset break startup.
            errorBuilder: (_, __, ___) => const FcmWordmark(size: 40),
          ),
        ),
      ),
    );
  }
}

/// Compact text wordmark for app bars: silver "FCM" + gold "RIVALS".
class FcmWordmark extends StatelessWidget {
  const FcmWordmark({super.key, this.size = 22});

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
