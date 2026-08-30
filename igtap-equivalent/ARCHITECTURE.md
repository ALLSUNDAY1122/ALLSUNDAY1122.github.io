# Architecture and merge boundary

Project root: `igtap-equivalent/`.

Session A and Session B never depend on each other's concrete node paths. They expose capabilities to Session C through the contract in `Integration/INTERFACE_CONTRACT.md`. Session C owns the adapters and may detect either production implementations or mocks at boot.

The integration path is:

`InputRouter -> CoreGameplayAdapter -> Stage/World -> lap_complete -> ProgressionWorldAdapter -> economy/upgrades/unlocks -> CoreGameplayAdapter capability update`.

Rules:

1. Production gameplay code must not read iOS touch nodes directly; it reads normalized actions from `InputRouter`.
2. Production world/progression code must not reach into player internals; it consumes contract events or adapter methods.
3. Save payloads are plain Dictionaries with versioning owned by Session C.
4. Fixed-step gameplay is required. Visual interpolation may run at 120 Hz, but physics/economy outcomes cannot depend on display refresh rate.
5. Original reference-game names, art, audio, prose, and stage geometry are forbidden from shipping assets.
