# FP3級・2026年度分 内容再監査 SHARD（2026-11-08 JST）

- 対象リポジトリ: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- 対象ブランチ: `codex/fp-release-preparation-20261107`
- 参照: `fp3-manabi-sprint/audits/CONTENT_REAUDIT_20261108.md`（同ファイルは無変更）
- 参照問題データ: `fp3-manabi-sprint/question_bank_180.payload.json`（読み取りのみ）
- 対象: 未判定の2026年度分のうち `fp3-2026-16〜19`、`fp3-2026-21〜36` の20問。既判定 `01〜15` と `20` は除外。
- 原典時点: 各問 `law_basis_date=2025-04-01`。現行CBT法令基準日 `2026-04-01` とは区別。
- 監査方法: 各問の設問・選択肢・正答・解説をJSONから直接確認し、行政機関・公的制度実施機関の一次資料と制度論点を照合。旧 `final_audit_result` のPASSを流用せず判断した。
- **監査範囲の限界:** 日本FP協会公式原典PDFの全設問・選択肢との逐語突合は未実施。「合格」は制度論点とアプリ正答・解説の整合に限定し、リリース許可を意味しない。

## 個別判定

| ID | 判定 | JSON正答 | 一次資料照合・理由 | 一次資料URL |
|---|---|---|---|---|
| fp3-2026-16 | 合格 | false | 源泉分離課税は支払時の源泉徴収で完結。申告分離課税と区別され、現行正答・解説と整合。 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/2230.htm |
| fp3-2026-17 | 合格 | true | 公的年金等の雑所得＝年金収入－公的年金等控除。 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1600.htm |
| fp3-2026-18 | 合格 | true | 総合課税の長期譲渡所得は特別控除後の2分の1を総合課税に算入。土地建物・株式とは別。 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/joto/3152.htm |
| fp3-2026-19 | 合格（注記推奨） | false | 原則3年であり10年は誤り。ただし特定非常災害による一定の純損失には5年の例外があり、解説の『原則』は維持する。 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/2070.htm |
| fp3-2026-21 | 合格 | true | 土地・家屋の固定資産評価替えは原則3年ごと。例外的な価格修正等は別途存在。 | https://www.tax.metro.tokyo.lg.jp/shitsumon/real_estate/o |
| fp3-2026-22 | 合格 | false | 定期建物賃貸借は1年未満も有効。普通借家と区別。 | https://www.mlit.go.jp/common/001334935.pdf |
| fp3-2026-23 | 合格 | true | 市街化区域内の農地の自己転用は農業委員会への事前届出による例外。農地法4条の届出手続と整合。 | https://www.maff.go.jp/j/keiei/koukai/nouchi_seido/pdf/j1-1.pdf |
| fp3-2026-24 | 合格 | false | 固定資産税の賦課期日は毎年1月1日。4月1日ではない。 | https://www.tax.metro.tokyo.lg.jp/kazei/real_estate/kotei_tosi |
| fp3-2026-25 | 保留 | false | 建設資金の負担主体を明示した公的な事業受託方式の一次資料を今回確認できず、デベロッパー全負担の否定が妥当でも独立合格にはしない。 | 未確認（事業方式別の行政一次資料の要取得） |
| fp3-2026-26 | 合格 | true | 合計所得金額は原則2,000万円以下。40㎡以上50㎡未満は1,000万円以下。 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/sozoku/4508.htm |
| fp3-2026-27 | 合格 | true | 配偶者＋兄弟姉妹の場合、配偶者の遺留分は1/2、兄弟姉妹はなし。 | https://www.moj.go.jp/content/001395858.pdf |
| fp3-2026-28 | 合格（適用条件注意） | false | 暦年贈与の加算対象は原則として相続等で財産を取得した者。相続時精算課税等の特殊条件を混同しない。 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/sozoku/4161.htm |
| fp3-2026-29 | 合格 | false | 2割加算の除外は配偶者・一親等の血族等。父母は対象外、兄弟姉妹は原則対象。 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/sozoku/4157.htm |
| fp3-2026-30 | 合格 | true | 相続開始を知った時から原則3か月以内に家庭裁判所へ申述。期間伸長の制度あり。 | https://www.courts.go.jp/saiban/qa/qa_kazi/index.html |
| fp3-2026-31 | 保留 | 1 | 『前年末残高×(1＋運用利率)＋当年年間収支』は一般的な期末収支仮定の式として整合するが、今回公式出題原典またはFP協会の一次教材で選択肢を独立照合できず保留。 | 未確認（日本FP協会の公式出題PDF・一次解説の要取得） |
| fp3-2026-32 | 合格 | 2 | 介護保険法9条の第2号被保険者は40歳以上65歳未満の医療保険加入者。 | https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/hukushi_kaigo/kaigo_koureisha/nintei/gaiyo4.html |
| fp3-2026-33 | 合格 | 1 | 付加年金年額は200円×付加保険料納付済月数。400円は月額掛金。 | https://www.nenkin.go.jp/service/yougo/hagyo/fukanenkin.html |
| fp3-2026-34 | 合格（例外注意） | 3 | 原則報酬比例部分の3/4。65歳以上の一定の配偶者には比較計算の特例があるため解説に注記推奨。 | https://www.nenkin.go.jp/service/jukyu/seido/izokunenkin/jukyu-yoken/20150424.html |
| fp3-2026-35 | 合格 | 3 | 国の教育ローンは固定金利、返済期間最長20年。 | https://www.jfc.go.jp/n/finance/ippan/pdf/kyouiku_leaflet.pdf |
| fp3-2026-36 | 合格 | 3 | 保険法95条で保険給付請求権と保険料返還請求権の時効は行使可能時から3年。 | https://laws.e-gov.go.jp/law/420AC0000000056 |

## 集計と残件

- 今回20件: **合格18件、要修正0件、保留2件**（保留: `fp3-2026-25`、`fp3-2026-31`）。
- 主監査記録の既判定: 合格17、要修正2、保留1、未判定160（2026年度分は01〜15合格・20保留）。
- 本SHARDを合算した全180問の進捗: **合格35、要修正2、保留3、未判定140**。
- 2026年度60件の進捗: 合格33（01〜19のうち20以外＋21〜36の合格18）、保留3（20・25・31）、未判定24（37〜60）。
- 判定保留は未判定件数から除外して管理する。
- `fp3-2026-19` の5年例外、`fp3-2026-34` の遺族年金の比較計算は正答への影響なしだが説明追記候補。
- 他年度（2024・2025）とロック済み問題データ、正答・選択肢・解説、`SOURCE_LOCK.md` を変更しない。
- 全問題の公式原典逐語監査が終了するまで、製品ゲートは **BLOCKED** 継続。
