# 第一種衛生管理者｜264問 権利監査の全体総括・残件台帳（2026-11-12）

## 0. 証拠の前提と全体判定
- ブランチ `codex/hm1-integrate-basic-a-b-c-20261111`、直前HEAD `c87f1f90feb12564b3136682911a0c4b6106e408`。
- **監査した「問題ID件数」は過去の参照URLに基づく履歴集合で、出典差替え後の現行依存数と異なる**。各系統の件数は重複・変更時点差があるため単純合算しない。外部資料がNCBI/PMCの公的掲載プラットフォームに載ることと、米国政府が著作者であることは異なる。
- **結論：公開品質ゲートFAIL/BLOCKEDのまま**。原典にある学術的事実を参考にして独自表現で問題を作ることと、原典の文章・図表・翻訳を商用アプリに転載・翻案することを区別する。問題の独自表現の確認は、出版社ライセンスの商用再利用許諾とは別の判定。

## 1. 出典系統別の対応履歴と残るリスク

| 系統 | 監査・照合した範囲（履歴） | 再設計・書換え・出典差替えでの対処 | 今残る権利・品質のリスク |
|---|---|---|---|
| **OpenStax** | **27問**（優先12問・残15問）について設問・5肢・解説の英語原典との表現・構成の照合を実施。旧版・現行版の利用条件を区別。 | **14問を再設計**（先行7＋追加7）。原典の列挙・構成を避けた独自条件判断へ組み直した。**2問の出典関連修正**という先行作業報告を継承するが、個別の適用範囲は履歴台帳で照合する。 | 現行A&P 2e等はCC BY-NC-SAの非商用条件。旧A&PはCC BY表示と非商用表記の矛盾が残り、商用転載の判断には版を固定した権利確認要。再設計済みでも原典の保護表現を利用していないことの法的最終証明ではなく、全27問の現行出典依存・帰属・全文監査の最終判定は未完了。特に`practice-B-Q31`のNHLBI根拠は中心命題の全要素を単独立証できず、`practice-B-Q32`は旧版表示の版別判定が必要。 |
| **StatPearls** | 対象は元台帳で**20固有記事・28問**。個別記事のCC BY-NC-ND 4.0表示確認は**16/20記事**。残り4記事はBookshelf本文にreCAPTCHA等で到達できず、個別のライセンスフッター確認未達。 | 設問・5肢・解説の表現照合を行い、独立性を高めるため`2025-04-Q38`・`practice-C-Q35`・`practice-C-Q41` の**3問detail書換え**。未確認4記事のうち`practice-A-Q42`（NBK499897）・`practice-A-Q43`（NBK541067）・`practice-C-Q32`（NBK500006）の**3問をNIH/NCI/NLM公式資料へ出典差替え**し、Museが264問の限定差分PASSを報告。 | **`practice-C-Q44`（NBK542189）のStatPearls出典は維持**。現行の個別ライセンス未確定（書籍全体にはCC BY-NC-ND、商用文章転載・翻案は許諾なし不可）。従来の残り3記事も個別権利条件の歴史的未確認は継続するが、上記3問は製品登録出典としては参照を外した。**NBK500006は旧版CC BY表示と現行書籍CC BY-NC-ND表示の版差**が未確定。ほかのStatPearls参照問題も出版社の表現を転載してよいと承認したわけではない。 |
| **GeneReviews** | `practice-C-Q30` **1問**を個別全文対照。University of Washingtonの非商用研究目的に限定する複製条件を確認。 | `practice-C-Q30`の**detailのみ独自構成へ書換え**。StatPearls3件と合わせ計4問書換え。Museが4問限定差分detail-only、問題文・5肢・正答不変をPASS報告。 | 非商用限定の原典表現を無断で商用転載・翻訳できない。問題は条件付き低リスクとするが、権利者許諾や独立執筆履歴の最終証明はない。現行`sourceRef`はGeneReviews NBK1177であり、公式資料への出典差替えは未実施。 |
| **PMC論文** | `practice-C-Q24`（PMC3302369）・`practice-C-Q39`（PMC6932299）の**2論文・2問**。各論文の個別著作権者を照合し、設問・5肢・解説全文と原典の説明・図表・数値例を対照。 | **2問とも出典は学術的事実の参照のみ**と条件付き判定。前者の2,400/2,100kcal・0.4kgの独自例、後者の運動時迷走神経/交感神経の独自5肢を確認。原典の文章・表・特有の実験データの転載・翻案は認められず、**問題データ変更不要**。 | ©2012 American Society for Nutrition・©2013 Wiley Periodicalsの保護表現に商用転載を認める明示ライセンスは未確認。権利者に許諾を得たわけではない。表現の「非転載」は既存記録の定性的判定で、作成履歴・英日全文機械照合の法的証明ではない。全5肢独立逐語直接立証は未完了。 |
| **NCBI Bookshelf内の別出版社** | `practice-A-Q31`（Morgan & Claypool Life Sciences、NBK54103）、`practice-C-Q34`（BIOS Scientific Publishers、NBK26）の**2問**全文照合。 | 2問とも条件付き低表現リスク。A31の**detail内誤肢番号4→1を訂正**、C34は心臓交感神経終末に関する直接根拠**NBK597441（Springer刊行資料）へ主出典差替え**、旧NBK26を補助出典として保持。MuseがA31 detailのみ、C34出典関係のみの限定差分PASS報告。 | 両原著書や新Springer資料は**NCBIに収載されていても米国政府著作物ではない**。商用転載・翻案の包括許諾を確認できない。C34の直接内容根拠は補強済みでも、権利ライセンスを持つものではない。 |
| **米国政府公式資料（NIH/NLM/NCI/NHLBI等）** | 上記の出典変更と再設計で一般的・専門的な科学事実の直接根拠として参照。 | StatPearls未確定3問をNIH/NCI/NLMサイトへ出典差替え済み。OpenStax再設計の一部でもNIH等の公的資料を採用。 | **出典変更だけで権利CLEARにはならない**。公式サイトに含まれる第三者画像・転載物・個々の出典の施行日/改訂日と、すべての誤肢の直接的根拠の点検が別途必要。 |

