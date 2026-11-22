# No.161（sm2-5y-r09-hyg-09）労安法第66条の4・5：一次法令独立照合（2026-11-12）

## 条文の直接検証

- 一次資料：[厚生労働省・労働安全衛生法（昭和47年法律第57号）第66条の4・第66条の5、HTML本文6ページ中2ページ](https://www.mhlw.go.jp/web/t_doc?dataId=74001000&dataType=0&pageNo=2)。2026-11-12直接参照。補助：[e-Gov 法令検索](https://laws.e-gov.go.jp/law/347AC0000000057)。
- **第66条の4**：健診で異常所見がある労働者について、健康保持に必要な措置に関し、事業者が医師又は歯科医師の意見を聴く義務。第66条の5：事業者はその意見を**勘案**し、**必要があると認めるとき**本人の実情を考慮して、就業場所の変更、作業の転換、労働時間の短縮、深夜業の回数減少等の措置を講ずる義務。**医師の提案が常に自動的に強制実施されるという規定ではない**。
- 問題文「健康診断で異常所見がある労働者について医師が就業上の制限を提案」「第66条の4・5に照らし事業者の対応」を直接比較。**第2肢（index1）**：医師意見を勘案、本人の実情考慮、必要性に応じ事業者が措置を講ずる、は条文に整合。
- 第1肢「意見聴取で措置検討不要」は第66条の5と不整合。第3肢「医師意見・本人実情を無視」は同条と不整合。第4肢「事業者は医師意見を一切利用できない」は66条の4・5に反する。第5肢「全員一律解雇義務」は同条の必要性・個別措置に反し、条文に一律解雇義務なし。**5肢を独立確認し正答一意性を妥当と判定**。
- 解説・`primary_basis`・`source_url`が現行の条文と整合することを確認。新たな条文修正・出題意味の変更不要。

## 正式な監査状態の変更

- 確認日：**2026-11-12**。`legalChecked: null → "2026-11-12"`、`auditStatus: "内容監査済" → "一次資料照合済"`。正答、全5肢、設問文、解説、出典URL、法令分類`lawRelated=true`、既存の独立レビューゲートは不変。
- 生成元`apps/sanitary-manager-2/audit-fixes.js`にID・topic・subject・問題文・五肢集合・正答文字列・根拠・出典・旧説明・旧状態の全ガードを追加。コミット：`e43d9eea110bef18d7c5dae5136fe26f90537679`。
- 配布JSONに同二項目のみ反映。コミット：`fe9e5d4cd2cdd16b9aaa862720bcc48ef36714c7`、当該配布JSONのGit blob：`c438c858471b66a3a5a24cad6d9feacc3afedf1b`（後続監査文書コミットでは内容不変）。
- **これは本件の法令設問に関する一次法令照合の完了記録であり、178問の別途独立レビュー完了や外部専門家査読完了を意味しない**。

## 実行検証・残ゲート

- GitHub Actions [HM2 exact JSON parity and strict release-gate regression #43102877499](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/43102877499) **success**：Nodeによる正本300問再生成、配布JSONとの`cmp -s`バイト一致、SHA-256 **`b4233fc88e3bb4067c0a4f422f8f6a9d927a4aed949fda8a77d2dd997c0496d3`**。独立レビュー待ち178問の残存をログで確認。
- 旧リリースエクスポートは`HM2_RELEASE_REVIEW_BLOCKED: 178 generated questions require independent review / status reconciliation`で**意図した停止**。正答位置0〜4各60、出題データ差異0、ID300一意。178問の`contentReviewStatus`は一件も変更しない。
- 178問の証跡照合開始台帳：[FINAL_GATE_178_ID_EVIDENCE_MATRIX_20261112.md](FINAL_GATE_178_ID_EVIDENCE_MATRIX_20261112.md)。**本番公開BLOCKED**維持。
