import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';

import '../../app/providers.dart';
import '../../core/ui/fcm_logo.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../squad/formations.dart';

/// Club creation (GDD 3, FR-001): club name, crest, manager name and
/// the STARTER FORMATION — the squad's initial shape, picked the same
/// way the Team tab picks it. Changeable any time later from the Team
/// tab.
class ClubCreationScreen extends ConsumerStatefulWidget {
  const ClubCreationScreen({super.key});

  @override
  ConsumerState<ClubCreationScreen> createState() => _ClubCreationScreenState();
}

class _ClubCreationScreenState extends ConsumerState<ClubCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clubName = TextEditingController();
  final _managerName = TextEditingController();
  int _crestIndex = 0;
  String _formationCode = formations.first.code;
  bool _submitting = false;

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
      await store.createClub(
        clubName: _clubName.text,
        managerName: _managerName.text,
        crestIndex: _crestIndex,
        formationCode: _formationCode,
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
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            const SizedBox(height: 14),
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
                            const SizedBox(height: 22),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.clubCrestSection,
                              style: TextStyle(
                                color: FcmColors.textDim,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
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
                            const SizedBox(height: 22),
                            Text(
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
                            const SizedBox(height: 10),
                            // The same picker the Team tab uses: the
                            // closed field shows the live shape, tapping
                            // lists every formation by name.
                            FcmDropdown<String>(
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FcmEntrance(
                      index: 3,
                      child: FcmButton(
                        label: AppLocalizations.of(context)!.startManaging,
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
                BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 18),
            ],
          ),
          child: const Icon(Icons.star_rounded, color: Colors.white),
        ),
      ),
    );
  }
}
