# L1-A41 Validation — Crash-Resumable Long-Track Output Transfer

State: **COMPLETED_NON_PARITY**

## Product gap addressed

A15 already bounded source/output size, transfer chunk size, disk preflight and transfer concurrency. However, the inherited production collector deletes `<logical_job>.staging` at the beginning of each collection attempt and on failure. A process/network interruption during a large stem download therefore forced the next attempt to redownload that stem from byte zero.

L1-A41 adds a durable download cache outside ephemeral staging and resumes only when the remote object can be proven unchanged by a strong ETag plus exact byte-range/total-length checks.

## Implementation

- Added `Separation/Server/resumable_long_track_production_orchestrator.py` (`L1-A41-v1`).
- `CrashResumableLongTrackProductionSeparationOrchestrator` subclasses the A15 long-track production orchestrator, preserving its storage preflight, one-transfer backpressure, max-stem cap, telemetry and inherited atomic final-directory commit.
- Interrupted default HTTPS transfers retain partial bytes only when a strong ETag and positive total length were durably recorded first.
- Resume sends `Range: bytes=<prefix>-` and `If-Range: <strong-etag>`.
- HTTP 206 must carry the exact expected range start, total length and the same strong ETag. Any mismatch fails closed and removes the partial/state pair.
- If a server ignores Range and returns HTTP 200, A41 restarts from byte zero rather than appending to the old prefix.
- Signed output URLs are not persisted. The sidecar contains a SHA-256 URL reference, validator, expected byte count and completion flag.
- Complete cached stems are hard-linked into inherited ephemeral staging so the crash-safe cache does not require a second full-size copy before hashing/manifest generation. The extra cache link is removed only after the inherited atomic final-directory commit succeeds.
- `BudgetedProductionSeparationOrchestrator` now instantiates the crash-resumable wrapper, so the normal cost-guarded long-track production path uses A41.

## Failure and recovery semantics

A41 deliberately refuses unsafe resumption. Weak/missing ETag, URL rotation, validator mismatch, range mismatch, total mismatch, corrupt/unsafe sidecar, oversize output and storage exhaustion never result in byte splicing. Providers that do not expose a safe validator may still work, but an interrupted transfer restarts rather than reusing an unverifiable prefix.

Hard-link materialization assumes cache and staging are on the same artifact filesystem. If a deployment filesystem cannot provide that guarantee, A41 reports `SEP_OUTPUT_CACHE_LINK_FAILED` as retryable instead of silently creating another large copy. HQ may later provide an equivalent same-filesystem atomic/reflink strategy if required by the deployment target.

## Validation observed in this wave

An isolated interface-compatible Python execution compiled the A41 runtime/test candidates and ran **14 tests / 14 PASS / 0 failures / 0 errors**. Cases include interrupted resume, `Range` + `If-Range`, complete-cache reuse, signed-URL rotation, validator mismatch, missing strong validator, output cap, truncated body, raw-URL non-persistence, hard-link lifetime, Range-ignored HTTP 200 safe restart, bad Content-Range fail-closed, A41 runtime/regression presence and budgeted production wiring.

This isolated execution is not the exact repository-native final-tip full discovery. The exact A26 audit must be rerun on the final Worker 1 A41 tip before A26 can close.

## Non-claims

- No real provider Range/ETag behavior was observed.
- No rights-cleared real long-track audio campaign was run.
- No physical-iPhone memory, thermal, battery or storage-pressure evidence exists from this wave.
- No current-iPhone Moises differential was run.
- This does **not** promote MOI-P021 or any PARITY row.

## HQ follow-up

1. Run the one-command A26 audit against the exact final A41 Worker tip, not superseded A39/A40 tips.
2. During production-provider qualification, verify strong-ETag and Range/If-Range behavior using rights-cleared long audio and forced network/process interruption.
3. Verify the artifact filesystem supports the same-filesystem hard-link strategy or replace it with an equivalent no-double-copy materialization before production enablement.
4. Run physical-iPhone long-processing memory/thermal/battery/storage-pressure/relaunch evidence before considering P021 promotion.
