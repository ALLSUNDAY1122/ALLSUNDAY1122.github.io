# Session B UI / UX Spec

This document describes original project UI behavior. It does not reproduce reference-game art, text, layout or branding.

## Persistent HUD

The always-visible information hierarchy is:

1. exact formatted Flux balance;
2. current Flux/s;
3. global echo allocation / capacity;
4. current stage + timer + best time;
5. one explicit next-objective sentence.

The player should never need to infer whether they are waiting for a stage clear, an ability purchase or an unlock condition from color alone.

## Stage UI

Each stage card shows:

- stage name;
- READY / CLEARED / MASTERED / LOCKED text state;
- explicit locked reason;
- best time;
- mastery target;
- assigned echo count and per-stage cap.

Stage playability must come from `ProgressionWorld.stage_availability`, not raw StageManager unlock state.

## Upgrade UI

Each upgrade card shows:

- original upgrade name;
- level;
- cost;
- current → next numeric effect;
- KEY marker for mandatory progression upgrades;
- short description;
- explicit status: Ready / Need more Flux / prerequisite / MAX.

Mandatory progression items should remain visually and textually distinguishable from optional tuning, but optional tracks remain available after the current key gate is purchased.

## Clone allocation

Echo controls use explicit minus / count / plus controls. The plus control is disabled when either:

- global capacity is exhausted; or
- the stage has reached the per-stage cap of 3.

Global capacity reaches 15 at max progression, allowing all five stages to hold three echoes. This prevents the optimal economy from collapsing into placing every clone on only the newest stage.

## Accessibility / iPhone

- Minimum interactive control height: 48 logical UI units in the B reusable panel.
- Body text target: 18; headers: 22–24 before C applies device-specific scale.
- No state communicates through color alone.
- Locked reasons and upgrade effects are written in text.
- Scrolling is vertical only in the progression panel to avoid horizontal gesture conflict with movement controls.
- Session C owns final Safe Area placement and touch-control avoidance.
- The progression panel should not cover movement buttons while gameplay is active; C may use a pause/menu presentation or a side drawer.

## Darkness readability

Blackout-stage darkness must never hide required interaction silhouettes, objective text, checkpoint feedback or the progression HUD. World visibility may change behind the CanvasLayer UI, but critical UI remains full-opacity.

## Feedback

`Game/Audio/FeedbackBus.gd` emits semantic original events only:

- `upgrade_purchase`
- `ability_unlock`
- `clone_capacity`
- `stage_unlocked`

Session C may connect these to original sound assets and Haptics. No reference audio is included or implied.

## Anti-friction rules

- Stage Select remains available for cleared/unlocked content; no mandatory long traversal between courses.
- A failed purchase never removes resource.
- The next mandatory objective is always visible.
- Replay/clone automation is optional for progression: active repeated clears alone can reach every mandatory ability gate.
- No secret is required for mandatory progression.
- The UI must not show a raw-unlocked stage as playable if its required ability is still locked.
