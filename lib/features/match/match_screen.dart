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
  bool _usedAdBoost = false;
  String? _error;
  bool _halfTimeOffered = false;

  Future<void> _kickOff() async {
    try {
      final store = await ref.read(collectionStoreProvider.future);
      final random = ref.read(randomProvider);
      setState(() {
        _halfTimeOffered = false;
      });
      // Pre-match pep talk (GDD 15.1): one optional choice, ad-free.
      final talk = await _chooseTalk(
        title: 'Pre-match pep talk',
        subtitle:
            'One motivational choice before kick-off — effects last the '
            'whole match.',
        talks: preMatchPepTalks,
      );
      final session = await MatchSession.create(
        store: store,
        seed: random.nextInt(1 << 31),
        opponentName: 'Cairo XI',
        opponentAverageOverall: 68,
        preMatchTalk: talk,
      );
      setState(() {
        _session = session;
        _lines.clear();
        _finished = false;
        _report = null;
        _pepTalk = null;
        _usedAdBoost = false;
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
    if (events.isNotEmpty) {
      final lines = generateCommentary(
        events,
        playerNames: session.userPlayerNames,
        homeTeamName: 'FC Rivals',
        awayTeamName: 'Cairo XI',
      );
      setState(() => _lines.addAll(lines));
    }
    _maybeOfferHalfTimeTalk();
    if (session.isFinished) {
      _finishMatch();
    }
  }

  void _maybeOfferHalfTimeTalk() {
    final session = _session;
    if (session == null || _halfTimeOffered) return;
    final state = session.engine.state;
    // Offer once when the clock first reaches/reaches past half time.
    if (state.minute >= 45 && !state.isFinished) {
      _halfTimeOffered = true;
      _chooseHalfTimeTalk();
    }
  }

  Future<void> _chooseHalfTimeTalk() async {
    final session = _session;
    if (session == null) return;
    // Half-time pep talk (GDD 15.2): effects apply to the second half,
    // ad-free like every pep talk (FR-043).
    final talk = await _chooseTalk(
      title: 'Half-time pep talk',
      subtitle: 'One choice for the second half — applies from kick-off '
          'of the second half.',
      talks: halfTimePepTalks,
    );
    if (talk != null && session == _session && !session.isFinished) {
      session.queueHalfTimeTalk(talk);
    }
  }

  /// Shows the pep-talk chooser; returns null when skipped. Never gated
  /// by an ad (FR-043).
  Future<MatchPepTalk?> _chooseTalk({
    required String title,
    required String subtitle,
    required List<MatchPepTalk> talks,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet<MatchPepTalk>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            for (final talk in talks)
              ListTile(
                title: Text(talk.label),
                subtitle: Text('${talk.effectSummary}\n${talk.description}'),
                isThreeLine: true,
                onTap: () => Navigator.pop(sheetContext, talk),
              ),
            ListTile(
              title: Text('Skip',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
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

    // Post-match pep talk (GDD 15.3/11.6) or the ad-supported boosted
    // recovery (GDD 19.3) — mutually exclusive (GDD 19.4), chosen BEFORE
    // persistence runs so the choice is real this time.
    var usedAdBoost = false;
    PepTalk? talk;
    final choice = await _choosePostMatchRecovery();
    if (choice == null) {
      // nothing chosen: default recovery
    } else if (choice.boosted) {
      usedAdBoost = true;
    } else {
      talk = choice.pepTalk;
    }

    final report = await session.finish(
        pepTalk: talk, adBoostedRecovery: usedAdBoost);
    setState(() {
      _finished = true;
      _report = report;
      _pepTalk = talk;
      _usedAdBoost = usedAdBoost;
    });
    ref.invalidate(clubProvider);
    ref.invalidate(collectionProvider);
    ref.invalidate(squadProvider);
  }

  /// Chooses the post-match recovery path: a normal pep talk (free,
  /// FR-043) or the ad-boosted +15% recovery (GDD 19.3) when ads remain.
  Future<_RecoveryChoice?> _choosePostMatchRecovery() async {
    final theme = Theme.of(context);
    final session = _session;
    if (session == null) return null;
    final report = _report;
    final userAtHome = session.userSide == MatchSide.home;
    final userGoals =
        userAtHome ? session.engine.state.scoreHome : session.engine.state.scoreAway;
    final opponentGoals = userAtHome
        ? session.engine.state.scoreAway
        : session.engine.state.scoreHome;
    final won = userGoals > opponentGoals;

    return showModalBottomSheet<_RecoveryChoice>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Post-match recovery', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
                'Choose one recovery focus for the squad (bonus to natural '
                'recovery, GDD 11.6):',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final choice in PepTalk.values)
              ListTile(
                title: Text(choice.displayName),
                subtitle: Text(
                    '+${(choice.recoveryBonus * 100).round()}% natural recovery'),
                onTap: () => Navigator.pop(
                    sheetContext, _RecoveryChoice(pepTalk: choice)),
              ),
            if (!won)
              ListTile(
                leading: const Icon(Icons.movie),
                title: const Text('Watch ad: boosted recovery'),
                subtitle: const Text(
                    '+15% natural recovery for the whole squad (GDD 19.3)'),
                onTap: () =>
                    Navigator.pop(sheetContext, const _RecoveryChoice.boosted()),
              ),
            ListTile(
              title: Text('No pep talk',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              subtitle: report == null ? null : const Text('Default recovery'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyPepTalk(PepTalk pepTalk) async {
    // Informational selection on the report screen; the persistence
    // already ran with the choice made at full time.
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
                  adBoostedRecovery: _usedAdBoost,
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
    this.adBoostedRecovery = false,
  });

  final MatchReportResult report;
  final PepTalk? pepTalk;
  final ValueChanged<PepTalk> onPepTalk;

  /// Whether the ad-supported boosted recovery was applied (GDD 19.3).
  final bool adBoostedRecovery;

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
        if (adBoostedRecovery)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.movie, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      'Ad-boosted recovery applied: +15% natural recovery '
                      '(GDD 19.3)',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                ),
              ],
            ),
          )
        else
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

/// Post-match recovery choice: one free Pep Talk or the ad-boosted path.
class _RecoveryChoice {
  const _RecoveryChoice({this.pepTalk}) : boosted = false;
  const _RecoveryChoice.boosted() : pepTalk = null, boosted = true;

  final PepTalk? pepTalk;
  final bool boosted;
}
