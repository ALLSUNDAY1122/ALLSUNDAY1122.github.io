# RELEASE STATUS｜薬剤師国家試験｜学びスプリント

更新：2026-08-10 JST

- 状態：SwiftUIネイティブ実装・コード側ReleaseゲートPASS・Internal TestFlight外部ゲート待ち
- 担当：ChatGPT（Codex移管は解除）
- Version：1.0.0
- Bundle ID：`jp.allsunday1122.yakuzaishi`
- App Store Connect App ID：`6799753724`
- Codemagic署名プロファイル正本名：`yakuzaishi_appstore`
- GitHub正本：main
- iOS方式：**SwiftUIネイティブ**。学習UIの`WKWebView`実行は禁止
- ビルド方式：XcodeGen + Codemagic
- TestFlight：Internal testing only
- App Store本審査自動送信：OFF

## 問題バンク
- 第111・110・109回：1,035問
- 採点対象：1,031問
- 公式「解なし」：4問（通常採点から除外）
- 任意2肢正答：3問
- 無料：第111回必須90問
- プレミアム：採点対象1,031問
- 問題監査：blocked 0、解説1,035/1,035、未解決高類似0、水増し0
- ネイティブ問題資産は`content/product/questions.json`から`prepare-ios.sh`で生成し、問題を二重管理しない

## ネイティブ学習機能
- 標準8問、設定4／8／16問
- ホーム／模試／記録／設定の4タブ
- 選択肢タップで即時採点
- 「わからない」で苦手登録
- 苦手は3回連続正解で卒業
- 途中再開。回答済み問題の二重加算を防止
- 問題・図版はアプリ内同梱でオフライン学習
- 学習状態はApplication SupportのJSONへ保存
- JSON書き出し／読み込み
- 35日ヒートマップ
- 達成度は採点対象問題のユニーク着手率、正答率とは分離
- 不正解でも`daily.answered`を即時加算し、5週間の学習へ反映
- 未着手は`—`、回答済み0正解は`0%`
- Reduce Motion対応

## StoreKit 2
- 月額：`jp.allsunday1122.yakuzaishi.monthly`
- 買い切り：`jp.allsunday1122.yakuzaishi.lifetime`
- `Product.displayPrice`を使用し、価格をコードへ固定しない
- `Transaction.currentEntitlements`／`Transaction.updates`
- `AppStore.sync()`による復元
- サブスクリプション管理導線
- 無料体験文言はApp Store側にIntro Offerがあり、かつeligibleの場合だけ表示

## Privacy / Rights
- データ収集：なし
- ログイン：なし
- 広告：なし
- 解析SDK：なし
- 独自クラウド同期：なし
- Privacy Manifest：tracking false / collected data [] / accessed API []
- Support / Privacy / Terms：作成済み

## AppIcon正本
- Google Drive：`05_薬剤師国家試験.png`
- file ID：`1Au-Es7rxAyLxuGCzySTDsE-DXLWTwTtu`
- SHA-256：`dfc7dfe4a1c13afbe98658cde591274e11665b016c39e2a4411de4dbe86127ec`
- GitHub asset：`ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

## ループエンジニアリング結果
PR #4128で以下をすべてPASS後にmainへ統合した。
- Static Gate：PASS
- Swift構文：PASS
- 1,035問→ネイティブJSON生成：PASS
- 採点対象1,031／無料90／解なし4／任意2肢3：PASS
- 公式画像154問のリソース生成：PASS
- `WKWebView` / `import WebKit`混入検査：PASS
- XcodeGen + In-App Purchase capability：PASS
- XCTest：PASS
- Release iOS Simulator build：PASS
- Release app resource audit：PASS
- specialist audit：Golden Master設定順、Reduce Motion、StoreKit、Privacy、TestFlight-only設定を再監査してPASS

最新PR最終ゲート：
- Native Compile Xcode16 run `31363872485`：PASS
- Native iOS Preflight run `31363872501`：PASS
- PR #4128 main統合：PASS

ユーザー実機で発見された「0正解だと達成度が動かないように見える」「5週間の学習へ回答が反映されない」問題は、ネイティブ版の実装とXCTest回帰テストへ固定した。

## 現在の未完了ゲート
**コード側FAILは0。署名付きInternal TestFlightは未送信。**

外部アカウント側で以下を確認してからCodemagicを実行する。
1. Explicit App ID / Bundle ID `jp.allsunday1122.yakuzaishi`
2. App Store Connect App ID `6799753724`
3. Codemagic provisioning profile正本名 `yakuzaishi_appstore` と対応するApple Distribution証明書
4. 月額／買い切りIAP、Subscription Group、必要なIntro Offer・ローカライズ・審査用情報
5. root `codemagic.yaml` の `pharmacist-ios` をmainから実行
6. 署名付きIPAを**Internal TestFlightのみ**へ送信
7. iPhone実機で学習・購入・復元・オフライン・記録画面を確認

`submit_to_testflight: true`、`submit_to_app_store: false`、`testFlightInternalTestingOnly`を維持し、本審査には送信しない。
