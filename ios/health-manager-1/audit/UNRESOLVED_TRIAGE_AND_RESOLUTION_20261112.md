# 第一種衛生管理者｜全264問・未解決事項3群仕分けと第1次代替原典追証（2026-11-12）

**ブランチ**：`codex/hm1-integrate-basic-a-b-c-20261111`。基準コミット`d56f0fb0c4889881357c4ebd6fbebda27c46504a`。

## 集計基準
統合残件台帳のPENDING 15 ID、PARTIAL 43 IDと、登録URL障害グループを問題IDに展開して和集合とし、後続の修正済み記録がある歴史IDを除外。重複はIDごと1回。以下の **a は「公開資料による対応が可能・見込みの項目」** であり解消済み数ではない。bは特定の不可欠な有料規格が確認された場合のみ、cは問題の条件自体に修正を要する場合のみ計上。分類は継続調査で更新可能。

| 分類 | 件数 | 内容 |
|---|---:|---|
| a：到達可能な代替一次資料・公開資料で追証／URL差替え可能な候補 | **84** | 未解決のまま残る項目も含む |
| b：特定の有料・制限規格への依存で到達自体が困難と確認した項目 | **0** | 現台帳に特定の有料JIS本文が必須と確定する項目はない |
| c：設問内容自体の修正が必要 | **1** | 基本2026-04-Q25の適用事業場区分 |
| **合計（重複なし）** | **85** | 全264問を再カウントした数ではなく追跡対象のID数 |

## 対象ID一覧
**a（84件）**：`2025-04-Q34`、`2025-04-Q36`、`2025-04-Q37`、`2025-04-Q38`、`2025-04-Q40`、`2025-04-Q43`、`2025-10-Q01`、`2025-10-Q02`、`2025-10-Q06`、`2025-10-Q10`、`2025-10-Q14`、`2025-10-Q15`、`2025-10-Q37`、`2025-10-Q39`、`2025-10-Q44`、`2026-04-Q02`、`2026-04-Q04`、`2026-04-Q08`、`2026-04-Q12`、`2026-04-Q13`、`2026-04-Q14`、`2026-04-Q15`、`2026-04-Q17`、`2026-04-Q19`、`2026-04-Q20`、`2026-04-Q28`、`2026-04-Q29`、`2026-04-Q30`、`2026-04-Q31`、`2026-04-Q33`、`2026-04-Q34`、`2026-04-Q41`、`2026-04-Q42`、`2026-04-Q43`、`2026-04-Q44`、`practice-A-Q08`、`practice-A-Q11`、`practice-A-Q13`、`practice-A-Q20`、`practice-A-Q21`、`practice-A-Q26`、`practice-A-Q27`、`practice-A-Q28`、`practice-A-Q33`、`practice-A-Q34`、`practice-A-Q37`、`practice-A-Q39`、`practice-B-Q08`、`practice-B-Q20`、`practice-B-Q27`、`practice-B-Q28`、`practice-B-Q31`、`practice-B-Q33`、`practice-C-Q01`、`practice-C-Q02`、`practice-C-Q03`、`practice-C-Q04`、`practice-C-Q05`、`practice-C-Q06`、`practice-C-Q07`、`practice-C-Q08`、`practice-C-Q09`、`practice-C-Q10`、`practice-C-Q14`、`practice-C-Q15`、`practice-C-Q17`、`practice-C-Q18`、`practice-C-Q19`、`practice-C-Q20`、`practice-C-Q21`、`practice-C-Q22`、`practice-C-Q26`、`practice-C-Q29`、`practice-C-Q30`、`practice-C-Q31`、`practice-C-Q32`、`practice-C-Q33`、`practice-C-Q34`、`practice-C-Q35`、`practice-C-Q36`、`practice-C-Q37`、`practice-C-Q41`、`practice-C-Q42`、`practice-C-Q44`。

**b（0件）**：該当確定なし。

**c（1件）**：`2026-04-Q25`。

なおJISはJISCで国内登録者の無料閲覧が可能だが、印刷・ダウンロード不可で商用複製等には許諾が必要（https://www.jisc.go.jp/site/kiyaku.html）。閲覧制限だけを理由に有料規格依存と断定しない。**この分類は全件をその場で追証完了したことを意味しない**。

## a群：今回着手した個別成果
1. **演習C Q29（教材生成元変更あり）**：登録の厚労省旧URLから現行Q&A `https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/shokuhin/syokuchu/campylobacterqa.html` へ、最終上書き元`audit/practice_c_fixes_21_30.json`の`sourceRef`と`auditSourceURL`のみを差替え。問題・選択肢・正答index・detailは不変。厚労省Q&Aで生肉器具経由の交差汚染と洗浄・消毒を確認。**264問Node CLI再生成と配布JSON限定差分は本担当未実施**。
2. **演習C Q34（問題データ変更なし）**：既存の副腎髄質原典に加え、NCBI `https://www.ncbi.nlm.nih.gov/sites/books/NBK539845/` の交感神経節後ノルアドレナリン放出、およびヒト心臓の局所神経分布の研究 `https://pmc.ncbi.nlm.nih.gov/articles/PMC12353864/` を追証。副腎髄質と心臓局所伝達を別資料で裏づけた中心命題追証であり、全5肢の独立逐語PASSではない。
3. **演習C Q42（問題データ変更なし）**：NCBI `https://www.ncbi.nlm.nih.gov/sites/books/NBK532978/` とOpenStax Biology 2e `https://openstax.org/books/biology-2e/pages/36-4-hearing-and-vestibular-sensation` で半規管の角加速度を直接確認。小脳の運動協調は既登録OpenStax16.5に依拠。中心命題追証まで、全肢直接PASSではない。

## c群：修正が必要な問題
- **基本2026-04-Q25**：問題文「屋内作業場」は事務所以外を含むが、根拠の事務所衛生基準規則第1条・第3条は「事務所」・「事務室」を対象とする。200㎡の1/20=10㎡、既存8㎡との差2㎡の計算自体は成立するが、対象条件を「事務作業従事者が主として使用する事務室」等に限定する必要がある。今回は**問題データを変更しない**。根拠本文：https://www.mhlw.go.jp/web/t_doc?dataId=74089000 。

## 未解決事項・引き継ぎ
- a群の未処理項目は引き続きOPEN。NCBI `/books/`のreCAPTCHA、e-GovのJavaScript本文抽出不可、RCPA 403、NRA PDF取得障害、教材で旧URLのままの箇所について、設問単位で実際の代替経路・条文と改正時点を確認して修正する。
- 過去の修正済みの解説肢番号（演習B Q09/Q12など）を新たな未修正として二重計上しない。a/c区分は初回台帳のスナップショットのため、閉鎖前に現行264問生成値との照合が必要。
- **問題データ変更は演習C Q29の出典参照2フィールドと監査状態のみ**。生成元1ファイル、追加監査JSON、追加監査Markdownの3ファイル更新。既存の巨大な`CONTENT_REAUDIT_264_20261110.md`は内容保持のため編集せず、この追加監査記録を第14バッチの続編として正本に準じる追記資料とする。
- Node CLI再生成・264問限定差分・Web/iOS配布バイト・SHA256・全1,320肢の逐語証明・商用権利・実機検証は未了。**リリースゲートFAIL/BLOCKED維持**。mainマージ・配信・審査申請なし。
