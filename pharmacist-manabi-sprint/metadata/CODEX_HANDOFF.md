# CODEX HANDOFF｜薬剤師国家試験｜学びスプリント

更新：2026-08-09 19:52 JST
担当移管：ChatGPT → Codex

## 現在地
ChatGPT側の大きな製品化ループは完了。ユーザーはGitHub Pages v0.6.1をiPhone Safari実機で確認し「問題なし」と承認済み。

iOS製品化、StoreKit 2、Privacy、申請原稿、Codemagic、AppIcon正本配置、静的リリース監査、macOS/Xcode Simulator compileまで完了している。最終PreflightはGitHub Actions run `31304173464` / run number `15` がSUCCESS、`simulatorBuildExit: 0`。

**ここからの主担当はCodex。** ただし最初の停止条件はApple Developer / App Store Connect / Codemagicでの本人アカウント操作。本人操作が済んだら、Codexは署名付きInternal TestFlight生成→実機確認支援→申請前監査へ進む。

## 固定値
- Repo：`ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Main path：`pharmacist-manabi-sprint/`
- Notion正本：`https://app.notion.com/p/3b609c10697d81c6b58dd0935d581b7d`
- Bundle ID：`jp.allsunday1122.yakuzaishi`
- Version / Build基準：`1.0.0 / 1`（CIではbuild番号を更新してよい）
- iOS方式：SwiftUI + WKWebView / audited local bundled assets
- Build：root `codemagic.yaml` workflow `pharmacist-ios`
- Monthly：`jp.allsunday1122.yakuzaishi.monthly`
- Lifetime：`jp.allsunday1122.yakuzaishi.lifetime`
- Free：第111回 必須90問
- Premium：採点対象1,031問
- 問題バンク：1,035問（採点対象1,031 / 解なし除外4 / multiple accepted 3）
- TestFlight：Internal testing only
- App Store本審査自動送信：**禁止**。`submit_to_app_store: false`を維持する

## 完了済み・再実装不要
1. Safari価値検証 v0.6.1：ユーザー実機PASS
2. 第111・110・109回：各345問、計1,035問を収録
3. 問題監査：blocked 0、解説1,035/1,035、未解決高類似0、水増し0
4. UI Master v2.1適用
5. SwiftUI + WKWebViewローカル教材方式
6. StoreKit 2：月額＋買い切り、currentEntitlements、pending、cancel、restore、manage subscriptions
7. 7日無料表示：StoreKitのintro offer設定＋eligibilityがtrueの場合のみ表示
8. 価格：ハードコード禁止、`Product.displayPrice`を使用
9. Privacy Manifest：tracking false / collected data [] / accessed API []
10. Support / Privacy / Terms公開ページ
11. App Store metadata / App Privacy & Content Rights資料
12. Codemagic `pharmacist-ios`
13. AppIcon正本をiOS Assetへmaterialize済み
14. XcodeGen + IAP capability normalizer
15. 最終Preflight PASS

## 重要な正本・変更禁止対象
### UI
Notion 学びスプリント UI Master v2.1 Golden Masterを最上位とする。

### 問題
- `pharmacist-manabi-sprint/content/product/questions.json`
- `pharmacist-manabi-sprint/content/product/final-audit-v2.json`
- `pharmacist-manabi-sprint/content/product/web-static-audit.json`

問題数を見かけ上増やすための複製・言い換え水増しは禁止。公式正答・採点除外・複数正答の状態を崩さない。

