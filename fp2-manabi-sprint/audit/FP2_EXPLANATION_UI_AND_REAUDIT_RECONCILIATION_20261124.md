# FP2 Muse UI追加2件・解説再監査台帳の照合（2026-11-24）

## 対象・非変更保証
- 対象：正規310問のうち `release_selected=true` の公式逐語298問。
- 正規バンク Git Blob: `2f46642dbbe1ade7f48c6db6ac4dc13b62e1c4a5`。問題文・4選択肢・正答・`explanation`・`explanation_provenance` はこのPRで変更しない。
- 表示アダプタでは全298問に独立した `memory`/`key_point` がなく、`m`/`r`/`d` が同じ解説全文を参照。Web表示では異なる短文要約がある場合以外「一文」ボックスを非表示とし、同一の詳説は重複表示しない。内容は `reason` に残す。
- 画面描画時のみ `【独自解説…】`、`【独立最終監査…】`、`【2026-04-01基準・独立最終監査済み】` などの監査状態接頭辞を除外。公式正答など意味のある `【2024年5月公式解答：3】` は除去しない。
- 監査状態はHTML文言の有無でなく個別証拠行に基づく。権利・出版・App Review承認を示さない。

## 逐語選抜298問・回別照合

| 回 | 選抜 | 両監査フラグ true | explanation_provenance=LEGACY... | 個別の4肢一次根拠+explanation_review PASS系列+VERIFIED+verified_at がすべて確認できる解説 | 別レベルの旧監査で解説整合が記録された件数 |
|---|---:|---:|---:|---:|---:|
| 2024-05 | 59 | 59 | 0 | **0**（今回の180問最終台帳の対象外） | 59（explanation_quality 58件 CONSISTENT_WITH_OFFICIAL_ANSWER、Q53図版再監査PASS 1件） |
| 2024-09 | 59 | 59 | 0 | **0**（同上） | 59（explanation_review=CONSISTENT_WITH_VERDICT） |
| 2025-01 | 60 | 60 | 51 | **60** | ― |
| 2025-05 | 60 | 60 | 60 | **60** | ― |
| 2026-05 | 60 | 60 | 60 | **60** | ― |
| 合計 | **298** | **298** | **171** | **180** | **118** |

**件数定義に注意：** 2024年の118問には別ファイルによる独立法令・正答・解説整合監査の記録があるが、2025〜2026年180問の最終台帳と同水準の `choice_evidence` + 独立 `explanation_review` + `verified_at` の組合せを要求すると、**同条件で最終解説再監査を確認できるのは180/298問**。2024年118問を「未監査」と断定するものではなく、証拠の水準が異なるため別掲する。

### 180問最終台帳の内部整合
- 出典：`audit/FP2_180_LEGAL_EXPLANATION_FINAL_REAUDIT_TRACKER_20261124.json`、Git Blob `8d471b935702e4a9e267f6f5296ecb82ebdae9cd`。
- `items` 180件の全件で `status=VERIFIED`、`choice_evidence`4件、`explanation_review.result` が `PASS` で始まる値、`verified_at` の存在を確認。PASS=104、PASS_WITH_CLARIFICATION=16、PASS_WITH_QUALIFICATIONS=40、PASS_WITH_NOTES=20。**合計180**。
- `summary.verified=180` と個別実件数は一致するが、`verified_records_count=90` と `audit_progress_note` の90/180は**陳腐化した集計**。本表示専用PRでは台帳・正規バンクを書き換えず、後続の監査正本更新課題として明記。
- `explanation_provenance=LEGACY_REVIEW_FLAG_NOT_INDEPENDENTLY_VERIFIED` は2025-01:51、2025-05:60、2026-05:60、合計171。最終台帳の対象180問に含まれるため、**後段の最終再監査記録が存在する一方、正規レコードの由来表示が更新されていない状態**である。フラグ・台帳の存在と、法令一次URL全件の今回の独立再取得・歴史的施行版照合の完了を混同しない。
- 正規バンクの `audit.legalChecked`・`audit.explanationChecked` は選抜298/298でtrue。ただしフラグだけで証拠充足を認定しない。

### 画面監査用の原文接頭辞
- 2026-05：`【独自解説・回収バンク移管初稿（未再監査）】` 58件、`【独立最終監査修正・2026-04-01基準】` 2件
- 2025-05：`【独自解説・回収バンク移管初稿（未再監査）】` 60件
- 2025-01：`【独自解説・初稿／独立再監査待ち】` 51件、`【2026-04-01基準・独立最終監査済み】` 6件、`【独自解説・2026年4月1日法令・一次資料再監査済】` 3件
- 以上 **180件**を画面描画時のみ整形する。元の解説本文・監査追跡可能性は残す。2024-05 Q53の公式正答ラベル1件は監査ステータスではなく内容ラベルのため保持。

## 公開ゲート
Q0=BLOCKED（権利・出典・逐語利用条件）、Q5=BLOCKED（署名IPA・TestFlight・ASC実物）。総合 NOT_SUBMISSION_READY。PR #5729 Draft、mainマージとApp Store提出は禁止。
