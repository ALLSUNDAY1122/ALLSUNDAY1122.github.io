# L2-AW05 — External File Acquisition Boundary

Status: **IMPLEMENTED / NON-PARITY EVIDENCE**

## Goal

Close the Lane-2 gap between an external picker/File Provider URL and app-owned durable IO staging without changing frozen Shared/App contracts.

This wave intentionally does **not** claim current-iPhone PARITY. App-owned presentation/picker UI, Apple runtime codec validation and physical-device evidence remain HQ late-integration gates.

## Implemented

### `IOExternalFileAcquisition.swift`

- accepts only local file URLs at the external-file boundary;
- rejects sources already inside the app-owned root to avoid ambiguous ownership;
- rejects missing files, directories, symbolic links, empty files and configured oversize inputs;
- performs storage preflight before copying;
- preserves the source filename stem/extension as metadata only; durable path ownership remains app-controlled;
- copies into the app-owned `Staging/` directory while external access is still held;
- verifies staged byte count exactly matches the inspected source byte count before returning;
- deletes staged output when post-copy verification fails;
- on Apple platforms, `securityScoped` mode holds `startAccessingSecurityScopedResource()` through `NSFileCoordinator` coordinated read/copy and fails closed if scope/coordination is unavailable;
- on non-Apple platforms, security-scoped acquisition fails closed rather than pretending provider access succeeded.

### `IOStagingRecovery.swift`

- sweeps only stale direct file/symlink children of app-owned `Staging/`;
- uses a caller-provided grace interval so a recent/concurrent acquisition is not treated as an orphan;
- does not recurse into staged directories or follow symlink targets;
- cleanup is idempotent across repeated relaunch recovery passes;
- invalid grace intervals fail closed.

## Negative / recovery coverage committed

`IOExternalFileAcquisitionTests.swift` covers:

- non-file URL rejection;
- missing source;
- directory source;
- empty source;
- oversize source;
- complete byte-for-byte staged copy;
- stable descriptor normalization;
- repeated same-file acquisition without staging-name collision;
- app-owned source rejection;
- non-Apple security-scope fail-closed behavior.

`IOStagingRecoveryTests.swift` covers:

- stale-vs-fresh staging discrimination;
- non-recursive directory retention;
- repeated sweep idempotency;
- invalid grace rejection.

## Executed evidence in current environment

Swift toolchain: **Swift 6.2.1 / x86_64-unknown-linux-gnu**.

Executed with `-strict-concurrency=complete -warnings-as-errors` using an `IOFileStore` seam matching the production methods consumed by these two new sources:

- source typecheck: **PASS**;
- executable acquisition/recovery self-check: **PASS — 11 scenarios**;
- result marker: `L2_AW05_SELF_TEST_PASS scenarios=11`.

The executable self-check covered invalid URL, missing/directory/empty/oversize source, valid copy/descriptor, collision avoidance, app-owned-root rejection, stale cleanup, cleanup idempotency and invalid recovery grace.

## Remaining Apple / product gates

The following are deliberately **not** claimed from Linux evidence:

- actual `startAccessingSecurityScopedResource()` behavior for Files/iCloud/File Provider URLs;
- actual `NSFileCoordinator` provider download/coordination behavior;
- camera-roll export URL behavior;
- AVFoundation decode/container compatibility after staging;
- actual iPhone storage-pressure interruption during provider copy;
- picker/share UX;
- MOI-P001/MOI-P002 PARITY.

## Next Lane-2 priority

Wire the external acquisition boundary through `IOSAudioIOService` media validation/finalization and then harden the reference codec/container matrix (MP3/WAV/FLAC/M4A/MP4/MOV/WMA), while keeping actual picker UI and physical-device evidence HQ-owned.
