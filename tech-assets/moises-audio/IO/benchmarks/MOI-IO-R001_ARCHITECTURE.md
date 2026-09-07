# MOI-IO-R001 — iPhone IO Architecture Decision

Captured: 2026-08-22 JST
Worker: Moises-Worker-3
Attempt: `task/MOI-IO-R001/attempt-1`
Scope: `tech-assets/moises-audio/IO/benchmarks/**`
PARITY rows informed: MOI-P001, MOI-P002, MOI-P019. This document does not raise PARITY.

## Boundary constraints

HQ-fixed `Shared/MODULE_BOUNDARIES.md` says IO owns supported audio/video import adapters, sandbox/file-lifetime handling at the import/export boundary, mix/stem export encoding/naming, and system share handoff. IO must return normalized local asset descriptors and must not leak external URLs as long-lived assumptions. Library persistence semantics and Separation/Playback/DSP algorithms remain outside this task.

Accordingly, this research selects an IO-only pipeline and does not create or redefine Shared protocols.

## Current reference contract used

Canonical Notion requirements and current Reference evidence establish these observable mobile requirements without copying Moises UI:

- Import entry exposes Files, Camera Roll, Recording, iTunes and Cloud Storage concepts.
- Observed/import-listed formats include MP3, WAV, FLAC, M4A, MP4, MOV and WMA.
- Cloud import accepts a cloud file or public URL; streaming-service links are not treated as valid downloadable song files.
- Import may progress to a project/player state before stems are ready, so acquisition/decode completion and separation completion are distinct states.
- Mobile export exposes separated tracks and a custom Audio Mix, with Save-to-device / Share behavior.
- Current official Moises Help documents mobile MP3/M4A output. Audio Mix includes key/speed/mix changes; separated stem export does not inherit key/speed edits.

Reference gaps remain UNKNOWN rather than implemented by guess: exact 2026 picker labels/order, per-source entitlement details, error-copy wording, exact export bitrate/quality, and exact destination defaults.

## Selected import architecture

### 1. Files / iCloud Drive / third-party File Provider

Use `UIDocumentPickerViewController(forOpeningContentTypes:asCopy:)` (or SwiftUI file importer backed by the same system facilities) with audio/movie UTTypes.

Implementation boundary:

1. User explicitly selects a file through the system picker.
2. If the returned URL is security-scoped, call `startAccessingSecurityScopedResource()` only for the acquisition transaction and balance it with `stopAccessingSecurityScopedResource()`.
3. Coordinate external reads with `NSFileCoordinator` where required.
4. Copy the selected asset to an app-owned staging URL, then atomically move it to the IO-owned durable local asset location after validation.
5. Release external access. Downstream modules receive only the normalized local descriptor through the eventual HQ Shared contract.

Rationale: Apple documents that document pickers access files outside the sandbox and can return security-scoped URLs; Apple also says external picker URLs should not simply be persisted. Copying into app-owned storage intentionally satisfies this project’s stricter boundary that external URLs must not become long-lived feature assumptions.

Cloud providers require no vendor-specific SDK for the baseline path: Apple’s document picker surfaces iCloud and third-party File Provider locations. A provider-specific integration can be added later only if verified reference behavior requires it.

### 2. Camera Roll / Photos video

Use `PhotosPicker` / `PHPickerViewController` filtered to video. For large media, request a file-backed Transferable representation rather than loading the whole asset into memory. Immediately copy the received temporary file into app-owned staging storage.

Apple explicitly recommends file representations for large assets such as video and states that the receiving app is responsible for file lifetime; received files should be copied to the app directory. PhotosPicker can fail while retrieving an iCloud Photos asset when network access is unavailable, so this is a retryable acquisition failure rather than a decode failure.

After the local copy is durable, use AVFoundation to locate the audio track and decode only audio for source separation. A video with no usable audio track fails deterministically as `NO_AUDIO_TRACK`.

### 3. Public URL

Use `URLSessionDownloadTask` to download HTTP(S) file content to a temporary file. For long transfers, a background `URLSessionConfiguration` is the selected resilience path because Apple documents that background download tasks continue while the app is suspended and may be reassociated after relaunch.

Validation sequence:

1. Only HTTP/HTTPS URLs enter the network path; prefer HTTPS/ATS-compliant resources.
2. Inspect response/status and expected length when available. A 2xx response is necessary but not sufficient.
3. Enforce configurable byte and duration limits before expensive decode where metadata is trustworthy.
4. Move the completed download from the temporary URL to staging before the delegate/completion lifetime ends.
5. Probe actual media with AVFoundation; do not trust extension or MIME alone.
6. Reject HTML pages, playlist/streaming-service pages, protected content, missing audio tracks, unsupported/corrupt media, and quota/storage failures with explicit error categories.

