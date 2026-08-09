# RELEASE_STATUS｜第二種衛生管理者｜学びスプリント

更新: 2026-08-09

## 現在地
TestFlightビルド入力直前。Safari価値検証・UI確認・90問監査・法令/権利監査・iOSラッパー・申請原稿・公開Privacy/Support・Codemagic workflowまで準備済み。

## 固定値
- Version: `1.0.0`
- Build: `1`
- Bundle ID: `jp.allsunday1122.healthmanager2`
- iOS: SwiftUI + WKWebView
- Web教材: アプリ内同梱
- ビルド: Codemagic
- 課金: v1.0ではなし
- 広告/解析/ログイン/クラウド同期: なし

## PASS済み
- [x] Golden Master v2.1 UIへ同期
- [x] ユーザーによるSafari UI確認
- [x] 90問 / 3試験回 / 3科目 / 9セット各10問
- [x] 問題ID重複0
- [x] 本文高類似0
- [x] 要点高類似0
- [x] 水増し候補16問を再設計
- [x] 一次根拠URL 90/90
- [x] 基準日 90/90
- [x] 作問由来 90/90
- [x] 権利根拠 90/90
- [x] 法令関連35問の監査日設定
- [x] 2026-08-01施行の産業医辞任等報告改正を反映
- [x] 2025-06-01施行の熱中症対策を反映
- [x] SwiftUI + local WKWebViewラッパー作成
- [x] JSONバックアップをiOS共有シートへブリッジ
- [x] Privacy Manifest作成
- [x] Support / Privacy公開ページ作成
- [x] App Store日本語原稿作成
- [x] XcodeGen project.yml作成
- [x] Codemagic root workflow作成
- [x] TestFlight Internal Testing Only用export option設定
- [x] App Store本審査の自動提出を無効化

## クラウドMacで初めて確認する項目
現在のChatGPT実行環境にはXcode/macOS署名環境がないため、以下はCodemagicの最初のビルドで機械確認する。
- [ ] XcodeGenによる `.xcodeproj` 生成
- [ ] Swift compile
- [ ] Asset Catalog / 1024px AppIcon生成
- [ ] PrivacyInfo.xcprivacy同梱
- [ ] WKWebViewのローカルWeb資産読込
- [ ] Distribution signing
- [ ] IPA archive/export
- [ ] App Store ConnectへのBuild 1アップロード

FAIL時は標準手順v2.2に従い、該当箇所を修正して同じビルドループを再実行する。

## Apple/Codemagic側でのみ必要な本人操作
- [ ] Apple DeveloperでExplicit App ID `jp.allsunday1122.healthmanager2` を登録
- [ ] App Store Connectで新規アプリを作成しBundle IDを紐付け
- [ ] Codemagic Team integration `codemagic` にApp Store Connect API Keyを接続
- [ ] App Store用証明書・Provisioning ProfileをCodemagicで取得/登録
- [ ] Codemagicで `health-manager-2-ios` workflowを開始

パスワード、2FAコード、API秘密鍵はGitHub/Notion/チャットへ保存しない。

## 次の人間品質ゲート
Build 1がTestFlightへ到達したらiPhone 16で実機確認する。

### 実機合格条件
- [ ] 起動クラッシュなし
- [ ] ホーム/模試/記録/設定の4タブ
- [ ] 9セットが各10問で起動
- [ ] 8問スプリント完走
- [ ] 選択肢タップ即時採点
- [ ] ○×・ここだけ覚える・詳細解説
- [ ] 中断→続きから
- [ ] 苦手3連続正解で解除
- [ ] 学習記録永続化
- [ ] JSON書き出し→iOS共有シート
- [ ] アプリ再起動後も履歴保持
- [ ] 機内モードでも教材利用可能
- [ ] レイアウト崩れなし

この実機確認をPASSするまでApp Store本審査へ進めない。
