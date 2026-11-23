# FP2 先頭30問・FAIL2件の修正追跡（2026-11-23）

## 独立監査記録の取得状況
指定ファイル `fp2-manabi-sprint/audits/FP2_RECOVERED_180_INDEPENDENT_BATCH01_30_20261123.md` は、このブランチへの GitHub fetch_file が404 NOT_FOUND。GitHub default branch全文検索も該当なし。従ってPASSとされた個別ID・実監査理由を確認できず、28件を自動承認してはならない。先行15問も現存の元ドラフトでは全問HOLDであり、別の承認台帳を取得できていない。

## 修正対象1: fp2-2026-05-gakka-014
原典：日本FP協会2026年5月公表 2級学科問14、https://www.jafp.or.jp/exam/mohan/files/g2_202605_qa.pdf PDF8枚目（表示7頁）、正解3。
- 修正前の誤転記: 一般生命（旧）10万円、介護医療10万円、個人年金（新）10万円。元JSONの説明が「13万円を12万円で頭打ち」と言いつつ正答10万円を選ぶ内部矛盾あり。
- 公式原題の実際の表：一般生命保険（旧）10万円、介護医療なし、個人年金（旧）10万円＋（新）10万円。
- 計算：旧一般生命5万円＋個人年金は旧のみ5万円（新旧併用なら4万円上限、したがって旧のみ有利）＝10万円。
- 正答3を維持。問題文の資料条件と解説を訂正、modified=true、modification_noteに原文表のテキスト化・誤転記訂正・解説修正を保存。以前の文・解説は correction_prior に保存。
- 公式原題と国税庁No.1140 https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1140.htm で計算確認。
- 判定: CORRECTED / INDEPENDENT_REVIEW_PENDING。既存FAILを承認に上書きしない。

## 修正対象2: fp2-2025-01-gakka-034
原典：日本FP協会2025年1月26日 2級学科問34、https://www.jafp.or.jp/exam/mohan/files/g2_202501_q.pdf PDF14枚目（表示14頁）。
- 原題第4肢の48万円以下を、2025年分所得税からの改正後の配偶者所得要件58万円以下に更新。
- 青色事業専従者給与の受給者は、所得要件に合致しても控除対象配偶者ではないため、正答4を維持。
- modified=true、modification_noteに税制改正による加工と内容、出典を保存。以前の第4肢と解説は correction_prior に保存。
- 国税庁 https://www.nta.go.jp/users/gensen/2025kiso/index.htm と財務省 https://www.mof.go.jp/tax_policy/tax_reform/outline/fy2025/07taikou_01.htm にて58万円への改正確認。2026年4月1日現在は58万円（2026年度後日改正に伴う将来の62万円適用と混同しない）。
- 判定: CORRECTED / INDEPENDENT_REVIEW_PENDING。

## 正規バンク判定
既存原型15問（original12、2024-05改編3）の確認済み独立承認記録はなく、最新のデータではHOLD。
180問の先行30問について指定独立監査ファイルが404のため、28問のPASS識別・理由を検証不能。
そのため今回発行する正規承認済みbankは **0問**（証跡がないデータを偽PASSとして収録しない）。
残り178問の modified=null は原文比較が未完了のHOLDであり、本番bankには移さない。Q0/Q1はBLOCKED。
本番申請・公開・PRマージはしない。