## 2. 限定差分の受領・確認履歴（Muse報告）
| 単位 | 検証の結論 | 証拠の帰属 |
|---|---|---|
| StatPearls/GeneReviews `2025-04-Q38`, `practice-C-Q30/Q35/Q41` | **PASS**：4問の`detail`のみ変更、全264問の問題文・5肢・正答不変 | Museローカル再生成（ユーザー提供）。`HM1_STATPEARLS_GENEREVIEWS_4_DETAIL_REWRITE_20261112.md` |
| NCBI別出版社 `practice-A-Q31`, `practice-C-Q34` | **PASS**：A31は`detail`のみ、C34は出典関係フィールドのみ、問題文・5肢・正答不変 | Museローカル再生成（ユーザー提供）。`HM1_A31_C34_SOURCE_CORRECTION_20261112.md` |
| StatPearls未確定4記事対策の `practice-A-Q42/Q43`, `practice-C-Q32` | **PASS**：指定3問の**出典関係フィールドのみ**変更、全264問の`stem`・`choices`・`ans`・`detail`不変、他261問完全一致 | Museローカル再生成（ユーザー提供）。`HM1_STATPEARLS_4_GOV_REPLACEMENT_20261112.md` |

**証拠の限界**：本総括執筆時にMuseのローカル実行ログ、Web/iOS配布JSONのバイト一致、SHA-256を独立計測していない。個別報告のPASSを「全品質ゲートPASS」と拡張しない。

## 3. 横断的な閉鎖済み／未閉鎖事項
### 閉鎖済み
- **出典4フィールド空欄20件の疑義は、製品データ上欠損0/264とMuseが検証し、「製品データに空欄なし」で閉鎖**。20件は権利一覧の抽出行に由来した可能性があるが、原票との原因特定は未了。参照：`HM1_EMPTY_SOURCE_URL_20_HANDOFF_20261112.md`。
- 上記の個別改修と限定差分の**生成元反映・Muse検証**は完了。ただし配布ファイルの再現性・全問題の独立最終承認ではない。
### 継続
1. **最優先**：`practice-C-Q44`（NBK542189）の出典を直接根拠のそろう公的資料へ変えるか、個別記事のライセンス・表現独立性の追跡を完了する。単に近見調節と輻輳の個別事実が記載された資料を見つけただけでは、光反射との区別を含む設問全体の直接根拠として差し替えない。
2. **個別版の権利**：未確認記事NBK499897・NBK541067・NBK500006・NBK542189について現行の個別ライセンスフッター／権利者回答が未完了。旧版と現行版の条件差に注意。現行製品に直接残るのはQ44のNBK542189だけ。
3. **OpenStax旧版／残る参照**：`practice-B-Q32`の旧版CC BYと非商用文言の矛盾、`practice-B-Q31`の混在出典・権利/直接命題の厳密照合、14問再設計後の未再設計分と資料権利の最終承認。
4. **一般の権利者資料**：GeneReviews NBK1177、その他StatPearls記事、PMC2論文、NCBIのMorgan & Claypool/BIOS/Springer資料について、**保護される原文・図表を商用転載するなら個別の許諾または明示ライセンスが必要**。参照URLだけを登録し独自表現で出題することを禁止と断定しない。
5. **問題内容／配布の品質**：全264問×5肢の直接独立根拠、法令の施行日と出典改訂日、定量値・正答唯一性、Web/iOS配布バイト一致・SHA-256、必要な実機/審査検証を独立ゲートとして継続する。
- **公開・mainマージ・新規TestFlight・App Store審査提出はしない**。最終判定 **FAIL/BLOCKED**。新たな問題データ変更はこの総括作成時には実施しない。

