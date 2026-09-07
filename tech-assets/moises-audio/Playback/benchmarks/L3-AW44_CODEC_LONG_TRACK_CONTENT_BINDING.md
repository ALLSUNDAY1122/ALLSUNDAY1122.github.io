# L3-AW44｜Codec / Long-Track Content Binding

Result: `COMPLETE_NON_PARITY`

## Purpose
AW43 can prove a declared codec family was exercised as clean/truncated/corrupted, while AW30 can produce a long-track differential completion receipt. Before AW44 those durable records could be stored beside one another without proving that the AW43 clean decoded PCM was the exact PCM role whose SHA-256 identity participated in the AW30 run binding.

AW44 adds a content-addressed bridge. It is **not** a signature, provenance service, physical-device attestation, or PARITY proof.

## Contract
`Lane3CodecLongTrackEvidenceBinder.makeReceipt` requires:

1. one AW43 clean report with exact full bounded sweep;
2. one AW43 truncated report with an actually observed expected fault;
3. one AW43 corrupted report with an actually observed expected fault;
4. the same declared codec label and unmodified baseline channels/sample-rate/frame-count across all three reports;
5. distinct fixture IDs and rights-cleared >=30-minute baseline semantics inherited from AW43;
6. the clean `Lane3PCMChunkReadable` source itself;
7. an explicit AW30 PCM role: `reference` or `observed`;
8. the AW30 unified evidence result and its AW30 completion receipt.

The binder then:

- re-executes the AW43 clean bounded sweep and requires byte-for-byte report equality;
- hashes the clean PCM through AW30's existing `SHA256_FLOAT32_LE_V1` identity path;
- requires that digest to equal the selected AW30 reference/observed digest and frame count;
- recomputes AW30 `runBindingSHA256` from the same fields used by `Lane3LongTrackUnifiedEvidencePipelineV2` rather than trusting the stored hash string;
- validates the AW30 completion receipt and requires its run binding to equal the recomputed unified run binding;
- SHA-256 content-binds every AW43 report field, the ordered clean/truncated/corrupted family, the AW30 completion receipt, the selected PCM identity and the AW30 run binding into one receipt.

## Fail-closed cases
- clean report cannot be reproduced from the supplied clean source;
- clean source PCM differs from the selected AW30 role;
- AW30 report and completion name different runs;
- AW30 run-binding string was changed without matching the fields from which it is derived;
- codec labels or baseline metadata disagree across the three AW43 cells;
- fixture IDs are reused;
- truncated/corrupted expected fault was not actually observed;
- rights/long-track/bounded-read/privacy contracts are not satisfied.

## Deliberate non-claims
- SHA-256 content addressing is not an authenticity signature (`authenticitySignatureIncluded=false`).
- AW43 does not contain a hash of the original compressed baseline plus derivative-generation recipe. Therefore `derivativeLineageCryptographicallyProven=false`: AW44 does **not** prove that the truncated/corrupted files were mechanically derived from the exact clean compressed file.
- `codecFamilyPhysicalIPhoneComplete` can describe AW43 cell environment only. The final AW44 receipt keeps `authoritativePhysicalEvidenceAllowed=false` and `parityPromotionAllowed=false` because AW30/device/Moises/listening authority remains HQ-owned.
- No raw PCM, raw compressed bytes or source paths are retained by the receipt.

## Validation performed in this wave
Local environment: Swift 6.2.1 Linux, language mode 6, strict concurrency complete, warnings as errors.

Because the execution container cannot resolve `github.com`, the complete Worker branch could not be cloned locally. The new production binder was compiled and executed against exact-shape repository interface stubs. This is structural/non-selected evidence only.

Structural self-test PASS:
- valid reference-role binding;
- receipt rebuild validation;
- different clean PCM rejected;
- stored AW30 run hash that is internally self-consistent with completion but does not recompute from AW30 fields rejected;
- observed-role binding accepts the observed digest even when the AW30 reference sample-rate differs within the existing long-track tolerance;
- derivative-lineage and authenticity-signature flags remain false.

Structural canonicalization stress PASS:
- 1,000,000 report-binding operations;
- no state is retained between operations;
- checksum `3411186190977283808`;
- local interface-stub elapsed about 4.857 s. This timing is **not** production SHA-256 performance.

A repository-native self-test, 100,000-operation production SHA-256 stress, and 20 x 10,000 production SHA-256 benchmark are authored under `Playback/Tests`. They are intentionally not claimed executed until HQ's permanent full Lane3 gate compiles/runs the relevant selected checkpoint.

## HQ execution recipe
1. Keep the AW43 clean/truncated/corrupted family from one declared codec/baseline group.
2. Run AW30 with the clean decoded PCM as either `reference` or `observed` and record that role explicitly.
3. Preserve the exact clean source object/file content long enough for AW44 re-execution and SHA-256 identity verification; do not substitute a separately decoded/transcoded file unless its PCM identity is identical.
4. Build and validate the AW44 receipt.
5. For physical evidence, execute the codec matrix and AW30 on physical iPhone with rights-cleared real audio and separately record RSS/thermal/battery plus current-Moises/listening evidence.
6. Do not infer compressed derivative lineage from the AW44 receipt. If HQ needs that property, add a higher-level fixture-generation manifest containing baseline compressed digest + deterministic derivative recipe/digest.

## PARITY
No PARITY row is promoted by AW44. P006/P007/P008/P010/P012/P014/P015 and P021 remain subject to their existing integrated real-device/real-audio gates.
