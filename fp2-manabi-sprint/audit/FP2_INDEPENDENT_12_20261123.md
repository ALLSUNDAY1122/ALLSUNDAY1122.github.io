# FP2 12問 独立監査（2026-11-23）

対象: `fp2-manabi-sprint/questions/draft/fp2-original-20261123-a.json` / blob `c00e905789eb943d6c56e209a5913bdf4b3a0e23`
基準日: 2026-04-01。制作側の判定は採用せず、公式機関の公開資料と全4肢の整合を照合。PASS 11 / FAIL 1 / HOLD 0。Critical 0 / High 1。

| ID末尾 | 判定 | 理由・全肢確認 | 公式出典 |
|---|---|---|---|
| L01 | PASS | 10年。4肢・解説整合。 | https://www.nenkin.go.jp/service/jukyu/seido/roureinenkin/jukyu-yoken/20150401-02.html |
| L02 | FAIL | High: 指定出典は受給資格期間の用語説明であり、合算対象期間が年金額に反映されない点の直接証拠として不十分。正答①および他3肢の方向性は妥当だが、直接根拠への差替えが必要。 | https://www.nenkin.go.jp/service/yougo/sagyo/jukyushikaku.html |
| R01 | PASS | 地震保険は火災保険に付帯。全4肢整合。 | https://www.sonpo.or.jp/insurance/jishin/index.html |
| R02 | PASS | 30～50％。全4肢整合。 | https://www.sonpo.or.jp/insurance/jishin/index.html |
| F01 | PASS | 一般預金等は元本1000万円と破綻日までの利息等。全4肢整合。 | https://www.fsa.go.jp/policy/payoff/index.html |
| F02 | PASS | 120+240=360万円。1800万円は生涯非課税保有限度額。全4肢整合。 | https://www.fsa.go.jp/policy/nisa2/know/index.html |
| T01 | PASS | 200万円以上なら10万円。全4肢整合。 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1120.htm |
| T02 | PASS | 16歳以上。全4肢整合。 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1180.htm |
| E01 | PASS | 80/200=40％。25％、60％、250％の説明も計算上整合。 | https://www.thr.mlit.go.jp/bumon/b00093/k00490/eizen/hozen/word/w_02ka.html |
| E02 | PASS | 300/150=200％。全4肢整合。2017年資料のため2026年施行時点の法令リンク併記を推奨。 | https://www.mlit.go.jp/common/001205298.pdf |
| S01 | PASS | 3000+600×3=4800万円。全4肢整合。 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/sozoku/4102.htm |
| S02 | PASS | 暦年課税の基礎控除110万円。全4肢整合。 | https://www.nta.go.jp/taxes/shiraberu/taxanswer/zoyo/4410.htm |

## 是正事項
- L02: 日本年金機構の「合算対象期間（カラ期間）」の定義と年金額不算入を直接記載した一次資料にsource_urlとsource_sectionを差し替え、再監査すること。
- 共通: `source_section` が全問「該当制度の基本規定・制度説明」であり証拠箇所を特定できない。各問の節名・該当記述へ具体化すること。これは今回の正答判定とは別のトレーサビリティ改善事項。
- 法令基準日: 国税庁3問はページ上の令和8年4月1日現在表示を確認。その他は制度説明と整合を確認したが、全URLの2026-04-01時点スナップショットの固定は未実施。権利・逐語類似監査は本監査の範囲外。
