# FP2級データ状況｜2026-11-08更新

製品方針は公式過去問方式に変更。協会公開5回（学科300、実技200、計500問相当）が収録候補。既存180行（2026-05、2025-05、2025-01の学科各60）は監査台帳上の確認済み記録であり、新方式での製品承認は未了。原典・正答・権利・法令・解説の再検証が必要。A01独自問題は製品に算入しない。詳細：[変更決定・実装計画](./OFFICIAL_PAST_QUESTIONS_POLICY_20261108.md)。以下は旧時点の記録。

---

# FP2 PRODUCT DATA STATUS

Updated: 2026-09-16 JST

## Fresh source audit

Connected Google Drive canonical spreadsheet `AUDIT_MATRIX_FP2` (`1vnRCsnMzwyNwTnzccpK1Tv5lSSIC4H3EpJL0i0YpPNA`) was read directly.

- Sheet: `AUDIT_MATRIX_FP2.csv`
- Grid: 1000 rows × 26 columns
- Rows matching canonical `fp2-` IDs: **180**
- Covered exams visible in the matrix: 2026-05 (60), 2025-05 (60), 2025-01 (60)
- Each returned row carries source URL plus `transcription_check=済` and `explanation_check=済`.
- The current GitHub `fp2-manabi-sprint/index.html` contains only an 8-question UI sample and explicitly says the product data will be replaced after a 600-question audit.

## Release decision

Do not claim a 600-question canonical product bank. Fresh connected evidence currently establishes 180 audited matrix rows, not 600.

The FP2 release remains fail-closed until the product contract is reconciled. Either:

1. produce and audit the remaining canonical rows needed by an explicitly approved 600-question contract, without filler/padding; or
2. explicitly revise the product contract to the smaller audited corpus if that corpus is sufficient for the intended product value.

In either case, wire the accepted canonical bank into the v2.1 product UI and run the learning Quality Pack before any Release/TestFlight gate.
