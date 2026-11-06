# L1-A15 Validation — Long-Track Streaming / Storage Pressure Hardening

Captured: 2026-08-24 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`  
Result: `COMPLETE_NON_PARITY`

## Goal

Make the Lane 1 separation route safe for long inputs and large multi-stem outputs without whole-file memory materialization, while refusing work early when storage is clearly insufficient and preserving A14 atomic-result guarantees if capacity disappears mid-transfer.

## Baseline audit

A15 did not replace working streaming behavior:

- the checked-in AudioShake multipart upload already reads the source file in 1 MiB chunks;
- the A06 server output downloader already streams the HTTP response in 1 MiB chunks directly to a staging file;
- source SHA-256 already scans in 1 MiB chunks;
- the Swift `URLSessionVendorOutputFetcher` uses download-to-temporary-file semantics instead of loading the response body as `Data`.

The missing hardening was around those streams: no capacity preflight, no explicit output-size cap, no durable transfer byte/time ledger, no formal download backpressure, and no preflight for A14's second full-set local copy.

## Server implementation

### `Separation/Server/long_track_io.py`

Introduces a configurable deployment policy and pure storage/streaming primitives.

Current defaults:

- source upper boundary: 2 GiB;
- transfer chunk: 1 MiB;
- estimated output: source bytes × 8 per target;
- maximum accepted single stem: source bytes × 16, with a minimum bound;
- storage safety reserve: 256 MiB;
- active output download transfers: 1 per orchestrator instance.

These values are **deployment guards, not Moises facts and not provider/PARITY evidence**. They are deliberately configurable and must be recalibrated from real codec/provider/device evidence later.

The guard provides:

- source-size validation;
- target-count-aware disk requirement estimation;
- injectable free-space measurement for deterministic failure tests;
- bounded-memory local stream copy;
- per-stream byte cap;
- stable `SEP_STORAGE_EXHAUSTED` mapping for ENOSPC/EDQUOT;
- partial destination cleanup on size/storage failure;
- transfer byte/chunk/time statistics.

### `Separation/Server/long_track_production_orchestrator.py`

Wraps the existing A06/A07 production orchestrator rather than forking its lifecycle semantics.

Two capacity gates are enforced:

1. before provider upload/create;
2. immediately before provider output download.

The output path uses a `BoundedSemaphore` and currently permits one active output transfer per orchestrator instance. The existing A06 staging → manifest → `os.replace` final promotion remains authoritative for server-side atomic output publication.

The default HTTP downloader additionally:

- validates HTTPS;
- rejects a declared `Content-Length` above the per-stem cap before reading the body;
- enforces the same cap while streaming when no trustworthy length is declared;
- fsyncs the destination;
- removes partial output on size/network/storage failure.

### Durable transfer telemetry

A separate atomic JSON ledger records only operational scalars:

- logical job ID;
- policy version;
- source byte count and target count;
- upload bytes / elapsed milliseconds;
- storage required/free/estimated bytes and preflight state;
- maximum allowed single-stem bytes;
- download bytes / elapsed milliseconds / count;
- largest transfer chunk;
- configured parallel-transfer limit;
- stable error code.

It intentionally does **not** persist the source filename/path, signed output URL, API credential or raw audio. A test-driven audit also found and fixed an initial non-reentrant telemetry lock that could self-deadlock on `get() -> _load()`; the store now uses an `RLock` while still serializing its local read/modify/write operations.

## A10 cost-guard integration

`BudgetedProductionSeparationOrchestrator` now routes through the long-track production wrapper.

Important ordering:

- source-size guard occurs before hashing, duration resolution and cost reservation;
- storage preflight failure after cost reservation but before provider create is a provably pre-create failure, so the A10 reservation is released;
- provider create ambiguity rules from A07/A10 remain unchanged;
- successful jobs expose both cost state and long-track transfer state.

This prevents an oversized multi-gigabyte source from being fully hashed merely to discover that it exceeds the configured production boundary.

## Swift / A14 storage accounting

### `Separation/Sources/SeparationStoragePreflight.swift`

The Swift assurance path now accounts for the actual A14 copy topology.

Before `prepare()` downloads any provider outputs:

- stale job-owned staging is removed first;
- if authoritative expected byte counts exist, they are used;
- otherwise the fallback estimate is `frameCount × channels × 8 bytes + 1 MiB WAV/header allowance` per stem;
- required space is all final staging bytes + the largest one-stem temporary download + 256 MiB reserve.

Before `commit()` touches an existing project final:

- every prepared file is revalidated first;
- required additional space is the complete verified stem set + 256 MiB reserve, because A14 copies the complete staging set into `incoming` before rename promotion;
- backup/final promotion itself is same-volume rename behavior and therefore does not require another full copy in this model.

All arithmetic is overflow-checked. Capacity shortage is `SEP_STORAGE_PREFLIGHT_INSUFFICIENT`, retryable, and happens before an existing final is moved aside.

## Machine verification

Local machine verification used synthetic/sparse data only and therefore cannot promote P021.

### Long-track IO stress

- **7 / 7 PASS**.
- Includes a **128 MiB + 123 byte sparse fixture** copied with 1 MiB reads.
- Python `tracemalloc` peak remained **below 8 MiB** in that stress case.
- Includes exact source boundary, above-limit rejection, storage formula, insufficient-capacity behavior, stream cap cleanup and empty-output cleanup.

### Production contract hardening harness

- **6 / 6 PASS** against an A06-compatible production contract stub.
- Covers source limit before provider calls, preflight before provider work, second preflight before download, durable telemetry, oversize output rejection and peak active download concurrency of one.

### Bounded HTTP output downloader

- **4 / 4 PASS**.
- Declared oversize rejected before body read.
- Undeclared oversize rejected during stream with partial cleanup.
- Successful byte/chunk/time accounting verified.
- Invalid `Content-Length` fails closed.

### AudioShake upload streaming regression

- **1 / 1 PASS** focused runtime harness.
- An 8 MiB + 123 byte sparse input was sent as multiple multipart body sends, each file-body send no larger than 1 MiB; total transmitted body bytes matched the file size.

### Telemetry lock regression

- Focused read/save/re-read regression: **PASS** after replacing the self-deadlocking non-reentrant lock with `RLock`.

### Swift storage preflight

- Swift compiler: 6.2.1, Swift language mode 6.
- The A15 storage-preflight implementation and actor extension compiled and ran successfully in a lane-local contract harness: **PASS**.
- Durable self-test source contains six focused estimate/overflow/retry scenarios: `Separation/Tests/L1_A15_StoragePreflightSelfTest.swift`.

Durable Python regressions are stored under `Separation/Tests/`, including long-track IO, production orchestration, bounded HTTP streaming, AudioShake streaming, cost/storage integration and early source-boundary ordering.

Machine-readable evidence:

`Processing/Tests/L1-A15_LONG_TRACK_MATRIX.json`

## Remaining boundaries

A15 closes the Lane Engineering long-track streaming/storage-pressure implementation gap, but not the P021 product-quality gate.

Still required:

- real iPhone RSS/memory-pressure measurements;
- background/interruption/relaunch behavior with genuinely long audio;
- thermal and battery evidence;
- real provider long-track latency and output-size distribution;
- calibration of the 8×/16× storage heuristics using actual supported source codecs and provider outputs;
- real disk-full tests on the integrated iPhone target;
- horizontal multi-instance resource coordination. The current semaphore is process/orchestrator-local and is **not** a global cluster-wide transfer limit;
- real provider/device differential evidence against current-iPhone Moises.

Free space can also change after any preflight. A15 therefore treats preflight as an early rejection optimization, not a guarantee: runtime ENOSPC/EDQUOT and A14 rollback/cleanup remain mandatory safety paths.

The current 2 GiB source cap follows the checked-in AudioShake/deployment boundary. It is not evidence that Moises has the same limit and is not a product PARITY ceiling.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

No `PARITY_MATRIX.json` row is promoted by A15. In particular, `MOI-P021` remains MISSING until HQ has integrated real-iPhone long-track memory/thermal/battery evidence and current-reference differential validation.
