/// FCM Rivals — shared visual language (premium dark UI).
///
/// Colours are taken from the brand art: near-black charcoal surfaces, a
/// champagne-gold metal accent and a silver wordmark — no saturated hues
/// anywhere, so the whole game reads like the logo (gold on black).
library;

import 'package:flutter/material.dart';

/// Brand palette.
class FcmColors {
  FcmColors._();

  /// Deepest background tone of the brand art.
  static const Color night = Color(0xFF0B0A0E);

  /// Raised charcoal surface.
  static const Color surface = Color(0xFF141419);

  /// Brighter charcoal for overlays and chips.
  static const Color surfaceHigh = Color(0xFF1E1D24);

  /// Warm charcoal (the leather-brown tone of the brand art).
  static const Color ember = Color(0xFF2E2925);

  /// Dark bronze — borders, dim accents, secondary highlights.
  static const Color bronze = Color(0xFF8A6E42);

  /// Brand gold — the champagne tone of the logo emblem.
  static const Color gold = Color(0xFFD9B871);

  /// Bright champagne — highlights and gradient tops.
  static const Color goldSoft = Color(0xFFF5E3B0);

  /// Deepest gold-brown, for gradient tails.
  static const Color goldDeep = Color(0xFF6E5426);

  /// Silver — the logo wordmark tone, for secondary text and emblems.
  static const Color silver = Color(0xFFC9C4B8);

  /// Muted pitch green (backdrop only — never a UI accent).
  static const Color pitch = Color(0xFF57683F);

  /// Warm gray body text.
  static const Color textDim = Color(0xFF8F8A80);

  static const Color success = Color(0xFF8FD09A);
  static const Color danger = Color(0xFFD96A62);

  /// Ink that sits on gold surfaces.
  static const Color ink = Color(0xFF241806);

  /// Primary call-to-action gradient (champagne → gold → bronze).
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF5E3B0), Color(0xFFD9B871), Color(0xFF8A6E42)],
  );

  /// Secondary button / panel gradient (charcoal steel with gold warmth).
  static const LinearGradient steelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A2731), Color(0xFF17161B)],
  );
}

/// Card rarity. Derived from a player's rating so the same player looks the
/// same in the pack reveal, the collection and the squad: bronze (rare),
/// silver (epic) and gold (legendary) — the medal metals of the brand.
/// Higher rarity gets bigger reveal effects (GDD 5.6).
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
        CardRarity.rare => 'BRONZE',
        CardRarity.epic => 'SILVER',
        CardRarity.legendary => 'GOLD',
      };

  /// Main accent colour (glow, rays, particles).
  Color get accent => switch (this) {
        CardRarity.rare => const Color(0xFFC89A5B),
        CardRarity.epic => const Color(0xFFD9D9E2),
        CardRarity.legendary => const Color(0xFFF2D488),
      };

  /// Card face gradient, top-left → bottom-right.
  List<Color> get faceGradient => switch (this) {
        CardRarity.rare => const [
            Color(0xFFEBD3A4),
            Color(0xFFA57C3F),
            Color(0xFF523A18),
          ],
        CardRarity.epic => const [
            Color(0xFFF4F4F8),
            Color(0xFFADAFBC),
            Color(0xFF4E505A),
          ],
        CardRarity.legendary => const [
            Color(0xFFFFF3C4),
            Color(0xFFE0B968),
            Color(0xFF7A4E00),
          ],
      };

  /// Text colour that stays readable on [faceGradient].
  Color get ink => switch (this) {
        CardRarity.legendary => const Color(0xFF2B1B00),
        CardRarity.epic => const Color(0xFF17181C),
        CardRarity.rare => const Color(0xFF2B1D08),
      };

  /// 1.0 for rare, up to 2.0 for legendary — scales particles, ray length
  /// and glow so the better the pull, the bigger the show.
  double get intensity => switch (this) {
        CardRarity.rare => 1.0,
        CardRarity.epic => 1.5,
        CardRarity.legendary => 2.0,
      };
}

/// 1st, 2nd, 3rd, 4th… with the 11th/12th/13th exceptions handled —
/// used for league positions on the Season and pre-match screens.
String ordinalOf(int n) => switch (n % 100) {
      11 || 12 || 13 => '${n}th',
      _ => switch (n % 10) {
          1 => '${n}st',
          2 => '${n}nd',
          3 => '${n}rd',
          _ => '${n}th',
        },
    };

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
    seedColor: FcmColors.gold,
    brightness: Brightness.dark,
  ).copyWith(
    primary: FcmColors.gold,
    onPrimary: FcmColors.ink,
    secondary: FcmColors.bronze,
    surface: FcmColors.surface,
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
          color: FcmColors.ink, fontWeight: FontWeight.w800),
      checkmarkColor: FcmColors.ink,
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
        foregroundColor: FcmColors.ink,
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
