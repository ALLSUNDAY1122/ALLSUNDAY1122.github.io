# L1-E03 Readiness — Live Separation Benchmark

Captured: 2026-08-24 JST  
Worker: `Moises-Worker-1`  
Branch: `moises/wp1-separation-processing`

Engineering readiness: `READY_PENDING_EXTERNAL_INPUT`  
Live gate: `PENDING_EXTERNAL_INPUT`  
PARITY claim: `NONE`

## Roadmap acceptance

Lane 1 E03 requires live execution of:

- vocals / instrumental 2-stem;
- vocals / drums / bass / other core 4-stem;
- representative additional/custom instrument separation;
- Hi-Fi / advanced separation when the locked current-iPhone Reference scope requires it.

The gate measures success/failure, wall time, retries, cost, output integrity and G1 objective SI-SDR/reconstruction metrics. Fake or prebaked results are forbidden and required modes must succeed repeatedly.

No production credential, E01 live approval package, E02 rights-cleared real corpus or live provider output is available in this Worker wave. Live E03 is therefore intentionally not marked complete.

## Implementation

`Separation/Evaluation/live_separation_benchmark.py` is the live E03 coordinator.

It is deliberately downstream of E01 and E02. It refuses to start unless:

1. E01 evidence is `READY_FOR_LIVE_PROVIDER_GATE`;
2. E01 remains `NON_PARITY_EVIDENCE_ONLY / parity_claim = NONE`;
3. E01 says every required server credential was present and the exact-secret repository scan passed;
4. those credential environment variables are still present in the current execution process;
5. E02 evidence is `READY_FOR_HQ_LIVE_AUDIO_GATE`;
6. E02 remains `NON_PARITY_EVIDENCE_ONLY`;
7. every selected fixture is part of the E02 rights lock;
8. the physical fixture manifest SHA still equals the E02-bound SHA;
9. the physical fixture still passes the existing real/non-synthetic `PARITY_CANDIDATE` fixture validator.

This prevents a credential-only run, rights-only run, stale fixture, synthetic fixture or post-E02 fixture mutation from entering E03.

## Exact provider/model binding

Every E03 mode specifies exact:

- provider route inherited from E01;
- model name;
- model version;
- quality profile;
- canonical target roles.

The plan is rejected if the exact model/version/quality tuple is absent from the E01 production capability snapshot or if the requested role set exceeds its approved role coverage.

Each successful run manifest must identify the same E01 provider and exact mode model/version, and must report `execution_topology = server`.

A local coordinator cannot independently prove that arbitrary external code really contacted a provider merely because it writes the expected provider name. The live operator must therefore invoke the approved production driver from the exact integrated commit under the E01 credential and retain provider-side/account-side execution evidence. Test drivers and handcrafted manifests are never accepted as proof of provider reality.

## Mode contract

E03 distinguishes four mode classes instead of treating every arbitrary role list as equivalent:

- `TWO_STEM`: exactly `vocals + instrumental`;
- `CORE_FOUR_STEM`: exactly `vocals + drums + bass + other`;
- `CUSTOM_INSTRUMENT`: must include at least one additional instrument role such as guitar/keys/strings/wind;
- `HIFI_ADVANCED`: separately tracked so a normal model cannot silently stand in for a current-Reference Hi-Fi requirement.

`hifi_required_by_reference` is explicit in the plan. The checked-in template currently sets it true as a conservative live-plan placeholder because P005 remains in scope, but HQ must bind it to the locked current-iPhone Reference evidence. This is not a Moises performance threshold.

## Repeated live runs

A required mode must have at least two planned successful logical runs under the current E03 engineering policy.

Each repeat gets a distinct logical run identity. Retries of the same logical run retain the same deterministic provider idempotency key.

This separates:

- repeated-run evidence: independent logical runs;
- transport/provider retry: another attempt of the same logical run.

The two concepts are never merged into one counter.

The default `minimum_successful_runs_per_mode = 2`, failure fraction and retry fraction are project engineering acceptance controls. They are not claimed as Moises measurements and may only be changed by creating a new benchmark/session identity.

## Prebaked-result protection

Before the first E03 session is created, the coordinator calculates every expected project-run path.

If any run manifest already exists without a matching durable E03 session, the gate fails with `L1E03_PREEXISTING_RUN_UNBOUND`.

This prevents a pre-generated output from simply being placed at the expected path and counted as a live run.

The session is durably written before provider execution. The session identity binds:

- plan content;
- exact E01 evidence hash;
- exact E02 evidence hash;
- E01 approval identity;
- E02 rights intake lock.

Changing any of those while resuming fails closed.

## Crash / relaunch semantics

Before each provider subprocess is invoked, an attempt is written as `STARTED`.

After process interruption:

- if a valid run manifest and valid project-controlled artifacts were produced, the attempt is recovered as `RECOVERED_OUTPUT` and the provider is not called again;
- if no valid output exists, the attempt becomes `INTERRUPTED` and consumes one attempt from the configured budget;
- successful run manifests are SHA-bound in the session;
- a bound manifest that later changes fails with `L1E03_BOUND_RUN_MUTATED`;
- a bound manifest that disappears fails closed rather than silently regenerating historical evidence.

This composes with the A07/A16 duplicate-work and relaunch principles while remaining an evaluation coordinator rather than a replacement production orchestrator.

## Output integrity

A successful E03 logical run must have a project-controlled local artifact for every requested role.

For every artifact E03 records and verifies:

