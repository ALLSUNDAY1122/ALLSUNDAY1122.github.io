# WORKER2 STEP38 — Native recovery exact-HEAD CI certification pending

Date: 2026-10-21 JST. State: BLOCKED_CI_DISPATCH / IN_PROGRESS. Task SCANLAB-W1-001 WORKER_2 epoch2; native resource lock epoch2. No release rights. Worker1 STOPPED.

## Canonical reads
- Control queue branch `automation/scanlab-hq-control-20261020`, queue blob `ebba8d4a793b53a0abfd4f18bad0c6144f17b4bd`. Task and resource lock owner WORKER_2 epoch2 for Native; viewer WORKER_2 epoch1.
- HQ restart `HQ2_STEP38_WORKER2_RESTART.md` from HQ attempt, and `W2_STEP37_NATIVE_RECOVERY_EVIDENCE.md` from Worker2 recovery branch, re-read.
- PR #5639 open/draft/unmerged. Repair branch actual HEAD `7468a2113b010be14cccbba544e24c0e6edb5e1a` independently read from GitHub; base native attempt actual HEAD `6046660061b25efec0029b9ee9b95c7af19d3a7d`.
- Branches DIVERGED at merge base `dbcc8ba02cff0daad56593fc36c733167664f0f0`: Native base is ahead 6, repair branch ahead 7. Code differences involve both `SplatPreviousResultIntegrityRecovery.swift` and `SplatCompletionVerifierTests.swift`. Do not fast-forward or overwrite either branch.

## GitHub Actions verification
- Exact repair SHA `7468a2113b010be14cccbba544e24c0e6edb5e1a` has ZERO workflow runs by `actions/runs?head_sha=...`, ZERO check-runs by commit `check-runs`, and ZERO pull_request-only workflow runs by connector query.
- Repair branch older push runs were `completed/skipped`, e.g. #39533580319 at `133c1e04...` is SKIPPED, not PASS.
- Initial pull_request Native workflow run #39533009521 at `525fc662...` was CANCELLED; unrelated green runs and legacy #39433258555 FAIL do not certify exact SHA.
- `.github/workflows/splat-native-ios.yml` on repair branch declares `workflow_dispatch`, `push`, `pull_request`, but job `if` only permits dispatch, pull_request, feature/splat-native-ios-poc or testflight/* branches. Therefore push runs on an attempt branch are skipped by design. A new exact-SHA Native run needs workflow_dispatch(ref=repair HEAD/ref) or a new pull_request event; current connected GitHub Actions interface offers read/rerun jobs but no new dispatch workflow operation. PR #5639 already open, and neither queued nor completed Native job exists on the current exact HEAD.
- NO exact-SHA completed success and no XCTest total or zero failures can be honestly reported. Full integrated test count/result: UNKNOWN.
- Native successful test gate, release merge, Codemagic, Apple upload, TestFlight, and App Review NOT attempted. HQ release NO-GO.

## Code review status and remaining risk
- Repair branch preserves backup SHA-256 verification and rechecks staged clone digest after setting only staged modification time to authenticated prior completion. Backup untouched on invalid stage digest. Fault injection artificially sets backup future mtime.
- Distinct 6 commits on base branch may conflict semantically with repair's 7 commits. Consolidation and a new exact-source full native CI remain necessary. Timing/atomic promotion and backup cleanup require real XCTest evidence.
- Worker contract `automation/scanlab-development/WORKER_CONTRACT.md` at control branch not found (404); governance Worker ownership verified directly from Queue and HQ handoff. Notion app ledger, SCAN320 and app development standard v2.8 were located/read.

## Next required action
1. Initiate `Splat Native iOS Build` with `workflow_dispatch` targeting repair branch `attempt/scanlab-w2-recovery-step37-20261021-a2` at its independently rechecked immutable HEAD `7468a2113b010be14cccbba544e24c0e6edb5e1a`, or create a fresh eligible PR CI event without changing source. Verify resulting run.head_sha matches exact repair commit, not PR merge commit.
2. Read `completed/success`, run ID, job logs, test total and failure count. If failure, fix in new Worker2-owned isolated attempt branch with source/evidence readback; rerun.
3. HQ2 separately audits and reconciles diverged branch before integrating. NO-GO until full Native XCTest green.

No Queue mutation or unauthorized release branch writes.
