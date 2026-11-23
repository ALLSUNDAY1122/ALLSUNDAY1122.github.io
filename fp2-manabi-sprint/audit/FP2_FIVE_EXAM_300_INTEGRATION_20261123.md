# FP2 学科5回分300問｜バッチ原本突合・正規バンク統合記録（2026-11-23）

## 判定
**内容監査PASS300/300（5回分×各60問）**。2024-09の60問、2024-05の60問（新規57＋先行Q01/Q02/Q06の再監査3）と既存の2026-05/2025-05/2025-01の180問を合わせる。**canonical総数312=学科過去問300＋独自作成の別予備12**。公開承認0問。2024-05同一原題3問を重複追加しない。現行リリース選定は学科300問、予備12問。

## バッチ別独立監査原本（集計表の値からではなくitemsの各行を照合）

| 新規データと監査証拠 | 制作件数 | 監査PASS | 監査FAIL/HOLD | 監査Git Blob SHA |
|---|---:|---:|---:|---|
| 2024-09 B01 Q01–20 / FP2_202409_B01_INDEPENDENT_PRELIMINARY_20261123.json | 20 | 20 | 0/0 | 7bd89cc8c0d2ab79b6d685631be3d2180a1ebcef |
| 2024-09 B02 Q21–40 / FP2_202409_B02_INDEPENDENT_20261123.json | 20 | 20 | 0/0 | d0056b74b37374c4637c4b77804fbf60996536c1 |
| 2024-09 B03 Q41–60 / FP2_202409_B03_INDEPENDENT_20261123.json | 20 | 20 | 0/0 | 454a748368da7f323b9cfe95b149e63adbad25bf |
| 2024-05 B02 Q03–05,Q07–23 / FP2_202405_B02_INDEPENDENT_20261123.json | 20 | 20 | 0/0 | 8828b3b807f6fd281d9f09c3e7aa2743945e79ca |
| 2024-05 B03 Q24–43 / FP2_202405_B03_INDEPENDENT_20261123.json | 20 | 20 | 0/0 | 2bb175dd2f732274f69d139bf397022930e9051d |
| 2024-05 B04 Q44–60 / FP2_202405_B04_INDEPENDENT_20261123.json | 17 | 17 | 0/0 | 0f78a05b506fe2b2cb7847e79d9cd423cfba2af4 |
| 2024-05 B01 既存Q01/Q02/Q06 / FP2_202405_B01_HOLD3_RESOLUTION_20261123.json | 3（既存） | 3 | 0/0 | a18ac471fbf31102cb917e346b166a678090546f |

バッチ別itemsのID/正答index/4選択肢全文/独立監査PASS・canonical適格/原典出典/一次資料/2026-04-01基準日/各ソースBlobを突合。2024-05既存3問では問題ID、公式原題番号、本文、4選択肢、正答を一致確認。制作側6JSONのGit Blob SHAは監査記録内のsource_blob_shaに一致し、リリースブランチのquestions/draft/へ原本を保管した。原本は従来のDRAFT_NOT_FOR_RELEASEのまま保存し、公開許諾を推定しない。

## 改変分類
- 新規117問すべて**modified=true**：原題の論点を基に設問・4肢を再構成した加工設問。制作側modification_noteをmodification_note_draftとして保管、独立監査のmodification_note_reviewを正規バンクのmodification_noteとして採用。監査証拠パスおよびGit Blob SHAを各行に固定。
- **2024-09 B01の20問**では制作側と監査側の改変説明の**文言が異なる**ため両方保持。改変有無の分類はいずれもmodified=true、内容の正答・選択肢・stemは一致。公式原題全文との逐語差分の独立再抽出・許諾はQ0で別途確認。
- **2024-09 Q29**は旧選択肢2「元本と利息を含め全額」から「元本1,000万円とその利息まで」へ変更済み。二次監査PASS、正答index3で一意。変更前の文面は監査記録のreview_history、制作JSONのmodification_noteに保存。
- **2024-05既存3問**はmodified=trueの監査済み登録を維持し、HOLD3解消の独立監査パスとSHAを追記。同一原題を追加で数えない。

## 採否・権利の限界
**内容監査PASS≠配布承認。** 最新法令の一次資料スナップショットの完全保存、公式問題利用条件の著作権判断、出題構成の教育上の最終認定、実バンドル・Web・iOS/端末E2E、ASC/実機は独立ゲート。全312問をpublishable=falseのままとし、300問リリース選定もSUBMISSION_READYを意味しない。

## 固定後の選定
- canonical: `questions/canonical/approved-questions-20261123.json` Git Blob SHA `03b449dbe8a848b192bd970801846b18c486b1b4`。
- selection: `release/release-selection-300-20261123.json`、学科5回分各60、6分野各50、予備独自作成12。
- 旧120問選定ファイルは履歴として保存。Web/iOS/CIは新300問台帳を利用する。
- App Store Connectへは未申請、PR #5717はDraft、mainへは未マージ。
