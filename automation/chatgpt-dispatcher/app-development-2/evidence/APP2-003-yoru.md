# APP2-003｜夜の書架｜完了証拠

更新: 2026-08-28 13:46 JST
Worker: YORU
対象App: 夜の書架
App Store Connect App ID: `6794137637`
Bundle ID: `io.github.allsunday1122.yorunoshoka`
対象repo: `ALLSUNDAY1122/yoru-no-shoka`
対象branch: `main`

> このファイル・会話履歴・過去結果は開始点であり正本ではない。再開時は Notion / GitHub / App Store Connect / Codemagic をfresh readすること。

## 最終状態｜2026-08-28 13:46 JST

- Pattern C「紙面・温かみ」はmainへ統合済み。
- Build 4は実機UX不具合5点でFAIL。
- Build 5は修正コードがnative iOS entrypointへ接続されておらず、ユーザー実機で「何も解決していない」と判定されFAIL。
- native entrypointを修正し、生成native bundleと完成IPAそのものを検査するGateを追加した。
- Internal TestFlight `1.2.0 / Build 6` をユーザーが2026-08-28に実機確認し、**「問題なし」＝物理受入PASS**。
- ユーザーが続けて **「本申請して」** と明示承認。
- 同一source commitから本審査用 `1.2.0 / Build 7` を生成し、App Store Connectへ提出済み。
- App Store Version `1.2.0`: **WAITING_FOR_REVIEW**
- Review Submission: **WAITING_FOR_REVIEW**
- Release type: **MANUAL**。審査承認後の公開操作は今回の承認範囲に含めず、自動公開していない。

## Build 6｜Internal TestFlight physical PASS

- Codemagic Build ID: `6a9105fde0c3191da504c2c7`
- source commit: `0083095e354fb96a22afadba8a7f174bc5dc8220`
- ASC Build resource: `e831d8cf-fa07-463f-b948-c891e1554902`
- processingState: `VALID`
- buildAudienceType: `INTERNAL_ONLY`
- ユーザー実機受入: **PASS**

Build 4/5で報告された対象不具合:
1. 読むときに話の途中位置から表示される。
2. 話によって本文スクロールできない。
3. 読書途中に前画面／ホームへ戻りにくい。
4. 書架の検索・絞り込みUIがstickyで残る。
5. 「この話を読む」CTAが見えにくい。

Build 6 corrective layer:
- `native/main.tsx` から `ReaderRuntimeGuards` と `pattern-c-fixes.css` を実読込。
- Reader mount／作品切替でscroll positionを先頭へ再同期。
- iOS/WKWebView向け縦スクロールを明示。
- Reader toolbarを常時fixed化し、戻る導線を本文位置から独立。
- `.library-tools` のstickyを廃止。
- 「この話を読む」を主要CTAとして強化。

## Build 7｜App Store review candidate

- Codemagic Build ID: `6a910f0cfcbd73331ec99411`
- source commit: `0083095e354fb96a22afadba8a7f174bc5dc8220`
- IPA: version `1.2.0`, build `7`, 約12.8MB
- ASC Build resource: `b0fece05-6994-4602-afd5-17c3bdd69cee`
- processingState: `VALID`
- buildAudienceType: `APP_STORE_ELIGIBLE`
- `usesNonExemptEncryption=false`
- Minimum iOS: 15.0

### Build 7 native IPA proof

完成IPA `Payload/App.app/public` を直接監査し、Build 6と同じ修正レイヤーを確認済み。

- JS marker: `app2-003-reader-fixes-v3`
- CSS marker: `app2-reader-fixes-v3`
- scoped selectors:
  - `html.app2-reader-fixes-v3.reader-overlay`
  - `html.app2-reader-fixes-v3.reader-toolbar`
  - `html.app2-reader-fixes-v3.library-tools`
  - `html.app2-reader-fixes-v3.story-card.story-read-button`
- `all_scoped_selectors_present=true`

Privacy:
- app / Capacitor / Cordova の3 `PrivacyInfo.xcprivacy` を確認。
- `NSPrivacyTracking=false`
- Tracking Domains / Collected Data Types / Accessed API Types は空。
- `ITSAppUsesNonExemptEncryption=false`

## Submission metadata audit

- App Store Version ID: `812cd84c-3efb-407b-a04c-f9fb1b5554e6`
- Japanese localization ID: `bd9192c2-e28a-43d6-abf5-0345f5a4b694`
- Review detail ID: `630be79a-3c94-4c4b-8882-6644d165152e`
- AppInfo ID: `b681848e-808d-4d80-83a7-4a6a61610417`
- Age rating declaration: present
- Privacy Policy URL: present
- Review contact: required fields present
- Demo account: not required
- iPhone 6.5-inch screenshots: 4枚すべて `COMPLETE`
- Review Notes: 最終内容をwrite + read-back済み

`whatsNew` は現在Apple APIがSTATE_ERRORで編集不可だったため、推測で破壊的操作は行わなかった。提出必須Gateではブロックせず、実際のReview Submission作成・提出は成功した。

## App Review submission

- Review Submission ID: `be8d6f15-4ffe-409c-8078-3f3b331ba4bb`
- submittedDate: `2026-08-28T04:42:53.162Z`
- Review Submission state: **WAITING_FOR_REVIEW**
- App Store Version state: **WAITING_FOR_REVIEW**
- selected Build: `b0fece05-6994-4602-afd5-17c3bdd69cee` = Build 7
- selected Build processingState: `VALID`
- selected Build audience: `APP_STORE_ELIGIBLE`
- releaseType: `MANUAL`

独立post-submit read-backで上記を再確認済み。ReviewSubmissionItemは1件存在し `READY_FOR_REVIEW`。item単体の `/appStoreVersion` GETはApple API非対応で失敗したが、Version 1.2.0自身がWAITING_FOR_REVIEW、選択Build 7、Review Submission WAITING_FOR_REVIEWの3点で本申請成立を確認した。

## 署名資産

- Profile `6598LFYDY3`: ACTIVE / IOS_APP_STORE
- Certificate `B4WRC3G6V4`: IOS_DISTRIBUTION、expiration `2027-07-24T14:20:41Z`
- 既存資産を継続利用。新規発行・revokeなし。

## 結論

APP2-003で要求された修正→Internal TestFlight実機確認→本審査用Build生成→App Store Connect本申請まで完了。

現在Apple審査待ち。今回のTaskは **DONE** とする。
審査承認後の手動Releaseは別の真正な人間承認工程として残す。

## 禁止事項／再開時注意

- Codexは使わない。
- secret/token/.p8/private keyをGitHub/Notion/evidence/logへ保存しない。
- Build 4/5を再利用しない。
- Internal-only Build 6を本審査用として使わない。
- Apple審査承認後も、ユーザーの公開承認なしにmanual releaseしない。
