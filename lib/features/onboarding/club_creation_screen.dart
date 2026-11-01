import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

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

  static const _crestColors = [
    Color(0xFF0B7A3B), // green
    Color(0xFF1565C0), // blue
    Color(0xFFC62828), // red
    Color(0xFFF9A825), // amber
    Color(0xFF6A1B9A), // purple
    Color(0xFF37474F), // slate
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text('Create your club',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    'You start with coins and 36 free position packs.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _clubName,
                    decoration: const InputDecoration(
                        labelText: 'Club name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag_outlined)),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _managerName,
                    decoration: const InputDecoration(
                        labelText: 'Manager name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  Text('Club crest',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < _crestColors.length; i++)
                        _CrestOption(
                          color: _crestColors[i],
                          selected: i == _crestIndex,
                          onTap: () => setState(() => _crestIndex = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Start managing'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: const Icon(Icons.star_outlined, color: Colors.white),
      ),
    );
  }
}
