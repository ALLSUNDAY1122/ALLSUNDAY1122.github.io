# Scaniverse同等化｜次チャット引継ぎ

Updated: 2026-08-24 01:10 JST

## 最重要

会話履歴を正本にしない。開始時と各「次」受信時に必ず Notion / GitHub / Supabase production / App Store Connect・TestFlight の必要な最新実状態を再取得する。

現在は **統合本部 + A2/B2/C2/D2** の成果がHQへ統合済み。旧「分割開始前」「A2-D2同期待ち」の記述は失効している。管理作業へ戻らず、真正なPARITY差分か実機Gateを進める。

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

固定SHAを正本にしてはならないが、2026-08-24 01:10 JST時点の確認基準は HQ `17b52b79f032e7abe225bc216cc2d0ac2b71fadf`。

## 2026-08-24の成立済みGate

同app sourceで GitHub Privacy / Smoke / main iOS Build が全SUCCESS。production auth/session/profile E2E、S2/D2 contracts、Simulator msplat smoke、A2/C2 XCTest、OBJ/FBX/GLB/STL/PLY/USDZ reader compatibility、unsigned iPhone Release compileもPASS。

Xcode世代差のMetal completion blockerは `SplatVideoExporter.swift` の `addCompletedHandler` + continuation方式で解消し、GitHub側とXcode 26 signed archive側の双方で成立。

Internal TestFlight candidateは version `1.0.0` / build `2`。Codemagic build `6a8b1591c8729cb286ce7247` はfinished、App Store Connect build resource `53f5f4ae-2212-47d2-8860-af4805eb60de` は `VALID / INTERNAL_ONLY`。内部group `sun` のbuild一覧にもBuild 2を確認済み。

PR #4145は意図的にdraft / unmergedを維持する。TestFlight upload成功はPARITY完了ではない。

## 旧HQ未完了事項の再監査結果

以下は現HEADですでに解消済みなので再実装しない。

- 完成済みscanから「新規」: `SplatResultView` が確認ダイアログを出し `returnHomePreservingProject()` を使用。完成物をTrashへ移さない。
- 「あとで生成」: captured画面に明示入口あり。保存済み一覧の「生成待ち」から再開可能。
- WorldMap durability race: pause/transitionは `isWorldMapPersistencePending` で遷移を閉じ、`persistWorldMapForTransition` の完了結果をawaitしてからsession pause。失敗時は撮影を継続し、暗黙離脱しない。
- relaunch後の `points3D.ply`: checkpointからfeature pointsを復元し、生成時に `points3D.ply` が欠落していれば再生成する。captured projectはprocessability contractで生成へ戻せる。
- ScanModel責任境界: Capture / Persistence / Reconstruction / SessionLifecycle boundary filesは既に導入済み。

## 現在の最大Gate

Build 2を実機で Golden Reference と比較する。必須flow:

`capture → coverage → finish → processing → 3D result → save → library reopen`

同時に確認する。

- active capture中のbottom tabs非表示
- real ARKit feature points由来の赤/緑coverage heatmapが移動に応じて更新
- camera responsiveness / tracking / pause-resume / interruption recovery
- finish gateが冗長viewだけで誤成立しない
- processing進捗が実処理に対応
- resultが粗い偽3Dではなく実Gaussian Splat
- 保存後reopenして同じ完成物を表示
- Scaniverse Golden Referenceに対する欠損、二重化、色、立体感、手数、速度の明白な劣位

この物理Gateを通るまでは capture/reconstruction/viewer/library の `PARITY` 昇格禁止。

## 物理Gate後の次段

実生成したtrusted scanを使ってproduction E2Eを行う。synthetic/hardcoded scanで代替しない。

`explicit publish → durable asset URL → 別browser viewer → public/unlisted/private → Discover/Map（geotag opt-in時のみ） → unpublish/republish → owner delete`

production scan rowが実際に作られるまでは publish/share parity完了としない。

## 継続ループ

`最新実状態取得 → 未完了最大差分 → 実装/実測 → test/build/runtime → 辛口比較 → 修正 → 回帰gate → 正本更新`

禁止: compileだけで完了、古いhandoffの再実装、fake 3D/export/progress/Map、管理文書だけで停止、実機が必要でない作業まで人間待ちにすること。
