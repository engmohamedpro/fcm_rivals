# FCM RIVALS
## Game Design Document (GDD) & Software Requirements Specification (SRS)

**Document Version:** 1.1  
**Product Name:** FCM Rivals  
**Genre:** Football Management / Player Collection / Strategy  
**Platforms:** Android & iOS  
**Engine & Framework:** Flutter / Dart  
**Initial Game Mode:** Offline Single-player  
**Future Direction:** Online Football Management & Multiplayer Competition  
**Monetization:** Rewarded Advertisements  
**Local Database:** SQLite / Drift  
**State Management:** Riverpod

---

# PART 1 — GAME DESIGN DOCUMENT (GDD)

## 1. Game Vision

FCM Rivals is a football management game focused on building a football club, collecting players, creating competitive squads, developing players, managing tactics, and competing through a division-based football league system.

The game combines:

- Football club management.
- Player collection and card packs.
- Player development and upgrades.
- Squad building.
- Tactical management.
- Realistic football match simulation.
- League and season progression.
- AI-controlled rival clubs.
- Future online competitions.

### 1.1 Core Experience

The player's journey:

1. Create a football club.
2. Open starting player packs.
3. Build a squad of 23 players.
4. Select formations and tactics.
5. Compete in league matches.
6. Earn Coins and collect new players.
7. Upgrade players using duplicates.
8. Get promoted to stronger divisions.
9. Build an increasingly competitive club.

### 1.2 Design Principles

- Realistic football simulation.
- Meaningful management decisions.
- Balanced progression.
- Market Value-driven player economy.
- Offline gameplay without mandatory internet.
- Online-ready technical architecture.
- No advertisement-based tactical advantages.
- Efficient performance on low-end Android devices.
- Avoid unnecessary complexity.

---

## 2. Game Identity

**Official Name:** FCM Rivals

**Genre Description:** Football Management & Competition.

The brand should support both the initial offline career experience and future online leagues, competitive seasons, and multiplayer features.

The name must not restrict the game to a single-player-only identity.

---

## 3. Club Creation

During initial setup, the user creates:

- Club Name.
- Club Crest.
- Manager Name.

The user becomes the manager and owner of the created club.

The club has its own progression, squad, finances, statistics, and history.

---

## 4. Player Database

### 4.1 Player Data Source

The developer provides the player database through an importable dataset.

The dataset contains real-world player information and Market Values.

The imported database is the authoritative source for global player attributes.

### 4.2 Player Fields

| Field | Description |
|---|---|
| Player ID | Permanent unique identifier |
| Name | Player name |
| Nationality | Player nationality |
| Club | Current club |
| Position | Primary position |
| Age | Player age |
| Market Value | Current Market Value |
| Base Overall | Calculated base rating |
| Base Attack | Base Attack |
| Base Support | Base Support |
| Base Defence | Base Defence |
| Base Goalkeeping | Base Goalkeeping |

### 4.3 Supported Positions

- ST
- LW
- RW
- CAM
- LM
- RM
- CM
- CDM
- CB
- RB
- LB
- GK

### 4.4 Stable Player Identity

Every player must have a permanent Player ID.

Changes to player name, club, age, position, or Market Value must not create a new identity.

### 4.5 Base Stats Generation

Base Stats are generated using:

1. Market Value.
2. Player Position.
3. A non-linear Market Value conversion curve.
4. Position-specific attribute weighting.

Market Value must not be converted directly into linear ratings.

The generation formula should use logarithmic or similarly controlled scaling.

Different positions must produce different attribute distributions.

For example:

- ST: High Attack.
- CAM: High Attack and Support.
- CM: Balanced Support and Defence.
- CDM: High Defence and Support.
- CB: High Defence.
- GK: High Goalkeeping.

### 4.6 Player Database Update Rules

When a new player database is imported:

| Change | Expected Behavior |
|---|---|
| Name changed | Update player name |
| Club changed | Update player club |
| Age changed | Update player age |
| Position changed | Regenerate Base Stats |
| Market Value increased | Regenerate Base Stats |
| Market Value decreased | Regenerate Base Stats |
| Market Value unchanged and Position unchanged | Preserve Base Stats |

**Important:** Base Stats must be regenerated if either Market Value or Position changes.

Base Stats must remain unchanged if both Market Value and Position remain unchanged.

### 4.7 Preserve Player Upgrades

The user's upgrade progression must survive all database updates.

Example:

Before update:

- Base Overall: 85
- Upgrade Level: +3
- Final Overall: 88

After database update:

- New Base Overall: 87
- Preserved Upgrade Level: +3
- Final Overall: 90

The same principle applies to individual upgraded attributes.

Global Base Player data and user-owned Player Instance data must remain separate.

### 4.8 Removed Players

When a player is removed from the new database:

1. Find the user's owned copies.
2. Calculate the normal selling value.
3. Credit the user with the same Coins received from a normal sale.
4. Remove the player from the user's collection.
5. Remove the player from squad assignments.
6. Notify the user with the player's name and removal reason.

For upgraded players, compensation must use **exactly the same selling formula as selling an upgraded player**.

There must be no separate compensation calculation.

---

## 5. Player Collection & Pack System

### 5.1 Player Ownership

Players obtained from packs are permanently owned by the user until:

