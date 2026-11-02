import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ui/fcm_logo.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';

/// Club creation (GDD 3, FR-001): club name, crest and manager name.
class ClubCreationScreen extends ConsumerStatefulWidget {
  const ClubCreationScreen({super.key});

  @override
  ConsumerState<ClubCreationScreen> createState() =>
      _ClubCreationScreenState();
}

class _ClubCreationScreenState extends ConsumerState<ClubCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clubName = TextEditingController();
  final _managerName = TextEditingController();
  int _crestIndex = 0;
  bool _submitting = false;

  /// Crest swatches stay inside the brand's warm metal palette: champagne,
  /// bronze, ember, olive, steel and oxblood.
  static const _crestColors = [
    Color(0xFFD9B871), // champagne gold
    Color(0xFF8A6E42), // bronze
    Color(0xFF2E2925), // ember charcoal
    Color(0xFF57683F), // olive pitch
    Color(0xFF8D8A96), // steel silver
    Color(0xFF7A3B36), // oxblood
  ];

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
      await store.createClub(
        clubName: _clubName.text,
        managerName: _managerName.text,
        crestIndex: _crestIndex,
      );
      ref.invalidate(clubProvider);
      ref.invalidate(availablePacksProvider);
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
    final crest = _crestColors[_crestIndex];
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: FcmBackdrop(
        tint: crest,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FcmEntrance(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              kFcmLogoAsset,
                              cacheWidth: 500,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const FcmWordmark(size: 36),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FcmEntrance(
                      index: 1,
                      child: Column(
                        children: [
                          Text('Create your club',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(color: Colors.white)),
                          const SizedBox(height: 6),
                          Text(
                            'You start with coins and 36 free position packs.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: FcmColors.textDim),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    FcmEntrance(
                      index: 2,
                      child: FcmPanel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _clubName,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              decoration: _field(
                                  'Club name', Icons.shield_outlined),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _managerName,
                              textInputAction: TextInputAction.done,
                              textCapitalization: TextCapitalization.words,
                              decoration: _field(
                                  'Manager name', Icons.person_outline),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 22),
                            const Text('CLUB CREST',
                                style: TextStyle(
                                    color: FcmColors.textDim,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                for (var i = 0; i < _crestColors.length; i++)
                                  _CrestOption(
                                    color: _crestColors[i],
                                    selected: i == _crestIndex,
                                    onTap: () =>
                                        setState(() => _crestIndex = i),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FcmEntrance(
                      index: 3,
                      child: FcmButton(
                        label: 'Start managing',
                        icon: Icons.arrow_forward_rounded,
                        loading: _submitting,
                        onPressed: _submitting ? null : _submit,
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

/// Shield-shaped crest swatch; the selected one pops and glows.
class _CrestOption extends StatelessWidget {
  const _CrestOption({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: 52,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(26),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, Colors.white, 0.28)!,
                color,
                Color.lerp(color, Colors.black, 0.4)!,
              ],
            ),
            border: Border.all(
              color: selected ? FcmColors.gold : Colors.white24,
              width: selected ? 3 : 1.5,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                    color: color.withValues(alpha: 0.7), blurRadius: 18),
            ],
          ),
          child: const Icon(Icons.star_rounded, color: Colors.white),
        ),
      ),
    );
  }
}
