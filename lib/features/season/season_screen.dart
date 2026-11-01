import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../match/match_session.dart';
import 'season_store.dart';

/// Season screen (GDD 9): standings, the next fixture and season
/// management — start, play, quick-sim, complete and roll into the next
/// division.
class SeasonScreen extends ConsumerStatefulWidget {
  const SeasonScreen({super.key});

  @override
  ConsumerState<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends ConsumerState<SeasonScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function(SeasonStore store) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(await ref.read(seasonStoreProvider.future));
      ref.invalidate(seasonSummaryProvider);
      ref.invalidate(standingsProvider);
      ref.invalidate(nextFixtureProvider);
      ref.invalidate(clubProvider);
      ref.invalidate(availablePacksProvider);
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = '$e'.replaceFirst('SeasonException: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startSeason() => _run((store) => store.startSeason(division: 1));

  Future<void> _playNextFixture() async {
    final store = await ref.read(seasonStoreProvider.future);
    final next = (await store.getNextFixture())!;
    final collection = await ref.read(collectionStoreProvider.future);
    final session = await store.startNextFixture(collection);
    if (!mounted) return;
    // Quick-sim this fixture: the full live-match flow is the Match tab.
    session.simulateToEnd();
    final report = await session.finish();
    await store.commitFixtureResult(session, next);
    ref.invalidate(seasonSummaryProvider);
    ref.invalidate(standingsProvider);
    ref.invalidate(nextFixtureProvider);
    ref.invalidate(clubProvider);
    if (mounted) {
      await _showMatchReport(report);
      await _maybeCompleteSeason();
    }
  }

  Future<void> _simulateRound() => _run((store) async {
        // Simulate until the user's next round advances by one: cheap
        // approach — simulate remaining fixtures of nothing; instead we
        // simulate ALL remaining fixtures (fast enough at ~380 matches).
        await store.simulateRemainingFixtures(
            await ref.read(collectionStoreProvider.future));
      });

  Future<void> _showMatchReport(MatchReportResult report) {
    final theme = Theme.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            'Full time: ${report.state.scoreHome} - ${report.state.scoreAway}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reward: ${report.rewardCoins} coins',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.primary)),
            if (report.manOfTheMatch != null)
              Text('Man of the Match: ${report.manOfTheMatch!.name}'),
            if (report.commentary.any((l) => l.importance == 2))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  report.commentary
                      .where((l) => l.importance == 2)
                      .map((l) => "${l.minute}' ${l.text}")
                      .join('\n'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompletion(SeasonCompletion completion) {
    final theme = Theme.of(context);
    final outcomeLabel = switch (completion.outcome) {
      'promoted' => 'Promoted!',
      'relegated' => 'Relegated',
      _ => 'Stayed up',
    };
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Season complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$outcomeLabel You finished ${completion.finalPosition} of 20.',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Season reward: ${completion.rewardCoins} coins'),
            if (completion.rewardPackCategory != null)
              Text('Reward pack: ${completion.rewardPackCategory}'),
            Text('Next division: ${completion.nextDivision}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _maybeCompleteSeason() async {
    final store = await ref.read(seasonStoreProvider.future);
    final next = await store.getNextFixture();
    if (next != null) return;
    final collection = await ref.read(collectionStoreProvider.future);
    final completion = await store.completeSeason(collection);
    ref.invalidate(seasonSummaryProvider);
    ref.invalidate(standingsProvider);
    ref.invalidate(clubProvider);
    ref.invalidate(availablePacksProvider);
    if (mounted) await _showCompletion(completion);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = ref.watch(seasonSummaryProvider).valueOrNull;
    final standings = ref.watch(standingsProvider).valueOrNull;
    final next = ref.watch(nextFixtureProvider).valueOrNull;

    if (ref.watch(seasonSummaryProvider).isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (summary == null) {
      // No season yet: start the first campaign (GDD 9.1: division 1).
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Start your first season', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Division 1 · 20 clubs · 38 matches',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _startSeason,
              icon: const Icon(Icons.flag),
              label: const Text('Start season'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header: division, progress and outcome.
        Row(
          children: [
            Expanded(
              child: Text(
                summary.isCompleted
                    ? 'Season ${summary.ordinal} · Division ${summary.division} · finished'
                    : 'Season ${summary.ordinal} · Division ${summary.division}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          summary.isCompleted
              ? 'Final position: ${summary.finalPosition} (${summary.outcome})'
              : 'Round ${summary.roundsPlayed + (next != null ? 0 : 1)} of ${summary.roundsTotal}',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),

        // Next fixture card (GDD 9.2) or season controls.
        if (!summary.isCompleted && next != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next fixture · round ${next.round}',
                      style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    next.isHome
                        ? 'vs ${next.opponentName} (home)'
                        : 'at ${next.opponentName} (away)',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _playNextFixture,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play match'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _simulateRound,
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Sim rest'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (!summary.isCompleted && next == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _busy ? null : _maybeCompleteSeason,
                icon: const Icon(Icons.emoji_events),
                label: const Text('Complete season'),
              ),
            ),
          ),
        if (summary.isCompleted)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run((store) => store.startNextSeason(
                        ref.read(collectionStoreProvider).value!)),
                icon: const Icon(Icons.flag),
                label: Text(
                    'Start season in division ${summary.outcome == 'promoted' ? summary.division + 1 : summary.outcome == 'relegated' ? (summary.division > 1 ? summary.division - 1 : 1) : summary.division}'),
              ),
            ),
          ),
        const SizedBox(height: 16),

        // Standings (GDD 9.3).
        Text('Standings', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (standings == null || standings.isEmpty)
          const Text('No matches played yet.')
        else
          Card(
            child: Column(
              children: [
                // header row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: const [
                      SizedBox(width: 28, child: Text('#')),
                      Expanded(child: Text('Club')),
                      SizedBox(
                          width: 34, child: Text('P', textAlign: TextAlign.end)),
                      SizedBox(
                          width: 34,
                          child: Text('GD', textAlign: TextAlign.end)),
                      SizedBox(
                          width: 34,
                          child: Text('Pts', textAlign: TextAlign.end)),
                    ],
                  ),
                ),
                for (final e in standings)
                  Container(
                    color: e.position <= 3
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                        : e.position > 17
                            ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                            : null,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 28,
                            child: Text('${e.position}',
                                style: theme.textTheme.bodySmall)),
                        Expanded(child: Text(e.name, maxLines: 1)),
                        SizedBox(
                            width: 34,
                            child: Text('${e.played}',
                                textAlign: TextAlign.end)),
                        SizedBox(
                            width: 34,
                            child: Text(
                                e.goalDifference >= 0
                                    ? '+${e.goalDifference}'
                                    : '${e.goalDifference}',
                                textAlign: TextAlign.end)),
                        SizedBox(
                            width: 34,
                            child: Text('${e.points}',
                                textAlign: TextAlign.end,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
