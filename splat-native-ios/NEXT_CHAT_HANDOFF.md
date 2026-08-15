# Scaniverse同等化｜次チャット引継ぎ

Updated: 2026-08-15 17:53 JST

## 最重要｜分割開始済み

ユーザー承認により、旧「まだA〜Dへ分割しない」方針は終了した。

以後は **統合本部② + A2/B2/C2/D2** の5セッション構成で進める。

ただし起動順にはゲートがある。

1. 最初に `Scaniverse同等化 統合本部②開始` を起動する。
2. 統合本部②が共有ホットスポットの責任境界整理を実装する。
3. CI PASS後、その統合HEADへA2-D2を同期する。
4. その後A2/B2/C2/D2を本格並走させる。

分割しただけで古いbranch状態から勝手に開発を始めない。

## 共通基準点

分割決定時のコード基準点:

- integration branch: `feature/splat-native-ios-poc`
- baseline commit: `78c543ea794796a6f968bf8ffa7da9ec4f229c33`
- `Splat Native iOS Build` run `31871549531`: **success**
- Integration PR: #4145 `Scan Lab｜Scaniverse同等化 統合本部（4開発班）`

この後に分割用ドキュメントcommitが入るため、各セッションは固定SHAではなく開始時の最新HEADを再取得すること。

## Active branches

- Integration HQ 2: `feature/splat-native-ios-poc`
- A2: `scaniverse/a2-capture-reconstruction`
- B2: `scaniverse/b2-view-edit-mesh`
- C2: `scaniverse/c2-library-export`
- D2: `scaniverse/d2-share-discover`

A2-D2は分割決定時のgreen integration baselineから新規作成した。

旧branch:

- `scaniverse/a-capture-reconstruction`
- `scaniverse/b-view-edit-mesh`
- `scaniverse/c-library-export`
- `scaniverse/d-share-discover`

は今後の新規開発先ではない。削除せず移植元・比較元として凍結する。

比較確認済み:

- 旧A → integration: integration側が58 commits ahead、旧A独自behind 0。A成果はintegration ancestryに入っている。
- 旧B ↔ integration: diverged。旧B側にintegration ancestry外のcommitが残る。
- 旧C ↔ integration: diverged。旧C側にintegration ancestry外のcommitが残る。
- 旧D ↔ integration: diverged。旧D側にintegration ancestry外のcommitが残る。

したがってB2/C2/D2は旧branchを丸ごと戻してはならない。担当領域の旧差分を確認し、現在の統合実装にまだ存在しない有効な改善だけを意味的に移植する。

## 統合本部②の最初の仕事

コード機能追加より先に、共有編集競合を減らす境界整理を行う。

特に巨大化した `ScanModel.swift` 周辺を、少なくとも次の責任へ整理する。

- Capture / AR session input
- Reconstruction / training
- Persistence / resume / reprocess lifecycle
- Session interruption / app lifecycle

目的は責任境界を明確にすることであり、中心挙動の意図しない変更ではない。

境界整理後は relevant tests / typecheck / iPhone build / existing contract checks を通し、green HEADを作る。そのHEADをA2-D2へ同期してから専門実装を開始する。

## 現在までに統合済みの重要成果

- real on-device Splat capture/training path
- viewer orbit/pan/zoom/crop/exposure/contrast/measurement foundations
- extensive real Mesh path foundations
- persistent `ScanProjectStore`
- capture → generate → trusted atomic result commit
- saved Scan library and reopen after relaunch
- checkpoint schema v2 with depth/coverage state
- ARWorldMap cold-resume foundation
- legacy checkpoint backward decode tests
- PLY/SPZ/model/video export foundations
- latest baseline iPhone CI PASS

これらを「旧laneで未統合」と誤認して作り直さない。

## 現在の重要未完了

統合本部②/HQ横断:

- 完成済み保存projectで `新規` が `discardAndReset()` を使い破棄扱いになる。保存物を残す非破壊ホーム復帰が必要。
- captured stateに明確な `あとで生成` / 保存して離脱するUXがない。
- `persistWorldMapIfPossible()` は非同期callbackで、pause/finish直後の離脱・終了とのdurability raceがある。保存完了契約が必要。
- relaunch後、初回generation前の `points3D.ply` readinessとprocessability contractを再確認する必要がある。
- Parity ledgerは最近のlibrary/cold-resume統合をまだ反映していない。

A2:

- 実機で代表対象を繰り返したSplat品質比較
- tracking/relocalization continuity
- outdoor/sky quality
- memory/splat budget/thermal behavior
- real processing time and failure recovery

B2:

- actual integrated edit usability on newly generated scans
- real Mesh physical quality/texture/metric behavior
- large-scene rendering safety
- Mesh lifecycle and AR usability

C2:

- cold resume real-device proof
- process later / reprocess end-to-end
- export formats independent-reader interoperability
- large export/video memory and partial cleanup
- low-storage lifecycle proof

D2:

- live auth/service runtime
- explicit real upload → durable browser URL
- public/unlisted/private
- real Map/Discover content
- owner unpublish/delete/account deletion
- moderation/rate-limit/privacy/App Review consistency

## 正本

開始時に必ず再取得する。

1. Notion `Scaniverse同等化｜4開発班＋統合本部 v2.0`
2. `splat-native-ios/NEXT_CHAT_HANDOFF.md`
3. `splat-native-ios/ACTIVE_SESSION_PROMPTS.md`
4. `splat-native-ios/SCANIVERSE_PARITY_PLAN.md`
5. 対象branch latest HEAD
6. PR #4145 latest state/CI（HQ2）または担当branchのCI

過去チャットの進捗数字は正本にしない。

## セッション名

最初:

`Scaniverse同等化 統合本部②開始`

HQ2境界整理・同期完了後:

- `Scaniverse同等化 A2開始`
- `Scaniverse同等化 B2開始`
- `Scaniverse同等化 C2開始`
- `Scaniverse同等化 D2開始`

各チャットの詳細責任と開始promptは `ACTIVE_SESSION_PROMPTS.md` を正とする。

## 共通ループ

`実状態確認 → Scaniverseとの差分特定 → 最大差分を実装 → test/build/runtime → 辛口レビュー → 修正 → 回帰gate → 次の差分`

真正な人間判断ゲートまでは自動継続する。

## 完成条件

compile PASSやcommit数ではなく、Notion/`SCANIVERSE_PARITY_PLAN.md` の全rowがPARITYになり、代表実機比較・interoperability・network E2E・performance/privacy/accessibility/release regressionが成立し、Sev-1/Sev-2が0であること。

## 禁止

- 旧A-D branchで新規開発を続ける
- old branchのshared fileをwhole-file上書きして最新統合成果を消す
- 管理・差分表だけで停止する
- compile PASSをconsumer parityと扱う
- fake 3D / fake export / fake progress / hardcoded Map/Discoverを合格扱いする
- branch commit数を統合済み進捗として数える
