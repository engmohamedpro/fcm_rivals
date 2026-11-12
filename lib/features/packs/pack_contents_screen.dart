/// FCM Rivals — pack contents screen.
///
/// The store's players icon button shows every player that pack can
/// draw, as a grid of mini cards (small player cards with name under them only)
/// sorted from highest rated down. Probability percentages replace the
/// app bar title (hiding rarities with no eligible players in the pool or while loading),
/// and filtering supports search, nationality, position, rarity, and sorting,
/// with correct left/right padding on the horizontal filter scroll.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/players.dart' show BasePlayer;
import '../../core/ui/country_flag.dart' show flagEmojiFor;
import '../../core/ui/fcm_motion.dart' show FcmPressable;
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart' show FcmMiniCard;
import '../../l10n/card_class_l10n.dart';
import '../../l10n/l10n_context.dart';
import '../collection/player_detail_sheet.dart' show showPlayerDetail;
import '../squad/squad_engine.dart' show PlayerCard;
import 'pack_engine.dart' show PackCategory, PackTier;
import 'pack_rarity.dart'
    show PackRarity, defaultPackOddsConfig;
import 'pack_tier_colors.dart';

enum _SortBy { ratingDesc, ratingAsc, valueDesc, nameAsc }

/// The contents list of one store pack.
class PackContentsScreen extends StatefulWidget {
  const PackContentsScreen({
    super.key,
    required this.title,
    required this.category,
    required this.scopeValue,
    required this.tier,
    required this.loadPlayers,
  });

  /// Full offer title, e.g. 'Legendary Global Pack'.
  final String title;

  final PackCategory category;
  final String? scopeValue;
  final PackTier tier;

  /// Loads the eligible pool, best-first (store-side ordering).
  final Future<List<BasePlayer>> Function() loadPlayers;

  @override
  State<PackContentsScreen> createState() => _PackContentsScreenState();
}

class _PackContentsScreenState extends State<PackContentsScreen> {
  List<BasePlayer>? _players;
  Object? _error;

  final TextEditingController _search = TextEditingController();
  String? _nationality;
  String? _positionCode;
  CardRarity? _rarityFilter;
  _SortBy _sortBy = _SortBy.ratingDesc;

