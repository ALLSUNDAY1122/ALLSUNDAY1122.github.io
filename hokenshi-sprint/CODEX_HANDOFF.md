# Codex引継ぎ正本｜保健師国家試験｜学びスプリント

更新: 2026-08-14 21:42 JST

## 役割
この時点から、保健師国家試験｜学びスプリントの実装・申請準備はCodexへ引き継ぐ。
ChatGPT側で完了済みの工程を重複してやり直さず、GitHubとNotionの正本を取得して現状から続行すること。

## 最初に必ず読むもの
1. Notion「AIアプリ開発・公開フロー」現行標準手順 v2.5
2. Notion「申請手順」
3. Notion「保健師国家試験｜学びスプリント 開発正本」
4. GitHub PR #4135
5. 本ファイル
6. `hokenshi-sprint/release/RELEASE_STATUS.md`
7. `hokenshi-sprint/release/APP_STORE_RECORD_VALUES.md`
8. `hokenshi-sprint/release/APP_STORE_SUBMISSION_ANSWERS_JA.md`

## GitHub
- repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- branch: `feat/hokenshi-sprint-native-foundation`
- PR: `#4135`
- PR state: open / draft
- 2026-08-14 21:13時点でGitHub再計算により `mergeable=true` を確認済み
- App Store本審査は人間確認地点 #4 の明示承認まで禁止

## 最新品質状態
Hokenshi Sprint Native Foundation run #250
- run ID: `31799064863`
- head SHA: `af42127905d60f836987e453daecf87bec5a2a2d`
- conclusion: success
- content-plan: PASS
- native-foundation: PASS
- persist-release-resources: PASS

主なPASS項目:
- 330問構造・canonical監査
- 現行保健師活動指針再照合
- free 30問 / premium 300問
- 無料10分野×3問
- 科目別同一問題水増し禁止
- LearningSprintCore tests
- Hokenshi Native tests
- StoreKit識別子・回復導線
- WebKit/WKWebView禁止
- XcodeGen
- In-App Purchase capability
- iOS Simulator Release build

## 現行仕様
- 独自問題330問
- 3回×110問
- 各回 一般75 + 状況設定35
- 10分野×11問
- 36 scenario groups
- 無料30問
- Premium 300問 + 模試
- 課金: 非消耗型・買い切り 800円
- アプリ内価格表示: StoreKit `Product.displayPrice` のみ
- Bundle ID: `jp.allsunday1122.hokenshi`
- IAP Product ID: `jp.allsunday1122.hokenshi.premium`
- Apple Team ID: `MN3D2ZM44N`
- Version: `1.0.0`
- SKU: `hokenshi-sprint-13-ios`
- Codemagic workflow/profile: `hokenshi_appstore`
- Internal TestFlightのみ
- `submit_to_app_store: false`

## AppIcon正本
Google Drive個別PNG `13_保健師国家試験.png`
- Drive file ID: `13fX8V5AuEiOHu2vhhnzHo4NosZ6pwTBt`
- 1024×1024 RGB
- bytes: 609,807
- SHA-256: `34c1ec303ef5420947bf13ab4b05d2045a70b79417ac40ebd667e05c8f2f2c64`

別画像を生成・代替しないこと。Driveの公開権限も変更しないこと。署名ビルド前に実バイトを搬送し、SHA-256完全一致を必須ゲートにする。

## 現在の唯一の外部ブロッカー
Apple Developer / App Store Connectへのユーザー認証を伴う操作。

ユーザー側で以下を実施する必要がある。
1. Explicit App ID `jp.allsunday1122.hokenshi` が未登録なら登録
2. App Store Connectで新規Appレコードを作成
3. Appleが発行した数値App Store Connect App IDを取得

Apple ID・パスワード・MFAコード・秘密鍵をGitHub/Notionへ保存しないこと。
数値App IDには仮値を置かず、Apple実発行値だけを採用すること。

## ユーザーから数値App Store Connect App IDを受領したら直ちに行うこと
確認質問を挟まず、以下を人間判断が必要になる地点まで連続実行する。

1. 数値App Store Connect App IDを識別情報正本へ記録
2. 非消耗型IAP `jp.allsunday1122.hokenshi.premium` を作成・800円基準で設定
3. AppIcon正本をDriveから取得し、SHA-256一致確認
4. Codemagic `hokenshi_appstore` で署名設定・Archive
5. signed IPA生成
6. Internal TestFlightへアップロード
7. App Privacy / Export Compliance / Age Rating / IAP設定を申請正本と照合
8. TestFlight配信可能状態まで確認
9. 人間確認地点 #3「Internal TestFlight実機確認」で停止

## 禁止事項
- App Store本審査を自動提出しない
- 数値App IDを推測しない
- 課金方式・価格を独断で変更しない
- 問題を水増ししない
- 既にPASS済みの330問監査を理由なく全面再生成しない
- WebView化しない
- AppIconを生成画像へ差し替えない
- ユーザー判断が不要な工程で停止しない

## 進行ルール
標準手順 v2.5の「人間判断が必要になるまで進め続ける」を最優先する。
FAIL時は原因を修正して品質ループを再実行し、PASSまで自己復旧する。
同じ操作を繰り返して進展がない場合は方法を変える。

次の人間確認地点は、Apple認証操作の完了後に到達する Internal TestFlight実機確認 #3。
