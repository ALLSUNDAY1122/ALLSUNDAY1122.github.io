# RELEASE_STATUS｜第二種衛生管理者｜学びスプリント

更新: 2026-08-09

## 現在地
**TestFlightクラウドビルド開始直前。** Safari価値検証、Golden Master v2.1 UI確認、90問監査、法令/権利監査、最終辛口レビュー3周、iOSラッパー、Privacy/Support、App Store原稿、Codemagic workflowまで完了。

次に必要なのはApple/Codemagic側の本人認証を伴う登録・署名準備と、Codemagic `health-manager-2-ios` workflowの実行。Build 1がTestFlightへ到達した時点で次の人間品質ゲート（iPhone実機確認）へ移る。

## 固定値
- Version: `1.0.0`
- Build: `1`
- Bundle ID: `jp.allsunday1122.healthmanager2`
- iOS: SwiftUI + WKWebView
- Web教材: アプリ内同梱
- ビルド: Codemagic
- TestFlight: Internal Testing Only
- Beta App Review自動提出: しない
- App Store本審査自動提出: しない
- 課金: v1.0ではなし
- 広告/解析/ログイン/クラウド同期: なし

## PASS済み
- [x] Golden Master v2.1 UIへ同期
- [x] ユーザーによるSafari UI確認
- [x] 90問 / 3試験回 / 3科目 / 9セット各10問
- [x] 問題ID重複0
- [x] 高類似0.90以上0
- [x] 同一論点の高類似警告0
- [x] 水増し問題を独立論点・適用・計算問題へ再設計
- [x] 各10問セットで正答位置1〜5を各2回へ均等化
- [x] 一次根拠URL・基準日・作問由来・権利根拠を保持
- [x] 2026-08-01施行の産業医関連改正を反映
- [x] 2025-06-01施行の熱中症対策を反映
- [x] SwiftUI + local WKWebView
- [x] Web公開版とiOS同梱版で `audit-patch-v2.js` / `audit-fixes.js` / `question-order-v1.js` を共通利用
- [x] JSONバックアップをiOS共有シートへブリッジ
- [x] 正解/不正解/操作のネイティブハプティクス
- [x] Privacy Manifest
- [x] Support / Privacy公開ページ
- [x] App Store日本語原稿
- [x] XcodeGen project.yml
- [x] Codemagic workflow
- [x] CodemagicのmacOSビルド前に共通問題監査 `validate_questions.py` を自動実行
- [x] 同梱ファイル・Privacy Manifest・AppIcon存在検査
- [x] TestFlight Internal Testing Only export option
- [x] App Store本審査自動提出OFF
- [x] 最終辛口レビュー3周完了、修正可能な重大指摘0

## Codemagic最初のビルドで機械確認する項目
現在のChatGPT実行環境にはXcode/macOS署名環境がないため、以下はCodemagicを次の機械ゲートとする。
- [ ] 共通90問監査スクリプトPASS
- [ ] XcodeGenによる `.xcodeproj` 生成
- [ ] Swift compile
- [ ] Asset Catalog / 1024px AppIcon生成
- [ ] PrivacyInfo.xcprivacy同梱
- [ ] WKWebViewのローカルWeb資産読込
- [ ] Distribution signing
- [ ] IPA archive/export
- [ ] App Store ConnectへのBuild 1アップロード
- [ ] TestFlight処理完了

FAIL時は標準手順v2.2に従い、該当箇所を修正して同じループを再実行する。

## Apple/Codemagic側でのみ必要な本人操作
- [ ] Apple DeveloperでExplicit App ID `jp.allsunday1122.healthmanager2` を登録
- [ ] App Store Connectで新規アプリを作成しBundle IDを紐付け
- [ ] Codemagic integration `codemagic` にApp Store Connect API Keyを接続/確認
- [ ] Apple Distribution証明書とApp Store provisioning profileをCodemagicで利用可能にする
- [ ] Codemagicで `health-manager-2-ios` workflowを開始

パスワード、2FAコード、API秘密鍵はGitHub/Notion/チャットへ保存しない。

## App Reviewでの残存リスク
- Guideline 4.2: WKWebView主体だが、90問を完全同梱し、8問スプリント、9セット、履歴、苦手卒業、中断再開、JSON共有、ネイティブ触覚を備えることで単純なWeb再包装との差を明確化した。
- Guideline 4.3: 第一種など同シリーズとのUI基盤共有により、App Store本審査では類似アプリ判定の可能性が残る。第二種固有の試験範囲・独立90問バンク・Review Notesで差異を説明し、本審査提出時の人間最終承認で再評価する。

このリスクはInternal TestFlightビルドを止める技術的FAILではない。

## 次の人間品質ゲート
Build 1がTestFlightへ到達したらiPhone実機で確認する。

### 実機合格条件
- [ ] 起動クラッシュなし
- [ ] ホーム/模試/記録/設定の4タブ
- [ ] 9セット正常・各10問
- [ ] 8問スプリント完走
- [ ] 即時採点・ハプティクス
- [ ] ○×・ここだけ覚える・詳細解説
- [ ] 中断→続きから
- [ ] 苦手3連続正解で解除
- [ ] 学習記録永続化
- [ ] JSON書き出し→iOS共有シート
- [ ] アプリ再起動後も履歴保持
- [ ] 機内モードでも教材利用可能
- [ ] レイアウト崩れなし

この実機確認をPASSするまでApp Store本審査へ進めない。