  @override
  void initState() {
    super.initState();
    widget.loadPlayers().then(
      (players) {
        if (mounted) setState(() => _players = players);
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = e);
      },
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The pool narrowed by search, nationality, position, rarity, and sorted.
  List<BasePlayer> get _filtered {
    final players = _players;
    if (players == null) return const <BasePlayer>[];
    final query = _search.text.trim().toLowerCase();
    final nationality = _nationality;
    final position = _positionCode;
    final rarity = _rarityFilter;

    var list = players.where((p) {
      if (nationality != null && p.nationality != nationality) return false;
      if (position != null && p.position.code != position) return false;
      if (rarity != null) {
        final r = CardRarity.fromOverall(p.baseStats.overall);
        if (r != rarity) return false;
      }
      if (query.isNotEmpty && !p.name.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList(growable: false);

    list = List.of(list);
    switch (_sortBy) {
      case _SortBy.ratingDesc:
        list.sort((a, b) => b.baseStats.overall.compareTo(a.baseStats.overall));
        break;
      case _SortBy.ratingAsc:
        list.sort((a, b) => a.baseStats.overall.compareTo(b.baseStats.overall));
        break;
      case _SortBy.valueDesc:
        list.sort((a, b) => b.marketValueEur.compareTo(a.marketValueEur));
        break;
      case _SortBy.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = widget.tier.accent;
    return Scaffold(
      backgroundColor: FcmColors.night,
      appBar: AppBar(
        title: _OddsStrip(tier: widget.tier, players: _players),
        centerTitle: true,
        backgroundColor: FcmColors.surface,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _players == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: FcmPanel(
                accent: FcmColors.danger,
                child: Text('$_error', textAlign: TextAlign.center),
              ),
            )
          : Column(
              children: [
                _FiltersBar(
                  controller: _search,
                  nationalities: _nationalities(),
                  selectedNationality: _nationality,
                  selectedPosition: _positionCode,
                  selectedRarity: _rarityFilter,
                  sortBy: _sortBy,
                  onSearch: (_) => setState(() {}),
                  onNationality: (n) => setState(() => _nationality = n),
                  onPosition: (p) => setState(() => _positionCode = p),
                  onRarity: (r) => setState(() => _rarityFilter = r),
                  onSort: (s) => setState(() => _sortBy = s),
                ),
                Expanded(child: _buildGrid(tierColor)),
              ],
            ),
    );
  }

  /// Every nationality present in the pool, alphabetical.
  List<String> _nationalities() {
    final players = _players ?? const <BasePlayer>[];
    return players.map((p) => p.nationality).toSet().toList()..sort();
  }

  Widget _buildGrid(Color tierColor) {
    final players = _filtered;
    if (players.isEmpty) {
      return Center(
        child: Text(
          _players!.isEmpty
              ? 'No eligible players for this pack'
              : 'No players match your filters',
          style: const TextStyle(color: FcmColors.textDim),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 115,
        childAspectRatio: 0.60,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
      ),
      itemCount: players.length,
      itemBuilder: (context, i) {
        final p = players[i];
        final rarity = CardRarity.fromOverall(p.baseStats.overall);
        return FcmEntrance(
          index: math.min(i, 12),
          dx: 0,
          dy: 12,
          child: FcmPressable(
            onTap: () => showPlayerDetail(
              context,
              card: PlayerCard(
                ownedId: 0,
                base: p,
                upgradeLevel: 0,
              ),
            ),
            child: FcmMiniCard(
              overall: p.baseStats.overall,
              position: p.position.code,
              flag: flagEmojiFor(p.nationality),
              imageUrl: p.imageUrl,
              clubCrestUrl: p.clubCrestUrl,
              name: p.name,
              rarity: rarity,
              width: 92,
            ),
          ),
        );
      },
    );
  }
}

/// The pack's four-band rarity odds as the App Bar title: one
/// dim chip per non-zero band, strictly omitting rarities with zero eligible players in the pool.
class _OddsStrip extends StatelessWidget {
  const _OddsStrip({required this.tier, required this.players});

  final PackTier tier;
  final List<BasePlayer>? players;

  static List<(PackRarity, double)> _bandChips(PackTier tier, List<BasePlayer>? players) {
    if (players == null || players.isEmpty) return const [];
    final odds = defaultPackOddsConfig.oddsFor(tier);
    return [
      for (final (rarity, weight) in [
        (PackRarity.rare, odds.rare),
        (PackRarity.epic, odds.epic),
        (PackRarity.legendary, odds.legendary),
        (PackRarity.premium, odds.premium),
      ])
        if (weight > 0 &&
            players.any((p) => PackRarity.fromOverall(p.baseStats.overall) == rarity))
          (rarity, weight),
    ];
  }

  static String _rarityLabel(BuildContext context, PackRarity rarity) =>
      switch (rarity) {
        PackRarity.rare => l10nOf(context).packRarityRare,
        PackRarity.epic => l10nOf(context).packRarityEpic,
        PackRarity.legendary => l10nOf(context).packRarityLegendary,
        PackRarity.premium => l10nOf(context).packRarityPremium,
      };

  @override
  Widget build(BuildContext context) {
    final chips = _bandChips(tier, players);
    if (chips.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (i, band) in chips.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Text(
              '${_rarityLabel(context, band.$1)} ${(band.$2 * 100).round()}%',
              style: const TextStyle(
                color: FcmColors.goldSoft,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Comprehensive filter bar: search field + sort dropdown + nationality, position, and rarity filters.
class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.controller,
    required this.nationalities,
    required this.selectedNationality,
    required this.selectedPosition,
    required this.selectedRarity,
    required this.sortBy,
    required this.onSearch,
    required this.onNationality,
    required this.onPosition,
    required this.onRarity,
    required this.onSort,
  });

  final TextEditingController controller;
  final List<String> nationalities;
  final String? selectedNationality;
  final String? selectedPosition;
  final CardRarity? selectedRarity;
  final _SortBy sortBy;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onNationality;
  final ValueChanged<String?> onPosition;
  final ValueChanged<CardRarity?> onRarity;
  final ValueChanged<_SortBy> onSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onSearch,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search players',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: FcmColors.goldSoft.withValues(alpha: 0.7),
                      size: 19,
                    ),
                    filled: true,
                    fillColor: FcmColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: FcmColors.silver.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: FcmColors.gold.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildDropdown<_SortBy>(
                value: sortBy,
                items: const [
                  DropdownMenuItem(value: _SortBy.ratingDesc, child: Text('Top Rated')),
                  DropdownMenuItem(value: _SortBy.ratingAsc, child: Text('Lowest Rated')),
                  DropdownMenuItem(value: _SortBy.valueDesc, child: Text('Value')),
                  DropdownMenuItem(value: _SortBy.nameAsc, child: Text('Name A-Z')),
                ],
                onChanged: (v) => v != null ? onSort(v) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _buildDropdown<String?>(
                  value: selectedNationality,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Nationalities')),
                    for (final n in nationalities)
                      DropdownMenuItem(value: n, child: Text('${flagEmojiFor(n)} $n')),
                  ],
                  onChanged: onNationality,
                ),
                const SizedBox(width: 8),
                _buildDropdown<String?>(
                  value: selectedPosition,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Positions')),
                    for (final pos in ['ST', 'LW', 'RW', 'CAM', 'LM', 'RM', 'CM', 'CDM', 'CB', 'RB', 'LB', 'GK'])
                      DropdownMenuItem(value: pos, child: Text(pos)),
                  ],
                  onChanged: onPosition,
                ),
                const SizedBox(width: 8),
                _buildDropdown<CardRarity?>(
                  value: selectedRarity,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Rarities')),
                    for (final r in CardRarity.values)
                      DropdownMenuItem(value: r, child: Text(r.name.toUpperCase())),
                  ],
                  onChanged: onRarity,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: FcmColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: FcmColors.silver.withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: FcmColors.goldSoft.withValues(alpha: 0.7),
          ),
          dropdownColor: FcmColors.surface,
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
