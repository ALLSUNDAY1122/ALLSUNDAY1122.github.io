# L1-M04 — Real separator differential batch gate validation

Bundle: `L1-M04`  
Lane: `LANE-1-SEPARATION-PROCESSING`  
Assignment epoch: `2`  
Frozen Shared/App contract: `17d129c9f0faaf7f24a96439cf3aa3cd0e7c02e8`  
PARITY impact: **NONE. This bundle prepares the executable real-audio gate; it does not supply the missing real provider/reference/device evidence.**

## Done-when addressed

The lane-plan done-when is:

> one command/runbook can execute the complete future real-audio separation gate once external inputs are supplied

L1-M04 now provides that executable path through `Separation/Evaluation/differential_gate.py run` and `L1-M04_REAL_DIFFERENTIAL_RUNBOOK.md`.

## Implemented surface

### Batch and coverage gate

`differential_common.py` validates a machine-readable differential plan and enforces:

- evidence state fixed to `NON_PARITY_EVIDENCE_ONLY`;
- reference system fixed to `MOISES_CURRENT_IPHONE`;
- explicit commercial/privacy/reference-rights/idempotency approval record IDs;
- production credential environment variable names and presence for PARITY candidates;
- safe root-relative fixture/run paths;
- case/genre/duration/target-role coverage;
- provider driver argv as an explicit non-shell command;
- stable idempotency requirement for PARITY retries;
- `{idempotency_key}` actually reaching a driver that claims stable idempotency.

For `PARITY_CANDIDATE`, code-enforced minimum floors cannot be weakened in the plan: at least 6 real cases, at least 3 genres, short/medium/long coverage and at least one vocals/drums/bass/other case.

### Project execution / retry evidence

`differential_execute.py` executes each project case with a deterministic batch+case idempotency key, bounded retry count and timeout. It records attempt wall time, exit code, stable error code and run-manifest path. Provider stdout/stderr is not persisted as durable evidence.

Existing valid project run manifests are reused. Invalid stale outputs are rejected and the same case-scoped key is used for retry.

### Comparison manifest without reference-asset copying

`comparison-input-manifest.json` binds each fixture/project/reference manifest by path plus SHA-256 and explicitly records `reference_assets_copied_by_executor = false`.

Missing reference capture produces `L1M04_REFERENCE_CAPTURE_REQUIRED` rather than silently omitting the case.

### Current-iPhone identity boundary

Reference manifests must identify exactly:

- `provider_id = MOISES_CURRENT_IPHONE`
- `provider_kind = REFERENCE_APP_CURRENT_IPHONE`

Project runs are rejected if they identify as the reference system. This prevents project output from being accidentally accepted as its own comparator.

### Objective + blind review

The batch reuses the L1-M01 rights-aware evaluator for fixture validation and objective metrics. It creates deterministic blind A/B worksheets plus a separate private reveal map.

Both PROJECT and REFERENCE listening artifacts must be existing local files inside the gate root; a remote-only URL or missing path cannot become review evidence.

Reviewer score validation covers the fixed nine listening dimensions and requires reviewer/system/role coverage specified by the acceptance policy.

### Acceptance calculation

`differential_review.py` calculates:

- case failure rate;
- retry fraction;
- mean wall-time ratio versus reference;
- mean objective SI-SDR delta where ground-truth stems exist;
- objective-case count;
- mean blinded listening delta;
- worst per-role overall-practice-usability delta;
- optional project cost-per-audio-minute ceiling;
- reviewer coverage.

A passing result is `LANE_GATE_CANDIDATE_PASS`, while `parity_state` remains `NON_PARITY_EVIDENCE_ONLY`.

## Machine-readable contracts

Committed schemas:

- `Evaluation/schemas/differential-batch-plan.schema.json`
- `Evaluation/schemas/comparison-input-manifest.schema.json`
- `Evaluation/schemas/reviewer-scores.schema.json`
- `Evaluation/schemas/differential-acceptance.schema.json`

Committed representative plan:

- `Evaluation/examples/differential-batch-plan.template.json`

The template contains eight multi-genre/multi-duration cases and includes both 4-stem and 2-stem target configurations.

## Executable fault / contract tests

Committed:

`Separation/Tests/test_differential_gate.py`

The executable contract test file contains 17 cases covering:

1. valid PARITY plan normalization;
2. evidence-state self-promotion rejection;
3. non-current-iPhone reference rejection;
4. missing production credential rejection;
5. unsafe credential environment-name rejection;
6. stable-idempotency driver missing the key placeholder;
7. PARITY retry without proven stable idempotency;
8. non-configurable six-case PARITY floor;
9. non-configurable three-genre PARITY floor;
10. non-configurable short/medium/long floor;
11. non-configurable core 4-stem floor;
12. duplicate case IDs;
13. path escape;
14. deterministic case-scoped idempotency key;
15. stable key injection into provider argv;
16. project/reference identity non-interchangeability;
17. blind-review rejection when local comparison artifacts do not exist.

During L1-M04 implementation, the broader orchestration/fault suite completed **17 scenarios / 17 PASS** before branch persistence. A final Python compatibility-only quote adjustment was then followed by representative re-execution of the one-command success path, rights fail-closed path and stable-idempotency retry path; those representative cases passed. In the continuation turn, the committed test file was regenerated against the remote-read-back public APIs and Python syntax compilation passed before commit.

This evidence must not be interpreted as a live-provider or real-audio quality result.

## Runbook behavior / staged external inputs

The same canonical command is restartable across the external stages:

1. validate legal/credential/fixture inputs and execute PROJECT batch;
2. if current-iPhone reference manifests are missing, exit external-input-required after writing the comparison manifest;
3. after reference capture, generate objective evidence and blind-review worksheet;
4. if human scores are absent, exit external-input-required after creating score templates;
5. after reviewer scores exist, rerun the same command to calculate acceptance.

This staged behavior is deliberate: human/reference inputs are not fabricated by the executor.

## Remaining external gates

The following are still absent and therefore cannot be claimed by Worker 1:

- approved production separator credentials and signed commercial terms;
- approved real user-audio privacy/retention/deletion terms;
- a verified upstream stable-idempotency/no-duplicate-billing guarantee;
- rights-cleared executable G1/G2 real-audio corpus;
- live project separator outputs produced from that corpus;
- externally captured current-iPhone Moises comparison outputs;
- blinded human review scores;
- real latency, retry, failure and cost distribution;
- iPhone background/relaunch/storage/thermal/long-track evidence;
- four-lane integrated product differential.

Accordingly, P003/P004/P005/P020/P021/P024 and any other dependent current-iPhone PARITY rows remain unchanged/MISSING until HQ runs the applicable real evidence gates.

## Checkpoint recommendation

L1-M01 through L1-M04 now form one coherent Lane 1 checkpoint:

- L1-M01: rights-aware real-audio evaluation package;
- L1-M02: processing ambiguity/cancel/reconnect/idempotency hardening;
- L1-M03: verified project-controlled output/cost/retention assurance;
- L1-M04: future live real-separator differential batch gate.

Worker 1 should therefore signal `CHECKPOINT_READY` after remote read-back and frozen-base scope audit. HQ should integrate semantically and retain final PARITY ownership.
