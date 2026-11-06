# MOI-IO-001 Validation

Captured: 2026-08-22 JST
Worker: Moises-Worker-2
Work Package: `MOI-WP2-IO-LIBRARY`
Branch: `moises/wp2-io-library`
Task: `MOI-IO-001`
Owned scope: `tech-assets/moises-audio/IO/**`
PARITY rows informed: `MOI-P001`, `MOI-P002`, `MOI-P019`

## Result

Source-level IO implementation is complete for the HQ-fixed `AudioImporting` / `AudioExporting` contracts without changing `Shared/**`, `App/**`, `Package.swift`, global tests, resource locks, Queue, or PARITY.

This task does **not** claim iPhone runtime PARITY. Canonical `Package.swift` currently excludes `IO/**`, and the iOS host/target is explicitly owned by Worker 4. Therefore real-device compile/runtime/export/share evidence remains a later platform integration gate.

## Implemented import/decode seam

`IO/Sources/IOFileStore.swift` provides an app-owned transaction store:

- only normalized relative paths are accepted;
- `..`/absolute path escape is rejected;
- external/app-owned source bytes are copied into `Staging/` first;
- successful assets are moved into `Imports/` only after validation;
- failed/cancelled staging files are cleaned;
- download temp files are moved or copied across volumes while preserving a useful extension when available;
- deterministic filename sanitization prevents path/control characters from escaping the IO root;
- storage headroom is preflighted before copy/export using filesystem free-space metadata.

`IO/Sources/IOSAudioIOService.swift` conforms to HQ `AudioImporting`:

- `.appOwnedFile(relativePath:)` is re-staged and normalized rather than leaking caller file lifetime assumptions;
- `.directDownloadURL(URL)` accepts only HTTP(S), checks status/size, rejects HTML/xhtml/playlist MIME types as `REMOTE_NOT_DIRECT_MEDIA`, then stages the downloaded file;
- `AVURLAsset` checks protected content and playability;
- an audio track is mandatory and video-with-audio is distinguished from audio-only;
- `AVAssetReaderTrackOutput` is started with 32-bit float Linear PCM settings and must produce a first sample before the durable `LocalAudioAsset` is returned;
- the returned descriptor contains a fresh `AssetID`, app-owned relative path, media kind and duration; external URLs do not cross the Shared boundary.

This is a real decode probe, not extension/MIME-only acceptance.

## Implemented M4A/AAC export/share seam

The service also conforms to HQ `AudioExporting`.

An IO-owned `IOExportSourceProviding` adapter supplies already-rendered custom mixes or separated stem files. This keeps DSP/mixing outside IO and avoids redefining Shared contracts.

For each source:

1. Resolve only an app-owned relative path.
2. Preflight storage.
3. Use `AVAssetExportSession` with `AVAssetExportPresetAppleM4A`.
4. Require `.m4a` in runtime `supportedFileTypes`.
5. Export to `Staging/` and propagate cancellation to `cancelExport()`.
6. Re-probe the finished M4A and require a decodable PCM sample.
7. Move only a validated file into `Exports/`.
8. Return `ExportArtifact(relativePath:, mediaType: "audio/mp4")`.

`customMix` requires exactly one upstream render; `separatedStems` may emit multiple independent M4A artifacts. IO never applies key/speed/mix DSP itself.

`finalizedURL(for:)` resolves only finalized app-owned export artifacts and is the handoff seam for a document exporter or `UIActivityViewController`; presentation remains App-owned.

## Explicit failure boundary

HQ `DomainFailure` is used directly where possible. Additional stable detail is carried through `processingFailed` / `exportFailed` codes without changing Shared.

Covered source/error decisions:

- access denied -> `accessDenied`
- provider unavailable -> `providerUnavailable` through `IOAcquisitionErrorMapper`
- external acquisition network loss -> `networkUnavailable`
- user/system cancellation -> `cancelled`
- direct URL timeout -> `networkTimeout`
- HTTP status -> `HTTP_ERROR_<status>` with retryability for 408/429/5xx
- HTML/playlist URL -> `REMOTE_NOT_DIRECT_MEDIA`
- protected AVAsset -> `protectedMedia`
- no audio track -> `noAudioTrack`
- unsupported/decoder/file-format failure -> `unsupportedMedia`
- corrupt/failed reader -> `corruptMedia`
- no disk space / preflight failure -> `insufficientStorage`
- unsupported requested export container -> `exportFailed("EXPORT_UNSUPPORTED")`
- missing upstream export source -> stable export failure
- missing finalized share artifact -> stable export failure

Provider picker/Photos presentation itself is intentionally not implemented here because current HQ `ImportRequest` accepts only app-owned files and direct URLs; system picker/Photos acquisition belongs to the iOS/App composition layer. IO exposes the stable provider/acquisition failure mapping for that adapter.

## Validation performed in this Worker environment

Swift toolchain: Swift 6.2.1, Linux x86_64.

Executed:

- `swiftc -typecheck IOFileStore.swift IOFileStoreTests.swift -module-name MoisesIOTests` -> PASS.
- executable file-transaction self-check -> `PASS traversal stage import export finalize`.
- `swiftc -typecheck IOFileStore.swift <Shared-equivalent contract stubs> IOSAudioIOService.swift` -> PASS for the cross-platform declarations and conditional-compilation syntax.

The Linux host cannot import AVFoundation, so these commands are **not** iOS compilation or runtime proof. No such claim is made.

## Branch scope review before handoff

Task base was refreshed to integration head `c3843c57816fa636e364c9f5225b56f5828b01e3` after confirming the only newer canonical differences were per-worker status metadata. The implementation commits after that base are confined to `tech-assets/moises-audio/IO/**`.

## Known gaps kept visible

1. **iOS compile/device execution pending** — canonical Package currently excludes `IO/**`; Worker 4 owns Package.swift and `iOS/**`. `MOI-BLD-IOS-001` must compile this source with AVFoundation and execute device/simulator scenarios.
2. **M4A runtime artifact evidence pending** — source code validates exports by re-opening and decoding a PCM sample, but this branch cannot execute AVFoundation on Linux. A real M4A fixture and system share handoff must be exercised under the iOS target before any P019 readiness claim.
3. **MP3 export parity gap remains** — no Apple-native MP3 encoder is claimed. A lawful encoder/server path and real-device evidence are still required before reference MP3 export parity.
4. **WMA import gap remains** — native iOS WMA decode is not claimed.
5. **FLAC exact target-iOS support remains runtime-probe dependent**.
6. **Photos/File Provider UI acquisition** remains an App/iOS composition task; IO starts at the app-owned local file boundary and provides explicit provider error mapping.
7. **P001/P002/P019 remain MISSING** until HQ receives actual iPhone integration/device evidence and closes their full Reference gates.

## HQ integration requests

- When Worker 4 reaches the iOS platform task, include `IO/Sources/**` in the iOS target and wire `IO/Tests/**` or equivalent platform tests without moving ownership of IO source.
- Compose `IOExportSourceProviding` from canonical stem artifacts / upstream custom-mix render. Do not make IO reimplement Playback/DSP.
- Add real-device scenarios for Files/File Provider, direct URL, protected/corrupt/no-audio/storage failures, M4A separated stems, M4A custom mix, cancellation, and system share.
- Keep MP3/WMA/FLAC gaps visible until separately proven; do not silently downgrade the Reference scope.

No `PARITY_MATRIX` file was changed by Worker 2.
