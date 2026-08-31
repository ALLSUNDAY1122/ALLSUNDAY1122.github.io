# APP2-007｜危険物乙4｜720問・試験回別6回・Internal TestFlight

完了判定: **DONE（機械工程）**
確認時点: 2026-08-23 21:47 JST
Worker: OTSU4

## Task要件
2026-08-19追加要件:
1. ホームで分野別／試験回別を選択可能にする
2. 問題銀行を360→720問へ倍増
3. 試験回別を第1〜6回へ拡張
4. Content Audit→小型/大型iPhone Unit/UI XCTest→新署名Build 3以降→Internal TestFlight
5. App Store本審査提出は禁止

## 実装結果
- 最終720問
  - 法令 288
  - 物理・化学 192
  - 性質・消火 240
- 無料72問（法令29 / 物化19 / 性消24）
- ホーム `分野別 / 試験回別` 切替を実装
- 試験回別 第1〜6回、各35問
- 無料: 第1回 / Premium: 第1〜6回
- 模擬試験 6回 × 35問 / 120分
- 各回 法令15 / 物化10 / 性消10
- 合格判定 各科目60%以上
- 模試210問は全件重複なし

## Content / Difficulty Gate
- exact question duplicate: 0
- duplicate learning objective: 0
- duplicate explanation package: 0
- anti-padding: 0
- knowledge-free elimination risk: 0
- answer-length cue risk: 0
- difficulty 2: 216
- difficulty 3: 504

## 最新製品Gate
PR #4069: Draft維持
Product head: `d00abdc7ea7160f2a923e7ac2395594a5dd06cfb`

GitHub Actions:
- Otsu4 Content Audit run `32627298558`: **PASS**
- Otsu4 Native Typecheck run `32627298608`: **PASS**
- Otsu4 Release Foundation Lint run `32627298571`: **PASS**
- Otsu4 Xcode Build run `32627298621`, retry job `97194336213`: **PASS**

Xcode最終step:
- Release Simulator Build: PASS
- 720問bundle / 288-192-240 / canonical identifiers: PASS
- small / large iPhone simulator boot: PASS
- Native Unit Test: PASS
- small / large iPhone UI Test: PASS
- canonical AppIcon SHA: PASS

初回Xcode attemptはUnit Test工程のGitHub Actions 10分上限timeoutで終了したがassertion failureではない。同一headを再実行して全工程PASS。

## 署名IPA / App Store Connect
固定識別情報:
- Bundle ID `jp.allsunday1122.otsu4`
- App Store Connect App ID `6799755566`
- Version `1.0.0`
- IAP `jp.allsunday1122.otsu4.premium`
- AppIcon SHA-256 `d0cb19b237ca3306413c481e4fbc0fb871705b390a1bc37619d9683fff19ff2d`

最終署名Build:
- Codemagic build ID `6a8aa41c819174d676937dcf`
- Version / Build: **1.0.0 (93)**
- signed IPA内720問 / 288-192-240 / Bundle ID / PrivacyInfo / Assets / mobileprovision / CodeSignature: **PASS**
- Apple Build resource ID `626fdeb4-1712-4e8d-9d01-3394b1144c6d`

## Internal TestFlight readback
Internal group `sun`: `9cd34e64-9d08-4203-a27d-cb9d2e661c96`

Apple/Codemagic readback:
- Build 93: TestFlight反映済み
- `internalBuildState = IN_BETA_TESTING`
- `externalBuildState = NOT_APPLICABLE`
- `autoNotifyEnabled = true`
- `sun`からBuild 93へアクセス可能: **PASS**

配布安全設定:
- `testFlightInternalTestingOnly: true`
- `submit_to_testflight: false`（外部ベータ審査へ送らない）
- `submit_to_app_store: false`

## 正本同期
- Notion台帳: `公開準備` / Build 93 Internal TestFlight・実機受入待ちへ更新
- Notion開発正本: 720問 / Build 93 / sun readbackを追記
- PR #4069: `[INTERNAL TESTFLIGHT READY / DEVICE QA PENDING]`へ更新、Draft維持

