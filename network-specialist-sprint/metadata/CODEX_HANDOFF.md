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
旧実装のSwiftUI + WKWebView方式は、2026-08-10のユーザー指示「WebViewだけの簡易実装にしない」により廃止。
現在は純SwiftUIでホーム / 模試 / 記録 / 設定 / 問題 / 結果を実装し、WebKitソースをアプリターゲットから削除している。

## 変更禁止の正本
- 問題: 2025/2024/2023 春期 科目A-2 各25問＝75出題枠
- 通常学習: 68ユニーク
- 歴史的再出題・実質同一: 7出題をcanonical化
- AppIcon: Drive `07_ネットワークスペシャリスト試験.png` / file ID `1V9gAXcE7jSuYn9Y8SFgYWHNfRGsE_Lb8`
- AppIcon SHA-256: `5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729`
- AppIcon再生成禁止

## 不明値
- #7 App Store Connect App IDは、2026-08-10にユーザーが提示した正本ブロックに記載がない。外部検索や類推で埋めない。
- #7 IAP Product IDも正本ブロックに記載がない。初期版はIAPなしを維持し、StoreKit商品を発明しない。

## 次工程
PR #4126のUnit/UI/サイズ別テスト → 辛口レビュー3周 → Release Gate再監査 → 正本AppIcon配置 → Codemagic署名付きIPA → App Store Connect upload → TestFlight Internal Testing。

Codexへ引き継がない。
