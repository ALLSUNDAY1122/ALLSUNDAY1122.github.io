# LS16-002｜REUSE_SCAN・要件・データ契約確定

- Task: `LS16-002`
- Project: 学びスプリント #16｜作業療法士国家試験
- Role: RESEARCH
- Researched: 2026-08-19 JST
- Dependency: `LS16-001=DONE`
- Decision: **READY_FOR_BUILD / HUMAN_REQUIREDなし**
- Scope: LS16-002のみ。LS16-003以降の実装は本Taskでは行わない。

## 1. 結論

作業療法士国家試験版は、学びスプリントの共通UI・共通学習エンジン・問題品質パイプラインを再利用し、作業療法士固有の試験構成・問題データ・資格設定のみを新規化する。

**確定値**

- UI最上位正本: Notion `【正本テンプレ】学びスプリント｜UI要件定義テンプレ v2.1｜添付Golden Master準拠`
- `app_path`: `sagyo-ryohoshi-sprint`
- preview path: `previews/sagyo-ryohoshi-sprint/`
- Bundle ID案: `jp.allsunday1122.sagyoryouhoushi`
- 本試験 raw 問題数: **200問/1回**
- セッション: **午前100 + 午後100**
- 通常構成: **一般160 + 実地40**
- app-defined rounds: **3**
- 完成問題バンク必要数: **600問**
- UI学習分野: 厚労省の現行一般問題8科目をそのまま採用
- 実地問題で許容する科目: 厚労省の現行実地問題5科目
- 科目別の固定問題数は**設定しない**。厚労省が問題ごとの公式科目ラベル/固定配分表を公表していないため、内部分類を公式配分と偽装しない。

## 2. 一次資料による試験構成

### 第61回の現行試験科目

厚生労働省「作業療法士国家試験の施行」は、筆記を一般問題と実地問題に区分している。

一般問題8科目:
1. 解剖学
2. 生理学
3. 運動学
4. 病理学概論
5. 臨床心理学
6. リハビリテーション医学（リハビリテーション概論を含む）
7. 臨床医学大要（人間発達学を含む）
8. 作業療法

実地問題5科目:
1. 運動学
2. 臨床心理学
3. リハビリテーション医学
4. 臨床医学大要（人間発達学を含む）
5. 作業療法

一次資料:
- https://www.mhlw.go.jp/kouseiroudoushou/shikaku_shiken/sagyouryouhoushi/

### 問題数・解答形式

厚生労働省が公開している最新のフル問題冊子（2026-08-19確認時点では第60回）は、作業療法士の午前・午後を別PDFで公開している。午前PDFの注意事項は「試験問題の数は100問」と明記し、1つ選択・2つ選択の双方を正式な解答形式として示す。午後も100問で、1回あたりraw 200問となる。

第61回合格発表では、作業療法士は一般問題1点、実地問題3点で、実地問題は120点満点。通常のraw構造では実地40問、残る一般160問である。第61回は採点除外等により一般問題の採点対象が158点満点まで減っているため、**raw slot数と採点対象点数は別フィールドで保持する**。

一次資料:
- 第60回問題・正答公開: https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/tp250428-08_09.html
- 第60回OT午前: https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp250428-09a_01.pdf
- 第60回OT午後: https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp250428-09b_01.pdf
- 第61回合格基準・採点除外: https://www.mhlw.go.jp/general/sikaku/successlist/2026/siken08_09/about.html

注: PDF screenshot取得を2回試行したが、使用ツール側でcache missとなった。そのためPDFについて視覚推論は行わず、厚労省PDFの抽出テキストに明記された100問・解答形式と、厚労省HTMLの合格基準を根拠にした。

### 現行出題基準

2026-08-19時点で厚労省が掲載する現行版は `令和6年版理学療法士作業療法士国家試験出題基準`。

一次資料:
- https://www.mhlw.go.jp/stf/shingi2/0000163627_00001.html
- https://www.mhlw.go.jp/stf/shingi/shingi-idou_127800_00002.html