This intentionally implements direct downloadable media URLs, not extraction from protected streaming services.

### 4. Recording

Recording capture itself is not redefined in this research task. Any project-owned recorded file enters the same local validation/decode path once App/Recording provides a local URL through Shared composition.

## Selected decode architecture

Use `AVURLAsset` as the probe surface and async-load media properties/tracks. Before decode:

- reject protected media using async `hasProtectedContent`;
- require at least one audio track;
- load duration and media characteristics;
- check storage before creating large derivatives.

For audio-only files or an audio track inside MP4/MOV, use `AVAssetReader` + `AVAssetReaderTrackOutput` to obtain uncompressed linear PCM. Apple specifies that decoded audio output from `AVAssetReaderTrackOutput` uses linear PCM. Set `alwaysCopiesSampleData = false` when in-place modification is unnecessary to reduce copies.

The IO layer must not decide the Separation engine’s canonical sample rate/channel contract. It provides decoded PCM or an app-owned local asset descriptor according to the HQ Shared contract once MOI-ARCH-001 fixes that contract. If conversion is required by that contract, use AudioToolbox/AudioConverter at the IO boundary; do not duplicate separation preprocessing.

## Selected export architecture

### Native baseline: M4A/AAC

M4A/AAC is the selected Apple-native export baseline:

- AAC encoding is directly supported by Apple audio frameworks and sample code.
- `AVAssetWriter` can write media container files and re-encode samples.
- `AVAssetExportSession` exposes runtime `supportedFileTypes`, so capability must be checked rather than assumed for a preset/asset combination.

Export files are first rendered/written to an app-owned temporary URL, finalized, validated, and only then handed to a document exporter or `UIActivityViewController`.

### Separated stems

IO receives timeline-aligned stem artifacts from Separation through Shared/App composition. IO does not apply practice edits to these stems. Each stem is encoded independently with deterministic safe naming and the same reference time origin/duration semantics supplied by Shared.

For `Export All`, the container/packaging choice is an IO implementation detail; however, current iPhone reference behavior for ZIP packaging has not been directly reverified in the user recording, so packaging remains a reference-dependent detail rather than an assumed parity rule.

### Custom Audio Mix

Playback/DSP (not IO) must produce or expose an offline render representing the current mute/volume/key/speed state. IO then encodes that rendered timeline as one M4A/AAC file. This preserves module ownership: IO never reimplements speed, pitch, transport or mixing algorithms merely to export them.

Current Moises Help explicitly distinguishes Audio Mix (includes key/speed and other audio changes) from Separated Tracks (individual stems without those key/speed alterations). Count-in and transcribed lyrics are not exported in that reference behavior.

### MP3 parity dependency

Current Moises mobile Help exposes MP3 and M4A. Apple’s Core Audio documentation supports MP3 decoding, but Apple’s documented codec tables do not establish a native MP3 encoder and historical Core Audio documentation explicitly lists MP3 encode-from-PCM as unavailable. Therefore:

- Do not falsely claim Apple-native MP3 export parity.
- M4A/AAC is immediately implementable with system frameworks.
- Full MOI-P019 parity still needs a separately reviewed MP3 encoder path (commercially compatible on-device library or server-side encoder), including license/distribution review and real-device quality/performance evidence.

This is a known implementation dependency, not a scope deletion.

## System share / save

- Save/export to user-selected Files destination: system document export/file exporter.
- Share: `UIActivityViewController` with finalized file URLs.
- Never hand a partially written file to the share sheet.
- iPad popover requirements are handled by App presentation; iPhone is modal.

## Storage and lifecycle

Before import normalization, decode derivatives, or export render, query volume capacity using Foundation volume-capacity resource keys. Apple now classifies `volumeAvailableCapacityForImportantUsageKey` as a Required Reason API, so the shipping app must include the valid reason in `PrivacyInfo.xcprivacy` if this key is used.

Recommended reservation rule for later implementation validation:

- import copy: source bytes + safety margin;
- decode/PCM derivative: estimate from duration × sample rate × channels × bytes/sample plus overhead;
- export: estimated output + temporary-render headroom;
- on any insufficient-capacity signal, fail before destructive replacement and keep existing project artifacts intact.

IO owns temporary/acquisition/export-file cleanup. Library owns whether a durable normalized asset remains associated with a project after user deletion or resume.

## Error boundary

Canonical IO error categories proposed for HQ contract review (names are evidence proposals, not Shared changes):

