/// FCM Rivals — pack contents screen.
///
/// The store's players icon button shows every player that pack can
/// draw, as one mini card per player (no rank numbers) — sorted from the
/// highest rated down so the odds ladder reads at a glance. A search
/// field filters by name and a nationality dropdown narrows the pool, so
/// the scope's full depth is explorable. The screen is a read-only
/// showcase; buying stays on the store.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/players.dart' show BasePlayer;
import '../../core/ui/country_flag.dart' show flagEmojiFor;
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart' show FcmMiniCard;
import '../../l10n/card_class_l10n.dart';
import '../../l10n/l10n_context.dart';
import 'pack_engine.dart' show PackCategory, PackTier;
import 'pack_rarity.dart'
    show PackRarity, defaultPackOddsConfig;
import 'pack_tier_colors.dart';

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

  /// The pool narrowed by the current search text and nationality.
  List<BasePlayer> get _filtered {
    final players = _players;
    if (players == null) return const <BasePlayer>[];
    final query = _search.text.trim().toLowerCase();
    final nationality = _nationality;
    return players
        .where((p) {
          if (nationality != null && p.nationality != nationality) return false;
          if (query.isNotEmpty && !p.name.toLowerCase().contains(query)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = widget.tier.accent;
    return Scaffold(
      backgroundColor: FcmColors.night,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
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
                // The four-band odds sheet (T-0059, moved here by
                // T-0087): the tier's rarity table (PackOddsConfig) as
                // one chip per band — each label+percent is a single
                // atomic Text, no sentence interpolation, so RTL
                // reorders the chips freely and localized labels render
                // in both directions. Zero-weight bands (premium
                // outside the Legendary pack) render nothing, so the
                // strip shows exactly what the pack can roll. Visible
                // on open, above the filters and the list.
                _OddsStrip(tier: widget.tier),
                _FiltersBar(
                  controller: _search,
                  nationalities: _nationalities(),
                  selected: _nationality,
                  onSearch: (_) => setState(() {}),
                  onNationality: (n) =>
                      setState(() => _nationality = n ?? _nationality),
                ),
                Expanded(child: _buildList(tierColor)),
              ],
            ),
    );
  }

  /// Every nationality present in the pool, alphabetical.
  List<String> _nationalities() {
    final players = _players ?? const <BasePlayer>[];
    return players.map((p) => p.nationality).toSet().toList()..sort();
  }

  Widget _buildList(Color tierColor) {
    final players = _filtered;
    if (players.isEmpty) {
      return Center(
        child: Text(
          _players!.isEmpty
              ? 'No eligible players for this pack'
              : 'No players match your search',
          style: const TextStyle(color: FcmColors.textDim),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      itemCount: players.length,
      itemBuilder: (context, i) {
        final p = players[i];
        final rarity = CardRarity.fromOverall(p.baseStats.overall);
        final cardClass = CardClass.fromOverall(p.baseStats.overall);
        return FcmEntrance(
          index: math.min(i, 12),
          dx: 0,
          dy: 12,
          child: _PlayerRow(
            player: p,
            rarity: rarity,
            cardClass: cardClass,
            tierColor: tierColor,
          ),
        );
      },
    );
  }
}

/// The pack's four-band rarity odds as a header strip (T-0087): one
/// dim chip per non-zero band, in [PackRarity] order. The sheet has
/// room, so the chips read at ~11px — bigger than the store cell's old
/// 9px, same dim-text look.
class _OddsStrip extends StatelessWidget {
  const _OddsStrip({required this.tier});

  final PackTier tier;

  /// The tier's rarity table reduced to the chips rendered, in
  /// [PackRarity] order, zero-weight bands dropped.
  static List<(PackRarity, double)> _bandChips(PackTier tier) {
    final odds = defaultPackOddsConfig.oddsFor(tier);
    return [
      for (final (rarity, weight) in [
        (PackRarity.rare, odds.rare),
        (PackRarity.epic, odds.epic),
        (PackRarity.legendary, odds.legendary),
        (PackRarity.premium, odds.premium),
      ])
        if (weight > 0) (rarity, weight),
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
    return SizedBox(
      height: 22,
      child: Center(
        child: Wrap(
          spacing: 10,
          runSpacing: 2,
          alignment: WrapAlignment.center,
          children: [
            for (final (rarity, weight) in _bandChips(tier))
              Text(
                '${_rarityLabel(context, rarity)} '
                '${(weight * 100).round()}%',
                style: const TextStyle(
                  color: FcmColors.textDim,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Search field + nationality filter above the list. The dropdown offers
/// every nationality in the pool plus an ALL reset entry.
class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.controller,
    required this.nationalities,
    required this.selected,
    required this.onSearch,
    required this.onNationality,
  });

  final TextEditingController controller;
  final List<String> nationalities;
  final String? selected;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onNationality;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
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
          // Nationality dropdown: ALL resets, then every nationality in
          // the pool with its flag.
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: FcmColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FcmColors.silver.withValues(alpha: 0.3),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selected,
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: FcmColors.goldSoft.withValues(alpha: 0.7),
                ),
                dropdownColor: FcmColors.surface,
                borderRadius: BorderRadius.circular(12),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'All nationalities',
                      style: TextStyle(
                        color: selected == null
                            ? Colors.white
                            : FcmColors.textDim,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final n in nationalities)
                    DropdownMenuItem<String?>(
                      value: n,
                      child: Text(
                        '${flagEmojiFor(n)} $n',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected == n
                              ? Colors.white
                              : FcmColors.textDim,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
                onChanged: onNationality,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One player of the pool: the mini card on the left (the same card as
/// the collection and squad), then name, position and nationality. No
/// order numbers — the pool is a showcase, not a ranking.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.rarity,
    required this.cardClass,
    required this.tierColor,
  });

  final BasePlayer player;
  final CardRarity rarity;

  /// The premium class axis (T-0049): a 90+ row shows the localized
  /// red-tier label in the rarity tag.
  final CardClass cardClass;
  final Color tierColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FcmPanel(
        accent: rarity.accent,
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          children: [
            SizedBox(
              width: 68,
              child: FcmMiniCard(
                overall: player.baseStats.overall,
                position: player.position.code,
                flag: flagEmojiFor(player.nationality),
                name: player.name.split(' ').last,
                rarity: rarity,
                width: 56,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${flagEmojiFor(player.nationality)} ${player.nationality}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FcmColors.textDim,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Rarity tag: the rarity language shared with the store —
            // a 90+ premium shows the localized red-tier label instead.
            FcmPill(
              l10nOf(context).cardClassLabel(cardClass, rarity),
              color: cardClass == CardClass.premium
                  ? cardClass.accent
                  : tierColor,
              filled: false,
            ),
          ],
        ),
      ),
    );
  }
}
