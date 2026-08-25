# L4-W38 Validation｜Physical evidence archive chain

Status: **COMPLETE as Worker-4 NON_PARITY engineering wave**  
PARITY impact: **none**. MOI-P009/P011/P013/P016/P021 remain MISSING.

## Scope

W38 closes the archive-schema age gap identified after W35-W37. Historical W27 schema-v1 remains decodable and unchanged. A schema-v2 extension chain now anchors the exact W27 deterministic root and requires the post-W27 execution artifacts for every W24-predeclared run.

## Implementation

Added:

- `AnalysisPhysicalEvidenceArchiveChainV2.swift`
- `AnalysisPhysicalEvidenceArchiveChainV2Strict.swift`
- Package registration for both sources
- `AnalysisPhysicalEvidenceArchiveChainV2Tests.swift`
- `AnalysisPhysicalEvidenceArchiveChainV2StrictTests.swift`
- `ANALYSIS_PHYSICAL_EVIDENCE_ARCHIVE_CHAIN_RUNBOOK.md`
- `L4-W38_PHYSICAL_EVIDENCE_ARCHIVE_CHAIN.json`

### Required W38 per-run roles

- W35 runtime-algorithm evidence
- W36 current-runtime provenance summary
- W37 HQ capture plan
- W37 execution-integrity evidence
- W37 execution-integrity report

### Why a W36-specific archive summary exists

The historical W25 workload receipt type is also emitted by the current W36 runner. Archiving another W25 receipt alone therefore cannot prove that the W30-W34 current product runtime executed. W38 adds `AnalysisCurrentDeviceWorkloadArchiveEvidence`, binding W36 current-runtime acceptance, bounded source contract, observed source work, execution ID, outcome, snapshot and W35 companion explicitly.

## Canonical validation contract

Operational W38 validation uses `AnalysisPhysicalEvidenceArchiveChainValidator.validateStrict(...)`.

It fails closed before inner lookup construction when W24 planned run IDs are duplicated/non-exact. It also recomputes the W27 manifest root and requires the W27 declared root, archived report root/inventory, W27 policy/binding and W38 parent root to agree exactly.

The extension validator then requires one exact W35-W36-W37 chain per run and prevents W36 execution reuse across runs.

## Negative / adversarial coverage added

Durable XCTest source covers:

- missing required W35-W37 role;
- malformed/non-HQ W37 capture plan;
- artifact byte/hash/length tampering;
- cross-run W36 execution-ID reuse;
- parent W27 root swap;
- duplicate W24 planned run IDs;
- forged W27 report root;
- preservation/determinism of legacy W27 codec;
- deterministic W38 policy encoding;
- exact five-role inventory;
- valid two-run chain with distinct W36 executions.

## Portable validation actually observed

Environment:

- Swift 6.2.1
- x86_64 Linux

Observed source-shaped archive-chain mirror compiled with warnings-as-errors and executed **200,000/200,000** valid cases. Reused execution, missing role and duplicate planned-run adversarial inputs were rejected. Wall time was approximately **3.79 s** with maximum RSS approximately **17,920 kB**.

A separate deterministic-root Python mirror executed **200,000/200,000** records and confirmed that changing the parent W27 root or an artifact hash changes the W38 extension root. Missing-role and reused-execution adversarial cases failed closed.

These are portable engineering checks only. They are not physical evidence.

## Not observed in this Worker environment

A fresh full-worker-branch SwiftPM/XCTest run is not claimed because the Worker environment cannot DNS-resolve `github.com`, so the repository cannot be freshly checked out for canonical full-package execution here.

Also not observed:

- selected Xcode / Apple ARM compilation;
- physical-iPhone W23/W36/W37 execution;
- genuine Lane-2 bounded decoder runtime;
- real RSS / physical footprint / thermal / battery / cancellation timing;
- repeated W24 acceptance against HQ thresholds;
- independent HQ anchoring of W27/W38 roots;
- current-iPhone Moises quality differential.

No unobserved item is promoted to PASS.

## Remaining P021 gate

W38 makes final evidence packaging materially stricter, but it does not satisfy MOI-P021. Physical process telemetry remains authoritative. `BOUNDED_PULL_CONTRACT` is declarative and does not prove a decoder has no hidden whole-file buffers.

HQ must still integrate a genuine Lane-2 bounded decoder, execute W37 on selected physical iPhone hardware, perform repeated W24 worst-case acceptance, independently anchor the archive roots, and make the final PARITY decision.
