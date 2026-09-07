# L1-A23｜Generated Stem Timing / Mix Compatibility Hardening

Status: `COMPLETE_NON_PARITY`  
Target: `MOI-P025｜AI stem generation`  
PARITY claim: `NONE`

## Purpose

A21/A22 establish generated-stem entitlement, credit, lifecycle, runtime and live-evaluation boundaries. They do not by themselves prove that a generated audio artifact can be inserted into the project mixer without a format/timeline mismatch or that replacing a previous generated variant cannot corrupt the active project result.

A23 closes that Lane 1 engineering gap. It does **not** claim that any generated audio matches Moises in quality.

## Mix-ready contract

`Separation/Server/generated_stem_mix_compatibility.py` treats the runtime output as a raw artifact until it passes a separate mix-compatibility boundary.

For the current v1 contract, an active generated stem must match the source project mix spec exactly on:

- sample rate;
- channel count;
- PCM/float audio format;
- bit depth;
- frame count;
- timeline origin (`0` frames).

The source audio SHA is part of the receipt chain. A valid WAV file with unrelated timing/format metadata is not sufficient.

## Explicit normalization only

The default policy is fail-closed:

- resampling is forbidden unless explicitly enabled;
- channel remix is forbidden unless explicitly enabled;
- sample-format conversion is forbidden unless explicitly enabled;
- end trim/pad is forbidden unless `max_edge_adjustment_frames` explicitly permits it;
- non-zero timeline origin is rejected.

A23 does not silently stretch, shift, pad, trim or remap channels merely to make an artifact playable.

If normalization is required, the evidence chain binds:

`raw artifact SHA -> normalization plan SHA -> normalizer artifact SHA -> execution evidence SHA -> normalized artifact SHA`.

The resulting WAV still must exactly equal the source mix format/frame count before becoming mix-ready. Therefore an unrelated pre-existing WAV cannot be substituted as a normalized result merely because its format looks correct.

## WAV structural integrity

The A23 inspector rejects malformed/truncated RIFF/WAVE, duplicate or missing required chunks, unsupported codec/sample formats, invalid block alignment/byte rate/data alignment and symlink audio inputs.

This is a Lane-local compatibility validator. Existing A13 deep sample pathology analysis remains authoritative for broader output integrity; A23 does not weaken or replace it.

## Atomic generated-variant activation

`GeneratedStemVariantStore` separates immutable content-addressed objects/manifests from the active role pointer.

Commit order:

1. verify candidate against the mix-ready receipt;
2. copy content-addressed WAV under project control and `fsync` it;
3. persist immutable generation/variant manifest;
4. atomically replace the active `<project, role>` pointer.

Consequences:

- same generation+variant+artifact is idempotent;
- same variant index with a different generation/artifact is a conflict;
- variant index regression is rejected;
- process failure after object copy leaves the old active variant unchanged;
- process failure after new manifest creation but before pointer replacement also leaves the old active variant unchanged;
- an orphan object/manifest is harmless and can be reclaimed later;
- active pointer corruption or active object mutation fails closed rather than silently loading an inconsistent generated stem.

This preserves the previously accepted variant until the replacement is completely durable.

## Privacy / evidence

Public A23 evidence contains:

- project/generation hashes;
- role/variant index;
- artifact hash/bytes;
- audio format/frame metadata;
- mix-ready receipt hash.

It does not emit:

- project path;
- source/generated audio;
- raw prompt;
- account/runtime execution ID;
- signed URLs;
- private normalizer path.

## Validation

Executed locally against the A23 logic:

- focused regression: `22/22 PASS`;
- JSON Schema sample validation: `4/4 PASS`;
- implementation/test `py_compile`: `PASS`.

Covered faults include sample-rate/channel/sample-format/frame mismatch, non-zero timeline origin, missing/tampered normalization provenance, substituted direct artifact, symlink input, variant conflict/regression, crash after object/manfiest persistence, active pointer corruption and active object mutation.

The earlier design/fault exploration included additional cases; the durable checked-in regression is the 22-test focused suite above.

## NON-PARITY boundary

No real generated-audio campaign or current-iPhone Moises comparison was performed in A23. Therefore:

- `MOI-P025` remains canonical `MISSING`;
- `parity_claim` remains `NONE`;
- synthetic WAV/fault/schema evidence is `NON_PARITY_EVIDENCE_ONLY`.

Remaining external/HQ evidence includes current-iPhone generated-stem timing behavior, rights-cleared real generated audio, exact role/mode/credit UX, actual normalization/runtime behavior if needed, integrated iPhone Playback/DSP compatibility and blind current-iPhone differential listening.

## Files

- `Separation/Server/generated_stem_mix_compatibility.py`
- `Separation/Tests/test_generated_stem_mix_compatibility.py`
- `Separation/Evaluation/schemas/generated-stem-mix-policy.schema.json`
- `Separation/Evaluation/schemas/generated-stem-normalization-plan.schema.json`
- `Separation/Evaluation/schemas/generated-stem-normalization-receipt.schema.json`
- `Separation/Evaluation/schemas/generated-stem-active-variant-evidence.schema.json`
- `Processing/Tests/L1-A23_GENERATED_STEM_MIX_COMPATIBILITY_MATRIX.json`

## Next lane-local gap

After A23, the highest-value remaining non-external P025 engineering gap is generated-stem retention/delete/credit-refund coupling and orphan cleanup across regeneration/cancel/delete/relaunch. That should be handled without weakening A09/A21 privacy/deletion semantics.
