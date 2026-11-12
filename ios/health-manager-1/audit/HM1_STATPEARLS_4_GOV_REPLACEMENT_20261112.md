# HM1 StatPearls権利表示未確定4記事：公的資料への出典差替え監査（2026-11-12）

## 対象と原則
- 対象ブランチ：`codex/hm1-integrate-basic-a-b-c-20261111`。着手時HEAD `639d45621715722fe6d1dc0bb672c0c47687e10b`。
- 出典権利の個別表示を確認できなかったStatPearls記事：NBK499897・NBK541067・NBK500006・NBK542189。製品生成元に登録した対応問題は**4実ID**：`practice-A-Q42`、`practice-A-Q43`、`practice-C-Q32`、`practice-C-Q44`。
- **NIH/NLM/NCI自身が公開する資料**を優先。NCBI Bookshelfに収載されるだけの他出版社StatPearls教材や、PMCに載るだけの民間論文は「米国政府の作成資料」には分類しない。NIH公的資料でも文章・画像の著作権条件は別途確認する。
- 根拠に直接到達した中心命題だけを差し替える。一般向け公的ページは学術的事実の中心を支持するが、誤肢すべての細部まで逐語立証するとは限らない。権利問題と全5肢の正誤監査を別ゲートとして記録。

## 対応4件と出典差替え

| 実ID | 旧StatPearls記事 | 判定 | 新主出典 | 補助出典・原典命題への対応 |
|---|---|---|---|---|
| `practice-A-Q42` | [NBK499897](https://www.ncbi.nlm.nih.gov/books/NBK499897/) | **REPLACED** | NIH/NHLBI [Angina – Causes and Risk Factors](https://www.nhlbi.nih.gov/health/angina/causes) | [CHD Causes](https://www.nhlbi.nih.gov/health/coronary-heart-disease/causes)：運動負荷時の冠動脈拡張・酸素豊富な血流増加と狭窄の制限。[Angina Treatment](https://www.nhlbi.nih.gov/health/angina/treatment)：心筋の酸素需要と供給の均衡。運動で心臓の仕事量が上がると必要な酸素が増え、冠血流の不足で胸痛・虚血が生じ得る（正答index=2） |
| `practice-A-Q43` | [NBK541067](https://www.ncbi.nlm.nih.gov/books/NBK541067/) | **REPLACED** | NIH/NCI [Lymphedema PDQ – Health Professional, Pathophysiology](https://www.cancer.gov/about-cancer/treatment/side-effects/lymphedema/lymphedema-hp-pdq) | NCI [SEER Training – Components of the Lymphatic System](https://training.seer.cancer.gov/anatomy/lymphatic/components/)：毛細血管の静水圧と間質への濾過、余分な間質液のリンパ回収、リンパ障害による浮腫を直接説明。静脈うっ血とリンパ還流低下の組み合わせはこれらの生理事実からの問題独自推論（正答index=0） |
| `practice-C-Q32` | [NBK500006](https://www.ncbi.nlm.nih.gov/books/NBK500006/) | **REPLACED** | NIH/NLM [MedlinePlus – TSH Test](https://medlineplus.gov/lab-tests/tsh-thyroid-stimulating-hormone-test/) | [MedlinePlus – Thyroxine (T4) Test](https://medlineplus.gov/lab-tests/thyroxine-t4-test/)：T4が高いと下垂体がTSHを減らすこと、TSH低値だけでは原因疾患を決定できないことを直接記載。TSH低値・遊離T4高値に整合（正答index=1）。**旧個別出典のCC BY/CC BY-NC-ND版差**に依存しない参照先へ変更 |
| `practice-C-Q44` | [NBK542189](https://www.ncbi.nlm.nih.gov/books/NBK542189/) | **HOLD/UNCHANGED** | 差替えなし | NIH/NEI [About the Eye](https://www.nei.nih.gov/eye-health-information/healthy-vision/nei-for-kids/about-eye)、[Convergence Insufficiency](https://www.nei.nih.gov/eye-health-information/eye-conditions-and-diseases/convergence-insufficiency)、NLM [MedlinePlus – Ciliary body](https://medlineplus.gov/ency/article/002319.htm)、[Anisocoria](https://medlineplus.gov/ency/article/003314.htm)で光と瞳孔、近方調節と毛様体筋、眼球輻輳の個別事実は確認できた。しかし**対光反射に対する近見反応の三徴（調節・縮瞳・輻輳）と入力系の差異・上位制御を一つの公的機関作成資料で直接網羅する証拠が不足**。PMCには同じ機序を記す論文があるが、国立医学図書館で公開されたことだけで公的機関が執筆したとはいえず、出版社の権利条件も別。公的資料への完全差替えは未実施。 |

### 差替えしたフィールドと保存先
- `audit/practice_a_fixes_01_10.json`：A Q42・A Q43の`sourceRef`、`auditSourceURL`をNIH/NHLBI、NIH/NCI公式URLへ差替え。`supportingSourceURLs`、`sourceBasisNote`を追加。
- `audit/practice_c_fixes_31_40.json`：C Q32の`sourceRef`、`auditSourceURL`をNLM MedlinePlus公式URLへ差替え。`supportingSourceURLs`、`sourceBasisNote`を追加。旧`auditSourceURL`にはNBK519566（別のStatPearls）が登録されていたため、主・監査URLを同じNLM公的資料に統一。
- `audit/practice_c_fixes_41_44.json`：C Q44は未変更。個別権利表示未確定のStatPearls引用が残る。
- 修正コミット：A Q42=`359eb07be69d45b1b981d6426c659b109ccff39a`、A Q43=`c2d7c145072d4d186af27af77f95a51eca4ce694`、C Q32=`da9d7a963e804d4df6e156e8df88b535367a092e`。
- **変更した実IDは3件**。問題文`stem`、選択肢`choices`（各5肢）、正答index`ans`、解説`detail`に変更なし。更新JSON構文と各対象の中核属性不変を確認。C Q44も不変。

## 現在の未解決事項・厳密な区分
- **登録出典に残る権利表示未確定StatPearls：4問中1問（C Q44 / NBK542189）**。ほか3問については旧StatPearlsを当該問題の製品出典登録から削除したため、当該4記事の個別権利表示をさらに調査することは、製品出典依存を解消するうえでは必須ではなくなった。ただし旧版の権利者確定と今後の表現転用監査は別の歴史的課題。
- C Q44の**保護表現の商用転載権利未確定・現行出典のライセンス未確認**を継続。出典を変えれば既存問題の表現依存性が自動的に解消するわけではない。先行表現監査の条件付き低リスク判定は維持し、原文・図の転載を行わない。
- A Q42の心拍・収縮力や頻脈と拡張期短縮の説明、C Q44の三徴の詳細など、**全5肢の細部を公的資料だけで個別立証済みではない**。中心命題と全5肢の直接根拠の厳密な個別監査は未完了。
- 本作業は生成元パッチへの適用。**Node CLI 264問再生成、限定差分の実測PASS、配布JSONバイト一致・SHA-256検証は未実施**。次回Muse等で確認し、対象3問の出典関係フィールドだけが変わり、ほか261問・全264問の問題文/5肢/正答/`detail`が不変であることを記録する必要がある。
- 全体の権利監査と品質ゲートは別。**公開品質ゲート FAIL/BLOCKED** を維持。
