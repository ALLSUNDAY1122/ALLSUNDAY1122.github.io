# STEP14 HQ — W2 green release-risk review and W1 static CI escalation
Date: 2026-10-20 JST. State: IN_PROGRESS. Product integration HOLD.

## Independent live readback
Control Queue HEAD 7196cc2776f38fe9260c6cf5fa244fba4c5563c0: HQ, W1, W2 tasks CLAIMED epoch1, resource locks unchanged.
Product source feature/splat-native-ios-poc HEAD 2bcbbd6128863739ad168610cd2e3f8e3b01b458 unchanged.

W1 attempt HEAD 31ba91fdd7f6a550952ab0a814692377033783cf, ahead4, unchanged. PR #5620 Native CI run 39354568521 FAILED at static mesh durability test_mesh_durability_contract.py:54, before XCTest. PR escalation comment #6282772587 requests behavioral invariant and full CI.

W2 attempt HEAD 26839ecc8a516c4591fe8e5c4b03265d4b624d65, ahead17. PR #5619 Native iOS run 39362812776 SUCCESS, macOS hosted CI static checks PASS, 245 integrated XCTest with 0 failures; privacy, smoke, memory S10/S12 contracts success on same SHA.
New publish workflow retains local staging package on uncertain server ACK, cleans package only after serverOutcomeConfirmed true. Package stale cleanup policy tightened (avoid age-deleting uncertain state), ScanLabPublishPackageTests expanded.
Risks still not closed: server reconciliation and bounded disk retention of unacknowledged staged packages after app restarts; corrupt primary viewer edits correctly read only but recovered settings actually used in exporter unproven; real revoked-share token re-access and republish tests absent; separate fault-injected lost ACK end-to-end not proven. Static source tests cannot substitute.
HQ PR #5619 comment #6282770714 documents remaining safety gate.
W2 CI_GREEN != T37/T38/T39 P0_ACCEPTED. W1 CI_RED. No merge, no TestFlight build, Apple upload, or App Review Submit. Last live Apple baseline Build18.

## Next
1. W1 fix mesh durability check without restoring unsafe deletes; get PR Native full CI green.
2. W2 add end-to-end export backup use, staged cleanup retention/reconciliation, revoked token fault tests.
3. Verify queue epoch/head again; serially integrate into product only after independent T40; run integrated Native CI, then Codemagic unique source Build/TestFlight readback.
