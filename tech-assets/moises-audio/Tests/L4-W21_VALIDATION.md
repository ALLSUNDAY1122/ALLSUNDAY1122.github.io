# L4-W21 Validation — Reference Review Consensus / Transcription Integrity

Date: 2026-08-24 JST

Evidence class: **NON_PARITY**

## Scope

W21 closes the lane-local trust gap left after W20. W20 can deterministically recompute quality metrics from raw current-Moises observations, but it cannot know whether a human copied the raw value from the evidence artifact correctly. W21 therefore adds a machine-enforced independent-review gate before human-transcribed raw data may enter W20.

No actual Moises output was captured, invented or copied in this wave.

## Fresh contract check

Before implementation Worker 4 re-read the Notion v4 canonical contract, Worker bootstrap, work package, lane plan, Worker 4 status, resource locks and PARITY matrix, then compared `moises/wp4-analysis-platform` to frozen base `be1c84314db182d6eee5097de34e017af1a4a7de`.

At W21 start the branch was ahead 173 / behind 0. The changed-file set remained inside Worker 4 Analysis/Package/Tests/iOS scope plus its own status file. MOI-P009, P011, P013, P016 and P021 remained MISSING.

## Production implementation

`AnalysisReferenceReviewConsensus.swift` adds:

- artifact-local anchor types for time range, frame range, image region and page region;
- field-path anchors for every status/scalar/timestamp/label in a raw observation;
- reviewer submission provenance including opaque reviewer ID, review-session ID and completed review-record SHA-256;
- HQ-owned consensus policy with minimum independent reviewers and externally supplied numeric spread rules;
- copied-submission structural signals for shared sessions and byte-identical review records;
- optional capture-operator/reviewer separation;
- exact categorical consensus for status/key/chord/section labels;
- externally toleranced numeric consensus for BPM, beat timestamps, chord/section boundaries and anchor locations;
- deterministic median only after values are inside the approved spread;
- unresolved disagreement -> `UNSCORABLE`, never silent averaging;
- deterministic diagnostics and codec;
- `validateAndCompileReference(...)` facade enforcing W21 -> W20 -> W19 -> audited Reference ordering.

The implementation explicitly preserves unanimous `NO_DECISION`, `UNSUPPORTED` and `UNSCORABLE` review states. W20 remains responsible for scoring admissibility; W21 does not fabricate zero scores.

## Edge / negative / recovery behavior

Validated cases include:

1. stable independent tempo reviewers resolve inside externally supplied tolerance;
2. one reviewer cannot establish consensus;
3. duplicate same-reviewer submissions cannot increase independent count;
4. shared review-session ID across different reviewers fails as a copied-submission signal;
5. identical completed-review-record SHA-256 across reviewers fails as a copied-submission signal;
6. missing field anchors fail;
7. mismatched artifact-local anchor locations fail;
8. out-of-tolerance numeric values become UNSCORABLE instead of being averaged;
9. key tonic/mode disagreement requires exact resolution;
10. chord label disagreement fails while boundary differences may use approved tolerance;
11. unanimous NO_DECISION remains a valid raw state;
12. capture operator cannot self-review when HQ policy requires separation;
13. early/future review timestamps fail;
14. source-manifest mismatch fails;
15. duplicate policy rules fail as `INVALID_POLICY` without a runtime Dictionary trap;
16. frame/page-region anchors are range-checked and externally toleranced.

## Fail-closed templates and operator path

Added:

- `Analysis/benchmarks/REFERENCE_REVIEW_CONSENSUS_POLICY_TEMPLATE.json`
- `Analysis/benchmarks/REFERENCE_REVIEW_SET_TEMPLATE.json`
- `Analysis/benchmarks/REFERENCE_REVIEW_CONSENSUS_RUNBOOK.md`

The policy template intentionally has `rules: []`. Worker 4 ships no production transcription/anchor tolerance values. HQ must supply approved rules before the policy can validate.

`REFERENCE_RAW_OBSERVATION_RUNBOOK.md` was updated so future human-transcribed current-iPhone Reference evidence must use the W21 facade before W20. Direct W20 remains available for unit/compatibility/non-human instrumented paths.

## Portable validation

Runtime: Swift 6.2.1, x86_64 Linux.

- W21 production source-shaped typecheck: PASS.
- committed XCTest source Swift parse: PASS.
- portable optimized adversarial/stress harness: 15/15 assertions PASS in each of five complete runs.
- stress size: 50,000 fixture rows x 2 reviewers = 100,000 review submissions per run.
- every stress run emitted 50,000 diagnostics and 50,000 consensus raw observations.

Runs:

| Run | Internal seconds | Wall seconds | Max RSS kB |
| --- | ---: | ---: | ---: |
| 1 | 1.456956 | 1.65 | 168788 |
| 2 | 1.492181 | 1.69 | 168792 |
| 3 | 1.617197 | 1.82 | 168800 |
| 4 | 1.556700 | 1.74 | 168628 |
| 5 | 1.489525 | 1.68 | 168724 |

Machine evidence: `Analysis/benchmarks/L4-W21_REFERENCE_REVIEW_CONSENSUS.json`.

Canonical SwiftPM/Xcode XCTest execution remains HQ integrated-checkout evidence; portable validation does not replace it.

## Known limitations after W21

- W21 can detect missing independence, duplicate reviewers, shared session IDs and identical review-record bytes, but software cannot prove that two humans did not covertly coordinate.
- Two independent reviewers can still make the same semantic mistake. Artifact-local anchors make that mistake auditable, but do not automatically interpret the Moises UI.
- No production consensus spread values are shipped by Worker 4.
- No current-iPhone Moises observation, rights-cleared production corpus or Project physical-iPhone evidence was produced here.
- W21 protects transcription integrity but does not prove corpus sufficiency. A perfectly reviewed but trivial benchmark corpus could still be inadequate for P009/P011/P013/P016 coverage unless a separate coverage gate is enforced.
- MOI-P009/P011/P013/P016/P021 remain MISSING and final PARITY remains HQ-only.

## Recommended next autonomous wave

`L4-W22 | Analysis differential corpus coverage / sufficiency gate hardening`

Machine-enforce an HQ-approved benchmark coverage policy so a technically clean W21/W20/W19/W18 chain cannot pass using an underspecified corpus. The gate should bind the exact manifest SHA and require externally specified coverage strata/minimums for genre, tempo ranges, key modes, chord vocabulary/inversions and varied song structures, with fail-closed missing-stratum diagnostics. Worker 4 must not invent production corpus-size thresholds.
