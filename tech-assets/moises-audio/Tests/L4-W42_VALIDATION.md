# L4-W42 Validation｜External Evidence Root Anchor

Classification: **NON_PARITY**

## Scope

W42 adds an external expected-root boundary above W41. The destination package is not allowed to define its own expected roots. HQ supplies an independently preserved anchor receipt/expectation, and the verifier compares the fully revalidated W41 destination against that external root set.

Production:

- `Analysis/AnalysisPhysicalEvidenceExternalAnchor.swift`
- `Analysis/AnalysisPhysicalEvidenceDestinationCertificate.swift`
- `Analysis/AnalysisPhysicalEvidenceBatchValidation.swift` (Epoch 27 HQ parse-only compatibility mirror)
- `Package.swift`

Tests:

- `Tests/MoisesAudioCoreTests/AnalysisPhysicalEvidenceExternalAnchorTests.swift`

## Durable XCTest source coverage

The W42 XCTest source covers:

1. deterministic anchor-receipt issuance;
2. deterministic destination certificate and certificate-root recomputation;
3. certificate codec round-trip;
4. rollback to an older anchor sequence;
5. stale externally pinned anchor-receipt root;
6. same transfer ID with an older internally valid W41 root;
7. replay under a different transfer ID;
8. mixed W27/W38/W40/W41 roots;
9. W39 run/workload-execution substitution;
10. predecessor receipt-chain mismatch;
11. forged declared anchor-receipt root.

The adversarial unit seam `verifyAlreadyValidatedTransfer` is module-internal and exists for `@testable` tests. Production callers use `verifyDestination`, which first validates the externally supplied receipt/expectation and then executes the complete W41 destination verifier.

## Epoch 27 compatibility correction

Fresh canonical PR inspection showed that Epoch 27 integrated W39-W40 after applying HQ parse-only fix `09880c4e6d523b23e7f4e9feabfa81d0024b37ce` to W40 `AnalysisPhysicalEvidenceBatchValidation.swift`. The long-lived Worker branch still contained the pre-fix trailing-closure form.

W42 mirrored the same fix in Worker branch commit:

`46ce56be3b42b1c380dbfcd09548a76961f491d6`

The `allSatisfy` result is precomputed as `summariesAreValid`. Validation behavior is unchanged; this only restores the Swift 6 parse shape already accepted by HQ Integration Run #203.

## Exact production source syntax/type validation

Environment:

- Swift 6.2.1
- x86_64 Linux

Observed:

- exact `AnalysisPhysicalEvidenceExternalAnchor.swift` frontend parse: **PASS**
- exact `AnalysisPhysicalEvidenceDestinationCertificate.swift` frontend parse: **PASS**
- both exact production sources with dependency stubs, `-warnings-as-errors -typecheck`: **PASS**

An earlier minified source-shaped mirror failed because the mirror generator removed required lexical whitespace (`&& !` became an invalid token sequence). This is recorded as `MIRROR_CONSTRUCTION_FAILURE_NOT_PRODUCTION`. It is not counted as either a product PASS or product failure. The exact production source validation above supersedes it for syntax/type-shape evidence.

## Behavioral rollback/replay mirror

A deterministic SHA-256 behavioral mirror exercised **100,000 adversarial cases**.

Status: **PASS 100,000 / 100,000 rejected as required**

Mutation classes rotated evenly:

- anchor sequence rollback;
- externally pinned receipt-root mismatch;
- predecessor receipt mismatch;
- transfer-ID replay;
- run/workload-execution substitution;
- mixed root-set substitution.

Observed runtime: approximately **3.313 s**.

Observed maximum process RSS: approximately **159,496 kB**.

## Destination certificate root mirror

A second deterministic mirror generated a canonical destination-certificate root and exercised **100,000 mutations** across:

- anchor receipt root;
- expected W27 root;
- expected W38 root;
- expected W40 root;
- expected W41 root;
- destination W27 root;
- destination W40 root;
- destination W41 root.

Status: **PASS 100,000 / 100,000 root mutations detected**

Observed runtime: approximately **3.586 s**.

Observed maximum process RSS: approximately **159,496 kB**.

## Fresh full Worker-branch SwiftPM/XCTest

A fresh GitHub checkout was attempted again with `git ls-remote` against `moises/wp4-analysis-platform`.

Result: **NOT_OBSERVED**

Reason: Worker container DNS still returned `Could not resolve host: github.com`.

No full Worker-branch SwiftPM/XCTest result is claimed for W42. Epoch 27 HQ Run #203 does establish 333/333 for the canonical W39-W40 checkpoint, but it predates W41-W42 and therefore is not used as W42 test evidence.

## Security boundary

W42 detects rollback/replay only when HQ actually preserves the current expectation/receipt root independently. `anchorSequence` is a checked value, not a self-maintained authoritative monotonic database. A caller that reconstructs the expectation from the destination package removes the intended protection.

W42 certificates are deterministic SHA-256 metadata commitments. They are not signatures, trusted timestamps, Secure Enclave evidence, Apple attestation, or proof of physical-device origin.

An exact byte-for-byte re-copy of the currently anchored package is intentionally valid. A stale or different internally consistent package is rejected when it does not match the externally pinned identities/root set.

## PARITY boundary

No PARITY row is promoted by W42.

Still MISSING:

- MOI-P009 BPM
- MOI-P011 key
- MOI-P013 chord
- MOI-P016 song sections
- MOI-P021 long-audio memory / thermal / battery stability

Physical iPhone execution, genuine Lane-2 bounded decoding, real RSS/physical-footprint/thermal/battery/cancellation, rights-cleared corpus/current-Moises differential, and repeated W24 acceptance remain outside this validation result.
