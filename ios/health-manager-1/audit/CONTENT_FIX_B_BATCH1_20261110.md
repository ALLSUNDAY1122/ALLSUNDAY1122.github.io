# 追加演習B 修正バッチ1（2026-11-10）

## 結果
- ブランチ: `fix/hm1-practice-b-reaudit-20261110`
- 基準main: `fd82957f816c6794ff9bf99236cb01055cccd6c8`
- データ修正適用 **7問**: Q03・Q11・Q12・Q17・Q18・Q29・Q43。
- B44問のうち**未修正37問**。修正7問についても、品質ゲート全体の最終合格・実機確認は別途必要。App Review・TestFlight・main統合は実施していない。
- 監査履歴 `CONTENT_REAUDIT_264_B_20261110.md` の修正前スナップショットは維持。本ファイルが修正適用状況の追加証跡。

## 選定範囲と変更後の命題
| HM1 ID | 対応する指摘 | 修正後 |
|---|---|---|
| practice-B-Q03 | 基本2026-04-Q21と産業医人数が重複 | 産業医選任の利害関係・除外対象候補 |
| practice-B-Q11 | 基本2026-04-Q01と1,000人超の基準が重複 | 500人超・坑内労働30人以上の別ルートの境界判定 |
| practice-B-Q12 | 基本2025-10-Q21と巡視頻度が重複 | 衛生管理者へ権限を与える義務主体 |
| practice-B-Q17 | 基本2026-04-Q32と持上げ姿勢が重複 | 工程の自動化・省力化の選択 |
| practice-B-Q18 | 基本2026-04-Q32と姿勢、Q17と内容が反復 | 新設備導入時の作業標準の見直し |
| practice-B-Q29 | 基本2025-10-Q28と一次予防が重複 | ケアの主体と予防段階を組み合わせて判定 |
| practice-B-Q43 | 腎臓／ネフロン／糸球体の包含で一意性疑義、基本2025-10-Q35と原尿形成が重複 | 輸入細動脈→糸球体→輸出細動脈の血管経路 |

Q16（画面配置）、Q37（換気量）等は監査で**部分重複**とされた別命題であり、本バッチの実質重複対象6問とは分け、未修正37問に含める。Q10の例外対象の限定、Q34/Q35のB内反復、Q27/Q28の情報保護・復帰判断等も残る。

## 実装
- `content-overrides-b-20261110.json`: 設問、5肢、正答、短解説・詳細解説、直接出典、変更後論点、旧元IDの追跡情報。
- `apply-content-overrides.cjs`: 対象7IDの集合と元conceptKey・元設問を確認。7件全てを検証してから適用し、入力の対応が変わった場合は途中適用せず停止。
- `augment-to-264.cjs`: HM2由来の選定とA/B/Cの割当後、重複検査・書出し前に第一種専用の修正を適用。HM2の正本は変更しない。追加問題の採用順・ID・科目区分を維持。
- `Resources/questions.json` は正本132問のまま。修正された追加132問は従来どおり生成時に構成される。生成済み264問だけを編集して次回消える変更ではない。`prepare-ios.sh` が生成後JSONをHTMLへ埋め込む経路にも反映される。
- 既存リリース準備・公開停止条件は変更していない。

## 内容照合
- Q03/Q11/Q12: 厚生労働省「労働安全衛生規則」13条1項2号、7条1項5号、11条1・2項  
  https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0
- Q17/Q18: 腰痛予防対策指針2(1)、2(4)等。指針の推奨を一律の法定義務としない。  
  https://www.mhlw.go.jp/web/t_doc?dataId=00tb9484&dataType=1
- Q29: 心の健康指針3・5、こころの耳「一次予防」。分類の主体と目的を区別。  
  https://www.mhlw.go.jp/web/t_doc?dataId=00tc1466&dataType=1&pageNo=2  
  https://kokoro.mhlw.go.jp/glossaries/word-1518/
- Q43: Rice University / OpenStax Biology 2e 41.2「Capillary Network within the Nephron」。図・文章を転載せず血管経路の事実を確認。  
  https://openstax.org/books/biology-2e/pages/41-2-the-kidneys-and-osmoregulatory-organs
- 全7問の5肢を個別に確認し、正答と各誤答理由を詳細解説へ反映。Q43は上下位概念を答え候補から外し、同じ血管・管腔の経路比較へ統一した。
- 出典と変更後の論点を併記した局所的な再照合であり、全264問の独立した再監査完了や試験難易度の保証を意味しない。

## 検証結果
実行: `node ios/health-manager-1/audit/test-b-revisions-20261110.cjs`
- PASS: 264問、ID一意、6セット各44問、5肢・正答範囲・選択肢重複なし、正規化後の設問重複なし。
- PASS: 変更IDは上記7問のみ、他257問は全属性一致。基本132問・追加A/Cは不変。
- PASS: 同一入力からの再生成一致。元設問／元IDの変化、対象ID欠落・重複、正答範囲違反、identity変更を拒否し、部分適用しない。
- PASS: HTMLの既存QUESTIONS埋込み形式で264問を往復し、修正を保持。
- 既存 `difficulty-audit-2026-08-21.cjs` を隔離した生成結果に実行: exit 0、knowledge_free_risk=0、review=14、direct_recall_review=10。対象7問にflagなし。この機械検査は意味的重複・正答一意性を自動保証しない。
- iOSビルド・実機UI・新規配信は未実施。
