# HISTORICAL HANDOFF NOTICE｜ネットワークスペシャリスト｜学びスプリント

更新: 2026-08-10 JST

このファイル名は履歴互換のため残すが、**Codexへの引継ぎはユーザー指示により取消済み**。
以降の設計・実装・検証はChatGPT内で進める。

## 現在地
- 対象: 開発連番#7 ネットワークスペシャリスト試験｜学びスプリント
- ネイティブ化PR: #4126 `agent/network-specialist-native-swiftui`
- Bundle ID: `jp.allsunday1122.networkspecialist`
- Apple Team ID: `MN3D2ZM44N`
- Version: `1.0.0`
- Codemagic profile: `networkspecialist_appstore`
- TestFlight: Internal Testing only
- App Store本審査自動提出: 禁止

## 重要変更
旧実装のSwiftUI + WKWebView方式は廃止。現在は純SwiftUIでホーム / 模試 / 記録 / 設定 / 問題 / 結果を実装し、WebKitソースをアプリターゲットから削除している。

前回macOS CIのFAILはSwiftコンパイルではなく、生成済み `questions.native.json` が実行時Bundleから見つからないことが原因だった。現在は以下を修正済み。
- XcodeGenで `NetworkSpecialist/Resources/questions.native.json` を明示的なresourceとして登録
- `QuestionRepository` がBundleルートと `Resources` subdirectoryの両方を確認

## StoreKit 2
StoreKit 2の非消耗型買い切り機構を実装済み。
- `Product.products` で商品取得
- `Product.displayPrice` を価格表示に使用
- verified active transactionのみ解放
- unverified / pending / cancelled / revocationは解放しない
- `Transaction.currentEntitlements` を権利判定の正本にする
- `Transaction.updates` を起動中監視
- 「購入を復元」の明示操作時のみ `AppStore.sync()`

ただし #7 IAP Product IDは正本に未記載のため、コードへ発明していない。Product ID未設定時は購入UIを表示せず、Codemagic Release Gateは `--require-iap` で停止する。

## 変更禁止の正本
- 問題: 2025/2024/2023 春期 科目A-2 各25問＝75出題枠
- 通常学習: 68ユニーク
- 歴史的再出題・実質同一: 7出題をcanonical化
- AppIcon: Drive `07_ネットワークスペシャリスト試験.png` / file ID `1V9gAXcE7jSuYn9Y8SFgYWHNfRGsE_Lb8`
- AppIcon SHA-256: `5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729`
- AppIcon再生成禁止

## 不明値・Release blocker
- #7 App Store Connect App ID：正本未記載。外部検索や類推で埋めない
- #7 IAP Product ID：正本未記載。類推・生成禁止
- 正本AppIcon：ローカル原本SHA一致確認済みだがGitHub checkoutへのPNGバイナリ配置未完了
- Support / Privacy：GitHubファイルは更新済みだが、この実行環境から公開HTTP 200を独立確認できていない
- Apple/Codemagic認証、署名、App Store Connect upload、TestFlight実機確認未完了

## 次工程
最新PR CIでUnit/UI/大・小2サイズSimulatorをPASS → Product ID / ASC App ID / AppIconの外部ゲート解消 → Codemagic Release Gate → 署名付きIPA → App Store Connect upload → TestFlight Internal Testing → 実機確認。

App Store本審査へは進めない。Codexへ引き継がない。
