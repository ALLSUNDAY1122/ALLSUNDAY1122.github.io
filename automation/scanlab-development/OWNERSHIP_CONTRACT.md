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

## User-directed STOP + exclusive implementation transfer (2026-10-20; supersedes initial worker headings)
User explicitly stopped WORKER_1 due to persistent OpenAI safety-check GitHub write refusals. No further messages, tasks, review requests, PR comments, automation or writes are to be addressed to WORKER_1. This applies immediately. The initial W1/W2 ownership partition above is HISTORICAL; the operative ownership is now:
- WORKER_2 is sole implementation worker for T34–T39, with two separately fenced claims/branches. T34–T36: SCANLAB-W1-001 owner WORKER_2, claim epoch 2, token SCANLAB-W1-001-a2-W2-20261020, branch attempt/scanlab-w1-takeover-w2-20261020-a2, lock scanlab:native-capture-reconstruction-export epoch2; Draft PR #5622. Worker1 original PR #5620 remains a historical read-only predecessor and HQ companion PR #5621 remains a historical source. The takeover branch HEAD starts at a050e1fd78de with the Mesh reset static contract fix already included; DO NOT reapply blindly or merge historical PRs separately.
- T37–T39: SCANLAB-W2-001 remains owner WORKER_2, claim epoch1, token SCANLAB-W2-001-a1-20261020, branch attempt/scanlab-w2-20261020-a1, lock scanlab:viewer-library-publish-privacy epoch1; Draft PR #5619. This lock and claim must not be rewritten by the transfer.
- HQ: SCANLAB-HQ-001 epoch1, independent release/governance and integration only. The control Queue on automation/scanlab-hq-control-20261020 is the canonical fenced ownership record, updated by GitHub SHA compare-and-swap, with remote readback verified.
- WORKER_2 must re-read each task's current claim token and lock before modifying the corresponding branch; a historical Worker1 epoch1 token has no authority. Do not merge W1/W2 work into each other's branch; HQ integrates serially after independent CI and T40. No new Build, Apple upload, TestFlight assignment, or App Store Review until gates pass. This transfer is an authorization change, not proof that any implementation was completed or CI passed.
