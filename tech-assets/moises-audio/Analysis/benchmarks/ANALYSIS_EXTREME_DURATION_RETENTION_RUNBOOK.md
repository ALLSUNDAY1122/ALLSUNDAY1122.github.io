# Analysis Extreme-Duration Retention Runbook — L4-W31

## Purpose

W31 bounds Worker-4 retained Analysis feature cardinality for extreme-duration audio without changing the normal-song W29/W30 path.

This is an engineering resource policy. The cardinality limits in this document are **not** Moises-quality thresholds, device-performance acceptance thresholds, or PARITY thresholds.

## Preconditions

1. Use the W29 single-pass prepared-feature path.
2. Prefer the W30 pull-based chunked decoder seam so a whole decoded source PCM is not intentionally retained by Analysis.
3. Preserve W11 finite/clamped prepared-sample semantics and W30 contiguous-source validation.
4. Final real-device acceptance remains W23/W24 and final real-audio quality remains W22 + current-iPhone differential evidence.

## Retention policy

W31 currently bounds retained feature vectors at:

- Tempo onset: `1,048,576` retained bins.
- Chord preclassified decisions: `524,288` retained decisions.
- Section energy: `262,144` retained frames.

The limits exist to prevent unbounded retained vectors. They do not state what quality is acceptable.

### Exact mode

If the natural feature count fits below the corresponding cap, the W29/W30 cadence is unchanged:

- Tempo energy/onset window and hop are unchanged.
- Chord window and 0.25-second default hop are unchanged.
- Section energy remains at the natural 100-Hz feature rate.
- Key still uses the same bounded uniformly spaced windows and RMS probe.

Typical songs therefore remain bit-for-bit on the existing retained-feature schedule.

### Tempo compression

When natural Tempo onset cardinality exceeds the cap:

1. Continue calculating every natural-cadence Tempo frame/flux value.
2. Group contiguous natural onset values by `tempoFrameStride`.
3. Retain the maximum onset in each group.
4. Pass the effective grouped hop to the existing Tempo decision logic.

This max-pooling avoids the simpler but weaker design of evaluating only every Nth frame, which could miss a transient located between retained frames.

If the effective retained-envelope sample rate is below Nyquist for the configured maximum BPM, Tempo fails closed instead of returning a potentially aliased BPM.

### Chord compression

The Chord cap is deliberately high enough to preserve the default 0.25-second cadence through a 24-hour, 8-kHz Analysis stream. At still longer durations the hop may increase.

If the adaptive Chord hop exceeds the retained analysis-window width, the bounded ring can no longer reconstruct the intended centered window. W31 then suppresses normal Chord classification and emits one full-duration `X` unknown marker rather than reading overwritten samples and publishing incorrect chords.

### Section-energy compression

Section energy is recomputed into at most `262,144` duration-spanning RMS frames. The complete source duration remains represented; only retained feature resolution changes.

If the effective retained Section rate cannot represent at least one energy sample within the configured `minimumSectionSeconds`, Section energy fails closed to an empty signal rather than fabricating structure at insufficient resolution.

## Reference plans

### 10-minute / 8-kHz Analysis stream

- Tempo stride: 1
- Chord stride: 1
- Section energy frames: 60,000
- Compression: no

### 24-hour / 8-kHz Analysis stream

- Natural Tempo frames: 8,639,996
- Tempo stride: 9
- Retained Tempo bins: 960,000
- Effective Tempo hop: 0.09 seconds
- Natural/retained Chord decisions: 345,600 / 345,600
- Chord stride: 1; default 0.25-second cadence preserved
- Natural Section frames: 8,640,000
- Retained Section frames: 262,144
- Effective Section feature rate: approximately 3.034 Hz
- No domain is structurally suppressed at this duration.

### Ultra-long fail-closed examples

- At 48 hours under the default 8-kHz/55...210 BPM configuration, the Tempo retained rate becomes insufficient for the configured maximum-BPM Nyquist requirement, so Tempo is suppressed.
- At 96 hours, the bounded Chord plan requires a hop wider than the default 0.70-second Chord analysis window, so Chord is represented as full-duration `X` rather than using overwritten ring data.
- At sufficiently extreme durations such as 30 days, the capped Section-energy rate cannot resolve the configured minimum section duration, so Section energy is suppressed.

These examples are structural fail-closed behavior, not claims about supported product-duration limits.

## Memory budget interpretation

For 44.1-kHz mono Float source input, the W31 analytical Worker-4 retained-feature budget is:

- 1 hour: `10,375,552` bytes major Worker-4 working set.
- 24 hours: `41,172,416` bytes major Worker-4 working set.

The W29/W30 pre-W31 24-hour analytical retained-feature estimate was `197,563,776` bytes. W31 therefore reduces that estimate by approximately 4.80x.

These estimates do not include Swift allocator/VM overhead or hidden upstream-decoder buffers. If a genuine W30 pull decoder is used, one source chunk replaces the prepared-reader-cache allowance; with the default 32,768-sample chunk both are 131,072 bytes, so the current chunked budget has the same totals above.

## Validation sequence

1. Strict Swift 6 concurrency/warnings-as-errors compile of the W31 policy/diagnostic logic.
2. Verify normal-song retention plan has all strides = 1 and compression disabled.
3. Run normal-song W29/W31 output equivalence for Tempo, Key, Chord and Section energy.
4. Verify 24-hour cardinalities and exact Chord cadence.
5. Verify Tempo, Chord and Section structural unsafe cases fail closed.
6. Verify diagnostic JSON round-trip preserves compression and safety flags.
7. Stress many deterministic duration/sample-rate plans and assert all retained counts stay below caps.
8. Re-run W30 chunked-path budget assertions against the current W31 estimator.
9. At HQ Late Integration, execute W22 rights-cleared quality differential for any compressed long-duration cases selected for production evidence.
10. At HQ Late Integration, execute W23/W24 on a physical iPhone with the real Lane-2 decoder.

## PARITY boundary

W31 is **NON_PARITY engineering evidence**. It does not prove MOI-P021 and does not change PARITY_MATRIX.

A bounded vector is not evidence of acceptable real-device memory, thermal, battery, latency, or quality. Any compressed long-duration case that can alter Analysis output remains subject to HQ-owned W22 differential and W23/W24 physical-device acceptance.
