/// FCM Rivals — the in-match tactics panel (GDD 10.4 / 16).
///
/// Lives under the commentary on the live match screen so the manager
/// can react to what the momentum meter and the feed are saying WITHOUT
/// leaving the match or pausing it:
///
/// - TEAM MENTALITY: a seven-step ladder from very defensive to very
///   attacking, tinted cool-to-hot. One tap queues the change;
/// - LIVE ORDERS: the five timed match actions as one-tap tiles. The
///   running order is highlighted with its minutes left;
/// - the full editor (formation, style, substitutions) is one tap away.
///
/// A change is a queued command like any other (GDD 10.4: changes affect
/// FUTURE events only) — it lands at the next minute boundary, which is
/// at most one match minute (under 1.5 real seconds) away. Until it
/// lands the panel shows the new choice with a "queued" note, so a tap
/// always answers back instantly. The match clock never stops.
///
/// The header row stays visible when the body is collapsed and carries
/// the current mentality and order, so the panel costs one thin row on
/// a short phone.
library;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_motion.dart';
import '../../core/ui/fcm_panel.dart';
import '../../core/ui/fcm_style.dart';
import 'match_engine.dart';
import 'match_session.dart';
import 'team_tactics.dart';

/// Short codes shown inside the selected ladder step.
const _mentalityCodes = <Mentality, String>{
  Mentality.veryDefensive: 'V.DEF',
  Mentality.defensive: 'DEF',
  Mentality.cautious: 'CAUT',
  Mentality.balanced: 'BAL',
  Mentality.positive: 'POS',
  Mentality.attacking: 'ATT',
  Mentality.veryAttacking: 'V.ATT',
};

/// Tile label + icon of each live order.
const _orderTiles = <LiveMatchAction, ({String label, IconData icon})>{
  LiveMatchAction.pushForward: (
    label: 'Push',
    icon: Icons.north_east_rounded,
  ),
  LiveMatchAction.defendDeep: (label: 'Defend', icon: Icons.shield_rounded),
  LiveMatchAction.pressMore: (label: 'Press', icon: Icons.bolt_rounded),
  LiveMatchAction.stayCalm: (label: 'Calm', icon: Icons.spa_rounded),
  LiveMatchAction.playMoreDirect: (
    label: 'Direct',
    icon: Icons.arrow_upward_rounded,
  ),
};

/// Cool blue at the defensive end → gold at balanced → red at the
/// attacking end.
Color _mentalityColor(Mentality m) {
  final t = m.index / (Mentality.values.length - 1);
  const cool = Color(0xFF6FA8DC);
  return t < 0.5
      ? Color.lerp(cool, FcmColors.gold, t * 2)!
      : Color.lerp(FcmColors.gold, FcmColors.danger, (t - 0.5) * 2)!;
}

/// "Attack +15% · Defence -10% · Stamina use +5%" for a live order.
String _orderEffect(ActionModifiers m) {
  final parts = <String>[];
  void describe(String name, double multiplier) {
    final percent = ((multiplier - 1) * 100).round();
    if (percent == 0) return;
    parts.add('$name ${percent > 0 ? '+' : ''}$percent%');
  }

  describe('Attack', m.attack);
  describe('Defence', m.defence);
  return parts.isEmpty ? 'No modifiers' : parts.join(' · ');
}

/// The live tactics panel. See the library doc.
class LiveTacticsPanel extends StatefulWidget {
  const LiveTacticsPanel({
    super.key,
    required this.session,
    required this.minute,
    required this.enabled,
    required this.onOpenEditor,
  });

  final MatchSession session;

  /// The match minute shown — a change of minute means the queued
  /// commands were applied, so the "queued" markers clear.
  final int minute;

  /// False while the match cannot take orders (finished, card up).
  final bool enabled;

  /// Opens the full tactics editor (formation, style, substitutions).
  final VoidCallback onOpenEditor;

  @override
  State<LiveTacticsPanel> createState() => _LiveTacticsPanelState();
}

class _LiveTacticsPanelState extends State<LiveTacticsPanel> {
  bool _expanded = true;
  Mentality? _pendingMentality;
  LiveMatchAction? _pendingAction;

