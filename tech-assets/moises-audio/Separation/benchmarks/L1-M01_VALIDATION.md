# L1-M01 — Rights-aware separation evaluation package validation

Bundle: `L1-M01`  
Lane: `LANE-1-SEPARATION-PROCESSING`  
Assignment epoch: `2`  
Frozen Shared/App integration contract: `17d129c9f0faaf7f24a96439cf3aa3cd0e7c02e8`  
PARITY impact: **NONE — evidence tooling only; P003/P004 remain MISSING until real gates are executed.**

## Bundle done_when mapping

### 1. G1/G2 rights manifest ingestion and fail-closed validation — PASS for tooling

Implemented in `Evaluation/evaluation_core.py` with machine-readable fixture schema and G1/G2 templates.

The gate requires fixture identity, class, opaque private rights-record ID, rights basis, `VERIFIED` rights status, commercial-engineering permission, real-vs-synthetic declaration, requested roles, immutable file hashes, format metadata, genre and hard-case metadata. G1 additionally requires a clean reference stem for every requested role. G2 requires permission to submit the same source to the reference service.

`PARITY_CANDIDATE` explicitly rejects G3/G4/G5 fixture classes. File paths are relative-root constrained and SHA-256 verified.

Important limitation: a public JSON manifest cannot independently prove that a performer/rightsholder actually signed a grant or that an operator truthfully labelled audio as real. The signed/private rights record remains a required Human Gate outside GitHub. This package validates the recorded claim and binds it to immutable audio hashes; it does not manufacture legal authority.

### 2. Provider/model/version/cost/latency/result evidence schema — PASS

`Evaluation/schemas/run-evidence-input.schema.json` and runtime validation require:
- provider ID / kind;
- model name and version;
- execution topology;
- opaque commercial-approval basis ID;
- upload / queue / inference / download / total timing;
- currency / total cost / optional credit consumption / accounting basis;
- one result per requested role with container, sample rate, channels, frames, duration and artifact identity.

Missing, duplicate and unexpected stem roles fail closed. Local copies are SHA-256 checked. A remote-only result is accepted only while its expiry is still in the future; an expired remote-only output fails.

### 3. Objective reference-stem metric runner + blind listening capture — PASS for executable mechanics

For G1 clean references, the runner performs chunked PCM WAV evaluation rather than whole-song loading. It calculates per-stem SI-SDR, RMSE, duration alignment and complete-set mixture reconstruction normalized RMSE / peak. It rejects sample-rate, channel, PCM-width and material-duration incompatibility. SI-SDR is emitted as finite JSON and capped to a finite range rather than serializing Infinity/NaN.

Blind-listening capture follows the canonical `LISTENING_UX_RUBRIC.md` dimensions and 0–4 integer range. `PARITY_CANDIDATE` differential format requires both PROJECT and REFERENCE records for every requested role where reference submission rights exist.

No global scalar or threshold is used to promote quality. Real multi-genre distributions and HQ differential review are still mandatory.

### 4. Negative / edge cases — PASS

Executable tests cover:
- missing commercial rights;
- G2 without reference-service submission rights;
- licensed-synthetic PARITY attempt;
- generated-signal PARITY attempt;
- missing private rights-record ID;
- missing result stem;
- duplicate result role;
- expired remote-only output;
- source/reference hash mismatch;
- objective sample-rate mismatch;
- missing provider model version;
- blind-listening score out of range;
- incomplete PROJECT/REFERENCE blind pair;
- JSON schemas being machine-readable;
- complete blind-pair format;
- positive G1 evaluator mechanics and finite objective output.

### 5. Reproducible operator instructions and explicit NON-PARITY examples — PASS

`L1-M01_OPERATOR_RUNBOOK.md` gives concrete CLI commands, external-rights requirements, fail-closed behavior and interpretation rules. G1/G2/run/listening templates are committed. `non_parity_evidence.example.json` explicitly demonstrates the evidence state and cannot be mistaken for a quality pass.

Every `evaluate` output sets:

`"parity_state": "NON_PARITY_EVIDENCE_ONLY"`

A single run cannot promote PARITY.

## Machine validation performed

Local executable validation of the implemented evaluator mechanics:

- `python3 -m py_compile Evaluation/evaluation_core.py Evaluation/cli.py Tests/test_evaluation_package.py` — **PASS**.
- `python3 -m unittest discover -s Tests -p 'test_evaluation_package.py'` — **16 tests, 0 failures**.
- CLI `evaluate` end-to-end smoke — **exit 0** and evidence JSON emitted.
- Smoke evidence state — **`NON_PARITY_EVIDENCE_ONLY`**.
- Smoke objective role set — bass / drums / other / vocals.

The automated unit/smoke WAVs are generated signals used solely to prove evaluator mechanics. Their manifest declarations are not real rights evidence and they are **not** separation-quality, legal-clearance or PARITY evidence.

GitHub read-back after persistence confirmed the committed evaluator core, CLI and test suite are present on `moises/wp1-separation-processing`. The package remains standard-library-only for the executable Python path.

## Required real evidence still absent

This bundle intentionally does not claim the external gates are solved. The repository still lacks all of the following executable final evidence:

- approved production separator credentials/commercial/privacy/retention/cancellation terms, or a project-owned rights-cleared trained checkpoint;
- actual G1 rights-cleared real multitracks meeting the canonical minimum set;
- actual G2 rights-cleared real differential tracks meeting the canonical minimum set;
- live separation outputs from those fixtures;
- real per-stem quality distribution, blind listening outcome, latency/cost distribution and failure/recovery evidence;
- integrated current-iPhone / device evidence and HQ Moises differential review.

Therefore no statement in L1-M01 should be interpreted as Moises-equivalent separation quality.

## Bundle conclusion

`L1-M01` done_when is satisfied for the **evaluation package itself**: executable evaluator, rights gates, machine-readable schemas, negative tests, operator runbook and durable NON-PARITY examples are committed. Real quality remains blocked on real external inputs and is explicitly not promoted.
