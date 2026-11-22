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
