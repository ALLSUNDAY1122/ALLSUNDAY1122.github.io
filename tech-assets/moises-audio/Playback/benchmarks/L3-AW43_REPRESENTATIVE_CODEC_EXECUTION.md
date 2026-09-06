# L3-AW43｜Representative Codec / Corruption / Truncation Execution Evidence

Result: `COMPLETE_NON_PARITY`

## Why this wave exists

AW27 already provides a bounded `AVAudioFile` PCM reader and rejects open/read/short-read/position failures. AW30 records long-track execution progress and read counts. The remaining Lane-3 gap was evidence binding: a run did not durably state which declared codec fixture was executed, whether the fixture was clean/truncated/corrupted, whether the entire decoded stream was swept, or whether a fault fixture was actually observed by the decoder path.

This wave does **not** take ownership of file picking, import UX, app-owned file lifecycle, cloud/video import, or codec support policy. Those stay in Lane 2 / HQ. Lane 3 receives a rights-cleared fixture descriptor plus a local file URL at execution time and records only path-free decode/render evidence.

## Implemented contract

`Lane3RepresentativeCodecFixtureDescriptor` binds:
- stable fixture ID and declared codec label,
- `clean`, `truncated`, or `corrupted` expectation,
- expected channels/sample rate,
- baseline frame count from the unmodified fixture,
- rights-cleared status.

The baseline frame count is intentionally external evidence-manifest data. A truncated compressed file can still be perfectly decodable at its shortened length; without an unmodified baseline, Lane 3 must not pretend to infer truncation from the shortened file alone.

`Lane3RepresentativeCodecExecutionProbe.sweep` performs a full sequential bounded chunk sweep. It never stores a full-track PCM array. Durable output contains only metadata, counters, failure code and a non-cryptographic rolling PCM checksum.

### Clean fixture

A clean cell is satisfied only when:
- metadata matches the descriptor,
- decoded frame count equals baseline frame count,
- the complete stream is read sequentially,
- every read returns the exact requested sample count,
- no non-finite PCM appears.

### Truncated fixture

A truncated cell observes its expected fault only when at least one of these is true:
- decoded metadata frame count is lower than the unmodified baseline,
- decoder open/read path rejects the fixture,
- an exact-read/PCM validity failure is observed.

A shorter but otherwise fully decodable file is therefore still explicitly identified as truncation by the baseline-frame comparison.

### Corrupted fixture

A corrupted cell observes its expected fault only when the decoder path actually exposes a failure/invalid PCM condition. If the declared corrupted fixture opens and completes the entire exact sweep without a failure, `expectedFaultObserved` remains `false`; the matrix is incomplete instead of treating silent decoder acceptance as successful corruption detection.

This is deliberate. Lane 3 does not claim to classify compressed-byte corruption from PCM when the decoder concealed or recovered it.

## Matrix completion

For every codec label selected by HQ/Lane 2 current-reference evidence, AW43 requires three cells:
- clean,
- truncated,
- corrupted.

Every cell must be rights-cleared and derived from a baseline representing at least 30 minutes. `contractCoverageComplete` can be true on portable structural data, but `physicalEvidenceComplete` additionally requires every report to come from the physical-iPhone AVFAudio execution environment. Neither flag permits PARITY promotion by itself.

## Selected Apple bridge

`Lane3AppleRepresentativeCodecExecutionProbe`:
- uses the AW27 bounded `Lane3AppleFilePCMChunkSource`,
- does not persist the file URL,
- maps Apple decoder failures to stable path-free codes,
- distinguishes physical iPhone from simulator/macOS at compile time,
- runs the same full sequential sweep contract after a successful open.

The Apple source/Xcode path was authored but not executed in this worker environment.

## Portable validation

Swift 6.2.1 Linux, `-swift-version 6 -strict-concurrency=complete -warnings-as-errors`:

Self-test PASS:
- clean full sweep,
- metadata-detected truncation,
- generic mid-stream corruption read rejection,
- typed `shortRead` propagation,
- corrupted fixture silently decoding to completion remains incomplete,
- less-than-30-minute baseline rejected by matrix completeness,
- rights-uncleared fixture rejected by matrix completeness,
- selected-Apple open rejection is non-device evidence.

Optimized bounded stress PASS:
- 1,000,000 frames,
- 2 channels,
- 4,096-frame chunks,
- 245 read calls,
- exactly 1,000,000 frames returned,
- no non-finite PCM,
- no whole-track retention by the runner,
- elapsed about 0.0025 s in the synthetic Linux process.

Optimized bookkeeping/checksum benchmark PASS:
- 20 runs × 100,000 frames,
- median 232,551 ns,
- p95 300,143 ns,
- max 300,574 ns,
- checksum 15,965,826,248,408,535,780.

These timings are **not** AVFAudio decode throughput, iPhone latency, RSS, thermal, or battery evidence.

## HQ / device execution requirements

HQ should obtain the current required codec labels from current-reference/Lane-2 import evidence, then prepare rights-cleared ≥30-minute unmodified source fixtures plus intentionally truncated and corrupted derivatives for each required label. For each fixture:

1. Provide the unmodified baseline channels/sample rate/frame count in the descriptor.
2. Execute `Lane3AppleRepresentativeCodecExecutionProbe.run` on a physical iPhone.
3. Preserve the resulting report without file paths or raw compressed/PCM payloads.
4. Require clean exact full-sweep completion.
5. Require truncated `expectedFaultObserved=true` from baseline shortening or decoder rejection.
6. Require corrupted `expectedFaultObserved=true`; if the decoder silently completes the corrupted fixture, keep that matrix cell incomplete and characterize the fixture/decoder behavior rather than relabeling it PASS.
7. Run the existing AW26/AW30 long-track differential/resource path on valid clean fixtures and measure physical RSS/thermal/battery separately.

## Claims intentionally not made

- no selected Xcode/AVFAudio execution PASS,
- no physical-iPhone codec evidence,
- no rights-cleared real-track execution,
- no current-Moises differential,
- no RSS/thermal/battery result,
- no codec-support-policy claim,
- no PARITY promotion.
