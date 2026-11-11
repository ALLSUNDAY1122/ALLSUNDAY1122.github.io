# 第二種衛生管理者｜178問最終ゲート・固定ID証跡対照表（初回照合・2026-11-12）

**性質**：本表は独立レビュー待ち178問のIDを現在の配布JSON・固定170問台帳・既存個別出典監査バッチに突き合わせた**開始版**。**一次資料URLが存在することや監査記録にIDがあることは、独立専門家査読・条文全肢逐語確認・修正コミットとの照合合格を意味しない**。

## 対象集合の再現性と判定規則

- 出典：正本生成経路で得られる`contentReviewStatus`が`requires-independent-legal-review`、`requires-independent-specialist-review`、`requires-independent-subject-expert-review`に該当する問題ID。実行時に得られた件数は**法令44、専門20、科目専門114、計178問**。以下の明細はこの同定済みID集合と現行配布JSONをID突合して構築した。
- **ID178一意・全件配布JSON内に存在**。正式固定170問台帳と重なるもの**108件**、X-01第1〜13バッチにIDが記録されるもの**67件**、正式固定170第1〜17バッチにIDが記録されるもの**109件**。初期是正3問との対応は別台帳を追跡する。**文書中にIDがない場合でも未監査とは断定しない**。
- 各行で確認するもの：①現行設問・5肢・正答・解説、②現行`source_url`から到達できる一次資料本文と規制版、③現在の題意への根拠直接性、④修正対象なら旧→新差分とコミット、⑤該当IDの独立専門家・法令レビューの結論、⑥現在の実出題データとの一致。**欠けるものがあれば保留。**
- 表中「URL候補」は**現在のJSONのURLを写したもので、取得成功や条文適合を表明していない**。「未特定」はこの初回段階でのコミットとの対応未確定を指す。**全178問について機械的なリリース合格変更を行わず、従前のレビュー待ちマーカーを維持**。

## 178件個別照合の着手明細

