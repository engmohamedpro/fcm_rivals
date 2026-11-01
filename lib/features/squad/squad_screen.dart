import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/domain/players.dart';
import '../../features/squad/formations.dart';
import '../../features/squad/squad_engine.dart';

/// Squad tab: pitch with the starting XI positioned by the current
/// formation, bench and reserves rows, formation switch and Auto Pick
/// (GDD 6.2/6.3/6.4).
class SquadScreen extends ConsumerWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squad = ref.watch(squadProvider);
    final club = ref.watch(clubProvider).valueOrNull;
    final formation =
        formationByCode(club?.formationCode ?? '4-3-3');

    return squad.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (squad) {
        final xi = {
          for (final e in squad.entries)
            if (e.key < Formation.startingXiSize) e.key: e.value,
        };
        final bench = {
          for (final e in squad.entries)
            if (e.key >= Formation.startingXiSize &&
                e.key < Formation.startingXiSize + Formation.benchSize)
              e.key: e.value,
        };
        final reserves = {
          for (final e in squad.entries)
            if (e.key >=
                Formation.startingXiSize + Formation.benchSize) e.key: e.value,
        };
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _pickFormation(context, ref),
                    icon: const Icon(Icons.grid_on_outlined),
                    label: Text(formation.name),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _autoPick(context, ref),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Auto Pick'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Pitch(formation: formation, assignments: xi),
            const SizedBox(height: 16),
            if (bench.isNotEmpty) ...[
              Text('Bench (${bench.length}/7)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final card in bench.values)
                      _SlotChip(card: card, compact: true),
                  ],
                ),
              ),
            ],
            if (reserves.isNotEmpty) ...[
              Text('Reserves (${reserves.length}/5)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final card in reserves.values)
                      _SlotChip(card: card, compact: true),
                  ],
                ),
              ),
            ],
            if (squad.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                      'Open packs to collect players, then tap Auto Pick.'),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _autoPick(BuildContext context, WidgetRef ref) async {
    final store = await ref.read(collectionStoreProvider.future);
    await store.autoPickSquad();
    ref.invalidate(squadProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Best squad selected')));
    }
  }

  Future<void> _pickFormation(BuildContext context, WidgetRef ref) async {
    final formations = ref.read(formationsProvider);
    final club = ref.read(clubProvider).valueOrNull;
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose formation'),
        children: [
          for (final f in formations)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, f.code),
              child: Text(f.name),
            ),
        ],
      ),
    );
    if (chosen == null || chosen == club?.formationCode) return;
    final store = await ref.read(collectionStoreProvider.future);
    await store.changeFormation(chosen);
    ref.invalidate(clubProvider);
    ref.invalidate(squadProvider);
  }
}

/// Renders the pitch with player chips at formation coordinates (GDD 6.2).
class _Pitch extends StatelessWidget {
  const _Pitch({required this.formation, required this.assignments});

  final Formation formation;
  final Map<int, PlayerCard> assignments;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.72,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14532D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          return Stack(
            children: [
              // halfway line + center circle
              Positioned(
                left: 0,
                right: 0,
                top: constraints.maxHeight / 2,
                child: Container(height: 1, color: Colors.white24),
              ),
              Positioned(
                left: constraints.maxWidth / 2 - 28,
                top: constraints.maxHeight / 2 - 28,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
              ),
              for (var slot = 0; slot < formation.slots.length; slot++)
                () {
                  final fs = formation.slots[slot];
                  final card = assignments[slot];
                  return Positioned(
                    left: (fs.x / 100) * (constraints.maxWidth - 64) + 8,
                    top: (1 - fs.y / 100) * (constraints.maxHeight - 80) + 4,
                    child: _SlotChip(
                      card: card,
                      compact: false,
                      slotPosition: fs.position,
                    ),
                  );
                }(),
            ],
          );
        }),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.card,
    required this.compact,
    this.slotPosition,
  });

  final PlayerCard? card;
  final bool compact;
  final Position? slotPosition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (card == null) {
      return Container(
        width: compact ? 120 : 56,
        height: compact ? 76 : 72,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(slotPosition?.code ?? '—',
              style: const TextStyle(color: Colors.white70)),
        ),
      );
    }
    final c = card!;
    final mismatch = slotPosition != null && slotPosition != c.position;
    return Container(
      width: compact ? 120 : 56,
      height: compact ? 76 : 72,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: mismatch
            ? Border.all(color: theme.colorScheme.error, width: 2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${c.overall}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(c.position.code, style: theme.textTheme.bodySmall),
          if (!compact || true)
            Text(
              c.base.name.split(' ').last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontSize: 10),
            ),
        ],
      ),
    );
  }
}
