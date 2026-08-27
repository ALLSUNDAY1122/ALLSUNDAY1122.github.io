# W21 Current-iPhone Reference Review Consensus Runbook

## Purpose

W21 is the transcription-integrity gate that must run before W20 raw-observation metric recomputation for future current-iPhone Moises Analysis evidence.

It does not perform the Moises capture, choose production tolerances, or declare PARITY. HQ Late Integration owns those actions.

The protected evidence chain is:

`W19 capture + hashed artifacts -> W21 independent review consensus -> W20 deterministic metric derivation -> W19 provenance/repeatability validation -> W17 audited Reference -> W18 paired Project-vs-Reference differential -> HQ PARITY decision`

## 1. Freeze the W19 capture first

Each review set is bound to one W19 `captureSetID` and the exact source-manifest ID/SHA-256. Reviewers must inspect the evidence artifacts already registered on the corresponding W19 run/fixture/domain row.

Do not review a later copy, edited video, re-encoded screenshot, different app build, different source manifest, or different run and reuse the old identifiers.

## 2. Approve the review policy outside Worker 4

Start from `REFERENCE_REVIEW_CONSENSUS_POLICY_TEMPLATE.json`.

Required policy properties:

- `authority == HQ_LATE_INTEGRATION`;
- durable non-empty approval reference;
- at least two independent reviewers;
- whether reviewers must differ from the capture operator;
- externally approved maximum spread rules for every numeric value/anchor class actually used.

Numeric rule classes are:

- tempo BPM;
- beat timestamp seconds;
- chord boundary seconds;
- section boundary seconds;
- evidence-anchor time seconds;
- evidence-anchor frame index;
- normalized image/page-region coordinates.

Worker 4 ships no production spread values. The template has an empty `rules` array intentionally and is invalid until HQ approves explicit values.

## 3. Review independently

Each reviewer receives the W19 artifact/corpus identity, but should not see another reviewer's completed transcription before submitting their own record.

Use opaque reviewer IDs. Names, email addresses and other personal data are not required by the W21 schema.

Each `AnalysisReferenceReviewSubmission` records:

- globally unique submission ID;
- opaque reviewer ID;
- review-session ID;
- SHA-256 of the completed review-record bytes;
- submission time;
- one raw observation;
- artifact-local anchors for every raw claim.

The SHA-256 is not a signature or proof of identity. It is an integrity/copying signal for the exact completed record that was submitted.

## 4. Anchor every raw claim to evidence

Every submission requires an anchor for `status` plus every raw scalar, timestamp and label present in the observation.

Supported anchor shapes:

- video/audio time range in seconds;
- frame range;
- normalized image region;
- page index plus normalized page region.

Examples of required field paths include:

- `observed_bpm`;
- `beat_times_seconds[12]`;
- `key.tonic_pitch_class` and `key.mode`;
- `chords[4].start_seconds`, `chords[4].end_seconds`, `chords[4].normalized_label`;
- section boundary and label fields.

Anchor artifact IDs must be present both in the W19 row and the reviewer's raw observation. Invalid, missing, extra, differently located or differently typed anchors fail closed.

## 5. Independence gates

W21 rejects or invalidates a review group when:

- only one unique reviewer exists;
- the same reviewer submits twice for one run/fixture/domain;
- HQ requires capture/reviewer separation and the reviewer equals the capture operator;
- distinct reviewer IDs reuse the same `reviewSessionID`;
- distinct reviewer IDs submit byte-identical `reviewRecordSHA256` values;
- submission IDs are duplicated;
- review time precedes the capture or is future-dated.

Shared session IDs or identical review-record hashes are structural copied-submission signals. They do not prove or disprove deliberate human collusion; covert collusion remains an HQ process risk that software alone cannot eliminate.

## 6. Consensus rules

Categorical values are strict:

- raw status must match exactly;
- key tonic/mode must match exactly;
- chord labels must match exactly;
- song-section structural/functional labels must match exactly.

Numeric values may differ only within the externally approved HQ spread rule for their class. If they are inside that rule, W21 uses the deterministic median. If they are outside the rule, W21 does not average the disagreement away.

Beat/chord/section arrays must also have identical cardinality across reviewers before numeric consensus is attempted.

`NO_DECISION`, `UNSUPPORTED` and `UNSCORABLE` may be consensus states only when reviewers agree on the status and carry no contradictory raw payload. W20 later determines whether that consensus state can become a score. In particular, `UNSUPPORTED` and `UNSCORABLE` remain non-scorable and are never converted into artificial zero-quality values.

## 7. Unresolved disagreement

Any unresolved structural, anchor or value disagreement produces a consensus raw observation with:

`status = UNSCORABLE`

and a durable limitation such as `UNRESOLVED_REVIEW_CONSENSUS_NOT_W20_ADMISSIBLE`.

This is deliberate. A disagreement is not replaced with a mean, majority guess, first-reviewer choice or best-looking value.

`REVIEW_CONSENSUS_RESOLVED_PENDING_W20` means only that transcription consensus passed the supplied W21 policy. It is not PARITY.

## 8. Use the W21 facade for future Reference admission

Future HQ current-Moises Reference evidence should enter through:

```swift
try AnalysisReferenceReviewConsensusEngine.validateAndCompileReference(
    reviewSet: reviewSet,
    captureSet: captureSet,
    reviewPolicy: approvedReviewPolicy,
    capturePolicy: approvedW19Policy,
    manifest: exactBenchmarkManifest,
    manifestSHA256: exactManifestSHA256
)
```

The facade refuses unresolved review consensus and passes only the deterministic W21 consensus raw set to W20. W20 then independently derives quality metrics from Golden annotations, W19 validates repeatability/provenance, and the audited Reference can later enter W18.

Direct W20 APIs remain available for unit/compatibility paths, but bypassing W21 is not an acceptable future current-iPhone human-transcribed Reference admission procedure.

## 9. Preserve the complete evidence chain

Archive together:

1. exact W19 capture set and policy;
2. exact source manifest bytes and SHA-256;
3. all W19 evidence artifacts and hashes;
4. HQ-approved W21 consensus policy;
5. complete independent review set;
6. W21 consensus report;
7. W20 derivation report;
8. W19 repeatability validation report;
9. W17 audited Reference report;
10. W18 paired differential report and its separate HQ-approved non-inferiority profile.

Do not retain only the final median/metric report. That would discard the evidence needed to audit the transcription path.

## NON-PARITY notice

W21 synthetic/unit/portable evidence validates the review-consensus machinery only. It contains no real current-iPhone Moises observations, no rights-cleared production corpus and no physical-iPhone Project performance evidence. MOI-P009, P011, P013, P016 and P021 remain HQ Late Integration gates.
