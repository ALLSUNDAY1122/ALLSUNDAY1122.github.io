# Loopforge

Independent iPhone-oriented incremental platformer prototype inspired only by the *mechanical* idea of combining precision platforming with incremental progression. All names, art, stage layouts, text and audio are original placeholders.

## Godot

Target: Godot 4.x, GDScript, landscape iOS. Base viewport is 1280x720 with `canvas_items` + `expand`. iOS ProMotion is allowed; gameplay code must stay delta/physics-tick based rather than frame-count based.

## Session ownership

- Session A: `Player/`, `Physics/`, `Abilities/`, `Replay/`, `Ghost/`, `Camera/`
- Session B: `World/`, `Stages/`, `Gimmicks/`, `Economy/`, `Progression/`, `Upgrades/`, `UI/`, `Audio/`, `Content/`
- Session C: `Platform/`, `Integration/`, `Build/`, `Tests/Integration/`, iOS export/release files

Session C integrates A/B through adapters. Until A/B are present, `Integration/Mock/` keeps the project bootable and input-testable.
