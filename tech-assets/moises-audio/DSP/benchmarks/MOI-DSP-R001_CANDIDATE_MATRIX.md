# MOI-DSP-R001｜Time/Pitch DSP Candidate Matrix

- Worker: `Moises-Worker-2`
- Attempt: `task/MOI-DSP-R001/attempt-1`
- Integration epoch: `1`
- Scope: research/benchmark design only
- PARITY rows informed: `MOI-P010`, `MOI-P012`, `MOI-P014`, `MOI-P015`
- PARITY state change: **none**

## Decision

Use a two-stage strategy:

1. **First product implementation / zero-procurement baseline:** Apple `AVAudioEngine` + `AVAudioUnitTimePitch` for independent tempo and pitch/key changes, with sample-time scheduled click/count-in using `AVAudioPlayerNode`.
2. **Quality-upgrade challenger:** Rubber Band Library 4.x under a purchased commercial licence. It is the strongest immediately evaluable high-quality challenger because it explicitly supports desktop/mobile, real-time time stretch and pitch shift, formant preservation, and has an explicit proprietary redistribution licence path.
3. **Additional challenger:** Superpowered Audio SDK only under a launch-capable White Label/public-app licence. Evaluation use is not a public-release grant.
4. **Fallback/research:** SoundTouch can be benchmarked, but use the commercial non-LGPL licence for a closed iOS product unless legal review deliberately accepts LGPL static-link obligations.

No third-party DSP is approved merely because a demo runs. Apple remains the default until a challenger wins the real-track quality/performance gate and its exact distribution licence is recorded.

## Candidate comparison

Scores are engineering selection estimates (5 favorable, 1 unfavorable) before project-owned device measurements. `UNKNOWN` means no project measurement yet.

| Candidate | Tempo independent of pitch | Pitch independent of tempo | Formant option | iOS fit | Public commercial distribution | Integration | Expected quality ceiling | CPU/memory evidence in project | Decision |
|---|---|---|---|---:|---|---:|---:|---|---|
| Apple `AVAudioUnitTimePitch` | yes | yes | no explicit formant control | 5 | system framework; no bundled third-party licence | 5 | 3-4 | UNKNOWN | **Baseline** |
| Apple `AVAudioUnitVarispeed` | no; rate changes pitch | no | n/a | 5 | system framework | 5 | 4 for intentional varispeed | UNKNOWN | utility only, not main practice DSP |
| Rubber Band 4.x commercial | yes | yes | explicit preserved/shifted formant options | 4 | yes **after commercial licence purchase** | 3 | 5 potential | UNKNOWN | **Primary quality challenger** |
| Superpowered Audio SDK | yes | yes | implementation-specific | 5 | yes only with launch-capable licence | 4 | 4-5 potential | UNKNOWN | licensed challenger |
| SoundTouch commercial | yes | yes | no equivalent explicit vocal-formant mode captured | 3 | yes under commercial licence | 3 | 3 | UNKNOWN | secondary challenger |
| SoundTouch LGPL 2.1 | yes | yes | same algorithm | 3 | legal obligations require deliberate review; iOS static linkage is unusual | 2 | 3 | UNKNOWN | do not default to this route |

## Apple baseline evidence

Apple documents `AVAudioUnitTimePitch` as providing good-quality playback-rate and pitch shifting independently. Its `rate` supports `1/32 ... 32`, and `overlap` is documented as trading more overlap for fewer artifacts, range `3 ... 32`, default `8`.

Apple separately documents `AVAudioUnitVarispeed` as resampling: rate `2.0` raises pitch one octave and `0.5` lowers it one octave; its rate range is `0.25 ... 4.0`. This is useful for intentional tape/turntable-style varispeed, but does not meet the product requirement for independent speed and key controls.

Apple's asset time-pitch algorithms also distinguish `spectral` as the highest-quality music-oriented algorithm and document offline manual rendering in `AVAudioEngine`. Offline export therefore should not be assumed to use exactly the same real-time path as interactive playback; later implementation can benchmark real-time `AVAudioUnitTimePitch` against spectral/offline rendering where product semantics permit.

