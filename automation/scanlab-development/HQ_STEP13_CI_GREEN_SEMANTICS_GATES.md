# STEP13 — Independent HQ CI and semantics audit
Date 2026-10-20 JST. HQ claim epoch1.

## Live evidence
- Queue control HEAD 7196cc2776f38fe9260c6cf5fa244fba4c5563c0; HQ/W1/W2 CLAIMED epoch1 with separated locks. Integration baseline 2bcbbd6128863739ad168610cd2e3f8e3b01b458 unchanged.
- W1 HEAD 31ba91fdd7f6a550952ab0a814692377033783cf, ahead4, unchanged. Last PR Native iOS run 39354568521 FAILED in static contract before XCTest. Not integrated.
- W2 HEAD 285933362b6d45e439ccef9061978f1ede80fd9b, ahead14, PR #5619. Native iOS run 39360508896 completed SUCCESS, static checks PASS and integrated simulator XCTest 245 tests / 0 failures, test execute succeeded, macOS hosted CI. Smoke, privacy, S10/S12 checks also SUCCESS on same HEAD.
- This resolves the older positive-assert cleanupFailedDraft CI mismatch at current W2 HEAD: scripts/d2_hq_integration_contracts.mjs now has assert.doesNotMatch and CI PASS.
- W2 test semantics caveat: SplatExportAdmissionTests.testPreflightRecoversViewerEditsBeforeExportMaterialization now asserts corrupt primary bytes remain unchanged after preflight; it no longer demonstrates explicit durable recovery. The read-only safeguard is valid, but export of recovered backed-up settings is a separate, unverified contract. Require independent test of backup data actually used by output; no silent defaults.
- T37 source sentinel verifies no destructive deletion on lost ACK, but real fault-injected idempotency/reconciliation is unproven. T38 revoked token after republish and full T39 unknown/error meters also require independent security acceptance. W2 PR comment 6282411350 records these gates.
- W2 is CI_GREEN, not P0_ACCEPTED; keep draft/unmerged pending acceptance, source review and HQ T40. No source cherry-pick yet.
- No new Codemagic build, Apple upload, group mutations or App Review submit. Apple last live readback latest Build18.

## Integration plan
1. W1 fix static mesh durability contract, assert pose and generation gate behavior, attain Native iOS full CI PASS.
2. W2 add independent export backup-setting acceptance and lost-ACK/revoke tests; retain CI green.
3. HQ read both SHA/lock epoch after evidence, integrate serially, run combined T40 independent CI then release preflight.
