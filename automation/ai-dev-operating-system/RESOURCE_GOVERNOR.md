# Desktop Resource Governor Contract

Purpose: prevent memory pressure, browser collapse, and network saturation while still allowing many registered ChatGPT sessions.

## Key distinction

- REGISTERED: known in session registry; no resource cost assumed.
- OPEN: browser tab exists.
- ACTIVE: currently generating/using tools.
- HEAVY_IO: upload/download/build artifact transfer.

Concurrency limits apply to ACTIVE and HEAVY_IO, not REGISTERED session count.

## Initial limits

- max_active_generations: 3
- max_heavy_io: 1
- max_codex_exception_jobs: 1
- max_new_wakes_per_dispatch_tick: 1

Start conservatively. Increase only after telemetry shows stable RAM/network behavior.

## RAM state machine

Input: OS memory usage percent and responsiveness signal.

- GREEN: <70% used
  - configured ACTIVE limit allowed
- YELLOW: 70-80%
  - no low-priority wake
  - reduce target ACTIVE by 1
- RED: >80%
  - no new wake
  - running sessions may finish/checkpoint
- CRITICAL: >90%, sustained swap pressure, browser unresponsive, or repeated renderer failure
  - dispatcher paused
  - low-priority OPEN tabs become unload/close candidates after canonical session registry is persisted

Use hysteresis before returning to a higher state to avoid rapid oscillation.

## Network state machine

Track:

- concurrent HEAVY_IO
- transport/retry errors
- generation request failures
- rolling response latency where observable

Rules:

- never run more than 1 HEAVY_IO job initially
- after repeated network/transport failures, lower ACTIVE limit one step
- restore only after a stable observation window
- do not wake a burst of sessions simultaneously; stagger wake starts

## Browser rules

- many sessions may be registered without keeping all tabs active
- use exact conversation identifiers, never tab order
- generating tabs are never intentionally refreshed/closed
- superseded/idle sessions may be unloaded after state is canonicalized
- session standard lifetime is 3 Macro Waves; rotate to reduce context/memory accumulation

## Scheduler priority

When capacity is available, choose in this order:

1. release-blocking / Sev-1/2
2. recovery of interrupted high-priority work
3. integration-unlocking work
4. normal READY work by portfolio priority
5. low-priority work only in GREEN

## Telemetry

Persist per dispatch interval or session wave:

- timestamp
- ram_used_percent
- active_generation_count
- heavy_io_count
- open_tab_count when available
- wake_attempts / wake_success
- transport_retry_count
- session_timeout_count
- completed_wave_count
- dispatcher_pause_reason

## Tuning rule

After a stable sample window, increase `max_active_generations` by at most 1. On memory/network degradation, decrease immediately by 1 or pause. The system optimizes completed verified waves per day, not raw simultaneous session count.