## 3. rounds と必要問題数

`rounds` は国家試験制度の値ではなく、学びスプリントの商品仕様である。共通問題パイプライン v1.1 も `rounds` を資格ごとの設定値とし、3固定ではない。

本アプリは **rounds=3** を採用する。

根拠:
- #15 理学療法士が3回×200問=600問で完成しており、同じPT/OT国家試験体系の兄弟アプリとして再利用可能性が最も高い。
- 1 roundを本試験1回相当の200 slotとすることで、模試・問題品質監査・学習進捗を一貫させられる。
- 年間受験者約5千人規模のため、3 round以上へ無制限に拡張するより、まず600問を高品質に完成させる方が費用対効果に合う。

したがって:

`200 questions/round × 3 rounds = 600 questions`

roundは `R1/R2/R3` をcanonical IDとする。過去の第58〜60回等を構成参考に使う場合でも、公式本文の転載年と誤認させず、`reference_exam_round` を別フィールドで持つ。

## 4. REUSE_SCAN

| 資産 | 判定 | 取扱い |
|---|---|---|
| Notion UI Golden Master v2.1 | **REUSE** | 最上位UI正本。紙色、方眼、藍/朱/緑/金、明朝、最大幅520、4タブ、4/8/16問、○×、ここだけ覚える、5週ヒートマップ等を維持 |
| `native-ios/LearningSprintCore/` | **REUSE** | `LearningQuestion`、single/multi choice、`わからない`、弱点3連続解除、4/8/16選択、履歴、35日heatmap、分野正答率、試験日ペースを共通利用 |
| #15 `previews/rigaku-sprint/index.html` | **ADAPT** | LS16-003のブラウザMVP実装参考。資格名、問題、分野、保存key、プラン表示をOT用へ置換。Notion v2.1と矛盾する箇所はv2.1を優先 |
| #15 SwiftUI Root/AppModel/StudySession/Backup構造 | **ADAPT** | 将来Native実装で構造を再利用。`Rigaku*` 型名・識別子・PT固有分野は持ち込まない |
| #15 `product-content/exam-config.json` の200×3 frame、rights/scoring設計 | **REFERENCE** | 3×200、一般/実地分離、採点除外・複数正答・media rights分離の設計を参照。PTの科目別件数はOTへコピー禁止 |
| #15 PT問題600問・公式正答・分類値 | **REJECT** | PT固有コンテンツ。OTへ流用しない |
| #15 Bundle ID / SKU / Product ID / StoreKit商品 | **REJECT** | `rigakuryouhoushi` 固有。OTへコピーしない |
| #15 Support/Privacy/Terms本文 | **REFERENCE** | 構成のみ参考。資格名、価格、ID、データ処理をOT実状態で新規作成 |
| `automation/learning-sprint-question-pipeline/` のワークフロー思想 | **REUSE** | 重複、高類似、required fields、rights/source監査ループをそのまま使う |
| `validate_questions.py` 現行 `subjects:{name:count}` 強制 | **ADAPT** | OTでは公式科目別固定問題数を捏造しないよう、`question_type_counts` とsubject membershipを分離するv2 contractが必要 |
| OT `learning-sprint-audit.json` / exam frame / source ledger / question bank | **NEW_BUILD** | 本Taskで契約を定義し、後続Taskが作成 |
| OT preview / qualification config / OT Native adapter | **NEW_BUILD** | 共通UI/Coreを使い資格固有部分のみ作る |

### #15から直接再利用できる共通Core

現行branchの `native-ios/LearningSprintCore` はすでに:
- singleChoice / multiChoice / numeric等の回答型
- `isUnknown`
- 誤答/わからない→weak
- 3連続正解でweak解除
- 4/8/16問
- subject学習
- mock session
- 中断snapshot
- 35日heatmap
- subject accuracy
- exam date pace
を資格非依存で保持している。

