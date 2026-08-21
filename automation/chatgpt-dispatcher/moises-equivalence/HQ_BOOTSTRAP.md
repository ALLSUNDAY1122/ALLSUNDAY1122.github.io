# Moises同等化｜HQ BOOTSTRAP

## 正本
- Notion: Moises技術同等化｜AI音源分離アプリ 正本
- GitHub: ALLSUNDAY1122/ALLSUNDAY1122.github.io
- Integration branch: `tech/moises-separation`
- Integration PR: #4431
- Queue: `automation/chatgpt-dispatcher/moises-equivalence/queue.json`
- Parity: `tech-assets/moises-audio/PARITY_MATRIX.json`
- Resource locks: `automation/chatgpt-dispatcher/moises-equivalence/resource-locks.json`

## 運営方式
本プロジェクトは「同等化パック」を適用する。
1. AIアプリ開発・公開フロー v2.7
2. Queue駆動・並列化・統合運用 v1.1
3. 完全同等化PARITY契約

## 最終目的
Moisesの名称・ロゴ・非公開コード・学習データ・著作物を複製せず、公開されている主要iPhone体験を独自実装で実用品質まで同等化する。
技術Engine抽出はPARITY達成後に行い、同等化の代替条件にしない。

## HQ専有責任
- integration mainline / integration_epoch
- shared contract / shared data model / app shell
- Queue finalizer
- logical resource lock定義
- semantic integration
- PARITY最終判定
- cross-feature regression / CI
- BLOCKED_HUMANの提示

Workerはshared contractを独自再定義しない。変更が必要ならTask evidenceとしてHQへsurfacingする。

## Worker Pool
Worker 1〜4は固定部署ではない。各Workerは最新Queueを取得し、capability条件を満たすREADY Taskをatomic claimして1 Macro Waveを完了する。完了後はPoolへ戻る。

## Task状態
`BACKLOG -> READY -> CLAIMED -> WORKING -> INTEGRATION_READY -> MERGED -> VERIFIED`
補助: `BLOCKED_DEPENDENCY`, `BLOCKED_HUMAN`, `NEEDS_REBASE`, `STALE_ATTEMPT`, `CANCELLED`

## Fenced Attempt
- claimごとに`claim_epoch`を単調増加
- attempt branch: `task/<task-id>/attempt-<epoch>`
- stale epochはcanonical branch、Queue VERIFIED、production side effectを確定できない
- finalizerは最新`claim_epoch + claim_token`一致を必須とする

## PARITY Gate
状態: `MISSING -> PARTIAL -> NEAR_PARITY -> PARITY`
PARITYには最低限、機能存在・結果品質・操作性・速度・安定性・失敗復旧・実機証拠を要求する。
強い機能で弱い機能を相殺しない。未実装機能はMISSINGのまま残す。

## Differential Test
可能な限り同じ入力をMoisesと自作へ与え、結果品質、処理時間、操作手数、失敗復旧、実機性能を比較する。

## 現行Referenceの主要範囲
- audio/video import
- vocals/drums/bass等のstem separation
- stem solo/mute/volume/remix
- chord detection
- smart metronome / click track / count-in
- BPM detection / speed changer
- pitch/key changer / key detection
- trim / loop / song parts
- setlists / library
- export / share
- Premium/Proのadvanced separation等はMISSINGを隠さず別Parityとして追跡

## 禁止
- PoC成功を同等化完了と呼ぶ
- synthetic fixtureだけで品質PASS
- compile/testのみでPARITY
- Worker間で同じlogical resourceを無秩序に同時変更
- 古いattemptをcanonicalへ上書き
- 実装困難を理由にParity行を削除
