/// FCM Rivals — the daily rewards streak card (the profile's claim
/// surface).
///
/// One compact panel: the run's day counter with the last seven days
/// as pips (claimed days filled, the weekly-bonus day marked), the
/// claim button when today is still open, or the "come back tomorrow"
/// state once claimed — plus the one-line warning that a missed day
/// restarts the climb at day 1. The claim itself goes through the
/// store's atomic transaction; the card only reads the snapshot and
/// refreshes after the outcome.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show clubProvider, databaseProvider;
import '../../core/ui/fcm_button.dart';
import '../../core/ui/fcm_chip.dart';
import '../../core/ui/fcm_motion.dart' show FitText;
import '../../core/ui/fcm_panel.dart';
import '../../core/ui/fcm_style.dart';
import '../../l10n/l10n_context.dart';
import 'streak_providers.dart';
import 'streak_store.dart';

/// The profile's streak section: claims today's reward when open,
/// shows the run and tomorrow's payout otherwise.
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
      await StreakStore(database).claim(clubId: club.id);
      if (!mounted) return;
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
    final state = s.state;
    final currentDay = s.claimedToday ? state.lastStreakDay : s.nextStreakDay;

    return FcmPanel(
      accent: s.claimedToday ? FcmColors.bronze : FcmColors.gold,
      glow: !s.claimedToday,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: FcmColors.gold,
                size: 22,
              ),
              const SizedBox(width: 8),
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
              // The run's ordinal — the number the climb is measured by.
              FcmPill(
                l10n.streakDayCount(currentDay),
                color: FcmColors.gold,
                filled: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // The last seven days as pips: the claimed run behind, today
          // as the live slot, tomorrow dimmed. The 7th day wears the
          // weekly-bonus mark.
          _DayPips(currentDay: currentDay, claimedToday: s.claimedToday),
          const SizedBox(height: 12),
          if (s.claimedToday) ...[
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
          if (!s.claimedToday) ...[
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

/// The seven-day pip row: the climb's shape at a glance.
class _DayPips extends StatelessWidget {
  const _DayPips({required this.currentDay, required this.claimedToday});

  /// The streak ordinal TODAY sits at (claimed or claimable).
  final int currentDay;

  final bool claimedToday;

  @override
  Widget build(BuildContext context) {
    // The window ENDS at today (or the next rung when still open):
    // the last pip is the live slot. Show up to 7 pips ending on the
    // live slot; a fresh run shows fewer (a 1-day run shows one pip).
    final last = currentDay.clamp(1, currentDay);
    final first = (last - 6).clamp(1, last);
    final pipCount = last - first + 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < pipCount; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _DayPip(
            day: first + i,
            isToday: first + i == last,
            claimed: first + i < last || (first + i == last && claimedToday),
          ),
        ],
      ],
    );
  }
}

class _DayPip extends StatelessWidget {
  const _DayPip({
    required this.day,
    required this.isToday,
    required this.claimed,
  });

  final int day;
  final bool isToday;
  final bool claimed;

  @override
  Widget build(BuildContext context) {
    final bonusDay = day % 7 == 0;
    final width = isToday ? 34.0 : 24.0;
    return Container(
      width: width,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: claimed
            ? FcmColors.goldGradient
            : (isToday ? FcmColors.steelGradient : null),
        color: claimed
            ? null
            : Colors.white.withValues(alpha: isToday ? 0.10 : 0.05),
        border: Border.all(
          color: isToday
              ? FcmColors.gold.withValues(alpha: 0.9)
              : (claimed
                    ? FcmColors.goldSoft.withValues(alpha: 0.5)
                    : Colors.white24),
          width: isToday ? 1.5 : 1,
        ),
        boxShadow: [
          if (isToday && !claimed)
            BoxShadow(
              color: FcmColors.gold.withValues(alpha: 0.25),
              blurRadius: 10,
            ),
        ],
      ),
      child: claimed
          ? Icon(
              bonusDay ? Icons.stars_rounded : Icons.check_rounded,
              color: FcmColors.ink,
              size: bonusDay ? 18 : 16,
            )
          : Text(
              '$day',
              style: TextStyle(
                color: isToday ? FcmColors.gold : FcmColors.textDim,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}
