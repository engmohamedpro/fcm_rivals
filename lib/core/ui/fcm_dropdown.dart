/// FCM Rivals — shared premium UI kit: {title}.
///
/// Split out of the original single-file kit so each widget
/// family evolves independently; `fcm_widgets.dart` re-exports
/// everything, so existing imports are untouched.
library;

import 'package:flutter/material.dart';
import 'fcm_style.dart';
import 'fcm_motion.dart';

import 'fcm_widgets_helpers.dart';


// -----------------------------------------------------------------------------
// Dropdown
// -----------------------------------------------------------------------------

/// One entry of an [FcmDropdown]: a value plus the label shown in the
/// closed field and the effect summary rendered under it in the sheet.
class FcmDropdownItem<T> {
  const FcmDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;

  /// Secondary line (effect summaries) shown in the picker sheet.
  final String? subtitle;
}

/// Brand-styled dropdown for tactic selectors (GDD 10). The closed field
/// looks like a steel [FcmButton]; tapping opens a bottom sheet listing
/// every option with its visible percentage effects, the selected one
/// highlighted in gold. [onChanged] is skipped when the picked value
/// equals the current one.
class FcmDropdown<T> extends StatelessWidget {
  const FcmDropdown({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.hint,
    this.icon,
  });

  final List<FcmDropdownItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Field label rendered inside the closed field when nothing matches.
  final String? hint;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final item = items.firstWhere(
      (i) => i.value == selected,
      orElse: () => FcmDropdownItem(value: selected, label: hint ?? '—'),
    );
    return FcmPressable(
      onTap: () => _openSheet(context),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: FcmColors.steelGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FcmColors.bronze.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: FcmColors.goldSoft, size: 18),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FitText(
                item.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              color: FcmColors.goldSoft,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    fcmTick();
    final picked = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: FcmColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(top: 8, bottom: 6),
                decoration: BoxDecoration(
                  color: FcmColors.bronze.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    for (final i in items)
                      _SheetTile(
                        item: i,
                        selected: i.value == selected,
                        onTap: () => Navigator.pop(sheetContext, i.value),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked == selected) return;
    fcmTick();
    onChanged(picked);
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FcmDropdownItem<dynamic> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FcmPressable(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: item.subtitle != null ? 11 : 13,
          ),
          decoration: BoxDecoration(
            gradient: selected
                ? FcmColors.goldGradient
                : FcmColors.steelGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? FcmColors.goldSoft.withValues(alpha: 0.6)
                  : FcmColors.bronze.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? FcmColors.ink : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? FcmColors.ink.withValues(alpha: 0.85)
                              : FcmColors.textDim,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: FcmColors.ink, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

