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
| `sm2-5y-r04-law-02` | 法令 | 042 | 50人到達時の衛生管理者選任義務・14日以内の期限 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **段階照合済・最終保留**（5肢とindex4は配布JSON・BATCH05 No.042と一致。安衛則7条1項1号、安衛法12条・施行令4条を確認。修正コミットのID固有差分・独立レビュー証跡未確定） |
| `sm2-5y-r04-law-03` | 法令 | 043 | 製造業で第二種衛生管理者免許のみを持つ者の選任可否 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **段階照合済・最終保留**（5肢とindex0は配布JSON・BATCH05 No.043と一致。安衛則7条1項3号イ／ロにより製造業で第二種免許のみは不可。修正コミットのID固有差分・独立レビュー証跡未確定） |
| `sm2-5y-r04-law-04` | 法令 | 044 | 就業規則の作成・届出先 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **段階照合済・最終保留**（5肢とindex3は配布JSON・BATCH05 No.044と一致。労基法89条の10人以上・所轄労基署長への届出と整合。修正コミットのID固有差分・独立レビュー証跡未確定） |
| `sm2-5y-r04-law-05` | 法令 | 045 | 衛生管理者2人選任時の労働衛生コンサルタントの専属性例外 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **段階照合済・最終保留**（現行5肢・index2・BATCH05と整合。安衛則7条1項2号ただし書、同10条3号および7条1項4号の300人規模2人選任を照合。ID固有の最終修正コミット・独立レビュー証跡未確定） |
| `sm2-5y-r04-law-07` | 法令 | 047 | 衛生委員会の開催頻度 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **段階照合済・最終保留**（現行5肢・index2・BATCH05と整合。安衛則23条1項の毎月1回以上を照合。ID固有の最終修正コミット・独立レビュー証跡未確定） |
| `sm2-5y-r04-law-08` | 法令 | 048 | 就業規則の変更と意見聴取・届出 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **段階照合済・最終保留**（現行5肢・index4・BATCH05と整合。労基法89条・90条の変更届出、意見聴取、意見書添付を照合。ID固有の最終修正コミット・独立レビュー証跡未確定） |
| `sm2-5y-r04-law-09` | 法令 | 049 | 賃金支払の五原則 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **段階照合済・最終保留**（現行5肢・index1・BATCH05と整合。労基法24条1・2項の賃金支払五原則と例外を照合。ID固有の最終修正コミット・独立レビュー証跡未確定） |
| `sm2-5y-r04-law-10` | 法令 | 050 | 衛生委員会の電子ファイルによる議事概要周知 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **段階照合済・最終保留**（現行5肢・index3・BATCH05と整合。安衛則23条3項3号の電子記録と各作業場の常時閲覧機器を照合。ID固有の最終修正コミット・独立レビュー証跡未確定） |
| `sm2-5y-r05-law-02` | 法令 | 052 | 衛生管理者への衛生措置権限の付与 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **段階照合済・最終保留**（5肢・正答index0・既存BATCH06と整合。安衛則11条2項（衛生管理者への衛生措置権限付与）。不足：最終修正コミットのID固有最終差分・独立法令レビュアーの承認記録） |
| `sm2-5y-r05-law-03` | 法令 | 053 | 衛生委員会の設置義務 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md)、[BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md)、[BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347CO0000000318) | [生成元73e1cd1／配布203ec63](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/commit/203ec636ff9ba73e6fded1f846cd68c268799bca) | **段階照合済・最終保留**（5肢・正答index4・既存BATCH06と整合。安衛法18条＋施行令9条（50人以上）。不足：独立法令レビュアーの承認記録。URL修正履歴は生成元73e1cd1／配布203ec63で確認） |
| `sm2-5y-r05-law-04` | 法令 | 054 | 法定労働時間（1日・1週） | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **段階照合済・最終保留**（5肢・正答index1・既存BATCH06と整合。労基法32条1・2項（1日8時間・週40時間）。不足：最終修正コミットのID固有最終差分・独立法令レビュアーの承認記録） |
| `sm2-5y-r05-law-05` | 法令 | 055 | 休憩時間の自由利用と電話当番の扱い | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **段階照合済・最終保留**（5肢・正答index2・既存BATCH06と整合。労基法34条1・3項（9時間労働時60分休憩と電話当番）。不足：最終修正コミットのID固有最終差分・独立法令レビュアーの承認記録） |
| `sm2-5y-r05-law-07` | 法令 | 057 | 衛生委員会の記録事項：意見と対応措置 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **段階照合済・最終保留**（5肢・正答index1・既存BATCH06と整合。安衛則23条4項1号（委員会意見と対応措置記録）。不足：最終修正コミットのID固有最終差分・独立法令レビュアーの承認記録） |
| `sm2-5y-r05-law-08` | 法令 | 058 | 雇入時健康診断後の相当項目の省略条件 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **段階照合済・最終保留**（5肢・正答index3・既存BATCH06と整合。安衛則44条3項（雇入時健診後1年の相当項目省略）。不足：最終修正コミットのID固有最終差分・独立法令レビュアーの承認記録） |
| `sm2-5y-r05-law-09` | 法令 | 059 | 業務上傷病に関する解雇制限期間 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **段階照合済・最終保留**（5肢・正答index0・既存BATCH06と整合。労基法19条1項（業務上傷病の休業期間＋30日間の解雇制限）。不足：最終修正コミットのID固有最終差分・独立法令レビュアーの承認記録） |
| `sm2-5y-r06-law-02` | 法令 | 062 | 一般定期健診の聴力検査の年齢による代替特例 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **段階照合済・最終保留**（現行5肢・index4・BATCH07確認。安衛則44条4項：45歳未満のうち35・40歳除外、30歳は医師判断で代替可。旧独立点検は実施済みだが最終承認ではない。不足：最終変更コミットIDの全履歴追跡未完、最終変更後の独立専門家承認と対象版の逐肢署名） |
| `sm2-5y-r06-law-03` | 法令 | 063 | 6時間超8時間以下の休憩時間 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **段階照合済・最終保留**（現行5肢・index1・BATCH07確認。労基法34条1項：6時間超8時間以下は45分以上。旧独立点検は実施済みだが最終承認ではない。不足：最終変更コミットIDの全履歴追跡未完、最終変更後の独立専門家承認と対象版の逐肢署名） |
| `sm2-5y-r06-law-04` | 法令 | 064 | 年次有給休暇管理簿の労働者別記載事項 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=73023000&dataType=0) | 未特定（要追跡） | **段階照合済・最終保留**（現行5肢・index0・BATCH07確認。労基則24条の7：時季・日数・基準日。旧独立点検は実施済みだが最終承認ではない。不足：最終変更コミットIDの全履歴追跡未完、最終変更後の独立専門家承認と対象版の逐肢署名） |
| `sm2-5y-r06-law-05` | 法令 | 065 | 50人未満事業場の一般定期健康診断義務 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **段階照合済・最終保留**（現行5肢・index3・BATCH07確認。安衛則44条：50人未満も対象労働者に定期健診義務、52条の報告と区別。旧独立点検は実施済みだが最終承認ではない。不足：最終変更コミットIDの全履歴追跡未完、最終変更後の独立専門家承認と対象版の逐肢署名） |
| `sm2-5y-r06-law-07` | 法令 | 067 | 50人未満事業場の健診個人票作成・5年保存 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **段階照合済・最終保留**（現行5肢・index3・BATCH07確認。安衛則51条・52条：健康診断個人票5年保存と50人以上の結果報告の区別。旧独立点検は実施済みだが最終承認ではない。不足：再設計関連履歴11cd09cf68（配布）・7f5c569537（生成元）は候補、最新版全変更順序未確定、最終変更後の独立専門家承認と対象版の逐肢署名） |
| `sm2-5y-r06-law-08` | 法令 | 068 | 時間外・休日労働の36協定と届出 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/322AC0000000049) | 未特定（要追跡） | **段階照合済・最終保留**（現行5肢・index0・BATCH07確認。労基法36条：労使協定の締結と所轄署長届出。旧独立点検は実施済みだが最終承認ではない。不足：最終変更コミットIDの全履歴追跡未完、最終変更後の独立専門家承認と対象版の逐肢署名） |
| `sm2-5y-r06-law-09` | 法令 | 069 | 作業環境測定の実施と結果記録 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347AC0000000057) | 未特定（要追跡） | **段階照合済・最終保留**（現行5肢・index4・BATCH07確認。安衛法65条：法定対象作業場の作業環境測定と記録。旧独立点検は実施済みだが最終承認ではない。不足：最終変更コミットIDの全履歴追跡未完、最終変更後の独立専門家承認と対象版の逐肢署名） |
| `sm2-5y-r06-law-10` | 法令 | 070 | 健康診断後の医師等の意見聴取期限 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | [URL候補](https://laws.e-gov.go.jp/law/347M50002000032) | 未特定（要追跡） | **段階照合済・最終保留**（現行5肢・index2・BATCH07確認。安衛則51条の2第1項：医師意見聴取原則3か月以内。旧独立点検は実施済みだが最終承認ではない。不足：最終変更コミットIDの全履歴追跡未完、最終変更後の独立専門家承認と対象版の逐肢署名） |
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
| `sm2-5y-r04-hyg-09` | 科目専門 | — | 情報機器作業の視覚負担と画面環境 | [初期誤出典是正3問](INDEPENDENT_LEGACY_TOPIC_REVIEW_20261111.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-hyg-02` | 科目専門 | 121 | 視作業に応じた照度とまぶしさの管理 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-hyg-04` | 科目専門 | 123 | 騒音障害防止の発生源・伝搬経路対策 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc7618&dataType=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-hyg-06` | 科目専門 | 125 | 情報機器作業の机・椅子・入力機器の体格適合 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md)、[BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md)、[BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
| `sm2-5y-r05-hyg-07` | 科目専門 | — | 情報機器作業の画面反射・グレア対策 | [初期誤出典是正3問](INDEPENDENT_LEGACY_TOPIC_REVIEW_20261111.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
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
| `sm2-5y-r10-hyg-02` | 科目専門 | — | キーボード作業の手首と前腕支持による肩・腕負担の軽減 | [初期誤出典是正3問](INDEPENDENT_LEGACY_TOPIC_REVIEW_20261111.md) | [URL候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | 未特定（要追跡） | **保留** |
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


## 初期是正3問とのID対応を確定（2026-11-12）

- `sm2-5y-r04-hyg-09`、`sm2-5y-r05-hyg-07`、`sm2-5y-r10-hyg-02` は固定170の正式一覧とX-01 127問から**除外された初期誤出典是正3問**。各IDを`INDEPENDENT_LEGACY_TOPIC_REVIEW_20261111.md`の初期是正記録に照合した。
- 178問母集団の内訳は、固定170正式一覧に属する**108件**、X-01 127問集合に属する**67件**、初期誤出典是正3問の**3件**で、**108+67+3=178**。**集合間の重複は0**。上記3問についても修正内容の現行版差分・一次資料本文・第三者レビューまで完了したと断定しない。
- 結論：178行すべての既存監査資料への**所在照合（第一段階）**は実施したが、**修正コミットの厳密照合・出典の条文逐語照合・最終独立査読は残る**。**レビュー待ち解除0／本番公開BLOCKED**。


## 2026-11-12｜最終ゲート逐行照合 第1区間（固定170 No.042〜044）

- **No.161のMuse側再生成検証結果を受領・照合**：`sm2-5y-r09-hyg-09`の独立法令確認後、Muse側ローカルNode CLI `node ios/health-manager-2/export-canonical-snapshot.cjs` が正常終了し、生成JSONとコミット済み配布JSONがバイト完全一致したとのユーザー報告。SHA-256 `b4233fc88e3bb4067c0a4f422f8f6a9d927a4aed949fda8a77d2dd997c0496d3`。独立したGitHub Actions [run 43102877499](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/43102877499) についても、完了・success、実行対象HEAD `fe9e5d4cd2cdd16b9aaa862720bcc48ef36714c7`をGitHub APIから確認。**本セッションでMuseローカルCLIを直接実行したわけではない**。後続の監査文書のみの変更で配布JSONは不変。No.161の確認は178問の独立査読合格を意味しない。
- **今回の個別照合**：178問台帳の冒頭3行、固定No.042 `sm2-5y-r04-law-02`、No.043 `sm2-5y-r04-law-03`、No.044 `sm2-5y-r04-law-04`を、現行`release-questions.json`の設問・5肢・`correct_index`・解説・根拠、`DIRECT_SOURCE_170_BATCH05_20261112.md`の個別判断およびe-Gov/厚労省の法令本文と照合。順に正答index **4、0、3**。No.042は安衛則7条1項1号の**14日以内**、安衛法12条・施行令4条の**常時50人以上**、No.043は安衛則7条1項3号イの製造業の選任資格とロの第二種適用業種との区別、No.044は労基法89条の**常時10人以上・所轄労働基準監督署長**に整合。4誤肢／各問について現行表現と判断理由を確認。既存第5バッチのPASSは**出典・正答の監査**であり、独立専門家査読の完了を表すものではない。
- 参照した一次本文： [厚労省・労働安全衛生規則](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0)、[e-Gov・2026年1月1日施行版 労働安全衛生規則](https://laws.e-gov.go.jp/law/347M50002000032/20260101_507M60000100097/)、[e-Gov・労働基準法](https://laws.e-gov.go.jp/law/322AC0000000049)。いずれも参照法令の改正時点を他の178問へ自動適用しない。
- **修正コミットとの突合**：3問は既存BATCH05で問題データ変更なしと記録され、現行配布JSONのIDと本文は一致。ただし過去の全修正コミットから当該IDの最終変更差分を一意に特定した証跡は未完成。**コミット未特定を解消済みと扱わない**。
- **最終判定**：3問は「設問・全肢・正答・一次本文・既存監査記録の段階照合済、独立レビューと変更履歴の証明不足により保留」。178問の最終ゲート合格 **0件**、個別段階照合 **3/178件**、最終保留 **178件**、`contentReviewStatus`変更 **0件**。配布JSON・生成元・正答indexは**一切変更なし**。法令／衛生医学専門家査読、全対象の修正コミット特定、著作権、実機、公開判断は残件。**本番公開BLOCKEDを維持**。
- 次の範囲：固定No.045 `sm2-5y-r04-law-05`から順に、同一基準で全5肢・正答・条文・変更履歴の照合を継続する。独立レビューマーカーの一括解除は行わない。


### 続行：同区間No.045・047〜050（計5問）

- 現行配布JSONの5肢・正答・問題文・解説・basisと既存`DIRECT_SOURCE_170_BATCH05_20261112.md`を照合し、No.045=`sm2-5y-r04-law-05`（index2）、No.047=`sm2-5y-r04-law-07`（index2）、No.048=`sm2-5y-r04-law-08`（index4）、No.049=`sm2-5y-r04-law-09`（index1）、No.050=`sm2-5y-r04-law-10`（index3）を確認。法令本文の対応条項は順に安衛則7条1項2号ただし書・10条3号／同23条1項／労基法89・90条／同24条／安衛則23条3項3号。根拠は[厚生労働省・安衛則本文](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0)、[厚生労働省・労基法本文](https://www.mhlw.go.jp/web/t_doc?dataId=73022000)および[e-Gov安衛則2026-01-01版](https://laws.e-gov.go.jp/law/347M50002000032/20260101_507M60000100097/)。各肢の正誤は既存BATCH05の個別説明と整合。
- No.045は300人時の2人選任・専属例外、No.047は毎月1回開催、No.048は変更届出と意見書、No.049は通貨・直接・全額・毎月1回以上・一定期日、No.050は電子記録に加え各作業場で労働者が常時閲覧できる機器という要件をそれぞれ確認。**最終のID固有修正コミット差分と外部独立レビュー完了証拠は未確定**のため状態解除なし。
- **今回合計：段階照合8/178件、最終合格0件、保留178件、`contentReviewStatus`変更0件。** 次はNo.051（固定170）以降へ。配布JSON・生成元を改変せず公開BLOCKED維持。


## 2026-11-12｜継続照合：固定170 No.051〜060（178問対象7行）

- **対象母集団**：固定No.051〜060の10IDを現行`ios/health-manager-2/release-questions.json`で照合。178問状態照合対象はNo.052/053/054/055/057/058/059の**7行**。No.051/056/060は今回の178問集合外のため最終ゲート件数には算入しない。既存の固定170第6バッチ`DIRECT_SOURCE_170_BATCH06_20261112.md`および現行JSONの設問、5肢、正答index、説明、basis、sourceを比較。
- **7問の正答index／一次根拠**：No.052 index0（安衛則11条2項、措置権限付与）、No.053 index4（安衛法18条・同施行令9条、業種を問わず50人以上）、No.054 index1（労基法32条、8時間／40時間）、No.055 index2（労基法34条、電話当番は自由利用の休憩とならない）、No.057 index1（安衛則23条4項1号、委員会意見と措置の記録）、No.058 index3（安衛則44条3項、健診後1年間の相当項目省略）、No.059 index0（労基法19条、業務上傷病の休業期間＋その後30日間）。他の4肢は各問題の現行表現に即して条文・例外条件と照合し、既存BATCH06の説明とも矛盾なし。法令参照：[e-Gov安衛則2026年11月1日時点](https://laws.e-gov.go.jp/law/347M50002000032?occasion_date=20261101)、[安衛法施行令](https://laws.e-gov.go.jp/law/347CO0000000318)、[厚労省労基法](https://www.mhlw.go.jp/web/t_doc?dataId=73022000)、[厚労省電話・来客当番の説明](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudouseisaku/chushoukigyou/joken_kankyou_rule.html)。現行版参照と過去の監査基準日が異なるため、改正による実質変更可能性の確認は独立承認時の要件として維持。
- **修正コミット確認の具体的成果：No.053のsource_url**は旧安衛法URL→施行令URLへ、**No.056のsource_url・primary_basis**は安衛則URL→施行令URL／施行令5条追記へ、それぞれ生成元コミット [73e1cd1964696a455a70a36114d27c299751c0a4](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/commit/73e1cd1964696a455a70a36114d27c299751c0a4) と配布JSONコミット [203ec636ff9ba73e6fded1f846cd68c268799bca](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/commit/203ec636ff9ba73e6fded1f846cd68c268799bca) のパッチを取得し、内容・対象フィールドを検証。**No.053の最新URLは既に修正済みであり、第6バッチの当時の改善待ちは現状のままでは未修正扱いにしない**。No.056は178対象外だが、170固定ID監査の既知修復として記録する。ただし2コミットの厳密差分確認は、最終独立承認に代わらない。
- **独立レビュー承認との照合**：7問とも、当該IDのレビュー実施者・判定日・最新版の5肢に対する独立署名／明示的PASSを証明する完了記録を確認できず、最終合格へは変更しない。No.053はURL修正コミットまで特定できたが独立レビュー証跡不足。ほか6問は加えて**ID固有の全変更履歴における最終修正コミットの完全な追跡が不足**。単なる監査記録の「PASS」・法令URLの存在・旧`legal_checked`値だけで`contentReviewStatus`を解除しない。
- **固定台帳対象外の確認**：No.051 index3（安衛則52条の2）、No.056 index4（安衛法施行令5条）、No.060 index2（安衛則13条4・5項、令和8年8月施行の[厚労省基発0428第4号](https://www.mhlw.go.jp/web/t_doc?dataId=00td0095&dataType=1&pageNo=1)）。No.060の辞任報告問題には生成元再設計コミット [80f1c3f3bb4feea444eb6ad07201ed7595202d19](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/commit/80f1c3f3bb4feea444eb6ad07201ed7595202d19) があり、そのパッチを現行5肢に照合。配布JSON側の同一ID最終更新コミットの完全な確認、独立査読完了は別途必要。
- **結果**：今回の固定170新規確認 **10/10件**、うち178問最終ゲートの個別段階照合 **7件**。前回8件と合わせて**累計15/178件**に段階照合記録あり。**最終ゲート合格0件、未承認178件、`contentReviewStatus`解除0件。** 生成元・配布JSON・正答・公開フラグは今回未変更。公開**BLOCKED**維持。次回は固定No.061〜070へ進み、ID別コミットと独立レビューの最終承認を確認する。


## 2026-11-12｜178問ID別・独立レビューと最終修正コミットの対応索引（全件）

**重要：点検完了と最終承認は別物。** `INDEPENDENT_LEGACY_TOPIC_REVIEW_20261111.md` に固定された178IDと本台帳の178IDを機械的に双方向照合し、**178/178完全一致**。同ファイルの第18バッチまでに「固定178/178問の独立点検完了、残0問」と記録される。ただしこの完了は**当時の内容レビュー実施を意味するだけ**で、後続修正後の専門家独立逐語承認・著作権・リリース承認を意味しない。同ファイルも専門家最終承認未了と明記する。**最終独立承認が記録されたと確認できた件数は0**。既存X-01の出典URL修正済みを独立承認と混同しない。

- **索引の出典・優先順位**：旧独立点検 = `INDEPENDENT_LEGACY_TOPIC_REVIEW_20261111.md` の固定178IDと第1〜18バッチ。一次資料の過去照合 = `DIRECT_SOURCE_170_BATCH01〜17`／`X01_DIRECT_SOURCE_BATCH01〜13`（各行の既存個別バッチ参照を保持）。変更履歴 = `apps/sanitary-manager-2/audit-fixes.js` と `ios/health-manager-2/release-questions.json` の実コミットパッチ。最終状態 = 正本生成後 `contentReviewStatus`／独立承認と配布JSON一致。
- **厳格な判定**：索引上の「旧独立点検」は**最終レビュー完了ではない**。GitHubコミット中に対象IDの文字があるだけでは最終修正コミットと確定しない。旧レビュー後に5肢・設問・解説・source等の変更があれば**変更後の逐肢独立承認が別途必要**。未追跡行は最終変更コミットを推定で記入しない。旧記録を自動承認に使わない。
- **IDと台帳の照合範囲**：固定170 No.は正式な170集合での番号、X01／初期是正は別集合。既存バッチ列は今回新たに根拠本文を取得した証拠ではなく、追跡開始先である。下表の「最終修正」欄にURLやbasis等の部分的変更コミットが特定されても、**全履歴の最終差分を完全確定したことは意味しない**。全178行に最終承認の不足理由を明示。

| ゲートNo. | ID | 固定170 No.／集合 | 既存監査の参照 | 独立点検記録 | 特定できた修正／追跡状況 | 不足証跡 | 最終判定 |
|---:|---|---|---|---|---|---|---|
| 001 | `sm2-5y-r04-law-02` | 042 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 002 | `sm2-5y-r04-law-03` | 043 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 003 | `sm2-5y-r04-law-04` | 044 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 004 | `sm2-5y-r04-law-05` | 045 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 005 | `sm2-5y-r04-law-07` | 047 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 006 | `sm2-5y-r04-law-08` | 048 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 007 | `sm2-5y-r04-law-09` | 049 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 008 | `sm2-5y-r04-law-10` | 050 | [BATCH05](DIRECT_SOURCE_170_BATCH05_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 009 | `sm2-5y-r05-law-02` | 052 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 010 | `sm2-5y-r05-law-03` | 053 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md)、[BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md)、[BATCH08](DI | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | `203ec636ff9ba73e6fded1f846cd68c268799bca`（施行令URL差替パッチ確認。その他履歴全探索未完） | 独立専門家の現行5肢承認、最終修正以降のレビュー、追加修正有無 | 保留 |
| 011 | `sm2-5y-r05-law-04` | 054 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 012 | `sm2-5y-r05-law-05` | 055 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 013 | `sm2-5y-r05-law-07` | 057 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 014 | `sm2-5y-r05-law-08` | 058 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 015 | `sm2-5y-r05-law-09` | 059 | [BATCH06](DIRECT_SOURCE_170_BATCH06_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 016 | `sm2-5y-r06-law-02` | 062 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 017 | `sm2-5y-r06-law-03` | 063 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 018 | `sm2-5y-r06-law-04` | 064 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 019 | `sm2-5y-r06-law-05` | 065 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 020 | `sm2-5y-r06-law-07` | 067 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | `11cd09cf68`（P1-3健診票保存／報告の再設計候補。コミットIDと現行最終差分の完全な追跡は未完） | 独立専門家の現行5肢承認、最終修正以降のレビュー、追加修正有無 | 保留 |
| 021 | `sm2-5y-r06-law-08` | 068 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 022 | `sm2-5y-r06-law-09` | 069 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 023 | `sm2-5y-r06-law-10` | 070 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 024 | `sm2-5y-r07-law-02` | 072 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 025 | `sm2-5y-r07-law-03` | 073 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 026 | `sm2-5y-r07-law-04` | 074 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 027 | `sm2-5y-r07-law-05` | 075 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md)、[BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md)、[BATCH10](DI | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 028 | `sm2-5y-r07-law-07` | 077 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 029 | `sm2-5y-r07-law-08` | 078 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 030 | `sm2-5y-r07-law-09` | 079 | [BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 031 | `sm2-5y-r07-law-10` | 080 | [BATCH07](DIRECT_SOURCE_170_BATCH07_20261112.md)、[BATCH08](DIRECT_SOURCE_170_BATCH08_20261112.md)、[BATCH09](DI | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 032 | `sm2-5y-r08-law-02` | 082 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 033 | `sm2-5y-r08-law-03` | 083 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 034 | `sm2-5y-r08-law-04` | 084 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 035 | `sm2-5y-r08-law-05` | 085 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 036 | `sm2-5y-r08-law-07` | 087 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 037 | `sm2-5y-r08-law-08` | 088 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 038 | `sm2-5y-r08-law-09` | 089 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md)、[BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | `144a58189dcff68d7b3b40a2c7c4987ff0ab38b8`（台帳記載済み・最終性未証明） | 独立専門家の現行5肢承認、最終修正以降のレビュー、追加修正有無 | 保留 |
| 039 | `sm2-5y-r08-law-10` | 090 | [BATCH09](DIRECT_SOURCE_170_BATCH09_20261112.md)、[BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 040 | `sm2-5y-r09-law-02` | 092 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 041 | `sm2-5y-r09-law-05` | 095 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 042 | `sm2-5y-r09-law-07` | 097 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md)、[BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md)、[BATCH12](DI | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 043 | `sm2-5y-r10-law-02` | 102 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 044 | `sm2-5y-r10-law-07` | 107 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md)、[BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md)、[BATCH13](DI | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 045 | `sm2-5y-r09-law-03` | 093 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 046 | `sm2-5y-r09-law-08` | 098 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 047 | `sm2-5y-r09-law-10` | 100 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 048 | `sm2-5y-r10-law-03` | 103 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 049 | `sm2-5y-r10-law-05` | 105 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 050 | `sm2-5y-r10-law-08` | 108 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 051 | `sm2-5y-r10-law-10` | 110 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md)、[BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 052 | `sm2-5y-r04-hyg-03` | 113 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md)、[BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md)、[BATCH14](DI | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 053 | `sm2-5y-r04-hyg-05` | 115 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 054 | `sm2-5y-r04-hyg-08` | 118 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 055 | `sm2-5y-r04-hyg-10` | 119 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md)、[BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 056 | `sm2-5y-r05-hyg-03` | 122 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md)、[BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md)、[BATCH15](DI | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 057 | `sm2-5y-r05-hyg-05` | 124 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 058 | `sm2-5y-r05-hyg-08` | 126 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 059 | `sm2-5y-r05-hyg-10` | 128 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 060 | `sm2-5y-r06-hyg-03` | 131 | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 061 | `sm2-5y-r06-hyg-05` | 133 | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 062 | `sm2-5y-r06-hyg-10` | X01／初期是正 | [BATCH05](X01_DIRECT_SOURCE_BATCH05_20261111.md)、[BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 063 | `sm2-5y-r07-hyg-03` | 139 | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 064 | `sm2-5y-r07-hyg-05` | 141 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 065 | `sm2-5y-r09-law-04` | 094 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 066 | `sm2-5y-r09-law-09` | 099 | [BATCH10](DIRECT_SOURCE_170_BATCH10_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 067 | `sm2-5y-r10-law-04` | 104 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 068 | `sm2-5y-r10-law-09` | 109 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 069 | `sm2-5y-r04-hyg-01` | 111 | [BATCH11](DIRECT_SOURCE_170_BATCH11_20261112.md)、[BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 070 | `sm2-5y-r04-hyg-02` | 112 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 071 | `sm2-5y-r04-hyg-04` | 114 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 072 | `sm2-5y-r04-hyg-06` | 116 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | `f53c157cd892fa0047e0565896a8cb8329ea2a65`（台帳記載済み・最終性未証明） | 独立専門家の現行5肢承認、最終修正以降のレビュー、追加修正有無 | 保留 |
| 073 | `sm2-5y-r04-hyg-07` | 117 | [BATCH12](DIRECT_SOURCE_170_BATCH12_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 074 | `sm2-5y-r04-hyg-09` | X01／初期是正 | [初期誤出典是正3問](INDEPENDENT_LEGACY_TOPIC_REVIEW_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 075 | `sm2-5y-r05-hyg-02` | 121 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 076 | `sm2-5y-r05-hyg-04` | 123 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 077 | `sm2-5y-r05-hyg-06` | 125 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md)、[BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md)、[BATCH15](DI | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 078 | `sm2-5y-r05-hyg-07` | X01／初期是正 | [初期誤出典是正3問](INDEPENDENT_LEGACY_TOPIC_REVIEW_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 079 | `sm2-5y-r05-hyg-09` | 127 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 080 | `sm2-5y-r06-hyg-01` | 129 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 081 | `sm2-5y-r06-hyg-02` | 130 | [BATCH13](DIRECT_SOURCE_170_BATCH13_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 082 | `sm2-5y-r06-hyg-04` | 132 | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 083 | `sm2-5y-r06-hyg-09` | 137 | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md)、[BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md)、[BATCH16](DI | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 084 | `sm2-5y-r07-hyg-01` | X01／初期是正 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 085 | `sm2-5y-r07-hyg-02` | 138 | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 086 | `sm2-5y-r07-hyg-04` | 140 | [BATCH14](DIRECT_SOURCE_170_BATCH14_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 087 | `sm2-5y-r07-hyg-06` | X01／初期是正 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 088 | `sm2-5y-r07-hyg-07` | 142 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 089 | `sm2-5y-r07-hyg-08` | 143 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 090 | `sm2-5y-r07-hyg-09` | 144 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 091 | `sm2-5y-r07-hyg-10` | 145 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md)、[BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 092 | `sm2-5y-r08-hyg-01` | 146 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 093 | `sm2-5y-r08-hyg-02` | 147 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 094 | `sm2-5y-r08-hyg-03` | 148 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 095 | `sm2-5y-r08-hyg-04` | 149 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 096 | `sm2-5y-r08-hyg-05` | 150 | [BATCH15](DIRECT_SOURCE_170_BATCH15_20261112.md)、[BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 097 | `sm2-5y-r08-hyg-06` | 151 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 098 | `sm2-5y-r08-hyg-07` | 152 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 099 | `sm2-5y-r08-hyg-08` | 153 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 100 | `sm2-5y-r08-hyg-09` | X01／初期是正 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 101 | `sm2-5y-r08-hyg-10` | 154 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 102 | `sm2-5y-r09-hyg-01` | 155 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 103 | `sm2-5y-r09-hyg-02` | 156 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 104 | `sm2-5y-r09-hyg-03` | X01／初期是正 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 105 | `sm2-5y-r09-hyg-04` | 157 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md)、[BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | `cdc550fe8e426e5ee2b64dd3e31a352549a3c517`（台帳記載済み・最終性未証明） | 独立専門家の現行5肢承認、最終修正以降のレビュー、追加修正有無 | 保留 |
| 106 | `sm2-5y-r09-hyg-05` | 158 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 107 | `sm2-5y-r09-hyg-06` | 159 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 108 | `sm2-5y-r09-hyg-07` | 160 | [BATCH16](DIRECT_SOURCE_170_BATCH16_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 109 | `sm2-5y-r10-hyg-01` | 163 | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 110 | `sm2-5y-r10-hyg-02` | X01／初期是正 | [初期誤出典是正3問](INDEPENDENT_LEGACY_TOPIC_REVIEW_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 111 | `sm2-5y-r10-hyg-03` | 164 | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 112 | `sm2-5y-r10-hyg-04` | 165 | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 113 | `sm2-5y-r10-hyg-05` | 166 | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 114 | `sm2-5y-r10-hyg-06` | X01／初期是正 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 115 | `sm2-5y-r10-hyg-08` | 168 | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 116 | `sm2-5y-r10-hyg-09` | 169 | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 117 | `sm2-5y-r10-hyg-10` | 170 | [BATCH17](DIRECT_SOURCE_170_BATCH17_FINAL_20261112.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 118 | `sm2-5y-r04-phy-01` | X01／初期是正 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 119 | `sm2-5y-r04-phy-02` | X01／初期是正 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 120 | `sm2-5y-r04-phy-03` | X01／初期是正 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 121 | `sm2-5y-r04-phy-04` | X01／初期是正 | [BATCH06](X01_DIRECT_SOURCE_BATCH06_20261111.md)、[BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 122 | `sm2-5y-r04-phy-05` | X01／初期是正 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 123 | `sm2-5y-r04-phy-06` | X01／初期是正 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 124 | `sm2-5y-r04-phy-07` | X01／初期是正 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 125 | `sm2-5y-r04-phy-08` | X01／初期是正 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 126 | `sm2-5y-r04-phy-09` | X01／初期是正 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 127 | `sm2-5y-r04-phy-10` | X01／初期是正 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 128 | `sm2-5y-r05-phy-01` | X01／初期是正 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 129 | `sm2-5y-r05-phy-02` | X01／初期是正 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 130 | `sm2-5y-r05-phy-03` | X01／初期是正 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 131 | `sm2-5y-r05-phy-04` | X01／初期是正 | [BATCH07](X01_DIRECT_SOURCE_BATCH07_20261111.md)、[BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 132 | `sm2-5y-r05-phy-05` | X01／初期是正 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 133 | `sm2-5y-r05-phy-06` | X01／初期是正 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 134 | `sm2-5y-r05-phy-07` | X01／初期是正 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 135 | `sm2-5y-r05-phy-08` | X01／初期是正 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 136 | `sm2-5y-r05-phy-09` | X01／初期是正 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 137 | `sm2-5y-r05-phy-10` | X01／初期是正 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 138 | `sm2-5y-r06-phy-01` | X01／初期是正 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 139 | `sm2-5y-r06-phy-02` | X01／初期是正 | [BATCH08](X01_DIRECT_SOURCE_BATCH08_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 140 | `sm2-5y-r06-phy-06` | X01／初期是正 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 141 | `sm2-5y-r06-phy-07` | X01／初期是正 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 142 | `sm2-5y-r06-phy-08` | X01／初期是正 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 143 | `sm2-5y-r06-phy-09` | X01／初期是正 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 144 | `sm2-5y-r06-phy-10` | X01／初期是正 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 145 | `sm2-5y-r07-phy-01` | X01／初期是正 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 146 | `sm2-5y-r07-phy-02` | X01／初期是正 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 147 | `sm2-5y-r07-phy-03` | X01／初期是正 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 148 | `sm2-5y-r07-phy-04` | X01／初期是正 | [BATCH09](X01_DIRECT_SOURCE_BATCH09_20261111.md)、[BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 149 | `sm2-5y-r07-phy-05` | X01／初期是正 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 150 | `sm2-5y-r07-phy-06` | X01／初期是正 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 151 | `sm2-5y-r07-phy-07` | X01／初期是正 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 152 | `sm2-5y-r07-phy-08` | X01／初期是正 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 153 | `sm2-5y-r07-phy-09` | X01／初期是正 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 154 | `sm2-5y-r07-phy-10` | X01／初期是正 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 155 | `sm2-5y-r08-phy-01` | X01／初期是正 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 156 | `sm2-5y-r08-phy-02` | X01／初期是正 | [BATCH10](X01_DIRECT_SOURCE_BATCH10_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 157 | `sm2-5y-r08-phy-06` | X01／初期是正 | [BATCH11](X01_DIRECT_SOURCE_BATCH11_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 158 | `sm2-5y-r08-phy-10` | X01／初期是正 | [BATCH11](X01_DIRECT_SOURCE_BATCH11_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 159 | `sm2-5y-r09-phy-01` | X01／初期是正 | [BATCH11](X01_DIRECT_SOURCE_BATCH11_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 160 | `sm2-5y-r09-phy-02` | X01／初期是正 | [BATCH11](X01_DIRECT_SOURCE_BATCH11_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 161 | `sm2-5y-r09-phy-03` | X01／初期是正 | [BATCH11](X01_DIRECT_SOURCE_BATCH11_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 162 | `sm2-5y-r09-phy-04` | X01／初期是正 | [BATCH11](X01_DIRECT_SOURCE_BATCH11_20261111.md)、[BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 163 | `sm2-5y-r09-phy-05` | X01／初期是正 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 164 | `sm2-5y-r09-phy-06` | X01／初期是正 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 165 | `sm2-5y-r09-phy-07` | X01／初期是正 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 166 | `sm2-5y-r09-phy-08` | X01／初期是正 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 167 | `sm2-5y-r09-phy-09` | X01／初期是正 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 168 | `sm2-5y-r09-phy-10` | X01／初期是正 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 169 | `sm2-5y-r10-phy-01` | X01／初期是正 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 170 | `sm2-5y-r10-phy-02` | X01／初期是正 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 171 | `sm2-5y-r10-phy-03` | X01／初期是正 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 172 | `sm2-5y-r10-phy-04` | X01／初期是正 | [BATCH12](X01_DIRECT_SOURCE_BATCH12_20261111.md)、[BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 173 | `sm2-5y-r10-phy-05` | X01／初期是正 | [BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 174 | `sm2-5y-r10-phy-06` | X01／初期是正 | [BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 175 | `sm2-5y-r10-phy-07` | X01／初期是正 | [BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 176 | `sm2-5y-r10-phy-08` | X01／初期是正 | [BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 177 | `sm2-5y-r10-phy-09` | X01／初期是正 | [BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |
| 178 | `sm2-5y-r10-phy-10` | X01／初期是正 | [BATCH13](X01_DIRECT_SOURCE_BATCH13_FINAL_20261111.md) | 2026-11-11旧独立点検（固定178/178内の対象ID）／最終承認証跡なし | 未特定（Git履歴全走査／現行5肢との最終差分未完） | 独立専門家の現行5肢承認、修正後レビュー、全変更履歴 | 保留 |

**索引の暫定集計**：固定178旧独立レビューID対応178/178、旧点検実施記録178/178、最新版に対する独立専門家の最終承認証拠0/178。全修正履歴から現行版の**最終コミットまで確定**できた問数は0/178（No.053や既存台帳のリンクは部分的／対象別の差分まで確認済み）。最終合格0、最終保留178。公開BLOCKED。


## 2026-11-12｜最終ゲート・固定170 No.061〜070照合結果

- 固定No.061〜070の10IDを第7バッチ記録`DIRECT_SOURCE_170_BATCH07_20261112.md`と最新`release-questions.json`に照合。**178問ゲートに属するのはNo.062〜065、067〜070の8件**。No.061、No.066は当該178問集合外。現行全10問5肢で重複IDや5肢の欠落なし。
- **No.061（集合外）既知修正の解決**：`sm2-5y-r06-law-01`は生成元`58f4b2c98a`、配布 [`d8f6cca0a319867b5658444cf1b633e8f3284ff2`](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/commit/d8f6cca0a319867b5658444cf1b633e8f3284ff2) で、`source_url`を安衛法施行令へ直接化、`primary_basis`に同令4条を追加済み。配布コミット実パッチを確認。旧第7バッチの「要改善」は**現行JSONでは適用済み**。別途専門家最終承認を証明したわけではない。
- **8問の一次法令・全肢照合**：No.062 index4（安衛則44条4項、35・40歳を除く45歳未満の聴力検査代替）、063 index1（労基法34条1項、6時間超8時間以下45分）、064 index0（労基則24条の7、年休管理簿に時季・日数・基準日）、065 index3（安衛則44条、50人未満も定期健診）、067 index3（安衛則51・52条、健診票5年保存・定期健診報告閾値）、068 index0（労基法36条、36協定と届出）、069 index4（安衛法65条、測定・記録）、070 index2（安衛則51条の2、医師意見聴取3か月）。全8問の各誤肢4つを条文・条件に照らし第7バッチ結論と照合、正答矛盾は確認されない。主要法令確認： [e-Gov安衛則2026-01-01版](https://laws.e-gov.go.jp/law/347M50002000032/20260101_507M60000100097/)、[厚労省労基則24条の7](https://www.mhlw.go.jp/web/t_doc?dataId=73023000)、[労基法](https://laws.e-gov.go.jp/law/322AC0000000049)、[安衛法](https://laws.e-gov.go.jp/law/347AC0000000057)。法律の施行版が異なる場合の改正履歴全件照合は未証明。
- **レビューの連鎖**：`INDEPENDENT_LEGACY_TOPIC_REVIEW_20261111.md` のゲート固定ID178件と本台帳178件は完全一致。8件はいずれも旧独立点検対象として記録されているが、**最終修正後の独立専門家による現行5肢全ての承認・レビュー実施者・対象データ版の同定・承認日を示す証跡なし**。No.067はP1-3再設計に関する古いコミット候補があるが、後続変更を含む最終コミットと現在の五肢との厳密同一性確定まで未了。他7件も現行最新版に対する最終修正コミットを完全に特定したとは断定しない。
- **結果**：今回対象10件を確認、178問のうち新規個別段階照合**8行**を更新。従前15件から**累計23/178件の個別段階照合**。本セッションで旧178問のID別対応索引**178行を追加**。独立専門家最終承認による`contentReviewStatus`解除**0件**、最終合格0/178、保留178/178、生成元・配布JSONは不変。**公開BLOCKEDを維持**。次はNo.071〜080を優先。
