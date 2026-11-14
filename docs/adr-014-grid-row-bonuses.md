# ADR-014: Grid-Row Tactical Bonuses for the Starting XI

- **Status**: Proposed (owner request 2026-11-14)
- **Scope**: Team-tab pitch grid, match engine team totals
- **Related**: GDD 6.4 (Formations), 10.2 (Custom Tactics), 12.2 (Team
  Attribute Calculation); the chess grid (owner request 2026-11-13, in
  `formations.dart`); mentality ladder (GDD 10.3, `team_tactics.dart`).

## Context

The Team-tab pitch is a fixed chess grid — 5 columns × 6 rows, row 0 the
keeper (bottom) and row 5 the most advanced line (top). A player's cell
already carries **meaning through the position it asks for**
(`positionOfCell`, `formations.dart`): a man standing off his cell's
position gets the compatibility penalty via the engine's compat factor.
What the grid does **not** yet carry is *depth*: today, moving a LB from
row 1 to row 2 changes nothing in the engine — both rows ask for LB, so
the same role weights and the same compatibility apply. The owner wants
rows to matter: a man pushed higher attacks better and defends worse, a
man dropped deeper defends better and attacks worse.

## Real-tactics grounding (why this is sound)

In real football, *role depth is a tactical instruction*: a full back
pushed into the opposition half becomes an attacking wing back — his
team's threat grows, but the space behind him is where counters strike
(asymmetric cost, visibly exploitable). Coaches already think in exactly
this trade: "high line", "low block", "rest defence". FM's player
instructions are the same mechanic. This is the tactical reality the
grid should encode.

It complements, not duplicates, the existing tools:
- **Mentality** (GDD 10.3) shifts the *whole team* one axis at once
  (att ×/def ×) — global.
- **Custom tactics** (GDD 10.2) shift tactical phases — global.
- **The grid** shifts *individual players* — local, per-player, and
  visible right on the pitch where the user is dragging.

## Decision

1. **A hidden per-row multiplier** applied to each outfield player's
   attack and defence attributes, linear in the row index, zero-sum
   around the midfield row:

   | Row (0 = GK, bottom) | Attack mult | Defence mult | Points at OVR 80 |
   |---|---|---|---|
   | 0 — keeper | — excluded, GK row never moves | — | — |
   | 1 — back line | ×0.970 | ×1.030 | −2.4 / +2.4 |
   | 2 — deep mid | ×0.985 | ×1.015 | −1.2 / +1.2 |
   | 3 — midfield | ×1.000 | ×1.000 | 0 / 0 (anchor) |
   | 4 — advanced | ×1.015 | ×0.985 | +1.2 / −1.2 |
   | 5 — front | ×1.030 | ×0.970 | +2.4 / −2.4 |

   Step size: **1.5 engine points per row** on each axis (i.e. ±1.5%
   multipliers per row from the row-3 anchor). Linear because six rows
   is too few to justify a curve, and linear is what users can reason
   about while dragging.

2. **Where it applies**: inside `computeTotals`
   (`match_engine_runtime.dart`), per player, as a multiplicative term
   on that player's attack/defence contribution **before** role
   weights — same layer as the compatibility factor, not a team-wide
   multiplier like mentality. The row comes from the player's grid cell
   (`gridCellsOf(formation)`), already available on the runtime's
   formation. Support and goalkeeping are untouched.

3. **Scale justification (game balance)**: a realistic extreme — the
   user pushes their whole XI one row up — swings the weighted mean by
   ~1 row ≈ ±1.5 points, and an aggressive all-out shape (two rows on
   the front men) reaches ~+3 points ≈ **one mentality step**
   (Positive is +5% attack / −3% defence at OVR 80 ≈ ±4 points).
   It *stacks* with mentality by design (shape + mentality = different
   tools), but alone it can never out-shout the mentality slider — the
   grid is fine-tuning, mentality is the big lever. Zero-sum around row
   3 means a default preset shape (which snaps to natural rows,
   weighted mean ≈ row 2.6) reads within −0.7 points of neutral: the
   calibration baseline moves negligibly.

4. **Determinism/replay**: the bonus is a pure function of the
   formation code (cell row is inside the `C|GK@2.0,…` serialisation),
   so the same formation code always yields the same totals. No new
   engine-input plumbing, no seed impact. **Bump `matchEngineVersion`
   4 → 5**: same seed now produces different totals for shifted rows —
   pre-change replays must be labelled with the old version (same rule
   as T-0052/T-0054).

5. **Hidden but inspectable**: the multiplier is not shown on the card
   (the owner called it a *hidden* bonus), but the pre-match forecast
   screen's totals reflect it, so the user sees the effect without the
   arithmetic. No UI number is required for v1; a debug overlay can
   come later if QA asks.

## Alternatives considered

- **Rows change the slot's asked position instead** (row 1 LB → row 2
  LB becomes CDM): rejected — brutal compatibility cliffs for natural
  wide men, and `positionOfCell` already encodes position per row; the
  bonus must be orthogonal, not a second position system.
- **Bigger steps (3 pts/row)**: rejected — an all-out front six would
  swing ~2 mentality steps and break the ladder's 47-50% home-win
  calibration band; 1.5 keeps the engine's sigmoid inside its measured
  margins even at the legal extreme.
- **Per-column bonuses too** (wider = more crossing): rejected for v1 —
  the owner asked for rows; columns would need their own balance pass
  and the report's bands would need re-measuring.
- **Do nothing (rows stay cosmetic)**: rejected — it wastes the grid's
  most interesting promise; moving a player up *should* mean
  something.

## Consequences

- Moving a player vertically on the grid now has engine weight even
  when the asked position is unchanged (the LB row 1 → row 2 gap is
  finally real).
- The default presets stay effectively neutral (weighted mean ≈ 2.6 vs
  the 3.0 anchor), so existing calibration suites
  (`engine_calibration_test.dart`, `match_engine_balance_test.dart`)
  must still hold within their published bands; the dev task re-runs
  them and re-anchors only if a band edge is crossed.
- Save-compat: formation codes are unchanged in format; the bonus is
  derived, not stored.
- `matchEngineVersion` bump labels replay divergence (deterministic
  replay records keep their meaning).
