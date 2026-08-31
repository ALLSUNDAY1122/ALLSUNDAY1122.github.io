# Original World Layout Guide — Next2

This guide is original project content. It preserves only the systemic idea of compact platforming stages that become faster after ability acquisition; it does not reproduce reference-game room geometry.

## Global scale assumptions

Session A currently models player movement in abstract world units (`maxRunSpeed 7`, `jumpSpeed 12`, `gravity 34`). Session C's Godot shell is pixel-based. Final integration should use one explicit world-unit-to-pixel scale rather than retuning stage logic per device. Until that adapter is fixed, this file specifies route relationships and relative distances, not canonical pixels.

Each mandatory route is divided by checkpoints so an ordinary clear tolerates mistakes, while the fastest route intentionally skips recovery structure after later abilities are unlocked.

## Relay Yard

Shape: mostly horizontal onboarding route with two height changes.

Main route: Start → exposed belt hazard → moving lift → spring rise → CP1 → hazard weave → CP2 → moving-platform Goal.

Revisit: Dash opens a direct Start→CP2 cut. Double Jump exposes an elevated secret cache that returns to CP1. The shortcut is intentionally much faster but not useful before the player has demonstrated the basic route.

## Liftworks

Shape: vertical zig-zag with alternating elevator timing.

Main route: Start → lower lift → crusher lane → spring shaft → CP1 → upper lift → hazard timing → CP2 → moving-platform Goal.

Revisit: Dash bypasses the lower timing cycle. Double Jump reaches a ventilation secret from the upper lift. Moving-platform cycles use different periods so the optimal route is about cycle reading rather than waiting for synchronized platforms.

## Phase Foundry

Shape: branching mid-height route with two state switches.

Main route: Start → Amber switch → Amber gate → moving transfer → Cyan switch → Cyan gate → hazard lane → CP1 → Dash gate → CP2 → spring Goal.

Revisit: Wall Jump creates a Start→CP2 wall bypass. Double Jump reaches a secret vat from the Amber lane. The switch sequence is mandatory but secrets are never required.

## Blackout Array

Shape: long horizontal/vertical mixed route using sparse beacons.

Main route: Start in reduced visibility → beacon → Double Jump shaft → moving transfer → CP1 → blind hazard span → spring recovery → CP2 → memory hazard → CP3 → moving-platform Goal.

Revisit: Wall Jump opens a large Start→blind-span cut. Phase Shift later exposes an optional control-room secret. Base visibility is 0.42, deliberately above black-screen territory; local darkness zones may reduce it temporarily and must restore to the stage baseline, not to 1.0.

## Core Spire

Shape: synthesis route that alternates vertical rise and drop around a central core.

Main route: Start → Amber switch → Wall Jump Amber gate → moving rise → CP1 → hazard transfer → Cyan switch → Cyan gate → Double Jump drop → CP2 → spring chain → CP3 → Dash finish.

Revisit: Phase Shift creates the strongest Start→CP3 shortcut and a crown secret. This gives the final unlock an immediately measurable old-route/new-route effect rather than existing only as a key for a final door.

## Difficulty guardrails

- Main progression never requires a secret discovery.
- A state gate always has an accessible corresponding switch earlier on the mandatory route.
- Darkness changes route readability but never hides mandatory geometry completely.
- Every stage uses at least six gimmick categories.
- Later-ability shortcuts reduce abstract route length by at least two challenge edges.
- Hazards are mixed with timing, state, movement and visibility problems; no stage is designed as a spike-only corridor.
