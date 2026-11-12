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
    this.onReselected,
  });

  final List<FcmNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  /// Called instead of [onChanged] when the already-selected tab is tapped
  /// again — the usual "scroll to top" gesture.
  final ValueChanged<int>? onReselected;

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
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FcmGoldSeam(bloomBelow: true, bloomHeight: 2),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavButton(
                        item: items[i],
                        selected: i == index,
                        onTap: () => i == index
                            ? onReselected?.call(i)
                            : onChanged(i),
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
    final badge = item.badge ?? 0;
    final inactive = Colors.white.withValues(alpha: 0.66);
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '${item.label}, $badge' : item.label,
      excludeSemantics: true,
      child: FcmPressable(
        onTap: onTap,
        scale: 0.92,
        child: ConstrainedBox(
          // Material's minimum touch target height.
          constraints: const BoxConstraints(minHeight: 48),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.only(top: 7, bottom: 4),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: -7,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: selected ? 22 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: FcmColors.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedScale(
                          scale: selected ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            item.icon,
                            size: 24,
                            color: selected ? FcmColors.gold : inactive,
                          ),
                        ),
                        if (badge > 0)
                          // Directional so the badge mirrors in RTL.
                          PositionedDirectional(
                            top: -7,
                            end: -13,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 17),
                              height: 17,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: FcmColors.goldGradient,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: FcmColors.ink,
                                  width: 1.5,
                                ),
                              ),
                              child: FitText(
                                (badge > 99) ? '99+' : '$badge',
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
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: FitText(
                        item.label,
                        align: Alignment.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          letterSpacing: 0.1,
                          color: selected ? FcmColors.gold : inactive,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
