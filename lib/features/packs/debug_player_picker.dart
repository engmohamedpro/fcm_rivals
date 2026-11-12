/// FCM Rivals — DEBUG-ONLY pack draw picker (debug tool request
/// 2026-11-12). THIS FILE AND ITS CALL SITE ARE REMOVED BEFORE
/// RELEASE — search `debugDrawOverride` when shipping.
///
/// What it does: a searchable picker over the FULL pack pool (~40-51k
/// dataset players). The chosen player is planted into
/// [CollectionStore.debugDrawOverride], so the NEXT pack opened —
/// bought, owned or chained through OPEN ANOTHER — reveals exactly
/// that player instead of rolling the two-stage odds. Everything else
/// stays real: the pack is consumed, the player is persisted, the
/// reveal animation runs with the player's OWN rarity band.
///
/// Why a custom sheet and not [FcmDropdown]: the pool is far too large
/// for a plain items list — this sheet filters as you type (name,
/// position code, nationality or club), caps the rendered rows at 24
/// hits, and offers a RANDOM CLEAR to return to real rolls.
///
/// The gate is [kDebugMode]: in release/profile builds the widget
/// renders nothing (SizedBox.shrink) and the whole file is dead code
/// tree-shaken by the compiler.
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../core/domain/players.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../collection/collection_store.dart';

/// The debug picker row: label + the field. Debug builds only.
class DebugPlayerPicker extends StatefulWidget {
  const DebugPlayerPicker({super.key, required this.store});

  /// The store whose [CollectionStore.debugDrawOverride] is planted.
  final CollectionStore store;

  @override
  State<DebugPlayerPicker> createState() => _DebugPlayerPickerState();
}

class _DebugPlayerPickerState extends State<DebugPlayerPicker> {
  BasePlayer? _picked;

  /// The store's pool, loaded once on first open (the registry is warm
  /// by then — the store screen opened it already).
  List<BasePlayer>? _pool;

  Future<List<BasePlayer>> _loadPool() async {
    // Same lazy warm-up the open path pays; on a warm registry this is
    // an in-memory list copy.
    await widget.store.debugWarmRegistry();
    return widget.store.debugPackPool();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Row(
        children: [
          const Icon(Icons.bug_report, color: FcmColors.goldSoft, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: FcmPressable(
              onTap: _openPicker,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: FcmColors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: FcmColors.bronze.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _picked == null
                            ? 'DEBUG draw: real rolls'
                            : 'DEBUG draw: ${_picked!.name} '
                                '(${_picked!.position.code} '
                                '${_picked!.baseStats.overall})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FcmColors.goldSoft,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_picked != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _picked = null;
                          widget.store.debugDrawOverride = null;
                        }),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.close,
                            color: FcmColors.goldSoft,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPicker() async {
    fcmTick();
    final pool = _pool ??= await _loadPool();
    if (!mounted) return;
    final picked = await showModalBottomSheet<BasePlayer>(
      context: context,
      backgroundColor: FcmColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DebugPlayerSheet(pool: pool, selected: _picked),
    );
    if (picked == null) return;
    setState(() => _picked = picked);
    widget.store.debugDrawOverride = picked;
  }
}

/// The searchable sheet: TextField on top, capped result list below.
class _DebugPlayerSheet extends StatefulWidget {
  const _DebugPlayerSheet({required this.pool, this.selected});

  final List<BasePlayer> pool;
  final BasePlayer? selected;

  @override
  State<_DebugPlayerSheet> createState() => _DebugPlayerSheetState();
}

class _DebugPlayerSheetState extends State<_DebugPlayerSheet> {
  static const _maxRows = 24;
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    // Sorted by overall DESC so the marquee names surface first when
    // the query is broad; exact-ish matches do not need a re-rank with
    // 24 visible rows and instant filtering.
    final hits = (q.isEmpty ? widget.pool : _filter(widget.pool, q))
        .where((p) => p.baseStats.overall >= 0)
        .toList()
      ..sort((a, b) => b.baseStats.overall.compareTo(a.baseStats.overall));
    final capped = hits.take(_maxRows).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              decoration: BoxDecoration(
                color: FcmColors.bronze.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search name / position / nation / club…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${hits.length} match${hits.length == 1 ? '' : 'es'}'
                      '${hits.length > _maxRows ? ' — showing first $_maxRows' : ''}',
                      style: const TextStyle(
                        color: FcmColors.goldSoft,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: capped.length,
                itemBuilder: (_, i) {
                  final p = capped[i];
                  final isSel = widget.selected?.playerId == p.playerId;
                  return ListTile(
                    dense: true,
                    selected: isSel,
                    leading: Text(
                      '${p.baseStats.overall}',
                      style: const TextStyle(
                        color: FcmColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    title: Text(
                      p.isIcon ? '${p.name} ★' : p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      '${p.position.code} · ${p.nationality}'
                      '${p.clubName.isEmpty ? '' : ' · ${p.clubName}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: isSel
                        ? const Icon(Icons.check, size: 18, color: FcmColors.gold)
                        : null,
                    onTap: () => Navigator.of(context).pop(p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Substring match over name, position code, nationality and club.
  static List<BasePlayer> _filter(List<BasePlayer> pool, String q) {
    return pool.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.position.code.toLowerCase() == q ||
          p.nationality.toLowerCase().contains(q) ||
          p.clubName.toLowerCase().contains(q);
    }).toList();
  }
}