  @override
  void didUpdateWidget(LiveTacticsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minute != widget.minute) {
      // The minute boundary applied everything queued before it.
      _pendingMentality = null;
      _pendingAction = null;
    }
  }

  bool get _canOrder => widget.enabled && !widget.session.isFinished;

  void _setMentality(Mentality next, Mentality shown) {
    if (!_canOrder || next == shown) return;
    final session = widget.session;
    session.queueCommand(
      ChangeMentalityCommand(
        atMinute: session.engine.state.minute + 1,
        side: session.userSide,
        mentality: next,
      ),
    );
    setState(() => _pendingMentality = next);
  }

  void _orderAction(LiveMatchAction next, LiveMatchAction? shown) {
    if (!_canOrder || next == shown) return;
    final session = widget.session;
    session.queueCommand(
      LiveActionCommand(
        atMinute: session.engine.state.minute + 1,
        side: session.userSide,
        action: next,
      ),
    );
    setState(() => _pendingAction = next);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final engine = session.engine;
    final side = session.userSide;

    final engineMentality = engine.mentalityOf(side);
    final mentality = _pendingMentality ?? engineMentality;
    final mentalityQueued =
        _pendingMentality != null && _pendingMentality != engineMentality;

    final engineAction = engine.activeActionOf(side);
    final action = _pendingAction ?? engineAction;
    final actionQueued =
        _pendingAction != null && _pendingAction != engineAction;
    final minutesLeft = engine.actionMinutesLeftOf(side);
    final nextMinute = engine.state.minute + 1;
    final duration = engine.config.liveActionDuration;

    final accent = _mentalityColor(mentality);

    return Opacity(
      opacity: widget.enabled ? 1 : 0.55,
      child: FcmPanel(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        accent: FcmColors.bronze,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: FcmPressable(
                    scale: 0.99,
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.psychology_rounded,
                          size: 18,
                          color: FcmColors.gold,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'LIVE TACTICS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _SummaryPill(
                                  color: accent,
                                  text: mentality.displayName,
                                ),
                                if (action != null)
                                  _SummaryPill(
                                    color: FcmColors.gold,
                                    icon: _orderTiles[action]!.icon,
                                    text: actionQueued
                                        ? action.displayName
                                        : "${action.displayName} · $minutesLeft'",
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          color: FcmColors.textDim,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                FcmPressable(
                  onTap: widget.onOpenEditor,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_rounded,
                          size: 15,
                          color: FcmColors.textDim,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Formation & subs',
                          style: TextStyle(
                            color: FcmColors.textDim,
                            fontSize: 10.5,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionLabel(
                            title: 'TEAM MENTALITY',
                            trailing: mentalityQueued
                                ? "Queued · applies from $nextMinute'"
                                : mentality.effectSummary,
                            queued: mentalityQueued,
                          ),
                          const SizedBox(height: 5),
                          _MentalityLadder(
                            selected: mentality,
                            onSelect: (m) => _setMentality(m, mentality),
                          ),
                          const SizedBox(height: 10),
                          _SectionLabel(
                            title: 'LIVE ORDERS',
                            trailing: actionQueued
                                ? "Queued · applies from $nextMinute'"
                                : action != null
                                ? '${action.displayName}: '
                                      '${_orderEffect(action.modifiers)}'
                                : "Each order lasts $duration min · tap one",
                            queued: actionQueued,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              for (final a in LiveMatchAction.values) ...[
                                if (a != LiveMatchAction.values.first)
                                  const SizedBox(width: 6),
                                Expanded(
                                  child: _OrderTile(
                                    label: _orderTiles[a]!.label,
                                    icon: _orderTiles[a]!.icon,
                                    active: a == action,
                                    queued: a == action && actionQueued,
                                    onTap: () => _orderAction(a, action),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded pill in the header summarising the current setting.
class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.color, required this.text, this.icon});

  final Color color;
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small caps section title with its effect / status line at the far
/// edge.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.trailing,
    required this.queued,
  });

  final String title;
  final String trailing;
  final bool queued;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: FcmColors.textDim,
            fontSize: 9.5,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FitText(
            trailing,
            align: AlignmentDirectional.centerEnd.resolve(
              Directionality.of(context),
            ),
            style: TextStyle(
              color: queued ? FcmColors.gold : FcmColors.silver,
              fontSize: 10.5,
              height: 1,
              fontWeight: queued ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// The seven-step mentality ladder: DEF … ATT, cool to hot. The selected
/// step fills with its colour and shows its short code.
class _MentalityLadder extends StatelessWidget {
  const _MentalityLadder({required this.selected, required this.onSelect});

  final Mentality selected;
  final ValueChanged<Mentality> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _EndCaption('DEF'),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: [
              for (final m in Mentality.values) ...[
                if (m != Mentality.values.first) const SizedBox(width: 4),
                Expanded(
                  child: FcmPressable(
                    scale: 0.94,
                    onTap: () => onSelect(m),
                    child: _LadderStep(
                      color: _mentalityColor(m),
                      selected: m == selected,
                      code: _mentalityCodes[m]!,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 6),
        const _EndCaption('ATT'),
      ],
    );
  }
}

class _EndCaption extends StatelessWidget {
  const _EndCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: FcmColors.textDim.withValues(alpha: 0.8),
        fontSize: 9,
        height: 1,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _LadderStep extends StatelessWidget {
  const _LadderStep({
    required this.color,
    required this.selected,
    required this.code,
  });

  final Color color;
  final bool selected;
  final String code;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: selected ? color : color.withValues(alpha: 0.14),
        border: Border.all(
          color: selected
              ? Colors.white.withValues(alpha: 0.85)
              : color.withValues(alpha: 0.4),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: [
          if (selected)
            BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10),
        ],
      ),
      child: selected
          ? FitText(
              code,
              align: Alignment.center,
              style: const TextStyle(
                color: FcmColors.night,
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

/// One live order tile: icon over a short label; the running order is
/// gold-filled, and a queued one gets a brighter border until it lands.
class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.label,
    required this.icon,
    required this.active,
    required this.queued,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool queued;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? FcmColors.night : Colors.white;
    return FcmPressable(
      scale: 0.95,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [FcmColors.goldSoft, FcmColors.gold],
                )
              : null,
          color: active ? null : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: active
                ? Colors.white.withValues(alpha: queued ? 0.9 : 0.55)
                : Colors.white.withValues(alpha: 0.16),
          ),
          boxShadow: [
            if (active)
              BoxShadow(
                color: FcmColors.gold.withValues(alpha: 0.4),
                blurRadius: 10,
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(height: 3),
            FitText(
              label,
              align: Alignment.center,
              style: TextStyle(
                color: fg,
                fontSize: 10.5,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