- Sold.
- Removed through an official database update.

### 5.2 Pack Categories

- Global Pack.
- League Pack.
- Nationality Pack.
- Club Pack.
- Position Pack.

### 5.3 Pack Contents

Each pack contains exactly one player.

The player's Market Value tier is rolled per pack (equal chance by default):

- Low Market Value tier.
- Medium Market Value tier.
- High Market Value tier.

The exact tier boundaries and probabilities remain configurable.

### 5.4 Pack Probability

Higher Market Value players must have lower probabilities.

Probability calculations must consider:

- Eligible player pool.
- Player Market Value.
- Pack category.
- Tier boundaries.
- Configurable probability coefficients.

The system must avoid making high-value players impossible to obtain.

Display the applicable odds to users.

### 5.5 Pack Pricing

Pack prices are calculated dynamically from the economic value of eligible players.

Pack pricing must be controlled by the Economy Engine.

### 5.6 Opening Experience

Pack opening should provide a cinematic experience:

1. Nationality flag.
2. Player name.
3. Position.
4. Player card.
5. Reveal animation.

Higher-value players should receive more exciting reveal effects.

### 5.7 Pack Results

After opening a pack, the user can:

- Keep the player.
- Sell the player.
- Merge duplicate players through the upgrade system.

### 5.8 Starting Free Packs

The user starts with:

Three free packs for each of the 12 supported positions.

Total: **36 starting packs**.

The user may open these packs at any time.

The required squad must be completed before the first match.

---

## 6. Squad Management

### 6.1 Squad Capacity

| Squad Section | Players |
|---|---:|
| Starting XI | 11 |
| Bench | 7 |
| Reserves | 5 |
| Total | 23 |

### 6.2 Squad Interface

The squad interface displays:

- Football pitch.
- Starting formation.
- Player cards positioned on the pitch.
- Horizontal bench row.
- Horizontal reserves row.

Players can be moved using drag-and-drop interactions.

### 6.3 Auto Pick

Auto Pick automatically chooses the best eligible players.

Selection order:

1. Starting XI.
2. Bench.
3. Reserves.

Selection rules:

- Position compatibility.
- Position-specific player rating.
- Highest suitable player rating.
- No duplicate player assignments.
- No incompatible positions when suitable alternatives exist.

Reserves should be sorted by rating.

### 6.4 Formations

Support a broad range of realistic formations.

Examples:

- 4-2-3-1
- 4-3-3
- 4-4-2
- 4-1-4-1
- 3-5-2
- 3-4-3
- 5-3-2
- 5-4-1
- 4-2-2-2
- 4-3-2-1

Formation definitions must be data-driven.

Changing formation must update player positions and tactical calculations.

---

## 7. Player Attributes & Ratings

### 7.1 Primary Attributes

Every player has exactly four visible primary attributes:

1. Attack.
2. Support.
3. Defence.
4. Goalkeeping.

Additional card information:

- Overall Rating.
- Position.
- Nationality.
- Name.
- Club.

Stamina is displayed separately as a percentage bar.

### 7.2 Position-Specific Rating

The player's rating must be position-sensitive.

Each position has different attribute weights.

A goalkeeper's rating must prioritize Goalkeeping, while a striker's rating must prioritize Attack.

The position rating calculation must be independent of the Match Engine's event calculations.

### 7.3 Overall Rating

Overall is a weighted representation of the four attributes according to the player's primary position.

Base Overall and upgraded Overall must be distinguishable internally.

---

## 8. Player Upgrade System

### 8.1 Duplicate Merging

Players are upgraded through merging duplicate copies.

- Two base copies = +1.
- One +1 copy + one base copy = +2.
- Further upgrades follow the same progression.

### 8.2 Upgrade Benefits

Every upgrade level provides:

- +1 Overall.
- +1 to one randomly selected individual attribute.

The random attribute selection must follow controlled rules.

### 8.3 Upgrade Scope

Upgrades affect only the user's owned Player Instance.

They must never modify the global Base Player record.

### 8.4 Upgrade Costs

Upgrade costs depend on:

- Current Market Value.
- Current Upgrade Level.

Higher Market Value and higher upgrade levels require more Coins.

The Economy Engine calculates all costs.

---

## 9. Division & Season System

### 9.1 Division Ladder

The game uses an expandable numbered division system.

- Division 1 is the starting division.
- Higher division numbers are progressively harder.
- There is no predefined final division.

### 9.2 Season Structure

Each division contains 20 clubs:

- One user-controlled club.
- Nineteen AI-controlled clubs.

Each team plays all other teams twice.

Total: 38 matches per team.

### 9.3 Promotion and Relegation

| Position | Outcome |
|---|---|
| 1–3 | Promotion |
| 4–17 | Stay |
| 18–20 | Relegation |

### 9.4 AI Club Generation

Each AI club contains:

- Club name.
- Crest.
- Manager name.
- Squad.
- Formation.
- Playing Style.
- Market Value profile.
- Tactical configuration.

### 9.5 Season Persistence

At the end of a season:

- Retain three promoted clubs.
- Retain three relegated clubs.
- Generate 17 new clubs in the target division.
- Remove the other previous-season opponents from the active division.
- Preserve historical match results and statistics.

### 9.6 Difficulty Scaling

