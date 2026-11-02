/// FCM Rivals — shared visual language (premium dark UI).
///
/// Colours are taken from the brand art: deep stadium navy, trophy gold and
/// the blue / purple / gold card tiers.
library;

import 'package:flutter/material.dart';

/// Brand palette.
class FcmColors {
  FcmColors._();

  static const Color night = Color(0xFF050B1F);
  static const Color navy = Color(0xFF0A1A44);
  static const Color royal = Color(0xFF1B4DDB);
  static const Color gold = Color(0xFFFFC53D);
  static const Color goldDeep = Color(0xFFC98A00);
  static const Color pitch = Color(0xFF1FA64A);
  static const Color silver = Color(0xFFDDE3F0);
}

/// Card rarity, derived from the pack tier the player was drawn from.
/// 0 = low tier → rare (blue), 1 = mid → epic (purple), 2 = high → legendary
/// (gold). Higher rarity gets bigger reveal effects (GDD 5.6).
enum CardRarity {
  rare,
  epic,
  legendary;

  static CardRarity fromTier(int tier) => switch (tier) {
        0 => CardRarity.rare,
        1 => CardRarity.epic,
        _ => CardRarity.legendary,
      };

  String get label => switch (this) {
        CardRarity.rare => 'RARE',
        CardRarity.epic => 'EPIC',
        CardRarity.legendary => 'LEGENDARY',
      };

  /// Main accent colour (glow, rays, particles).
  Color get accent => switch (this) {
        CardRarity.rare => const Color(0xFF3D8BFF),
        CardRarity.epic => const Color(0xFFB65CFF),
        CardRarity.legendary => const Color(0xFFFFC53D),
      };

  /// Card face gradient, top-left → bottom-right.
  List<Color> get faceGradient => switch (this) {
        CardRarity.rare => const [
            Color(0xFF6FB1FF),
            Color(0xFF2A62E0),
            Color(0xFF10286B),
          ],
        CardRarity.epic => const [
            Color(0xFFD59BFF),
            Color(0xFF8A3FE0),
            Color(0xFF2E1065),
          ],
        CardRarity.legendary => const [
            Color(0xFFFFE9A3),
            Color(0xFFF2B01E),
            Color(0xFF8A5A00),
          ],
      };

  /// Text colour that stays readable on [faceGradient].
  Color get ink => switch (this) {
        CardRarity.legendary => const Color(0xFF2B1B00),
        _ => Colors.white,
      };

  /// 1.0 for rare, up to 2.0 for legendary — scales particles, ray length
  /// and glow so the better the pull, the bigger the show.
  double get intensity => switch (this) {
        CardRarity.rare => 1.0,
        CardRarity.epic => 1.5,
        CardRarity.legendary => 2.0,
      };
}

/// Premium dark Material theme used by the whole app.
ThemeData buildFcmTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: FcmColors.royal,
    brightness: Brightness.dark,
  ).copyWith(
    primary: FcmColors.gold,
    onPrimary: const Color(0xFF2B1B00),
    secondary: FcmColors.royal,
    surface: FcmColors.navy,
    surfaceContainerHighest: const Color(0xFF14275E),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: FcmColors.night,
    appBarTheme: const AppBarTheme(
      backgroundColor: FcmColors.night,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF0E2054),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: FcmColors.gold,
      labelColor: FcmColors.gold,
      unselectedLabelColor: Colors.white70,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FcmColors.gold,
        foregroundColor: const Color(0xFF2B1B00),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 15),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
