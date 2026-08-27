# W47｜Physical iPhone real-audio corpus execution runbook

## Purpose

W47 binds the W46 Project-side audited Analysis report to one exact physical-iPhone corpus execution package. It is a **NON_PARITY provenance/readiness layer**. It never edits or promotes `PARITY_MATRIX.json`.

The intended chain is:

`canonical W22/W46 manifest bytes`
→ `genuine Lane-2 bounded decoder`
→ `one exact decoded source SHA per fixture`
→ `W36 current chunked Analysis runtime`
→ `unique workload execution + canonical snapshot`
→ `W47 fixture receipt`
→ `W47 audited Project report rebuilt only from retained snapshots`
→ `W46 expectedProjectReportSHA256`
→ `HQ Late Integration judgment`.

## Hard prerequisites

HQ must provide all of the following in the integrated Apple environment:

1. Canonical real-audio benchmark manifest bytes produced by `AnalysisRealAudioBenchmarkCodec.encodeManifest`.
2. Every fixture is `REAL_AUDIO` and has the rights state required by W46/W22.
3. A real Lane-2 adapter implementing `AnalysisPhysicalRealAudioChunkedDecoding`.
4. The adapter declares exactly `GENUINE_LANE2_BOUNDED_DECODER` and returns `.boundedPull` `AnalysisChunkedSignal` values.
5. The adapter returns the SHA-256 of the exact decoded source file and a unique decoder execution ID for each fixture.
6. A selected physical `iphoneos/arm64` build and one physical corpus session ID.
7. HQ-selected source revision, build identity, analyzer/config identity and Project engine/version.

Do not use the historical whole-signal compatibility adapter. It cannot create W47 physical evidence.

## Physical runtime gate

`AnalysisIOSPhysicalRealAudioCorpusCoordinator` only proceeds when compiled for:

- `os(iOS)`
- `arch(arm64)`
- not iOS Simulator
- not Mac Catalyst

A portable/Linux process may decode/reopen a retained W47 JSON package for integrity inspection, but it cannot create a physical-iPhone claim.

## Execution procedure

1. Retain the exact canonical manifest bytes before execution.
2. Supply those exact bytes to `AnalysisIOSPhysicalRealAudioCorpusCoordinator.capture(...)`.
3. Supply the genuine Lane-2 bounded decoder adapter.
4. Supply one `AnalysisIOSPhysicalRealAudioCorpusRequest` for the selected device/build/session.
5. W47 iterates **every manifest fixture**. There is no fixture-selection input.
6. For each fixture W47 verifies:
   - decoder source contract is `.boundedPull`;
   - source SHA exactly equals the manifest rights/source SHA;
   - channel count and descriptor are valid;
   - decoded duration agrees with the manifest tolerance;
   - decoder execution ID is nonempty and globally unique in the session.
7. W47 invokes `AnalysisCurrentDeviceWorkloadRunner` using the same W30-W34 current chunked Analysis runtime.
8. For each fixture W47 requires:
   - workload outcome `COMPLETED`;
   - unique workload execution ID;
   - exact complete Analysis stage order;
   - observed source chunk count > 0;
   - observed source sample count equals the declared decoded sample count;
   - `.boundedPull` algorithm evidence finalized for the same execution ID;
   - canonical snapshot bytes, snapshot SHA and output summary.
9. A failure/cancellation on any fixture aborts the corpus capture. No partial-success package is exported as ready.
10. After all fixtures complete, `AnalysisPhysicalRealAudioCorpusAssembler` revalidates the complete inventory and builds the Project audited report from the retained snapshots.
11. The package is immediately reopened. READY is returned only when reopen reports no issues.

## Exact inventory / anti-selection rules

W47 rejects:

- missing fixture receipts;
- duplicate fixture receipts;
- selective successful subsets;
- synthetic fixtures;
- simulator or non-arm64 runtime metadata;
- compatibility/unknown decoder kind;
- source SHA drift;
- decoded sample-count drift;
- duplicate run IDs;
- duplicate W36 workload execution IDs;
- duplicate decoder execution IDs;
- missing/out-of-order/non-completed W36 stages;
- invalid snapshot bytes/hash/summary;
- W36 execution-binding root mismatch.

A duplicate manifest fixture ID must fail canonical manifest validation and must not trigger a dictionary-construction trap.

## Audited Project report reconstruction

W47 does not trust a separately supplied Project quality report.

For each manifest fixture, it decodes the retained canonical W36 snapshot and recomputes the benchmark rows using the existing benchmark evaluators:

- tempo/BPM metrics;
- beat timing metrics;
- key metrics;
- chord metrics;
- structure/song-part metrics.

The resulting `AnalysisAuditedRealAudioBenchmarkReport` is deterministic for the retained fixture snapshots, manifest, runtime engine/version, configuration and report timestamp.

On reopen, W47 rebuilds the entire audited report again and requires byte-model equality with the retained report. It also recomputes:

- runtime binding SHA-256;
- Project audited report SHA-256;
- W47 package root SHA-256.

## W46 handoff

For W46, HQ must set:

- `expectedProjectReportSHA256` = W47 `auditedProjectReportSHA256`;
- Project engine/version = W47 runtime engine/version;
- Project source revision/build/device/OS/session fields = the exact W47 runtime binding.

HQ should separately retain the W47 package root as custody evidence. W46 currently pins the Project **report** root and runtime metadata; the W47 package root itself is an additional provenance artifact and should not be discarded.

## Trust boundary

W47 is tamper-evident, not cryptographic attestation.

The following remain metadata unless HQ independently attests/signs/trusted-timestamps them:

- genuine Lane-2 decoder identity;
- physical device model/OS;
- source revision/build identity;
- physical session identity.

The underlying rights-cleared source files and legal grants must remain retained outside the W47 JSON package. SHA-256 fields do not substitute for legal review.

## Expected status before real execution

Until a genuine integrated Lane-2 decoder and selected physical iPhone execute the exact rights-cleared corpus, there is **no real W47 READY package** and W46 cannot use W47 as physical Project provenance.

P009/P011/P013/P016 therefore remain `MISSING` until HQ receives real W47 + current-iPhone W19-W21 reference + W18/W46 differential evidence and independently judges the rows.
