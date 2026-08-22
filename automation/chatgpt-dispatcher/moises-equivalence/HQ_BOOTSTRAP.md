# Moises同等化｜HQ BOOTSTRAP v3 — 4 Independent Lanes / Late Integration

## 正本
- Notion: Moises技術同等化｜AI音源分離アプリ 正本
- GitHub: ALLSUNDAY1122/ALLSUNDAY1122.github.io
- Integration branch: `tech/moises-separation`
- Integration PR: #4431
- Global Queue: `automation/chatgpt-dispatcher/moises-equivalence/queue.json`（履歴・統合ledger。Worker配車には使わない）
- Work Package: `automation/chatgpt-dispatcher/moises-equivalence/work-packages.json`
- Lane Plan: `automation/chatgpt-dispatcher/moises-equivalence/lane-plan-v3.json`
- Worker status: `automation/chatgpt-dispatcher/moises-equivalence/worker-status/worker-N.json`
- Parity: `tech-assets/moises-audio/PARITY_MATRIX.json`
- Resource locks: `automation/chatgpt-dispatcher/moises-equivalence/resource-locks.json`

## 運営方式
本プロジェクトは4本の独立Laneを先に進め、後段でHQがまとめて統合する。

旧方式の問題:
- 1 Taskが細かすぎ、1回の「次」が短時間で終わる。
- dependencies / READY_ASSIGNED解放待ちでWorkerがTaskを取得できない空白が生じる。
- 小TaskごとのintegrationがWorker実装時間を削る。

v3解決策:
1. 4 Workerをexclusive Laneへ完全固定。
2. 各Laneへ最低4件のMacro Bundleを事前配布。
3. 1回の「次」= 1 Macro Bundle。従来小Task約4件分をまとめ、実装・edge cases・tests・evidenceまで一続きで完遂する。
4. WorkerはGlobal QueueからTaskを取得しない。Lane内はHQ解放なしで順次自動継続する。
5. Shared/Appはassignment epoch中freezeし、Worker間依存を通常実行から除去する。
6. HQは小Bundleごとにmergeせず、複数BundleのLane checkpointを後でsemantic integrationする。

## Lane
- Lane 1: Separation + Processing
- Lane 2: IO + Library
- Lane 3: Playback + DSP
- Lane 4: iOS Platform + Analysis

各Laneのbranch、scope、Macro Bundle列は `work-packages.json` と `lane-plan-v3.json` を正本とする。

## HQ専有責任
- Shared contract / shared data model / App shell
- integration mainline
- lane-plan / work-package / resource ownership
- Global Queue ledger
- lane checkpoint integration
- cross-lane build and semantic conflict resolution
- actual integrated iOS compile/device validation
- Differential Moises comparison
- PARITY final judgment
- external/human blocker handling

## Worker starvation防止
- Active Laneには常に最低4 Macro Bundleをpreloadする。
- 4件を使い切る前に次checkpoint分をHQが追加する。
- Workerは `READY_ASSIGNED` やHQの都度解放を待たない。
- 外部gateで1 Bundleが止まっても、同Lane内の外部gate不要Bundleへ進む。
- 他Laneへのtask stealingは禁止。

## Epoch / contract freeze
- assignment_epoch開始時にWorkerは一度だけlatest integrationへ同期しbase SHAを記録。
- epoch中は他Lane由来のintegration変更を理由に各回rebaseしない。
- Shared/App契約変更はHQだけが行い、原則次checkpointで4 Laneへまとめて配布する。
- critical contract bugだけはHQが緊急修正し、影響Laneへ明示する。

## Macro Bundle品質
1回分の終了条件:
- bundle goalの実装完了
- edge/negative case処理
- tests / benchmark / typecheck等の適切な検証
- durable evidence保存
- known gaps明記
- status更新

1 subtask / 1 commit / compileだけで終了しない。

## Integration checkpoint
HQは原則として各小Bundle直後には統合しない。以下のとき統合する。
- Laneが複数Bundleを完了しcoherent checkpointになった
- cross-lane統合しないと次の品質Gateへ進めない
- critical blocker rescueが必要
- Phase境界

統合時:
1. 各Laneのfrozen baseとcheckpoint headを確認
2. owned scope越境を監査
3. semantic conflictをHQで解消
4. Shared/App adapterをHQが実装
5. integrated iOS build / cross-feature regression
6. real-device / real-audio / differential evidence
7. PARITY_MATRIX更新
8. 次の4本×最低4 Macro BundleをpreloadしてからLaneを再開

## PARITY Gate
`MISSING -> PARTIAL -> NEAR_PARITY -> PARITY`
compile/test/harness/synthetic-onlyでは上げない。実音源・実機・品質・失敗復旧を含む。

## 禁止
- Workerへの都度task claim要求
- 小TaskごとのHQ merge待ち
- Worker間の相互依存を通常作業の停止条件にすること
- WorkerによるShared/App/PARITY/他Lane編集
- PoC/compile成功を完成扱い
- 困難を理由にscopeを削ること
