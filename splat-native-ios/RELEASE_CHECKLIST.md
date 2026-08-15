# Scan Lab｜Parity / TestFlight Gate

更新日: 2026-08-15

## 目的

TestFlightはScaniverse同等化途中の実機比較手段として使う。Splat中心経路が動いただけでは製品完成・同等化完了としない。

## Gate A｜統括基盤

- [x] Scaniverse同等化正本をNotionに作成
- [x] `SCANIVERSE_PARITY_PLAN.md` 作成
- [x] 9セッション構成確定
- [x] S1〜S8専用branch作成
- [x] おもちゃばこ固有UIを同等化branchから分離
- [x] 内部ブランドを `Scan Lab` に統一
- [x] Bundle ID `jp.allsunday1122.splatlab`
- [x] App Store本審査への自動提出禁止

## Gate B｜現在のSplat中心経路

- [x] SwiftUIネイティブ実装
- [x] ARKit camera pose取得
- [x] ARKit rawFeaturePointsを初期PLYへ保存
- [x] Nerfstudio transforms.json生成
- [x] msplatを固定revisionで利用
- [x] MetalSplatterを固定revisionで利用
- [x] 初回撮影開始前にARSessionをマウント
- [x] 12方向の撮影範囲評価
- [x] 最低8/12方向ゲート
- [x] 回転だけで写真を稼ぎにくい実移動ゲート
- [x] 生成3Dの自動フレーミング
- [x] 回転・zoom・表示リセット
- [x] 生成失敗時の再生成
- [x] 破棄確認
- [x] Privacy Manifest
- [x] 第三者ライセンス
- [ ] 最新integration HEADでGitHub Actions iPhone Release build PASS
- [ ] Internal TestFlightで実スキャン生成
- [ ] Scaniverseと同条件で代表対象を比較

## Gate C｜Consumer parity ledger

以下はすべて `PARITY` 必須。詳細は `SCANIVERSE_PARITY_PLAN.md` を正本とする。

- [ ] S1 Capture / Tracking / Resume / long-scan guidance
- [ ] S2 Gaussian Splat reconstruction quality / sky handling / enhancement
- [ ] S3 Viewer / pan / crop / exposure / contrast / measurement
- [ ] S4 Mesh / photogrammetry / LiDAR / texturing
- [ ] S5 persistent library / raw lifecycle / process later / reprocess
- [ ] S6 PLY / SPZ / model exports / video / share
- [ ] S7 account / public-unlisted sharing / browser viewer / Map / Discover
- [ ] S8 no unresolved Sev-1 / Sev-2
- [ ] S0 ledger has no MISSING / PARTIAL / NEAR_PARITY

## Gate D｜Apple / Codemagic / Internal TestFlight

Apple外部UI操作が必要な時点でのみ人間ゲートとする。

- [x] TestFlight preflightは最新S0を含まないrelease branchを強制FAILする（#4161）
- [x] Codemagic signed-IPA経路にXcode 26以上 / iOS 26 SDK以上のruntime guardを追加
- [x] Internal TestFlight用workflowは `submit_to_app_store: false`
- [ ] 最新S0統合候補を `testflight/splat-native-ios` へ同期し、stale-source preflight PASS
- [ ] Explicit App ID
- [ ] App Store Connect App record
- [ ] 実Apple ID記録
- [ ] signing profile
- [ ] signed IPA
- [ ] Internal TestFlight upload

このGateは開発終了条件ではなく、必要な実機比較を配布するために適宜通過する。S0統合候補ができる前に古いTestFlight枝を同期・配布しない。

## Gate E｜App Store本審査前の必須人間確認

Internal TestFlight比較とは別の最終ゲート。自動提出しない。

- [ ] Privacy Policy URLをApp Store Connectへ登録し、公開URLが表示可能
- [ ] 現行のAge Rating質問へApp Store Connectで回答し、Unratedでないことを確認
- [ ] App Store ConnectのApp Privacy回答を最終統合実装と再照合
- [ ] S7導入後のアカウント・公開共有・Map/Discoverに合わせPrivacy Manifest / privacy policy / Review Notesを再監査
- [ ] 最終スクリーンショット・説明・カテゴリ等のストア情報を完成版UIと照合
- [ ] ユーザーがApp Store本審査提出を明示承認

## Gate F｜おもちゃばこ移植判断

Scaniverse consumer parityが完了するまでは到達不可。

- [ ] Scan Lab consumer parity = PASS
- [ ] ユーザーが代表scanの品質を実機比較
- [ ] 3D基盤をおもちゃばこへ移植する判断

App Store本審査提出はGate Eの最終人間承認後にのみ行う。
