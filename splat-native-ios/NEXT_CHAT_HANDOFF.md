# Scaniverse同等化｜次チャット引継ぎ

Updated: 2026-08-24 03:56 JST

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

固定SHAを正本にしてはならないが、2026-08-24 03:56 JST時点のHQは `d23abd84d5fff6cfd3711311f8ba5110918d7714`。A2 residualを閉じたvalidated app-sourceは `164f5b3d2e1002c1e69423049ba73d2bf01a268a` で、そこからHQ current HEADまでの差分は一時workflow削除とEvidenceのみ。

## 2026-08-24の成立済みGate

HQ current HEADの GitHub Privacy / Smoke / Main iOS Build は全SUCCESS。production auth/session/profile E2E、S2/D2 contracts、Simulator msplat smoke、A2/C2 XCTest、OBJ/FBX/GLB/STL/PLY/USDZ reader compatibility、unsigned iPhone Release compileもPASS。

Xcode世代差のMetal completion blockerは `SplatVideoExporter.swift` の `addCompletedHandler` + continuation方式で解消済み。

A2 PR #4175からHQへ明示的に残っていた2件も解消済み。

- JPEG保存前に `CaptureImageQualityEvaluator` / `CaptureImageQualityPolicy` を通し、強い暗部潰れ・白飛び・明確なボケ/低ディテールframeを保存対象から除外。
- `GaussianDataset` / `GaussianTrainer` allocation前に `SplatResourceGuard.evaluate(splatCount: 0)` を実行し、memory/thermal pressure時はtrainer構築前に停止。

Build 2は上記A2 residual修正前なので履歴候補へ降格。

最新Internal TestFlight candidateは version `1.0.0` / build `3`。release branch `testflight/splat-native-ios-20260824-build3` はHQとの差分がrelease用 `codemagic.yaml` のみで、build numberを3へ設定。Codemagic build `6a8b36335c95c17422424e4d` はsigned IPA `Splat_Lab_Native.ipa`を生成してfinished。

Codemagic metadata上は `app_store_connect_status=failed` だがApple直接read-backを正とする。App Store Connect Build 3 resource `65e6164a-8ea8-4844-8259-c6d6a8507286` は `VALID / INTERNAL_ONLY / expired=false / usesNonExemptEncryption=false`。internal beta group `sun` のbuild一覧にもBuild 3を確認済み。

PR #4145は意図的にdraft / unmergedを維持する。TestFlight upload成功はPARITY完了ではない。

## 再実装禁止の解消済み事項

- 完成済みscanから「新規」: `returnHomePreservingProject()` で完成物を保持。
- 「あとで生成」: captured画面と保存済み一覧から再開可能。
- WorldMap durability race: 保存結果をawaitし、失敗時は撮影継続。
- relaunch後の `points3D.ply`: checkpointからfeature pointsを復元し、欠落時は生成開始時に再生成。
- ScanModel責任境界: Capture / Persistence / Reconstruction / SessionLifecycle boundary導入済み。
- B2 Mesh起動: `MeshScanContainerView()` 経由。
- D2 publish: `PublishScanView` は `publishTrustedPackage(...)` を使用し、直接未検証asset uploadへ戻さない。

## 現在の最大Gate

**Build 3** を実機で Golden Reference と比較する。必須flow:

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
- Scaniverse Golden Referenceに対する欠損、二重化、色、立体感、手数、速度の明白な劣位

この物理Gateを通るまでは capture/reconstruction/viewer/library の `PARITY` 昇格禁止。

## 物理Gate後

実生成したtrusted scanを使ってproduction E2Eを行う。synthetic/hardcoded scanで代替しない。

`explicit publish → durable asset URL → 別browser viewer → public/unlisted/private → Discover/Map（geotag opt-in時のみ） → unpublish/republish → owner delete`

Supabase productionは2026-08-24 03:56 JST時点で `auth.users=1 / scanlab_profiles=1 / scanlab_scans=0 / scanlab_reports=0 / scanlab_blocks=0`。production scan rowが実際に作られるまでは publish/share parity完了としない。

## 継続ループ

`最新実状態取得 → 未完了最大差分 → 実装/実測 → test/build/runtime → 辛口比較 → 修正 → 回帰gate → 正本更新`

禁止: compileだけで完了、古いhandoffの再実装、fake 3D/export/progress/Map、管理文書だけで停止、実機が必要でない作業まで人間待ちにすること。
