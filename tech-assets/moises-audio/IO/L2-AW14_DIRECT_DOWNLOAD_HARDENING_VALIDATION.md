# L2-AW14 Direct Download Acquisition Hardening Validation

## Scope

Worker 2 lane-local hardening only. This wave does **not** claim Moises PARITY and does not modify Shared/App/PARITY/Queue/Work Packages/Lane Plan/Resource Locks.

Selected after re-reading the current Notion v4 canonical, Worker contract, Work Package, Lane Plan, Worker 2 status, Resource Locks and PARITY ledger. Assignment epoch remains 2; HQ integration epoch advanced to 9. MOI-P001 and MOI-P002 remain MISSING.

## Problem found

The existing `IOSAudioIOService.importDirectDownload` uses `URLSession.download(from:)` and checks `maximumDownloadBytes` only after the download finishes (plus response `expectedContentLength` after the response is returned). This means a response with absent/incorrect Content-Length can consume network and temporary-disk capacity beyond the configured product limit before the app rejects it.

Other gaps in the direct public URL boundary were:

- redirect count was delegated entirely to URLSession;
- HTTPS -> HTTP redirect downgrade was not explicitly rejected;
- obvious localhost/private/link-local IP literal targets were not rejected;
- URL userinfo credentials were accepted;
- HTTP 206 partial content could pass the generic 2xx gate;
- only a narrow HTML/HLS MIME denylist existed, leaving generic `text/*`, JSON/XML and DASH error/manifest payloads to download fully;
- final extension/name came from the original URL, so redirects or query-only download URLs could lose a useful media extension;
- there was no explicit production composition seam ensuring only a fully completed remote download is handed to the existing media-probe/import path.

## Production change

### `IODirectDownloadAcquisition.swift`

Adds a Foundation/URLSession lane-local direct-download boundary:

- `IODirectDownloadPolicy`
  - accepts only HTTP/HTTPS;
  - rejects URL userinfo credentials;
  - rejects obvious local-network literals/names (`localhost`, `.local`, loopback, RFC1918, link-local, CGNAT, IPv6 loopback/link-local/ULA/multicast);
  - bounds redirects (default 5);
  - rejects HTTPS -> HTTP downgrade;
  - classifies HTTP retryability: 408/425/429/5xx retryable, other HTTP errors non-retryable;
  - rejects 206 partial content;
  - rejects clearly non-direct payload MIME types (`text/*`, JSON/XML families, HLS, DASH);
  - enforces both Content-Length/expected-length cap and streaming-progress cap;
  - rejects empty completed files;
  - derives filename/extension from final response metadata first, with MIME fallback for MP3/WAV/FLAC/M4A/MP4/MOV/WMA.

- `IOBoundedDirectDownloadTransport`
  - uses a one-shot `URLSessionDownloadDelegate`;
  - cancels the task while bytes are arriving as soon as `totalBytesWritten > maximumBytes`;
  - performs storage preflight when response size is known and again before app-owned staging;
  - moves bytes into `Staging/**` only from `didFinishDownloadingTo`, after status/MIME/size validation;
  - verifies the staged file is regular and byte-identical in size before returning it;
  - removes staged output if task completion subsequently resolves as failure/cancellation;
  - defaults to an ephemeral URLSession configuration to avoid persistent cache/cookie state for public URL acquisition.

### `IOBoundedRemoteAudioImporter.swift`

Adds the production `AudioImporting` composition seam for public URL imports.

- `.appOwnedFile` requests pass through unchanged.
- `.directDownloadURL` is acquired through `IODirectDownloading` first.
- Only the completed app-owned `Staging/**` file is handed to the wrapped importer as `.appOwnedFile`.
- The handoff staging file is removed after success or failure.
- If the process terminates after bounded acquisition moved the file into Staging but before handoff completes, existing `IOStagingRecovery` owns stale-file cleanup after its grace period.
- The wrapped importer remains authoritative for AVFoundation media probing, protected/no-audio/corrupt detection, final `Imports/**` publication and MP3/WAV/FLAC/M4A/MP4/MOV/WMA compatibility behavior. WMA is therefore not removed or bypassed.

The current raw `IOSAudioIOService` direct URL branch is left source-compatible in this Worker epoch because replacing its private implementation would require a whole-file edit and cross-target Apple validation. The canonical AW14 production composition is to inject `IOBoundedRemoteAudioImporter(baseImporter: IOSAudioIOService(...))` as `AudioImporting` into `Lane2DurableLifecycleCoordinator`. HQ/App must not inject the raw service directly for public-URL imports once AW14 is integrated.

## Security / privacy boundary

