# MOI-QA-001｜Listening / UX Differential Rubric

This rubric is used for the same rights-cleared input processed by the reference app and the project implementation. It is designed so strong objective numbers cannot hide obvious audible or operational inferiority.

## 1. Listening setup

For each G2 differential fixture:

1. Use the same input file and comparable separation mode.
2. Loudness-match outputs for evaluation only; do not hide clipping, pumping or dynamics artifacts.
3. Randomize labels as `A` and `B`.
4. Evaluate headphones first; repeat material low-frequency/stereo issues on full-range speakers when available.
5. Preserve raw notes and score sheets.
6. If the listener recognizes the system identity from UI/export metadata, re-blind the assets.
7. Do not average across stems until each stem has an individual score.

A later Human Gate is still required for final subjective sign-off. This rubric defines the evidence format and automated rejection conditions.

## 2. Per-stem listening scale

Score each dimension 0–4:

- `4` = no meaningful defect in normal listening / clearly production-usable for the intended practice workflow.
- `3` = minor defect; noticeable under attention but not disruptive.
- `2` = clear defect; usable with compromise.
- `1` = severe defect; distracts from practice/listening and is obviously inferior.
- `0` = unusable or fundamentally wrong output.

Dimensions:

### Target preservation
How much of the desired source remains complete and natural.

Listen for:
- missing syllables or consonants;
- lost bass notes;
- smeared drum attacks;
- removed instrument tails;
- unstable gain/pumping.

### Inter-stem bleed
How much non-target source remains in the stem.

Score worst audible competitor separately where useful: vocal-in-drums, drums-in-vocal, bass-in-other, etc.

### Musical noise / tonal residue
Warbling, chirps, watery artifacts, granular/phasiness or unstable narrow-band tones created by separation.

### Transient integrity
Kick, snare, cymbal, pick and piano attack preservation. Penalize pre-echo, softened attacks and duplicated transients.

### Timbre / formant integrity
Naturalness of voice/instrument tone. Penalize hollow, metallic, nasal or phase-cancelled timbre.

### Stereo / phase integrity
Stereo width, center stability and mono compatibility. Penalize wandering image, collapsed width or exaggerated decorrelation.

### Low-frequency integrity
Kick/bass fundamentals, sub content and low-end pumping. This is scored separately because many models appear acceptable on headphones while losing low-frequency structure.

### Reverb / ambience handling
Whether the output keeps or removes ambience coherently. Penalize chopped tails, floating reverb unrelated to source, and excessive cross-stem room residue.

### Overall practice usability
Would a musician reasonably use this stem to learn, rehearse or inspect the part?

## 3. Reference-comparison judgement

After scoring both blinded outputs, reveal identity and derive these comparisons per dimension:

- `BETTER`: project score >= reference + 1.
- `COMPARABLE`: absolute difference < 1.
- `WORSE`: project score <= reference - 1.
- `CRITICAL_WORSE`: project <= 1 while reference >= 3, or audible failure makes the stem unusable.

Automatic rejection for a PARITY proposal if any of the following is true:

- any mandatory stem has `CRITICAL_WORSE` on a rights-cleared real fixture;
- project median overall-practice score is more than 0.5 below reference across the G2 set;
- more than 20% of G2 fixtures are `WORSE` in overall-practice usability with no compensating root-cause resolution;
- a single genre/hard-case bucket consistently fails even when global mean appears acceptable;
- clipping, NaN/Inf, gross desynchronization or missing stem occurs.

These are rejection guards, not sufficient conditions for final PARITY.

## 4. Objective + listening fusion

No single scalar score decides quality. Report a dashboard containing:

- per-stem SI-SDR/SDR for G1/G4 where clean references exist;
- worst-fixture and P10 metric values;
- blinded listening medians and worst-case comments;
- processing wall time / RTF;
- failure/cancel/retry result;
- memory/thermal evidence for intended runtime;
- reference comparison state.

A candidate with better SI-SDR but materially worse listening remains rejected. A candidate with attractive listening but missing clean-reference metrics remains incomplete.

