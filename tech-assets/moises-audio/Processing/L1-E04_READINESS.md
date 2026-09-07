# L1-E04 Readiness — Current-iPhone Moises Differential Listening

Captured: 2026-08-24 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`

Engineering readiness: `READY_PENDING_EXTERNAL_INPUT`  
Live gate: `PENDING_EXTERNAL_INPUT`  
PARITY claim: `NONE`

## Roadmap acceptance

E04 compares project separation with current-iPhone Moises using the same rights-cleared G2 input and blind A/B listening across:

- target preservation;
- bleed;
- musical noise;
- transient integrity;
- timbre/formant integrity;
- stereo/phase integrity;
- low-frequency integrity;
- reverb/ambience;
- overall practice usability.

A project with obvious practical inferiority must not pass.

No real current-iPhone Moises capture or independent human listening result was supplied during this Worker wave, so live E04 is intentionally not marked complete.

## Implementation

`Separation/Evaluation/current_iphone_differential.py` coordinates E04 without copying Moises reference assets into the repository.

It requires:

1. live E02 evidence in `READY_FOR_HQ_LIVE_AUDIO_GATE`;
2. live E03 evidence in `READY_FOR_HQ_E03_LIVE_REVIEW`;
3. exact E02 rights lock continuity through E03;
4. a successful E03 project logical run whose run-manifest and stem SHA values remain unchanged;
5. a current-iPhone reference capture for an E02-cleared G2 fixture;
6. independent, conflict-free reviewers;
7. completed blind scores before final comparison review can become ready.

## Exact G2 input binding

E04 v1 requires the current-iPhone capture to declare an `input_mixture_sha256` exactly equal to the E02 G2 mixture SHA.

This is intentionally stricter than an unaudited claim that two inputs are merely "comparable". If a future iPhone capture workflow requires an unavoidable deterministic conversion, HQ should add a versioned equivalence method with input/output hashes instead of weakening v1 by assertion.

## Project output binding

Project comparison artifacts are not accepted merely because a private index names them.

For each project logical run E04 requires:

- the logical run to be successful in the supplied E03 evidence;
- the run-manifest SHA to equal E03;
- every physical project stem to hash to the same role/SHA bound by E03;
- the role set to exactly match the E03 artifact set.

This prevents project output replacement after the live benchmark.

## Current-iPhone reference capture

A private reference capture record binds:

- `reference_system = MOISES_CURRENT_IPHONE`;
- E02 G2 fixture ID;
- exact input mixture SHA;
- app version and build;
- iOS version and device model;
- account tier;
- reference mode label;
- capture timestamp;
- external capture-provenance file and SHA;
- each reference stem path and SHA.

Reference audio and capture provenance must remain outside the repository. E04 rejects a private root inside the repository and rejects reference assets resolving into the repository.

The checked-in template contains no real Moises asset.

## Blind assignment

The old M04 helper used a deterministic public batch identity for A/B swap. E04 hardens this for live review:

- a private 256-bit random blinding seed is created when the session starts;
- assignment A/B mapping is HMAC-derived from the private seed and assignment ID;
- only the seed hash appears in the public assignment worksheet;
- the raw seed and locator/reveal map remain private;
- resuming with additional review scores reuses the same seed and mapping;
- changing source locks, project/reference indexes, reviewer roster, policy or cases changes the session identity and is rejected.

The score document itself is deliberately not part of the immutable session identity, because reviews must be appendable while the blind source assignment remains frozen. Its final SHA is included in the final E04 evidence lock.

## Reviewer requirements

Active reviewers must attest:

- independence from separator development;
- no review conflict.

The live plan sets a minimum reviewer count per case/stem. The checked-in example value is an engineering policy, not a Moises product fact.

Reviewer IDs are private. Sanitized evidence stores only domain-separated reviewer hashes.

For roster replacement during a long live campaign, HQ should use the existing A20 auditable reviewer replacement-chain semantics rather than silently rewriting an established blind roster.

## Scoring and practical inferiority

Each blind A/B assignment records integer 0..4 scores for all nine dimensions and a blind `materially_worse = A | B | NONE` vote.

After reveal, E04 calculates:

- project-minus-reference mean delta for every listening dimension;
- project-materially-worse vote fraction per case/stem;
- overall practice-usability mean delta;
- missing assignment count.

State is:

- `WAITING_REVIEW` while required assignments are missing;
- `READY_FOR_HQ_E04_LIVE_REVIEW` only when review coverage is complete and engineering inferiority checks pass;
- `DIFFERENTIAL_FAIL` when material inferiority or the configured usability floor fails.

The numeric example thresholds are review-policy defaults only. They are not Reference facts and do not replace HQ judgment that no obvious practical inferiority remains.

## Privacy boundary

Sanitized E04 evidence emits no:

- reference artifact locator/path;
- project artifact locator/path;
- raw reviewer ID;
- private blinding seed;
- raw audio.

The private reveal map, current-iPhone reference media, capture provenance and reviewer roster stay outside the public repository.

## Machine verification

Repository-equivalent local execution against the final E04 source semantics:

- regression/fault scenarios: **21 / 21 PASS**;
- Python `py_compile`: **PASS**.

Coverage includes:

- waiting-review then same-session resume;
- stable private blinding;
- sanitized evidence redaction;
- project material-inferiority failure;
- E02/E03 lock and fixture-group drift;
- project run/artifact mutation;
- current-iPhone exact-input mismatch;
- capture-provenance mutation;
- reviewer independence/count;
- unsafe paths/repository-copy attempts;
- compromised blindness;
- duplicate/unknown review assignments;
- invalid scores/material votes;
- immutable session identity;
- missing E03 artifact evidence;
- wrong reference-system identity.

Test bytes are synthetic control fixtures only. They are not Moises output, Golden evidence, human listening evidence, or PARITY evidence.

Machine-readable matrix:

- `Processing/Tests/L1-E04_DIFFERENTIAL_LISTENING_MATRIX.json`

Checked-in regression:

- `Separation/Tests/test_current_iphone_differential.py`

Schemas/templates:

- `Separation/Evaluation/schemas/current-iphone-differential-plan.schema.json`
- `Separation/Evaluation/schemas/current-iphone-reference-capture-index.private.schema.json`
- `Separation/Evaluation/schemas/current-iphone-differential-evidence.schema.json`
- `Separation/Evaluation/examples/current-iphone-differential-plan.template.json`
- `Separation/Evaluation/examples/current-iphone-reference-capture-index.private.template.json`
- `Separation/Evaluation/examples/current-iphone-differential-review.private.template.json`

## Remaining live inputs

E04 still requires:

1. actual live E02 G2 rights-cleared recordings;
2. actual live E03 project separation outputs and E03 lock;
3. current-iPhone Moises capture of the exact same G2 bytes;
4. external reference artifact hashes and capture provenance;
5. independent human reviewer roster;
6. completed blind A/B scores;
7. HQ review of live provenance and practical-inferiority result.

These missing external inputs do not change Worker 1 to `BLOCKED_HUMAN`; the engineering lane remains checkpoint-ready.

## Next gate

The next autonomous preparation target is `L1-E05 | Live Processing Recovery / Provider Semantics`, covering real interruption/cancel/retry/relaunch/output-expiry/rate-limit/long-track/storage-pressure behavior.

## PARITY

`parity_claim = NONE`.

E04 readiness does not change `MOI-P003`, `MOI-P004`, `MOI-P005`, `MOI-P020`, `MOI-P021` or `MOI-P024`. Final PARITY remains an HQ decision based on live provider, real audio, current-iPhone reference, human review, real-device and integrated evidence.