#15 Draft PR #4139では複数許容正答 `acceptedIndexSets` への拡張も存在するが、Dispatcher branchの共通Coreには未反映である。OTの独自作問MVPでは必須ではない。公式採点調整を再現する段階で、必要なら共通Core側へ一般化して取り込む。#15 branch全体をコピーして依存させない。

参照:
- PR #4139: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/4139
- #15 config: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/blob/feat/15-rigaku-sprint-native/rigaku-sprint/product-content/exam-config.json
- 共通pipeline: `automation/learning-sprint-question-pipeline/`

## 5. OTデータ契約 v1

### `learning-sprint-audit.json`

後続実装で次の意味を固定する。

```json
{
  "qualification": "作業療法士国家試験",
  "app_path": "sagyo-ryohoshi-sprint",
  "bundle_id_candidate": "jp.allsunday1122.sagyoryouhoushi",
  "rounds": 3,
  "questions_per_round": 200,
  "sessions_per_round": {"am": 100, "pm": 100},
  "question_type_counts": {"practical": 40, "general": 160},
  "subjects": [
    "解剖学",
    "生理学",
    "運動学",
    "病理学概論",
    "臨床心理学",
    "リハビリテーション医学",
    "臨床医学大要",
    "作業療法"
  ],
  "practical_allowed_subjects": [
    "運動学",
    "臨床心理学",
    "リハビリテーション医学",
    "臨床医学大要",
    "作業療法"
  ],
  "similarity_threshold": 0.90,
  "questions_file": "data/questions.json"
}
```

`subjects` はUI/学習分類であり、固定件数mapにしない。各roundのsubject合計は200になればよいが、個別subject件数を公式値として強制しない。

### 1問題のcanonical schema

最低限:

```json
{
  "id": "OT-R1-AM-001",
  "round": 1,
  "session": "am",
  "slot": 1,
  "question_type": "practical",
  "subject": "作業療法",
  "topic": "上肢機能評価",
  "question": "独自作問本文",
  "choices": ["...", "...", "...", "...", "..."],
  "answer_type": "singleChoice",
  "answer": 0,
  "scoring_status": "normal",
  "explanation": "独自解説",
  "memory_point": "ここだけ覚える内容",
  "source_title": "一次資料名",
  "source_url": "https://...",
  "reference_date": "2026-08-19",
  "origin_type": "original_from_primary_source",
  "rights_basis": "一次資料に基づく独自作問",
  "requires_media": false,
  "reference_exam_round": 60,
  "reference_exam_slot": "AM-001"
}
```

解答型:
- 1肢選択: `answer_type=singleChoice`, `answer=<index>`
- 2肢選択: `answer_type=multiChoice`, `answer=[index,index]`
- 公式採点調整を構造参照として保持する場合: `scoring_status=excluded/all_correct/multiple_accepted/...`

rights:
- デフォルトは `original_from_primary_source`
- 第三者図版・写真・尺度表等を未許諾で収録しない
- `licensed_official` は利用根拠が問題単位で明確な場合だけ使用
- `source_url`, `reference_date`, `rights_basis` 欠損を最終PASS不可とする

## 6. pipeline v2適応要件

現行 `validate_questions.py` は `subjects` を `{科目名:件数}` として各roundで厳密一致させる。OTではこれをそのまま使うと非公式な科目配分を捏造するため、後続LS16-004で以下の構造監査へ適応する。

必須:
1. total = `rounds × 200 = 600`
2. roundごと total=200
3. roundごと `general=160`, `practical=40`
4. `session=am/pm` 各100
5. subjectは8科目allowlist内
6. practical subjectは5科目allowlist内
7. subjectごとの固定件数は要求しない
8. ID重複0
9. 独自問題の完全一致0、高類似0
10. source/rights/reference必須
11. single/multiChoiceのanswer検証
12. raw slotとscoring_statusを分離

