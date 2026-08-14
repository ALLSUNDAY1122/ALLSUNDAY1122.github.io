# Splat Lab Native｜Release Gate

更新日: 2026-08-15

## Gate 1｜実装・静的検査

- [x] SwiftUIネイティブ実装
- [x] ARKit camera pose取得
- [x] ARKit rawFeaturePointsを初期PLYへ保存
- [x] Nerfstudio transforms.json生成
- [x] msplatを固定revisionで利用
- [x] MetalSplatterを固定revisionで利用
- [x] 外部API・ログイン・解析SDKなし
- [x] PrivacyInfo.xcprivacyあり
- [x] AppIcon生成経路あり
- [x] 初回撮影開始前にARSessionをマウントする構成へ修正
- [ ] 最新コミットでGitHub Actions Release build PASS

## Gate 2｜申請設定整合

- [x] Bundle ID `jp.allsunday1122.splatlab`
- [x] Version `1.0.0`
- [x] iOS 18+
- [x] iPhone target
- [x] Camera usage description
- [x] `ITSAppUsesNonExemptEncryption = NO`
- [x] Internal TestFlight only
- [x] App Store本審査への自動提出なし
- [x] App Store metadata draft
- [x] Privacy Policy原稿
- [x] Support原稿

## Gate 3｜Apple / Codemagic

- [ ] Apple Developer Explicit App IDが存在する
- [ ] App Store Connectに新規Appレコードが存在する
- [ ] 実発行App Store Connect Apple IDを正本へ記録
- [ ] App Store signing profile取得/生成
- [ ] signed IPA build PASS
- [ ] Internal TestFlight upload PASS

## Gate 4｜実機PoC

- [ ] 初回起動
- [ ] カメラ権限
- [ ] 初回 `新しく3Dで残す` で撮影画面へ遷移
- [ ] 24〜48フレーム取得
- [ ] 特徴点64以上
- [ ] 3D学習開始
- [ ] 2,000 iteration完走
- [ ] result.splat生成
- [ ] Metal表示
- [ ] 回転
- [ ] ピンチ拡大縮小
- [ ] 共有シート
- [ ] 再撮影
- [ ] クラッシュなし
- [ ] 異常な発熱・メモリ強制終了なし

## Gate 5｜PoC採否（人間判断）

技術検証の実機結果を見て次を決める。

- PASS: 立体の思い出として識別できる品質 → おもちゃばこMVP（アルバム・思い出情報・撮影ガイド品質改善）へ進む。
- CONDITIONAL: 生成は成立するが品質/速度に課題 → 撮影枚数、downscale、iteration、初期点群、撮影ガイドを改善して再試験。
- FAIL: 実用品質または端末負荷が成立しない → オンデバイス3DGS方式を再設計する。

App Store本審査提出はこのPoC採否とは別の最終人間承認ゲートとする。
