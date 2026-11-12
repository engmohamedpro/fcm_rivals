import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';

import '../../app/providers.dart';
import '../../core/ui/fcm_logo.dart';
import '../../core/ui/fcm_language_toggle.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../squad/formations.dart';
import '../../core/domain/crest.dart';
import '../../core/ui/fcm_crest.dart';

/// Club creation (GDD 3, FR-001): club name, crest, manager name and
/// the STARTER FORMATION — the squad's initial shape, picked the same
/// way the Team tab picks it. Changeable any time later from the Team
/// tab.
class ClubCreationScreen extends ConsumerStatefulWidget {
  const ClubCreationScreen({super.key});

  @override
  ConsumerState<ClubCreationScreen> createState() => _ClubCreationScreenState();
}

/// Horizontal inset of the card's ordinary content; the crest pickers
/// bypass it so their scroll rows run edge to edge.
const _kCardGutter = EdgeInsets.symmetric(horizontal: 18);

class _ClubCreationScreenState extends ConsumerState<ClubCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clubName = TextEditingController();
  final _managerName = TextEditingController();
  String _formationCode = formations.first.code;
  bool _submitting = false;

  /// T-0098: the advanced crest builder's live state — shape, primary,
  /// secondary, icon. The default is the legacy look (shield, palette
  /// royal blue and ivory, star) so a fresh player who
  /// skips the builder saves a sane crest. Secondary never equals
  /// primary — the picker auto-corrects on every path.
  var _crestShape = CrestShape.shield;
  var _crestPrimary = 7; // royal blue
  var _crestSecondary = 13; // ivory
  var _crestIconColor = 13; // icon color
  var _crestIcon = CrestIcon.star;
  var _crestPattern = CrestPattern.halves;

  /// The built spec — what the preview shows and _submit persists.
  CrestSpec get _crestSpec => CrestSpec(
    shape: _crestShape,
    primaryIndex: _crestPrimary,
    secondaryIndex: _crestSecondary,
    icon: _crestIcon,
    pattern: _crestPattern,
    iconIndex: _crestIconColor,
  );

  /// Crest swatches live in the shared brand palette
  /// ([FcmColors.crestPalette]) — the same colours show up live wherever
  /// the club is represented (match momentum bar).
  static const _crestColors = FcmColors.crestPalette;

  @override
  void dispose() {
    _clubName.dispose();
    _managerName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final store = await ref.read(collectionStoreProvider.future);
    try {
      // T-0098: the built spec persists through the T-0097 API;
      // crestIndex mirrors the spec's primary palette index for the
      // legacy consumers.
      await store.createClub(
        clubName: _clubName.text,
        managerName: _managerName.text,
        crestIndex: _crestSpec.primaryIndex,
        formationCode: _formationCode,
        crest: _crestSpec,
      );
      ref.invalidate(availablePacksProvider);
      ref.invalidate(campusProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crest = FcmColors.crestColor(_crestSpec.primaryIndex);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: FcmBackdrop(
        tint: crest,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // T-0096: the language toggle above the wordmark —
                    // a brand-new player flips EN/AR before typing
                    // anything. End-aligned so LTR/RTL both park it at
                    // the far corner; visible without scrolling.
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: const FcmLanguageToggle(),
                    ),
                    const SizedBox(height: 4),
                    FcmEntrance(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Image.asset(
                            kFcmWordmarkAsset,
                            cacheWidth: 500,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const FcmWordmark(size: 36),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FcmEntrance(
                      index: 1,
                      child: Column(
                        children: [
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.createYourClub,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    FcmEntrance(
                      index: 2,
                      child: FcmPanel(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: _kCardGutter,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  FcmCrest(spec: _crestSpec, width: 62),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        TextFormField(
                                          controller: _clubName,
                                          textInputAction: TextInputAction.next,
                                          textCapitalization: TextCapitalization.words,
                                          decoration: _field(
                                            AppLocalizations.of(
                                              context,
                                            )!.clubNameLabel,
                                            Icons.shield_outlined,
                                          ),
                                          validator: (v) => (v == null || v.trim().isEmpty)
                                              ? AppLocalizations.of(
                                                    context,
                                                  )!.fieldRequired
                                              : null,
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _managerName,
                                          textInputAction: TextInputAction.done,
                                          textCapitalization: TextCapitalization.words,
                                          decoration: _field(
                                            AppLocalizations.of(
                                              context,
                                            )!.managerNameLabel,
                                            Icons.person_outline,
                                          ),
                                          validator: (v) => (v == null || v.trim().isEmpty)
                                              ? AppLocalizations.of(
                                                    context,
                                                  )!.fieldRequired
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _CrestBuilder(
                              spec: _crestSpec,
                              colors: _crestColors,
                              onShape: (s) => setState(() => _crestShape = s),
                              onPrimary: (i) => setState(() => _crestPrimary = i),
                              onSecondary: (i) => setState(() => _crestSecondary = i),
                              onIconColor: (i) => setState(() => _crestIconColor = i),
                              onIcon: (ic) => setState(() => _crestIcon = ic),
                              onPattern: (pt) =>
                                  setState(() => _crestPattern = pt),
                            ),
                            const SizedBox(height: 22),
                            Padding(
 padding: _kCardGutter,
 child: Text(
                              AppLocalizations.of(
                                context,
                              )!.starterFormationSection,
                              style: TextStyle(
                                color: FcmColors.textDim,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
),
                            const SizedBox(height: 10),
                            // The same picker the Team tab uses: the
                            // closed field shows the live shape, tapping
                            // lists every formation by name.
                            Padding(
 padding: _kCardGutter,
 child: FcmDropdown<String>(
                              icon: Icons.grid_on_rounded,
                              items: [
                                for (final f in formations)
                                  FcmDropdownItem(
                                    value: f.code,
                                    label: f.name,
                                  ),
                              ],
                              selected: _formationCode,
                              onChanged: (code) =>
                                  setState(() => _formationCode = code),
                            ),
),
                            const SizedBox(height: 22),
                            Padding(
                              padding: _kCardGutter,
                              child: FcmButton(
                                label: AppLocalizations.of(context)!.start,
                                loading: _submitting,
                                onPressed: _submitting ? null : _submit,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _field(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: FcmColors.gold),
    filled: true,
    fillColor: Colors.black.withValues(alpha: 0.28),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: FcmColors.gold, width: 2),
    ),
  );
}

/// T-0098: the advanced crest builder — a live [FcmCrest] preview with
/// the RANDOMIZE action, then compact pickers for SHAPE, PRIMARY,
/// SECONDARY and ICON. Selected options pop in gold like the old
/// swatch behaviour; primary and secondary can never collide (the
/// caller's callbacks auto-correct). Every row mirrors with the
/// text direction — no hardcoded left/right.
class _CrestBuilder extends StatelessWidget {
  const _CrestBuilder({
    required this.spec,
    required this.colors,
    required this.onShape,
    required this.onPrimary,
    required this.onSecondary,
    required this.onIconColor,
    required this.onIcon,
    required this.onPattern,
  });

  final CrestSpec spec;
  final List<Color> colors;
  final ValueChanged<CrestShape> onShape;
  final ValueChanged<int> onPrimary;
  final ValueChanged<int> onSecondary;
  final ValueChanged<int> onIconColor;
  final ValueChanged<CrestIcon> onIcon;
  final ValueChanged<CrestPattern> onPattern;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row 1: Primary color button switcher + Shapes
        _ScrollRow(
          leading: _ColorButtonSwitcher(
            color: colors[spec.primaryIndex],
            onTap: () {
              var next = (spec.primaryIndex + 1) % colors.length;
              if (next == spec.secondaryIndex) {
                next = (next + 1) % colors.length;
              }
              onPrimary(next);
            },
          ),
          children: [
            for (final shape in CrestShape.values)
              _ShapeOption(
                spec: spec,
                shape: shape,
                selected: shape == spec.shape,
                onTap: () => onShape(shape),
              ),
          ],
        ),
        // Row 2: Secondary color button switcher + Patterns
        _ScrollRow(
          leading: _ColorButtonSwitcher(
            color: colors[spec.secondaryIndex],
            onTap: () {
              var next = (spec.secondaryIndex + 1) % colors.length;
              if (next == spec.primaryIndex) {
                next = (next + 1) % colors.length;
              }
              onSecondary(next);
            },
          ),
          children: [
            for (final pattern in CrestPattern.values)
              _PatternOption(
                pattern: pattern,
                primary: spec.primaryColor,
                secondary: spec.secondaryColor,
                selected: pattern == spec.pattern,
                onTap: () => onPattern(pattern),
              ),
          ],
        ),
        // Row 3: Icon color button switcher + Icons
        _ScrollRow(
          leading: _ColorButtonSwitcher(
            color: colors[spec.iconIndex],
            onTap: () {
              var next = (spec.iconIndex + 1) % colors.length;
              onIconColor(next);
            },
          ),
          children: [
            for (final icon in CrestIcon.values)
              _IconOption(
                icon: icon,
                selected: icon == spec.icon,
                onTap: () => onIcon(icon),
              ),
          ],
        ),
      ],
    );
  }
}

/// One picker row: a single line that scrolls sideways, so a long
/// option list never wraps into a tall block. Items keep their
/// pop-scale room (vertical padding) and the row follows the text
/// direction.
class _ScrollRow extends StatelessWidget {
  const _ScrollRow({required this.children, this.leading});

  final List<Widget> children;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    return SizedBox(
      height: 68,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.hardEdge,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          children: [
            if (leading != null) ...[
              Center(child: leading!),
              const SizedBox(width: gap + 4),
            ],
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Center(child: children[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// A color button switcher at the start of each row.
class _ColorButtonSwitcher extends StatelessWidget {
  const _ColorButtonSwitcher({
    required this.color,
    required this.onTap,
  });

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FcmPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, 0.28)!,
              color,
              Color.lerp(color, Colors.black, 0.3)!,
            ],
          ),
          border: Border.all(
            color: FcmColors.gold,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 10),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.palette_rounded,
            size: 16,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// A shape swatch: a mini crest silhouette in the current colours so
/// the choice reads visually, not as text.
class _ShapeOption extends StatelessWidget {
  const _ShapeOption({
    required this.spec,
    required this.shape,
    required this.selected,
    required this.onTap,
  });

  final CrestSpec spec;
  final CrestShape shape;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = spec.primaryColor;
    return FcmPressable(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.28 : 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? FcmColors.gold : Colors.white24,
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: FcmCrest(
            spec: CrestSpec(
              shape: shape,
              primaryIndex: spec.primaryIndex,
              secondaryIndex: spec.secondaryIndex,
              icon: spec.icon,
              pattern: spec.pattern,
            ),
            width: 34,
          ),
        ),
      ),
    );
  }
}

/// An icon swatch: the glyph in a gold-rimmed chip.
class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final CrestIcon icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FcmPressable(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: FcmColors.gold.withValues(alpha: selected ? 0.22 : 0.08),
            border: Border.all(
              color: selected ? FcmColors.gold : Colors.white24,
              width: selected ? 2.5 : 1.5,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: FcmColors.gold.withValues(alpha: 0.5),
                  blurRadius: 16,
                ),
            ],
          ),
          child: FcmCrestGlyph(
            icon: icon,
            color: selected ? FcmColors.goldSoft : Colors.white70,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// A pattern swatch in the crest's current colours.
class _PatternOption extends StatelessWidget {
  const _PatternOption({
    required this.pattern,
    required this.primary,
    required this.secondary,
    required this.selected,
    required this.onTap,
  });

  final CrestPattern pattern;
  final Color primary;
  final Color secondary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FcmPressable(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? FcmColors.gold : Colors.white24,
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: FcmCrestPatternChip(
            pattern: pattern,
            primary: primary,
            secondary: secondary,
            size: 34,
          ),
        ),
      ),
    );
  }
}
