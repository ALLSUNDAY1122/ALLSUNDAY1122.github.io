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
- [x] 写真枚数だけでなく12方向の撮影範囲を評価
- [x] 撮影完了には最低8/12方向を要求
- [x] 端末をその場で回すだけでは写真を採用しない実移動ゲート
- [x] 48枚時点で方向不足なら最大72枚まで追加撮影可能
- [x] 生成3Dを実データ中心へ自動フレーミング
- [x] 3D表示のダブルタップ初期化
- [x] 生成失敗時に撮影を捨てず再生成可能
- [x] 完成3D破棄前に確認ダイアログ
- [x] 利用者画面から特徴点・iteration・splat数など内部用語を除去
- [ ] 最新コミットでGitHub Actions Release build PASS

## Gate 2｜申請設定整合

- [x] Bundle ID `jp.allsunday1122.splatlab`
- [x] Version `1.0.0`
- [x] iOS 18+
- [x] iPhone target
- [x] iPhoneホーム画面表示名 `おもちゃばこ`
- [x] Camera usage description
- [x] `ITSAppUsesNonExemptEncryption = NO`
- [x] Internal TestFlight only
- [x] App Store本審査への自動提出なし
- [x] App Store metadata draft
- [x] Privacy Policy原稿
- [x] Support原稿
- [x] TestFlight手順を撮影方向ゲート・新UIへ同期

## Gate 3｜Apple / Codemagic

- [ ] Apple Developer Explicit App IDが存在する
- [ ] App Store Connectに新規Appレコードが存在する
- [ ] 実発行App Store Connect Apple IDを正本へ記録
- [ ] App Store signing profile取得/生成
- [ ] signed IPA build PASS
- [ ] Internal TestFlight upload PASS

## Gate 4｜実機PoC

- [ ] 初回起動
- [ ] ホーム画面表示名 `おもちゃばこ`
- [ ] カメラ権限
- [ ] 初回 `新しく立体で残す` で撮影画面へ遷移
- [ ] 同じ場所で端末を回すだけでは撮影方向が埋まらない
- [ ] 対象の周囲を移動すると `撮影方向 x / 12` が増える
- [ ] 24枚以上かつ撮影方向8/12以上で生成可能になる
- [ ] 推奨48枚前後まで安定して取得できる
- [ ] 3D生成開始
- [ ] 利用者画面に内部iteration・splat数を出さず進捗が理解できる
- [ ] result.splat生成
- [ ] 生成3Dが自動的に中央へ収まる
- [ ] Metal表示
- [ ] 回転
- [ ] ピンチ拡大縮小
- [ ] ダブルタップ表示リセット
- [ ] 共有シート
- [ ] 完成3D破棄時に確認が出る
- [ ] 生成失敗時に撮影を残して再生成できる
- [ ] 再撮影
- [ ] クラッシュなし
- [ ] 異常な発熱・メモリ強制終了なし

## Gate 5｜PoC採否（人間判断）

技術検証の実機結果を見て次を決める。

- PASS: 立体の思い出として識別できる品質 → おもちゃばこMVP（アルバム・思い出情報・撮影ガイド品質改善）へ進む。
- CONDITIONAL: 生成は成立するが品質/速度に課題 → 撮影方向判定、撮影枚数、downscale、iteration、初期点群、撮影ガイドを改善して再試験。
- FAIL: 実用品質または端末負荷が成立しない → オンデバイス3DGS方式を再設計する。

App Store本審査提出はこのPoC採否とは別の最終人間承認ゲートとする。
