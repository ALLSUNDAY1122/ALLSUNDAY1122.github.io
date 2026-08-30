# Session C status

## Bootstrap checkpoint — C 0/5

Date: 2026-08-30 JST

Reference inspected: current itch.io demo and public jam feedback. Only mechanics/experience are reference inputs; names, art, audio, prose and stage geometry are excluded from reuse.

Git state observed during bootstrap:

- Session A branch `igtap/wp1-core-gameplay`: `cba860926d2b1d3fd5ee27b595fd3d69e75a8d4c`
- Session B branch `igtap/wp2-progression-world`: `d277edcd3da30f4d2155562cfb39bfcade68ecfc`
- Session C bootstrap commit before integration merge: `bc2d2038a5f8c0e052a9c8e20f2627af7b0a29ab`
- integration bootstrap merge: `9feb0fb556b72f0b82fa904e23fd80f9b4f005e8`

Completed before Next 1:

- Canonical final Godot project root created at `igtap-equivalent/`.
- Shared semantic contract created in `Integration/INTERFACE_CONTRACT.md`.
- Landscape 1280x720 / expand scaling / iOS high-refresh baseline configured.
- Safe-area abstraction, normalized keyboard/touch input, virtual left/right/jump/dash/pause controls and lifecycle notification abstraction created.
- Mock core gameplay + mock progression connected so C can continue without A/B runtime code.
- Python contract/integration tests added and passed in GitHub Actions.
- Headless Godot parse/import added to CI using current stable 4.7.2.

Integration blocker discovered:

A currently declares Swift/SpriteKit-or-Metal implementation direction and B uses a second project root (`igtap-equivalence/`). This conflicts with the required Godot iOS export architecture and is not economically solvable with a normal adapter. GitHub issue #4834 records the required correction while preserving A/B semantic design work.

Next C milestone: Next 1 completes and hardens the iOS foundation, then produces a validated Godot project/export path without depending on A/B completion.
