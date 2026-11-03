import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/domain/players.dart' show Position;
import '../../core/ui/fcm_logo.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../squad/formations.dart';

/// Club creation (GDD 3, FR-001): club name, crest, manager name and
/// the STARTER FORMATION — the shape the free 22 packs are matched to
/// (two packs per slot) and the squad's initial setup. Changeable any
/// time later from the Team tab.
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
      ref.invalidate(clubProvider);
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
                            errorBuilder: (_, __, ___) =>
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
                          Text('Create your club',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(color: Colors.white)),
                          const SizedBox(height: 6),
                          Text(
                            'You start with coins and 22 free packs — two '
                            'for every position in your starter formation.',
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
                            const SizedBox(height: 22),
                            const Text('STARTER FORMATION',
                                style: TextStyle(
                                    color: FcmColors.textDim,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2)),
                            const SizedBox(height: 4),
                            const Text(
                              'This is your starter formation — your team '
                              'starts in this shape and your 22 free packs '
                              'match its positions. You can change it any '
                              'time later from the Team tab.',
                              style: TextStyle(
                                  color: FcmColors.textDim,
                                  fontSize: 11,
                                  height: 1.4),
                            ),
                            const SizedBox(height: 10),
                            for (final f in formations)
                              _FormationOption(
                                formation: f,
                                selected: f.code == _formationCode,
                                onTap: () =>
                                    setState(() => _formationCode = f.code),
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
class _CrestOption extends StatelessWidget {  const _CrestOption({
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

/// One formation choice: the formation code as the headline and the
/// position census of its eleven slots as compact badges (GK 1 · CB 2
/// · LB 1 · …), so the user sees exactly what the 22 free packs will
/// cover. The selected row glows gold.
class _FormationOption extends StatelessWidget {
  const _FormationOption({
    required this.formation,
    required this.selected,
    required this.onTap,
  });

  final Formation formation;
  final bool selected;
  final VoidCallback onTap;

  /// Slot census in formation order, e.g. [(GK, 1), (CB, 2), (CDM, 1)].
  List<(Position, int)> get _census {
    final out = <(Position, int)>[];
    for (final slot in formation.slots) {
      final i = out.indexWhere((c) => c.$1 == slot.position);
      if (i == -1) {
        out.add((slot.position, 1));
      } else {
        out[i] = (out[i].$1, out[i].$2 + 1);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FcmPressable(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: selected ? FcmColors.goldGradient : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: selected
                  ? FcmColors.goldSoft
                  : Colors.white.withValues(alpha: 0.10),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  formation.name,
                  style: TextStyle(
                    color: selected ? FcmColors.ink : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final (position, count) in _census)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: selected
                              ? FcmColors.ink.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${position.code} $count',
                          style: TextStyle(
                            color:
                                selected ? FcmColors.ink : FcmColors.textDim,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: FcmColors.ink, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
