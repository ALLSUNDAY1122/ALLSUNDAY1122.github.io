# L1-E10｜Generic Evaluation Provenance Producer Readiness

Status: `READY_PENDING_EXTERNAL_INPUT`  
Live generic source production: `PENDING_EXTERNAL_INPUT`  
PARITY claim: `NONE`

## Purpose

E09 deliberately refuses to trust a hand-authored generic route summary, but its operational / benchmark / differential measurement files were still manual inputs. E10 replaces that transcription step with a deterministic producer that derives the E09-compatible records from physically SHA-bound source artifacts.

The producer creates:

1. `GENERIC_ROUTE_OPERATIONAL_MEASUREMENT`
2. `GENERIC_ROUTE_BENCHMARK_MEASUREMENT`
3. `GENERIC_ROUTE_DIFFERENTIAL_MEASUREMENT`
4. `GENERIC_ROUTE_LIVE_EVALUATION`
5. a sanitized `GENERIC_EVALUATION_PROVENANCE_RECEIPT`

The three measurement records and the evaluation remain private inputs for E09. The sanitized receipt may be retained as durable evidence because it contains hashes/locks rather than raw private material.

## Source binding

Every E10 production run binds:

- the exact E09 decision plan semantics used for the usability threshold,
- exact E07 bytes, route kind, runtime artifact and substitution lock,
- exact E08 bytes, authority identity and E07 binding,
- a private source index with physical SHA-256 for operational, benchmark and differential sources.

The private root must be outside the repository. Path traversal and symlink traversal are rejected.

## Operational provenance

Operational values are not accepted as an unreferenced summary. Every required field must map to one or more evidence IDs whose underlying files are physically SHA-verified.

Required fields include commercial use, confidentiality, output commercial/export rights, training-on-user-content policy, service/data region, retention, deletion control and commercial basis SHA.

Legal/commercial interpretation can still require a human decision; E10 does not pretend to infer contract meaning from arbitrary prose. Its purpose is to make the recorded interpretation traceable to immutable source evidence and prevent silent transcription drift.

## Benchmark derivation

Benchmark summary values are computed from logical run records rather than copied by hand.

E10 derives:

- successful mode classes,
- G1 objective run count,
- G1 floor pass,
- final failure fraction,
- retry fraction,
- mean successful execution latency,
- mean successful cost,
- currency,
- successful run count.

Each run is bound to a physical evidence file. Duplicate run IDs, no successful runs, mixed successful-run currencies and a G1 pass without G1 evaluability fail closed.

## Differential derivation

E10 derives differential values from exact input hashes and raw review records:

- `exact_input_bytes` from project/reference SHA equality,
- mean project-minus-reference usability delta,
- material-inferiority detection,
- usability threshold pass using the exact decision plan,
- material-inferiority vote pass,
- `comparison_state`.

Zero reviews produce `WAITING_REVIEW`. Different input bytes or material inferiority produce `DIFFERENTIAL_FAIL`; they are never silently treated as comparable evidence.

Raw reviewer IDs are not emitted to the durable receipt. Review IDs are domain-hashed inside derivation locks.

## Deterministic replay

For identical inputs E10 writes byte-identical sorted JSON. `verify_existing()` recomputes the expected payload and rejects a generated measurement/evaluation file that was edited after production.

Each measurement additionally carries:

- producer tool version,
- source SHA,
- source derivation lock,
- decision-plan SHA,
- deterministic measurement lock.

## E09 schema correction discovered during E10

E09 runtime decision code already inspected `differential.comparison_state`, but the E09 JSON Schema prohibited that field. E10 corrected the schema/template so the persisted contract matches the actual decision semantics.

The E09 measurement schema was also extended to permit E10 producer provenance and measurement locks while preserving compatibility with older evidence during transition.

## Privacy

The sanitized E10 receipt does not emit:

- private filesystem paths,
- raw reviewer IDs,
- raw audio,
- contract text,
- raw billing records,
- credentials or account secrets.

Private source index, legal evidence, run evidence, review evidence and generated E09 private inputs remain outside the public repository.

## Local verification

Final E10 semantics were exercised locally before branch persistence:

- `test_generic_evaluation_provenance.py`: **18/18 unittest methods PASS**
- generated source/evaluation/measurement/receipt JSON Schema checks: **9/9 PASS**
- implementation syntax compile: **PASS**
- test syntax compile: **PASS**

Negative coverage includes evidence mutation, unproven operational fields, duplicate run/review IDs, mixed currency, invalid G1 semantics, no successful run, exact-input mismatch, zero-review pending state, material inferiority, route/runtime mismatch, E08/E07 binding mismatch, source SHA mismatch, unsafe private root/output root, path traversal and generated-output mutation.

All tests use synthetic control files. They do not prove any actual provider/runtime quality, rights status, current-iPhone behavior or product PARITY.

## Required live inputs

E10 remains external-input pending until an actual candidate supplies:

- real E07/E08 evidence for the exact runtime,
- real commercial/privacy/region/retention/deletion source evidence,
- real rights-cleared benchmark run evidence,
- real current-iPhone exact-input blind review evidence,
- the E09 route policy to be used for final selection.

## Remaining product gates

E10 reduces transcription and provenance risk; it does not select a route. E01-E09 live gates remain pending until their external evidence exists, and HQ remains responsible for integrated device validation and PARITY judgment.

P003/P004/P005/P020/P021/P024 remain unchanged. P025 is also still `MISSING` in the canonical PARITY matrix and should be considered in the next Lane 1 autonomous gap selection because AI stem generation is current-iPhone in-scope and has not been addressed by the A05-E10 separation/recovery evidence chain.

## PARITY

`parity_claim = NONE`.

No PARITY row may be promoted from E10 producer/tests/schema evidence.
