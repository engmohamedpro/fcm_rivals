/// FCM Rivals — the daily rewards streak card, premium redesign
/// (owner request 2026-11-13: "total redesign — premium and
/// animations").
///
/// THE REDESIGN (research-grounded — Duolingo's streak-loop steps +
/// the 7-day-calendar pattern every top mobile game uses):
///
/// * THE FULL WEEK VISIBLE: all seven rungs of the current week
///   render as a horizontal track — each day a coin cell showing its
///   EXACT payout (full transparency, the FC Champions finding:
///   players target a rung when they can see what it pays), claimed
///   days lit gold with a tick, the weekly-bonus 7th day wearing a
///   star + a taller payout, today ringed in gold with a breathing
///   glow, future days dimmed.
/// * THE FIRE COUNTER: the streak's ordinal in a flame-gradient
///   badge — loss aversion made visible (the streak's engine).
/// * CLAIM = THE MOMENT: the button is the full-width gold gradient
///   with the amount ON it; the claim lands a coin-burst celebration
///   (the celebration painter shared with achievements), then the
///   card animates to the resting state.
/// * RESTING STATE: "claimed today" with tomorrow's rung highlighted
///   on the track — the next target, never a dead end.
///
/// The CONTRACTS stay (streak_card_test.dart locks them): the claim
/// pays exactly the engine-derived amount through the atomic store,
/// the card flips to the claimed state, a second tap is refused.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show clubProvider, databaseProvider;
import '../../core/ui/fcm_button.dart';
import '../../core/ui/fcm_chip.dart';
import '../../core/ui/fcm_coin.dart' show FcmCoinChip;
import '../../core/ui/fcm_motion.dart' show FitText;
import '../../core/ui/fcm_panel.dart';
import '../../core/ui/fcm_style.dart';
import '../../l10n/l10n_context.dart';
import '../achievements/achievements_claim_celebration.dart'
    show showAchievementClaimCelebration;
import '../achievements/achievement_catalog.dart' show BadgeMetal;
import 'streak_engine.dart';
import 'streak_providers.dart';
import 'streak_store.dart';

/// The rewards hub's streak section: claims today's reward when open,
/// shows the week's track and tomorrow's payout otherwise.
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(streakSnapshotProvider);
    return snapshot.maybeWhen(
      data: (s) => _StreakBody(snapshot: s!),
      orElse: () => const SizedBox(height: 140),
    );
  }
}

class _StreakBody extends ConsumerStatefulWidget {
  const _StreakBody({required this.snapshot});

  final StreakSnapshot snapshot;

  @override
  ConsumerState<_StreakBody> createState() => _StreakBodyState();
}

class _StreakBodyState extends ConsumerState<_StreakBody> {
  bool _claiming = false;

