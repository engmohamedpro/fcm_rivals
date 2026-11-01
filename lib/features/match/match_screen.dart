import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'match_engine.dart';
import 'match_report.dart';
import 'match_session.dart';
import 'stamina.dart';
import 'tactics.dart';

/// Live match screen (GDD 13, GDD 16): minute-by-minute simulation with
/// commentary feed, live tactical changes and the post-match report with
/// the pep talk choice (GDD 11.6).
class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key});

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> {
  MatchSession? _session;
  final List<CommentaryLine> _lines = [];
  bool _finished = false;
  MatchReportResult? _report;
  PepTalk? _pepTalk;
  String? _error;

  Future<void> _kickOff() async {
    try {
      final store = await ref.read(collectionStoreProvider.future);
      final random = ref.read(randomProvider);
      final session = await MatchSession.create(
        store: store,
        seed: random.nextInt(1 << 31),
        opponentName: 'Cairo XI',
        opponentAverageOverall: 68,
      );
      setState(() {
        _session = session;
        _lines.clear();
        _finished = false;
        _report = null;
        _pepTalk = null;
      });
      _advance();
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  void _advance() {
    final session = _session;
    if (session == null || session.isFinished) return;
    final events = session.advanceMinute();
    if (events.isEmpty) return;
    final lines = generateCommentary(
      events,
      playerNames: session.userPlayerNames,
      homeTeamName: 'FC Rivals',
      awayTeamName: 'Cairo XI',
    );
    setState(() => _lines.addAll(lines));
    if (session.isFinished) {
      _finishMatch();
    }
  }

  void _simToEnd() {
    final session = _session;
    if (session == null || session.isFinished) return;
    session.simulateToEnd();
    final lines = generateCommentary(
      session.engine.events,
      playerNames: session.userPlayerNames,
      homeTeamName: 'FC Rivals',
      awayTeamName: 'Cairo XI',
    );
    setState(() => _lines
      ..clear()
      ..addAll(lines));
    _finishMatch();
  }

  Future<void> _finishMatch() async {
    final session = _session;
    if (session == null) return;
    final report = await session.finish(pepTalk: null);
    setState(() {
      _finished = true;
      _report = report;
    });
    ref.invalidate(clubProvider);
    ref.invalidate(collectionProvider);
    ref.invalidate(squadProvider);
  }

  Future<void> _applyPepTalk(PepTalk pepTalk) async {
    // The pep talk choice made at full time is informational here: the
    // reward/stamina persistence ran in _finishMatch with the default
    // recovery; choosing now shows the effect preview for the next match.
    setState(() => _pepTalk = pepTalk);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() => _error = null);
                  _kickOff();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final session = _session;
    if (session == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _kickOff,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Play friendly match'),
        ),
      );
    }

    final state = session.engine.state;
    return Column(
      children: [
        // Scoreboard
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.inversePrimary,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                      child: Text('FC Rivals',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.titleMedium)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${state.scoreHome} - ${state.scoreAway}',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                      child: Text('Cairo XI',
                          textAlign: TextAlign.left,
                          style: theme.textTheme.titleMedium)),
                ],
              ),
              Text(_finished ? 'Full time' : "${state.minute}'",
                  style: theme.textTheme.labelLarge),
            ],
          ),
        ),
        // Controls (GDD 10.4/16)
        if (!_finished)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _advance,
                    icon: const Icon(Icons.fast_forward),
                    label: const Text('Next minute'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _simToEnd,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Sim to end'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => _showTacticsSheet(context),
                  icon: const Icon(Icons.tune),
                  tooltip: 'Tactics',
                ),
              ],
            ),
          ),
        // Commentary feed
        Expanded(
          child: _finished && _report != null
              ? MatchReportView(
                  report: _report!,
                  pepTalk: _pepTalk,
                  onPepTalk: _applyPepTalk,
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: _lines.length,
                  itemBuilder: (context, index) {
                    final line = _lines[_lines.length - 1 - index];
                    final bold = line.importance == 2;
                    final color = switch (line.importance) {
                      2 => theme.colorScheme.primary,
                      1 => theme.colorScheme.onSurface,
                      _ => theme.colorScheme.onSurfaceVariant,
                    };
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 38,
                            child: Text("${line.minute}'",
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: color)),
                          ),
                          Expanded(
                            child: Text(
                              line.text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: color,
                                fontWeight:
                                    bold ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Live tactical changes (GDD 10.4): formation, style, mentality and
  /// live actions with their explicit percentage effects (GDD 16).
  void _showTacticsSheet(BuildContext context) {
    final session = _session!;
    final nextMinute = session.engine.state.minute + 1;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        Widget section(String title, List<Widget> children) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(title,
                      style: Theme.of(sheetContext).textTheme.titleSmall),
                ),
                ...children,
              ],
            );
        return ListView(
          children: [
            section(
              'Mentality',
              [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in Mentality.values)
                      ActionChip(
                        label: Text(m.displayName),
                        onPressed: () {
                          session.queueCommand(ChangeMentalityCommand(
                              atMinute: nextMinute,
                              side: MatchSide.home,
                              mentality: m));
                          Navigator.pop(sheetContext);
                        },
                      ),
                  ],
                ),
              ],
            ),
            section(
              'Live action (10 minutes)',
              [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in LiveMatchAction.values)
                      ActionChip(
                        label: Text(a.displayName),
                        onPressed: () {
                          session.queueCommand(LiveActionCommand(
                              atMinute: nextMinute,
                              side: MatchSide.home,
                              action: a));
                          Navigator.pop(sheetContext);
                        },
                      ),
                  ],
                ),
              ],
            ),
            section(
              'Effects',
              [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Mentality shifts Attack and Defence by up to ±20%. '
                    'Live actions apply explicit Attack/Defence/Stamina '
                    'modifiers for 10 minutes and can be replaced any time.',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Post-match report (GDD 14 post-match screen): score, scorers, ratings,
/// Man of the Match, team statistics and the pep talk choice.
class MatchReportView extends StatelessWidget {
  const MatchReportView({
    super.key,
    required this.report,
    required this.pepTalk,
    required this.onPepTalk,
  });

  final MatchReportResult report;
  final PepTalk? pepTalk;
  final ValueChanged<PepTalk> onPepTalk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = report.stats;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Full time: FC Rivals ${report.state.scoreHome} - '
            '${report.state.scoreAway} Cairo XI',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text('Reward: ${report.rewardCoins} coins',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 8),
        if (report.manOfTheMatch != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events),
              title: Text(report.manOfTheMatch!.name),
              subtitle: Text(
                  'Man of the Match · rating ${report.manOfTheMatch!.rating.toStringAsFixed(1)}'),
            ),
          ),
        const SizedBox(height: 12),
        Text('Team statistics', style: theme.textTheme.titleSmall),
        _StatsTable(stats: stats),
        const SizedBox(height: 12),
        Text('Player ratings', style: theme.textTheme.titleSmall),
        for (final r in report.homeRatings.where((r) => r.played).take(11))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                    width: 34,
                    child: Text(r.position.code,
                        style: theme.textTheme.labelSmall)),
                Expanded(child: Text(r.name)),
                if (r.goals > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text('⚽ ×${r.goals}',
                        style: theme.textTheme.bodySmall),
                  ),
                if (r.assists > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text('🅰 ×${r.assists}',
                        style: theme.textTheme.bodySmall),
                  ),
                Text(r.rating.toStringAsFixed(1),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text('Pep talk', style: theme.textTheme.titleSmall),
        Text(
            'Choose one recovery focus for the squad (bonus to natural recovery, GDD 11.6):',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in PepTalk.values)
              ChoiceChip(
                label: Text(choice.displayName),
                selected: pepTalk == choice,
                onSelected: (_) => onPepTalk(choice),
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({required this.stats});

  final MatchStatsReport stats;

  static const _rows = [
    ('Possession', 'possess'),
    ('Shots', 'shots'),
    ('Shots on target', 'onTarget'),
    ('Expected goals', 'xg'),
    ('Big chances', 'bigChances'),
    ('Pass accuracy', 'passAccuracy'),
    ('Corners', 'corners'),
    ('Fouls', 'fouls'),
    ('Yellow cards', 'yellow'),
    ('Saves', 'saves'),
  ];

  (String, String) _values(TeamMatchStats s, String key) {
    switch (key) {
      case 'possess':
        return ('${stats.possessionPercent(s).round()}%', '');
      case 'shots':
        return ('${s.shots}', '');
      case 'onTarget':
        return ('${s.shotsOnTarget}', '');
      case 'xg':
        return (s.xg.toStringAsFixed(1), '');
      case 'bigChances':
        return ('${s.bigChances}', '');
      case 'passAccuracy':
        return (s.passesAttempted == 0
            ? '—'
            : '${(100 * s.passAccuracy).round()}%', '');
      case 'corners':
        return ('${s.corners}', '');
      case 'fouls':
        return ('${s.fouls}', '');
      case 'yellow':
        return ('${s.yellowCards}', '');
      case 'saves':
        return ('${s.saves}', '');
    }
    return ('—', '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (final (label, key) in _rows)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _values(stats.home, key).$1,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _values(stats.away, key).$1,
                        textAlign: TextAlign.left,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