Authoritative sources:
- https://developer.apple.com/documentation/avfaudio/avaudiounittimepitch
- https://developer.apple.com/documentation/avfaudio/avaudiounittimepitch/rate
- https://developer.apple.com/documentation/avfaudio/avaudiounittimepitch/overlap
- https://developer.apple.com/documentation/avfaudio/avaudiounitvarispeed/rate
- https://developer.apple.com/documentation/avfoundation/time-pitch-algorithm-settings
- https://developer.apple.com/documentation/AVFAudio/performing-offline-audio-processing

## Rubber Band evidence and obligations

Rubber Band 4.0 is a C++ time-stretch/pitch-shift library intended for desktop or mobile. Its documentation has separate real-time processing, high-quality pitch mode, formant preservation and limited-CPU presets. Its open-source grant is GPL v2-or-later; the vendor explicitly states the GPL route is unsuitable for proprietary App Store distribution and offers commercial licences for proprietary products.

Current public commercial licence page lists:
- Standard licence with prominent attribution: £590.
- Non-attribution for publishers with fewer than ten employees: £1490.
- Larger-company non-attribution: £9320.
- Vendor states no expiry and no royalties for the commercial licence route.

These are current web-listed figures and must be rechecked at purchase time. Purchase itself is a Human Gate; benchmarking the GPL source internally is not a public-distribution approval.

Authoritative sources:
- https://breakfastquay.com/rubberband/
- https://breakfastquay.com/rubberband/integration.html
- https://breakfastquay.com/rubberband/license.html
- https://breakfastquay.com/technology/license.html

## Superpowered evidence and obligations

Superpowered documents time stretching and pitch shifting for iOS and exposes playback-rate and pitch-shift controls in its AdvancedAudioPlayer. Current licensing documentation states that the evaluation licence is private/internal only and that public apps require a launch-capable licence; current pricing page describes White Label as public/private App Store launch with a fixed annual fee and no royalty/revenue share, with pricing via sales.

Because launch rights depend on a commercial agreement/license key, the project may evaluate Superpowered but must not treat the evaluation SDK as shippable.

Sources:
- https://docs.superpowered.com/reference/latest/advanced-audio-player/
- https://docs.superpowered.com/getting-started/licensing/
- https://superpowered.com/licensing
- https://superpowered.com/pricing

## SoundTouch evidence and obligations

SoundTouch supports iOS, tempo/pitch/rate control and real-time processing. Its open-source licence is LGPL 2.1. The author's FAQ specifically discusses iPhone static linkage and separately offers a commercial non-LGPL licence on request. For a closed App Store application the low-risk path is the commercial licence, not an implicit assumption that static LGPL integration has no obligations.

Sources:
- https://www.surina.net/soundtouch/
- https://www.surina.net/soundtouch/license.html
- https://surina.net/soundtouch/faq.html

## Why Apple is selected first

- No third-party runtime or licence purchase is needed.
- Native Swift/AVAudioEngine integration is direct.
- Tempo and pitch are independently adjustable.
- It can share the same audio render timeline used for click/count-in scheduling.
- It establishes a legally and technically clean quality floor before procurement.

The selection is **not a quality PARITY claim**. Apple may lose the later blind A/B test, especially on large stretches, vocals, dense mixes or transient-heavy material. If Rubber Band materially wins the defined gate, procurement is justified by measured quality rather than preference.

## Integration boundary

This task does not redefine Playback or Analysis contracts. The later DSP implementation should consume only:
- source PCM/stream already owned by playback;
- tempo ratio or target tempo derived from Analysis/product state;
- pitch offset in cents/semitones;
- beat/downbeat timeline supplied by Analysis;
- transport/sample timeline supplied by Playback.

DSP must not invent BPM/chord/beat estimates and must not own transport state.
