# L2-AW06 — External Import Wiring + Reference Codec Compatibility

Status: **IMPLEMENTED / NON-PARITY EVIDENCE**

## Goal

Connect the AW05 external picker/File Provider acquisition boundary to the real `IOSAudioIOService` validation/finalization path and establish a fail-closed codec strategy for the current-iPhone Reference formats without changing frozen Shared/App contracts.

Reference-visible extensions tracked by Lane 2: MP3 / WAV / FLAC / M4A / MP4 / MOV / WMA.

## Implemented

### `IOSAudioIOService.importExternalFile(...)`

- accepts an external local URL plus `direct` or `securityScoped` acquisition mode;
- delegates ownership transfer to `IOExternalFileAcquirer` while external access is valid;
- performs storage preflight before the external copy;
- routes the complete staged file through the same AVFoundation playable/audio-track/PCM-decode validation used by app-owned and direct-download imports;
- finalizes only validated media into app-owned `Imports/`;
- maps acquisition failures to stable `DomainFailure` values/codes;
- cancellation and failed validation remove staging rather than exposing partial metadata.

Picker presentation, Photos APIs and share UI remain App/iOS-owned. This API is the Lane-2 adapter they can call during HQ late integration.

### Reference codec policy

`IOReferenceMediaCompatibilityPolicy` records the current reference extension matrix:

- native-probe route: MP3, WAV, FLAC, M4A, MP4, MOV;
- native-first + compatibility route: WMA;
- unknown extensions are not trusted or rejected only by name: AVFoundation content probing remains authoritative.

This avoids two incorrect shortcuts: claiming a format supported from its extension alone, or silently removing WMA because native Apple decoding may not cover it.

### WMA compatibility seam

`IOCompatibilityAudioDecoding` defines a Lane-owned production seam that converts a compatibility-only source to canonical app-owned WAV staging. `IOCompatibilityDecodeStaging`:

- requires the input to already be inside `Staging/`;
- never mutates/deletes the original input while decoding;
- creates a unique WAV staging destination;
- checks cancellation before/after decoder execution;
- rejects missing, directory/symlink, or zero-byte output;
- deletes failed/invalid compatibility output;
- keeps the original source available until the service decides the fallback result is valid;
- maps unavailable/failed/invalid decoder results to stable WMA-specific failure codes in `IOSAudioIOService`.

`IOSAudioIOService` always tries native AVFoundation validation first for WMA. Only `unsupportedMedia` enters the compatibility decoder path. A production compatibility decoder implementation is intentionally not faked in this wave.

## Tests committed

`IOReferenceMediaCompatibilityTests.swift` covers:

- all seven reference extensions;
- case/dot/whitespace normalization;
- native vs compatibility routing;
- non-reference extension behavior;
- successful canonical WAV staging;
- missing decoder fail-closed behavior;
- decoder throw cleanup;
- zero-byte output cleanup;
- original source preservation across compatibility failure.

`IOSAudioIOServiceExternalImportTests.swift` is Apple-gated and covers:

- real minimal PCM WAV external file -> external acquisition -> AVFoundation validation -> app-owned `Imports/`;
- no residual staging artifact after success;
- zero-byte external file rejection before import visibility.

## Executed evidence in current environment

Swift toolchain: **Swift 6.2.1 / x86_64-unknown-linux-gnu**.

Executed locally against the production-consumed IOFileStore surface:

- `IOReferenceMediaCompatibility.swift` strict-concurrency + warnings-as-errors typecheck: **PASS**;
- committed portable XCTest source strict-concurrency + warnings-as-errors typecheck: **PASS**;
- `IOSAudioIOService.swift` non-AVFoundation visible surface typecheck with frozen-contract-equivalent stubs: **PASS**;
- executable compatibility self-check: **PASS — 9 scenarios**;
- result marker: `L2_AW06_SELF_TEST_PASS scenarios=9`.

Self-check scenarios covered reference matrix/native routes, WMA compatibility route, unknown-extension behavior, successful canonical output, nil decoder, throwing decoder, empty decoder output, source preservation and no failed-output residue.

## Remaining Apple / product gates

The following are deliberately **not** claimed:

- actual Apple AVFoundation decode results for each MP3/WAV/FLAC/M4A/MP4/MOV fixture;
- actual WMA native behavior on the supported deployment target;
- a production WMA compatibility decoder implementation and its license/package audit;
- actual security-scoped File Provider execution on iPhone;
- camera-roll/Music/recording App adapters;
- physical-device storage-pressure interruption;
- MOI-P001 or MOI-P002 PARITY.

If the supported Apple runtime proves WMA is not natively decodable, HQ must allow the selected production compatibility decoder dependency to be linked into the iOS package/target; Lane 2 now has the stable injection seam and cleanup contract for that decoder.

## Next Lane-2 priority

Build the executable real-codec fixture matrix and import evidence schema for MP3/WAV/FLAC/M4A/MP4/MOV/WMA, while separately hardening production export validity/naming/batch cleanup and keeping actual Apple/iPhone runs explicit as HQ evidence gates.