## 5. Analysis listening/visual check

For BPM/key/chord/metronome/song-parts fixtures, the evaluator also checks whether numerical correctness translates into usable presentation:

- beat/click feels locked to the groove rather than systematically early/late;
- half/double-tempo errors are obvious and tagged;
- key confidence is not presented as certainty on ambiguous/modulating tracks;
- chord changes occur close enough to the musical change to support following along;
- inversions/complex chords are not silently simplified when the reference shows them and the feature contract expects them;
- section boundaries are useful for navigation/looping rather than merely optimizing an offline metric.

## 6. UX differential protocol

Use the same scenario and input on reference and project apps where reference observation permits it.

Measure:

### Operation count
Count deliberate user actions from the same starting state to the same goal.

Scenarios:
- import a local file and start standard 4-stem processing;
- reach first playable project state;
- mute one stem and change another stem's volume;
- seek to a visible musical position;
- enable practice click/metronome;
- change pitch/key;
- export a custom mix;
- recover from a failed processing attempt.

A project flow is flagged if it requires more than two additional deliberate actions for a core scenario without a clear functional reason.

### Time-to-state
Record:
- time to import-source picker;
- time from submit to first visible processing state;
- time to first playable state;
- time to separated-stem ready state;
- seek response latency;
- time to export-complete state.

For network/server inference, record upload, queue, inference and download separately so network variance is not hidden inside one number.

### State clarity
Score 0–4 for each:
- processing status clarity;
- available-vs-not-ready controls;
- failure explanation;
- retry discoverability;
- cancellation discoverability;
- preservation of work after interruption;
- export completion clarity.

Automatic UX rejection if:
- user cannot tell processing from failure;
- destructive/cancel action can silently corrupt or discard the project;
- a core function is unreachable without undocumented gesture;
- reference allows useful player access during processing but project unnecessarily blocks the entire project with no technical need;
- failed network/server processing requires re-import when deterministic retry is technically available.

## 7. Processing / recovery rubric

Every relevant fixture scenario records PASS/FAIL for:

- cancel at early / mid / near-complete phases;
- immediate retry;
- network timeout and reconnect if server-based;
- duplicate-submit idempotency;
- app background/interruption;
- relaunch after termination;
- insufficient temporary storage;
- malformed/unsupported input;
- backend/model failure;
- output cleanup after failure.

The expected state after each failure must be explicit: retained project, retryable job, cleaned partial artifacts, and user-visible reason.

Any data loss, corrupted project, orphaned large artifact, duplicated charge/job, or unrecoverable processing state blocks a PARITY proposal for affected rows.

## 8. Long-track performance rubric

For 5/15/30/60 minute cases record:

- wall time;
- RTF;
- peak RSS;
- thermal state and battery delta if on-device;
- upload/queue/inference/download times if server;
- temp/output storage maximum;
- seek latency at 10%, 50%, 90%;
- playback drift over repeated loop/seek operations;
- cancellation cleanup latency;
- recovery after interruption.

A candidate cannot hide long-track failure behind normal-song medians.

## 9. Required raw score record

Each evaluated stem/scenario emits a record containing:

```json
{
  "run_id": "...",
  "fixture_id": "G2-...",
  "system_blind_id": "A",
  "revealed_system": "PROJECT|REFERENCE",
  "stem": "vocals",
  "scores": {
    "target_preservation": 0,
    "bleed": 0,
    "musical_noise": 0,
    "transient_integrity": 0,
    "timbre_formant_integrity": 0,
    "stereo_phase_integrity": 0,
    "low_frequency_integrity": 0,
    "reverb_ambience": 0,
    "overall_practice_usability": 0
  },
  "notes": [],
  "listener_id": "human-gate-anonymous-id",
  "timestamp": "ISO-8601"
}
```

## 10. PARITY impact

This rubric creates evidence requirements only. It does not raise any PARITY row. HQ may use resulting evidence for `MOI-P003`, `P009`, `P011`, `P013`, `P014`, `P021`, and `P022` after real executions exist.