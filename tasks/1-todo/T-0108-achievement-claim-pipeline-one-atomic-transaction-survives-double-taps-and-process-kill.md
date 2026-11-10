---
id: T-0108
title: Achievement claim pipeline — one atomic transaction (coins + claim + ledger) that survives double taps and process kill
priority: high
status: todo
attempts: 0
depends_on: [T-0106, T-0107]
created: 2026-11-10
completed:
---

# T-0108: Achievement claim pipeline — one atomic transaction (coins + claim + ledger) that survives double taps and process kill

## Goal
Claiming a tier is ONE database transaction: UNIQUE-guarded claim row insert + `creditCoins` ledger row, all-or-nothing. A double tap claims once. Back-navigation re-entry claims zero. A process kill mid-claim leaves either both rows or neither. The reward can never be double-spent into the economy.

## Context
- The pack-opening feature already had this exact requirement ("rewards that cannot be re-rolled by back-navigation or double taps") and solved it at the DB layer; `coin_ops.dart`'s atomic `creditCoins`/`spendCoins` are the building blocks. The claim adds a second guard: the UNIQUE(clubId, achievementId, tierKey) constraint from T-0106 makes the claim row the idempotency token — if the insert lands, the credit is justified; if it cannot land, no credit.
- Interaction with the fixture-replay path (T-0099): replay refunds the recorded match reward and re-credits a fresh one. Achievements are NOT re-rolled on replay — the claim stays, the metric re-derives to the same value (T-0107's derivation), so nothing needs refunding. Document this in the pipeline's doc comment: claims are terminal, replays are transparent to them.
- Ledger reason convention: write `reason: 'achievement'` with `detail: '<achievementId>:<tierKey>'` so T-0109's sweep can attribute achievement income precisely (T-0107's reason constants own the string).
- UX contract for T-0110's screen (set here so the pipeline API matches): the screen shows UNCLAIMED eligible tiers; tapping claims; already-claimed tiers render claimed (from the claims table, not from a local flag). The pipeline's return type therefore distinguishes: granted (with the credited amount) vs already-claimed (idempotent no-op, not an error) — a sealed result type, the repo's standard for fallible operations.

## Requirements
1. `lib/features/achievements/achievement_claim_service.dart` — `claimTier(clubId, achievementId, tierKey)`:
   - Re-derivees current progress via T-0107 and REJECTS claims whose tier threshold is not actually met (a stale/tampered UI cannot claim what the game state does not support — the DB guard alone is not enough; eligibility is state-derived, not request-declared).
   - Inside ONE `transaction()`: insert the claim row (UNIQUE violation ⇒ `AlreadyClaimed`), `creditCoins` with the catalog's tier reward (T-0105 config), return `Granted(coins: …, titleGranted: …)`.
   - Sealed `ClaimResult { Granted, AlreadyClaimed, NotEligible }` — no exceptions across the API boundary for the two expected cases.
   - If the tier carries a titleId, the claim row records it (T-0106's `titleGranted` column); EQUIPPING stays manual (T-0112) — granting ≠ equipping.
2. Batch claim helper for T-0110's "claim all" affordance if the screen design needs it — but each tier still claims through the same single-tier path (loop of transactions, not one mega-transaction; a partial batch success must persist, and the UI re-renders from the claims table).
3. `test/features/achievements/claim_service_test.dart` — in-memory db + T-0107's fixture helpers: happy path (granted, ledger row with reason `achievement` and the exact detail, balance moved); double claim (AlreadyClaimed, balance unchanged, still one ledger row); not-eligible (NotEligible, no rows); claim survives "kill" simulation (perform the claim, close db, reopen the same in-memory db file if the harness supports it — otherwise assert the transaction boundary by checking both rows exist atomically in the post-state); title-recording on title tiers.
4. The reason string `'achievement'` joins T-0107's typed constants; no raw strings in the service.

## Out of Scope
- UI (T-0110), economy sweep gating (T-0109), equipping titles (T-0112).
- Any change to `coin_ops.dart` itself — the service COMPOSES it.

## Acceptance Criteria
- [ ] Coins + claim + ledger land atomically; double-claim returns AlreadyClaimed with the balance provably unchanged (test asserts both the row count and the balance).
- [ ] Ineligible claims rejected from derived state, not request parameters.
- [ ] `flutter analyze` zero warnings; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/achievements/
# Expected: green

flutter test
# Expected: full suite green
```

---

<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
