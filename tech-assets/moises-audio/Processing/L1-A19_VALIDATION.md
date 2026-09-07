# L1-A19 Validation — Golden G1/G2 Corpus Intake Hardening

Captured: 2026-08-24 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`  
Result: `COMPLETE_NON_PARITY`

## Goal

Make rights-cleared real-audio delivery immediately machine-checkable before any fixture can enter the HQ Golden evaluation gate. A19 prevents a corpus from being treated as Golden-ready merely because files exist or individual hashes happen to match.

No real Golden corpus was supplied in this Wave. No production Golden corpus lock has been issued.

## Reused M01 foundation

A19 extends the existing rights-aware evaluation package rather than replacing it.

`Separation/Evaluation/evaluation_core.py` already validates each fixture independently:

- `rights_status = VERIFIED`;
- commercial engineering use permission;
- real-recorded/non-synthetic declarations for real fixture classes;
- G1 (`PROJECT_OWNED_REAL_MULTITRACK`) reference stems for every requested role;
- G2 (`RIGHTS_CLEARED_REAL_REFERENCE`) reference-service submission permission;
- mixture and G1 reference-stem SHA-256 identity;
- safe relative paths and supported role vocabulary;
- synthetic/non-real classes cannot support `PARITY_CANDIDATE`.

A19 adds the missing corpus-level intake layer above those checks.

## Implementation

### `Separation/Evaluation/golden_corpus_intake.py`

The intake command consumes:

1. a Golden corpus index;
2. an HQ-approved coverage policy;
3. existing M01 fixture-rights manifests and audio files.

It produces a privacy-safe machine-readable intake report only when every fixture and the complete corpus pass.

Example invocation after real files arrive:

```text
python Separation/Evaluation/golden_corpus_intake.py \
  --root /secure/golden-corpus \
  --index golden-index.json \
  --policy golden-policy.json \
  --out golden-intake-report.json
