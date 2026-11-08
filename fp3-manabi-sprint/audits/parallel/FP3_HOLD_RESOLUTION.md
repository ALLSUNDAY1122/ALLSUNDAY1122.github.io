# FP3保留21問・追加一次資料照合（FP3_HOLD_RESOLUTION）

実施日: 2026-11-09 JST。主記録、2025/2026外部シャード、並列監査シャード（2024-A/B/C、2025-B/C、2026-B）を確認し、保留IDの重複を除去。2024年度7問、2025年度9問、2026年度5問。

## 方法と射程
ロック済みJSON内の対象21問の問題文・選択肢・正答・解説を読取り、追加取得した公的機関・制度運営主体・業界団体の一次公開資料と制度論点を照合。PASSは制度論点と登録正答の一致に限定。日本FP協会原典PDFと全設問・全選択肢の逐語照合は未実施であり、製品リリース承認ではない。法令基準日: 2024年度2023-04-01、2025年度2024-04-01、2026年度2025-04-01。現行CBT参照2026-04-01。後年の公開情報を出題時点に無条件遡及しない。

| ID | 判定 | 根拠・処置 | 一次資料 |
|---|---|---|---|
| fp3-2024-21 | PASS | 登記事項証明書は何人も交付請求可。false維持 | https://laws.e-gov.go.jp/law/416AC0000000123/20260401_503AC0000000024 |
| fp3-2024-22 | PASS | 借地借家法29条。普通借家1年未満は期間定めなし。true維持 | https://laws.e-gov.go.jp/law/403AC0000000090?occasion_date=20210825 |
| fp3-2024-25 | PASS | 国交省の等価交換方式の権利配分と整合。建設協力金方式との混同を否定。false維持 | https://www.mlit.go.jp/kisha/kisha08/03/030328/05.pdf |
| fp3-2024-31 | PASS | 日本FP協会CFP試験資料で減債基金係数を確認。選択肢3維持 | https://www.jafp.or.jp/aim/cfp/cfp_exam/files/2026_01_CFP03_q.pdf |
| fp3-2024-35 | PASS | 住宅金融支援機構は同条件では元利均等返済の総返済額が多いと説明。選択肢1維持 | https://www.flat35.com/loan/lineup/kinto/index.html |
| fp3-2024-41 | UNVERIFIED | グロース運用の定義に関する運用機関等の一次資料の直接照合未了 | 未確認 |
| fp3-2024-43 | PASS | GPIFはポートフォリオ期待収益率を構成比加重平均と明記。2%×0.4+5%×0.6=3.8%、選択肢2維持 | https://www.gpif.go.jp/operation/h20_q4.pdf |
| fp3-2025-04 | PASS | 厚労省のiDeCo加入対象に第3号被保険者を明記。true維持 | https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/nenkin/kyoshutsu/ideco.html |
| fp3-2025-08 | UNVERIFIED | 女性の平均余命が長い統計は確認したが同条件の男女別終身年金保険料の一次料率未確認 | https://www.jili.or.jp/lifeplan/lifesecurity/1043.html |
| fp3-2025-09 | UNVERIFIED | 一般傷害保険は細菌性食中毒免責の例あり。国内旅行傷害保険固有の補償・約款を確認できず | https://soudanguide.sonpo.or.jp/body/q070.html |
| fp3-2025-10 | PASS | 日本損害保険協会は人身傷害を過失割合にかかわらず保険金額まで所定実損補償と明記。true維持 | https://www.sonpo.or.jp/report/publish/bousai/koutuu/article/6/ |
| fp3-2025-11 | PASS | 日銀論文は米国金利上昇によるドル高・円安の推計を提示。他条件一定の要因としてtrue維持 | https://www.boj.or.jp/research/wps_rev/wps_2025/wp25j02.htm |
| fp3-2025-12 | PASS | 金融教育一次資料は公社債投信は株式を一切組み入れないと説明。true維持 | https://www.j-flec.go.jp/links/jikan/qa/052.html |
| fp3-2025-13 | PASS | 公的金融教育資料で債券価格と市場金利は逆方向と明記。false維持 | https://www.j-flec.go.jp/links/jikan/qa/013.html |
| fp3-2025-25 | UNVERIFIED | 建設協力金方式と事業受託方式の正確な対比について公的な定義の直接照合が未了 | https://www.mlit.go.jp/kisha/kisha08/03/030328/05.pdf（方式比較のみ） |
| fp3-2025-53 | PASS | 国交省研究資料で区分所有法14条1項の床面積割合と4項の規約別段規定を確認。選択肢3維持 | https://www.nilim.go.jp/lab/ieg/tasedai/shiryou/110228_2_3_1.pdf |
| fp3-2026-20 | PASS（解説更新要） | 所得一律58万円は誤り、false維持。2025年分の表と2026年分適用・2026-12-01施行の改正を明確に区別。法令基準日2025-04-01と現行試験2026-04-01も別記 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1199.htm ; https://www.nta.go.jp/users/gensen/2026kiso/index.htm |
| fp3-2026-25 | PASS | 国交省の事業受託方式は土地・建物所有権が土地所有者で開発業者等が事業実行者。デベロッパー全額建設拠出という断定は誤り、false維持 | https://www.mlit.go.jp/kisha/kisha08/03/030328/05.pdf |
| fp3-2026-31 | PASS | 日本FP協会公式提案書作成教材が前年貯蓄残高×(1＋運用率)＋当年収支と明記。選択肢1維持 | https://www.jafp.or.jp/aim/afp/training/proposaltool/files/e-book_proposaltool.pdf |
| fp3-2026-38 | PASS | 日本損害保険協会の飲食店食中毒事例はPL保険による対応と明記。選択肢1維持。支払には約款条件あり | https://www.sonpo.or.jp/sme_insurance/explanation/article05/ |
| fp3-2026-57 | UNVERIFIED | 子孫・祖父母等先順位の不存在、全血/半血、他兄弟姉妹・代襲者の有無が不明。兄1/8を唯一正答として確定不可。設問条件補足要 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/sozoku/4132.htm |

## 集計
- 対象21件：PASS 16、FAIL 0、UNVERIFIED 5。未解消ID: 2024-41、2025-08、2025-09、2025-25、2026-57。
- 2026-20は制度論点PASS。ただし2026年度改正の施行日・適用年分を解説へ追記する必要があり、変更未適用。2026-57は設問条件に不足があり保留。
- 公式原典PDF逐語照合、2026-20を含む解説修正反映の独立検証、権利・加工表示を完了していないため製品ゲートはBLOCKED。
- ロック済みquestion_bank_180.payload.json、SOURCE_LOCK.md、正答・設問・選択肢・解説本体・アプリコードは無変更。
- FP3-26-HOLDの制度論点照合は完了。21件全件解消とは扱わない。
