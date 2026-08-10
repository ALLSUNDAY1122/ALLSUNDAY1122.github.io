# 司法書士｜純SwiftUI移行ステータス

更新: 2026-08-10 JST

## 旧実装の判定
従来の `SwiftUI + WKWebView` 実装は、2026-08-10のユーザー指定「WebViewだけの実装は禁止、SwiftUIネイティブで実装」により実装/UI/ReleaseのPASSを失効した。問題本文・正答・解説・根拠データは変更していないため、210問の問題内容監査PASSは保持する。

## 今回の純ネイティブ範囲
- SwiftUIネイティブ画面のみ。`WebKit` / `WKWebView` / `UIViewRepresentable` を禁止。
- Golden Master v2.1: 生成り紙、28px方眼、藍・朱・緑・金、明朝＋ゴシック、82px進捗リング。
- 4タブ: ホーム／模試／記録／設定。
- 標準8問、設定4／8／16問。
- 即時採点、手書き風○×、解説、`ここだけ覚える`。
- 誤答で苦手登録、同一問題3連続正解で解除。
- 問題途中／回答後解説状態を含む途中再開。
- 210問JSONをアプリバンドルへ同梱。学習機能はオフライン。
- Codable状態を端末内UserDefaultsへ保存。
- Files経由JSONバックアップの書き出し／読み込み。
- 学習記録: 全体ドーナツ、11科目バー、5週間ヒートマップ、苦手復習。
- 試験日、残日数、必要ペース。
- StoreKit 2 Non-Consumable `jp.allsunday1122.shoshi.premium`。

## 固定Apple情報
- App: `司法書士 学びスプリント`
- Bundle ID: `jp.allsunday1122.shoshi`
- App Store Connect App ID: `6799755748`
- Codemagic signing profile canonical name: `shoshi_appstore`
- IAP: `jp.allsunday1122.shoshi.premium`
- TestFlight: Internalのみ。本審査自動提出は禁止。

## 監査
GitHub Actions `Shoshi Native iOS Release Gate` が次を実施する。
1. 210問共通validator。
2. 純SwiftUIソース契約監査。
3. Apple/TestFlight preflight。
4. Privacy Manifest監査。
5. macOS/XcodeGenで単体テスト。
6. unsigned Release Simulator build。
7. `.app`内210問・Privacy・Assets・Webディレクトリ不在を検査。
8. 正本AppIcon SHA-256を独立ハードゲートとして検査。

## 正本AppIcon
Release/TestFlightでは `Assets.xcassets/AppIcon.appiconset/AppIcon.png` が次のSHA-256と完全一致すること。
`c34399358e182a4709f805127fc7244f9763a1f796bb68dfed24b5c4ee815506`

Simulatorのコンパイル確認に限りplaceholderを生成できるが、Archive/TestFlight使用は禁止。
