# Scaniverse同等化｜次チャット引継ぎ

Updated: 2026-08-24 14:42 JST

## 最重要

会話履歴や固定SHAを正本にしない。開始時と各「次」受信時に必ず Notion / GitHub / Supabase production / App Store Connect・TestFlight の必要な最新実状態を再取得する。

現在は **統合本部 + A2/B2/C2/D2** の実装成果がHQへ統合済み。追加実装を目的化せず、真正なPARITY差分または実機Gateだけを進める。

## 正本

- Notion: `Scaniverse同等化｜4開発班＋統合本部 v2.0`
- GitHub: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- HQ: `feature/splat-native-ios-poc`
- Integration PR: `#4145`
- A2: `scaniverse/a2-capture-reconstruction`
- B2: `scaniverse/b2-view-edit-mesh`
- C2: `scaniverse/c2-library-export`
- D2: `scaniverse/d2-share-discover`
- Supabase production: `gybchnyqlqwmajwkhsly`
- parity ledger: `splat-native-ios/SCANIVERSE_PARITY_PLAN.md`

## 現行validated app-source

2026-08-24のfresh auditで、Build 4が検証するapp-sourceは:

`595c1d1d3468dd85594a958d8750264d9db91f50`

Build 3以降に入った実source差分:

- persisted viewer editをexport / video / publishの実outputへmaterialize。
- 外部publish等が古いviewer stateを読むraceを避けるためedit永続化を即時化。
- crop片側handleだけを動かしたとき、未操作側tailを暗黙に切らないopen-ended endpoint semanticsへ修正。

このapp-sourceの Privacy Preflight / Splat Smoke Diagnostic / Splat Native iOS Build は全SUCCESS。

A2/B2/C2/D2を最新HQに対してfresh compareし、4 branchすべて `ahead_by=0`。未統合Worker成果なし。

## Internal TestFlight Build 4 — VERIFIED

Build 3は履歴candidateへ降格。現在の実機比較対象は **Build 4**。

- release branch: `testflight/splat-native-ios-20260824-build4`
- release commit: `bdb1488b101c3855edc52687b5dd230748297a62`
- app-sourceとの差分: release用 `codemagic.yaml` のみ
- Codemagic build: `6a8bd803c391bffc3d7617ce`
- Codemagic status: `finished`
- App Store Connect build resource: `219264e6-587a-49f2-96b1-0850d5a8ad4c`
- build number: `4`
- `processingState=VALID`
- `buildAudienceType=INTERNAL_ONLY`
- `expired=false`
- `usesNonExemptEncryption=false`
- `internalBuildState=IN_BETA_TESTING`
- internal beta group: `sun`
- `assigned=true`
- tester count: `1`
- App Store Review submission: false
- external beta review submission: false

Evidence: `splat-native-ios/evidence/scaniverse-build4-release.json`。

## Supabase production

2026-08-24 14:42 JST fresh read-only:

- project status: `ACTIVE_HEALTHY`
- `auth.users=1`
- `scanlab_profiles=1`
- `scanlab_scans=0`
- `scanlab_reports=0`
- `scanlab_blocks=0`
- `scanlab-public` v12 ACTIVE
- `scanlab-publish` v12 ACTIVE
- `scanlab-delete-account` v4 ACTIVE
- `scanlab-visibility` v5 ACTIVE
- `scanlab-delete-scan` v7 ACTIVE
- `scanlab-unpublish` v2 ACTIVE
- `scanlab-upload` v1 ACTIVE

実生成scanが0件なのでproduction publish/share parityはまだ未成立。

## 現在の真正なGate — HUMAN PHYSICAL DEVICE

追加の管理作業やfixtureで代替しない。**TestFlight Build 4** を実iPhoneでScaniverse Golden Referenceと比較する。

必須flow:

`capture → coverage → finish → processing → 3D result → save → library reopen`

同じ画面録画で最低限確認する:

- active capture中にbottom tabsが隠れる
- real ARKit feature points由来の赤/緑coverage heatmapが移動に応じて更新
- camera responsiveness / tracking / pause-resume / interruption recovery
- 暗すぎ・白飛び・強いボケframeのreject挙動
- finish gateが冗長viewだけで誤成立しない
- processing進捗が実処理に対応し、crash / hangしない
- resultが粗いfake 3Dではなく実Gaussian Splat
- orbit / pan / zoomが実用的
- viewer editが保存され、reopen後も保持
- crop片側操作時に未操作側tailを勝手に欠損しない
- 保存後Libraryから同じ完成物をcold reopenできる
- Golden Referenceに対して欠損、二重化、色、立体感、操作性、速度に明白な劣位がない

この物理Gateを通るまで capture / reconstruction / viewer / library を `PARITY` に昇格しない。

## 物理Gate後

実機で生成したtrusted scanを使い、production lifecycle E2Eを行う。synthetic / hardcoded scanで代替しない。

`explicit publish → durable asset URL → 別browser viewer → public/unlisted/private → Discover/Map（geotag opt-in時のみ） → unpublish/republish → owner delete`

ここまで通った後に最終Parity ledger更新、PR #4145のfinal gate判定、main merge可否を決める。

## 再実装禁止の解消済み事項

- 完成済みscanから「新規」: `returnHomePreservingProject()` で完成物を保持。
- 「あとで生成」: captured画面と保存済み一覧から再開可能。
- WorldMap durability race: 保存結果をawaitし、失敗時は撮影継続。
- relaunch後の `points3D.ply`: checkpointからfeature pointsを復元し、欠落時は生成開始時に再生成。
- Capture / Persistence / Reconstruction / SessionLifecycle boundary導入済み。
- capture image-quality rejectionはJPEG保存前。
- Gaussian resource guardはdataset/trainer大規模allocation前。
- B2 Mesh起動は `MeshScanContainerView()` 経由。
- D2 publishは `PublishScanView` → `publishTrustedPackage(...)`。
- viewer edit materialization / immediate persistence / one-sided crop endpoint semanticsはBuild 4へ反映済み。

## 継続ループ

`最新実状態取得 → 未完了最大差分 → 実測/実装 → runtime → Golden辛口比較 → 修正 → 回帰gate → 正本更新`

禁止: compileだけで完了、TestFlight uploadだけで完了、古いhandoffの再実装、fake 3D/export/progress/Map、実機でしか判定できない品質をfixtureでPARITY扱いすること。
