# 開発連番#11｜v2.4継続チェックポイント

更新: 2026-08-14

## 確定済み

- 標準手順 v2.4 適用。
- Bundle ID: `jp.allsunday1122.yobishikentantou`。
- 課金: Auto-Renewable Subscription、月額200円基準。
- planned IAP Product ID: `jp.allsunday1122.yobishikentantou.monthly`。
- App Store Connect実登録確認まではruntime Product IDを未設定にしてfail-closed。
- Source Contract #361 PASS。
- Swift Validation #32 PASS（XCTest / XCUITest / unsigned Release build）。
- practice-mock-1: 法律95＋一般教養44＝139/139完成。
- 正式監査済み総数の確定チェックポイント: 167/417。

## practice-mock-2 作成済み・監査進行中

### 一般教養 44題

4カテゴリ×11題の候補を作成済み。

- `practice-mock-2-general-quantitative-01`
- `practice-mock-2-general-natural-science-01`
- `practice-mock-2-general-social-data-01`
- `practice-mock-2-general-language-01`

品質方式:

`self-authored candidate → schema/rights → deterministic answer recomputation → global uniqueness → editorial quality → release_passed`

公式問題本文・実在統計・第三者文章を使用しない。設問内fixtureだけから正答を再計算する。

監査改善:

- percentage point と percent を単位意味まで区別。
- 増加・低下の語義を符号として検証。
- 誤答理由の部分修正専用fail-closed overrideを追加。

### 法律 batch-01 14題

- 憲法42・44条
- 行政手続法7・8条
- 民法113・121条
- 会社法349・362条
- 民事訴訟法135・136条
- 刑法38・60条
- 刑事訴訟法30・39条

候補・2026-01-01 source locks・answer audit・distractor auditを作成済み。

### 法律 batch-02 14題

- 憲法45・46条
- 行政手続法9・10条
- 民法145・146条
- 会社法350・356条
- 民事訴訟法179・180条
- 刑法41・42条
- 刑事訴訟法40・41条

候補・2026-01-01 source locks・answer audit・distractor auditを作成済み。

## 件数の扱い

上記practice-mock-2追加72題は、GitHub Actionsで `release_passed` がbranch正本へ固定されるまで167/417へ加算しない。

全72題がPASSした場合の次チェックポイントは239/417ではなく、mock2 seed14を既に167へ含めているため **239/417** となる。

- mock1 139
- mock2 seed14 + general44 + legal28 = 86
- mock3 seed14
- total 239
- remaining 178

## 次の自動工程

1. General Education Bank PipelineをPASSまで修正。
2. Mock Bank Pipelineでlegal batch-01/02を2026-01-01 e-Gov exact-date監査。
3. FAIL markerは閾値を緩めず実表記へ修正。
4. 高類似FAILは設問能力を変更し、editorial overrideで上流から再監査。
5. PASS済みreleaseファイルだけをpractice-mock readinessへ加算。
6. practice-mock-2法律残り53題を追加し139/139へ進める。
7. practice-mock-3へ移行。

人間判断が必要になるまでは停止しない。App Store Connect Apple ID等Apple実発行値は推測せず、実際に作成工程へ到達した時点で正本化する。