Opponent quality must increase progressively between divisions.

The AI squad generation system must consider the division's target Market Value and player rating ranges.

Difficulty must be tested through automated season simulations.

---

## 10. Tactical Management

### 10.1 Formation

The user selects the formation used by the team.

Formation changes affect player positioning and match calculations.

### 10.2 Custom Tactics

The ten preset Playing Styles are removed. The user builds his own
tactics from instructions grouped into three phases of play:

- **In Possession** — build-up style, tempo, width and final-third
  approach (phase 1, shipped):

  | Instruction | Options | Anchor effects (rule 14 placeholders) |
  |---|---|---|
  | Build-up | Play Out from the Back / Mixed / Long Ball | Play Out: possession 1.10, passing 1.05, chances 0.94 · Long Ball: possession 0.82, passing 0.86, chances 1.06, stamina 0.96 |
  | Tempo | Slow / Standard / Fast | Slow: possession 1.06, chances 0.95, stamina 0.94 · Fast: possession 0.95, chances 1.05, passing 0.97, stamina 1.08 |
  | Width | Narrow / Standard / Wide | Narrow: passing 1.04, chances 0.96 · Wide: passing 0.96, chances 1.05 |
  | Final third | Work Ball into Box / Balanced / Early Crosses / Shoot on Sight | Work Ball: chances 0.92, shot quality 1.08 · Early Crosses: chances 1.04, shot quality 0.95, passing 0.96 · Shoot on Sight: chances 1.10, shot quality 0.90 |

  Shot quality is a per-side hook on the chance→goal conversion path —
  the only way Work Ball vs Shoot on Sight are tellable apart.
  Combinations rebuild the legacy possession family: Play Out + Slow +
  Narrow ≈ old Tiki-Taka; Long Ball + Fast ≈ old Direct Play. The UI
  shows an estimated possession share that updates with the chosen mix.
  Balance bands (10k seeded sims, even strength): any single extreme
  46–54% win rate, full-stack extremes 40–58%, measured possession
  33–65%, goals 2.6–2.9/match, conversion 10–11%.
- **Out of Possession** — defensive line height, pressing intensity,
  tackling aggression and the offside trap. Delivered in phase 2.
- **Transitions** — counter-press, counter-attacking and rest defence.
  Delivered in phase 3.

Until a phase ships, its group carries its default (identity) state;
the default `TeamTactics` reproduces the old Balanced style exactly
(all multipliers 1.00), so gameplay is unchanged during the rollout.

Custom Tactics affect:

- Team performance.
- Chance creation.
- Defensive behavior.
- Passing patterns.
- Stamina consumption.
- Chance quality (from phase 1).

**Legacy style mapping.** Every removed style is rebuilt as an
instruction combination (documentation only — no preset chips return):

| Legacy style | Rebuilt by |
|---|---|
| Possession / Tiki-Taka | In Possession: Play Out + Slow + Narrow (phase 1) |
| Direct Play / Long Ball | In Possession: Long Ball + Fast (phase 1) |
| Wing Play | In Possession: Wide + Early Crosses (phase 1) |
| Gegenpressing / High Press | Out of Possession: High Press (phase 2) + Transitions: Counter-Press (phase 3) |
| Low Block | Out of Possession: Deep Line + Low Press (phase 2) |
| Counter Attack | Transitions: Fast Counter (phase 3) |

Persistence: the club row stores the tactics as one JSON payload;
legacy saves that carried a style name load as the default setup, and
the mapping table above tells the player how to rebuild his old style
once the phases land.

**Rule (GDD 10.3 also applies here): every instruction's effect summary
is user-visible** — the UI shows the estimated possession share and the
percentage effects of each chosen combination, never raw multipliers.

### 10.3 Mentality

Supported mentalities:

- Very Defensive.
- Defensive.
- Cautious.
- Balanced.
- Positive.
- Attacking.
- Very Attacking.

Mentality applies percentage-based changes to the team's Attack and Defence balance.

All effects must be visible to the user.

### 10.4 Live Tactical Changes

The user can change:

- Formation.
- Playing Style.
- Mentality.

Changes are allowed at any time during a match.

The changes must affect future simulation events immediately.

### 10.5 Substitutions

Maximum substitutions per match: 5.

Substitutions update:

- Team totals.
- Player Stamina.
- Match statistics.
- Player ratings.
- Position assignments.

---

## 11. Stamina System

### 11.1 Stamina Range

Every player has Stamina from 0% to 100%.

### 11.2 Effective Attributes

All four primary attributes are proportionally affected by Stamina.

Example:

Base Attack = 90  
Stamina = 80%

Effective Attack = 72.

### 11.3 Stamina Consumption

Stamina decreases only while a player is on the pitch.

Bench and reserve players do not consume match Stamina.

Consumption depends on:

- Playing Style.
- Mentality.
- Match duration.
- Player workload.
- Tactical changes.

Gegenpressing, High Press, and attacking systems generally increase consumption.

Low Block and defensive systems generally reduce consumption.

### 11.4 Dynamic Consumption

Stamina loss must not be a simplistic fixed amount per minute.

It should be based on dynamic workload and the player's activity.

Changing tactics must affect subsequent Stamina consumption.

### 11.5 Recovery

Post-match recovery depends on:

