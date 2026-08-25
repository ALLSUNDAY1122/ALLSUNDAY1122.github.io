# Analysis Physical Evidence Transfer Verification Runbook

## Scope

L4-W41 is an integrity/transfer layer above W39/W40. It does not create physical-device evidence and it does not promote PARITY.

The source of truth for one export is an already-published W40 batch under `batches/<publicationID>` plus the W39 run directories referenced by that batch. W41 never treats a directory listing as evidence inventory.

## Source re-open audit

Call:

```swift
let reopened = try AnalysisPhysicalEvidencePublishedBatchReopener.reopen(
    publicationID: publicationID,
    archiveRootURL: archiveRootURL
)
```

The re-opener reads only the declared evidence/control paths and fails closed unless all of the following hold:

1. `W40_BATCH_MANIFEST.json` is schema 1 / `READY_TO_PUBLISH` and has unique safe run IDs and unique W36 execution IDs.
2. Exactly eleven W27 singleton roles are declared and their exact bytes/hash/length are valid.
3. All six W27/W38 documents are present and regular non-symlink files:
   - `w27-policy.json`
   - `w27-manifest.json`
   - `w27-report.json`
   - `w38-policy.json`
   - `w38-manifest.json`
   - `w38-report.json`
4. Every W39 run is reopened from `W39_BUNDLE_MANIFEST.json`; its nine declared artifacts are rehashed and its W39 bundle root is recomputed.
5. W39 control/artifact files must be regular non-symlink files whose resolved paths remain inside the archive root.
6. W27 manifest entries exactly equal the eleven singleton entries plus four declared W39 projections for every run.
7. W27 root is recomputed from the manifest and must equal both the W27 declared root and the W40 control root.
8. The cached W27 report is not used to establish the root. A deterministic successful report is reconstructed from the recomputed root/counts/known limitations, and the stored report must equal it exactly.
9. W38 manifest entries exactly equal five declared W39 projections for every run.
10. W38 root is recomputed and must bind the recomputed W27 root exactly.
11. The cached W38 report is likewise required to equal the deterministic reconstructed successful report.
12. W40 root is recomputed from the exact run summaries, eleven singleton records and recomputed W27/W38 roots.

For `N` W24 runs the re-open result contains exactly `18 + 10N` transferable source files:

- 1 W40 publication control
- 6 W27/W38 documents
- 11 singleton artifacts
- per run: 1 W39 publication control + 9 W39 artifacts

The old W39/W40 staging-marker files are transaction-control files and are intentionally not copied as evidence.

## Build a deterministic transfer package

Call:

```swift
let receipt = try AnalysisPhysicalEvidenceTransferExporter.publish(
    transferID: transferID,
    publicationID: publicationID,
    archiveRootURL: archiveRootURL
)
```

The resulting directory is:

```text
transfers/<transferID>/
  W41_TRANSFER_MANIFEST.json
  payload/
    batches/<publicationID>/W40_BATCH_MANIFEST.json
    batches/<publicationID>/w27-policy.json
    batches/<publicationID>/w27-manifest.json
    batches/<publicationID>/w27-report.json
    batches/<publicationID>/w38-policy.json
    batches/<publicationID>/w38-manifest.json
    batches/<publicationID>/w38-report.json
    batches/<publicationID>/singletons/...
    runs/<runID>/W39_BUNDLE_MANIFEST.json
    runs/<runID>/... nine W39 artifacts ...
```

Every transfer item records:

- item kind
- original source relative path
- payload relative path
- optional run ID / role
- SHA-256
- exact byte length

`declaredTransferRootSHA256` is a deterministic SHA-256 over the transfer ID, publication ID, W40/W27/W38 roots, sorted run summaries and sorted transfer item metadata.

## Atomic staging and recovery

W41 writes to:

`transfers/.w41-staging-<transferID>-<first16(transferRoot)>`

The stage receives `W41_STAGING_MANIFEST.json`, the exact payload, and `W41_TRANSFER_MANIFEST.json`. The package is verified before publication. The source W40/W39 evidence is then reopened again; if it changed after initial snapshot creation, publication stops.

Only an existing stage with the exact expected transfer ID/root/count marker can be removed and rebuilt. Any corrupt marker, missing marker, or a different `.w41-staging-<same transferID>-<different root>` is ambiguous and is preserved for HQ inspection.

Before the final same-parent rename, the W41 staging marker is removed. Therefore the final transfer directory has an exact manifest-declared file inventory and no staging marker.

Existing final `transfers/<transferID>` is never overwritten or automatically deleted.

## Destination verification

After any copy or transfer, call:

```swift
let manifest = try AnalysisPhysicalEvidenceTransferVerifier.verify(
    transferDirectoryURL: copiedTransferDirectory
)
```

Verification fails on:

- missing/truncated/replaced payload bytes
- mismatched SHA-256 or byte length
- unsafe path or path rebinding
- duplicate source/payload path
- role/run rebinding
- undeclared regular files
- symbolic links
- missing declared files
- transfer-root drift
- stale W39 root/execution binding
- W27/W38/W40 root drift
- stale cached W27/W38 reports

The verifier reopens `payload/` as a standalone evidence root and recomputes W39 → W27 → W38 → W40 again. It then rebuilds the expected W41 manifest and requires exact equality.

## HQ handoff procedure

For real P021 evidence, HQ should:

1. Execute the exact HQ W24 physical-iPhone runs through W37/W39.
2. Freeze the selected W39 run directories.
3. Build W40 with the exact eleven HQ singleton artifacts.
4. Record W39/W27/W38/W40 roots independently from the evidence tree.
5. Build W41 transfer package.
6. Record the W41 transfer root independently before copy.
7. Copy the complete `transfers/<transferID>` directory.
8. Run destination verification.
9. Compare destination-recomputed W39/W27/W38/W40/W41 roots to the independently recorded values.
10. Only then use the package as an input to HQ physical-device acceptance. P021 remains MISSING until the actual device/performance gate passes.

## Security and evidence limitations

W41 roots are tamper-evident metadata roots, not signatures, Apple attestation, Secure Enclave proofs, trusted timestamps or hardware-origin evidence.

A party able to rewrite an entire unanchored W39/W40 evidence tree and all of its roots consistently before W41 is created can produce another internally consistent W41 package. Preventing that requires an independently anchored prior root or an external signing/timestamp system. W41 intentionally does not claim to supply that authority.

W41 reopens the source immediately before and after transfer publication, but cannot atomically lock the separately stored W39/W40 source directories together with the new transfer directory.

Portable Linux filesystem validation does not establish APFS/iPhone durability or physical-device origin.

`BOUNDED_PULL_CONTRACT` remains declarative; physical RSS/physical-footprint/thermal/battery/cancellation telemetry remains authoritative for MOI-P021.
