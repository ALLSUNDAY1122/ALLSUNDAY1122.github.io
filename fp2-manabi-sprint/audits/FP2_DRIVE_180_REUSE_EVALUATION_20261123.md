# FP2 Drive 180件再利用評価（2026-11-23）

## 実物取得
Google Sheets: https://docs.google.com/spreadsheets/d/1vnRCsnMzwyNwTnzccpK1Tv5lSSIC4H3EpJL0i0YpPNA/edit
タブ AUDIT_MATRIX_FP2.csv、A1:I181を直接取得。180件のIDは全件一意。2026-05/2025-05/2025-01の各60件。
9列: id, examDate, domain, sourceQuestionNumber, answer, sourceUrl, transcription_check, explanation_check, legal_reference_date。
出典URLと旧正答は180/180、転記済みと解説確認済みの過去のフラグは180/180。

## 判定
この監査表には問題本文、4選択肢の本文、解説本文、問題ごとの加工履歴、2026-04-01現行法での独立再監査結果が存在しない。『済』の文字だけで完成問題と認定しない。GitHubの一部識別子・ファイル名検索でも完全問題データを確認できなかった（他ブランチの不存在は未証明）。
180件は出典インデックスとして再利用可能、完成問題バンクとしては利用不可。製品へ投入可能0問。個別現行法再確認180件未実施。
2026-05公式試験の法令基準日は2025-04-01。製品目標基準日2026-04-01とは異なる。旧正答は無条件に流用できない。

## GitHub成果物
questions/draft/fp2-drive-matrix-180-source-index-20261123.json に180件の出典メタデータを隔離保存。問題本文・選択肢・解説・加工情報はnull、publishable=false、current_law_review_status=NOT_TESTED。
公式過去問の著作権条件は条件付き確認済みだが個別Q0はBLOCKED。Q1もBLOCKED。第三者FP2級ドットコムの文章・解説・データは転載しない。

## 残作業
公式公開PDFまたは既存の完全転記資産を取得し、問題本文・4肢・解説を埋める。試験回/問番号/原典URLの対応、加工表示・現行法再解答、全肢独立監査、重複・類似・権利確認、canonical統合後の再監査、UI Master v2.1組込を行う。
現時点：出典メタデータ180件取込、完成問題0件、現行法再監査0件、未再監査180件。