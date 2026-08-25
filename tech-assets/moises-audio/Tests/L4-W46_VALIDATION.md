# L4-W46 validation｜Anchored real-audio Analysis parity adjudication

## Result

**Implementation: complete.**

**Current real Analysis parity readiness: NOT READY.**

W46 does not manufacture a positive real-audio result. It is a deterministic fail-closed gate that can become READY only when HQ supplies the actual rights-cleared corpus, selected current-iPhone Reference package and selected physical Project differential package.

## Fresh canonical context

W46 began with fresh reads of Notion/GitHub canonical state.

Observed:

- operating model remains v4 / Four Autonomous Independent Lanes / Late Integration;
- Worker 4 write scope remains Analysis/Package/Tests/iOS plus Worker-4 status;
- `PARITY_MATRIX.json` remains HQ-owned;
- MOI-P009/P011/P013/P016/P021 remain MISSING;
- Lane 4 remains canonical through W44;
- W45+ remains post-Epoch30;
- Epoch30 semantic checkpoint remains `f2b82b167ce2ddde1039666e29740d9ba52f9027`;
- HQ cross-lane hardened tested head is `e0f64c6be8237f625106d40de846d7b9f003e993`;
- HQ Run #238 / `32887077836`: SUCCESS, SwiftPM 375/375 plus Lane2 IO+Library and Lane3 Playback+DSP portable full-source typecheck PASS.

Run #238 does not cover W45-W46 and is not real-iPhone/real-audio evidence.

At W46 start:

- W45 final Worker branch point `6720f8a7c409f7f1f7a765397da45bfcf5c4a4dd` -> Worker: identical;
- frozen base `be1c84314db182d6eee5097de34e017af1a4a7de` -> Worker: ahead 473 / behind 0.

No rebase/sync was performed.

## Production implementation

### Canonical byte entry

`AnalysisRealAudioParityCanonicalAdjudicator` is the HQ production entry.

It requires the retained manifest bytes to:

1. decode;
2. re-encode exactly through `AnalysisRealAudioBenchmarkCodec`;
3. match byte-for-byte;
4. produce the independently HQ-bound manifest SHA-256.

Malformed, noncanonical or digest-substituted manifest bytes fail before semantic adjudication.

### Semantic adjudication

`AnalysisRealAudioParityAdjudicator` recomputes:

- W22 corpus coverage;
- W19-W21 current-iPhone Reference review consensus/raw derivation/repeat validation;
- W18 paired Project/Reference differential.

It does not trust saved PASS labels alone.

### Rights gate

Every case must:

- be `REAL_AUDIO`;
- have a nonempty unexpired rights grant;
- have a valid source SHA-256;
- explicitly allow ANALYSIS_BENCHMARK;
- explicitly allow INTERNAL_QUALITY_REVIEW;
- explicitly allow DIFFERENTIAL_REFERENCE.

Synthetic-only evidence is prohibited.

### Current Reference gate

The exact HQ binding pins:

- reference engine;
- product/app/build;
- iPhone model;
- iOS version;
- locale;
- account tier;
- minimum reference epoch;
- repeat count;
- independent reviewer count.

W21 must preserve reviewer independence and evidence anchors, and W20 must rederive metrics from consensus raw observations.

### Project runtime gate

The external HQ binding requires one selected Project `iphoneos / arm64` source/build/device/session identity and exact Project audited-report root.

This is provenance metadata, not Apple attestation.

### Per-row anti-masking

W46 requires every eligible fixture covering the domain to contribute every required metric exactly once.

P009 requires 4 metrics per tempo fixture.
P011 requires 5 metrics per key fixture.
P013 requires 5 metrics per chord fixture.
P016 requires 5 metrics per structure fixture.

One missing, duplicated, outside-tolerance or non-parity-candidate pair makes that feature row NOT_READY regardless of aggregate means.

## Durable XCTest source

Added:

- `AnalysisRealAudioParityAdjudicationTests.swift`
- `AnalysisRealAudioParityAdjudicationReportValidatorTests.swift`
- `AnalysisRealAudioParityCanonicalGateTests.swift`

Coverage includes:

- synthetic fixture rejection;
- incomplete rights-use rejection;
- mixed-root rejection;
- simulator/x86 Project-binding rejection;
- one missing P009 metric;
- one P013 tolerance failure hidden among otherwise good pairs;
- one P016 non-parity-candidate pair hidden among otherwise good pairs;
- deterministic report root/codec;
- legitimate global-gate NOT_READY while all feature metric rows are READY;
- forged READY with recomputed root but incomplete feature evidence;
- READY without Reference/differential root;
- root tamper;
- missing required PARITY row;
- malformed/noncanonical/digest-mismatched manifest bytes;
- canonical manifest bytes reaching semantic fail-closed adjudication.

### Full branch execution status

Fresh Worker-branch `git ls-remote` again failed:

`Could not resolve host: github.com`

Therefore:

**full current Worker-branch SwiftPM/XCTest = NOT_OBSERVED**.

No W46 full-XCTest PASS is claimed.

## Portable Swift fail-closed mirror

Environment:

- Swift 6.2.1
- x86_64 Linux
- `swiftc -warnings-as-errors`

Observed:

- compile PASS;
- compile elapsed ~0.41 s;
- compile max RSS 152,196 kB;
- runtime PASS 100,000/100,000 checks;
- runtime elapsed ~2.09 s;
- runtime max RSS 18,476 kB;
- valid baseline contains 19 required pairs for one fixture covering all four target domains.

Mutation classes:

- synthetic source;
- missing rights uses;
- Project simulator platform;
- Project x86 architecture;
- insufficient reviewers;
- mixed evidence root;
- missing pair;
- outside tolerance;
- non-parity candidate;
- duplicated favorable pair.

This mirror is NON_PARITY and does not use real Moises or real audio.

## Deterministic report-root mirror

Observed:

- 30,000 report packages;
- 300,000 mutations;
- PASS;
- elapsed ~14.183 s;
- max RSS ~110,320 kB.

Mutations covered binding/manifest/coverage/capture/review/Project roots, status, fixture inventory, per-row pair count and issue metric identity.

## Self-audit correction

The first persisted-report validator version incorrectly required an overall NOT_READY report to contain at least one feature-row NOT_READY result.

That was too strict: a global rights/root/reference/device-binding failure can legitimately make the overall package NOT_READY while all four feature metric pair sets are individually READY.

Fixed in:

`ccca998df369a52d0ccfcb7f680167167a9b6b04`

A dedicated XCTest now fixes that behavior. Overall READY remains strict and still requires no global issues plus all four READY rows.

## Current conclusion

No actual W46 package can be marked READY from this Worker session because it did not receive or execute:

- HQ-approved exact rights-cleared real-audio corpus;
- current-iPhone Moises W19-W21 reviewed evidence;
- selected physical Project real-audio output package;
- complete W18 paired differential using those exact artifacts.

Therefore:

- MOI-P009 remains MISSING;
- MOI-P011 remains MISSING;
- MOI-P013 remains MISSING;
- MOI-P016 remains MISSING;
- Worker 4 makes no PARITY edit.
