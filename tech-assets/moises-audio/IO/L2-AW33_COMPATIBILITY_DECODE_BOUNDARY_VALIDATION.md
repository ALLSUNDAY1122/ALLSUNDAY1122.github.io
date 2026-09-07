# L2-AW33 Compatibility Decode Boundary Validation

Result: `COMPLETED_NON_PARITY`

## Scope

Lane 2 IO only. The WMA reference route already used native probe first and an injectable compatibility decoder when native Apple decoding reported unsupported media. Before AW33, the compatibility seam required only a non-empty regular destination file. A buggy or unsafe decoder could mutate the staged source or return a non-WAV/compressed/structurally invalid file and rely on the later AVFoundation probe to detect it.

AW33 hardens the Lane-2 compatibility boundary itself without selecting or licensing a production WMA decoder.

## Fresh canonical state

At wave start:

- Notion canonical remained v4 autonomous lanes / late integration.
- Worker contract SHA: `c9e8ec5d191108db6eb20fbd40db0dab3c46b725`.
- Work Package SHA: `aad7983bdaf315a996dce1496ed245008085c712`.
- Lane Plan SHA: `10b595b47e5a71278bde32e8656bd284e14e62eb`.
- Resource Lock SHA: `55b0056b5563c64515ddc74abd448c545c7c0bb4`, integration epoch 22, assignment epoch 2.
- Worker-2 status blob: `80ff6253bf7ff792bf85fe6d52981002ef98bfd4`, reporting AW32 complete/non-parity.
- PARITY SHA: `db98892a379180c25ffeb3586a7c3353620a2d5d`.
- MOI-P001/P002/P017/P018/P019/P020/P024 remained `MISSING`.

## Production behavior

### Source immutability verification

`IOCompatibilityDecodeStaging` now fingerprints the staged compatibility source before invoking the decoder and again after decoder completion. The bounded-memory fingerprint includes:

- regular non-symlink file requirement;
- positive file size;
- content modification time;
- streaming 64-bit FNV-1a content digest read in 1 MiB chunks.

If the decoder deletes, replaces or mutates the source, the destination is removed and the compatibility decode fails closed.

The FNV digest is an integrity/change detector for a local staging contract, not a cryptographic authenticity primitive.

### Canonical WAV structural validation

`IOCanonicalWAVValidator` validates decoder output before returning it to the normal media probe. It reads only RIFF/WAVE chunk headers and the 16-byte core `fmt ` payload; audio payload bytes are not materialized.

Required conditions:

- regular non-symlink file;
- minimum canonical WAV size;
- `RIFF` + `WAVE` container;
- declared RIFF size contained by the actual file;
- bounded maximum 256 chunk headers;
- valid chunk boundaries/padding;
- `fmt ` chunk of at least 16 bytes;
- PCM (`1`) or IEEE float (`3`) format tag;
- 1...64 channels;
- 8 kHz...768 kHz sample rate;
- positive byte rate and block alignment;
- 1...64 bits/sample;
- non-empty `data` chunk.

Compressed WAV formats are deliberately rejected because the compatibility contract promises a canonical decoded WAV, not merely another compressed container.

### Cleanup behavior

Cancellation, decoder failure, source mutation and structural WAV validation failure remove the temporary compatibility destination. The original staged source remains owned by the caller and the existing `IOSAudioIOService` failure mapping remains unchanged.

## Validation

Exact AW33 production logic was reproduced from the committed source and typechecked with a minimal existing-Library-contract stub using:

`swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors -typecheck`

Result: PASS on Swift 6.2.1 Linux.

Portable execution against the same boundary logic:

`L2_AW33_SELF_TEST_PASS scenarios=4 valid_pcm=true invalid_container_rejected=true source_mutation_rejected=true compressed_wav_rejected=true`

Scenarios:

1. valid PCM WAV succeeds and source bytes remain identical;
2. non-WAV decoder output fails closed;
3. decoder source mutation fails closed;
4. compressed WAV format tag is rejected.

Prepared XCTest regression file:

- `IO/Tests/IOCompatibilityDecodeBoundaryTests.swift`

Committed blobs:

- `IOReferenceMediaCompatibility.swift`: `01d353f19e0d407752f5905b2a7edae9afe4458e`
- `IOCompatibilityDecodeBoundaryTests.swift`: `f7aa480cb2f95fd82314457eb6a3d2af00c53dd7`
- `L2AW33CompatibilityDecodeBoundarySelfCheck.swift`: `2643a6ae87af9f901bfc22bf0cae48cbdb42ede2`

Static audit:

`L2_AW33_STATIC_AUDIT_PASS checks=18/18`

The audit verified native-first WMA routing is unchanged; decoder remains injectable; source path must remain under Staging; source is regular/non-symlink/non-empty; source fingerprint is taken before and after decode; mutation removes output and fails; cancellation removes output; destination is regular/non-symlink/non-empty; RIFF/WAVE structure is required; compressed WAV is rejected; chunk scan is bounded; payload is not loaded wholesale; no source deletion is added; no Shared/App/PARITY/schema modification is required; and final AVFoundation probe remains downstream.

## Scope audit

AW33 modified/added only `tech-assets/moises-audio/IO/**`. The pre-existing Worker-2 status commit immediately before AW33 is outside implementation scope but is the Worker-owned status file. No Shared, App, PARITY, resource-lock, queue, work-package, lane-plan or other-lane path was modified by AW33 implementation.

AW33 implementation/test commits before Evidence:

1. `18f75a16876b6acf1cec5d883152543af9eb75ea` — harden compatibility decode boundary
2. `d71a98b59ec42dd1cbafa4d4188891e8b8579d96` — add regression tests
3. `e5b8d669d0cac7dec3a8bc6d98f66652915e4d26` — correct portable XCTest helper
4. `fee281c239dabea344fe056e9797714f628bdaa9` — add executable self-check

## Remaining gates

- A production WMA decoder is still not selected. If Apple native decoding remains unavailable on target iOS, the compatibility decoder and its commercial/license obligations require HQ/legal approval.
- Real rights-cleared WMA fixtures must be run through native-first routing and the selected compatibility decoder on iPhone.
- AVFoundation decode/probe behavior, cancellation, storage pressure, long-file RSS/latency and malformed real-world WMA behavior require Apple evidence.
- The streaming FNV fingerprint is intentionally a local mutation detector, not a security hash.
- MOI-P001/P002 remain MISSING; compile/synthetic evidence is not import PARITY.

## PARITY

No PARITY row is promoted from AW33. Final import support still requires real user-file, real codec, iPhone and reference evidence under HQ authority.
