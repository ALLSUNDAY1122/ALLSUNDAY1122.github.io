# #14 助産師国家試験｜本番問題スキーマ v1.0

## 原則

`data/questions.json` は本番アプリへ結線する唯一の問題バンク候補です。生成しただけの問題を本番扱いしません。

各問題は `data/generation-plan.json` 相当の計画情報と1対1で対応し、以下を満たしたものだけを `auditStatus: pass` にできます。

- 330個の計画IDのいずれかと一致
- mockRound / session / questionType / scenario linkage / subject / topicId / intentId が計画と一致
- 問題本文・選択肢・正答・独自解説・「ここだけ覚える」が揃う
- `sourceIds` が根拠レジストリに存在し、少なくとも1つは当該論点の計画アンカーと一致
- `sourceCheckedAt` と、法令・制度問題では `lawBaselineDate` を保持
- `originType = original_from_primary_source`
- `rightsBasis` に独自表現・直接転載なしを明示
- 高類似・完全一致なし
- 医療・法令内容の別監査をPASS

## 問題レコード

```json
{
  "id": "JOS-R1-AM-Q01",
  "mockRound": 1,
  "session": "AM",
  "slotNumber": 1,
  "questionType": "general",
  "scenarioId": null,
  "scenarioIndex": null,
  "scenarioTotal": null,
  "subject": "基礎助産学",
  "topicId": "BASIC-01",
  "intentId": "BASIC-01-I1",
  "intentFocus": "助産・助産師の定義と法的位置付け",
  "answerType": "singleChoice",
  "prompt": "独自問題本文",
  "choices": ["選択肢1", "選択肢2", "選択肢3", "選択肢4"],
  "correctIndices": [0],
  "explanation": "独自解説",
  "memoryPoint": "ここだけ覚える",
  "sourceIds": ["EGOV-PHN-MIDWIFE-NURSE-ACT"],
  "sourceCheckedAt": "2026-08-13",
  "lawBaselineDate": "2026-08-13",
  "rightsBasis": "original wording from verified facts; no direct reproduction",
  "originType": "original_from_primary_source",
  "contentVersion": "josanshi-content-v1",
  "auditStatus": "draft"
}
```

## 状況設定

状況設定105問は `scenarios` の36症例に必ず所属します。問題側の `scenarioId` / `scenarioIndex` / `scenarioTotal` と、症例レコードのID・問題順が一致しなければFAILです。

症例本文は同一症例内で共有し、各設問ごとに患者像を作り直しません。妊娠週数、産科歴、時系列、検査値、母体・胎児・新生児状態などは症例内で矛盾させません。

```json
{
  "scenarioId": "JOS-R1-AM-SC01",
  "mockRound": 1,
  "session": "AM",
  "scenarioFamily": "pregnancy",
  "scenarioText": "独自症例本文",
  "clinicalFrame": {
    "phase": "pregnancy",
    "timeline": "妊娠期の時系列",
    "keyFindings": ["症例内で固定する重要所見"]
  },
  "questionIds": ["..."],
  "sourceIds": ["..."],
  "sourceCheckedAt": "2026-08-13",
  "rightsBasis": "original scenario; no direct reproduction",
  "auditStatus": "draft"
}
```

## 段階ゲート

### Draft gate

部分バンクを許可します。ただし追加済みレコードは全てスキーマ・計画整合・根拠・権利・重複監査を通す必要があります。

### Full bank gate

- questions = 330
- general = 225
- situation = 105
- scenarios = 36
- 計画ID欠損 = 0
- intentId欠損/重複 = 0
- 完全一致 = 0
- 高類似 = 0
- 正答形式不正 = 0
- source欠損 = 0
- rightsBasis欠損 = 0
- auditStatus != pass = 0

このFull bank gateをPASSするまでSwiftUI本番問題画面へ製品コンテンツとして解放しません。
