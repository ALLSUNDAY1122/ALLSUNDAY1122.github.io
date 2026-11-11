# X-03 生成再現性 — 2026-11-11

対象ブランチ: `audit/hm2-quality-20261110`

## 原因
`apps/sanitary-manager-2/audit-fixes.js` の P1-1 は、修正前の `q.answer` が再設計版 `f.answer` と同じであることを要求し、`sm2-5y-r08-law-05` の旧36協定問題（正答5）から新しい健診結果報告問題（正答3）への置換時に停止した。従来の `Object.assign` は `answer` を更新していなかった。

## 対応
- P1-1で旧36協定問題を ID・旧正答5・設問キーワードで識別する。
- 再設計済みの設問・選択肢・正答が一致する場合も許容する。
- 想定外の設問・正答の組合せでは停止する。
- `answer:f.answer` を含めて一括更新する。

## 検証状況
- GitHub上の修正コミット: `8c38f2ee2b8ff8d2d31cdb88e0a6dcbee635fa71`
- `node ios/health-manager-2/export-audit-data.cjs`: **未実行**（GitHubコネクタには任意コマンド実行機能がない）。
- 300問の再生成結果と現行 `release-questions.json` の完全比較: **未実施**。
- 他ブロックの前提不一致: P1-2以降にも `q.answer===f.answer` を前提とするガードが複数存在することを確認。ただし実際の旧版正答との突合・停止有無は未検証。

## 次のゲート
1. 対象ブランチをローカルでチェックアウトし `node ios/health-manager-2/export-audit-data.cjs` を実行。
2. 失敗した場合は停止したブロックと入力正本を照合し、ガードを個別修正。
3. 出力JSONと現行リリースJSONを ID 単位・全フィールドで比較し差異を記録。
4. 一致確認後に X-03 を PASS とする。現時点では **BLOCKED（実行未検証）**。
