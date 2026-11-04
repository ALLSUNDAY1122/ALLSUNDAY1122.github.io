# RELEASE STATUS｜薬剤師国家試験｜学びスプリント

更新：2026-11-04 JST
担当：ChatGPT
GitHub正本：`main`

## 対象アプリ
- App：薬剤師国家試験｜学びスプリント
- Bundle ID：`jp.allsunday1122.yakuzaishi`
- App Store Connect App ID：`6799753724`
- Version：`1.0.0`
- 次回Build：Codemagic workflow実行時にUTC timestamp（YYYYMMDDHHMMSS）で採番
- Codemagic workflow：`pharmacist-ios`
- 価格：無料
- アプリ内課金：なし
- 利用範囲：第111・110・109回、採点対象1,031問を追加購入なしで全開放

## 2026-08-25 方針変更
ユーザーの明示指示により、初回公開では課金システムを搭載しない。旧Build 4のStoreKit／無料90問／プレミアム制限は申請対象外とする。

申請対象Buildでは以下を必須とする。
- StoreKit実装をXcodeターゲットから除去
- Paywall、購入、復元、サブスクリプション管理を除去
- 分野別・模試・苦手・今日のスプリントを購入状態に依存させない
- 採点対象1,031問を全ユーザーへ開放
- App Storeメタデータを「無料・アプリ内課金なし」へ統一
- 旧IAP商品はVersionへ紐付けず、今回の審査対象に含めない

## 品質正本
- 問題バンク：1,035問
- 採点対象：1,031問
- 解なし：4問
- 第111・110・109回：各345問
- 生成補充：0
- 難易度方針：厚生労働省公式過去問のみ
- 公式紙面画像：全画面＋最大6倍ピンチズーム＋ドラッグ＋ダブルタップ
- 分野別：約20問ずつの均等セット
- 今日のスプリント：4／8／16問
- SwiftUIネイティブ、WKWebViewなし
- ログインなし、広告なし、解析SDKなし、独自クラウド同期なし

## 直前Build・今回のTestFlight方針
旧Build 4は2026-08-23時点で `VALID / INTERNAL_ONLY / IN_BETA_TESTING`、internal group `sun` まで到達したが、no-IAP変更前のため今回の確認には使用しない。直近のASC読取記録（2026-11-04）では旧Build `202609140032` が `VALID`。これは今回の品質修正を含まないため再利用しない。

今回の目的は、最新品質修正版をInternal TestFlightへアップロードし、ユーザーが実機で最終確認できる状態にすること。App Store Reviewへの追加・提出は行わない。Codemagic `pharmacist-ios` は `submit_to_testflight: true` / `submit_to_app_store: false` を維持する。

## 次工程｜TestFlight限定
1. 公式正誤表・法令改正・出典表示の重大欠陥を修正
2. Static Gate / XCTest / Xcode16 Release / iOS Preflightを再実行
3. mainへ統合
4. Codemagic `pharmacist-ios` で署名IPAを生成・ASCへupload
5. ASCでprocessing完了、Build `VALID`、Internal TestFlight登録をread-back
6. ユーザーが実機で最終受入確認

App Review用VersionへのBuild紐付け、Review Submission追加、Add for Review、Submit for Reviewは今回実施しない。

ユーザーは2026-08-25に本申請を明示承認済み。ただし申請手順上、新BinaryのiPhone実機受入が真正なHUMAN_REQUIREDとして残る場合は、そのGateを偽装せず停止する。