  Future<void> _claim() async {
    if (_claiming) return; // one in-flight claim per card
    setState(() => _claiming = true);
    try {
      final database = await ref.read(databaseProvider.future);
      final club = await (database.select(database.clubs)
            ..where((c) => c.isUser))
          .getSingle();
      // The atomic claim — the celebration fires only on a GRANT (a
      // refused double-tap celebrates nothing).
      final outcome = await StreakStore(database).claim(clubId: club.id);
      if (!mounted) return;
      if (outcome is StreakClaimGranted) {
        showAchievementClaimCelebration(
          context,
          metal: outcome.streakDay % 7 == 0
              ? BadgeMetal.legend
              : BadgeMetal.gold,
          title: l10nOf(context).streakTitle,
          coins: outcome.rewardCoins,
        );
      }
      // Refresh the card AND every coin-reading surface.
      ref.invalidate(streakSnapshotProvider);
      ref.invalidate(clubProvider);
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final s = ref.watch(streakSnapshotProvider).valueOrNull ?? widget.snapshot;
    final claimedToday = s.claimedToday;
    final currentDay = claimedToday
        ? s.state.lastStreakDay
        : s.nextStreakDay;

    return FcmPanel(
      accent: claimedToday ? FcmColors.bronze : FcmColors.gold,
      glow: !claimedToday,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The header: the flame badge + the title + the ordinal.
          Row(
            children: [
              const _FlameBadge(),
              const SizedBox(width: 10),
              Expanded(
                child: FitText(
                  l10n.streakTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              // The run's ordinal — the number the climb is measured
              // by, the loss-aversion counter.
              FcmPill(
                l10n.streakDayCount(currentDay),
                color: FcmColors.gold,
                filled: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // The week's track: seven rungs, each with its payout.
          _WeekTrack(
            currentDay: currentDay,
            claimedToday: claimedToday,
          ),
          const SizedBox(height: 12),
          if (claimedToday) ...[
            // Claimed: the resting state — tomorrow's rung is the
            // "keep going" hook, the reset warning the one rule that
            // must never be forgotten.
            Text(
              l10n.streakClaimedToday,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FcmColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.streakTomorrowPays(s.tomorrowRewardCoins),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FcmColors.goldSoft,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else ...[
            // Open: the claim button pays exactly what the engine
            // derived — the label carries the amount.
            FcmButton(
              label: l10n.streakClaimAction(s.nextRewardCoins),
              icon: Icons.redeem_rounded,
              loading: _claiming,
              onPressed: _claim,
              compact: true,
            ),
            if (s.missedDay) ...[
              const SizedBox(height: 8),
              Text(
                l10n.streakBrokenNotice,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FcmColors.danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Text(
            l10n.streakWeeklyBonus,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FcmColors.textDim,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!claimedToday) ...[
            const SizedBox(height: 4),
            Text(
              l10n.streakResetWarning,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: FcmColors.textDim,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The streak's flame badge: a hand-painted two-tone flame in a gold
/// ring — the loss-aversion counter's identity mark.
class _FlameBadge extends StatelessWidget {
  const _FlameBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: CustomPaint(painter: _FlamePainter()),
    );
  }
}

class _FlamePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // The gold ring.
    canvas.drawCircle(
      Offset(cx, h / 2),
      w * 0.46,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = FcmColors.gold.withValues(alpha: 0.75),
    );

    // The outer flame: a teardrop with a licking tip.
    final outer = Path()
      ..moveTo(cx, h * 0.10)
      ..quadraticBezierTo(w * 0.88, h * 0.42, w * 0.78, h * 0.62)
      ..quadraticBezierTo(w * 0.68, h * 0.86, cx, h * 0.92)
      ..quadraticBezierTo(w * 0.32, h * 0.86, w * 0.22, h * 0.62)
      ..quadraticBezierTo(w * 0.12, h * 0.42, cx, h * 0.10)
      ..close();
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [FcmColors.goldSoft, FcmColors.gold, FcmColors.goldDeep],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // The inner flame: a hotter core, ember-to-gold.
    final inner = Path()
      ..moveTo(cx, h * 0.34)
      ..quadraticBezierTo(w * 0.66, h * 0.58, cx, h * 0.78)
      ..quadraticBezierTo(w * 0.34, h * 0.58, cx, h * 0.34)
      ..close();
    canvas.drawPath(
      inner,
      Paint()..color = FcmColors.goldSoft.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_FlamePainter old) => false;
}

/// The week's track: the seven rungs of the CURRENT week — each a
/// coin cell carrying its exact payout, claimed rungs lit, today
/// ringed, the 7th wearing the bonus star. The rungs beyond the
/// current day preview their payouts (target visibility); days of the
/// PREVIOUS completed weeks collapse into a "+N" lead-in cell.
class _WeekTrack extends StatelessWidget {
  const _WeekTrack({required this.currentDay, required this.claimedToday});

  /// The streak ordinal TODAY (claimed or claimable).
  final int currentDay;

  final bool claimedToday;

  @override
  Widget build(BuildContext context) {
    // The week's 1..7 rungs map onto the climb's modulo position;
    // day 7 of week 1 is ordinal 7, day 1 of week 2 is ordinal 8.
    final weekPos = ((currentDay - 1) % 7) + 1; // 1..7
    final weekStart = currentDay - weekPos + 1; // the ordinal of rung 1
    final engine = const StreakEngine();

    return Row(
      children: [
        // The lead-in: previous completed weeks collapsed into one
        // cell (only when the climb passed a full week).
        if (weekStart > 1) ...[
          _CollapsedWeeksCell(weeks: (weekStart - 1) ~/ 7),
          const SizedBox(width: 5),
        ],
        for (var rung = 1; rung <= 7; rung++) ...[
          if (rung > 1) const SizedBox(width: 5),
          Expanded(
            child: _DayCell(
              day: weekStart + rung - 1,
              reward: engine.rewardForDay(weekStart + rung - 1),
              claimed: weekStart + rung - 1 < currentDay ||
                  (weekStart + rung - 1 == currentDay && claimedToday),
              isToday: rung == weekPos,
            ),
          ),
        ],
      ],
    );
  }
}

/// One rung of the week: a vertical coin cell — the day's ordinal
/// small at the top, the coin face centre, the payout below. Claimed
/// rungs go full gold with a tick overlay; today wears a gold ring
/// and (unclaimed) a breathing glow; future rungs stay dim. The 7th
/// rung's payout wears the bonus star.
class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.day,
    required this.reward,
    required this.claimed,
    required this.isToday,
  });

  final int day;
  final int reward;
  final bool claimed;
  final bool isToday;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController? _breathe = widget.isToday && !widget.claimed
      ? (AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2000),
        )..repeat(reverse: true))
      : null;

  @override
  void dispose() {
    _breathe?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bonus = widget.day % 7 == 0;
    final glow = _breathe == null ? 0.0 : 0.16 + 0.16 * _breathe.value;
    return AnimatedBuilder(
      animation: _breathe ?? const AlwaysStoppedAnimation(0.0),
      builder: (context, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          height: 62,
          decoration: BoxDecoration(
            gradient: widget.claimed ? FcmColors.goldGradient : null,
            color: widget.claimed
                ? null
                : FcmColors.surfaceHigh.withValues(
                    alpha: widget.isToday ? 0.95 : 0.75,
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isToday
                  ? FcmColors.gold
                  : (widget.claimed
                        ? FcmColors.goldSoft.withValues(alpha: 0.5)
                        : FcmColors.bronze.withValues(alpha: 0.30)),
              width: widget.isToday ? 1.6 : 1,
            ),
            boxShadow: [
              if (glow > 0)
                BoxShadow(
                  color: FcmColors.gold.withValues(alpha: glow),
                  blurRadius: 10,
                ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The coin face.
                  _CoinFace(
                    size: widget.claimed ? 17.0 : 15.0,
                    dim: !widget.claimed && !widget.isToday,
                  ),
                  const SizedBox(height: 3),
                  // The payout — the cell's promise.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        FcmCoinChip.compact(widget.reward),
                        maxLines: 1,
                        style: TextStyle(
                          color: widget.claimed
                              ? FcmColors.ink
                              : (widget.isToday
                                    ? FcmColors.goldSoft
                                    : FcmColors.textDim),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // The ordinal, tucked in the top corner.
              Positioned(
                top: 3,
                start: 4,
                child: Text(
                  '${widget.day}',
                  style: TextStyle(
                    color: widget.claimed
                        ? FcmColors.ink.withValues(alpha: 0.7)
                        : FcmColors.textDim.withValues(alpha: 0.8),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
              // The bonus star on the 7th rung.
              if (bonus)
                Positioned(
                  top: 2,
                  end: 3,
                  child: Icon(
                    Icons.stars_rounded,
                    size: 12,
                    color: widget.claimed
                        ? FcmColors.ink
                        : FcmColors.gold.withValues(alpha: 0.9),
                  ),
                ),
              // The claimed tick.
              if (widget.claimed)
                Positioned(
                  bottom: 2,
                  right: 3,
                  child: Icon(
                    Icons.check_rounded,
                    size: 11,
                    color: FcmColors.ink.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

}

/// The collapsed previous weeks: one dim cell carrying the count —
/// the climb's history without stealing the week's width.
class _CollapsedWeeksCell extends StatelessWidget {
  const _CollapsedWeeksCell({required this.weeks});

  final int weeks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 62,
      decoration: BoxDecoration(
        color: FcmColors.surfaceHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: FcmColors.bronze.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history_rounded,
            size: 13,
            color: FcmColors.textDim,
          ),
          const SizedBox(height: 2),
          Text(
            '+$weeks',
            style: const TextStyle(
              color: FcmColors.textDim,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A painter-drawn coin: the house gold disc with a ringed face —
/// the same craft as the celebration rain, sized for the cell.
class _CoinFace extends StatelessWidget {
  const _CoinFace({required this.size, this.dim = false});

  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.5 : 1.0,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _CoinFacePainter()),
      ),
    );
  }
}

class _CoinFacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, w / 2);
    final r = w / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = FcmColors.goldGradient.createShader(
          Rect.fromCircle(center: c, radius: r),
        ),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.09
        ..color = FcmColors.goldSoft.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      c,
      r * 0.52,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.07
        ..color = FcmColors.ink.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_CoinFacePainter old) => false;
}