- Rest interval.
- Minutes played.
- Workload.
- Current Stamina.

Full-match players recover more slowly than substitutes.

Stamina must not automatically reset to 100%.

### 11.6 Post-Match Pep Talk Recovery

The following choices are supported:

| Choice | Target | Bonus |
|---|---|---:|
| Rest, everyone deserves it! | All players | +5% |
| Focus on exhausted players! | Below 60% Stamina | +10% |
| Reward the substitutes! | Played under 45 minutes | +10% |
| Everyone gave their best! | Played 45+ minutes | +7% |

These are bonuses to natural recovery, not direct percentage-point additions to current Stamina.

Only one choice can be selected.

The game must show the affected player count and exact recovery effect before confirmation.

Values remain configurable for balancing.

---

## 12. Match Engine

### 12.1 Core Philosophy

The Match Engine simulates football through a sequence of realistic events.

It must not generate goals through a simple Attack-versus-Defence comparison or unrestricted random score generation.

### 12.2 Team Attribute Calculation

For every starting player:

Effective Attribute = Player Attribute × Stamina Percentage.

Calculate team totals:

- Attack.
- Support.
- Defence.
- Goalkeeping.

Apply modifiers in this order:

1. Individual Stamina scaling.
2. Mentality modifiers.
3. Playing Style modifiers.
4. Home Advantage.

Home Advantage provides a modest percentage boost.

The final percentage must be established through simulation.

### 12.3 Event Pipeline

Match events follow a structured pipeline:

1. Possession.
2. Build-up.
3. Passing and progression.
4. Defensive pressure.
5. Chance creation.
6. Shot selection.
7. Shot accuracy.
8. Goalkeeper reaction.
9. Goal, save, miss, or block.

Goals must emerge from these events.

### 12.4 Match Realism

The simulation considers:

- Player attributes.
- Player positions.
- Formation.
- Playing Style.
- Mentality.
- Stamina.
- Home Advantage.
- Tactical changes.
- Substitutions.
- Match score.
- Time remaining.
- Controlled randomness.

### 12.5 Random Seed & Deterministic Simulation

Each match receives one initial Random Seed.

The seed remains fixed throughout the match.

The random number generator maintains an evolving internal state.

Every random draw advances the state naturally.

**The seed must not be regenerated every minute.**

The simulation must process match events continuously using:

- Current Match State.
- Current tactics.
- Current player conditions.
- Current score.
- Current time.
- Current PRNG state.

Tactical changes become new simulation inputs.

For example:

If the user changes Mentality from Balanced to Attacking at minute 60, the new modifiers affect all relevant events generated from that point onward.

Previously completed events must never be recalculated.

For deterministic replay and testing, record:

- Initial Match Seed.
- Match Engine Version.
- Initial Match State.
- Timestamped user commands.
- AI tactical decisions.
- Simulation configuration.

Replaying the same initial state, seed, engine version, and command sequence must reproduce the same results.

### 12.6 Opponent AI

AI managers may adapt according to:

- Match score.
- Time remaining.
- Team performance.
- Red cards.
- Player fatigue.
- Lack of attacking opportunities.

AI changes must have tactical reasons.

The AI must not constantly change its tactics.

Important opponent tactical changes can generate notifications.

---

## 13. Live Commentary & Match Statistics

### 13.1 Commentary

Commentary must be generated from actual Match Engine events.

Supported event categories:

- Kick-off.
- Possession.
- Passing.
- Attacks.
- Dispossessions.
- Chances.
- Shots.
- Saves.
- Goals.
- Corners.
- Free kicks.
- Penalties.
- Cards.
- Substitutions.
- Full time.

Commentary must include contextual player names and event information.

It must never contradict the underlying Match Engine event.

### 13.2 Live Statistics

The game should support:

- Possession.
- Shots.
- Shots on Target.
- Corners.
- Pass Accuracy.
- Fouls.
- Yellow Cards.
- Red Cards.
- Expected Goals (xG).
- Big Chances.
- Saves.
- Offsides.
- Passes Completed.
- Tackles.
- Interceptions.
- Fouls Won.
- Crosses.
- Dribbles.

### 13.3 Match Timeline

All important events must be recorded with match time.

The timeline supports:

- Goals.
- Assists.
- Cards.
- Substitutions.
- Penalties.
- Major chances.
- Important tactical events.

---

## 14. Player Match Ratings

Every player receives an individual match rating.

Suggested starting rating: 6.0.

Rating calculations must be position-sensitive.

Examples:

| Position | Evaluation Factors |
|---|---|
| ST | Goals, shots, chances |
| Wingers | Dribbles, crosses, assists |
| CAM | Key passes, assists, chance creation |
| CM | Passing, possession, interceptions |
| CDM | Tackles, interceptions |
| CB | Defensive actions, errors |
| Fullbacks | Defensive work, crosses |
| GK | Saves, goals conceded, errors |

### Post-Match Screen

Display:

- Final score.
- Goal scorers.
- Assist providers.
- Player ratings.
- Man of the Match.
- Best performer.
- Worst performer.
- Team statistics.

The final rating formula requires balance testing.

---

## 15. Pep Talks

Three Pep Talk stages:

### Pre-Match

Motivational choices before kick-off.

Each choice has visible percentage-based performance effects.

### Half-Time

