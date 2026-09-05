# Session B Next3 Evidence — Incremental Economy

Date: 2026-08-31 JST
Branch: `igtap/wp2-progression-world`
Implementation commit: `ab61fdeaadaabebf29fc58aab440888ff342334a`

## Scope completed

- Big-number resource storage using mantissa + base-1000 exponent.
- Atomic resource add/spend with negative/NaN/infinite input rejection.
- Active lap reward calculation with bounded speed scaling.
- Clone cycle reward calculation with bounded speed and route-quality scaling.
- Passive clone income aggregated at 0.25 second economy ticks.
- Clone route replacement policy: faster routes replace slower routes; slower routes cannot degrade existing cycle time or route quality.
- Per-stage clone counts as a public hook for Next4 capacity progression.
- Three geometric economic upgrade tracks with stage-clear availability gates.
- Resource formatting from Flux through YFlux and scientific fallback without changing stored values.
- Aggregate `ProgressionWorld` production root matching Session C's existing adapter surface.
- Precision-preserving economy signals in parallel with Session C's legacy float compatibility signals.
- Economy/upgrades integrated into aggregate serialize/restore state.

## Balance model

Original base active rewards at target first-clear time:

- Relay Yard: 14 Flux
- Liftworks: 40 Flux
- Phase Foundry: 120 Flux
- Blackout Array: 330 Flux
- Core Spire: 850 Flux

Clone cycle reward uses 72% of base reward before bounded speed/route-quality/multiplier effects. Faster routes increase both per-cycle reward and cycle frequency, so route skill materially improves automation value.

Mastery clone RPS results at one clone per stage:

- Relay Yard: 1.8508 Flux/s
- Liftworks: 3.4555 Flux/s
- Phase Foundry: 7.8148 Flux/s
- Blackout Array: 15.5208 Flux/s
- Core Spire: 30.3633 Flux/s

Previous-stage share when compared with the newly unlocked next stage:

- Relay Yard vs Liftworks: 34.88%
- Liftworks vs Phase Foundry: 30.66%
- Phase Foundry vs Blackout Array: 33.49%
- Blackout Array vs Core Spire: 33.83%

All exceed the 30% guardrail, so a newly unlocked stage does not immediately make its predecessor economically meaningless.

## Upgrade tracks

1. `flux_coils`: first cost 18 Flux, growth ×1.72, passive income ×1.18/level, available after Relay Yard clear.
2. `loop_compression`: first cost 115 Flux, growth ×1.88, clone reward ×1.16/level, available after Liftworks clear.
3. `route_dividend`: first cost 400 Flux, growth ×2.00, active lap reward ×1.14/level, available after Phase Foundry clear.

Sequential target-play simulation, buying the first level of each track when it becomes available:

- Flux Coils: 9.52 s wait
- Loop Compression: 50.16 s wait
- Route Dividend: 65.04 s wait

All are below the 90 s target and well below the 180 s failure threshold.

## Validation

Local reconstructed progression tests:

- `test_economy_balance.py`
- `test_big_resource_contract.py`
- result: `10 passed`

Balance simulation confirmed:

- first-clear clone RPS: 0.4200 / 0.8471 / 1.8783 / 3.8323 / 7.4634
- mastery clone RPS: 1.8508 / 3.4555 / 7.8148 / 15.5208 / 30.3633
- prior-stage pair share floor: 30.66%
- sequential first-upgrade wait maximum: 65.04 s

Large-number stress model normalized `9.75e15 × 1000^180` into exponent group 185, equivalent to decimal exponent 555. Storage and suffix formatting remain separate.

## Failures / risks found and fixed during Next3

1. Session C's adapter declares `currency_changed(total: float)`, which cannot carry arbitrary-size resource snapshots. Fixed by keeping `BigResource` authoritative while emitting a clamped float projection only for adapter compatibility.
2. A slower newly recorded route could preserve best cycle time but overwrite route quality with a worse value. Fixed so slower routes cannot degrade either time or quality; equal-time routes may only improve quality.
3. Dynamically added economy/upgrade children may not all have completed `_ready` at the exact parent setup point. Initial multiplier/context publication is deferred with `_finish_ready`.
4. Economic upgrades could otherwise be purchased early by injecting enough resource. `upgrade_availability` now enforces the declared stage-clear milestone before purchase.
5. Upgrade-spend balance simulation was initially optimistic because it treated each unlock independently. Replaced with a sequential simulation that spends earlier upgrade costs and applies their multipliers before later waits.

## Validation limitations

- Godot is not installed in the execution environment, so GDScript could not be run through the Godot parser/runtime.
- Python tests validate balance data, contract/source invariants and the large-number design model. GDScript runtime behavior still requires Session C's Godot integration test.
- Direct repository checkout remains unavailable from the execution container; GitHub connector reads/writes were used for authoritative repository changes. Test files were reconstructed locally with the same authored content and current stage timing data.

## Public API changes

`ProgressionWorld` now implements:

- `add_resource`
- `spend_resource`
- `current_resource`
- `resource_per_second`
- `calculate_clone_reward`
- `set_clone_count`
- `purchase`
- `purchase_upgrade`
- `upgrade_availability`
- `current_level`
- `current_cost`
- `resulting_effect`
- `economy_snapshot`
- aggregate `serialize_state` / `restore_state`

Session C-compatible signals on the production root:

- `stage_context_changed`
- `currency_changed`
- `upgrade_purchased`
- `ability_unlocked` (reserved for Next4 emission)
- `clone_income_applied`

Precision-preserving additions:

- `economy_changed`
- `economy_rate_changed`
- `upgrade_purchase_committed`

## Integration attention

1. Session C currently instantiates `MockProgression`; it must bind `ProgressionWorld.gd` when integrating Session B. Session B did not modify Session C-owned bootstrap/adapter files.
2. Session C's float currency signal is compatibility-only. Final Session B UI should read `BigResource` snapshots through `economy_changed`, `current_resource`, and `ResourceFormatter` to avoid precision loss.
3. Clone income begins only after an accepted lap supplies a non-empty replay payload. This preserves the core gameplay contract that automation is based on a recorded run rather than appearing for free.
4. Next4 must add authoritative ability unlocks and clone-capacity progression, then compose StageManager unlock state with WorldState entry requirements into one UI availability result.
5. No Session A/C owned files were changed in Next3.
