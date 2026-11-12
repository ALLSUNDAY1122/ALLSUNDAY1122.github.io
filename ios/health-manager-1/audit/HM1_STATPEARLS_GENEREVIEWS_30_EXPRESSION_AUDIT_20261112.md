# 第一種衛生管理者｜StatPearls・GeneReviews参照30問 表現権利・全文照合（2026-11-12）

## 対象・方法・重要な限界
- 対象ブランチ `codex/hm1-integrate-basic-a-b-c-20261111`。調査開始HEAD `53c123ff78c50b329118567493dd7dd65c9fb4aa`。既存の個別原典台帳14ファイル（264問）から登録NCBI Bookshelf記事IDを突合し、StatPearls **29問**、GeneReviews **1問**、合計**30問**（StatPearlsの掲載記事は20固有NBK、GeneReviews 1固有NBK）を抽出した。
- **製品データの生成・修正は実施しない**。基本`Resources/questions.json`、演習A`practice_a_fixes_01_10.json`、演習B`content-overrides-b-20261110.json`、演習C各`practice_c_fixes_*.json`から現行の設問全文、5肢、`detail`全文を取得し、各掲載原典の公開HTML本文の該当する段落・表・例題・説明順と定性的に突合した。
- 判定は**著作権侵害認定でも、独立創作の法的最終証明でもない**。「LOW」は原典の文章・図表・数値事例・固有の説明構成の再録が見られず、一般の学術的事実と独自設計が中心とする**条件付き低リスク**。「REWRITE」は原典の保護され得る説明順序・表現への依存を優先排除すべきもの。英日翻訳の完全な文字列自動照合、制作履歴・他の転載元の監査、権利者の許諾取得は未実施。
- 参考原典は各行のNBKリンク。StatPearlsの掲載書籍は原則**CC BY-NC-ND 4.0**であり、原文・保護表現・翻案文の商用教材配信は別途許諾なしに行わない。GeneReviewsは非商用研究目的に限定。引用・事実参照と、文章や図表の転載・翻案を区別する。StatPearls書籍全体の表示 https://www.ncbi.nlm.nih.gov/sites/books/NBK430685/?report=classic 、GeneReviews権利表示 https://www.ncbi.nlm.nih.gov/sites/books/NBK138602/ 。
- 原典本文の主要照合例：NBK557491では例題の真陽性369・偽陰性15等とアプリの90/10・160/20等を比較。NBK525983のGlycogen metabolism段落は合成促進と分解抑制の説明順が近い。NBK1177のV2/AQP2経路は教材解説の順に近い。これらは事実・数式の一致それ自体を著作物の翻案と断定する根拠ではない。

## 30問のID別判定（設問・5肢・detailを対象）

