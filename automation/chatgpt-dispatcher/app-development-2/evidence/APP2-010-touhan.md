# APP2-010｜登録販売者｜360問品質改稿後 Internal TestFlight 受入

- Worker: `TOUHAN`
- Session: `登録販売者④`
- Result: `HUMAN_REQUIRED`
- Date: `2026-08-23 JST`
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- App Store review submission: **NOT PERFORMED / PROHIBITED**
- External TestFlight Beta Review: **NOT PERFORMED / PROHIBITED**

## 1. 正本識別情報

- Bundle ID: `com.allsunday1122.tourokuhanbaisha`
- App Store Connect App ID: `6802119268`
- Apple Team ID: `MN3D2ZM44N`
- Version: `1.0.0`
- Codemagic app id: `6a769d81a1add9d06020b524`
- Codemagic workflow: `touhan-ios`
- iOS wrapper source: `touroku-hanbaisha-ios/native-ios/Sources/TouhanSprintApp.swift`
- Runtime web source: `https://allsunday1122.github.io/touroku-hanbaisha-sprint/`
- Question JSON fetch: `cache: no-store`

## 2. 360問品質改稿と最終Gate

旧360問の手動監査では C+D が 251/360 (69.7%) あり、知識なしでも消去可能な誤答、極端語、無関係肢、単純一問一答が多かったため、問題銀行を全面的に再設計した。

2026-08-23 最終監査:
- 全360問 = 3回 × 120問
- 難易度: `B=252`, `B-=108`, `C/D=0`
- 完全重複: `0`
- 高類似重複: `0`
- 第1回 正答位置: `24/24/24/24/24`
- 第2回 正答位置: `24/24/24/24/24`
- 第3回 正答位置: `22/25/26/23/24`
- 出典: MHLW 354問 / PMDA 6問
- Final Gate: **PASS**

Evidence:
- `automation/audits/app2-010-360-final-audit.json`
- `automation/audits/app2-010-360-final-audit.md`
- final audit commit: `7a7640bf7fa7ea950036f9c99e664781c3129f9f`
- Exam 3 finalize commit: `a6c18698acab9fe19966b7d58eb1bac7cc0bd7ac`
- Exam 1 answer rebalance commit: `6c0d5d288f090cf989cd62229e9eadfd2bf7e1d8`

第4章の法規は2026年5月1日施行内容を含め現行制度へ合わせて再確認済み。

## 3. Build #10 の扱い

Build #10 (`1.0.0 (10)`) は署名・ASC upload・Internal TestFlight経路の技術確認には有効だったが、問題品質Gate前のため**品質受入Buildとして失効**。

## 4. 品質Gate後 Build #11

360問Gate PASS後、mainから新しい署名Buildを作成した。

Codemagic:
- request: `APP2-010-TFLIGHT-360-GATEPASS-20260823-1724`
- build id: `6a8aae11008962a6f19d1bf7`
- build index: `11`
- version: `1.0.0`
- status: `finished`
- signed IPA: `TouhanSprint.ipa`
- Build signed IPA: success
- Publishing: success

Evidence:
- `automation/codemagic-results/APP2-010-TFLIGHT-360-GATEPASS-20260823-1724.json`

App Store Connect read-back / Internal TestFlight:
- Apple Build ID: `47c9a0eb-f0e1-45ec-a4f3-3c4fd963ce74`
- Build number: `11`
- `processingState = VALID`
- `expired = false`
- `buildAudienceType = INTERNAL_ONLY`
- `usesNonExemptEncryption = false`
- `internalBuildState = IN_BETA_TESTING`
- internal group: `sum`
- `hasAccessToAllBuilds = true`
- Build assigned: `true`
- tester count: `1`
- tester state read-back: `INSTALLED`
- App Store review submitted: `false`
- External Beta Review submitted: `false`

Evidence:
- `automation/asc-results/app2-010-build11-route-20260823-1802.json`
- route trigger commit: `5532c98372230f8ffa6c0c2e333a5a23cc7a4196`

## 5. 残る真正なHuman Gate

機械側の実装・品質監査・署名・ASC upload・Internal TestFlight配布までは完了。

残件は**ユーザー実機でBuild 11を受入確認することのみ**。

受入条件:
1. TestFlightで `1.0.0 (11)` を開ける。
2. ホームで全360問 / 3試験回が表示される。
3. 第1〜3回から代表問題を開き、旧版の知識不要な極端誤答ではなく改稿後問題が表示される。
4. 回答・解説・次問題への遷移が正常。
5. 学習履歴カレンダーが学習後に更新される。
6. 白画面・読込エラー・操作不能がない。

ユーザーが実機で `問題なし` を確認した時点で APP2-010 を `DONE` に移行可能。

## 6. 現在判定

**HUMAN_REQUIRED — Build #11 Internal TestFlight実機受入のみ残存。**

App Store本審査submit/releaseは実行しない。
