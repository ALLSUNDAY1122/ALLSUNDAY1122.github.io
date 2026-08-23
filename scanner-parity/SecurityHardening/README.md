# LANE-2 Privacy / Security Hardening

This lane enforces a local-only default path for source video, page images, OCR text and BookPackage generation.

## Enforcement layers

1. `PrivacyStaticAuditor` detects network APIs, analytics SDKs, external-AI endpoints and network CLIs.
2. `BookDataLifecyclePolicy` denies sensitive logging, cache retention and standard-path network transmission; temporary artifacts must be purged.
3. `SensitiveDataStaticAudit` fails on likely OCR/image logging, cache persistence and network boundaries.
4. `ApplePrivacyComplianceAuditor` inventories required-reason API categories and camera/photo usage-description requirements.
5. `PrivacyManifestBaseline.xcprivacy` is the local-only baseline: tracking disabled, no tracking domains, no collected-data declaration, no required-reason entries until code use requires them.
6. `Tests/SecurityHardening/run-lane2-privacy-gate.sh` is the fail-close CI entry point.

## Integration requirements

- AppShell must bundle a file named exactly `PrivacyInfo.xcprivacy`; copy/adapt the baseline into the application target resources.
- If AppShell adds camera capture, `NSCameraUsageDescription` must be supplied. If it directly accesses the photo library, `NSPhotoLibraryUsageDescription` must be supplied.
- If required-reason API usage is introduced, the corresponding `NSPrivacyAccessedAPITypes` category and an Apple-approved reason must be added. The audit intentionally does not invent or auto-select reason codes.
- Any future external-AI/cloud OCR/analytics/network upload feature is a new privacy boundary and must not be allowlisted around the egress rules.
- Final Privacy PASS/FAIL remains HQ Release Gate ownership.

## Apple source-of-truth note

Apple requires valid `PrivacyInfo.xcprivacy` manifests and requires apps using designated required-reason APIs to declare the applicable API category and approved reason. App Store Connect rejects invalid manifests; required-reason omissions have blocked submission since May 1, 2024. Re-check Apple documentation at release time because the API/reason list can change.