```

The command returns a stable error code only on validation failure. It does not print media paths, rights text or signed-service material into the normal failure output.

## G1 / G2 distinction

Only the two real-audio fixture classes can enter A19:

- **G1** = `PROJECT_OWNED_REAL_MULTITRACK`
  - real mixture;
  - clean reference stem for every requested role;
  - objective stem/reconstruction evaluation can be run later.
- **G2** = `RIGHTS_CLEARED_REAL_REFERENCE`
  - real source audio;
  - reference-service submission permission;
  - intended for legally permitted PROJECT-vs-reference differential listening when clean source stems are not available.

The index declares the expected group, but the underlying fixture class remains authoritative. A G1 manifest cannot be relabeled as G2 or vice versa merely by editing the corpus index.

## Fixture lock and physical audio checks

Each index entry locks the exact fixture-rights manifest SHA-256. The manifest then locks mixture/reference SHA-256 values using the existing M01 validator.

A19 additionally verifies the actual WAV mixture against declared:

- sample rate;
- channels;
- duration within policy tolerance.

For G1 reference stems it also requires:

- sample rate equal to the mixture;
- channel count equal to the mixture;
- duration/frame alignment within policy tolerance;
- no duplicate reference SHA across different roles;
- no reference stem SHA equal to the mixture SHA.

A corpus can also reject duplicate mixture SHA values across fixture IDs, preventing one recording from being counted repeatedly to satisfy nominal coverage.

## Corpus coverage gate

Coverage is controlled by a machine-readable policy. The implemented dimensions are:

- minimum G1 and G2 fixture count;
- global and per-group genre diversity;
- explicit duration buckets and required global coverage;
- per-group duration-bucket diversity;
- required role sets in selected groups;
- global and per-group production-bucket diversity;
- optional required production buckets;
- minimum/required hard-case coverage;
- groups that require reference-service submission permission.

The checked-in policy template is an **engineering intake starting point**, not a Moises PARITY threshold. Counts, duration ranges, production labels and hard-case requirements must be approved by HQ before a real corpus is accepted.

## Deterministic Golden corpus lock

A successful intake generates `corpus_lock_sha256` from:

- corpus ID and revision;
- normalized policy SHA-256;
- each fixture ID/group;
- fixture manifest SHA-256;
- mixture SHA-256;
- G1 role-to-reference-SHA mapping;
- production bucket.

Fixture ordering does not alter the lock. Changes to policy, fixture manifests, mixture audio, G1 reference audio, G1/G2 identity or production classification do alter the lock.

The synthetic test-suite lock is intentionally **not** recorded as a Golden lock because those fixtures are test material only.

## Path and control-file safety

A19 fails closed on:

- absolute/out-of-root/path-traversal paths;
- symlinked control, manifest or audio path components;
- missing control/manifest/audio files;
- corrupt manifest JSON;
- unknown index/policy fields;
- duplicate manifest paths/fixture IDs;
- malformed or overlapping duration-bucket policy.

This prevents an intake manifest from silently binding to media outside the declared Golden root.

## Privacy-safe report

The report contains the minimum information needed to reproduce corpus identity and coverage:

- fixture ID and G1/G2 group;
- manifest/mixture/reference SHA-256 values;
- domain-separated rights-record reference hash;
- genre/production/duration bucket;
- sample rate/channels;
- requested roles/hard-case labels;
- coverage summary and corpus lock.

It deliberately omits:

- audio paths;
- media/title aliases;
- raw rights-record IDs or signed agreements;
- raw audio;
- provider credentials or signed URLs.

Schemas:

- `Separation/Evaluation/schemas/golden-corpus-index.schema.json`
- `Separation/Evaluation/schemas/golden-corpus-policy.schema.json`
- `Separation/Evaluation/schemas/golden-corpus-report.schema.json`

Placeholder templates:

- `Separation/Evaluation/examples/golden-corpus-index.template.json`
- `Separation/Evaluation/examples/golden-corpus-policy.template.json`

The index template contains placeholder paths/zero hashes and cannot pass intake until replaced with actual rights-cleared manifests and their real SHA-256 values.

## Real / non-synthetic provenance boundary

A19 does **not** claim that waveform inspection can prove that a recording is legally usable or genuinely non-synthetic.

The real/non-synthetic property remains an authenticated rights/provenance input represented by the existing VERIFIED rights record and fixture declarations. A19 checks that those declarations are internally consistent with the allowed G1/G2 class and then independently validates the delivered file identity and WAV metadata.

Final legal approval remains an HQ/human rights gate.

## Machine verification

Executed in the lane-local environment against the final A19 intake semantics:

- broad corpus/fault suite: **50 / 50 PASS**;
- checked-in critical regression suite: **8 / 8 PASS**;
- `py_compile` for A19 implementation and checked-in test: **PASS**.

The broad suite covers manifest/audio SHA mutation, rights/provenance rejection, group relabeling, duplicate audio, physical WAV metadata, G1 reference alignment, all coverage dimensions, schema corruption, traversal/symlink behavior and stable CLI failures.

The checked-in test is:

`Separation/Tests/test_golden_corpus_intake.py`

All generated test WAVs are synthetic and exist only to test the validator. They are not Golden evidence and cannot change any PARITY state.

Current branch M01 interface audit also confirmed that the imported A19 dependencies are present in `evaluation_core.py`: `EvaluationError`, `load_json`, `normalize_sha256`, `read_wav_info`, `safe_relative_path`, `sha256_file`, and `validate_fixture_manifest`.

Machine-readable Wave matrix:

`Processing/Tests/L1-A19_GOLDEN_INTAKE_MATRIX.json`

## What is still missing

A19 makes the intake gate executable, but it cannot run the real Golden gate until external material exists:

- rights-cleared real G1 multitrack audio and private rights records;
- rights-cleared real G2 reference-submission audio and private rights records;
- HQ approval of the final Golden coverage policy;
- live separator credentials/results;
- current-iPhone Moises differential runs;
- blinded human review and real-device performance/recovery evidence.

Golden Dataset absence, SHA not-yet-issued and Golden measurement not-yet-run are external pending conditions, not reasons to mark this Worker lane `BLOCKED_HUMAN`. A19 is complete as engineering intake infrastructure and the actual Golden validation remains an HQ-owned later gate.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

`MOI-P003`, `MOI-P004` and `MOI-P005` remain `MISSING`. A19 prevents invalid or under-covered source material from reaching those differential gates, but it does not provide the missing real-audio comparison evidence itself. P020/P021/P024 are also unchanged.
