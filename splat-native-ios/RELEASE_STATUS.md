# Scan Lab｜Parity Program Status

更新日: 2026-08-15

## 現在地

`SCANIVERSE_PARITY_PROGRAM_ACTIVE`

Splat中心PoCを「完成」とみなす方針を廃止し、現行Scaniverse個人向けiOS機能との機能・実用品質同等化を先に完了する。

## 統括正本

- Notion: `Scaniverse同等化｜9セッション分割・統括正本 v1.0`
- GitHub: `splat-native-ios/SCANIVERSE_PARITY_PLAN.md`
- Session prompts: `splat-native-ios/SESSION_PROMPTS.md`
- Integration branch: `feature/splat-native-ios-poc`

## Specialist branches

- S1 `scaniverse/s1-capture`
- S2 `scaniverse/s2-splat-reconstruction`
- S3 `scaniverse/s3-splat-viewer-edit`
- S4 `scaniverse/s4-mesh-photogrammetry`
- S5 `scaniverse/s5-library-lifecycle`
- S6 `scaniverse/s6-export-video-share`
- S7 `scaniverse/s7-map-discover-backend`
- S8 `scaniverse/s8-adversarial-qa`

各専門sessionは開始時にintegration最新HEADとの差分を確認し、必要なら取り込んでから担当branch上でループエンジニアリングを継続する。

## 現在できている基盤

- ARKit撮影
- camera-to-world pose取得
- rawFeaturePoints初期点群
- Nerfstudio dataset
- msplat Metal学習経路
- `.splat` 書出し
- MetalSplatter表示
- 撮影方向coverage gate
- 実移動gate
- 自動framing
- 回転 / zoom / reset
- 再生成
- 破棄確認
- Privacy / license / CI基盤

これらは同等化programの出発点であり、Scaniverse parity完了を意味しない。

## 主な未同等項目

- Resume scan / process laterの製品導線
- 3DGS品質最適化・sky segmentation・enhance
- pan / crop / exposure / contrast / measurement
- Mesh / LiDAR / photogrammetry / texture
- persistent scan library / reprocess
- PLY / SPZ / mesh各種export
- video export
- browser share URL
- account / public-unlisted share
- Map / Discover
- representative-object side-by-side quality evidence
- device performance / thermal matrix

## おもちゃばこ

Scan Labのconsumer parityが完了するまで、おもちゃばこ固有UI・思い出メタデータ・対象物特化機能は本rootへ混ぜない。同等化完了後に3D基盤を移植する。

## 人間ゲート

各sessionは自動で進める。途中で止めてよいのは、実機比較、Apple認証済み外部UI、法的/商標判断、公開最終承認など真正な人間判断・操作が不可避な地点のみ。
