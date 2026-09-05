# Original World Layout Guide — Next2/Next4

This guide is original project content. It preserves only the systemic idea of compact platforming stages that become faster after ability acquisition; it does not reproduce reference-game room geometry.

## Global scale assumptions

Session A currently models player movement in abstract world units while Session C's Godot shell is pixel-based. Final integration should use one explicit world-unit-to-pixel scale rather than retuning stage logic per device. Until that adapter is fixed, this file specifies route relationships and relative distances, not canonical pixels.

Each mandatory route is divided by checkpoints so ordinary completion tolerates mistakes, while later-ability routes intentionally skip recovery structure for mastery/clone optimisation.

## Relay Yard

Main route: Start → belt hazard → moving lift → spring rise → CP1 → hazard weave → CP2 → moving-platform Goal.

Revisit: Speed Tune opens a direct Start→CP1 tuned-belt route immediately after the first clear. Dash later opens the stronger Start→CP2 cut. Double Jump exposes an elevated secret cache returning to CP1.

## Liftworks

Main route: Start → lower lift → crusher lane → spring shaft → CP1 → upper lift → hazard timing → CP2 → moving transfer → CP3 → Goal hazard.

Revisit: Dash bypasses the lower timing cycle with Start→CP1. Double Jump reaches a ventilation secret from the upper lift and returns near CP2.

## Phase Foundry

Main route: Start → Amber switch → Amber gate → moving transfer → Cyan switch → Cyan gate → hazard lane → CP1 → Dash gate → CP2 → spring → CP3 → moving-platform Goal.

Revisit: Wall Jump creates a Start→CP2 wall bypass. Double Jump reaches a secret vat from the Amber lane. The switch sequence is mandatory; the secret never is.

## Blackout Array

Main route: Start in reduced visibility → beacon → Double Jump shaft → moving transfer → CP1 → blind hazard span → spring recovery → CP2 → memory hazard → CP3 → moving transfer → CP4 → Goal hazard.

Revisit: Wall Jump opens the large Start→blind-span cut. Phase Shift later exposes an optional control-room secret returning near CP3. Baseline visibility is 0.42 and local darkness restores to that baseline, never blindly to 1.0.

## Core Spire

Main route: Start → Amber switch → Wall Jump Amber rise → moving transfer → CP1 → hazard transfer → Cyan switch → Cyan gate → Double Jump drop → CP2 → spring → CP3 → Dash gate → CP4 → moving-platform Goal.

Revisit: Phase Shift creates the strongest Start→CP3 shortcut and a crown secret. This is an endgame mastery unlock rather than a key required for the first Core Spire clear.

## Difficulty / progression guardrails

- Main progression never requires a secret discovery.
- A state gate always has an accessible corresponding switch earlier on the mandatory route.
- Darkness changes route readability but never hides mandatory geometry completely.
- Hazards are mixed with timing, state, movement and visibility problems; no stage is a spike-only corridor.
- `speed_tune`, `dash`, `double_jump` and `wall_jump` each have both a forward progression use and a prior-stage revisit use.
- `phase_shift` is the post-Core endgame exception: it has multiple revisit shortcuts/secrets rather than a sixth mandatory stage gate.
