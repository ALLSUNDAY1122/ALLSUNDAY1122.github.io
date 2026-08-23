# 書籍スキャナー同等化｜HQ Autonomous Standby

Effective: 2026-08-23 16:35 JST

## Decision
HQはWorkerの中間Task配車・中間merge・中間レビューを停止する。

Current control plane:
- `AUTONOMOUS_LANES.json` = active
- `FIXED_ASSIGNMENTS.json` = inactive / superseded
- Worker contract = v0.5 AUTONOMOUS LANES
- baseline integration HEAD = `fd9cb2ec7745a927fae80a82f5cfc514ebc40020`

## HQ must not do
- milestone単位のPR merge
- Workerへの次Task発行
- Worker lane内の実装順指示
- 他lane待ちを理由にWorkerを止める
- Golden未取得/SHA mismatchだけを理由にWorkerを止める

## Worker exit condition
各laneが以下を満たすまでWorkerが所有する。
- lane milestones complete
- self-review + fixes complete
- reproducible tests complete
- `LANE-N-FINAL.md` complete
- final lane PR open against `scanner-parity/integration`
- status `LANE_READY_FOR_FINAL_INTEGRATION`

## HQ wake condition
原則として4 laneすべてが `LANE_READY_FOR_FINAL_INTEGRATION` になった時だけHQ統合作業を再開する。

再開後の順序：
1. Notion / GitHub / all final PR / integration HEAD fresh read
2. cross-lane scope/conflict/contract audit
3. 4 final PRを安全な順序で統合
4. Apple SDK / E2E / long-run / Privacy regression
5. HQ Golden Dataset identity resolution
6. same-Golden end-to-end parity measurement
7. iPhone/TestFlight acceptance preparation
8. Release Gate

真のhuman-only gateが発生した場合のみ例外的にHQへ戻す。