Motivational choices at half-time.

Effects apply to the second half.

### Post-Match

Choices influence Stamina recovery before the next match.

Normal Pep Talk choices never require advertisements.

---

## 16. Live Match Actions

The user can issue tactical actions during matches.

| Action | Effect |
|---|---|
| Push Forward | Attack increases, Defence decreases |
| Defend Deep | Defence increases, Attack decreases |
| Press More | Pressing increases, Stamina consumption increases |
| Stay Calm | Encourages controlled play |
| Play More Direct | Encourages direct attacking play |

All effects must display explicit percentage modifiers.

No Live Match Action requires an advertisement.

Important events can generate decision notifications:

- Goals conceded.
- Red cards.
- Bookings.
- Low Stamina.
- Opponent tactical changes.
- Lack of chances.

Avoid blocking the match for minor events.

---

## 17. Economy Engine

### 17.1 Centralized Economy

The Economy Engine controls:

- Player Economic Value.
- Pack prices.
- Pack probabilities.
- Player selling prices.
- Upgrade costs.
- Division rewards.
- Match rewards.

### 17.2 Economic Value

Market Value is the primary reference.

Raw Market Value must be converted using a controlled non-linear formula.

Use stable reference parameters and configurable coefficients.

### 17.3 Selling

Selling price depends on current Economic Value and the applicable selling percentage.

Upgraded players receive the appropriate additional valuation according to the upgrade selling formula.

The same formula must be used for removed players.

### 17.4 Upgrade Costs

Upgrade costs depend on player Economic Value and current Upgrade Level.

### 17.5 Economy Stability

Updating the player database must not arbitrarily shift the value of every player.

Use stable reference values rather than relying only on relative ranking across the latest imported dataset.

Economy changes must be measurable and testable.

### 17.6 Coin Sources

Coins are earned through:

- Match rewards.
- Player sales.
- Season rewards.
- Progression rewards.
- Configured in-game rewards.

No real-money Coin purchases in the initial version.

---

## 18. Division Progression & Rewards

Each season contains 38 matches.

Rewards depend on final position and division.

Proposed reward structure:

| Achievement | Reward |
|---|---|
| 1st Place | Coins + Premium Pack |
| 2nd–3rd Place | Coins + Pack |
| Promotion | Free Pack of User's Choice |
| Staying in Division | Position-based Coins |
| Relegation | Participation Reward |

Higher divisions offer higher rewards, but reward growth must not exceed the economic cost curve.

Long-term achievements can include:

- Reaching specific divisions.
- Winning a target number of matches.
- Promotion streaks.

Complex daily quests are not required in the initial version.

---

## 19. Rewarded Advertisements

### 19.1 Advertising Philosophy

Advertisements are optional.

No forced interstitial ads are included in the initial version.

### 19.2 Confirmed Advertisement Restrictions

Ads must never be required for:

- Pre-Match Pep Talks.
- Half-Time Pep Talks.
- Normal Live Match Actions.

All users must have equal access to tactical controls.

### 19.3 Rewarded Ad Opportunities

**Post-Match Pep Talk**

One special ad-supported option provides a higher Stamina recovery bonus.

Proposed value: +15% to natural recovery for eligible players.

**Match Replay**

- Available only after a draw or defeat.
- Maximum one replay opportunity per match.
- Requires completed rewarded video.
- No replay after a win.
- No duplicate match rewards.

**Other Proposed Opportunities**

- Free user-selected pack.
- Upgrade cost discount.
- Player selling bonus.
- Daily reward multiplier.
- Season reward multiplier.

The exact limits, refresh periods, and percentages remain configurable and subject to final balancing.

### 19.4 Advertisement Validation

- Grant rewards only after successful completion.
- Prevent duplicate callbacks.
- Enforce daily and transaction limits.
- Never interrupt an active match unexpectedly.
- Prevent stacking multiple ad bonuses on one transaction.

---

## 20. Future Online Vision

FCM Rivals must be designed to support online features after the initial offline release.

Online features are not required for Version 1.

Potential future features:

- Online accounts.
- Cloud synchronization.
- Online leagues.
- Competitive divisions.
- Head-to-head matches.
- Multiplayer tournaments.
- Online rankings.
- Player trading.
- Club competitions.
- Friends and rival clubs.
- Seasonal online events.

These features are future scope and must not be treated as existing Version 1 requirements.

The initial architecture must avoid decisions that make future online integration unnecessarily difficult.

In particular:

- Use stable player IDs.
- Separate player base data from owned player instances.
- Give clubs, matches, seasons, and owned players stable identifiers.
- Keep Match Engine calculations independent from UI.
- Keep Economy Engine calculations centralized.
- Separate local persistence from domain logic.
- Record match events in structured form.
- Use explicit match seeds and simulation versions.

Future online competitive play will require authoritative server-side validation of matches, rewards, economy transactions, and player ownership.

---

# PART 2 — SOFTWARE REQUIREMENTS SPECIFICATION (SRS)

## 21. Technical Stack