## 安全条件
- App Store本審査: **未提出**
- 外部TestFlightベータ審査: **未提出**
- PR merge: **未実施**
- 実機受入前にアプリ全体を完成扱いしない
- secret / token / .p8をEvidenceへ保存していない

## 結論
APP2-007で要求された人間判断不要な工程は完了。720問化、分野別／試験回別、第1〜6回、全Content/Native/Xcode Gate、新署名Build 93、App Store Connect/Internal TestFlight `sun`配布readbackまで成立した。

残るのはiPhone実機での最終受入のみ。Build 93で主要UI、分野別3科目、試験回別1〜6、模試6回、購入成功/cancel/pending/restore/再インストール後entitlement、VoiceOver等を確認する。実機PASS後のみApp Store本審査へ進む。

---

## 2026-08-31｜ユーザー本申請承認後の追加Release工程
ユーザーから明示的に「本申請まで進めて」「全部やって」の承認を受け、旧Taskの本審査禁止Gateを解除して追加Release工程を実施。

### 現行App Store候補
- Version: **1.0**（Apple canonical display）
- Build: **94**
- Build resource: `19650d9a-f2e2-4ce9-b135-2fba143f678b`
- `processingState = VALID`
- `buildAudienceType = APP_STORE_ELIGIBLE`
- 旧Build 93の `INTERNAL_ONLY` 制約を解消したApp Store候補IPA。

### Store / IAP提出前整備
- Copyright: `2026 ALLSUNDAY1122` read-back PASS
- アプリ本体価格: JPN基準 **0円**。Review Submissionサーバー検証で `APP_PRICING_REQUIRED` が消失したことを確認。
- IAP `jp.allsunday1122.otsu4.premium`
  - Non-Consumable
  - 800円
  - 日本販売
  - 日本語表示名・説明
  - IAP審査用スクリーンショット COMPLETE
- App Store公開用スクリーンショット6枚 COMPLETE
- 説明 / キーワード / Support URL / Privacy Policy URL / 年齢区分 / Review連絡先・Notes: 設定済み

### 2026-08-31 最終Review Submission検証
Run `33382774372` でBuild 94 + App Version + 初回IAPの審査追加を検証。

Apple associatedErrors は **App Privacyだけ**:
- `STATE_ERROR.APP_DATA_USAGES_REQUIRED`
- `You must have published answers to your app's data usages.`

Copyright・価格など従来のassociatedErrorsは解消済み。

### App Privacy自動化の到達限界を実証
本アプリの実装監査では、アカウント登録・広告・行動解析・トラッキングを行わず、学習履歴は端末内保存。正しい回答は **「データを収集しない / DATA_NOT_COLLECTED」**。

自動化経路を以下まで確認:
1. App Store Connect公式JWT API
   - `appDataUsages` / `appDataUsageDataProtections` / `dataUsagePublishState` はすべて404 PATH_ERROR
   - App Privacy回答のwrite/publish APIは公開されていない。
2. Fastlaneが使うApp Store Connect内部 `iris` API
   - `DATA_NOT_COLLECTED` 作成およびPublish endpointの存在はFastlane実装で確認。
   - 現在保有するASC API Key JWTではHTTP 401。Apple ID Web Sessionが必要。
3. GitHub Actions secrets存在監査
   - `FASTLANE_SESSION` / `FASTLANE_USER` / `APPLE_ID` / `APP_STORE_CONNECT_USERNAME` / `FASTLANE_PASSWORD` / application-specific password はすべて未登録。

### 現在の唯一のHUMAN_REQUIRED
App Store Connect UIの「アプリのプライバシー」で以下を一度だけ公開する:
- 「いいえ、このアプリからデータを収集しません」
- 保存
- 公開
- 確認ダイアログでも公開

このUI公開後、mainの `.github/workflows/app2-007-otsu4-final-submit-normalized.yml` は、余計なPrivacy API再試行を行わず、Appleの審査Gateを再検証してBuild 94 + 初回IAPを同一Review Submissionに追加し `submitted=true` を実行する。

完了条件は `review_submission_state = WAITING_FOR_REVIEW / IN_REVIEW / COMPLETING / COMPLETE` のread-back。

現時点のApp Store本審査状態: **未提出（App Privacy UI公開のみ待ち）**。
