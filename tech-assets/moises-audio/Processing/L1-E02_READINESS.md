# L1-E02 Readiness — Rights-Cleared Real Audio Intake

Captured: 2026-08-24 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`

Engineering readiness: `READY_PENDING_EXTERNAL_INPUT`  
Live gate: `PENDING_EXTERNAL_INPUT`  
PARITY claim: `NONE`

## Roadmap acceptance

Lane 1 E02 requires:

- G1: rights-cleared real multitrack audio with isolated source/reference stems;
- G2: rights-cleared real recording that may be submitted both to the project processing route and the current-iPhone Moises reference route.

Acceptance requires the G1/G2 rights manifest and hashes to pass A19 and forbids synthetic-only evidence.

No actual rights-cleared G1/G2 media or private rights records were supplied in this wave, so live E02 is intentionally not marked complete. This is a pending external/live input condition, not `BLOCKED_HUMAN` and not PARITY.

## Gap closed by E02 readiness

A19 already validates:

- fixture/media SHA-256;
- real/non-synthetic fixture flags;
- G1 complete reference-stem sets;
- G1 WAV alignment and metadata;
- G2 reference-service submission flag;
- corpus-level genre/duration/role/production/hard-case coverage;
- the deterministic A19 Golden corpus lock.

However, A19 starts from `rights_status = VERIFIED` and related permission fields inside each fixture manifest. E02 adds the missing external evidence binding: those manifest claims must now be backed by a private machine-readable rights/provenance grant whose bytes and underlying source-rights document are SHA-verified.

## Implementation

`Separation/Evaluation/rights_cleared_audio_intake.py` performs a second fail-closed intake pass after A19.

It requires a private rights index covering exactly every fixture in the A19 report. Each record binds:

- fixture ID;
- expected G1/G2 group;
- fixture-manifest relative path and SHA-256;
- private grant-record relative path and SHA-256.

The private grant record binds:

- raw `rights_record_id` matching the fixture manifest;
- fixture ID;
- VERIFIED grant state;
- authority-reviewed flag;
- revoked state;
- effective / expiry dates;
- underlying source-rights document path and SHA-256;
- real-recording provenance attestation;
- non-synthetic/non-generated attestation;
- private origin-record ID;
- exact permission profile.

## G1 rights rules

A G1 fixture must have all of the following in addition to A19 media/stem validation:

- commercial engineering use permitted;
- project/provider processing submission permitted;
- isolated-source evaluation permitted;
- internal stem evaluation permitted;
- real-recorded-music provenance attested;
- synthetic/generated provenance explicitly false.

The E02 grant does not invent or infer isolated stems. A19 remains responsible for verifying that the physical G1 reference stems exist, hash correctly, cover the required roles and align with the mixture.

## G2 rights rules

A G2 fixture must have:

- commercial engineering use permitted;
- project/provider processing submission permitted;
- current reference-service submission permitted;
- real-recorded-music provenance attested;
- synthetic/generated provenance explicitly false.

The fixture manifest itself must also state `reference_service_submission_allowed = true`. A private grant cannot be used to silently repair an inconsistent manifest, and a manifest cannot overclaim permission not present in the private grant.

## A19 ↔ E02 evidence chain

E02 refuses to run from an A19 result unless:

- A19 `intake_state = READY_FOR_HQ_GOLDEN_GATE`;
- A19 remains `NON_PARITY_EVIDENCE_ONLY`;
- corpus ID/revision match;
- every fixture has exactly one E02 rights record;
- fixture group matches;
- fixture-manifest SHA equals both the physical file and the A19 record;
- the private raw rights record ID hashes to the same A19 domain-separated `rights_record_ref_hash`.

A successful live E02 intake emits a deterministic `e02_rights_intake_lock_sha256` built on top of the A19 corpus lock plus the verified rights evidence rows. Record ordering does not alter the lock; semantic rights/media changes do.

## Privacy boundary

Public/durable E02 evidence deliberately excludes:

- raw rights record IDs;
- raw origin/provenance record IDs;
- private grant paths;
- source-contract paths;
- contract text;
- media paths/titles;
- raw audio.

It retains only hashes, fixture aliases, groups, dates and permission-profile hashes needed to reproduce the audit chain.

Private rights records and source documents should remain outside the public repository. The checked-in private schemas/templates describe the expected structure without containing real grants.

Schemas:

- `Separation/Evaluation/schemas/rights-cleared-audio-index.schema.json`
- `Separation/Evaluation/schemas/rights-cleared-audio-grant.schema.json`
- `Separation/Evaluation/schemas/rights-cleared-audio-evidence.schema.json`

Templates:

- `Separation/Evaluation/examples/rights-cleared-audio-index.private.template.json`
- `Separation/Evaluation/examples/rights-cleared-audio-grant.private.template.json`

## Machine verification

Executed against the final E02 validator semantics in repository-equivalent `Separation/Evaluation` -> `Separation/Tests` layout:

- rights/provenance/hash/privacy/fault assertions: **37 / 37 PASS**;
- `py_compile`: **PASS**.

Coverage includes A19-state/corpus binding, exact fixture coverage, group mismatch, physical fixture/grant/source-document SHA mutation, grant state, authority review, revocation, effective/expiry dates, real/synthetic provenance, commercial/project permissions, G1 isolated-stem permissions, G2 reference submission, raw rights-record ID matching, A19 rights-ref matching, manifest overclaim rejection, missing/duplicate records, privacy redaction and order-independent lock determinism.

The test media/control data is synthetic and exists only to verify gate semantics. It is not Golden evidence and cannot satisfy live E02.

Machine-readable matrix:

- `Processing/Tests/L1-E02_RIGHTS_INTAKE_MATRIX.json`

Checked-in regression suite:

- `Separation/Tests/test_rights_cleared_audio_intake.py`

## How HQ runs live E02

Keep the rights root private, then run E02 against the already-approved A19 corpus/index/policy:

```text
python Separation/Evaluation/rights_cleared_audio_intake.py \
  --corpus-root /private/golden-corpus \
  --a19-index golden-corpus-index.json \
  --a19-policy golden-corpus-policy.json \
  --rights-root /private/rights \
  --rights-index rights-cleared-audio-index.json \
  --out /private/evidence/e02-rights-cleared-audio.sanitized.json
```

A real pass must produce `READY_FOR_HQ_LIVE_AUDIO_GATE` and an E02 rights intake lock. Placeholder templates, missing rights documents, synthetic-only media or self-declared fixture rights without the matching private grant do not pass.

## Remaining E02 live inputs

Still required:

1. actual G1 real multitrack media and isolated sources;
2. actual G2 real recordings;
3. private rights/provenance grant records for every fixture;
4. underlying source-rights documents with physical SHA-256;
5. authority review of each grant;
6. HQ approval of the A19 coverage policy and corpus lock.

Until those exist, Worker 1 remains `CHECKPOINT_READY`. E01 and E02 are prepared but pending their actual external inputs.

## Next live gate

After E01 and E02 live acceptance, the next roadmap gate is `L1-E03 | Live Separation Benchmark` covering 2-stem, core 4-stem, representative custom/additional instruments, and Hi-Fi/advanced mode where current Reference requires it.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

E02 readiness does not change `MOI-P003`, `MOI-P004`, `MOI-P005`, `MOI-P020`, `MOI-P021` or `MOI-P024`. HQ must collect real provider, real-audio, current-iPhone reference, blind-review and real-device evidence before modifying `PARITY_MATRIX.json`.
