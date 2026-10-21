# STEP15 — HQ independent Mesh CI unblock and W2 status
Date: 2026-10-20 JST. State IN_PROGRESS.

## Live upstream state
- Product baseline feature/splat-native-ios-poc HEAD 2bcbbd6128863739ad168610cd2e3f8e3b01b458, unchanged.
- Queue control commit 7196cc2776f38fe9260c6cf5fa244fba4c5563c0, W1/W2/HQ CLAIMED epoch1, distinct locks.
- W1 attempt HEAD 31ba91fdd7f6a550952ab0a814692377033783cf (unchanged). Existing PR #5620 Native CI static failure caused by test_mesh_durability_contract.py expecting an in-reset FileManager.default.removeItem that has intentionally been removed.
- Inspection of MeshScanModel.reset() proves new behavior: guard if destructiveResetBlockedReason then false, invalidate captureGeneration, cancel tasks, detach projectURL (not remove project); all UI state reset occurs without in-reset deletion.
- W2 attempt HEAD 26839ecc8a516c4591fe8e5c4b03265d4b624d65. Native CI run 39362812776 SUCCESS, 245 XCTest / 0 failures. T37/T38 fault injection and bounded retained staging remain acceptance gaps.

## Actual HQ code change
- New independent branch attempt/scanlab-hq-mesh-contract-20261020-a1 forked from W1 commit 31ba91fdd7f6a550952ab0a814692377033783cf, without moving or writing the W1 branch.
- Modified exactly splat-native-ios/scripts/test_mesh_durability_contract.py: replaced obsolete in-reset deletion assertion with stronger nondestructive invariant: block reason guard precedes captureGeneration rotation precedes projectURL detach; any removeItem invocation inside reset block fails. No production code edit, no weakening of fail-closed constraint.
- Companion commit a050e1fd78deb8094178242c4515aeb2819cb64a, Draft PR #5621 targeting W1 attempt branch. https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/5621
- Native iOS pull_request CI run 39367475853 was QUEUED on readback, with other smoke/privacy/memory workflows running. Do not count as PASS until completed and logs verified.
- W1 owner can review/merge companion test correction after CI; HQ has not merged or displaced the W1 claim.

## Release
- Both Worker source branches stay separate and unmerged into feature branch.
- New TestFlight IPA, Codemagic trigger, Apple upload, assignment, App Store Submit: NOT DONE.
- Next: collect actual CI result of PR #5621 and remediate additional failures if any; W2 T37/T38 end-to-end evidence and T40 independent integration QA.
