# HM2 Q0 分割A：前半69問・一次照合作業台帳（2026-11-22 JST）

対象ブランチ：`fix/hm2-priority123-regression-20261122`。対象は固定178問の一意ID配列の第41〜109件（69問）。**この順序は固定178問台帳に基づく暫定割当であり、先行40問の実際の確認順と一致する保証はない。統合前に既存40問との重複をID単位で照合すること。**

## 判定と実施範囲

- 69問のID・論点・一次資料URL候補を固定台帳から抽出して作業単位を確定した。
- 下表のURLは**既存台帳からの転記であり、今回公式本文を開いて照合した実績ではない**。全5肢の現行本文・正答・解説との照合も未完了。したがって**新規一次確認合格0/69問**、69問すべて「要逐肢原典照合」とする。
- 出典の施行版・適用範囲、現行配布JSONのSHA-256と5肢内容、権利利用条件は未確定。旧台帳の過去PASSは流用しない。
- このファイルは未確認を可視化するための分割作業記録であり、Q0証跡としての合格入力に使用しない。
- 本体台帳・配布JSON・生成元・ゲート・CI・App Review・TestFlightには触れない。

## 69問の個別確認待ち一覧

| 分割No. | 問題ID | 論点 | 一次資料候補（未再閲覧） | 逐肢照合 |
|---:|---|---|---|---|
| 1 | `sm2-5y-r09-law-05` | 出産予定日超過時の産前休業延長と産後休業 | [候補](https://www.bosei-navi.mhlw.go.jp/faq/faq16.html) | **未実施** |
| 2 | `sm2-5y-r09-law-07` | 年5日取得義務への半日年休と時間単位年休の算入 | [候補](https://www.startup-roudou.mhlw.go.jp/qa/zigyonushi/yukyu/q11.html) | **未実施** |
| 3 | `sm2-5y-r10-law-02` | 雇入時健診と定期健診の医師判断による省略要件の違い | [候補](https://jsite.mhlw.go.jp/tokyo-roudoukyoku/hourei_seido_tetsuzuki/anzen_eisei/a-hotetu.html) | **未実施** |
| 4 | `sm2-5y-r10-law-07` | ストレスチェック後の医師面接指導 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=74001000) | **未実施** |
| 5 | `sm2-5y-r09-law-03` | 常時120人の衛生管理者選任人数 | [候補](https://laws.e-gov.go.jp/law/347M50002000032) | **未実施** |
| 6 | `sm2-5y-r09-law-08` | 衛生管理者選任後の報告期限 | [候補](https://laws.e-gov.go.jp/law/347M50002000032) | **未実施** |
| 7 | `sm2-5y-r09-law-10` | 供給空気の一酸化炭素濃度と特例の適用判断 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | **未実施** |
| 8 | `sm2-5y-r10-law-03` | 法定休日労働の割増賃金率 | [候補](https://laws.e-gov.go.jp/law/322AC0000000049) | **未実施** |
| 9 | `sm2-5y-r10-law-05` | 健康診断後の就業上の措置 | [候補](https://laws.e-gov.go.jp/law/347AC0000000057) | **未実施** |
| 10 | `sm2-5y-r10-law-08` | 健診後の医師意見聴取期限と健診個人票への記載 | [候補](https://laws.e-gov.go.jp/law/347M50002000032) | **未実施** |
| 11 | `sm2-5y-r10-law-10` | 産後6週間以降の例外的就業条件 | [候補](https://laws.e-gov.go.jp/law/322AC0000000049) | **未実施** |
| 12 | `sm2-5y-r04-hyg-03` | 室内CO₂濃度の上昇と換気改善 | [候補](https://www.mhlw.go.jp/content/11130500/001304966.pdf) | **未実施** |
| 13 | `sm2-5y-r04-hyg-05` | 温度変化と相対湿度の計算 | [候補](https://mynasadata.larc.nasa.gov/sites/default/files/2019-04/Relative%20Humidity%20Protocol.pdf) | **未実施** |
| 14 | `sm2-5y-r04-hyg-08` | WBGTの着衣補正値と作業時の熱中症リスク評価 | [候補](https://neccyusho.mhlw.go.jp/pdf/2026/r8_neccyusho_guidelines.pdf) | **未実施** |
| 15 | `sm2-5y-r04-hyg-10` | WBGTの測定条件と日射の有無による算定方法の選択 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | **未実施** |
| 16 | `sm2-5y-r05-hyg-03` | 心停止疑い時の一次救命処置とAED | [候補](https://www.jrc.or.jp/study/safety/airway/) | **未実施** |
| 17 | `sm2-5y-r05-hyg-05` | 目標換気回数を満たす必要換気量の逆算 | [候補](https://www.aist.go.jp/aist_j/new_research/2020/nr20201224/nr20201224.html) | **未実施** |
| 18 | `sm2-5y-r05-hyg-08` | 騒音下の警報認知と衝突防止 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc7618&dataType=1&pageNo=1) | **未実施** |
| 19 | `sm2-5y-r05-hyg-10` | 音圧レベル差と音圧振幅比の計算 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc7618&dataType=1&pageNo=1) | **未実施** |
| 20 | `sm2-5y-r06-hyg-03` | 情報機器作業の視距離とディスプレイ上端の高さ | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc6314&dataType=1) | **未実施** |
| 21 | `sm2-5y-r06-hyg-05` | 防じんマスクと防毒マスクの対象物質 | [候補](https://www.mhlw.go.jp/content/11300000/001100842.pdf) | **未実施** |
| 22 | `sm2-5y-r06-hyg-10` | スクリーニング検査の感度の計算 | [候補](https://stacks.cdc.gov/view/cdc/193774) | **未実施** |
| 23 | `sm2-5y-r07-hyg-03` | 小集団の健診情報の再識別防止 | [候補](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/anzen/anzeneisei28/index.html) | **未実施** |
| 24 | `sm2-5y-r07-hyg-05` | 成人心肺蘇生の胸骨圧迫と胸郭の戻し | [候補](https://www.jrc.or.jp/study/safety/) | **未実施** |
| 25 | `sm2-5y-r09-law-04` | 衛生委員会の運営事項を決定する主体 | [候補](https://laws.e-gov.go.jp/law/347M50002000032) | **未実施** |
| 26 | `sm2-5y-r09-law-09` | 一般定期健診で医師判断の省略対象外となる検査 | [候補](https://laws.e-gov.go.jp/law/347M50002000032) | **未実施** |
| 27 | `sm2-5y-r10-law-04` | 常時200人・201人事業場の衛生管理者選任人数 | [候補](https://laws.e-gov.go.jp/law/347M50002000032) | **未実施** |
| 28 | `sm2-5y-r10-law-09` | 実労働8時間の休憩時間 | [候補](https://laws.e-gov.go.jp/law/322AC0000000049) | **未実施** |
| 29 | `sm2-5y-r04-hyg-01` | 日射のある屋外におけるWBGTの算出 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | **未実施** |
| 30 | `sm2-5y-r04-hyg-02` | 事務室の温湿度・気流・換気管理 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | **未実施** |
| 31 | `sm2-5y-r04-hyg-04` | 冬季事務室の相対湿度・乾燥対策 | [候補](https://laws.e-gov.go.jp/law/347M50002000043) | **未実施** |
| 32 | `sm2-5y-r04-hyg-06` | 暑熱作業の休憩 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | **未実施** |
| 33 | `sm2-5y-r04-hyg-07` | 熱中症の重篤化防止 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | **未実施** |
| 34 | `sm2-5y-r04-hyg-09` | 情報機器作業の視覚負担と画面環境 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | **未実施** |
| 35 | `sm2-5y-r05-hyg-02` | 視作業に応じた照度とまぶしさの管理 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | **未実施** |
| 36 | `sm2-5y-r05-hyg-04` | 騒音障害防止の発生源・伝搬経路対策 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc7618&dataType=1) | **未実施** |
| 37 | `sm2-5y-r05-hyg-06` | 情報機器作業の机・椅子・入力機器の体格適合 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | **未実施** |
| 38 | `sm2-5y-r05-hyg-07` | 情報機器作業の画面反射・グレア対策 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | **未実施** |
| 39 | `sm2-5y-r05-hyg-09` | 熱中症疑い時の初期対応 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | **未実施** |
| 40 | `sm2-5y-r06-hyg-01` | 腰痛予防教育 | [候補](https://www.mhlw.go.jp/stf/newpage_31158.html) | **未実施** |
| 41 | `sm2-5y-r06-hyg-02` | CO₂濃度測定器の配置による代表値の信頼性評価 | [候補](https://jsite.mhlw.go.jp/mie-roudoukyoku/content/contents/000766889.pdf) | **未実施** |
| 42 | `sm2-5y-r06-hyg-04` | CO₂濃度と空気清浄機・換気の役割の識別 | [候補](https://www.mhlw.go.jp/content/000971006.pdf) | **未実施** |
| 43 | `sm2-5y-r06-hyg-09` | 一酸化炭素中毒疑い時の退避・救急対応 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tb7875&dataType=1&pageNo=1) | **未実施** |
| 44 | `sm2-5y-r07-hyg-01` | 三次予防 | [候補](https://www.cdc.gov/mmwr/preview/mmwrhtml/00016403.htm) | **未実施** |
| 45 | `sm2-5y-r07-hyg-02` | 健康診断による早期発見・二次予防 | [候補](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/kenkou/) | **未実施** |
| 46 | `sm2-5y-r07-hyg-04` | WBGT・作業強度・暑熱順化による熱中症リスク評価 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | **未実施** |
| 47 | `sm2-5y-r07-hyg-06` | 陽性的中率 | [候補](https://stacks.cdc.gov/view/cdc/198512) | **未実施** |
| 48 | `sm2-5y-r07-hyg-07` | 睡眠不足・作業疲労と勤務計画 | [候補](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/kenkou/suimin/) | **未実施** |
| 49 | `sm2-5y-r07-hyg-08` | 増床による室容積変化と換気回数の比較 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | **未実施** |
| 50 | `sm2-5y-r07-hyg-09` | 室内温熱環境の気流・放射熱と局所冷感 | [候補](https://www.mhlw.go.jp/content/001499691.pdf) | **未実施** |
| 51 | `sm2-5y-r07-hyg-10` | 重量物取扱いにおける腰部負担軽減 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tb9484&dataType=1) | **未実施** |
| 52 | `sm2-5y-r08-hyg-01` | 夜勤中の仮眠の長さと睡眠慣性 | [候補](https://www.mhlw.go.jp/content/001305530.pdf) | **未実施** |
| 53 | `sm2-5y-r08-hyg-02` | 感染性胃腸炎疑いの食品取扱者の就業・衛生管理 | [候補](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/shokuhin/syokuchu/kanren/yobou/040204-1.html) | **未実施** |
| 54 | `sm2-5y-r08-hyg-03` | 精密視作業の作業面照度と局部照明 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | **未実施** |
| 55 | `sm2-5y-r08-hyg-04` | 洗浄剤のSDSによる有害性・曝露経路の確認 | [候補](https://www.mhlw.go.jp/stf/newpage_11389.html) | **未実施** |
| 56 | `sm2-5y-r08-hyg-05` | エンジン式機器の屋内使用と一酸化炭素曝露予防 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tb7875&dataType=1&pageNo=1) | **未実施** |
| 57 | `sm2-5y-r08-hyg-06` | ボツリヌス毒素 | [候補](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/0000131106.html) | **未実施** |
| 58 | `sm2-5y-r08-hyg-07` | 職場における感染症拡大防止（手指衛生・換気・体調不良者対応） | [候補](https://www.mhlw.go.jp/content/11302000/001741252.pdf) | **未実施** |
| 59 | `sm2-5y-r08-hyg-08` | 重量物保持距離と腰部外力モーメント | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tb9484&dataType=1&pageNo=1) | **未実施** |
| 60 | `sm2-5y-r08-hyg-09` | 音の強さの比とデシベル換算 | [候補](https://www.osha.gov/otm/section-3-health-hazards/chapter-5) | **未実施** |
| 61 | `sm2-5y-r08-hyg-10` | 呼吸器感染症の咳エチケットと飛沫対策 | [候補](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/kenkou/kekkaku-kansenshou/infulenza/QA2026.html) | **未実施** |
| 62 | `sm2-5y-r09-hyg-01` | AEDがショック不要と判定した直後の心肺蘇生 | [候補](https://www.fdma.go.jp/relocation/kyukyu_sosei/sisin2015.pdf) | **未実施** |
| 63 | `sm2-5y-r09-hyg-02` | 洗浄剤の眼曝露時の流水洗浄・応急対応 | [候補](https://anzeninfo.mhlw.go.jp/anzen/gmsds/88-85-7.html) | **未実施** |
| 64 | `sm2-5y-r09-hyg-03` | 自由音場の点音源の距離減衰（6dB則） | [候補](https://www.osha.gov/otm/section-3-health-hazards/chapter-5) | **未実施** |
| 65 | `sm2-5y-r09-hyg-04` | 長時間立位作業の人間工学的負担軽減 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tb9484&dataType=1) | **未実施** |
| 66 | `sm2-5y-r09-hyg-05` | 暑熱非順化者の段階的作業管理と熱中症予防 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1) | **未実施** |
| 67 | `sm2-5y-r09-hyg-06` | 骨折の副子固定後における末梢血行の観察 | [候補](https://www.fdma.go.jp/relocation/syobodan/item/upload/tetyou2025.pdf) | **未実施** |
| 68 | `sm2-5y-r09-hyg-07` | 化学防護手袋の耐透過性と作業時間に応じた選択 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc2426&dataType=1) | **未実施** |
| 69 | `sm2-5y-r10-hyg-01` | ストレスチェック受検者10人未満の集団分析結果提供の例外条件 | [候補](https://www.mhlw.go.jp/web/t_doc?dataId=00tc1015&dataType=1&pageNo=1) | **未実施** |

## コーディネーターへの引き継ぎ

このファイルの69件を一次確認済みとして集計しないこと。まず既存40件のID集合と照合して担当範囲を確定し、現行bankのSHA-256を固定する。各問5肢の実際の文言と正誤、根拠本文の条項・施行日・適用範囲を記録して初めて一次確認として数える。二重チェック・300問権利判定・Q0/Q1判定は本担当の範囲外。

## 続行バッチ：分割No.1〜30の現行5肢照合と公式根拠の調査（2026-11-22 JST）

- 対象：固定69問の先頭30問（150肢）、Git blob `72888a617ff17bf84b25e9d5a61f5cdec0d7493d` の配布bank。**blob SHAはSHA-256ではない**。現行ブランチへのリベースや更新があれば再固定が必要。
- 5肢の本文・正答indexはこのblobから読み取った。下表はそれぞれ「1〜5肢の判定」=正答として選ぶべき肢「○」と、それ以外「×」を各肢順に列挙する。誤肢ごとの正誤理由は判定根拠欄の命題から判定したもので、法令全肢個別条項の追加検証までは完了していない。
- 根拠区分「直接」は今回公式検索で該当する制度・式を確認したこと、「追加確認」「要条文再精査」「原典未再閲覧」は全肢の公式原典直接照合を完了していないことを意味する。**今回の一次確認正式合格数は慎重に0/30とする**（制度・計算の一次評価は30問着手）。

| No. | ID | 配布正答（1起点） | 5肢の一次判定（1→5） | 命題別根拠・計算 | 原典 | 確認水準 |
|---:|---|---:|---|---|---|---|
| 1 | `sm2-5y-r09-law-05` | 4 | × / × / × / ○ / × | 産前延長は産前扱いで産後8週を減らさない | [公的資料](https://www.bosei-navi.mhlw.go.jp/faq/faq16.html) | 直接 |
| 2 | `sm2-5y-r09-law-07` | 4 | × / × / × / ○ / × | 半日年休は0.5日換算、時間単位は5日義務に算入不可 | [公的資料](https://www.startup-roudou.mhlw.go.jp/qa/zigyonushi/yukyu/q11.html) | 追加確認 |
| 3 | `sm2-5y-r10-law-02` | 5 | × / × / × / × / ○ | 雇入時43条と定期44条2項の省略は別制度 | [公的資料](https://jsite.mhlw.go.jp/tokyo-roudoukyoku/hourei_seido_tetsuzuki/anzen_eisei/a-hotetu.html) | 直接 |
| 4 | `sm2-5y-r10-law-07` | 3 | × / × / ○ / × / × | 面接指導申出時の事業者義務と申出による不利益禁止 | [公的資料](https://anzeninfo.mhlw.go.jp/yougo/yougo95_1.html) | 直接 |
| 5 | `sm2-5y-r09-law-03` | 2 | × / ○ / × / × / × | 安衛則7条1項4号：50〜200人は1人 | [公的資料](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1) | 直接 |
| 6 | `sm2-5y-r09-law-08` | 1 | ○ / × / × / × / × | 安衛則7条3項：選任後遅滞なく電子報告 | [公的資料](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1) | 直接 |
| 7 | `sm2-5y-r09-law-10` | 3 | × / × / ○ / × / × | 事務所則5条の供給空気CO原則10ppm以下、特例適用を区別 | [公的資料](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 要条文再精査 |
| 8 | `sm2-5y-r10-law-03` | 1 | ○ / × / × / × / × | 法定休日労働35%以上の割増、36協定でも免除されない | [公的資料](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudouseisaku/chushoukigyou/joken_kankyou_rule.html) | 直接 |
| 9 | `sm2-5y-r10-law-05` | 3 | × / × / ○ / × / × | 安衛法66条の4・5：医師意見を踏まえ就業措置 | [公的資料](https://www.mhlw.go.jp/content/11201250/001597865.pdf) | 直接 |
| 10 | `sm2-5y-r10-law-08` | 5 | × / × / × / × / ○ | 安衛則51条・51条の2：個人票5年、意見3か月以内に聴取・記載 | [公的資料](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | 直接 |
| 11 | `sm2-5y-r10-law-10` | 4 | × / × / × / ○ / × | 労基法65条2項：産後6週間経過、本人請求、医師支障なし | [公的資料](https://www.bosei-navi.mhlw.go.jp/gimu/kyugyo.html) | 直接 |
| 12 | `sm2-5y-r04-hyg-03` | 5 | × / × / × / × / ○ | CO2上昇時は在室者数・換気設備・運用の再評価、CO2のみで個人感染を特定しない | [公的資料](https://www.mhlw.go.jp/content/11130500/001304966.pdf) | 追加確認 |
| 13 | `sm2-5y-r04-hyg-05` | 3 | × / × / ○ / × / × | 相対湿度＝実際の水蒸気量÷飽和水蒸気量×100：6/23と6/13 | [公的資料](https://mynasadata.larc.nasa.gov/sites/default/files/2019-04/Relative%20Humidity%20Protocol.pdf) | 計算確認・原典未再閲覧 |
| 14 | `sm2-5y-r04-hyg-08` | 4 | × / × / × / ○ / × | 織物衣服二重着用はWBGT着衣補正+3℃ | [公的資料](https://anzeninfo.mhlw.go.jp/yougo/yougo89_1.html) | 直接 |
| 15 | `sm2-5y-r04-hyg-10` | 3 | × / × / ○ / × / × | 日射ありWBGT=0.7湿球+0.2黒球+0.1気温、日射なし=0.7湿球+0.3黒球 | [公的資料](https://www.mhlw.go.jp/web/t_doc?dataId=00tc6081&dataType=1&pageNo=1) | 直接 |
| 16 | `sm2-5y-r05-hyg-03` | 2 | × / ○ / × / × / × | 意識・正常呼吸なしなら119通報・AED依頼・胸骨圧迫 | [公的資料](https://www.jrc.or.jp/study/safety/airway/) | 追加確認 |
| 17 | `sm2-5y-r05-hyg-05` | 4 | × / × / × / ○ / × | 換気回数4回/時×室容積300m³=必要換気量1200m³/時 | [公的資料](https://www.aist.go.jp/aist_j/new_research/2020/nr20201224/nr20201224.html) | 計算確認・出典直接性未確認 |
| 18 | `sm2-5y-r05-hyg-08` | 1 | ○ / × / × / × / × | 騒音測定と設備・警報の補完的対策、視覚警報の法定一律義務ではない | [公的資料](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/anzen/anzeneisei02_00004.html) | 追加確認 |
| 19 | `sm2-5y-r05-hyg-10` | 3 | × / × / ○ / × / × | 音圧レベル差10dB→音圧比10^(10/20)=3.162 | [公的資料](https://www.mhlw.go.jp/web/t_doc?dataId=00tc7618&dataType=1&pageNo=1) | 計算確認・式の原典未再閲覧 |
| 20 | `sm2-5y-r06-hyg-03` | 1 | ○ / × / × / × / × | 情報機器作業指針：視距離40cm以上、画面上端は眼とほぼ同じか下 | [公的資料](https://www.mhlw.go.jp/web/t_doc?dataId=00tc6314&dataType=1&pageNo=1) | 直接 |
| 21 | `sm2-5y-r06-hyg-05` | 3 | × / × / ○ / × / × | 粒子のろ過材とガス・蒸気用の吸収缶を区別 | [公的資料](https://www.mhlw.go.jp/web/t_doc?dataId=00tc7653&dataType=1&pageNo=1) | 直接 |
| 22 | `sm2-5y-r06-hyg-10` | 4 | × / × / × / ○ / × | 感度＝真陽性/(真陽性+偽陰性)=90/100 | [公的資料](https://stacks.cdc.gov/view/cdc/193774) | 計算確認・原典未再閲覧 |
| 23 | `sm2-5y-r07-hyg-03` | 5 | × / × / × / × / ○ | 小集団の健診情報は再識別・目的外共有を避ける | [公的資料](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/anzen/anzeneisei28/index.html) | 追加確認 |
| 24 | `sm2-5y-r07-hyg-05` | 3 | × / × / ○ / × / × | 胸骨圧迫解除時は胸郭を完全に戻す | [公的資料](https://www.jrc.or.jp/study/safety/) | 追加確認 |
| 25 | `sm2-5y-r09-law-04` | 1 | ○ / × / × / × / × | 安衛則23条2項：委員会運営事項は委員会が定める | [公的資料](https://anzeninfo.mhlw.go.jp/yougo/yougo44_1.html) | 直接 |
| 26 | `sm2-5y-r09-law-09` | 5 | × / × / × / × / ○ | 安衛則44条2項：血圧・尿検査は医師省略対象に含まれない | [公的資料](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | 要条文再精査 |
| 27 | `sm2-5y-r10-law-04` | 4 | × / × / × / ○ / × | 安衛則7条：200人までは1人、201〜500人は2人 | [公的資料](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1) | 直接 |
| 28 | `sm2-5y-r10-law-09` | 2 | × / ○ / × / × / × | 労基法34条：8時間ちょうどは45分、8時間超は60分 | [公的資料](https://www.mhlw.go.jp/bunya/roudoukijun/faq_kijyunhou_13.html) | 直接 |
| 29 | `sm2-5y-r04-hyg-01` | 4 | × / × / × / ○ / × | 日射ありWBGT=0.7×26+0.2×36+0.1×32=28.6 | [公的資料](https://www.mhlw.go.jp/web/t_doc?dataId=00tc6081&dataType=1&pageNo=1) | 直接・計算確認 |
| 30 | `sm2-5y-r04-hyg-02` | 1 | ○ / × / × / × / × | 事務所則の温湿度・気流・換気の複合管理 | [公的資料](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 直接 |

### 個別の追加検討事項

- No.7：事務所衛生基準規則の「供給する空気」と「室内の測定濃度」、外気汚染時の例外を分離して現行施行版で確定する。
- No.13：仮定値を使った計算自体は25℃で26.09%、15℃で46.15%。NASAの数値例・著作権重複の疑義は別の権利担当に移管する。
- No.17：換気回数4回/時は設問条件であり、あらゆる会議室に法定義務として課す値ではない。
- No.19：振幅比と音響強度比を取り違えないこと（振幅比約3.16、強度比10）。
- No.22：疾病なし群が提示されていないので、特異度・陽性的中率・有病率を推計してはならない。
- No.26：2026年の定期健診に関する通知改正との整合、および安衛則44条2項の省略対象を条文ベースで再確認する。
- No.29：0.7×26+0.2×36+0.1×32=18.2+7.2+3.2=28.6℃。
- 本表は**一次判定の作業記録**であり、独立二重レビュー・権利許諾・Q0/Q1ゲート認定ではない。残39問（No.31〜69）は今回未着手。今後の完全確認では選択肢ごとの反証と条文施行版を追記する。

## 続行バッチ：分割No.31〜69（残り39問・195肢）の一次判定（2026-11-22 JST）

- 上記同一配布bank Git blobの39問を突合。全5肢の文言と現行の正答indexを読み取り、選択肢ごとの一次判定を記録した。5肢欄は第1肢から第5肢までの正答性（○=適切な解答肢、×=不適切）を示す。
- 「直接確認」は該当する中心命題を今回公的機関の公開検索結果で確認した意味であり、**5肢それぞれについて法令の適用日・原典ページまで追跡した最終合格とは異なる**。数値を仮定した問題では算術的計算の検証と法律の根拠確認を分離する。

| No. | 問題ID | 配布正答（1起点） | 第1〜5肢の一次判定 | 判定命題・検証内容 | 根拠資料 | 留保事項 |
|---:|---|---:|---|---|---|---|
| 31 | `sm2-5y-r04-hyg-04` | 2 | × / ○ / × / × / × | 乾燥25%時は湿度管理と換気の両立。空調設置条件等の事務所則適用範囲に注意 | [根拠](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 公式条文あり・適用条件追試 |
| 32 | `sm2-5y-r04-hyg-06` | 5 | × / × / × / × / ○ | めまい持続は暑熱暴露を中断、冷却し意識と自力飲水を見て必要時救急 | [根拠](https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/kenkou/nettyuu/nettyuu_taisaku/happen.html) | 直接確認 |
| 33 | `sm2-5y-r04-hyg-07` | 2 | × / ○ / × / × / × | WBGTに応じ作業負荷・休憩・水分塩分補給・暑熱順化を考慮 | [根拠](https://neccyusho.mhlw.go.jp/heat_index/) | 直接確認 |
| 34 | `sm2-5y-r04-hyg-09` | 1 | ○ / × / × / × / × | ディスプレイの映り込み、視距離、文字サイズ、休止を調整 | [根拠](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | 直接確認 |
| 35 | `sm2-5y-r05-hyg-02` | 5 | × / × / × / × / ○ | 精密視作業では局所照度とグレアの確認が重要 | [根拠](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 条文の作業分類追試 |
| 36 | `sm2-5y-r05-hyg-04` | 1 | ○ / × / × / × / × | 騒音は発生源と伝搬経路の対策が優先候補、保護具のみで完結しない | [根拠](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/anzen/anzeneisei02_00004.html) | 公式案内・本文要追試 |
| 37 | `sm2-5y-r05-hyg-06` | 2 | × / ○ / × / × / × | 机椅子足台・入力機器の体格適合で不自然な肩上げを抑制 | [根拠](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | 直接確認 |
| 38 | `sm2-5y-r05-hyg-07` | 4 | × / × / × / ○ / × | 窓の反射や照明グレアは遮光・配置・角度で改善 | [根拠](https://www.mhlw.go.jp/web/t_doc?dataId=00tc4418&dataType=1&pageNo=1) | 直接確認 |
| 39 | `sm2-5y-r05-hyg-09` | 5 | × / × / × / × / ○ | 熱中症疑いのめまいは作業中止・冷却・意識確認と必要時救急 | [根拠](https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/kenkou/nettyuu/nettyuu_taisaku/happen.html) | 直接確認 |
| 40 | `sm2-5y-r06-hyg-01` | 2 | × / ○ / × / × / × | 重量物業務配置時と必要時に腰痛予防教育 | [根拠](https://www.mhlw.go.jp/stf/newpage_31158.html) | 直接確認 |
| 41 | `sm2-5y-r06-hyg-02` | 5 | × / × / × / × / ○ | CO2計は窓・換気口・人から距離を取る。人から少なくとも50cm | [根拠](https://www.mhlw.go.jp/content/000968524.pdf) | 直接確認 |
| 42 | `sm2-5y-r06-hyg-04` | 4 | × / × / × / ○ / × | HEPAは粒子除去でCO2希釈には外気換気が必要 | [根拠](https://www.mhlw.go.jp/content/000971006.pdf) | 原典本文追試 |
| 43 | `sm2-5y-r06-hyg-09` | 2 | × / ○ / × / × / × | 燃焼機器由来COを疑い、安全な退避と救急通報、救助者二次曝露回避 | [根拠](https://www.mhlw.go.jp/web/t_doc?dataId=00tb7875&dataType=1&pageNo=1) | 原典本文追試 |
| 44 | `sm2-5y-r07-hyg-01` | 4 | × / × / × / ○ / × | 治療後の再発防止・社会復帰支援は三次予防 | [根拠](https://www.cdc.gov/mmwr/preview/mmwrhtml/00016403.htm) | CDC原典未再閲覧 |
| 45 | `sm2-5y-r07-hyg-02` | 1 | ○ / × / × / × / × | 早期発見と早期治療への結びつけは二次予防 | [根拠](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/kenkou/) | 出典直接性追試 |
| 46 | `sm2-5y-r07-hyg-04` | 2 | × / ○ / × / × / × | WBGTのみでは不十分で代謝率・順化・着衣条件を反映 | [根拠](https://neccyusho.mhlw.go.jp/heat_index/) | 直接確認 |
| 47 | `sm2-5y-r07-hyg-06` | 5 | × / × / × / × / ○ | 陽性的中率=真陽性20/陽性総数80=25% | [根拠](https://stacks.cdc.gov/view/cdc/198512) | 計算確認・原典未再閲覧 |
| 48 | `sm2-5y-r07-hyg-07` | 2 | × / ○ / × / × / × | 睡眠機会確保と交替勤務計画・疲労の評価 | [根拠](https://www.mhlw.go.jp/content/001305530.pdf) | 直接確認 |
| 49 | `sm2-5y-r07-hyg-08` | 4 | × / × / × / ○ / × | 換気回数=換気量/室容積：前900/300=3、後900/450=2 | [根拠](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 計算確認・法定数値でない |
| 50 | `sm2-5y-r07-hyg-09` | 1 | ○ / × / × / × / × | 体感温熱は温度・気流・湿度・放射熱を含め総合評価 | [根拠](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 原典の放射熱記載追試 |
| 51 | `sm2-5y-r07-hyg-10` | 3 | × / × / ○ / × / × | 荷を身体に近づけ、作業高や補助具を調整して腰負担減 | [根拠](https://www.mhlw.go.jp/stf/newpage_31158.html) | 直接確認 |
| 52 | `sm2-5y-r08-hyg-01` | 3 | × / × / ○ / × / × | 夜勤中の仮眠・睡眠慣性に注意。ただし20〜50分という具体幅の直接根拠を要精査 | [根拠](https://www.mhlw.go.jp/content/001305530.pdf) | **数値根拠要修正検討** |
| 53 | `sm2-5y-r08-hyg-02` | 5 | × / × / × / × / ○ | 感染性胃腸炎疑い食品従事者の就業と衛生管理を評価 | [根拠](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/shokuhin/syokuchu/kanren/yobou/040204-1.html) | 原典本文追試 |
| 54 | `sm2-5y-r08-hyg-03` | 2 | × / ○ / × / × / × | 作業面の局所照度を測り全般照明・局部照明を調整 | [根拠](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | 条文適用範囲追試 |
| 55 | `sm2-5y-r08-hyg-04` | 1 | ○ / × / × / × / × | SDSから化学物質の吸入・皮膚曝露と適合保護具を判断 | [根拠](https://www.mhlw.go.jp/stf/newpage_11389.html) | 原典本文追試 |
| 56 | `sm2-5y-r08-hyg-05` | 4 | × / × / × / ○ / × | 発電機を屋外安全位置に設け排気の屋内流入を防止 | [根拠](https://www.mhlw.go.jp/web/t_doc?dataId=00tb7875&dataType=1&pageNo=1) | 原典本文追試 |
| 57 | `sm2-5y-r08-hyg-06` | 2 | × / ○ / × / × / × | ボツリヌス毒素はアセチルコリン放出を阻害し弛緩性麻痺 | [根拠](https://www.mhlw.go.jp/content/10900000/001464074.pdf) | 直接確認 |
| 58 | `sm2-5y-r08-hyg-07` | 4 | × / × / × / ○ / × | 手指衛生・換気・体調不良者対応で拡大防止 | [根拠](https://www.mhlw.go.jp/content/11302000/001741252.pdf) | 原典本文追試 |
| 59 | `sm2-5y-r08-hyg-08` | 1 | ○ / × / × / × / × | 重量と力点距離から外力モーメントは比例。40cmは10cmの4倍 | [根拠](https://www.mhlw.go.jp/stf/newpage_31158.html) | 力学計算・原典直接性追試 |
| 60 | `sm2-5y-r08-hyg-09` | 5 | × / × / × / × / ○ | 音の強さ10倍→10log10(10)=10dB。音圧振幅の比とは別 | [根拠](https://www.osha.gov/otm/section-3-health-hazards/chapter-5) | 計算確認・OSHA原典未再閲覧 |
| 61 | `sm2-5y-r08-hyg-10` | 3 | × / × / ○ / × / × | 咳の際ティッシュまたは腕で口鼻を覆い手洗い | [根拠](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/kenkou/kekkaku-kansenshou/infulenza/QA2026.html) | 原典URL追試 |
| 62 | `sm2-5y-r09-hyg-01` | 2 | × / ○ / × / × / × | AED『ショック不要』後も正常呼吸がなければ胸骨圧迫再開 | [根拠](https://www.fdma.go.jp/relocation/kyukyu_sosei/sisin2015.pdf) | 旧2015版・現行ガイド要確認 |
| 63 | `sm2-5y-r09-hyg-02` | 5 | × / × / × / × / ○ | 眼に洗浄剤が入った場合は流水洗浄、SDSと医療相談 | [根拠](https://anzeninfo.mhlw.go.jp/anzen/gmsds/88-85-7.html) | 個別SDS物質との対応追試 |
| 64 | `sm2-5y-r09-hyg-03` | 1 | ○ / × / × / × / × | 自由音場点音源では距離2倍により20log10(2)=6.02dB減 | [根拠](https://www.osha.gov/otm/section-3-health-hazards/chapter-5) | 計算確認・原典未再閲覧 |
| 65 | `sm2-5y-r09-hyg-04` | 4 | × / × / × / ○ / × | 長時間立位の作業高・交替姿勢・休憩で負担軽減 | [根拠](https://www.mhlw.go.jp/web/t_doc?dataId=00tb9484&dataType=1) | 指針本文追試 |
| 66 | `sm2-5y-r09-hyg-05` | 3 | × / × / ○ / × / × | 暑熱非順化者は段階的に負荷を上げ休憩・補給を確保 | [根拠](https://neccyusho.mhlw.go.jp/heat_index/) | 直接確認 |
| 67 | `sm2-5y-r09-hyg-06` | 1 | ○ / × / × / × / × | 固定後足先の血流・冷感悪化は圧迫を再評価し救急に伝達 | [根拠](https://www.fdma.go.jp/relocation/syobodan/item/upload/tetyou2025.pdf) | 原典本文追試 |
| 68 | `sm2-5y-r09-hyg-07` | 3 | × / × / ○ / × / × | 化学防護手袋は破過時間と使用90分・実使用条件からBを候補 | [根拠](https://www.mhlw.go.jp/web/t_doc?dataId=00tc2426&dataType=1) | 数値の設問条件確認・原典追試 |
| 69 | `sm2-5y-r10-hyg-01` | 4 | × / × / × / ○ / × | ストレスチェック10人未満でも非特定手法+事前衛生委員会審議なら同意不要提供例外 | [根拠](https://www.mhlw.go.jp/web/t_doc?dataId=00tc1015&dataType=1&pageNo=1) | 直接確認 |

### 今回新たに発見した優先確認対象

1. **No.52 `sm2-5y-r08-hyg-01`**：厚労省の睡眠ガイド2023に夜勤中仮眠の記述はあるが、選択肢の「20〜50分程度」という幅が原典本文のどこで支持されるかは未確認。正答位置3を機械的にPASSとせず、具体数値の根拠・表現の再設計要否を検討する。
2. **No.62 `sm2-5y-r09-hyg-01`**：出典が消防庁2015ガイド。最新版の救急蘇生手順との整合・変更有無を別途確かめる。
3. **No.69 `sm2-5y-r10-hyg-01`**：10人未満例外は無条件ではない。非特定の分析手法と衛生委員会の事前審議を要件として保持する。
4. **No.41 `sm2-5y-r06-hyg-02`**：厚労省公表のCO2濃度測定器留意点では人から50cm以上離すと明記。原URLより直接的な公的資料を併記した。

### 分割Aの進捗とQ0ゲートへの投入制限

- **69/69問（345肢）の配布bank取得・5肢一次判定欄の作成は完了**。これは監査作業の進捗であり、正式な一次確認合格69件を意味しない。
- 全問を各肢の根拠条文・施行版・適用範囲に対応付ける完了証跡は不足しており、**新Q0基準の一次確認完了数は0/69として保守的に据置**。
- 既存40件とのID重複確認・配布bank SHA-256算出・原典の逐肢直接性・著作権の判断は未完。独立二重チェックやQ0/Q1判定にも計上しない。
- 問題データ・生成元・台帳本体の変更なし。App Review提出なし、新規TestFlight配信なし。