- `ACCESS_DENIED`: security scope / picker / provider permission failure.
- `PROVIDER_UNAVAILABLE`: File Provider or Photos/iCloud retrieval unavailable.
- `NETWORK_UNAVAILABLE`, `NETWORK_TIMEOUT`, `HTTP_ERROR`: public URL transfer failures.
- `REMOTE_NOT_DIRECT_MEDIA`: HTML/playlist/non-media URL after download/probe.
- `UNSUPPORTED_MEDIA`: container/codec cannot be decoded.
- `PROTECTED_MEDIA`: AVAsset protected-content signal.
- `CORRUPT_MEDIA`: parser/reader fails after media was nominally recognized.
- `NO_AUDIO_TRACK`: video/container has no usable audio track.
- `STORAGE_INSUFFICIENT`: preflight or write ENOSPC-equivalent.
- `EXPORT_UNSUPPORTED`: selected output type is unavailable for current runtime/input.
- `EXPORT_FAILED`, `SHARE_FAILED`: encoder/finalization/share handoff failures.
- `CANCELLED`: user/system cancellation; must not be reported as corruption.

Retryability must be explicit. Network/provider temporary failures are retryable; protected/unsupported/no-audio are not; storage is retryable after cleanup; corrupt input is not automatically retried.

## Acceptance review

1. iOS-native audio/video/file import, sandbox lifetime, public-URL/cloud and failure boundaries: COVERED by the selected picker/PhotosPicker/URLSession -> app-owned durable copy -> AVFoundation probe/decode pipeline.
2. Codec/container comparison: machine-readable matrix accompanies this document.
3. Separated-stem + Audio-Mix export/share: COVERED with strict ownership boundary; edits are rendered upstream, IO only encodes/hands off.
4. Implementable iPhone path: SELECTED — system pickers + app-owned local normalization + AVURLAsset/AVAssetReader PCM decode + M4A/AAC native export + system document/share handoff.

Known gaps intentionally remain:

- MP3 export encoder path/licensing.
- Native WMA decode support is not established by current Apple iOS format documentation despite the Reference import label; requires runtime proof or an additional decoder/transcode path.
- Exact FLAC handling must be runtime-probed on target iOS versions; Apple exposes a FLAC AudioFormatID, but extension acceptance should not be inferred solely from that symbol.
- Exact bitrate/sample-rate/channel policy awaits HQ Shared contract and real-device quality gates.
- No PARITY row is raised by this research task.

## Authoritative sources

Apple:
- UIDocumentPickerViewController: https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller
- Providing access to directories / File Provider: https://developer.apple.com/documentation/uikit/providing-access-to-directories
- PhotosPicker: https://developer.apple.com/documentation/photosui/photospicker
- WWDC22 Photos picker file-lifecycle guidance: https://developer.apple.com/videos/play/wwdc2022/10023/
- CoreTransferable FileRepresentation: https://developer.apple.com/documentation/coretransferable/filerepresentation
- AVAssetReaderTrackOutput: https://developer.apple.com/documentation/avfoundation/avassetreadertrackoutput
- AVAsset protected-content async property: https://developer.apple.com/documentation/avfoundation/avpartialasyncproperty/hasprotectedcontent
- AVAssetWriter: https://developer.apple.com/documentation/avfoundation/avassetwriter
- AVAssetExportSession supported file types: https://developer.apple.com/documentation/avfoundation/avassetexportsession/supportedfiletypes
- URLSession background downloads: https://developer.apple.com/documentation/foundation/downloading-files-in-the-background
- URLSessionDownloadTask: https://developer.apple.com/documentation/foundation/urlsessiondownloadtask
- Volume capacity: https://developer.apple.com/documentation/foundation/checking-volume-storage-capacity
- Required-reason volume capacity key: https://developer.apple.com/documentation/foundation/urlresourcekey/volumeavailablecapacityforimportantusagekey
- UTType media identifiers: https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct
- UIActivityViewController: https://developer.apple.com/documentation/uikit/uiactivityviewcontroller
- AudioToolbox encoding/decoding sample: https://developer.apple.com/documentation/audiotoolbox/encoding-and-decoding-audio
- Core Audio format/codec reference (archived; used only for historical codec capability boundary): https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/CoreAudioEssentials/CoreAudioEssentials.html

Reference behavior:
- Moises mobile export: https://help.moises.ai/hc/en-us/articles/360013691720-How-do-I-export-my-file
- Moises export with edits: https://help.moises.ai/hc/en-us/articles/10554030191004-How-do-I-export-my-song-with-the-changes-made
