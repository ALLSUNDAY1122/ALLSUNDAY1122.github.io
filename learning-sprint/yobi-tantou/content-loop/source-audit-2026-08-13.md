# 司法試験予備試験・短答式｜一次資料監査 2026-08-13

## 結論

正式教材の Release はまだ不可。R6・R7は法務省の問題ページと「正解及び配点」ページまで一次資料の存在を確認できた。R8は問題4冊の公開を確認できたが、2026-08-13時点で当開発環境から検索・取得できる法務省結果ページでは「正解及び配点」を確定できていないため、R8正答は未確定のまま保持する。

また、4冊のPDF本文をページ単位で監査できていないため、年度別・科目別の正式問題数は推測せず `null` を維持する。

## 共通の確定事項

- 短答式の対象は、憲法、行政法、民法、商法、民事訴訟法、刑法、刑事訴訟法、一般教養科目。
- R6以降は原則として、試験が行われる年の1月1日現在施行法令が出題基準。
- したがって法令基準日は R6=2024-01-01、R7=2025-01-01、R8=2026-01-01。
- 問題文には配点が記載されるが、部分点がある問題は部分点の内容が問題文に記載されない場合がある。
- 法務省サイトのコンテンツは、個別の権利表示等がある場合を除き公共データ利用規約（PDL1.0）に基づく利用を検討できるが、第三者著作物は別途権利確認が必要。

## 年度別監査

### R8 / 2026

状態: `PROBLEMS_VERIFIED / ANSWERS_PENDING / COUNTS_PENDING_PDF`

一次資料:
- 問題: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00317.html
- Q&A: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00210.html
- 委員会決定等: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00296.html

確認済み:
- 短答式問題は4冊（憲法・行政法 / 民法・商法・民事訴訟法 / 刑法・刑事訴訟法 / 一般教養科目）として公開。
- 法令基準日 2026-01-01。
- 短答式合格発表予定日は2026-08-06。

未確定:
- 正解及び配点の一次資料本文。
- 各科目の正式問題数。
- 部分点・複数正答・除外等の個別採点状態。

禁止:
- 過年度の構成からR8の正答・件数を推定しない。

### R7 / 2025

状態: `PROBLEMS_VERIFIED / ANSWER_PAGE_VERIFIED / CORRECTION_AUDIT_REQUIRED / COUNTS_PENDING_PDF`

一次資料:
- 問題: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00287.html
- 短答式結果・正解及び配点: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00289.html
- 年度結果ハブ: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00285.html
- 委員会決定等: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00267.html

確認済み:
- 問題4冊を公開。
- 結果ページに4冊それぞれの「正解及び配点」PDFが存在。
- 年度結果ハブに「短答式試験における試験問題の誤記およびその取扱いについて」が掲載されているため、R7問題は訂正資料の反映を必須ゲートとする。
- 法令基準日 2025-01-01。

未確定:
- PDF本文をページ単位で確認した正式問題数・正答・配点・特殊採点。
- 誤記訂正の対象設問と最終採点への影響。

### R6 / 2024

状態: `PROBLEMS_VERIFIED / ANSWER_PAGE_VERIFIED / COUNTS_PENDING_PDF`

一次資料:
- 実施・法令基準: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00162.html
- 問題: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00228.html
- 短答式結果・正解及び配点: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00258.html

確認済み:
- 問題4冊を公開。
- 結果ページに4冊それぞれの「正解及び配点」PDFが存在。
- R6から試験年1月1日現在施行法令を原則基準とすることが法務省ページに明記。
- 法令基準日 2024-01-01。

未確定:
- PDF本文をページ単位で確認した正式問題数・正答・配点・特殊採点。

## Releaseゲート

次の全条件が満たされるまで `releaseEligible=true` を禁止する。

1. 年度×科目の正式件数が一次資料PDFから確定。
2. 問題ごとの最終正答・配点・特殊採点状態が一次資料と一致。
3. R7は誤記訂正資料を反映済み。
4. 一般教養など第三者著作物の疑いがある素材は、権利根拠を確認できない限り本文を再利用しない。
5. 独自問題は法令・判例等の一次資料に直接根拠を持たせる。
6. 共通 `automation/learning-sprint-question-pipeline/validate_questions.py` の構造・件数・重複・高類似監査をPASS。
7. 正答・法令基準・著作権を別監査しFAIL 0。

## 次の処理

PDF本文の取得が可能になるまで、年度問題の推測作成はせず、年度非依存の論点マップ、独自問題候補バンク、候補用preflight validator、アプリ側Releaseバンク読込ゲートを先行実装する。
