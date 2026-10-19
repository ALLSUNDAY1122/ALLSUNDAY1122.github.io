# SCANLAB Round3 Implementation Ownership and Evidence Gates
Date: 2026-10-20. Baseline: feature/splat-native-ios-poc @ 2bcbbd6128863739ad168610cd2e3f8e3b01b458. PR #4145 remains draft.

## Queue governance
Source: automation/scanlab-development/queue.json on automation/scanlab-hq-control-20261020.
Each worker must independently CAS its own READY task to CLAIMED, increment claim_epoch, specify unique claim_token and attempt_branch, and remote readback before touching product source. No active workers assumed merely from prompt generation. CAS is only one sink; resource locks must be witnessed before integration. Claims are per-attempt and are invalid after epoch change. Do not modify shared baseline directly.

## Worker 1 — native capture, reconstruction, export (T34–T36)
Owned semantic surfaces:
- AR frame capture/pose/depth, FrameLease, capture generation, durable captured RAW + checkpoint writer
- Gaussian reconstruction and Mesh production
- Splat/mesh export writers and serializer validation
Example existing Swift anchors, inspected at baseline:
- splat-native-ios/SplatNative/ScanProjectStore.swift (RAW writer + manifest; shared contract boundary; writer ownership W1, readonly consumer W2)
- splat-native-ios/SplatNative/SplatExportService.swift
- splat-native-ios/SplatNative/MeshExportService.swift
W1 must expose immutable FrameEvidence, GenerationRecord, trusted/raw read descriptors and SourceGeneration/EditPin contracts to W2. W1 does NOT modify any publish/delete/visibility endpoints or viewer UI.

## Worker 2 — viewer, library, publish, privacy (T37–T39)
Owned semantic surfaces:
- Viewer read-path and display, Library census, UNKNOWN != EMPTY, calibrated measurement only
- Publish idempotency, independent owner-delete, receipt/outbox, temporary and durable grants, revocation and user consent UI
Example existing anchors:
- splat-native-ios/SplatNative/SplatViewerState.swift
- splat-native-ios/SplatNative/ScanLabPublishPackage.swift
W2 must not alter ScanProjectStore writer or export producer implementations. Cross-owner edits require HQ new independent queue task + lock and ordered serial integration.

## HQ — shared contracts, integration, independent QA, release
- Registry / queue / Task locks / baseline evidence / integration gate
- GitHub Actions and Codemagic gateway, Build number allocation, ASC upload and readback, Internal TestFlight group assignment readback
- Independent acceptance: real Swift/XCTest, isolated RAW reopen, two-connection PG conflict, signed artifact reader, physical Golden / iPhone human acceptance
- No Xcode Cloud, no secrets to docs, no App Review Submit, no duplicated commit+build number rebuild.

## Interface gates
1. Capture->Store: generation-scoped FrameLease/DepthLease, reject malformed and stale before any side effects.
2. Store->Reconstruction->Export: immutable trusted source SHA, commit receipts and editPin binding, STAGED never TRUSTED.
3. Export->Publish: verified SPZ file SHA, independent reader opened, failure preserves source and published data.
4. Store/Export->Viewer: NONDESTRUCTIVE reads, missing/corrupt UNKNOWN not EMPTY, no meter without separate calibration proof.
5. Publish->Privacy: owner intent + grant epoch + revocation receipt; old bearer cannot be revived by republish.
6. Integration: actual commit, CI, IPA, Apple build, and tester group readback aligned.

## Apple readback hazard found in STEP03
Existing .github/workflows/splat-s17-asc-readback.yml is push-triggered only on feature/splat-native-ios-poc request-file changes; successful workflow commits the result BACK TO THAT SHARED BRANCH. Triggering it now without a dedicated fenced lock would violate the attempt-only branch rule. It returns latest Build details but does NOT independently prove internal group assignment. Do not claim current Apple status from its September 2026 historical result.
Preferred next implementation step: create a fenced readback-only release task/workflow on isolated branch and explicit evidence contract, then execute authorized readback via GitHub Actions without accidental build or source changes.