最新公表問題の配置を参考にAM/PM各20実地+80一般を再現する場合は、`session_question_type_counts` を資格設定へ明記して監査する。将来の公式構成変更を検知した場合はこの設定を更新し、200/160/40を無条件に永久固定しない。

## 7. MVP要件（LS16-003への契約）

LS16-003はfull 600問を作らない。中心導線を実データで成立させる。

必須:
- UI正本 v2.1の紙/方眼/色/タイポ/最大幅/4タブを維持
- ホーム → 今日のスプリント → 問題 → 即時採点 → 解説/ここだけ覚える → 結果 → 記録
- `分野から解く` 8科目カードをデータから生成
- 4/8/16問のtarget UIを共通仕様どおり保持
- `わからない` を正式回答として扱う
- 誤答/わからないをweakへ記録
- 履歴を永続化し、再読込後も記録が残る
- 5週間heatmapは日付単位で集計する。#15で発生した「履歴があるだけで直近5マスをON」の旧バグを再導入しない
- MVP seedは **最低16問** の実問題。8科目すべてを最低1問含み、singleChoiceとmultiChoiceの両方を含める
- MVP seedも `source_url/reference_date/origin_type/rights_basis` を必須とし、ダミー問題・市販教材転記は禁止
- 図版権利処理が不要なtext-only独自問題を優先
- preview: `previews/sagyo-ryohoshi-sprint/index.html`
- preview URL HTTP 200確認 + 中心導線smoke testを証拠化
- 課金実装、StoreKit実商品登録、full600問題、App Store提出はLS16-003の範囲外

## 8. UI正本

最上位はNotion:
`https://app.notion.com/p/3b609c10697d81f0b3d0f78d160a819f`

主要固定:
- 生成り紙 + 28px方眼
- 藍 / 朱 / 緑 / 金の意味固定
- 主要教材表現は明朝
- max-width 520
- ホーム / 模試 / 記録 / 設定の4タブ
- 4 / 8 / 16問、標準8問
- 進捗リング
- 手書き風○×
- `ここだけ覚える`
- 苦手、3連続正解解除
- 中断再開
- 5週間heatmap / 分野別正答率
- 試験日ペース
- JSON backup/restore（製品段階）

#15の見た目を正本に昇格させない。#15 preview/nativeはv2.1を具現化した参考実装として使う。

## 9. 識別子・パス

- app path: **`sagyo-ryohoshi-sprint`**（Queue既定値を採用）
- preview path: **`previews/sagyo-ryohoshi-sprint/`**
- Bundle ID candidate: **`jp.allsunday1122.sagyoryouhoushi`**
  - #15 `jp.allsunday1122.rigakuryouhoushi` と兄弟命名を揃える
  - 未登録候補であり、Appleが実登録した値を最終正本とする
- content prefix: `OT`
- question ID: `OT-R<round>-<AM|PM>-<001..100>`

## 10. LS16-003へ渡す確定事項

LS16-003は以下を再判断せず実装へ進んでよい。

- Gate: ADVANCE維持
- UI: Golden Master v2.1
- app_path: `sagyo-ryohoshi-sprint`
- preview: `previews/sagyo-ryohoshi-sprint/`
- Bundle ID案: `jp.allsunday1122.sagyoryouhoushi`
- 8 subjects / practical 5-subject allowlist
- full target: 3 rounds × 200 = 600
- MVP seed: >=16 audited real questions
- data contract: `round + session + slot + question_type + subject + topic + flexible answer + source/rights`
- current common LearningSprintCore: REUSE
- #15 UI/native: ADAPT/REFERENCE、PT content/IDs: REJECT
- question pipeline: REUSE、subject-count modelだけADAPT

## 11. Human gate

**なし。**

Bundle IDは標準手順上、人間確認不要の候補決定が可能。App Store Connectへの実登録・課金契約・本提出など不可逆操作は本Taskに含まれない。LS16-003へ自動進行可能。
