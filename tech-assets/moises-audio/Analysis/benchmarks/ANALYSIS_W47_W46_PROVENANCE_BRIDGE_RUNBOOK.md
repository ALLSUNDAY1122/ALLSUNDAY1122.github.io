# W48｜W47 → W46 physical Project provenance bridge runbook

## Purpose

This runbook closes the operator/custody gap between the physical real-audio Project package produced by W47 and the canonical Analysis adjudication entry produced by W46. It does **not** declare PARITY.

## Required retained inputs

HQ must retain and select all of the following before invoking W48:

1. Exact canonical W47 package bytes from the selected physical `iphoneos/arm64` corpus execution.
2. W47 `declaredPackageRootSHA256` and the SHA-256 of the exact retained package bytes.
3. Exact canonical rights-cleared manifest bytes and their SHA-256.
4. W47 runtime-binding SHA-256 and physical-session identity.
5. W47 audited Project report SHA-256.
6. Exact W46 evidence binding and its canonical SHA-256.
7. Exact coverage/capture/review/tolerance objects referenced by that W46 binding.
8. Independently persisted list of W47 package roots already consumed by a prior bridge decision.

Do not reconstruct any of these roots from operator notes, filenames or a separately generated report.

## Build the HQ expectation

Create `AnalysisPhysicalRealAudioParityBridgeExpectation` with authority `HQ_LATE_INTEGRATION`. Pin the exact W47 package root, exact package-byte SHA, manifest ID/root, runtime root, physical-session ID, audited Project report root and W46 binding root. Supply the prior-consumed W47 package-root inventory from HQ's durable custody record.

The current package root must not already appear in that inventory.

## W46 binding mapping

The W46 binding must use the reopened W47 package values directly:

- `expectedProjectReportSHA256` ← W47 `auditedProjectReportSHA256`
- `expectedProjectEngine` ← W47 runtime `engine`
- `expectedProjectEngineVersion` ← W47 runtime `engineVersion`
- `projectPlatform` ← W47 runtime `platform`
- `projectArchitecture` ← W47 runtime `architecture`
- `projectSourceRevision` ← W47 runtime `sourceRevision`
- `projectBuildIdentity` ← W47 runtime `buildIdentity`
- `projectDeviceModel` ← W47 runtime `deviceModel`
- `projectOSVersion` ← W47 runtime `osVersion`
- `projectCaptureSessionID` ← W47 runtime `physicalSessionID`
- `manifestID` / `manifestSHA256` ← the same canonical manifest bound by W47

A separately generated Project report or separately typed runtime metadata is not an acceptable substitute.

## Single-entry execution

Invoke only `AnalysisPhysicalRealAudioParityBridge.adjudicate(...)` for the W47 → W46 handoff.

The bridge performs the following before W46 is entered:

1. Decode and canonically re-encode the exact W47 package bytes.
2. Recompute package-byte SHA and W47 canonical package root.
3. Decode and canonically re-encode the exact manifest bytes.
4. Recompute manifest SHA and W47 runtime-binding root.
5. Reopen W47 and require zero W47 package validation issues.
6. Require package/root/runtime/session/report values to equal the HQ expectation.
7. Require every W46 Project binding field to equal the reopened W47 runtime/report values.
8. Require coverage/capture/review/tolerance objects to equal the roots pinned by W46 and to use the same manifest.
9. Reject a package root already present in the HQ prior-consumed inventory.
10. Invoke the W46 canonical byte-entry adjudicator.
11. Validate the returned W46 adjudication report.
12. Emit a deterministic W48 bridge certificate.

## After a successful bridge execution

Persist the W48 bridge certificate and its `declaredCertificateRootSHA256` together with the exact W47 package bytes, manifest bytes, W46 binding and W46 adjudication report. Then append the consumed W47 package root to HQ's durable external consumption record before permitting a later bridge run.

W48 does not itself mutate a trusted global ledger. Therefore failing to persist the consumed root externally would weaken future replay detection.

## Fail closed

Do not retry by substituting another Project report, runtime field, manifest, Reference set, tolerance profile or binding root. Any mismatch requires a new explicitly selected and independently pinned HQ expectation.

## NON-PARITY boundary

A W48 certificate means only that one externally pinned W47 Project package reached one exact W46 adjudication binding without substitution. `READY_FOR_HQ_ANALYSIS_PARITY_JUDGMENT`, if W46 eventually reaches it, still does not automatically promote a PARITY row.

MOI-P009 / P011 / P013 / P016 remain under HQ final judgment and still require current-iPhone Moises Reference evidence, rights review, paired differential evidence and independent review.