- canonical role;
- SHA-256;
- byte count.

Remote-only signed URLs cannot satisfy E03, even if still valid. Physical bytes must match the run-manifest SHA.

The production provider driver is expected to use the A13/A14 assured output path before creating the evaluation run manifest. E03 additionally revalidates local file identity. Deep production integrity evidence remains part of the integrated provider route rather than being replaced by this benchmark layer.

## Objective metrics

G1 runs are evaluated through the existing streaming evaluation core.

For G1, E03 requires objective output including:

- per-stem SI-SDR;
- RMSE / duration alignment details from the evaluator;
- mixture reconstruction error.

A successful G1 run that cannot produce objective per-stem metrics cannot count toward the G1 objective floor.

G2 is retained for later same-input current-iPhone differential listening; it is not given fabricated reference stems merely to produce an objective score.

## Timing, retries and cost

For each successful logical run E03 captures:

- provider-reported upload time;
- queue time;
- inference time;
- download time;
- provider total time;
- total wall time across the E03 provider attempts;
- attempt count;
- retry count;
- provider-reported currency and cost total;
- optional credits field;
- SHA-256 of the private cost-basis text rather than the text itself.

A reported cost is not automatically authoritative invoice reconciliation. E03 records what the live production route reports. Provider-account/dashboard/invoice reconciliation remains required wherever Gate B/HQ needs authoritative billing evidence.

## Privacy boundary

The E03 report deliberately excludes:

- credential values;
- raw audio;
- media file paths;
- media titles;
- raw rights record IDs;
- provider signed URLs;
- free-text cost basis.

It retains only the IDs, counts, timings, costs, provider/model/version identities, objective metrics and artifact hashes required to review the live benchmark.

## Evidence lock

A completed E03 report emits `e03_live_benchmark_lock_sha256`.

The lock binds:

- durable session identity;
- plan SHA;
- E01 approval identity;
- E02 rights lock;
- each logical run success state;
- successful run-manifest SHA;
- per-role artifact SHA;
- E03 acceptance-check results.

Later E04/A20 evidence should reference this lock rather than silently swapping the project outputs being compared.

## Schemas and template

- `Separation/Evaluation/schemas/live-separation-benchmark-plan.schema.json`
- `Separation/Evaluation/schemas/live-separation-benchmark-evidence.schema.json`
- `Separation/Evaluation/examples/live-separation-benchmark-plan.template.json`

The template contains `REPLACE_*` provider/model/fixture values. It cannot become a legitimate live E03 input until those are replaced with the exact E01/E02-approved values and an actual production driver.

## Machine verification

Local fault/integration harness for the final E03 semantics:

- test methods: **9 / 9 PASS**;
- `py_compile`: **PASS**;
- happy-path control exercise: four mode classes × two logical repeats = **8 / 8 synthetic test runs completed**;
- excessive retry behavior correctly changed benchmark acceptance to FAIL;
- deterministic resume reproduced the same evidence lock without rerunning bound successful results.

Checked-in regression suite:

- `Separation/Tests/test_live_separation_benchmark.py`

Machine-readable coverage:

- `Processing/Tests/L1-E03_LIVE_BENCHMARK_MATRIX.json`

The local harness creates generated WAV files and uses a test driver. It validates the E03 control/evidence implementation only. It is not a live provider benchmark, a Golden run or PARITY evidence.

## How HQ runs live E03

After E01 and E02 actually pass, keep private media/evidence outside the public repository and invoke the live E03 coordinator against the exact approved integrated tree:

```text
python Separation/Evaluation/live_separation_benchmark.py \
  --root /private/e03-work-root \
  --plan /private/e03-live-plan.json \
  --e01 /private/evidence/e01-commercial-route.sanitized.json \
  --e02 /private/evidence/e02-rights-cleared-audio.sanitized.json \
  --output-dir /private/evidence/e03
```

The provider command in the plan must invoke the production Lane 1 driver, not a fixture generator or mock. The production credentials remain environment-only.

A successful technical execution returns `READY_FOR_HQ_E03_LIVE_REVIEW`. HQ still has to verify that the run provenance is the approved production route and that the live provider/account evidence is genuine. This state does not mean product PARITY.

## Remaining E03 live inputs

Still required:

1. actual E01 `READY_FOR_LIVE_PROVIDER_GATE` evidence with production credential and approved provider/model/version access;
2. actual E02 `READY_FOR_HQ_LIVE_AUDIO_GATE` rights lock on real G1/G2 media;
3. HQ-approved current Reference scope deciding the required Hi-Fi/custom modes;
4. the exact production provider driver from the integrated commit;
5. actual provider-side separation runs;
6. project-controlled real output artifacts;
7. live timing/retry/failure/cost records;
8. G1 real objective metrics;
9. provider/account-side execution and billing provenance where authoritative reconciliation is required.

Until these inputs exist, Worker 1 remains `CHECKPOINT_READY`. E01, E02 and E03 are prepared but live acceptance remains pending.

## Next live gate

After E03 live evidence is accepted, the roadmap next gate is `L1-E04 | Current-iPhone Moises Differential Listening` using the exact locked G2 inputs and E03 project output evidence.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

E03 readiness does not change `MOI-P003`, `MOI-P004`, `MOI-P005`, `MOI-P020`, `MOI-P021` or `MOI-P024`. They remain `MISSING` until real provider, real-audio, current-iPhone differential, processing/recovery, device and HQ evidence actually satisfy their gates.