### AppIcon
- Drive：`05_薬剤師国家試験.png`
- Drive file ID：`1Au-Es7rxAyLxuGCzySTDsE-DXLWTwTtu`
- GitHub asset：`pharmacist-manabi-sprint/ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- SHA-256：`dfc7dfe4a1c13afbe98658cde591274e11665b016c39e2a4411de4dbe86127ec`
- 1024x1024 / RGB / alphaなし

## 監査証跡
- `content/product/ios-preflight-report.json`
  - pass: true
  - simulatorBuildExit: 0
  - workflowRunId: 31304173464
- `content/product/release-preflight-static.json`
  - pass: true
  - errors: []
  - warnings: []
- `metadata/RELEASE_STATUS.md`
- `metadata/RELEASE_CHECKLIST.md`
- `metadata/APP_STORE_METADATA_JA.md`
- `metadata/APP_PRIVACY_AND_RIGHTS.md`

## Codexが最初に確認すること
```bash
cd <repo-root>
python3 pharmacist-manabi-sprint/scripts/validate_release.py
```
PASSしなければTestFlightへ進まない。

次に以下を確認する。
- `git status` が意図しない変更なし
- `pharmacist-manabi-sprint/ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` のSHA一致
- root `codemagic.yaml` の `pharmacist-ios` が `submit_to_testflight: true` / `submit_to_app_store: false`
- Bundle ID / Product IDが固定値と一致

## 現在ユーザー本人に必要な操作
1. Apple DeveloperでExplicit App ID `jp.allsunday1122.yakuzaishi` を登録または確認
2. App Store Connectに新規Appを作成
   - SKU：`yakuzaishi-sprint-ios`
3. Paid Apps Agreement、税務、銀行情報を必要に応じて有効化
4. Subscription Group「薬剤師国家試験 プレミアム」を作成
5. 月額 `jp.allsunday1122.yakuzaishi.monthly`
   - Auto-Renewable Subscription
   - Duration: 1 month
   - Introductory Offer: Free Trial 1 week
   - 価格はApp Store Connectで設定。コードへ固定価格を書かない
6. 買い切り `jp.allsunday1122.yakuzaishi.lifetime`
   - Non-Consumable
   - 価格はApp Store Connectで設定
7. 両商品のローカライズ・Review Screenshotを登録
8. Codemagic App Store Connect integration `codemagic` とApp Store signingを確認

## 本人操作完了後にCodexが実行する次の大きなループ
1. Apple/App Store Connect設定とrepo固定値の一致確認
2. `validate_release.py` 再実行
3. Codemagic `pharmacist-ios` を署名付きで実行
4. Internal TestFlightへの到着を確認
5. Build processing / export compliance / IAP商品取得エラーを確認し、コード側問題なら修正
6. TestFlight実機確認用チェックリストをユーザーへ提示
7. ユーザー実機結果を受けて不具合修正
8. 全項目PASS後、App Store提出前監査まで進める
9. **Add for Review / Submit for Reviewはユーザーの明示承認があるまで実行しない**

## TestFlight実機確認
`metadata/RELEASE_CHECKLIST.md`を正本として使用する。最低限以下を確認。
- 起動・クラッシュなし
- 無料状態は第111回必須90問のみ
- 4 / 8 / 16問スプリント
- 中断→続きから
- 苦手3連続正解で卒業
- 達成度・35マスヒートマップ
- 月額価格がStoreKit表示価格
- 7日無料はeligible時のみ表示
- 月額購入 / cancel / pending
- 買い切り購入
- 購入復元
- 再起動後の権利維持
- Premiumで1,031問・9区分解放
- サブスクリプション管理
- 機内モードで教材・記録利用
- 横はみ出し・レイアウト崩れなし

## STOP条件
Codexは以下を勝手に突破しない。
- Apple IDログイン、2FA、本人確認
- 契約 / 税務 / 銀行情報の確定
- 有料商品の最終価格決定
- TestFlightでのユーザー実機合否
- App Store提出最終承認
- 本審査送信

## Codexへの最初の指示文
「`pharmacist-manabi-sprint/metadata/CODEX_HANDOFF.md` を正本として読み、Notionの薬剤師国家試験｜学びスプリント正本も確認してください。既に完了しているWeb/UI/問題バンク/iOS製品化を作り直さず、現在の停止地点から再開してください。まずrelease preflightを再確認し、Apple Developer / App Store Connect / Codemagicの本人操作が未完なら、その項目だけをユーザーに返してください。本人操作済みなら `pharmacist-ios` でInternal TestFlightまで進め、App Store本審査には送信しないでください。」
