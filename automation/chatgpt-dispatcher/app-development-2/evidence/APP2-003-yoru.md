# APP2-003｜夜の書架｜次セッション引き継ぎ

更新: 2026-08-28 01:25 JST
Worker: YORU
対象App: 夜の書架
App Store Connect App ID: `6794137637`
Bundle ID: `io.github.allsunday1122.yorunoshoka`
対象repo: `ALLSUNDAY1122/yoru-no-shoka`
対象branch: `main`

> このファイル・会話履歴・過去結果は開始点であり正本ではない。開始時および各「次」で Notion / GitHub / App Store Connect / Codemagic をfresh readすること。

## 現在状態｜2026-08-28 01:25 JST

- Pattern C「紙面・温かみ」はmainへ統合済み。
- 現行テスト対象は `1.2.0 / Build 4`。
- Codemagic App ID: `6a8af6e5a5c86907b00c2efd`
- 成功Build ID: `6a903f4e0b744f0115921f39`
- 成功commit: `0b2977ff436c76da013cb9d1201a20906f2e3c6f` (`Fix APP2-003 signing project scope`)
- Codemagic status: `finished`
- `App.ipa` 生成成功、size `12,809,170 bytes`、version `1.2.0`、build `4`
- App Store Connect Build resource: `bb60e27a-1888-4e74-8e09-e4924ffeebb1`
- Apple processingState: `VALID`
- buildAudienceType: `INTERNAL_ONLY`
- usesNonExemptEncryption: `false`
- App Store Version `1.2.0`: `PREPARE_FOR_SUBMISSION`
- Review Submission: 0件

## 今回解消したblocker

1. Corepack / pnpm署名不整合
   - Corepackを使わず `npm install --global --force pnpm@11.9.0` へ変更済み。
2. iOS署名private key不足
   - 既存Apple Distribution証明書 `B4WRC3G6V4` とprofile `6598LFYDY3` を安全に利用できる状態へ復旧済み。
3. `xcode-project use-profiles` の対象過多
   - `ios/SchemeIndex.xcodeproj` まで自動探索して失敗していた。
   - `--project "$CM_BUILD_DIR/$XCODE_PROJECT"` を明示し、`ios/App/App.xcodeproj` のみに限定して解消。

## Build 4実バイナリPrivacy監査｜2026-08-28 01:25

Codemagic artifactから実際の `App.ipa` を取得し、構造化監査した。

- `Payload/App.app/PrivacyInfo.xcprivacy`
- `Payload/App.app/Frameworks/Capacitor.framework/PrivacyInfo.xcprivacy`
- `Payload/App.app/Frameworks/Cordova.framework/PrivacyInfo.xcprivacy`

3 manifestすべて:
- `NSPrivacyTracking = false`
- `NSPrivacyTrackingDomains = []`
- `NSPrivacyCollectedDataTypes = []`
- `NSPrivacyAccessedAPITypes = []`

実IPA `Info.plist`:
- `CFBundleIdentifier = io.github.allsunday1122.yorunoshoka`
- `CFBundleShortVersionString = 1.2.0`
- `CFBundleVersion = 4`
- `MinimumOSVersion = 15.0`
- `ITSAppUsesNonExemptEncryption = false`

よって現行ASCの「データ収集なし」およびexport complianceと矛盾する証拠は実バイナリ上も確認されない。

## 重要な判定

Build 4はInternal TestFlight確認用として成功している。ただし `buildAudienceType=INTERNAL_ONLY` のため、App Store本審査用Buildとしては使用できない。

したがって現在の正しい工程は:
1. ユーザーがiPhoneのTestFlightでBuild 4 / Pattern Cを実機受入
2. PASSなら本審査用Build 5以降を `APP_STORE_ELIGIBLE` で生成
3. Pattern C現UIスクリーンショットへ差し替え
4. Privacy / Age Rating / Review Notes / Review contact / DSAをfresh audit
5. App Store Versionへ本審査用Buildをattach
6. 最終 `Add for Review / Submit for Review` はユーザー承認後のみ実行

## 真正な人間Gate

現時点で必要なのは **Build 4のiPhone TestFlight実機受入**。

確認項目:
- 起動できる
- ホームで主CTA「今夜の一話を読む」が明確
- 紙面 / 深いセピア / 漆黒テーマ切替
- 明るさ70–120%
- 本文文字サイズ / 行間 / 明朝・ゴシック切替
- シリーズ / 話者ガイドが理解できる
- 書架から各作品を読める
- 検索 / 怖さ / 長さ / シリーズ絞り込み
- 保存済み / 読了状態
- 読書進捗バー
- 戻る / タイトル / Aa / その他メニューの操作性
- 重大な表示崩れ、白画面、クラッシュがない

## 署名資産｜2026-08-28 01:19 fresh read

- Bundle resource ID: `K459HXU63D`
- Bundle identifier: `io.github.allsunday1122.yorunoshoka`
- Profile ID: `6598LFYDY3`
- Profile state: `ACTIVE`
- Profile type: `IOS_APP_STORE`
- Certificate ID: `B4WRC3G6V4`
- Certificate type: `IOS_DISTRIBUTION`
- Certificate expiration: `2027-07-24T14:20:41Z`

新しいApple Distribution証明書を推測で発行/revokeしない。

## Review Notes

Pattern C向けReview Notes文面は確定済み。ただし新設した専用Issue-trigger workflowが実行登録されないため、現ASCは旧Notesのまま。これは提出blockerではなく、最終提出前に既存の安定したwrite経路へ統合して更新する。Review Notes更新のためだけに共有Gatewayを危険に変更しない。

## 禁止事項

- Codexは使わない。
- secret/token/.p8/private keyをGitHub/Notion/evidence/logへ保存しない。
- Build 4をApp Store本審査用として誤認しない。
- 旧Pattern C前スクリーンショットを現UI証拠としてPASSしない。
- `Add for Review / Submit for Review` をユーザー最終承認なしで実行しない。

## Queue判定

APP2-003は `HUMAN_REQUIRED` が正しい。旧blockerではなく、真正な人間Gateである「Build 4 TestFlight実機受入」待ちとして扱う。
