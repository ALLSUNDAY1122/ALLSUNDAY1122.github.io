# MOI-SEP-002 — Partial implementation evidence / blocker

Captured: 2026-08-22 JST
Worker: `Moises-Worker-1`
Work package: `MOI-WP1-SEPARATION-PROCESSING`
Work branch: `moises/wp1-separation-processing`

## Status

`MOI-SEP-002` is **not Acceptance-complete** and must not be promoted to PARITY or INTEGRATION_READY yet.

The client/server boundary and a fail-closed commercial-rights checkpoint gate have been implemented so that the project can accept a real lawful separator backend without later replacing the HQ `SourceSeparationProviding` contract. However, canonical project state still lacks the executable production separator checkpoint and rights-cleared real multitrack/reference fixture corpus required to perform actual multi-genre inference and Golden QA.

## Implemented in this Wave

### iPhone/client separation provider

`Separation/Sources/ServerSeparationProvider.swift` implements the existing HQ-owned `SourceSeparationProviding` interface without changing `Shared/**`.

Behavior:
- source audio must already be under the app-owned data root;
- symlink-resolved path containment is enforced;
- long source audio is uploaded from a file URL instead of being materialized as one large `Data` buffer;
- requests carry project ID, asset ID, requested stem roles, quality profile and an idempotency key;
- job state maps to canonical `ProcessingSnapshot` phases and stable retry/error state;
- cancel uses idempotent HTTP DELETE and canonical state is observed via later snapshot polling;
- result retrieval is accepted only after terminal `ready` state;
- server response must preserve stable `projectID` and `stemID` values across relaunch/re-fetch;
- duplicate stem roles/IDs, invalid audio metadata, unsafe role names, unsafe extensions, insecure stem download URLs and path escapes are rejected;
- stem downloads are staged and atomically finalized under the app-owned root before `StemArtifact` exposure;
- HTTP/network/storage/cancellation failures are mapped to existing `DomainFailure` values.

### Server API contract expected by the provider

`POST /v1/separations`
- body: source audio bytes streamed from the app-owned source file;
- headers:
  - `Idempotency-Key`;
  - `X-Project-ID`;
  - `X-Asset-ID`;
  - `X-Stem-Roles`;
  - `X-Quality-Profile`;
  - optional runtime authorization supplied outside source control;
- response: `{ "jobID": "<uuid>" }`.

`GET /v1/separations/{jobID}`
- response fields: `jobID`, `phase`, `fractionComplete`, `retryable`, `stableErrorCode`;
- `phase` must map to the HQ enum: queued/uploading/separating/finalizing/ready/cancelled/failed.

`GET /v1/separations/{jobID}/result`
- legal only after job `ready`;
- response contains stable `jobID`, stable `projectID`, and one item per stem with stable `stemID`, role, HTTPS download URL, media extension, sample rate, channels, frame count and start time.

`DELETE /v1/separations/{jobID}`
- idempotent cancellation request;
- eventual cancelled/failed/ready state remains authoritative through snapshot polling.

### Fail-closed checkpoint rights gate

`Separation/Server/rights_gate.py` does **not** grant legal rights. It prevents a production server from booting a checkpoint whose local rights manifest fails project policy.

The gate requires:
- `commercial_inference_allowed = true`;
- `production_approved = true`;
- no Reference-output contamination;
- non-empty rights-record references;
- exact checkpoint SHA-256 match;
- rights basis either `PROJECT_OWNED_FROM_SCRATCH` or `EXPLICIT_WRITTEN_COMMERCIAL_GRANT`;
- from-scratch path requires a training-manifest hash and no uncleared pretrained initializer;
- known disallowed lineages such as official Demucs/HTDemucs pretrained weights, MUSDB/MUSDB-HQ, uncleared Spleeter pretrained weights and uncleared/noncommercial Open-Unmix lineages are rejected under the current verified licensing policy.

## Machine verification

### Swift contract/provider typecheck

Environment: Swift 6.2.1, x86_64 Linux.

A minimal Shared-shaped compile harness was used only to compile the provider against the signatures/types already fixed in `Shared/DomainContracts.swift`. It does not claim an iOS device build.

Result:
- `swiftc -typecheck DomainStubs.swift ServerSeparationProvider.swift`
- exit code: **0** after correcting cancellation authorization optional binding.

### Rights gate unit tests

Python `unittest`, 6 cases, all passed:
1. valid project-owned checkpoint + matching hash accepted;
2. checkpoint hash mismatch rejected;
3. `commercial_inference_allowed=false` rejected;
4. official Demucs/MUSDB lineage rejected;
5. missing training manifest for project-owned-from-scratch path rejected;
6. explicit written commercial grant path accepted without project training manifest.

Result: **6 tests / 0 failures**.

These machine checks prove contract/scaffolding correctness only. They do not prove separation quality or product parity.

## Why Acceptance is still blocked

The verified `MOI-SEP-LIC-001` decision requires either:
1. project-owned separator weights trained from scratch using rights-cleared real multitracks, or
2. an explicit written commercial grant/contract for the exact checkpoint/API and intended topology.

Current canonical repository evidence has neither an executable production checkpoint nor a written commercial API/model grant.

The verified Golden QA strategy additionally requires actual rights-cleared real music:
- G1 project-owned/explicitly licensed real multitracks with isolated sources for objective separation metrics;
- G2 rights-cleared real recordings that may be submitted to both Reference and project implementation for blinded differential listening.

The strategy sets the final separation proposal floor at 12 G1 songs and 12 G2 tracks with broad genre/production coverage. Canonical repository currently contains the strategy/rubric, not the required audio corpus and rights records.

Therefore the following Acceptance items cannot truthfully be executed now:
- real multi-genre audio produces actual separated stems;
- Golden objective/listening quality evidence;
- actual server inference latency/cost/failure evidence against the production model;
- P003/P004 promotion.

## Alternatives exhausted / available

Rejected under current verified policy:
- official Demucs/HTDemucs pretrained weights;
- uncleared Spleeter pretrained weights;
- noncommercial/uncleared Open-Unmix weights;
- MUSDB/MUSDB-HQ as commercial training/final gate assets;
- mock/identity/prebaked/synthetic-only stems.

There are two lawful unblocking routes:

### Route A — project-owned model
- acquire/commission rights-cleared real multitracks with explicit ML-training/commercial-result rights;
- train project-owned Demucs/HTDemucs-class weights from scratch;
- produce model card/training manifest/rights references/checkpoint hash;
- run this provider against the gated server and execute G1/G2 Golden QA.

### Route B — written commercial separation API/model agreement
- procure an API/model contract that explicitly permits this product's commercial use and intended processing topology;
- provision credentials outside GitHub;
- document retention/deletion/privacy and output rights;
- map the vendor response behind the existing provider/backend boundary;
- execute the same G1/G2 real-audio quality and recovery gates. A contract does not waive QA.

Route B can shorten training time but requires a human procurement/account/credential gate.

## Current PARITY impact

- `MOI-P003`: remains `MISSING`.
- `MOI-P004`: remains `MISSING`.
- `parity_state_changes = []`.

No `Shared/**`, `App/**`, Queue, resource-lock manifest or `PARITY_MATRIX.json` file is changed by this work package.