| Component | Technology |
|---|---|
| Application | Flutter |
| Language | Dart |
| State Management | Riverpod |
| Local Database | SQLite |
| Database Layer | Drift |
| Analytics | Firebase Analytics |
| Crash Reporting | Firebase Crashlytics |
| Notifications | Firebase Cloud Messaging |
| Configuration | Firebase Remote Config (Optional) |
| Advertising | Google Mobile Ads / AdMob |
| Gameplay Backend V1 | None |
| Online Backend | Future Phase |
| Cloud Save V1 | Excluded |
| IAP V1 | Excluded |

### 21.1 Architecture Principles

Use modular, feature-based architecture.

Keep the following engines independent from Flutter UI:

- Match Engine.
- Economy Engine.
- Player Database Engine.
- Pack Engine.
- Progression Engine.
- Stamina Engine.

Avoid over-engineering.

Do not introduce a gameplay server for Version 1.

---

## 22. Project Structure

```text
lib/
├── app/
│   ├── app.dart
│   ├── router/
│   ├── theme/
│   └── config/
│
├── core/
│   ├── database/
│   ├── constants/
│   ├── extensions/
│   ├── utils/
│   ├── errors/
│   └── services/
│
├── features/
│   ├── onboarding/
│   ├── club/
│   ├── players/
│   ├── player_database/
│   ├── packs/
│   ├── squad/
│   ├── formations/
│   ├── tactics/
│   ├── matches/
│   ├── match_engine/
│   ├── commentary/
│   ├── statistics/
│   ├── leagues/
│   ├── seasons/
│   ├── economy/
│   ├── upgrades/
│   ├── stamina/
│   ├── pep_talks/
│   ├── advertisements/
│   ├── progression/
│   └── settings/
│
├── integrations/
│   ├── firebase/
│   └── admob/
│
└── main.dart
```

This is a recommended starting structure. Small related components should remain grouped rather than creating unnecessary abstractions.

---

## 23. Functional Requirements

### Player & Database

**FR-001:** The system shall allow the user to create a club and manager profile.

**FR-002:** The system shall import player datasets and validate required fields.

**FR-003:** Every player shall have a stable unique Player ID.

**FR-004:** The system shall update player information using imported datasets.

**FR-005:** Base Stats shall regenerate when Market Value or Position changes.

**FR-006:** Base Stats shall remain unchanged when both Market Value and Position remain unchanged.

**FR-007:** Player upgrade progression shall survive database updates.

**FR-008:** Removed players shall be compensated using the exact normal selling formula.

### Collection & Economy

**FR-009:** The system shall support the five pack categories.

**FR-010:** Every pack shall contain exactly one player, drawn from a tier rolled according to its configured tier weights.

**FR-011:** Pack probabilities shall depend on Market Value and eligible players.

**FR-012:** The system shall support permanent player ownership.

**FR-013:** The system shall support player selling.

**FR-014:** The system shall support duplicate merging.

**FR-015:** Upgrade costs shall depend on Economic Value and Upgrade Level.

**FR-016:** All Coin transactions shall be atomic and recorded.

### Squad & Tactics

**FR-017:** The system shall support a 23-player squad.

**FR-018:** The system shall support formations.

**FR-019:** The system shall provide Auto Pick.

**FR-020:** The system shall support drag-and-drop squad management.

**FR-021:** The system shall support Playing Styles and Mentalities.

**FR-022:** Tactical changes shall be available during matches.

**FR-023:** The system shall enforce a maximum of five substitutions.

### Match Simulation

**FR-024:** The Match Engine shall simulate structured football events.

**FR-025:** The Match Engine shall use player attributes and Stamina.

**FR-026:** The Match Engine shall apply formation, style, mentality, and home advantage.

**FR-027:** The Match Engine shall support deterministic simulation using a fixed initial seed.

**FR-028:** The PRNG state shall advance as random draws are consumed.

**FR-029:** Tactical changes shall affect future events without recalculating previous events.

**FR-030:** The system shall calculate Stamina consumption and recovery.

**FR-031:** The system shall generate commentary from actual Match Engine events.

**FR-032:** The system shall calculate match statistics from actual events.

**FR-033:** The system shall calculate position-sensitive individual match ratings.

**FR-034:** The system shall support match replay after a draw or loss through one rewarded advertisement opportunity.

### Progression

**FR-035:** The system shall generate 20-team divisions.

**FR-036:** The system shall manage 38-match seasons.

**FR-037:** The system shall promote the top three teams and relegate the bottom three.

**FR-038:** The system shall preserve historical results and statistics.

**FR-039:** The system shall generate division-appropriate AI opponents.

### Monetization & Integrations

**FR-040:** The system shall support optional rewarded advertisements.

**FR-041:** The system shall validate advertisement completion before granting rewards.

**FR-042:** The system shall prevent duplicate ad rewards.

**FR-043:** The system shall not require advertisements for Pep Talks or Live Match Actions.

**FR-044:** The system shall not support real-money Coin purchases in Version 1.

**FR-045:** Firebase Analytics shall collect configured gameplay events when online.

**FR-046:** Firebase Crashlytics shall report crashes when online.

**FR-047:** Firebase Cloud Messaging shall support push notifications.

**FR-048:** Remote Config may distribute approved configuration values, with local defaults.

---

## 24. Non-Functional Requirements

### NFR-001: Offline Functionality

Core gameplay must work without internet connectivity.

### NFR-002: Performance

The application must target smooth operation on supported low-end Android devices.

Avoid unnecessary UI rebuilds, expensive calculations, and excessive object allocation.

