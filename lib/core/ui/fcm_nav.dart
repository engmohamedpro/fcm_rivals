/// FCM Rivals — shared premium UI kit: the bottom navigation and chrome seams.
///
/// Split out of the original single-file kit so each widget
/// family evolves independently; `fcm_widgets.dart` re-exports
/// everything, so existing imports are untouched.
library;

import 'package:flutter/material.dart';
import 'fcm_style.dart';
import 'fcm_motion.dart';


// -----------------------------------------------------------------------------
// Navigation
// -----------------------------------------------------------------------------

/// The brand's light seam: a hairline of gradient gold with a soft bloom
/// falling to one side. The AppBar caps itself with the bloom rising
/// into the bar, the bottom nav mirrors it with the bloom falling into
/// the nav — the two chrome edges read as one lit system.
class FcmGoldSeam extends StatelessWidget {
  const FcmGoldSeam({
    super.key,
    this.bloomBelow = false,
    this.bloomHeight = 3.8,
  });

  /// When true the line sits on top and the bloom falls below it (bottom
  /// nav); otherwise the bloom rises above the line (AppBar bottom edge).
  final bool bloomBelow;

  final double bloomHeight;

  @override
  Widget build(BuildContext context) {
    final line = Container(
      height: 1.2,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x3D6E5426),
            FcmColors.goldSoft,
            FcmColors.gold,
            Color(0x3D6E5426),
          ],
        ),
      ),
    );
    final bloom = Container(
      height: bloomHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bloomBelow
              ? [FcmColors.gold.withValues(alpha: 0.22), Colors.transparent]
              : [Colors.transparent, FcmColors.gold.withValues(alpha: 0.22)],
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: bloomBelow ? [line, bloom] : [bloom, line],
    );
  }
}

class FcmNavItem {
  const FcmNavItem(this.label, this.icon, {this.badge});

  final String label;
  final IconData icon;

  /// Optional notification badge (hidden when null or zero) — e.g. the
  /// number of unopened packs waiting on the Store tab.
  final int? badge;
}

/// Bottom navigation: animated gold pill behind the selected item.
class FcmBottomNav extends StatelessWidget {
  const FcmBottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<FcmNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Same chrome language as the AppBar: a deep vertical gradient
      // capped by the gold light seam — line on the top edge, bloom
      // falling into the nav.
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0A0E), Color(0xFF141319)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FcmGoldSeam(bloomBelow: true),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavButton(
                        item: items[i],
                        selected: i == index,
                        onTap: () => onChanged(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FcmNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FcmPressable(
      onTap: onTap,
      scale: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // Borderless: the selected tab is lit, not boxed — a soft gold
          // wash falling from above plus a glow under it, no stroke that
          // would read as a button outline.
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    FcmColors.gold.withValues(alpha: 0.16),
                    FcmColors.gold.withValues(alpha: 0.04),
                  ],
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: FcmColors.gold.withValues(alpha: 0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: selected ? 1.18 : 1.0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: selected ? FcmColors.gold : Colors.white60,
                  ),
                ),
                if ((item.badge ?? 0) > 0)
                  Positioned(
                    top: -7,
                    right: -13,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      height: 17,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: FcmColors.goldGradient,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: FcmColors.ink, width: 1.5),
                      ),
                      child: FitText(
                        (item.badge! > 99) ? '99+' : '${item.badge}',
                        align: Alignment.center,
                        style: const TextStyle(
                          color: FcmColors.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FitText(
                item.label,
                align: Alignment.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: selected ? FcmColors.gold : Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
