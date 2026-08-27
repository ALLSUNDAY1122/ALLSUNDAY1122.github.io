# W26 Physical-iPhone Analysis Corpus Selection Runbook

Purpose: prevent MOI-P021 physical-device evidence from being collected only on an unrepresentatively easy subset after W22 has approved a broader Analysis corpus.

W26 does not run an iPhone benchmark, choose production coverage thresholds, or declare PARITY. HQ Late Integration owns approval, physical execution and final judgment.

## 1. Freeze W22 first

Archive the exact rights-cleared real-audio manifest bytes and SHA-256, the HQ-approved W22 coverage policy, and the resulting W22 report. W26 requires W22 status `SUFFICIENT_CORPUS_PENDING_HQ`, no W22 issues, and exact manifest/policy binding.

## 2. Choose one selection mode before capture

### FULL_W22_ELIGIBLE_CORPUS

Use every fixture listed by W22 as eligible. W26 derives global, five-domain and all-stratum minima directly from the W22 policy. Subset fields must remain empty/zero.

This is the strongest and simplest mode when the physical-device run cost is acceptable.

### HQ_APPROVED_EXACT_SUBSET

HQ must approve the exact fixture IDs before capture. The policy must also include:

- positive selected fixture-count and duration minima
- one requirement for each canonical domain: tempo, beat, key, chord, structure
- one requirement for every W22 semantic stratum

The W26 minima may equal or exceed the bound W22 minima but may never weaken them. A subset that omits a slow track, minor-key track, inversion/no-chord case, varied structure, or any other approved W22 stratum fails closed when that omission causes a required stratum deficit.

The template is intentionally invalid until HQ fills all fields.

## 3. Bind W24 and W25 to W26

The W24 `requiredFixtureIDs` must exactly equal the W26 selected fixture set. Its duration map must exactly cover that set and match the canonical W22 manifest durations.

The W25 workload-policy fixture inventory must also exactly equal W26. For every fixture, W25 fixture ID, source SHA-256 and source duration must match the canonical W22 manifest.

Fixtures absent from W22 eligible corpus, duplicate selected IDs, manifest swaps, source swaps and silently dropped fixtures are rejected.

## 4. Canonical execution order

1. Freeze manifest bytes/SHA and rights grants.
2. Run W22 corpus sufficiency.
3. Approve and run W26 physical corpus selection.
4. Approve matching W24 repeated-run plan and W25 workload policy.
5. Capture W23 physical telemetry while W25 proves real Analysis workload execution.
6. Run W25 workload validation.
7. Run W24 worst-case repeated-run acceptance.
8. HQ archives and performs final MOI-P021/PARITY judgment.

`AnalysisDeviceCorpusBoundPerformanceGate` refuses to invoke the W25/W24 downstream gate unless W26 is `PHYSICAL_SELECTION_READY_PENDING_HQ`.

## 5. Any selection epoch change invalidates the downstream plan

If the manifest, W22 coverage policy, W26 selected fixture set, source SHA, fixture duration, build/device plan, W24 run inventory or W25 workload policy changes, create a new approval epoch and rerun the affected gates. Do not mix evidence across epochs.

## 6. Archive

Archive together:

- exact manifest bytes and SHA-256
- W22 policy/report
- W26 selection policy/report
- W24 profile/batch/report
- W25 workload policy/receipts/reports
- all W23 raw telemetry evidence
- integrated build identity and physical-device corroboration

## 7. Status boundary

`PHYSICAL_SELECTION_READY_PENDING_HQ` means only that the physical-performance fixture inventory is structurally representative relative to the supplied HQ-approved W22 policy. It is not physical-device evidence and not PARITY.

W26 cannot prove the authenticity or physical-device origin of archived JSON files and does not independently verify the file loader's claimed source hash. Those remain later integrity/HQ gates.