| 実ID | 独立レビュー | 固定170 No. | 現行topic | 既存個別バッチ参照 | 現在の一次資料URL候補 | 対象修正コミット | 最終ゲート |
|---|---|---:|---|---|---|---|---|
| `sm2-5y-r04-law-02` | 法令 | 042 | 50人到達時の衛生管理者選任義務・14日以内の期限 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-law-03` | 法令 | 043 | 製造業で第二種衛生管理者免許のみを持つ者の選任可否 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-law-04` | 法令 | 044 | 就業規則の作成・届出先 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-law-05` | 法令 | 045 | 衛生管理者2人選任時の労働衛生コンサルタントの専属性例外 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-law-07` | 法令 | 047 | 衛生委員会の開催頻度 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-law-08` | 法令 | 048 | 就業規則の変更と意見聴取・届出 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-law-09` | 法令 | 049 | 賃金支払の五原則 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-law-10` | 法令 | 050 | 衛生委員会の電子ファイルによる議事概要周知 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-law-02` | 法令 | 052 | 衛生管理者への衛生措置権限の付与 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-law-03` | 法令 | 053 | 衛生委員会の設置義務 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md)、[BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md)、[BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347CO0000000318) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-law-04` | 法令 | 054 | 法定労働時間（1日・1週） | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-law-05` | 法令 | 055 | 休憩時間の自由利用と電話当番の扱い | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-law-07` | 法令 | 057 | 衛生委員会の記録事項：意見と対応措置 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-law-08` | 法令 | 058 | 雇入時健康診断後の相当項目の省略条件 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-law-09` | 法令 | 059 | 業務上傷病に関する解雇制限期間 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-law-02` | 法令 | 062 | 一般定期健診の聴力検査の年齢による代替特例 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-law-03` | 法令 | 063 | 6時間超8時間以下の休憩時間 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-law-04` | 法令 | 064 | 年次有給休暇管理簿の労働者別記載事項 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=73023000&dataType=0) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-law-05` | 法令 | 065 | 50人未満事業場の一般定期健康診断義務 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-law-07` | 法令 | 067 | 50人未満事業場の健診個人票作成・5年保存 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-law-08` | 法令 | 068 | 時間外・休日労働の36協定と届出 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-law-09` | 法令 | 069 | 作業環境測定の実施と結果記録 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347AC0000000057) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-law-10` | 法令 | 070 | 健康診断後の医師等の意見聴取期限 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-law-02` | 法令 | 072 | 特定業務従事者の定期健康診断間隔 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-law-03` | 法令 | 073 | 単胎妊娠の産前休業請求 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-law-04` | 法令 | 074 | 産業医の作業場等巡視頻度 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-law-05` | 法令 | 075 | 短時間労働者の年次有給休暇の比例付与 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md)、[BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md)、[BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=73023000&dataType=0) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-law-07` | 法令 | 077 | 産業医の選任期限 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-law-08` | 法令 | 078 | 産業医に選任できない事業場統括責任者 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-law-09` | 法令 | 079 | 児童の最低使用年齢 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-law-10` | 法令 | 080 | 産業医の選任と専属要件 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md)、[BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md)、[BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md)、[BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347CO0000000318) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-law-02` | 法令 | 082 | 有害業務500人従事時の専属産業医の選任 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-law-03` | 法令 | 083 | 雇入時健康診断と一般定期健康診断 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-law-04` | 法令 | 084 | 深夜労働の割増賃金率 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-law-05` | 法令 | 085 | 常時使用労働者49人と50人の定期健診結果報告義務 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-law-07` | 法令 | 087 | 定期健康診断結果報告の電子申請手続 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md) | [URL候補](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/denshishinsei_00002.html) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-law-08` | 法令 | 088 | 年次有給休暇の年5日取得確保 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-law-09` | 法令 | 089 | 衛生管理者の巡視における有害性確認対象 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md)、[BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | [144a581](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/commit/144a58189dcff68d7b3b40a2c7c4987ff0ab38b8) | **保留** |
| `sm2-5y-r08-law-10` | 法令 | 090 | 事務室の1人当たり気積の単純計算 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md)、[BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-law-02` | 法令 | 092 | 実労働7時間の法定休憩時間 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-law-05` | 法令 | 095 | 出産予定日超過時の産前休業延長と産後休業 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | [URL候補](https://www.bosei-navi.mhlw.go.jp/faq/faq16.html) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-law-07` | 法令 | 097 | 年5日取得義務への半日年休と時間単位年休の算入 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md)、[BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md)、[BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | [URL候補](https://www.startup-roudou.mhlw.go.jp/qa/zigyonushi/yukyu/q11.html) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-law-02` | 法令 | 102 | 雇入時健診と定期健診の医師判断による省略要件の違い | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | [URL候補](https://jsite.mhlw.go.jp/tokyo-roudoukyoku/hourei_seido_tetsuzuki/anzen_eisei/a-hotetu.html) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-law-07` | 法令 | 107 | ストレスチェック後の医師面接指導 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md)、[BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md)、[BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=74001000) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-law-03` | 専門 | 093 | 常時120人の衛生管理者選任人数 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-law-08` | 専門 | 098 | 衛生管理者選任後の報告期限 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-law-10` | 専門 | 100 | 供給空気の一酸化炭素濃度と特例の適用判断 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-law-03` | 専門 | 103 | 法定休日労働の割増賃金率 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-law-05` | 専門 | 105 | 健康診断後の就業上の措置 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347AC0000000057) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-law-08` | 専門 | 108 | 健診後の医師意見聴取期限と健診個人票への記載 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-law-10` | 専門 | 110 | 産後6週間以降の例外的就業条件 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md)、[BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-hyg-03` | 専門 | 113 | 室内CO₂濃度の上昇と換気改善 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md)、[BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md)、[BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md) | [URL候補](https://www.mhlw.go.jp/content/11130500/001304966.pdf) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-hyg-05` | 専門 | 115 | 温度変化と相対湿度の計算 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | [URL候補](https://mynasadata.larc.nasa.gov/sites/default/files/2019-04/Relative%20Humidity%20Protocol.pdf) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-hyg-08` | 専門 | 118 | WBGTの着衣補正値と作業時の熱中症リスク評価 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | [URL候補](https://neccyusho.mhlw.go.jp/pdf/2026/r8_neccyusho_guidelines.pdf) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-hyg-10` | 専門 | 119 | WBGTの測定条件と日射の有無による算定方法の選択 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md)、[BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-hyg-03` | 専門 | 122 | 心停止疑い時の一次救命処置とAED | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md)、[BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md)、[BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | [URL候補](https://www.jrc.or.jp/study/safety/airway/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-hyg-05` | 専門 | 124 | 目標換気回数を満たす必要換気量の逆算 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | [URL候補](https://www.aist.go.jp/aist_j/new_research/2020/nr20201224/nr20201224.html) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-hyg-08` | 専門 | 126 | 騒音下の警報認知と衝突防止 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc7618&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-hyg-10` | 専門 | 128 | 音圧レベル差と音圧振幅比の計算 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc7618&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-hyg-03` | 専門 | 131 | 情報機器作業の視距離とディスプレイ上端の高さ | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc6314&dataType=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-hyg-05` | 専門 | 133 | 防じんマスクと防毒マスクの対象物質 | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md) | [URL候補](https://www.mhlw.go.jp/content/11300000/001100842.pdf) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-hyg-10` | 専門 | — | スクリーニング検査の感度の計算 | [BATCH05](X01_DIRECT_SOURCE_BATCH05_20261111.md)、[BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | [URL候補](https://stacks.cdc.gov/view/cdc/193774) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-hyg-03` | 専門 | 139 | 小集団の健診情報の再識別防止 | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md) | [URL候補](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/anzen/anzeneisei28/index.html) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-hyg-05` | 専門 | 141 | 成人心肺蘇生の胸骨圧迫と胸郭の戻し | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | [URL候補](https://www.jrc.or.jp/study/safety/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-law-04` | 科目専門 | 094 | 衛生委員会の運営事項を決定する主体 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-law-09` | 科目専門 | 099 | 一般定期健診で医師判断の省略対象外となる検査 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-law-04` | 科目専門 | 104 | 常時200人・201人事業場の衛生管理者選任人数 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-law-09` | 科目専門 | 109 | 実労働8時間の休憩時間 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-hyg-01` | 科目専門 | 111 | 日射のある屋外におけるWBGTの算出 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md)、[BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-hyg-02` | 科目専門 | 112 | 事務室の温湿度・気流・換気管理 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-hyg-04` | 科目専門 | 114 | 冬季事務室の相対湿度・乾燥対策 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000043) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-hyg-06` | 科目専門 | 116 | 暑熱作業の休憩 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | [f53c157](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/commit/f53c157cd892fa0047e0565896a8cb8329ea2a65) | **保留** |
| `sm2-5y-r04-hyg-07` | 科目専門 | 117 | 熱中症の重篤化防止 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-hyg-09` | 科目専門 | — | 情報機器作業の視覚負担と画面環境 | X-01/別記録との突合待ち | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-hyg-02` | 科目専門 | 121 | 視作業に応じた照度とまぶしさの管理 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-hyg-04` | 科目専門 | 123 | 騒音障害防止の発生源・伝搬経路対策 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc7618&dataType=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-hyg-06` | 科目専門 | 125 | 情報機器作業の机・椅子・入力機器の体格適合 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md)、[BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md)、[BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-hyg-07` | 科目専門 | — | 情報機器作業の画面反射・グレア対策 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-hyg-09` | 科目専門 | 127 | 熱中症疑い時の初期対応 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-hyg-01` | 科目専門 | 129 | 腰痛予防教育 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | [URL候補](https://www.mhlw.go.jp/stf/newpage_31158.html) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-hyg-02` | 科目専門 | 130 | CO₂濃度測定器の配置による代表値の信頼性評価 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | [URL候補](https://jsite.mhlw.go.jp/mie-roudoukyoku/content/contents/000766889.pdf) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-hyg-04` | 科目専門 | 132 | CO₂濃度と空気清浄機・換気の役割の識別 | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md) | [URL候補](https://www.mhlw.go.jp/content/000971006.pdf) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-hyg-09` | 科目専門 | 137 | 一酸化炭素中毒疑い時の退避・救急対応 | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md)、[BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md)、[BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tb7875&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-hyg-01` | 科目専門 | — | 三次予防 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | [URL候補](https://www.cdc.gov/mmwr/preview/mmwrhtml/00016403.htm) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-hyg-02` | 科目専門 | 138 | 健康診断による早期発見・二次予防 | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md) | [URL候補](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/kenkou/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-hyg-04` | 科目専門 | 140 | WBGT・作業強度・暑熱順化による熱中症リスク評価 | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-hyg-06` | 科目専門 | — | 陽性的中率 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | [URL候補](https://stacks.cdc.gov/view/cdc/198512) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-hyg-07` | 科目専門 | 142 | 睡眠不足・作業疲労と勤務計画 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | [URL候補](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/kenkou/suimin/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-hyg-08` | 科目専門 | 143 | 増床による室容積変化と換気回数の比較 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-hyg-09` | 科目専門 | 144 | 室内温熱環境の気流・放射熱と局所冷感 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | [URL候補](https://www.mhlw.go.jp/content/001499691.pdf) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-hyg-10` | 科目専門 | 145 | 重量物取扱いにおける腰部負担軽減 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md)、[BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tb9484&dataType=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-hyg-01` | 科目専門 | 146 | 夜勤中の仮眠の長さと睡眠慣性 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | [URL候補](https://www.mhlw.go.jp/content/10904750/001181265.pdf) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-hyg-02` | 科目専門 | 147 | 感染性胃腸炎疑いの食品取扱者の就業・衛生管理 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | [URL候補](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/shokuhin/syokuchu/kanren/yobou/040204-1.html) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-hyg-03` | 科目専門 | 148 | 精密視作業の作業面照度と局部照明 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-hyg-04` | 科目専門 | 149 | 洗浄剤のSDSによる有害性・曝露経路の確認 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | [URL候補](https://www.mhlw.go.jp/stf/newpage_11389.html) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-hyg-05` | 科目専門 | 150 | エンジン式機器の屋内使用と一酸化炭素曝露予防 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md)、[BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tb7875&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-hyg-06` | 科目専門 | 151 | ボツリヌス毒素 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | [URL候補](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/0000131106.html) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-hyg-07` | 科目専門 | 152 | 職場における感染症拡大防止（手指衛生・換気・体調不良者対応） | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | [URL候補](https://www.mhlw.go.jp/content/11302000/001741252.pdf) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-hyg-08` | 科目専門 | 153 | 重量物保持距離と腰部外力モーメント | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tb9484&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-hyg-09` | 科目専門 | — | 音の強さの比とデシベル換算 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | [URL候補](https://www.osha.gov/otm/section-3-health-hazards/chapter-5) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-hyg-10` | 科目専門 | 154 | 呼吸器感染症の咳エチケットと飛沫対策 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | [URL候補](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/kenkou/kekkaku-kansenshou/infulenza/QA2026.html) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-hyg-01` | 科目専門 | 155 | AEDがショック不要と判定した直後の心肺蘇生 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | [URL候補](https://www.fdma.go.jp/relocation/kyukyu_sosei/sisin2015.pdf) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-hyg-02` | 科目専門 | 156 | 洗浄剤の眼曝露時の流水洗浄・応急対応 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | [URL候補](https://anzeninfo.mhlw.go.jp/anzen/gmsds/88-85-7.html) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-hyg-03` | 科目専門 | — | 自由音場の点音源の距離減衰（6dB則） | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | [URL候補](https://www.osha.gov/otm/section-3-health-hazards/chapter-5) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-hyg-04` | 科目専門 | 157 | 長時間立位作業の人間工学的負担軽減 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md)、[BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tb9484&dataType=1) | [cdc550f](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/commit/cdc550fe8e426e5ee2b64dd3e31a352549a3c517) | **保留** |
| `sm2-5y-r09-hyg-05` | 科目専門 | 158 | 暑熱非順化者の段階的作業管理と熱中症予防 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-hyg-06` | 科目専門 | 159 | 骨折の副子固定後における末梢血行の観察 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | [URL候補](https://www.fdma.go.jp/relocation/syobodan/item/upload/tetyou2025.pdf) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-hyg-07` | 科目専門 | 160 | 化学防護手袋の耐透過性と作業時間に応じた選択 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc2426&dataType=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-hyg-01` | 科目専門 | 163 | ストレスチェック受検者10人未満の集団分析結果提供の例外条件 | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc1015&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-hyg-02` | 科目専門 | — | キーボード作業の手首と前腕支持による肩・腕負担の軽減 | X-01/別記録との突合待ち | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-hyg-03` | 科目専門 | 164 | 暑熱順化が中断した場合の順化低下と再評価 | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-hyg-04` | 科目専門 | 165 | 健診データの匿名集団分析と作業条件評価 | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | [URL候補](https://www.mhlw.go.jp/content/000922318.pdf) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-hyg-05` | 科目専門 | 166 | 聴覚保護具の適正遮音値と警報音の聞き取り | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc7618&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-hyg-06` | 科目専門 | — | 尿色だけで脱水の程度を断定しない職場の水分管理 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | [URL候補](https://pmc.ncbi.nlm.nih.gov/articles/PMC13692142/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-hyg-08` | 科目専門 | 168 | 健診有所見率の集団分析と勤務条件評価 | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=74001000&dataType=0) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-hyg-09` | 科目専門 | 169 | WBGT測定地点と暑熱曝露条件 | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-hyg-10` | 科目専門 | 170 | 情報機器作業の表示文字高と視距離の調整 | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-phy-01` | 科目専門 | — | 高地低酸素とヘモグロビン酸素飽和度 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK539701/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-phy-02` | 科目専門 | — | 運動時の筋組織による酸素抽出と動静脈酸素較差 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK57139/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-phy-03` | 科目専門 | — | 心拍出量の計算 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK470455/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-phy-04` | 科目専門 | — | 運動時の心拍出量と活動筋血流 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md)、[BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK482280/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-phy-05` | 科目専門 | — | 肺循環から左心房への還流 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK525948/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-phy-06` | 科目専門 | — | 凝固後の血清で低下するフィブリノゲンの判断 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK531504/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-phy-07` | 科目専門 | — | 凝固検査のためのクエン酸加血漿の検体選択 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK544269/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-phy-08` | 科目専門 | — | 解剖学的死腔を除く毎分肺胞換気量の計算 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK493219/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-phy-09` | 科目専門 | — | 貧血における酸素飽和度と血液酸素含有量の区別 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK525974/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r04-phy-10` | 科目専門 | — | 二酸化炭素分圧と化学受容器による換気調節 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK482456/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-phy-01` | 科目専門 | — | 冠動脈による心筋への酸素供給 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | [URL候補](https://www.nhlbi.nih.gov/health/heart/blood-flow) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-phy-02` | 科目専門 | — | 右心室から肺動脈への血液流出 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK554457/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-phy-03` | 科目専門 | — | 肺胞・肺毛細血管間の二酸化炭素分圧差と拡散 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK539907/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-phy-04` | 科目専門 | — | 食後のインスリン増加と肝糖放出の抑制 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md)、[BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/sites/books/NBK30/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-phy-05` | 科目専門 | — | 糸球体ろ過膜の選択性と血球の非透過性 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK538339/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-phy-06` | 科目専門 | — | 脈拍 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK542175/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-phy-07` | 科目専門 | — | 心尖拍動数と橈骨脈拍数の差（脈拍欠損） | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK278/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-phy-08` | 科目専門 | — | 運動時の筋収縮によるインスリン非依存性GLUT4膜移行 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | [URL候補](https://pmc.ncbi.nlm.nih.gov/articles/PMC5369262/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-phy-09` | 科目専門 | — | 骨格筋収縮とカルシウム・アクチン・ミオシン | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK9961/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-phy-10` | 科目専門 | — | 膵リパーゼによる中性脂肪消化 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK554545/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-phy-01` | 科目専門 | — | 安静時呼息 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK559004/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-phy-02` | 科目専門 | — | 横隔膜収縮と安静吸息の胸腔容積・肺内圧変化 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK482502/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-phy-06` | 科目専門 | — | 腎臓 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK538339/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-phy-07` | 科目専門 | — | ADHのV2受容体とアクアポリン2による水再吸収 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK526069/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-phy-08` | 科目専門 | — | 骨格筋の酸化的リン酸化とATP生成 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK553192/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-phy-09` | 科目専門 | — | 多量飲水後のADH抑制と希釈尿 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK544365/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r06-phy-10` | 科目専門 | — | 心臓の刺激伝導系と伝導順序 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK594995/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-phy-01` | 科目専門 | — | アルドステロン | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK470339/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-phy-02` | 科目専門 | — | インスリン抵抗性がある骨格筋の糖取り込み | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | [URL候補](https://pubmed.ncbi.nlm.nih.gov/37248992/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-phy-03` | 科目専門 | — | 血小板の一次止血と粘着・凝集 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK545263/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-phy-04` | 科目専門 | — | 長鎖脂肪酸由来脂質のカイロミクロン・リンパ輸送 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md)、[BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK545157/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-phy-05` | 科目専門 | — | 局所冷却時の寒冷血管拡張反応（ハンティング反応） | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK232852/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-phy-06` | 科目専門 | — | 短時間の空腹時におけるグルカゴンと肝グリコーゲン分解 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/sites/books/NBK279127/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-phy-07` | 科目専門 | — | 長時間絶食で肝グリコーゲンが減少した際の糖新生 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK541119/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-phy-08` | 科目専門 | — | ADH受容体が遮断された場合の集合管AQP2作用 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK1177/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-phy-09` | 科目専門 | — | 近見反射に伴う両眼の輻輳と縮瞳 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK542189/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r07-phy-10` | 科目専門 | — | 好中球・マクロファージによる貪食と自然免疫 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK556043/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-phy-01` | 科目専門 | — | 反射 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK544292/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-phy-02` | 科目専門 | — | 明所から暗所への移行時の錐体・杆体の機能差 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK11522/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-phy-06` | 科目専門 | — | 網膜の光受容から視神経出力までの情報伝達 | [BATCH11](X01_DIRECT_SOURCE_BATCH11_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK10885/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r08-phy-10` | 科目専門 | — | 対光反射の直接反射と間接（共同）反射 | [BATCH11](X01_DIRECT_SOURCE_BATCH11_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK553169/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-phy-01` | 科目専門 | — | 骨格筋 | [BATCH11](X01_DIRECT_SOURCE_BATCH11_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/sites/books/NBK532258/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-phy-02` | 科目専門 | — | 骨格筋の滑走説とアクチン・ミオシン | [BATCH11](X01_DIRECT_SOURCE_BATCH11_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK26888/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-phy-03` | 科目専門 | — | 暗所での散瞳と交感神経による瞳孔散大筋 | [BATCH11](X01_DIRECT_SOURCE_BATCH11_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK553169/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-phy-04` | 科目専門 | — | 同じ分時換気量での浅速呼吸・深徐呼吸と肺胞換気比較 | [BATCH11](X01_DIRECT_SOURCE_BATCH11_20261111.md)、[BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK482501/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-phy-05` | 科目専門 | — | コリ回路における乳酸の肝糖新生と筋への再供給 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK541119/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-phy-06` | 科目専門 | — | 嫌気的解糖 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK546695/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-phy-07` | 科目専門 | — | ミトコンドリアの脱共役とATP合成の低下 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK526105/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-phy-08` | 科目専門 | — | 膵島β細胞とインスリン分泌 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK459261/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-phy-09` | 科目専門 | — | 出血時の交感神経による循環代償 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK538172/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r09-phy-10` | 科目専門 | — | von Willebrand因子と血小板の損傷血管壁への粘着 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK559062/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-phy-01` | 科目専門 | — | 肝臓 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK542254/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-phy-02` | 科目専門 | — | 胆汁酸による脂質乳化と胆汁の消化補助作用 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK470209/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-phy-03` | 科目専門 | — | 肺血流低下に伴う肺胞死腔の増加と換気血流不均衡 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK482501/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-phy-04` | 科目専門 | — | 近位尿細管でのブドウ糖再吸収 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md)、[BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | [URL候補](https://pmc.ncbi.nlm.nih.gov/articles/PMC3889318/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-phy-05` | 科目専門 | — | 肺胞から血液への酸素拡散 | [BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/sites/books/NBK493219/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-phy-06` | 科目専門 | — | 外気温が皮膚温を超える環境での熱移動と蒸発冷却 | [BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK541107/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-phy-07` | 科目専門 | — | 高湿度下の汗の蒸発と熱放散 | [BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | [URL候補](https://www.cdc.gov/diabetes/articles/managing-diabetes-in-the-heat.html) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-phy-08` | 科目専門 | — | 腸管毛細血管から門脈を介した糖輸送 | [BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK597379/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-phy-09` | 科目専門 | — | 二酸化炭素増加と血液pHの低下 | [BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/sites/books/NBK482430/) | 未特定（要追跡） | **保留** |
| `sm2-5y-r10-phy-10` | 科目専門 | — | 小腸での糖質と脂質の輸送経路比較 | [BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | [URL候補](https://www.ncbi.nlm.nih.gov/books/NBK545157/) | 未特定（要追跡） | **保留** |

## 今回の判断と後続照合

- 固定170問バッチにIDが存在することは**過去の照合実施を示すだけ**。その後の出典URL・解説・誤肢の修正は、現行内容との再突合が必要。
- 固定170問の17バッチとX-01の13バッチをIDごとに索引照合した。ただし各記録と現行の正答・一次資料本文・修正コミットの一致は未了であり、全件**保留**。初期是正3問の履歴は継続。
- No.161 `sm2-5y-r09-hyg-09`は本178問集合の外にあり、別途安衛法66条の4・5の一次資料を直接照合し、`legalChecked=2026-11-12`、`auditStatus=一次資料照合済`を個別記録した。**178問のレビュー待ちを解除する根拠にはならない。**
- 優先順：X-01バッチのID別証跡追加 → 修正コミットの厳密なID紐付け → 出典の逐語・版と全肢の個別判定 → 独立専門家結論 → 逐問状態変更。**本番公開BLOCKED**維持。


## 誤集計是正・X-01索引追補（2026-11-12）

- 初回版は固定170問台帳に併記された**X-01の127問一覧を誤って固定170一覧と混同**し、175件と過大集計していた。正式固定170問の見出し以降だけで再集計したため、**175件の旧値を撤回**する。
- 178問のうち正式固定170問に属するもの**108件**。X-01第1〜13バッチ内にID記載67件、固定170第1〜17バッチ内にID記載109件。固定170・X-01・初期是正3問の母集団区分を混同しない。
- 記録存在は内容の独立承認ではない。**保留178、マーカー解除0、公開BLOCKED**を維持。
