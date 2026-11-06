# L1-M03 — Production separation output assurance / retention / cost validation

Bundle: `L1-M03`  
Lane: `LANE-1-SEPARATION-PROCESSING`  
Assignment epoch: `2`  
Frozen Shared/App contract: `17d129c9f0faaf7f24a96439cf3aa3cd0e7c02e8`  
PARITY impact: **NONE. P003/P004/P020/P024 remain MISSING until real provider, rights-cleared real audio, device/recovery and privacy evidence exist.**

## Implemented

### 1. Provider output manifest and production validation

`Sources/SeparationOutputAssurance.swift` introduces a provider-neutral run manifest containing:

- project/job identity;
- provider ID/kind, model name/version and quality profile;
- exact requested stem roles;
- per-output stem ID, role, HTTPS download URL, URL expiry, container, sample rate, channels, frame count and duration;
- optional vendor byte count / SHA-256;
- measured upload/queue/inference/download timing inputs;
- currency, cost total, unit usage/basis and actual-vs-estimated flag;
- vendor/local retention and delete timestamps/policy.

Manifest validation fails closed on missing/duplicate roles, duplicate stem IDs/URLs, insecure URLs, unsupported containers, inconsistent duration metadata, invalid sample/channel/frame metadata, invalid cost fields and invalid retention/delete ordering.

### 2. Project-controlled copy before vendor URL expiry

`prepare()` requires at least 30 seconds of URL validity by default both before and after the fetch call. It never stores a vendor URL as the final product artifact.

Outputs are copied to app-owned job staging and verified before the result set is eligible to commit. Current production assurance intentionally accepts WAV only because AudioShake's evaluated core route supports WAV and WAV permits deterministic local format verification without trusting vendor metadata.

Verification is streaming/bounded where material:

- HTTPS and expiry window;
- actual file byte count;
- SHA-256 computed locally using a streaming implementation;
- RIFF/WAVE identity;
- PCM/IEEE-float WAV format support;
- sample rate;
- channel count;
- frame count derived from data bytes/block alignment;
- duration tolerance (default 20 ms);
- optional vendor-provided byte count/hash comparison.

The positive fixture is checked against externally known SHA-256 constants, so the internal SHA implementation is not tested only against itself.

### 3. Complete-set staging and crash-safe commit

No output becomes final until every requested stem has been downloaded and verified. Any corrupt or incomplete stem removes the job staging directory and leaves the previous final stem set untouched.

Commit prepares a complete incoming directory, verifies copied hashes, backs up the current project stem directory, then swaps in the complete run. `recoverInterruptedCommit()` handles a crash between rename steps, including the case where the parent final directory no longer exists.

If ledger persistence fails after the swap, the backup is intentionally retained so recovery can restore the previous run.

### 4. Retention and delete safety

`FileSeparationRunLedgerStore` durably records `prepared / committed / deleted`, verified hashes/byte counts, final artifacts, cost and retention inputs.

`deleteLocalRun()` deletes a committed project stem directory only when:

- every expected file exists;
- every hash still matches the recorded run; and
- the directory's non-hidden file-name set exactly matches the run.

This prevents an old ledger from deleting a newer run whose files changed or which added an extra stem.

Vendor deletion is evidence-only until an approved live provider exposes contractual/API deletion semantics. The manifest records request/confirmation timestamps but this lane does not invent upstream deletion.

### 5. Existing Shared provider seam integration

`Sources/AssuredSeparationProvider.swift` preserves the frozen `SourceSeparationProviding` contract. `start / snapshot / cancel` delegate to the selected controller; `result()` instead consumes a `SeparationRunManifestProviding` manifest and returns `StemArtifact` only after L1-M03 assurance succeeds.

A committed result is hash/file-set verified and reused without redownloading. The raw controller's `result()` is deliberately bypassed in the executable test, preventing unverified vendor outputs from crossing the Shared artifact boundary.

### 6. Flat live-provider JSON contract

`Sources/SeparationRunManifestCodec.swift`, `Evaluation/schemas/live-provider-output-run.schema.json`, and `Evaluation/examples/live-provider-output-run.template.json` define one flat provider-facing JSON shape.

The same shape can be populated later by:

- an AudioShake production backend;
- a project-owned model backend; or
- another approved server provider.

The root field `evidence_state` is fixed to `NON_PARITY_EVIDENCE_ONLY`; a run manifest cannot self-promote PARITY.

## Machine verification

Executed with Swift 6.2.1 on Linux:

- production assurance + manifest codec + Shared-seam adapter: `-strict-concurrency=complete -warnings-as-errors` compile — **PASS**;
- executable file/fault self-test — **`L1_M03_SELF_TEST_PASS scenarios=18`**;
- JSON Schema Draft 2020-12 structural check — **PASS**;
- provider template validation with format checking — **`L1_M03_SCHEMA_PASS`**.

The 18 scenarios cover:

1. prepare -> verify -> commit -> delete happy path;
2. expiring URL rejected before any fetch;
3. duplicate role rejection;
4. duplicate stem-ID rejection;
5. corrupt WAV / partial-set cleanup with old final preserved;
6. sample-rate mismatch;
7. frame-count mismatch;
8. expected SHA-256 mismatch;
9. invalid cost and retention inputs;
10. delete protection after a newer file replaces a tracked stem;
11. crash recovery restoring an old directory backup;
12. file-backed ledger roundtrip of hashes/cost/retention;
13. missing output count;
14. unsupported container;
15. expected byte-count mismatch;
16. delete protection when a newer run adds an extra stem;
17. `AssuredSeparationProvider` bypasses raw unverified result and caches the committed verified result;
18. flat provider JSON codec feeds the assurance pipeline without redesign.

Generated WAVs are mechanics-only fault fixtures. They are not separation-quality or PARITY evidence.

## Remaining external / late-integration gates

- Production credentials and approved commercial/privacy/retention/deletion terms remain absent.
- No live AudioShake or project-owned model result has populated this manifest yet.
- No rights-cleared G1/G2 real-audio quality run exists.
- No actual vendor output-expiry race, billing, delete confirmation or cancellation behavior has been measured.
- No current-iPhone storage/background/relaunch/device evidence exists.
- The app/server composition must inject `AssuredSeparationProvider` (and the L1-M02 stable-start capability where selected) at HQ Late Integration.

Therefore this bundle satisfies the L1-M03 **output validator/accounting layer** done-when, but does not change PARITY.
