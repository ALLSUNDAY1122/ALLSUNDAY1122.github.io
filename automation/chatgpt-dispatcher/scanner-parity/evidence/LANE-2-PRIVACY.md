# LANE-2-PRIVACY Evidence

- lane: `LANE-2-PRIVACY`
- worker: `worker2`
- branch: `scanner-parity/worker2-privacy-lane`
- integration base: `fd9cb2ec7745a927fae80a82f5cfc514ebc40020`
- final PR: `#4522`
- final Privacy PASS owner: HQ Release Gate

## Implemented controls

1. SCAN-011 static inventory: network APIs, analytics SDKs, external-AI endpoints, network CLI, local CLI, Apple-local frameworks and remote package dependencies are classified separately.
2. Egress deny rules are non-bypassable by allowlist; allowlist only suppresses informational/review findings such as approved local build tools.
3. Data lifecycle policy denies sensitive book data in logs/cache/network standard path; temporary processing requires purge; user-selected persistent export requires explicit action.
4. Sensitive-data regression audit flags likely OCR/image logging, cache persistence and network upload boundaries.
5. Apple compliance auditor detects required-reason API categories for UserDefaults/system boot time/disk space/file timestamps and checks camera/photo usage-description requirements.
6. Local-only privacy manifest baseline declares tracking=false, no tracking domains, no collected data and no required-reason entries until source use requires them.
7. `run-lane2-privacy-gate.sh` compiles all lane fixtures and performs current-tree static egress audit; it exits nonzero when egress risks are found.

## Verification

- SCAN-011 PrivacyStaticAuditor fixtures: 12/12 PASS before lane absorption.
- ApplePrivacyComplianceAuditor: Swift 6.2.1 compile + smoke execution PASS for baseline, required-reason detection and camera permission detection.
- SensitiveDataStaticAudit: Swift 6.2.1 compile + smoke execution PASS for sensitive logging, network boundary and test exclusion.
- DataLifecyclePolicy: Swift 6.2.1 compile + smoke execution PASS for network denial, log denial, temporary purge, cache denial and unsafe-ID redaction.
- GitHub code search on scanner-parity returned no production match for `URLSession` or `api.openai.com` at evidence time.
- Full checkout runner could not be executed in the worker container because that runtime could not resolve `github.com`; the deterministic runner is committed for PR/HQ checkout execution. This is an environment transport limitation, not a Golden/Human gate.
- PR #4522 is open against `scanner-parity/integration` and is mergeable. No commit status checks were attached at the time of final read-back.

## Current dataflow conclusion

The inspected standard path uses AVFoundation/CoreVideo/ImageIO for video extraction, CoreImage/Vision for correction/audit, Apple Vision for OCR, local Tesseract CLI comparison, and local FileManager/UIKit/CoreText output generation. No direct third-party upload path for source book images or OCR body text was identified.

## Apple compliance basis

Apple requires bundled privacy manifests to be valid, and required-reason API use must be represented in `NSPrivacyAccessedAPITypes` with an approved reason. The exact approved reason must match actual app behavior and is intentionally not auto-invented by this lane. The baseline must be copied/adapted into the final AppShell target as `PrivacyInfo.xcprivacy` during integration.

Official references checked 2026-08-23:
- https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- https://developer.apple.com/support/third-party-SDK-requirements/

## Integration assumptions / final gate

- AppShell is owned by LANE-1 and did not yet exist on this lane baseline; LANE-2 therefore does not modify its target resources or Info.plist outside write scope.
- HQ final integration must bundle/adapt `PrivacyManifestBaseline.xcprivacy`, add camera/photo purpose strings only if corresponding APIs are present, and run `scanner-parity/Tests/SecurityHardening/run-lane2-privacy-gate.sh` after lane merge.
- If LANE-1 or future work adds analytics, external AI, cloud OCR, upload, tracking domains or required-reason APIs, HQ must treat the resulting fail-close finding as a release blocker until explicitly resolved.
- Final Privacy PASS remains HQ-owned; this lane provides implementation and evidence only.
