# Scaniverse同等化｜次チャット引継ぎ

Updated: 2026-08-24 14:01 JST

## 最重要

会話履歴を正本にしない。開始時と各「次」受信時に必ず Notion / GitHub / Supabase production / App Store Connect・TestFlight の必要な最新実状態を再取得する。

現在は **統合本部 + A2/B2/C2/D2** の成果がHQへ統合済み。管理作業へ戻らず、真正なPARITY差分か実機Gateを進める。

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

固定SHAを正本にしてはならない。2026-08-24 14:01 JSTのfresh auditで、現行validated app-sourceは `595c1d1d3468dd85594a958d8750264d9db91f50`。

## Build 3以降の重要source差分

Build 3が検証したapp-source以降に実app source変更が入っているため、Build 3は現在の最終実機candidateではない。

- viewer editをexport / video / publishで共有するため、persisted editを実outputへmaterialize。
- 外部publishが古いviewer stateを読むraceを避けるため、edit変更時の永続化を即時化。
- cropの片側handleだけを動かした場合、未操作側の端を勝手に1%切り落とさないopen-ended endpoint semanticsへ修正。

現validated app-source `595c1d1d...` の GitHub Actions:

- Splat Native Privacy Preflight: SUCCESS
- Splat Smoke Diagnostic: SUCCESS
- Splat Native iOS Build: SUCCESS

A2/B2/C2/D2を同app-sourceに対してGitHub compareし、4 branchすべて `ahead_by=0`。未統合Worker成果なし。

## TestFlight candidate

Build 3は履歴candidateへ降格。

現行app-source `595c1d1d...` から release branch `testflight/splat-native-ios-20260824-build4` を作成済み。release branchは `codemagic.yaml` だけをInternal TestFlight専用workflowへ置換し、`CURRENT_PROJECT_VERSION: 4` をbuild時に設定する。

release branch commit: `bdb1488b101c3855edc52687b5dd230748297a62`

この時点ではCodemagic build result / App Store Connect Build 4 read-backを未確認。Build 4を `VALID` と先取りしてはならない。次回は最初にCodemagic / App Store Connect / TestFlightの最新実状態を取得し、Build 4が存在しなければ実行経路を進める。

## Supabase production

2026-08-24 14:01 JST fresh read-only:

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

## 再実装禁止の解消済み事項

- 完成済みscanから「新規」: `returnHomePreservingProject()` で完成物を保持。
- 「あとで生成」: captured画面と保存済み一覧から再開可能。
- WorldMap durability race: 保存結果をawaitし、失敗時は撮影継続。
- relaunch後の `points3D.ply`: checkpointからfeature pointsを復元し、欠落時は生成開始時に再生成。
- ScanModel責任境界: Capture / Persistence / Reconstruction / SessionLifecycle boundary導入済み。
- capture image-quality rejectionはJPEG保存前。
- Gaussian resource guardはdataset/trainer大規模allocation前。
- B2 Mesh起動: `MeshScanContainerView()` 経由。
- D2 publish: `PublishScanView` は `publishTrustedPackage(...)` を使用。

## 次の真正なGate

まずBuild 4がApp Store Connectで `VALID / INTERNAL_ONLY` かつinternal beta groupへ配布されたことをread-backする。

成立後に **Build 4** を実機で Golden Reference と比較する。必須flow:

`capture → coverage → finish → processing → 3D result → save → library reopen`

同時に確認する。

- active capture中のbottom tabs非表示
- real ARKit feature points由来の赤/緑coverage heatmapが移動に応じて更新
- camera responsiveness / tracking / pause-resume / interruption recovery
- 暗すぎ・白飛び・強いボケframeが保存されないこと
- finish gateが冗長viewだけで誤成立しない
- processing進捗が実処理に対応
- resultが粗い偽3Dではなく実Gaussian Splat
- 保存後reopenして同じ完成物を表示
- viewer editが保存・export・video・publishへ同じ意味で反映
- crop片側操作時に未操作側tailを勝手に欠損しない
- Scaniverse Golden Referenceに対する欠損、二重化、色、立体感、手数、速度の明白な劣位

この物理Gateを通るまでは capture/reconstruction/viewer/library の `PARITY` 昇格禁止。

## 物理Gate後

実生成したtrusted scanを使ってproduction E2Eを行う。synthetic/hardcoded scanで代替しない。

`explicit publish → durable asset URL → 別browser viewer → public/unlisted/private → Discover/Map（geotag opt-in時のみ） → unpublish/republish → owner delete`

## 継続ループ

`最新実状態取得 → 未完了最大差分 → 実装/実測 → test/build/runtime → 辛口比較 → 修正 → 回帰gate → 正本更新`

禁止: compileだけで完了、古いhandoffの再実装、fake 3D/export/progress/Map、管理文書だけで停止、実機が必要でない作業まで人間待ちにすること。
