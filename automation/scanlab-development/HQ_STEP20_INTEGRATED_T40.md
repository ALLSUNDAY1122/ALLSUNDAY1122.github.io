# STEP20 — Serial T34-T39 integration in isolated HQ branch
2026-10-20 JST. T40 combined QA IN_PROGRESS; no release.

## Evidence before integration
Control Queue b96837c26877371616502a15f00eaa5408373b01, claims native SCANLAB-W1-001 owner WORKER_2 epoch2, viewer SCANLAB-W2-001 owner WORKER_2 epoch1, HQ epoch1. Worker1 stopped. Product branch feature/splat-native-ios-poc HEAD 2bcbbd6128863739ad168610cd2e3f8e3b01b458 unchanged.
Native T34-T36 PR #5622 HEAD dbcc8ba02cff0daad56593fc36c733167664f0f0: Native iOS run39380199091 SUCCESS 247 XCTest, 0 failures. Viewer T37-T39 PR #5619 HEAD18987c29eda1ea4c4e49dda103f1e005d9b868d9: Native iOS run39380203683 SUCCESS 249 XCTest, 0 failures. Static, privacy, smoke and memory gates on these heads also green.

## Actual T40 integration actions
Created isolated branch attempt/scanlab-hq-t40-integration-20261020-a1 at verified Native HEAD dbcc8ba02cff0daad56593fc36c733167664f0f0. Opened independent Viewer-to-integration PR #5623 and merged it ONLY to that isolated branch, expected W2 head SHA18987c29eda1ea4c4e49dda103f1e005d9b868d9. GitHub returned merged=true, merge SHA 0c0b7207c80e9c6294a4d7487d1de92de04ca46b. Remote-readback confirmed integration branch at that exact SHA.
Opened draft combined-to-product PR #5624 targeting feature/splat-native-ios-poc, without merging. Pull request event started Native iOS run39382480195 (QUEUED at first readback), plus privacy/smoke/S9/S10/S12/S13 gates. Need wait for actual CI results and inspect test counts; no PASS claim for combined code.

## Release guard
No product branch merge, Codemagic build, Apple upload, Internal TestFlight changes or App Review submit. Last independently live ASC latest Build18. Further gate: combined full native CI and T40 semantic QA, UI/physical Golden acceptance, privacy/revocation, package recovery; avoid claiming Scaniverse parity from CI alone.