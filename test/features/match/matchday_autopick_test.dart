// The matchday Auto Pick policy (T-0118): the pre-match duplicate's
// XI and bench are chosen by FITNESS — injured (and, one day,
// suspended) players are excluded from the starting XI AND the bench,
// and every slot ranks by stamina band first (bands of 10: a 2-point
// fitness edge must not outweigh a 15-point quality gap inside a
// band), then by slot rating. The Team tab's merit policy (T-0117)
// and this policy live in the ONE engine behind explicit parameters.
//
// Fixtures run the banding rule BOTH directions, the two exclusion
// rules (bench included — the owner's explicit ask), the empty
// suspended-set default, and the merit regression.
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart'
    show positionWeights;
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/squad/formations.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart';

PlayerCard _card(
  int id,
  Position position, {
  int overall = 70,
  int stamina = 100,
  int injuryMatchesRemaining = 0,
}) => PlayerCard(
  ownedId: id,
  upgradeLevel: 0,
  staminaPercent: stamina,
  injuryMatchesRemaining: injuryMatchesRemaining,
  base: BasePlayer(
    playerId: 1000 + id,
    name: 'Player $id',
    position: position,
    nationality: 'Egypt',
    marketValueEur: 5_000_000,
    baseStats: _statsFor(position, overall),
  ),
);

BaseStats _statsFor(Position position, int overall) {
  final weights = positionWeights[position]!;
  int attr(PlayerAttribute a) {
    final w = weights[a] ?? 0;
    if (w == 0) return 1;
    return (overall + 10.0 * (w - 0.375)).round().clamp(1, 99);
  }

  return BaseStats(
    overall: overall,
    attack: attr(PlayerAttribute.attack),
    support: attr(PlayerAttribute.support),
    defence: attr(PlayerAttribute.defence),
    goalkeeping: attr(PlayerAttribute.goalkeeping),
  );
}

void main() {
  // Two centre backs is the smallest fixture that pits the banding
  // rule against the rating rule in one slot (4-3-3's CB slots).
  final f433 = formationByCode('4-3-3');

  test('same band: rating decides — 92-stamina 78 beats 96-stamina 72', () {
    final a = _card(1, Position.cb, overall: 78, stamina: 92);
    final b = _card(2, Position.cb, overall: 72, stamina: 96);
    final assignment = const SquadEngine().autoPick(
      [a, b],
      f433,
      excludeInjured: true,
      staminaFirst: true,
    );
    // Both CB slots fill; the BETTER player owns the first slot the
    // engine fills — and (the point) stamina 92 vs 96 is the same
    // band, so quality won.
    expect(assignment.values.toSet(), containsAll([1, 2]));
    final betterSlot =
        assignment.entries.firstWhere((e) => e.value == 1).key;
    final weakerSlot =
        assignment.entries.firstWhere((e) => e.value == 2).key;
    expect(betterSlot, lessThan(weakerSlot),
        reason: 'inside one stamina band the slot rating decides');
  });

  test('band beats rating — 100-stamina 75 beats 61-stamina 85', () {
    final fit = _card(1, Position.cb, overall: 75, stamina: 100);
    final tired = _card(2, Position.cb, overall: 85, stamina: 61);
    final assignment = const SquadEngine().autoPick(
      [fit, tired],
      f433,
      excludeInjured: true,
      staminaFirst: true,
    );
    final fitSlot = assignment.entries.firstWhere((e) => e.value == 1).key;
    final tiredSlot = assignment.entries.firstWhere((e) => e.value == 2).key;
    expect(fitSlot, lessThan(tiredSlot),
        reason: 'the 90s band outranks the 60s band even at -10 overall');
  });

  test('injured players: excluded from the XI AND the bench', () {
    // 11 fit outfielders + 1 injured STAR: the injured star must land
    // in the RESERVES (unassigned by the matchday pick — the bench is
    // for fit contributors), and no XI slot holds him.
    final fit = <PlayerCard>[
      _card(10, Position.gk),
      _card(11, Position.lb),
      _card(12, Position.cb),
      _card(13, Position.cb),
      _card(14, Position.rb),
      _card(15, Position.cdm),
      _card(16, Position.cm),
      _card(17, Position.cam),
      _card(18, Position.lw),
      _card(19, Position.rw),
      _card(20, Position.st),
    ];
    final injuredStar = _card(
      99,
      Position.st,
      overall: 95,
      injuryMatchesRemaining: 3,
    );
    final assignment = const SquadEngine().autoPick(
      [...fit, injuredStar],
      f433,
      excludeInjured: true,
      staminaFirst: true,
    );
    // XI: no injured player.
    for (var slot = 0; slot < Formation.startingXiSize; slot++) {
      expect(assignment[slot], isNot(99),
          reason: 'the injured star never starts');
    }
    // BENCH (slots 11..17): no injured player either — the owner's
    // explicit rule.
    for (var slot = Formation.startingXiSize;
        slot < Formation.startingXiSize + Formation.benchSize;
        slot++) {
      expect(assignment[slot], isNot(99),
          reason: 'the injured star does not sit on the matchday bench');
    }
  });

  test('suspendedPlayerIds: the red-card HOOK excludes like an injury '
      '(empty default = unchanged)', () {
    final a = _card(1, Position.cb, overall: 80);
    final b = _card(2, Position.cb, overall: 70);
    // Default: both pickable.
    final plain = const SquadEngine().autoPick(
      [a, b],
      f433,
      staminaFirst: true,
    );
    expect(plain.values.toSet(), containsAll([1, 2]));
    // With the ban set (the future red-card state): player 1 is gone
    // from every section exactly like an injured player.
    final banned = const SquadEngine().autoPick(
      [a, b],
      f433,
      suspendedPlayerIds: const {1},
      staminaFirst: true,
    );
    expect(banned.values, isNot(contains(1)));
    expect(banned.values, contains(2));
  });

  test('the merit policy is untouched: staminaFirst false ranks by '
      'rating alone (T-0117 regression)', () {
    // The tired SUPERIOR player wins the first slot when the Team
    // tab's merit policy runs — no stamina in the key at all.
    final fit = _card(1, Position.cb, overall: 75, stamina: 100);
    final tired = _card(2, Position.cb, overall: 85, stamina: 61);
    final assignment = const SquadEngine().autoPick(
      [fit, tired],
      f433,
      excludeInjured: false,
    );
    final tiredSlot = assignment.entries.firstWhere((e) => e.value == 2).key;
    final fitSlot = assignment.entries.firstWhere((e) => e.value == 1).key;
    expect(tiredSlot, lessThan(fitSlot),
        reason: 'merit ranking ignores fitness entirely');
  });
}
