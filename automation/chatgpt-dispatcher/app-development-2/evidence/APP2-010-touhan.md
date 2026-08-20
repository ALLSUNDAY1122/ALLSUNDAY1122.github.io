# APP2-010｜登録販売者｜App record反映とTestFlight準備

- Worker: `TOUHAN`
- Session: `登録販売者③`
- Result: `READY`
- Date: `2026-08-20 JST`
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- App Store review submission: **NOT PERFORMED / PROHIBITED**
- External TestFlight Beta Review: **NOT PERFORMED / PROHIBITED**

## 1. 正本識別情報

- Bundle ID: `com.allsunday1122.tourokuhanbaisha`
- App Store Connect App ID: `6802119268`
- Apple Team ID: `MN3D2ZM44N`
- Version: `1.0.0`
- Codemagic app id: `6a769d81a1add9d06020b524`
- workflow: `touhan-ios`
- Apple Distribution certificate: `K2A3VCP583`
- App Store provisioning profile: `7B328C2DU4` / ACTIVE

## 2. Build #10 / Internal TestFlight

Build #10 (`1.0.0 (10)`, Codemagic `6a861f2e68c24c24844d3f66`) は署名IPA生成・App Store Connect uploadを完了。

- Apple build id: `d59a0d3d-5aeb-455d-ba9a-cfb193b9a84c`
- `processingState = VALID`
- `buildAudienceType = INTERNAL_ONLY`
- export compliance: `usesNonExemptEncryption=false`
- `internalBuildState = IN_BETA_TESTING`
- internal group: `sum`
- tester state read-back: `INVITED`
- userのiPhone TestFlightで実際に起動し、問題画面表示まで到達したことを2026-08-20に確認。

Evidence:
- `automation/asc-results/app2-010-compliance-route-20260820-2010.json`
- `automation/asc-results/app2-010-invite2-20260820-2016.json`
- `automation/codemagic-results/app2-010-upload-log-build10-20260820-0637.txt`

Build #9以前は有効な登録販売者TestFlight Buildではない。

## 3. 360問 難易度・選択肢品質監査

TestFlight実機で `RS26-001` が「知識なしでも極端な誤答を消去して正解できる」問題であることをユーザーが指摘。これを単発修正せず、第1回・第2回・第3回を各120問単位で全360問目視監査した。

判定基準:
- A: 本試験相当。知識・識別が必要。
- B: 使用可能だが易しめ。
- C: 易しすぎ。改稿対象。
- D: 常識・文体・極端語・無関係肢で解ける。全面改稿対象。

### 第1回 120問
- A 14
- B 18
- C 46
- D 42
- C+D: **88 / 120 (73.3%)**

Evidence:
`automation/audits/app2-010-touhan-exam1-manual-difficulty-audit.md`

### 第2回 120問
- A 19
- B 23
- C 38
- D 40
- C+D: **78 / 120 (65.0%)**

Evidence:
`automation/audits/app2-010-touhan-exam2-manual-difficulty-audit.md`

### 第3回 120問
- A 14
- B 21
- C 50
- D 35
- C+D: **85 / 120 (70.8%)**

Evidence:
`automation/audits/app2-010-touhan-exam3-manual-difficulty-audit.md`

### 360問総合
- A: **47**
- B: **62**
- C: **134**
- D: **117**
- C+D: **251 / 360 = 69.7% 改稿対象**
- A+B: 109 / 360 = 30.3%

Overall evidence:
`automation/audits/app2-010-touhan-360-manual-difficulty-summary.md`

## 4. 横断的に確認した欠陥

1. 誤答へ `必ず / すべて / 一切 / 不要 / 起こらない / 無制限` を多用し、常識で落とせる。
2. 正答だけが長く自然な条件付き文で、文体から正解推測できる。
3. 肝臓の問題に「音を感じる」、唾液の問題に「尿・酸素・血液凝固」など同一論点で競合しない誤答がある。
4. 成分重複問題に「箱の色・価格」、副作用報告情報に「好きな色・商品棚」等、専門知識と無関係な選択肢がある。
5. 受診勧奨問題が「受診」対「倍量・無視・長期継続」になり、専門知識を要求しない。
6. 単純な `成分名→用途` / `器官→機能` 一問一答が多く、複数知識の同時判定が不足。

## 5. 次工程

現時点に真正な人間gateはない。問題品質は機械的に改修可能なため `READY` とする。

次の実装単位:
1. D 117問を全面再作問。
2. C 134問は正答テーマを再利用可能でも、誤答肢を全面再設計。
3. B 62問を近接概念で難化。
4. A 47問も法令・正答・表現を再確認。
5. 各120問の40〜60問を a〜d 複数記述正誤組合せ型へ移行。
6. 改稿後、各120問ごとに再監査し C+D 20%以下をRelease Gateとする。
7. 360問の新品質Gate PASS後のみ新しい署名Buildを作成しInternal TestFlight再受入する。

## 6. 現在判定

**Build #10はInternal TestFlight経路の技術検証用として有効だが、問題品質の受入Buildとしては失効。**

App Store本審査submit/releaseは実行しない。
