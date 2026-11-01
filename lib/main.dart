import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'core/domain/leagues.dart';
import 'core/domain/players.dart';
import 'features/economy/economy_engine.dart';
import 'features/player_database/player_database.dart';

void main() {
  runApp(const FcmRivalsApp());
}

class FcmRivalsApp extends StatelessWidget {
  const FcmRivalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCM Rivals',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B7A3B)),
        useMaterial3: true,
      ),
      home: const PlayerDatabaseScreen(),
    );
  }
}

/// Entry screen of the development build: loads the bundled player dataset,
/// imports it through the Player Database Engine and shows the top-rated
/// players. This proves the full asset → engine pipeline inside the running
/// app while the game UI is under construction.
class PlayerDatabaseScreen extends StatefulWidget {
  const PlayerDatabaseScreen({super.key});

  @override
  State<PlayerDatabaseScreen> createState() => _PlayerDatabaseScreenState();
}

class _PlayerDatabaseScreenState extends State<PlayerDatabaseScreen> {
  final PlayerDatabase _db = PlayerDatabase();
  static const EconomyEngine _economy = EconomyEngine();

  String? _error;
  bool _loading = true;
  List<BasePlayer> _top = const [];
  int _totalCount = 0;
  int _datasetVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadDatabase();
  }

  Future<void> _loadDatabase() async {
    setState(() => _loading = true);
    try {
      final jsonText =
          await rootBundle.loadString('assets/data/players_v1.json');
      final result = _db.importDatasetFromJson(jsonText);
      final top = _db.all.toList()
        ..sort((a, b) => b.baseStats.overall.compareTo(a.baseStats.overall));
      setState(() {
        _top = top.take(50).toList();
        _totalCount = result.added.length;
        _datasetVersion = _db.datasetVersion;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load player database: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: const Text('FCM Rivals — Player Database'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: theme.textTheme.bodyLarge),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _top.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildHeader(theme);
                    final player = _top[index - 1];
                    return _PlayerTile(
                      player: player,
                      sellPrice: _economy.sellPriceOf(player),
                    );
                  },
                ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final leagues = _top.map((p) => p.leagueCode).toSet();
    final leagueSample = leagues.take(6).map(leagueDisplayName).join(', ');
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Player Database v$_datasetVersion',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '$_totalCount real players imported from the bundled '
              'Transfermarkt-derived dataset — name, position, age, '
              'nationality, club and Market Value with stable ids.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text('Leagues in top 50: $leagueSample',
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player, required this.sellPrice});

  final BasePlayer player;
  final int sellPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = player.baseStats;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text('${stats.overall}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            )),
      ),
      title: Text(player.name),
      subtitle: Text(
        '${player.position.code} · ${player.age}y · ${player.nationality} · '
        '${player.club} · €${(player.marketValueEur / 1_000_000).toStringAsFixed(1)}M',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        'sell ${formatCoins(sellPrice)}',
        style: theme.textTheme.bodySmall,
      ),
      dense: true,
    );
  }
}
