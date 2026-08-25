# RELEASE STATUS｜薬剤師国家試験｜学びスプリント

更新：2026-08-25 JST
担当：ChatGPT
GitHub正本：`main`

## 対象アプリ
- App：薬剤師国家試験｜学びスプリント
- Bundle ID：`jp.allsunday1122.yakuzaishi`
- App Store Connect App ID：`6799753724`
- Version：`1.0.0`
- 次回Build：`5`
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

## 直前Build
Build 4は2026-08-23時点で `VALID / INTERNAL_ONLY / IN_BETA_TESTING`、internal group `sun` まで到達し、ユーザー実機確認済み。ただし課金方針変更により申請には使用しない。

## 次工程
1. no-IAP変更をStatic Gate / XCTest / Xcode16 Release / iOS Preflightで検証
2. mainへ統合
3. Build 5を署名・App Store Connectへupload
4. Build 5 processing/read-back
5. App Store Version 1.0.0へBuild 5を紐付け
6. Store metadata / Privacy / Age Rating / Review Detail / Screenshotsを申請手順に沿って監査・補完
7. 新BuildのHuman Device Acceptanceを満たす
8. Review Submissionへ追加し、本申請

ユーザーは2026-08-25に本申請を明示承認済み。ただし申請手順上、新BinaryのiPhone実機受入が真正なHUMAN_REQUIREDとして残る場合は、そのGateを偽装せず停止する。
