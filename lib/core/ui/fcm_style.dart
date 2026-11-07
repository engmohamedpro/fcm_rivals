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

  /// Free / claim action gradient (mint → success green) — reads as
  /// "costs nothing" next to the gold BUY.
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFC4E8C9), Color(0xFF8FD09A), Color(0xFF54845F)],
  );

  /// Crest swatches the manager picks from at club creation: champagne,
  /// bronze, ember, olive, steel and oxblood — the brand's warm metals.
  /// Shared by the creation picker and everywhere the club's colour is
  /// shown live (e.g. the match momentum bar's user side spikes).
  static const List<Color> crestPalette = [
    Color(0xFFD9B871), // champagne gold
    Color(0xFF8A6E42), // bronze
    Color(0xFF2E2925), // ember charcoal
    Color(0xFF57683F), // olive pitch
    Color(0xFF8D8A96), // steel silver
    Color(0xFF7A3B36), // oxblood
  ];

  /// The club's crest colour by saved [crestIndex] — clamped so a stale
  /// index (older save, future palette change) can never crash the UI.
  static Color crestColor(int index) =>
      crestPalette[index.clamp(0, crestPalette.length - 1)];
}

/// Card rarity. Derived from a player's rating so the same player looks the
/// same in the pack reveal, the collection and the squad: rare, epic and
/// legendary — one rarity language shared with the store's pack tiers,
/// each carrying the gem accent of its pack. Higher rarity gets bigger
/// reveal effects (GDD 5.6).
enum CardRarity {
  rare,
  epic,
  legendary;

  /// Rating thresholds: 80+ legendary (the owner's 2026-11-07 regrade,
  /// T-0047 — every player rated 80+ shows the golden legendary colour in
  /// every surface), 70+ epic, otherwise rare.
  static CardRarity fromOverall(int overall) {
    if (overall >= 80) return CardRarity.legendary;
    if (overall >= 70) return CardRarity.epic;
    return CardRarity.rare;
  }

  String get label => switch (this) {
    CardRarity.rare => 'RARE',
    CardRarity.epic => 'EPIC',
    CardRarity.legendary => 'LEGENDARY',
  };

  /// Main accent colour (glow, rays, particles): a jewel ladder — royal
  /// amethyst, royal sapphire, radiant champion gold. Saturated enough
  /// to read at a glance on the charcoal night, three clearly distinct
  /// hues, and legendary still crowns the brand's own gold.
  Color get accent => switch (this) {
    CardRarity.rare => const Color(0xFF8B5CF6),
    CardRarity.epic => const Color(0xFF3B82F6),
    CardRarity.legendary => const Color(0xFFF7C948),
  };

  /// Card face gradient, top-left → bottom-right: each gem cast as a
  /// metal — light jewel sheen into the royal tone into its deep shade.
  List<Color> get faceGradient => switch (this) {
    CardRarity.rare => const [
      Color(0xFFCDB8FA),
      Color(0xFF8B5CF6),
      Color(0xFF36206B),
    ],
    CardRarity.epic => const [
      Color(0xFFBFD6FD),
      Color(0xFF3B82F6),
      Color(0xFF14315E),
    ],
    CardRarity.legendary => const [
      Color(0xFFFFF3C4),
      Color(0xFFE9B93F),
      Color(0xFF7A4E00),
    ],
  };

  /// Text colour that stays readable on [faceGradient].
  Color get ink => switch (this) {
    CardRarity.legendary => const Color(0xFF2B1B00),
    CardRarity.epic => const Color(0xFF0D1B36),
    CardRarity.rare => const Color(0xFF1F0F45),
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
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Premium dark Material theme used by the whole app.
ThemeData buildFcmTheme() {
  final scheme =
      ColorScheme.fromSeed(
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
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FcmPageTransitions(),
        TargetPlatform.iOS: FcmPageTransitions(),
        TargetPlatform.macOS: FcmPageTransitions(),
        TargetPlatform.windows: FcmPageTransitions(),
        TargetPlatform.linux: FcmPageTransitions(),
        TargetPlatform.fuchsia: FcmPageTransitions(),
      },
    ),
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
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
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
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
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: const TextStyle(
        color: FcmColors.ink,
        fontWeight: FontWeight.w800,
      ),
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
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: FcmColors.gold,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FcmColors.gold,
        foregroundColor: FcmColors.ink,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
          fontSize: 15,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          fontSize: 14,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