### NFR-003: Data Integrity

Critical operations must use database transactions.

Examples:

- Pack opening.
- Player selling.
- Player merging.
- Coin deductions.
- Coin rewards.
- Season completion.
- Player database updates.

### NFR-004: Local Persistence

User progression must be saved locally.

### NFR-005: Reliability

The same initial state, Random Seed, engine version, and command sequence must produce reproducible simulation results.

### NFR-006: Maintainability

Domain logic must remain independent of Flutter UI and storage implementation.

### NFR-007: Localization

Initial language support:

- Arabic.
- English.

The architecture should support additional languages.

### NFR-008: Security

Validate all local transactions and advertisement rewards.

Because Version 1 has no authoritative gameplay backend, local save data cannot be guaranteed against a technically capable user modifying the application or its database.

### NFR-009: No Cloud Save

Version 1 must not upload gameplay progression to Firebase or another cloud database.

### NFR-010: No Backup

Version 1 must not provide Backup Export, Import, or Cloud Restore.

Uninstalling the game or losing the device may permanently erase local progression.

### NFR-011: Online Readiness

The architecture must support future server integration without requiring a complete rewrite of the Match Engine, Economy Engine, Player Database, or domain models.

---

## 25. Local Database Design

Proposed tables:

| Table | Purpose |
|---|---|
| PlayerDatabase | Imported global players |
| PlayerDatabaseVersions | Dataset version tracking |
| Users | Local manager profile |
| Clubs | User and AI clubs |
| OwnedPlayers | User-owned player instances |
| PlayerUpgrades | Upgrade history and levels |
| Packs | Pack definitions |
| PackOdds | Pack probabilities |
| CoinTransactions | Coin transaction ledger |
| Squad | Squad assignments |
| Formations | Formation definitions |
| Tactics | Tactical configuration |
| Divisions | Division definitions |
| Seasons | Season records |
| LeagueTeams | Participating clubs |
| Fixtures | Match schedules |
| MatchResults | Final results |
| MatchEvents | Structured match events |
| PlayerMatchStats | Individual match statistics |
| PlayerStamina | Current Stamina |
| AdUsage | Advertisement limits |
| Achievements | Long-term achievements |

### 25.1 Data Separation

The database must distinguish between:

**Global Player Data**
- Player ID.
- Name.
- Position.
- Age.
- Club.
- Market Value.
- Base Stats.

**Owned Player Instance**
- Owned Instance ID.
- Player ID.
- Upgrade Level.
- Upgrade Attribute Progress.
- Acquisition Information.
- Ownership Status.

A database update must not overwrite owned upgrade information.

---

## 26. Match Engine Technical Model

### 26.1 Match State

```text
MatchState
├── matchId
├── randomSeed
├── engineVersion
├── currentMinute
├── currentSecond
├── homeTeam
├── awayTeam
├── score
├── possession
├── formations
├── playingStyles
├── mentalities
├── substitutionsUsed
├── playerStates
├── teamStatistics
└── eventTimeline
```

### 26.2 Random Generator

```text
MatchRandomState
├── initialSeed
├── currentPrngState
└── drawCounter
```

The initial seed remains fixed.

The internal PRNG state advances with each random operation.

### 26.3 Match Events

```text
MatchEvent
├── eventId
├── matchId
├── minute
├── second
├── eventType
├── teamId
├── primaryPlayerId
├── secondaryPlayerId
├── eventOutcome
└── metadata
```

### 26.4 Match Commands

User actions must be recorded as timestamped commands.

Examples:

- Formation changed.
- Mentality changed.
- Playing Style changed.
- Substitution made.
- Live Action activated.

The Match Engine applies commands in chronological order.

Commentary, statistics, and player ratings must derive from the same event records.

---

## 27. Economy Configuration

All balancing parameters must be configurable.

```text
EconomyConfig
├── marketValueReference
├── economicValueCurve
├── sellingPercentage
├── packPriceCoefficients
├── packProbabilityCoefficients
├── upgradeCostCoefficients
├── divisionRewardCoefficients
├── matchRewardCoefficients
└── progressionRewardCoefficients
```

The economy must be recalculated and tested after player dataset updates.

Avoid uncontrolled inflation.

---

## 28. Firebase Integration

Firebase is used for supporting services only.

### Firebase Analytics

Track:

- Active users.
- Sessions.
- Match completion.
- Match results.
- Pack openings.
- Player selling.
- Player upgrades.
- Division progression.
- Advertisement engagement.
- Retention.

### Firebase Crashlytics

Track:

- Application crashes.
- Application version.
- Device information.
- Relevant diagnostic details.

### Firebase Cloud Messaging

Support:

- Game announcements.
- Updates.
- New seasons.
- Events.
- Optional return-to-game notifications.

### Firebase Remote Config

Optional controlled configuration updates.

Local defaults must always be available.

Remote Config must not arbitrarily modify saved user progression or perform destructive economy operations.

### Privacy

Collect only necessary information.

Follow applicable privacy requirements and platform policies.

---

## 29. Future Online Architecture

Online functionality is a separate future development phase.

The initial release must not depend on online services for gameplay.

### Future Backend Responsibilities

An authoritative backend will eventually be responsible for:

- User authentication.
- Online account management.
- Cloud progression.
- Online player ownership.
- Coin transactions.
- Online leagues.
- Multiplayer match coordination.
- Competitive rankings.
- Online tournaments.
- Anti-cheat validation.

### Online Competitive Integrity

For online competition:

- The server must validate match results.
- Rewards must be server-authorized.
- Coin transactions must be authoritative.
- Player upgrades must be validated.
- Users must not be able to submit arbitrary match results.

The existing local Match Engine should be structured so its rules can be reused or ported into an authoritative server implementation.

The online phase must define how simulation versions, random seeds, player data versions, and tactical commands are synchronized.

No online backend provider or multiplayer protocol is selected yet.

---

# PART 3 — TESTING & BALANCING

## 30. Economy Simulation

Run automated tests across:

- Low Market Value players.
- Medium Market Value players.
- High Market Value players.
- Different positions.
- Different Upgrade Levels.
- Database update scenarios.

Measure:

- Coins earned per season.
- Coins spent per season.
- Pack openings.
- Player collection growth.
- Upgrade frequency.
- Time needed to obtain stronger players.

## 31. Match Engine Simulation

Run thousands of simulated matches.

Measure:

- Average goals per match.
- Home win rate.
- Away win rate.
- Draw rate.
- Shots.
- Shots on target.
- Goal conversion.
- Cards.
- Stamina depletion.
- Tactical effectiveness.
- Division difficulty.

Test deterministic replay using the same seed and command sequence.

Test that changing tactics at minute 60 affects future events without altering earlier events.

## 32. Progression Simulation

Simulate multiple seasons.

Ensure:

- Promotion is achievable.
- Higher divisions are progressively harder.
- Relegation remains possible.
- AI clubs remain competitive.
- Rewards do not cause Coin inflation.

## 33. Advertisement Simulation

Test:

- Successful ad completion.
- Failed ad completion.
- Duplicate callbacks.
- Repeated reward requests.
- Daily limits.
- Match replay limits.
- Upgrade discount application.
- Selling bonus application.

The game must remain playable without watching advertisements.

---

# PART 4 — RELEASE SCOPE

## 34. Version 1 — Offline Release

### Included Features

- Club creation.
- Player database import.
- Player collection.
- Five pack categories.
- 36 starting packs.
- Player selling.
- Duplicate merging.
- Player upgrades.
- Squad management.
- Formations.
- Auto Pick.
- Tactical management.
- Stamina.
- Match Engine.
- Live commentary.
- Match statistics.
- Player match ratings.
- Pep Talks.
- Live Match Actions.
- Divisions.
- Seasons.
- Promotion and relegation.
- AI clubs.
- Dynamic Economy Engine.
- Rewarded advertisements.
- Local SQLite persistence.
- Firebase Analytics.
- Firebase Crashlytics.
- Firebase Cloud Messaging.

### Explicitly Excluded From Version 1

- Online multiplayer.
- Online PvP.
- Cloud Save.
- Backup Export.
- Backup Import.
- Real-money Coin purchases.
- Player trading between users.
- Coin transfers between users.
- Online marketplace.
- Gameplay backend.
- User-to-user competitive leagues.

---

## 35. Future Version — Online Expansion

Potential features:

- Online accounts.
- Cloud synchronization.
- Online leagues.
- Multiplayer matches.
- Online tournaments.
- Global rankings.
- Friends and rivals.
- Player marketplace.
- Player trading.
- Club competitions.
- Online seasonal events.

Each feature requires its own detailed technical and security specification before implementation.

---

# PART 5 — IMPLEMENTATION REQUIREMENTS

## 36. Development Rules

1. Implement the data model before building the full UI.
2. Implement the Player Database Engine first.
3. Implement the Economy Engine as a separate domain system.
4. Implement the Match Engine independently from Flutter widgets.
5. Keep owned player instances separate from global player records.
6. Preserve upgrades across database imports.
7. Use deterministic test seeds.
8. Write unit tests for all Coin transactions.
9. Write simulation tests for the Match Engine.
10. Validate database imports before applying changes.
11. Do not add online gameplay dependencies to Version 1.
12. Do not introduce cloud backup.
13. Do not introduce real-money Coin purchases.
14. Do not hardcode final balancing values before simulation.
15. Keep the architecture ready for future online services.
16. Do not over-engineer or introduce unnecessary abstractions.

---

## 37. Definition of Done

Version 1 is ready for release when:

- Player database import works.
- Base Stats regenerate correctly when Market Value or Position changes.
- Unchanged players preserve Base Stats.
- Player upgrades survive database updates.
- Removed players receive the exact normal selling value.
- Pack probabilities are validated.
- Economy simulations show stable progression.
- Squad management works correctly.
- Auto Pick respects positions and player ratings.
- Match Engine produces plausible football results.
- Match events, commentary, and statistics remain consistent.
- Tactical changes affect future match events immediately.
- Deterministic simulation works.
- Stamina consumption and recovery behave correctly.
- Division progression works over multiple seasons.
- Rewarded advertisements grant rewards exactly once.
- Local progression persists correctly.
- Gameplay works without internet.
- Firebase failures do not block gameplay.
- Supported low-end devices meet performance targets.

---

**END OF DOCUMENT**

**FCM Rivals — GDD & SRS v1.1**