| 問題ID | 掲載原典 | 判定 | 全文対照での理由・改善方針 |
|---|---|---|---|
| `2025-04-Q37` | [NBK539825](https://www.ncbi.nlm.nih.gov/sites/books/NBK539825/) | 条件付き低リスク | 肺胞換気式と500/150/12の独自計算。原典の文章・例題数値の転用なし |
| `2025-04-Q38` | [NBK544242](https://www.ncbi.nlm.nih.gov/sites/books/NBK544242/) | **解説書換推奨** | 原典の胃での消化→膵酵素の小腸消化という説明順が解説と近い。症例と5肢は独自だが解説再構成推奨 |
| `2025-04-Q43` | [NBK541120](https://www.ncbi.nlm.nih.gov/sites/books/NBK541120/) | 条件付き低リスク | 夜勤・睡眠・勤務間隔の継続評価は独自管理ケース。急性ストレス原典と説明焦点が異なる |
| `practice-A-Q32` | [NBK499818](https://www.ncbi.nlm.nih.gov/sites/books/NBK499818/) | 条件付き低リスク | Bohr効果の一般事実。運動条件と誤肢は独自で原典図表転用なし |
| `practice-A-Q34` | [NBK507850](https://www.ncbi.nlm.nih.gov/sites/books/NBK507850/) | 条件付き低リスク | 血小板減少と凝固因子低下の2ケース、一次/二次止血の公知機序を独自比較 |
| `practice-A-Q37` | [NBK459327](https://www.ncbi.nlm.nih.gov/sites/books/NBK459327/) | 条件付き低リスク | 心室駆出期に限定した弁開閉と逆方向誤肢。共通するのは生理事実 |
| `practice-A-Q38` | [NBK526127](https://www.ncbi.nlm.nih.gov/sites/books/NBK526127/) | 条件付き低リスク | V/Q=0とシャントの原典機序を完全閉塞・隣接正常区域の独自条件で問う。原典の図表・数値転用なし |
| `practice-A-Q39` | [NBK525948](https://www.ncbi.nlm.nih.gov/sites/books/NBK525948/) | 条件付き低リスク | 肺循環の低圧低抵抗と右室後負荷、独自の比較誤肢 |
| `practice-A-Q40` | [NBK526127](https://www.ncbi.nlm.nih.gov/sites/books/NBK526127/) | 条件付き低リスク | V維持/Q減少を設定した高V/Q・死腔様換気の独自対比 |
| `practice-A-Q41` | [NBK547686](https://www.ncbi.nlm.nih.gov/sites/books/NBK547686/) | 条件付き低リスク | SV=EDV-ESV・CO=SV×HRという公知式を130/50/75の独自数値で計算 |
| `practice-A-Q42` | [NBK499897](https://www.ncbi.nlm.nih.gov/sites/books/NBK499897/) | 条件付き低リスク | 階段昇降による狭窄・冠血流予備能の症例。需要供給の一般機序のみ共有 |
| `practice-A-Q43` | [NBK541067](https://www.ncbi.nlm.nih.gov/sites/books/NBK541067/) | 条件付き低リスク | 静脈うっ血とリンパ低下を同時に設定した独自の浮腫判断 |
| `practice-A-Q44` | [NBK538226](https://www.ncbi.nlm.nih.gov/sites/books/NBK538226/) | 条件付き低リスク | MAP近似式を126/78の独自数値で計算。原典表・図再録なし |
| `practice-B-Q30` | [NBK459327](https://www.ncbi.nlm.nih.gov/sites/books/NBK459327/) | 条件付き低リスク | 上腕動脈血圧と左心室圧の混同を独自に判定させる |
| `practice-C-Q17` | [NBK557491](https://www.ncbi.nlm.nih.gov/sites/books/NBK557491/) | 条件付き低リスク | 感度TP/(TP+FN)の一般式。90/10の独自数値で原典例題と不一致 |
| `practice-C-Q18` | [NBK557491](https://www.ncbi.nlm.nih.gov/sites/books/NBK557491/) | 条件付き低リスク | 特異度TN/(TN+FP)の一般式。180/20の独自数値 |
| `practice-C-Q19` | [NBK557491](https://www.ncbi.nlm.nih.gov/sites/books/NBK557491/) | 条件付き低リスク | 閾値前後の70/10→85/25を独自設定。感度・特異度の一般原理のみ共有 |
| `practice-C-Q20` | [NBK557491](https://www.ncbi.nlm.nih.gov/sites/books/NBK557491/) | 条件付き低リスク | NPVの一般式を160/20に適用。原典の558/15の例題数値とは異なる |
| `practice-C-Q21` | [NBK557491](https://www.ncbi.nlm.nih.gov/sites/books/NBK557491/) | 条件付き低リスク | 有病率1%、感度/特異度90%の独自条件でPPV9/(9+99)を算出 |
| `practice-C-Q22` | [NBK557491](https://www.ncbi.nlm.nih.gov/sites/books/NBK557491/) | 条件付き低リスク | 1000人のA/B二検査の独自比較。原典と母数が同じでも症例構成・数値は別 |
| `practice-C-Q30` | [NBK1177](https://www.ncbi.nlm.nih.gov/sites/books/NBK1177/) | **解説書換推奨** | GeneReviewsのV2→AQP2→集合管透過性という説明経路・順序に解説が近い。健常人の浸透圧条件と誤肢は独自 |
| `practice-C-Q31` | [NBK470339](https://www.ncbi.nlm.nih.gov/sites/books/NBK470339/) | 条件付き低リスク | 高Kアルドステロン対高浸透圧ADHの独自比較 |
| `practice-C-Q32` | [NBK500006](https://www.ncbi.nlm.nih.gov/sites/books/NBK500006/) | 条件付き低リスク | TSH・FT4負帰還の一般事実に薬剤影響を除外した検査解釈を組合せ |
| `practice-C-Q33` | [NBK537039](https://www.ncbi.nlm.nih.gov/sites/books/NBK537039/) | 条件付き低リスク | 濾胞細胞T3/T4とC細胞calcitoninの一般機能対比を独自の5肢で判定 |
| `practice-C-Q35` | [NBK525983](https://www.ncbi.nlm.nih.gov/sites/books/NBK525983/) | **解説書換推奨** | 原典Glycogen metabolism節と解説の『合成促進→分解抑制→貯蔵増』の順序が近い。独立資料から解説再設計推奨 |
| `practice-C-Q36` | [NBK541119](https://www.ncbi.nlm.nih.gov/sites/books/NBK541119/) | 条件付き低リスク | 絶食時の糖新生・基質列挙という公知機序を症例条件と独自誤肢に適用 |
| `practice-C-Q37` | [NBK544292](https://www.ncbi.nlm.nih.gov/sites/books/NBK544292/) | 条件付き低リスク | 求心路を維持し遠心路のみ障害する独自反事実条件で脊髄反射を問う |
| `practice-C-Q41` | [NBK544292](https://www.ncbi.nlm.nih.gov/sites/books/NBK544292/) | **解説書換推奨** | 原典序論の『脊髄反射→大脳知覚』に近い説明順。熱刺激の例と誤肢は独自だが解説を再構成推奨 |
| `practice-C-Q44` | [NBK542189](https://www.ncbi.nlm.nih.gov/sites/books/NBK542189/) | 条件付き低リスク | 対光反射と近見反応を明暗A/距離Bで独自に分離。図や原典例の転用なし |

## 件数とデータ変更要否
- **30問レビュー**：条件付き低リスク **26問**、解説の再設計推奨 **4問**、現時点で権利CLEARの断定 **0問**。4問は `2025-04-Q38`、`practice-C-Q30`、`practice-C-Q35`、`practice-C-Q41`。原典事実の再確認だけでなく、別の利用可能な一次・学術資料に照らし、**説明順・論理の展開・言い回しを独自に組み直すことを推奨**する。正答index・5肢を変更する必要があると確定したわけではない。
- **問題データ変更の推奨は4問の`detail`、今回は未適用**。現段階で設問本文・選択肢・正答indexに確定した権利侵害や必須再設計は特定していない。新規執筆後、4問のみに限定した264問再生成・他260問完全一致・正答不変・Web/iOS同期の独立ゲートが必要。
- **除外・別権利者のNCBI掲載問題**：`practice-A-Q31` のNBK54103（Oxygen Transport、StatPearlsではない）と `practice-C-Q34` のNBK26（2001年BIOS Scientific Publishers刊行書籍）はこの**2系列30問集計に含めない**。各別出版社の商用利用規約・表現監査は引き続き別残件。NBK26は心臓局所ノルアドレナリン放出の直接証明不足も別品質課題。
- **OpenStax27問・PMC等は別台帳**。その表現監査結果を本件に重複算入しない。
- 今回のレビューは書き換えや許諾を完了したものではない。**商用公開権利ゲートOPEN／総合品質FAIL/BLOCKED維持**。mainマージ、新規TestFlight、App Store審査申請は実施しない。
