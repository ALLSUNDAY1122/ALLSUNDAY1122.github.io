# L3-AW30｜Long-track Evidence Cancellation / Progress / Checkpoint

Result: `COMPLETE_NON_PARITY`

## Goal

Make the AW26/AW27 bounded long-track evidence path cooperatively cancellable and observable without allowing a cancelled/failed/partial run to be mistaken for completed evidence.

## Production contract

- `Lane3LongTrackEvidenceExecutionController` is a lock-backed, pollable execution controller.
- `Lane3CancellationAwarePCMChunkSource` wraps both reference and observed `Lane3PCMChunkReadable` inputs.
- Cancellation is checked immediately before every underlying PCM read and again after the read returns.
- If cancellation arrives while a synchronous decoder read is in progress, returned PCM is discarded before analyzer use.
- Swift Task cancellation and explicit `requestCancellation()` use the same fail-closed path.
- Stage progression is monotonic: validating -> time-domain -> spectral -> envelope -> core assembly -> PCM identity -> finalizing -> completed.
- Progress is a conservative completed-stage lower bound (`permille`), not ETA or decoder throughput prediction.
- Checkpoints contain aggregate read counters and state only. They contain no raw PCM, local file path, partial analyzer metrics, ProjectID, generation/ticket value, or user media metadata.
- Every checkpoint has `authoritativeEvidenceAllowed=false` and `parityPromotionAllowed=false`, including a checkpoint observed after a successful run.
- Checkpoint `resumeMode` is `restartRequired`. AW30 does not serialize FFT/statistical accumulator state and does not claim mid-analysis resume.
- Only after the final AW13-compatible report has been constructed and a valid lowercase 64-hex run binding exists can the controller enter `completed` and expose `Lane3LongTrackEvidenceCompletionReceipt`.
- Cancelled/failed runs cannot expose a completion receipt.

## Pipeline integration

`Lane3LongTrackUnifiedEvidencePipelineV2.analyze` retains its existing behavior when `executionController` is omitted. When supplied, the pipeline wraps both sources and advances the controller at stage boundaries. Any normal error marks the execution failed; cancellation remains cancelled rather than being rewritten as failure. The final completion binding is the exact `reportV2.runBindingSHA256`.

## Portable validation

Environment: Swift 6.2.1, Linux x86_64, `-strict-concurrency=complete -warnings-as-errors`.

Exact production execution source blob `ceba6420af94b17550015a21a87e1ee7a6a012b8` strict-compiled with the `Lane3PCMChunkReadable` interface contract.

Self-test output:

`L3-AW30 long-track execution self-test PASS cancellation=pre+midread+task progress=monotonic partialEvidence=forbidden completionBinding=validated`

Covered:
- explicit cancellation before read: zero reads, cancelled, no completion;
- cancellation during underlying read: read activity counted, returned PCM discarded, no completion;
- Swift Task cancellation: observed by the synchronous wrapper before PCM delivery;
- illegal stage skip rejected;
- failed execution cannot complete;
- lowercase SHA-256 completion binding required; uppercase forged binding rejected;
- checkpoint JSON privacy sentinels and no-authoritative-evidence invariant;
- successful run read counters and final 1000/1000 progress.

50,000-cycle stress output:

`L3-AW30 stress PASS cycles=50000 cancelled=37500 completed=12500 completionRejected=37500 checksum=543750`

All 37,500 cancelled cycles rejected completion. All checkpoints remained non-authoritative.

Bookkeeping benchmark, 20 rounds x 100,000 read-record operations with checkpoint polling every 1,000 operations:
- median: `1.462 ms`
- p95: `1.537 ms`
- max: `1.590 ms`
- checksum: `101002000`

The benchmark measures only lock/counter/checkpoint bookkeeping on Linux. It excludes AVAudioFile, codec/file IO, AW07/AW08/AW10 analysis, SHA-256 PCM scanning, actual cancellation latency, Playback/DSP runtime, device thermal/RSS/battery and audio quality.

## Repository validation

Authored:
- `Playback/Tests/L3_AW30_LongTrackExecutionSelfTest.swift`
- `Playback/Tests/L3_AW30_LongTrackExecutionStress.swift`
- `Playback/Tests/L3_AW30_LongTrackExecutionBenchmark.swift`
- `Playback/Tests/L3_AW30_LongTrackPipelineExecutionSelfTest.swift`

The full pipeline integration test builds a real production generation/recovery lineage, runs AW26 long-track evidence with an execution controller, binds completion to the returned report run binding, and verifies a pre-cancelled run cannot return evidence. It remains pending execution in the complete selected Lane-3/Xcode source graph.

## Important limitations

- `AVAudioFile.read` is synchronous. AW30 does not prove that an in-progress framework decoder call can be interrupted immediately; it guarantees a post-read cancellation check and discards the returned PCM before analysis continues.
- Cancellation request-to-abort latency must be measured on physical iPhone with representative codecs and long files.
- AW30 checkpoints are not resumable computation snapshots. Retry starts a fresh analysis from the same validated input pair.
- No physical iPhone, real >=30-minute rights-cleared source pair, measured RSS/thermal/battery, current-Moises differential or human listening was performed.
- This wave does not change any PARITY state.

## HQ Late Integration

1. Run the repository AW30 pipeline integration self-test with the complete selected Lane-3 source graph.
2. For AW27 -> AW26 real-file evidence, create one execution controller per evidence attempt and expose only its checkpoint for UI/progress polling.
3. Cancellation may be requested either through the controller or by cancelling the execution Task; treat either as an invalidated evidence attempt.
4. Do not upload/bind a checkpoint into AW24 as completed evidence. Require `completionReceipt.runBindingSHA256 == result.reportV2.runBindingSHA256` first.
5. After cancellation/failure, discard any temporary derived metrics/artifacts that are not already covered by a separately valid evidence contract; retry from the validated source pair.
6. Measure physical-iPhone request-to-cancel-observed latency for local PCM/CAF plus representative selected app codecs, including a cancellation request while `AVAudioFile.read` is active.
7. Keep actual device RSS/thermal/battery, real audio, current-Moises A/B and listening as separate HQ gates.
