# Moises同等化｜HQ BOOTSTRAP v4 — 4 Autonomous Independent Lanes / Late Integration

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
4 Workerをexclusive Laneへ固定し、各Workerが自Laneの必要作業を自律的に設計して連続実行する。HQは通常のWorker Task/Macro Bundleを作成・補充・解放しない。

旧方式で廃止したもの:
- Global QueueからのTask claim
- HQによるREADY_ASSIGNED解放
- HQによる有限Macro Bundleの事前配布・補充
- 小Taskごとのintegration待ち

現在方式:
1. Worker 1〜4をexclusive Laneへ固定する。
2. 各「次」でWorker自身がbranch/status/PARITY/known gapsを監査する。
3. Worker自身が最も価値の高い未完了事項を25〜40分相当のAutonomous Macro Waveへまとめ、その場で実装・検証・証拠保存まで行う。
4. 配布Taskが尽きても停止しない。Lane内に意味ある仕事がある限り自分で次Waveを作る。
5. Shared/Appはepoch内freezeし、Lane間の通常依存を減らす。
6. HQは価値のあるcheckpointで後段semantic integrationを行う。

## Lane
- Lane 1: Separation + Processing
- Lane 2: IO + Library
- Lane 3: Playback + DSP
- Lane 4: iOS Platform + Analysis

担当scopeは `work-packages.json` と `lane-plan-v3.json` を正本とする。

## Worker自律計画の優先順位
Workerは原則以下の順で次Waveを選ぶ。
1. current-iPhone PARITYに直結するLane内未実装・不完全実装
2. worker status `known_gaps` でLane内解消可能なもの
3. failure/recovery/edge case不足
4. correctness / durability / performance / security / privacy不足
5. tests / benchmark / evidence不足
6. Late Integration用adapter / measurement / runbook準備
7. 外部入力待ちは、それなしで進められる準備を先に完了する

HQはこの通常バックログを代わりに作らない。

## HQ専有責任
- Shared contract / shared data model / App shell
- integration mainline
- work-package / logical resource ownership境界
- Global Queue ledger
- lane checkpoint semantic integration
- cross-lane build / adapter / semantic conflict resolution
- actual integrated iOS compile/device validation
- real-audio / rights / external credential gate
- Differential Moises comparison
- PARITY final judgment
- 本当にLane単独では解決不能なhuman/external blocker対応

## Worker停止監査
Workerが `CHECKPOINT_READY` / `BLOCKED` になった場合、HQは「配布Taskが尽きた」だけでは停止を認めない。

停止を認める条件:
- 外部credential・権利クリア実データ・人間判断なしにはLane内で意味ある実装/検証準備がもう残らない
- frozen Shared/App契約変更が必須
- ownership越境なしでは解決不能
- unsafe / technically impossible

停止理由として無効:
- Macro Bundleを全部消化した
- HQがTaskを補充していない
- QueueにREADY Taskがない
- 他Workerがまだ終わっていない

無効な理由で止まっていたら、HQはTaskを作るのではなく、Worker契約を再読させて**自分で次Waveを選定させる**。

## Epoch / contract freeze
- assignment epoch開始時にWorkerはlatest integrationのShared/App契約を一度読みbase SHAを記録。
- epoch中は他Lane由来のintegration変更を理由に毎回rebaseしない。
- Shared/App契約変更はHQだけが行う。
- critical contract bugだけHQが緊急修正する。

## Autonomous Macro Wave品質
1回の「次」は目標25〜40分相当。

最低限:
- Waveのgoal / rationale / done_whenをWorker自身が定める
- meaningful implementation / hardening
- edge / negative / recovery cases
- tests / benchmark / typecheck等
- durable evidence
- commit
- status更新

TODOを考えただけ、1 subtask、1 commit、compileだけでは1回分としない。

## Integration checkpoint
HQは小Waveごとには統合しない。以下で統合する。
- Lane成果がcoherent checkpointになり統合価値がある
- cross-lane統合しないと次の品質Gateへ進めない
- critical contract/blocker rescueが必要
- Phase境界

統合時:
1. frozen base / checkpoint head確認
2. owned scope越境監査
3. semantic conflict解消
4. Shared/App adapter実装
5. integrated iOS build / cross-feature regression
6. real-device / real-audio / differential evidence
7. PARITY_MATRIX更新

統合後もHQは次Taskを配らない。Workerは更新された正本・PARITY・known gapsを読み、自分で次Waveを選定する。

## PARITY Gate
`MISSING -> PARTIAL -> NEAR_PARITY -> PARITY`
compile/test/harness/synthetic-onlyでは上げない。実音源・実機・品質・失敗復旧を含む。

## 禁止
- HQが通常Worker Taskを逐次設計すること
- WorkerにTask補充待ちをさせること
- Workerへの都度task claim要求
- 小TaskごとのHQ merge待ち
- Worker間の相互依存を通常作業の停止条件にすること
- WorkerによるShared/App/PARITY/他Lane編集
- PoC/compile成功を完成扱い
- 困難を理由にscopeを削ること