## 4. 主要監査参照
- `OPENSTAX_12_EXPRESSION_FULLTEXT_20261112.md` / `OPENSTAX_REMAINING_15_FULLTEXT_20261112.md`：OpenStax 27問の表現全文照合。
- `OPENSTAX_SEVEN_APPLIED_VALIDATION_20261112.md` / `OPENSTAX_SECOND_SEVEN_APPLIED_35_CHOICE_EVIDENCE_20261112.md`：OpenStax 14問再設計。
- `HM1_STATPEARLS_GENEREVIEWS_29_EXPRESSION_AUDIT_20261112.md` / `HM1_STATPEARLS_GENEREVIEWS_4_DETAIL_REWRITE_20261112.md`：29問監査・4問解説書換え。
- `HM1_NCBI_RIGHTS_REMAINING_STATPEARLS_PMC_20261112.md`：StatPearls16/20個別表示・PMC2論文権利・独立表現判断。
- `HM1_A31_C34_SOURCE_CORRECTION_20261112.md` / `HM1_NCBI_OTHER_PUBLISHERS_A31_C34_RIGHTS_EXPRESSION_20261112.md`：NCBI別出版社2問の対照・修正。
- `HM1_STATPEARLS_4_GOV_REPLACEMENT_20261112.md`：StatPearls未確認4記事と3問のNIH等への出典差替え、Muse限定差分PASS。
- `HM1_EMPTY_SOURCE_URL_20_HANDOFF_20261112.md`：出典欠損疑義の閉鎖。

## 5. 追加対応（2026-11-12）：演習C Q44 の StatPearls 登録依存解消

- 対象：`practice-C-Q44`（出典旧登録：StatPearls NBK542189）。着手時HEAD `47ada402a1e9ed53a119c04d3ea5c2e500ef1be5`。
- **主出典（公立大学が公開する医学部教材）**：University of Utah School of Medicine / Suzanne Stensaas, *Visual Reflexes* (2012) [公開講義PDF](https://anatomy.med.utah.edu/diganat/SOM/dental.neuro/06.c%20VisReflex%20dental%20annot%202012.pdf)。PDF p.1で視蓋前域を介する対光反射、p.5で「光に対する縮瞳」と「近見反応の三要素（調節・輻輳・縮瞳）」を別項目として直接説明。同p.5に虹彩括約筋、毛様体筋、チン小帯の緊張低下に関する記述がある。これは**公立大学の公開教材であって連邦政府著作物ではない**。
- **補助出典**：NIH/NEI [Convergence Insufficiency](https://www.nei.nih.gov/eye-health-information/eye-conditions-and-diseases/convergence-insufficiency) は近方視時の両眼の内転（輻輳）、NLM [MedlinePlus Ciliary body](https://medlineplus.gov/ency/article/002319.htm) は毛様体・水晶体調節、NLM [MedlinePlus Standard eye exam](https://www.medlineplus.gov/ency/article/003434.htm) はペンライト刺激による瞳孔収縮の確認を補強する。
- **登録変更**：生成元 `audit/practice_c_fixes_41_44.json` のQ44に限り、`sourceRef` と `auditSourceURL` を同一のUtah PDF URLへ差し替え、`supportingSourceURLs` 3件と `sourceBasisNote` を付記し、監査状態 `auditStatus` を更新。**`stem`・`choices`（5肢）・`ans`（index 3）・`detail` は不変**（更新時の対象オブジェクト比較）。旧NBK542189は当該製品生成元の登録出典から除外。変更コミット `5cff1b6a4fe1965a7c5dbc8891c2aa9c697e7b0c`。
- **判定**：登録された未確認4記事のうち、製品出典としての残依存は **0/4**（先行3問＋今回Q44）。これは**StatPearlsシリーズ全体の参照ゼロや商用権利CLEARを意味しない**。Utah教材の画像・テキスト等は第三者素材を含む可能性があり、科学的事実のみ参照し、文章・図表の転載や翻案を行わない。近見反応の上位経路・対光反射との入力相違、全5肢の細部を独立に立証するゲート、既存問題の表現類似性は継続する。
- **検証限界**：出典ページの該当箇所を確認し、変更対象オブジェクトの固定4フィールドを更新前後で比較した。Node CLIによる264問再生成、他263問完全一致、Web/iOS配布物バイト一致、SHA-256、独立権利審査は本作業では実施していない。次回は限定差分と配布物の再現性を独立検証する。
- **リリース判定：FAIL/BLOCKED 維持**。mainへのマージ・TestFlight新規配布・App Store審査申請は行わない。

> 本節は前掲「未解決事項」のQ44未差替え記載を**後続の履歴として更新**する。先行時点の表を遡及改変しない。現在の個別ライセンス未確認という歴史的事項も消去しない。
