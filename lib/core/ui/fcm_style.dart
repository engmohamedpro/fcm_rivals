/// FCM Rivals — shared visual language (premium dark UI).
///
/// Colours are taken from the brand art: deep stadium navy, trophy gold and
/// the blue / purple / gold card tiers.
library;

import 'package:flutter/material.dart';

/// Brand palette.
class FcmColors {
  FcmColors._();

  static const Color night = Color(0xFF040A1C);
  static const Color navy = Color(0xFF0A1A44);
  static const Color surface = Color(0xFF0D1F52);
  static const Color surfaceHigh = Color(0xFF15296B);
  static const Color royal = Color(0xFF2A5CFF);
  static const Color gold = Color(0xFFFFC53D);
  static const Color goldDeep = Color(0xFFC98A00);
  static const Color goldSoft = Color(0xFFFFE08A);
  static const Color pitch = Color(0xFF1FA64A);
  static const Color silver = Color(0xFFDDE3F0);
  static const Color textDim = Color(0xFF9FB0D9);
  static const Color success = Color(0xFF2EE59D);
  static const Color danger = Color(0xFFFF5470);

  /// Primary call-to-action gradient (gold).
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE08A), Color(0xFFFFC53D), Color(0xFFE09A00)],
  );

  /// Secondary button / panel gradient (royal blue).
  static const LinearGradient royalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A6BFF), Color(0xFF1B3FB8)],
  );
}

/// Card rarity. Derived from a player's rating so the same player looks the
/// same in the pack reveal, the collection and the squad: blue (rare),
/// purple (epic) and gold (legendary). Higher rarity gets bigger reveal
/// effects (GDD 5.6).
enum CardRarity {
  rare,
  epic,
  legendary;

  /// Rating thresholds: 82+ legendary, 70+ epic, otherwise rare.
  static CardRarity fromOverall(int overall) {
    if (overall >= 82) return CardRarity.legendary;
    if (overall >= 70) return CardRarity.epic;
    return CardRarity.rare;
  }

  /// Legacy pack-tier mapping (0 low .. 2 high).
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

/// Fade + gentle rise for every route (replaces the platform default).
class FcmPageTransitions extends PageTransitionsBuilder {
  const FcmPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }
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
    surfaceContainerHighest: FcmColors.surfaceHigh,
    error: FcmColors.danger,
    onSurfaceVariant: FcmColors.textDim,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: Brightness.dark,
  );
  final text = base.textTheme;
  return base.copyWith(
    scaffoldBackgroundColor: FcmColors.night,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FcmPageTransitions(),
      TargetPlatform.iOS: FcmPageTransitions(),
      TargetPlatform.macOS: FcmPageTransitions(),
      TargetPlatform.windows: FcmPageTransitions(),
      TargetPlatform.linux: FcmPageTransitions(),
      TargetPlatform.fuchsia: FcmPageTransitions(),
    }),
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
      headlineSmall: text.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.3),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.6),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: FcmColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: FcmColors.gold,
      labelColor: FcmColors.gold,
      unselectedLabelColor: Colors.white70,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: FcmColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: FcmColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Colors.white24,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FcmColors.surfaceHigh,
      contentTextStyle: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x33FFFFFF)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: FcmColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: FcmColors.surfaceHigh,
      selectedColor: FcmColors.gold,
      secondarySelectedColor: FcmColors.gold,
      labelStyle: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700),
      secondaryLabelStyle: const TextStyle(
          color: Color(0xFF2B1B00), fontWeight: FontWeight.w800),
      checkmarkColor: const Color(0xFF2B1B00),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.08),
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: FcmColors.gold,
      textColor: Colors.white,
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: FcmColors.gold),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FcmColors.gold,
        foregroundColor: const Color(0xFF2B1B00),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 15),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w800, letterSpacing: 0.6, fontSize: 14),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: FcmColors.gold,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}
