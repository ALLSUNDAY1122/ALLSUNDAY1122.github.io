# 通関士｜学びスプリント コンテンツ監査仕様

## 公開条件

製品に表示できる問題は、次の条件をすべて満たすものだけとする。

- `auditStatus === "approved"`
- `contentVersion` がアプリの有効版と一致する
- `lawBaseline` が対象試験の法令基準と一致する、または監査により有効と確認済み
- `rightsStatus` が `original` / `allowed` / `licensed` のいずれか
- 第三者権利がある場合は個別許諾または利用根拠が記録されている

## 共通フィールド

```json
{
  "id": "TB-0001",
  "subject": "通関業法",
  "topic": "通関業の許可",
  "answerType": "singleChoice",
  "question": "...",
  "point": "この問題で覚える一文",
  "detail": "独自解説",
  "lawBaseline": "2026-07-01",
  "contentVersion": "tsukanshi-2026-07-v01",
  "sourceType": "original",
  "sourceTitle": "関税法等の一次資料名",
  "sourceUrl": "https://...",
  "transformationNote": "一次資料から論点を抽出し独自作問",
  "rightsStatus": "original",
  "auditStatus": "approved",
  "auditedAt": "2026-08-08"
}
```

## 回答形式

### singleChoice

```json
{
  "choices": ["...", "...", "...", "...", "..."],
  "answer": 0
}
```

### multiChoice

```json
{
  "choices": ["...", "...", "...", "...", "..."],
  "answers": [0, 2],
  "selectionCount": 2
}
```

### blankSelect

```json
{
  "blanks": [
    {"label": "A", "options": ["...", "..."], "answer": "..."}
  ]
}
```

### numeric

```json
{
  "correctNumber": 50000,
  "unit": "円",
  "acceptedRange": 0,
  "roundingRule": "問題固有の端数処理を明記"
}
```

### declaration

```json
{
  "sourceText": "インボイス等の資料",
  "declarationFields": [
    {
      "key": "origin",
      "label": "原産国",
      "answer": "ベトナム",
      "aliases": ["ベトナム社会主義共和国"]
    }
  ]
}
```

## 480問の目標配分

初期配分は固定値ではなく、公式出題範囲・直近傾向の監査後に調整する。作問着手時の暫定目標は以下。

- 通関業法：120問
- 関税法等：240問
- 通関実務（知識・計算）：120問
- 上記とは別に申告書演習：12セット

各問題は「一問一論点」を基本にし、同一論点の文章だけを変えた水増しを禁止する。直近3回の公式問題は、出題傾向分析・本試験形式検証に用い、問題本文を収録する場合はPDL1.0と第三者権利を問題単位で監査する。

## 自動監査項目

- ID重複なし
- 必須フィールド欠落なし
- answerTypeごとの回答データ整合
- singleChoiceの正解indexがchoices内
- multiChoiceのanswers重複なし、selectionCount一致
- blankSelectのanswerがoptions内
- numericの数値・単位・丸め規則整合
- declarationのkey重複なし
- 解説空欄なし
- `auditStatus !== approved` を製品バンドル対象から除外
- 法令基準不一致をビルド時警告
- 同一問題文・選択肢セットの重複検出

## 監査順序

1. 公式出題範囲・一次資料から論点抽出
2. 独自問題・独自選択肢・独自解説作成
3. 正答根拠を一次資料で確認
4. 表現・重複・回答整合の機械監査
5. 権利状態を確認
6. 法令基準を確認
7. `auditStatus = approved`
8. 製品用JSONへ収録

未監査問題はGitHub上に存在してもアプリUIへ表示しない。
