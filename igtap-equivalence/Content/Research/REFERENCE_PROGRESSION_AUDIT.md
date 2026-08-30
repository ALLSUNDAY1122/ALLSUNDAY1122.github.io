# Session B Reference Progression Audit

Date: 2026-08-30
Scope: Progression / World only
Reference: public IGTAP demo / Steam materials / public player reports.

## Confirmed reference traits

- Core loop: complete short platforming courses -> earn currency -> buy production/movement upgrades -> unlock higher-income courses and faster routes in earlier courses.
- Clones replay an optimised route and generate passive income; better routes materially improve automation value.
- Current public demo exposes five numbered courses.
- Movement/exploration includes dash, double-jump, wall-jump interactions and advanced dash-wall-jump routing.
- Checkpoints are frequent enough that ordinary completion is more forgiving than full-run optimisation.
- Hidden bonuses exist outside the main route; public discussion identifies roughly nine secret bonuses in the current demo.
- A state/polarity switch changes traversability of coloured hazards/blocks.
- A late-game state shifts courses into a mostly-dark/emergency-light replay with higher income; prior course times are reset in the reference build.
- B-side/hard-mode reworks all five courses. Completing it unlocks level select in the reference build.
- Public feedback repeatedly identifies navigation friction, unclear stage 4 signposting, waiting-heavy economy ramps, and later courses becoming spike-heavy/repetitive.

## Observed numeric examples (NOT canonical formulas)

Public screenshots show values such as very large power totals, stage rewards from GW through PW/TW scales, clone reward multipliers, clone counts and best times. These are point observations only. We do not treat any screenshot price/reward as the authoritative economy equation.

## Design lessons to preserve

1. Skill and economy must reinforce each other: a better route should increase passive income.
2. New movement abilities must both unlock new content and create meaningful shortcuts in old content.
3. Optional secrets should be reachable early with high skill or later with stronger abilities.
4. Re-running old stages must remain economically relevant; later stages must not completely invalidate earlier stages.
5. Checkpoints support completion, while best-time/full-route play supports mastery.
6. Environmental state changes should create route re-evaluation, not merely recolour the same obstacle field.

## Design defects we intentionally do not copy

- Long manual travel between already-cleared courses.
- A rigid one-stage-at-a-time economy where the newest course makes all earlier courses irrelevant.
- Reliance on visually ambiguous pits or excessive spike-only difficulty.
- Unclear next-stage signposting.
- Upgrade effects whose value is not visible to the player.
- Forced waiting as the dominant activity between meaningful decisions.

## Original target world structure

Working world is intentionally original and uses five compact districts rather than reproducing any reference layout:

1. Relay Yard — onboarding, timer literacy, first automation loop.
2. Liftworks — vertical routing, moving-platform shortcuts, first ability gate.
3. Phase Foundry — state-switch routing and secret branches.
4. Blackout Array — reduced visibility, dynamic hazards and checkpoint risk/reward.
5. Core Spire — synthesis stage requiring learned movement + state logic, with multiple shortcut tiers.

Each district has: Start, Goal, 1-3 checkpoints, one mastery shortcut, one optional secret, and at least one later-ability revisit opportunity.

## Progression target

Baseline unlock arc (provisional, original):
- Relay Yard -> speed tuning / first clone capacity.
- Liftworks -> Dash gate.
- Phase Foundry -> Double Jump gate + phase switch.
- Blackout Array -> Wall Jump gate + visibility control.
- Core Spire -> advanced clone/economy upgrades and mastery loop.

Exact movement ownership remains Session A. Session B only declares gates/unlock state and never implements player physics.

## Acceptance targets for Session B

- No hard progression deadlock from a missed secret.
- Every mandatory unlock has at least one deterministic path from the prior mandatory content.
- Secrets accelerate progression but are never required to escape a softlock.
- Median intended active wait between meaningful purchases should stay under ~90 seconds during the demo-length arc; sustained waits above 180 seconds are treated as balance failures.
- At least 30% of earlier-stage production remains economically meaningful after the next stage opens, before global multipliers.
- Each newly unlocked movement ability must create at least two new opportunities: one forward gate and one backward shortcut/secret.

## Confidence policy

Confirmed = directly supported by official store/demo text or current official announcement.
Corroborated = repeated public player reports/screenshots.
Inferred = our design interpretation.
Any unknown exact reference value remains unknown until directly measured; it must never be labelled as the original game's exact value.