The local-network deny rule covers literal/private hosts detectable before a request. It does **not** prove that an arbitrary public hostname will not resolve/rebind to a private address after DNS resolution. Final DNS-rebinding/local-network enforcement requires Apple/network-layer evidence or a resolved-endpoint policy not exposed by the frozen Shared contract; this remains an HQ/device gate.

The default URLSession configuration is ephemeral. Callers may inject another configuration for controlled tests/integration, but production should retain an ephemeral/no-persistent-cookie configuration for unauthenticated public URLs. Authenticated cloud/file-provider import remains a separate File Provider/security-scoped path rather than smuggling credentials into a direct public URL.

## Executed portable validation

Environment: Swift 6.2.1, Linux x86_64.

Executed in this Worker session:

- `IODirectDownloadAcquisition.swift` strict-concurrency / warnings-as-errors typecheck against the fetched `IOFileStore` method surface via contract-equivalent stub: PASS.
- `IOBoundedRemoteAudioImporter.swift` strict-concurrency / warnings-as-errors typecheck against frozen `AudioImporting`/DomainFailure contract-equivalent stubs: PASS.
- `IODirectDownloadAcquisitionTests.swift` and `IOBoundedRemoteAudioImporterTests.swift` strict XCTest typecheck: PASS.
- production wiring static audit: PASS 14/14 checks.
- executable self-check: PASS, marker:
  `L2_AW14_SELF_TEST_PASS scenarios=10 policy_iterations=100000 elapsed_seconds=0.356493`

Self-check coverage includes:

1. public URL acceptance plus localhost/private-IP rejection;
2. HTTPS downgrade and redirect-limit rejection;
3. 429 retryable vs 404 non-retryable status classification;
4. 206 and non-direct text/JSON/HLS/DASH rejection;
5. header-size and mid-stream byte-cap enforcement;
6. final response filename/extension recovery;
7. completed Staging -> wrapped `.appOwnedFile` handoff and cleanup;
8. existing app-owned import bypassing the downloader;
9. stable `REMOTE_FILE_TOO_LARGE` DomainFailure mapping;
10. 100,000 policy URL/progress validations.

The `0.356493 s` figure is a Linux policy/value benchmark only. It is not a network throughput, URLSession delegate latency, iPhone disk, or media-import performance measurement.

A Linux `URLProtocol` attempt was intentionally not used as runtime PASS evidence because FoundationNetworking crashed inside its download-task URLProtocol bridge on this runner. The production `URLSessionDownloadDelegate` code itself strict-typechecks, but its live delegate behavior remains an Apple test gate rather than being misreported as validated.

## Negative / recovery invariants

- oversize Content-Length rejects before publication;
- absent/incorrect Content-Length is still bounded by streaming progress and final size;
- no partial/oversize/error payload is moved into `Imports/**`;
- redirect downgrade/private literal/credentialed URLs fail before media probing;
- 206 is not accepted as a complete media object;
- response HTML/JSON/XML/HLS/DASH is rejected before media probing;
- app-owned Staging handoff is removed after base importer success/failure;
- existing stale Staging recovery handles a process death after successful download staging;
- final media validation remains AVFoundation/compatibility-decoder owned;
- WMA native-first + compatibility-decoder scope is preserved.

## Gates intentionally still open

The following remain unverified and are not marked PASS:

- actual Apple/iPhone execution of `URLSessionDownloadDelegate` streaming cancellation and redirect callbacks;
- real public URL downloads with unknown/chunked Content-Length, redirects, 429/5xx, slow/stalled responses and cancellation;
- DNS-rebinding/private-resolution behavior for non-literal public hostnames;
- authenticated cloud URL behavior (intentionally separate from public direct URL acquisition);
- actual iPhone Files/iCloud/File Provider/security-scoped/NSFileCoordinator behavior;
- real MP3/WAV/FLAC/M4A/MP4/MOV/WMA fixture execution and WMA production decoder/license audit if native decode is unavailable;
- integrated App selection/UX for public URL vs File Provider routes;
- Apple Core Data accumulated runtime gates;
- real AVFoundation export/share/playback and storage pressure;
- Differential Moises and final PARITY judgment.

## Integration requirement

At Lane-2 late integration, use the hardened wrapper as the importer composition:

`IOBoundedRemoteAudioImporter(baseImporter: IOSAudioIOService(...))`

and inject that wrapper into `Lane2DurableLifecycleCoordinator`. The raw `IOSAudioIOService` can still be retained for its lane-local external File Provider bridge and export functions, but should not be the directly injected `AudioImporting` instance for public URL requests after AW14.

## PARITY statement

`COMPLETED_NON_PARITY` for L2-AW14.

This wave materially hardens the public/direct URL acquisition path for MOI-P001/P002 preparation, but actual current-iPhone reference route inventory, real public/cloud/device imports and integrated error UX remain required. No PARITY row is promoted from this Worker evidence alone.
