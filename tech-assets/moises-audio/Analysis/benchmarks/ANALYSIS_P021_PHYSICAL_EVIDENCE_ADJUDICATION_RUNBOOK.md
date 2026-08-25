# L4-W45｜P021 physical-evidence adjudication runbook

## Purpose

W45 is the final fail-closed **readiness gate for HQ to judge MOI-P021**. It does not edit `PARITY_MATRIX.json` and it does not claim PARITY.

A successful result is only:

`READY_FOR_HQ_P021_JUDGMENT`

That status means the exact externally anchored evidence package is complete enough for HQ to inspect and make the separate P021 decision.

## Trust chain required

W45 requires all of the following as independent inputs:

1. current W43 ledger directory;
2. HQ-supplied W44 checkpoint expectation;
3. matching W44 checkpoint certificate;
4. exact W42 anchor receipt corresponding to the latest W43 record;
5. exact W41 transfer package;
6. HQ-supplied W45 runtime binding describing the selected Apple build, physical iPhone and genuine Lane-2 bounded decoder.

Production verification reopens W43 and W41 from disk. A cached W43 snapshot or copied W41 manifest is not accepted as a substitute for those reopen steps.

## W45 runtime binding

`AnalysisP021RuntimeBinding` must use:

- authority `HQ_LATE_INTEGRATION`;
- decoder origin `GENUINE_LANE2_BOUNDED_DECODER`;
- platform `iphoneos`;
- architecture `arm64`;
- nonempty decoder implementation and decoder source revision;
- nonempty selected Xcode / Swift / app source revision;
- exact build identity, bundle ID, app version and build version;
- exact physical device model, OS version and capture-session ID;
- exact W44 checkpoint-certificate root;
- exact W42 anchor-receipt root;
- exact W41 transfer root;
- one unique run/execution binding for every W24 planned run.

`COMPATIBILITY_ADAPTER`, `SYNTHETIC_FIXTURE`, `UNKNOWN`, simulator or non-arm64 bindings can never produce READY.

The runtime binding is HQ metadata. It becomes stronger provenance only if HQ separately signs or trusted-timestamps it; W45 does not mislabel SHA-256 commitments as signatures or Apple attestation.

## Evidence reopened from W41

W45 reopens the transfer package and then the published W40 payload. Required singleton evidence includes:

- W24 performance profile;
- W24 performance batch;
- W24 acceptance report;
- W25 workload policy;
- build corroboration;
- device corroboration.

For every W24 planned run, W45 requires exactly the W39 artifact chain:

- W23 performance evidence;
- W23 performance validation;
- W25 workload receipt;
- W25 workload validation;
- W35 algorithm evidence;
- W36 current-runtime evidence;
- W37 capture plan;
- W37 execution-integrity evidence;
- W37 execution-integrity report.

## Required recomputation

W45 does not trust cached success labels by themselves. It recomputes or revalidates:

1. W44 certificate against the current W43 ledger;
2. W42 anchor receipt root and latest-ledger binding;
3. W41 transfer package, W40/W38/W27 roots and exact run summaries;
4. archived W24 batch equality against per-run W23 bytes;
5. W24 acceptance at the original report evaluation timestamp;
6. W25 workload receipt validation and batch execution-ID uniqueness;
7. W35 exact run inventory and current-runtime identity;
8. W36 bounded-pull current-runtime binding and observed source work;
9. W37 capture-plan and execution-integrity validation;
10. W23 physical telemetry completeness.

## Physical evidence required per run

Every planned run must be `PHYSICAL_IOS_DEVICE` and must expose usable:

- resident memory;
- physical footprint;
- thermal state;
- battery start/end observations;
- memory-pressure observation channel;
- cancellation latency for cancellation probes.

Complete runs and cancellation probes must remain exactly the repeated run plan approved by W24. Missing, unexpected, duplicated or selectively dropped runs fail closed.

## Build/device corroboration

W27 build and device corroboration must describe the same execution selected by W24/W25 and the external W45 runtime binding. The gate rejects corroboration text that identifies the evidence as simulator, synthetic, mock, portable or compatibility evidence.

## Output

`AnalysisP021PhysicalEvidenceAdjudicationReport` records:

- W44/W42/W41 roots and identities;
- W24 profile/batch identity;
- planned and observed run counts;
- runtime-binding identity;
- per-run physical metrics/status;
- deterministic issue list;
- deterministic report SHA-256.

Persisted reports should be reopened with `AnalysisP021PhysicalEvidenceAdjudicationReportValidator`. The validator rejects a forged READY report even if the caller recomputes the report root while omitting required physical run facts.

## Decision boundary

`READY_FOR_HQ_P021_JUDGMENT` is not `PARITY`.

HQ must still inspect the real selected-iPhone evidence and decide MOI-P021. Worker 4 never edits PARITY.

## Current project state

Until genuine physical inputs exist, the expected W45 result is `NOT_READY_FOR_HQ_P021_JUDGMENT`. Portable Swift/SHA mirrors only verify gate behavior and deterministic commitments; they cannot satisfy the physical gate.
