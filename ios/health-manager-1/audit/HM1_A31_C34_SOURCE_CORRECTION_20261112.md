# 第一種衛生管理者：演習A Q31 解説誤肢番号訂正・演習C Q34 直接出典補強（2026-11-12）

## 実施内容
- 作業開始HEAD：`570bf52dbf2d17b7df57c59d836ec7fa0bb33fe2`。対象は `practice-A-Q31` と `practice-C-Q34` の2問。生成元ファイルを更新し、問題文・5肢・正答indexを維持。
- A Q31（`audit/practice_a_fixes_01_10.json`）：解説の「4は溶存酸素の自動補償を誤認」を「肢1は溶存酸素の自動補償を誤認」に訂正し、他の誤肢番号に「肢」を補う。誤肢番号を正すのみで正答index=4、問題文・選択肢等は変更なし。
- C Q34（`audit/practice_c_fixes_31_40.json`）：旧`sourceRef`と`auditSourceURL`のNCBI NBK26を、心臓交感神経節後ニューロンのノルアドレナリン放出を**直接記述する** `https://www.ncbi.nlm.nih.gov/books/NBK597441/` に差し替え。旧NBK26は`supportingSourceURL`に残し、両資料と命題の関係を`sourceBasisNote`へ登録。問題文・5肢・正答index=3・解説`detail`は不変。

## C Q34 の公的データベース収載根拠
1. **主根拠**：Crystal M. Ripplinger, **Neural Regulation of Cardiac Rhythm** (2022-09-21), in *Cardiovascular Signaling in Health and Disease*, Springer, NCBI Bookshelf ID **NBK597441**。URL：https://www.ncbi.nlm.nih.gov/books/NBK597441/ 。節「Sympathetic Innervation」「Adrenergic Signaling」に、心臓の交感神経節後ニューロンが主にノルアドレナリンを放出することと、副腎髄質からのエピネフリンが血中を介して心臓に作用することを記す。NCBIの索引本文・PubMed書誌 https://pubmed.ncbi.nlm.nih.gov/37988489/ でも掲載章と著者・日付・出版者を確認した。
2. **補助根拠（旧出典保持）**：Stephen Nussey / Saffron Whitehead, *Endocrinology: An Integrated Approach*, Chapter 4, **The adrenal gland** (2001), BIOS Scientific Publishers, **NBK26**。URL：https://www.ncbi.nlm.nih.gov/books/NBK26/ 。副腎髄質への交感神経節前線維の入力とカテコールアミンの血中分泌の説明に対応する。
3. **権利上の注意**：NCBI BookshelfはNIH傘下の公的資料プラットフォームであるが、**NBK597441は米国政府著作物ではなく、Springer刊行の著作物**（ページ権利表示は© The Author(s), exclusive license to Springer Nature Switzerland AG 2022）。NCBIで無料閲覧できることと商用転載許可を混同しない。今回は医学的事実の裏付けとしてリンク・書誌情報を追加し、原文・図・表の転載や翻案は行っていない。事実の参照と著作物再利用の権利問題は別途最終監査。

## 検証と適用範囲
| ID | 生成元 | 変更フィールド | 不変を確認したフィールド | 変更コミット |
|---|---|---|---|---|
| `practice-A-Q31` | `audit/practice_a_fixes_01_10.json` | `detail`のみ | `stem`、`choices`（5肢）、`ans`=4、出典 | `895d5bc9ae33b5f95cde1d70669768ab34ec095c` |
| `practice-C-Q34` | `audit/practice_c_fixes_31_40.json` | `sourceRef`、`auditSourceURL`、`supportingSourceURL`、`sourceBasisNote` | `stem`、`choices`（5肢）、`ans`=3、`detail` | `774b77f4dd3534dbb7006e386ca96a2bff0f3312` |

- 更新JSONのパース、対象オブジェクトの問題文・5肢・正答・Q34の`detail`不変をチェック。GitHubの各コミット差分を再取得し、**2つの対象ファイルに限定した差分**を検証。
- **生成パイプラインでの取込み**：`augment-to-264.cjs` は選別後に `practice_a_fixes_01_10.json` と `practice_c_fixes_31_40.json` を読み、対象IDへ上書きする既存仕組みのため、次回再生成に反映される。
- **未実施**：本セッションでのNode CLIによる前後264問の独立再生成・限定差分実測、配布JSONのWeb/iOSバイト一致・SHA-256検証・配布更新。本段階で実際の264問再生成をPASSとは主張しない。
- 残件：次回の独立264問限定差分確認（想定はA Q31の`detail`とC Q34の出典関係項目のみ、他262問一致）、公開に必要な権利・法令・全問内容ゲート。**公開品質ゲート FAIL/BLOCKED 維持**。mainマージ、新規TestFlight、App Store審査申請は行わない。
