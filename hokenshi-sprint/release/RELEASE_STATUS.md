# Release Status｜保健師国家試験｜学びスプリント

更新: 2026-08-14

## 到達状態
**標準手順 v2.4再適用済み / Apple操作直前までのNative Release Gate PASS / Apple新規Appレコード作成待ち**

## v2.4再確認・差分適用
2026-08-14改訂の標準手順 v2.4を再確認し、本アプリへ次を適用済み。
- 学びスプリント課金標準: 本アプリは完成教材として長期利用できるため、既採用の非消耗型・買い切りPremiumを維持し、日本向け価格を`800円`へ確定
- Bundle ID恒久委任: `jp.allsunday1122.hokenshi`を維持。ユーザー確認ゲートに戻さない
- 早期試用URL必須: GitHub Pagesデモを公開・提示済みで条件達成
- NO_PROGRESS自己復旧: 同一操作の空回りを継続せず、CIトリガー変更・main同期等の方法変更で復旧済み
- アプリ内価格は引き続きStoreKit `Product.displayPrice`のみを表示し、`800円`文字列をコードへ固定しない

## 完了
- Notion正本照合
- 初期Safari試作品のユーザー動作確認・採用
- Golden Master v2.1適用
- SwiftUI Native製品シェル
- WebKit/WKWebView不使用
- 330問独自問題bankを `release_ready` としてSwift Packageへ同梱
- 3回×110問 / 各回75一般+35状況設定 / 10分野×11
- 36 scenario groups
- 状況設定本文をNative問題画面へ接続
- 一次根拠を解説画面から開く導線
- Evidence / Content / Rights / current-guidance gate
- 現行保健師活動指針（2026-05-15）再照合
- オフライン学習
- 4/8/16、苦手、わからない、3連続解除、途中再開、履歴、35日ヒートマップ、目標試験日、文字サイズ、JSON backup
- 午前55／午後55／通し110模試
- Privacy Manifest
- iPhone向けXcodeGen App target
- StoreKit 2買い切りPremium実装
- verified transaction / revocation確認 / transaction updates
- 購入復元常設
- StoreKit `Product.displayPrice` だけを価格表示に使用
- StoreKit製品情報取得失敗時の「製品情報を再読み込み」回復導線
- 無料科目別3問を8問へ同一問題で水増ししないことを10科目すべてテストで固定
- `codemagic.yaml` にInternal TestFlight専用 `hokenshi_appstore` workflow追加
- 課金導入後の辛口レビュー3周を再実施してPASS
- App Store日本語原稿を課金・独自問題の実態へ同期。「過去問」キーワードを削除
- App Store Connect入力回答正本 `APP_STORE_SUBMISSION_ANSWERS_JA.md` 作成

## 公開済みURL
GitHub Pages mainで公開・build成功。
- Demo: `https://allsunday1122.github.io/hokenshi-sprint/demo/`
- Support: `https://allsunday1122.github.io/hokenshi-sprint/support.html`
- Privacy: `https://allsunday1122.github.io/hokenshi-sprint/privacy.html`

## 決定済み識別情報
- Bundle ID: `jp.allsunday1122.hokenshi`
- Codemagic profile/workflow: `hokenshi_appstore`
- IAP Product ID: `jp.allsunday1122.hokenshi.premium`
- Apple Team ID: `MN3D2ZM44N`
- Version: `1.0.0`
- SKU: `hokenshi-sprint-13-ios`

App Store Connectの数値App IDはApple自動発行値のため仮値を作らない。

## 課金方式
- 非消耗型・買い切りPremium
- 日本向け価格: `800円`（標準手順 v2.4）
- 無料: 30問。第1回の10分野から各3問ずつを均等に公開
- Premium: 残り300問＋模試機能
- 無料版でも通常スプリント・分野別学習・苦手復習の中心体験を確認できる
- 無料科目別学習は利用可能3問で終了し、目標8問へ同一問題を反復補充しない
- App Store Connectの商品価格とStoreKit `Product.displayPrice`の一致をTestFlightで確認する

## AppIcon正本
Google Drive個別PNG `13_保健師国家試験.png` を正本として特定・取得済み。
- Drive file ID: `13fX8V5AuEiOHu2vhhnzHo4NosZ6pwTBt`
- format: PNG RGB
- size: 1024×1024
- bytes: 609,807
- SHA-256: `34c1ec303ef5420947bf13ab4b05d2045a70b79417ac40ebd667e05c8f2f2c64`

2026-08-14にDriveから実バイトを再取得し、ローカルSHA-256も上記正本値と完全一致。Driveファイルはowner-onlyの非公開状態を維持する。Asset Catalogは `AppIcon-1024.png` を参照済み。GitHub/Codemagicへ実バイトを搬送する際はSHA完全一致を必須ゲートとし、別画像生成・代替画像・公開権限変更は行わない。

## CI
最新の機能コードを含む Hokenshi Sprint Native Foundation run #249（ID `31772797429`）:
- content-plan: PASS
- native-foundation: PASS
- persist-release-resources: PASS

検証内容:
- canonical/content/current-guidance/release-resource gate PASS
- free=30 / premium=300 / 無料10分野×3問 PASS
- Native product shell audit PASS
- LearningSprintCore tests PASS
- Hokenshi Native tests PASS
- 科目別同一問題反復禁止テスト PASS
- StoreKit製品情報再読込導線の静的監査 PASS
- Bundle ID / Team ID / IAP Product ID正本一致 PASS
- WebView禁止 PASS
- XcodeGen + IAP capability PASS
- iOS Simulator Release build PASS
- audited resource persist PASS

CI運用はfeature branch `push`＋`workflow_dispatch`へ一本化し、同一commitのpush/PR二重実行を廃止。

## App Store申請準備
- Privacy Policyは現行の買い切りPremium実装へ更新済み
- Supportに購入復元FAQ・問い合わせ導線を追加済み
- App Privacy: 現実装ではData Collectionなしとして申告する正本を準備済み
- Export Compliance: `ITSAppUsesNonExemptEncryption=false` をiOS targetへ設定済み
- Age Rating: 国家試験教材で疾患等を扱うため、Medical or Treatment InformationをNoneとせずInfrequentで回答する正本を準備済み
- IAPローカライズ名・説明・Review Notesを正本化済み
- IAP日本向け価格800円を正本化済み

## 現在の外部ブロッカー
Apple Developer / App Store Connectへのユーザー認証を伴う操作が必要。
1. Explicit App ID `jp.allsunday1122.hokenshi` が未登録なら登録
2. App Store Connectで新規Appレコードを作成
3. Appleが発行した実App IDを取得

固定入力値は `release/APP_STORE_RECORD_VALUES.md` と `release/APP_STORE_SUBMISSION_ANSWERS_JA.md` に記録済み。

Appレコード作成後は、実App IDを正本へ記録→800円の非消耗型IAP作成→正本AppIcon搬送→Codemagic署名→signed IPA→Internal TestFlightへ進む。

## 人間確認地点
次の製品判断の人間確認地点は #3「Internal TestFlight実機確認」。ただしその前段として、Appleログイン/MFAを伴う新規Appレコード作成はユーザー操作が必要。
App Store本審査は #4 の明示承認まで実行しない。
