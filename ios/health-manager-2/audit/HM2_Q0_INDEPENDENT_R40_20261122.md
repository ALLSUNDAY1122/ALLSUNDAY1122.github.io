# HM2 Q0 独立R40（2026-11-22）

- 担当：独立レビュー用セッション（GPT-6）。先行レビューの判定・DC本文・他の監査結果は判定根拠に使用しない。固定ID集合を得るため、既存の178問ID表の冒頭40IDのみ抽出。
- 参照bank：`ios/health-manager-2/release-questions.json`、Git blob `4ecbfea81e3a453aa6bf60e4647d880abf821c09`。SHA-256バイト値は本セッションで別途実測していない。
- 対象：40問×5肢＝200肢。各選択肢の記載を配布bankから読み取り、意味判定を独自に作成。○は正しい肢、×は誤りの肢。出典リンクの直接条文を基準とし、後段の実際の逐語照合範囲には限界がある。
- 2026年法令版照合入口： [労働安全衛生規則（2026-11-01時点）](https://laws.e-gov.go.jp/law/347M50002000032?occasion_date=20261101)、[労働基準法（2026-10-23時点）](https://laws.e-gov.go.jp/law/322AC0000000049?occasion_date=20261023)、[厚労省 労働時間・休日](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/roudouzikan/index.html)、[2025-01電子申請](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/denshishinsei_00002.html)。2026-11-22に厚労省の法令本文と公的説明資料を確認した。e-Gov法令検索のHTML本文は本環境で読み取り不可のためe-Gov直接照合は未実施。将来施行を含む全改正附則の通史調査は対象外。

## 40問の独立内容判定

| No | ID | 正肢(1起算) | 五肢判定(①〜⑤) | 独立判断の根拠・誤肢排除 | 根拠条項 | 区分 |
|---:|---|---:|---|---|---|---|
| 1 | `sm2-5y-r04-law-02` | 5 | × / × / × / × / ○ | 50人到達で義務が発生し、選任期限は14日。100人・即日のみ・30日・健診時点はいずれも法定期限でない。 | 労働安全衛生法12条・同施行令4条／労働安全衛生規則7条1項1号 | PASS（厚労省公式原典） |
| 2 | `sm2-5y-r04-law-03` | 1 | ○ / × / × / × / × | 製造業は第二種免許単独での選任対象外。同意・産業医併置・50人超過で資格要件は免除されない。 | 労働安全衛生規則7条1項3号イ／製造業の資格要件 | PASS（厚労省公式原典） |
| 3 | `sm2-5y-r04-law-04` | 4 | × / × / × / ○ / × | 常時10人以上の就業規則は所轄労基署長に届出。知事・市町村・代表への手渡しでは代替不可。 | 労働基準法89条 | PASS（厚労省公式原典） |
| 4 | `sm2-5y-r04-law-05` | 3 | × / × / ○ / × / × | 衛生管理者2人以上で労働衛生コンサルタントを含むと1人に専属例外。300人で3人義務との記載も誤り。 | 労働安全衛生規則7条1項2号ただし書・10条3号 | PASS（厚労省公式原典） |
| 5 | `sm2-5y-r04-law-07` | 3 | × / × / ○ / × / × | 衛生委員会は毎月1回以上。四半期・半年・年1回や健診成績による免除はない。 | 労働安全衛生法18条・労働安全衛生法施行令9条・労働安全衛生規則23条1項 | PASS（厚労省公式原典） |
| 6 | `sm2-5y-r04-law-08` | 5 | × / × / × / × / ○ | 変更も届出対象で、過半数労組等の意見聴取・意見書添付が必要。全員の同意とは区別。 | 労働基準法89条・90条 | PASS（厚労省公式原典） |
| 7 | `sm2-5y-r04-law-09` | 2 | × / ○ / × / × / × | 通貨・直接・全額・毎月1回以上・一定期日。労使協定や口座振込の条件付き例外は原則を否定しない。 | 労働基準法24条 | PASS（厚労省公式原典） |
| 8 | `sm2-5y-r04-law-10` | 4 | × / × / × / ○ / × | 議事概要の電磁的周知は常時閲覧可能な機器を各作業場に設置。役員限定・閲覧不能・遅延周知は不可。 | 労働安全衛生規則23条3項3号 | PASS（厚労省公式原典） |
| 9 | `sm2-5y-r05-law-02` | 1 | ○ / × / × / × / × | 衛生管理者には衛生措置権限の付与が必要。産業医の権限、人数、健診日とは無関係。 | 労働安全衛生規則11条2項 | PASS（厚労省公式原典） |
| 10 | `sm2-5y-r05-law-03` | 5 | × / × / × / × / ○ | 衛生委員会は常時50人以上で業種を問わず必要。衛生管理者・健診による義務代替はない。 | 労働安全衛生法18条・労働安全衛生法施行令9条 | PASS（厚労省公式原典） |
| 11 | `sm2-5y-r05-law-04` | 2 | × / ○ / × / × / × | 一般原則は1日8時間・週40時間。設問では変形制・適用除外を明示的に除いている。 | 労働基準法32条1項・2項 | PASS（厚労省公式原典） |
| 12 | `sm2-5y-r05-law-05` | 3 | × / × / ○ / × / × | 電話応対義務のある待機は労働から解放された休憩に当たらない。9時間労働なら自由利用可能な60分が必要。 | 労働基準法34条3項／休憩の自由利用 | PASS（厚労省公式原典） |
| 13 | `sm2-5y-r05-law-07` | 2 | × / ○ / × / × / × | 委員会の意見と講じた措置が記録対象。費用・売上等だけでは法定記録に不足。 | 労働安全衛生規則23条4項1号 | PASS（厚労省公式原典） |
| 14 | `sm2-5y-r05-law-08` | 4 | × / × / × / ○ / × | 雇入時等の受診から1年間の相当項目に限る省略。健診義務全体の免除ではない。 | 労働安全衛生規則44条3項 | PASS（厚労省公式原典） |
| 15 | `sm2-5y-r05-law-09` | 1 | ○ / × / × / × / × | 業務上傷病による療養休業期間とその後30日間。法定例外を設問で除外。 | 労働基準法19条1項 | PASS（厚労省公式原典） |
| 16 | `sm2-5y-r06-law-02` | 5 | × / × / × / × / ○ | 聴力代替は45歳未満のうち35歳・40歳を除く。30歳は医師が認める代替検査可。 | 労働安全衛生規則44条4項 | PASS（厚労省公式原典） |
| 17 | `sm2-5y-r06-law-03` | 2 | × / ○ / × / × / × | 6時間超8時間以下の休憩下限45分。6時間30分は無休憩・15分では足りない。 | 労働基準法34条1項 | PASS（厚労省公式原典） |
| 18 | `sm2-5y-r06-law-04` | 1 | ○ / × / × / × / × | 年休管理簿の法定記載は時季・日数・基準日。売上・病歴・通勤経路等は対象外。 | 労働基準法施行規則24条の7／年休管理簿の記録事項 | PASS（厚労省公式原典） |
| 19 | `sm2-5y-r06-law-05` | 4 | × / × / × / ○ / × | 健診実施義務は50人未満の常時使用対象労働者にも及ぶ。報告規模とは異なる。 | 労働安全衛生規則44条（結果報告は同52条） | PASS（厚労省公式原典） |
| 20 | `sm2-5y-r06-law-07` | 4 | × / × / × / ○ / × | 健診個人票は5年間保存。常時30人では一般定期健診の安衛則52条報告義務なし。 | 労働安全衛生規則44条・51条・52条（個人票保存と結果報告の区別） | PASS（厚労省公式原典） |
| 21 | `sm2-5y-r06-law-08` | 1 | ○ / × / × / × / × | 法定時間外労働の前提は労使の36協定締結と所轄労基署長への届出。就業規則等では代替不可。 | 労働基準法36条 | PASS（厚労省公式原典） |
| 22 | `sm2-5y-r06-law-09` | 5 | × / × / × / × / ○ | 法定作業環境測定の実施・記録が必要。体感や健康診断で測定記録の代替不可。 | 労働安全衛生法65条 | PASS（厚労省公式原典） |
| 23 | `sm2-5y-r06-law-10` | 3 | × / × / ○ / × / × | 異常所見がある健診について医師等意見聴取は原則健診日から3か月以内。 | 労働安全衛生規則51条の2第1項 | PASS（厚労省公式原典） |
| 24 | `sm2-5y-r07-law-02` | 5 | × / × / × / × / ○ | 特定業務従事者の健診は配置替え時および6か月以内ごと1回。検査項目省略の別規定あり。 | 労働安全衛生規則45条 | PASS（厚労省公式原典） |
| 25 | `sm2-5y-r07-law-03` | 1 | ○ / × / × / × / × | 単胎妊娠の産前6週間以内の請求は就業させられない。請求要件と産後強制休業を区別。 | 労働基準法65条1項 | PASS（厚労省公式原典） |
| 26 | `sm2-5y-r07-law-04` | 4 | × / × / × / ○ / × | 産業医巡視は原則少なくとも毎月1回。一定要件の2か月緩和は設問で除外。 | 労働安全衛生規則15条1項 | PASS（厚労省公式原典） |
| 27 | `sm2-5y-r07-law-05` | 3 | × / × / ○ / × / × | 週30時間未満かつ週4日以下は比例付与対象となり得る。週5日・28時間は原則通常付与。 | 労働基準法39条3項・労働基準法施行規則24条の3 | PASS（厚労省公式原典） |
| 28 | `sm2-5y-r07-law-07` | 3 | × / × / ○ / × / × | 産業医選任事由発生日から14日以内。30日・60日・年度末ではない。 | 労働安全衛生規則13条1項1号 | PASS（厚労省公式原典） |
| 29 | `sm2-5y-r07-law-08` | 5 | × / × / × / × / ○ | 統括管理者を産業医に選任できない。医師資格、非専属、委員会承認だけで例外にならない。 | 労働安全衛生規則13条1項2号ハ | PASS（厚労省公式原典） |
| 30 | `sm2-5y-r07-law-09` | 2 | × / ○ / × / × / × | 15歳到達後最初の3月31日終了まで原則使用不可。単なる15歳誕生日までではない。 | 労働基準法56条1項 | PASS（厚労省公式原典） |
| 31 | `sm2-5y-r07-law-10` | 4 | × / × / × / ○ / × | 55人の一般事務所は産業医の選任義務あり、専属・2人選任の閾値には達しない。 | 労働安全衛生法13条・労働安全衛生法施行令5条・労働安全衛生規則13条1項3号 | PASS（厚労省公式原典） |
| 32 | `sm2-5y-r08-law-02` | 1 | ○ / × / × / × / × | 著しい暑熱の場所で常時500人以上の業務なら専属産業医。事業場全体1000人未満でも例外ではない。 | 労働安全衛生規則13条1項3号イ／産業医の専属要件（1,000人以上または一定有害業務500人以上） | PASS（厚労省公式原典） |
| 33 | `sm2-5y-r08-law-03` | 5 | × / × / × / × / ○ | 雇入時健診とは別に対象者の一般定期健診を原則1年以内ごとに実施。相当項目省略は別扱い。 | 労働安全衛生規則43条・44条 | PASS（厚労省公式原典） |
| 34 | `sm2-5y-r08-law-04` | 2 | × / ○ / × / × / × | 深夜労働割増は25%以上。時間外・休日の割増との重複は別規定。 | 労働基準法37条4項・労働基準法施行規則20条 | PASS（厚労省公式原典） |
| 35 | `sm2-5y-r08-law-05` | 3 | × / × / ○ / × / × | 一般定期健診は49人事業場でも対象者に義務、結果報告は常時50人以上。 | 労働安全衛生規則44条・52条（健診実施義務と報告義務の規模閾値） | PASS（厚労省公式原典） |
| 36 | `sm2-5y-r08-law-07` | 2 | × / ○ / × / × / × | 60人事業場の定期健診結果は遅滞なく所轄労基署長へ原則電子申請。本人通知・個人票保存は代替不可。 | 労働安全衛生規則51条・51条の4・52条／2025年1月1日電子申請義務化 | PASS（厚労省公式原典） |
| 37 | `sm2-5y-r08-law-08` | 4 | × / × / × / ○ / × | 年10日以上付与時は年5日取得確保。自己取得3日を算入して不足2日。 | 労働基準法39条7項・8項 | PASS（厚労省公式原典） |
| 38 | `sm2-5y-r08-law-09` | 1 | ○ / × / × / × / × | 安衛則11条の列挙語は設備・作業方法・衛生状態。他選択肢は法定の列挙語を別概念に置換。 | 労働安全衛生規則11条1項 | PASS（厚労省公式原典） |
| 39 | `sm2-5y-r08-law-10` | 3 | × / × / ○ / × / × | 120平方メートル×3メートル÷10人=36立方メートル/人。法定気積で設備占有体積除外が必要な点と区別。 | 事務所衛生基準規則2条（法定算定条件との区別） | PASS（厚労省公式原典） |
| 40 | `sm2-5y-r09-law-02` | 5 | × / × / × / × / ○ | 実労働7時間は6時間超8時間以下で45分以上。 | 労働基準法34条1項 | PASS（厚労省公式原典） |

## 結論と保留の厳格区別

- **問題文と5肢の内容を独立に見た暫定判定：40/40で配布bankの正答位置と明白な矛盾なし。200肢に個別の○×を記録。**

## 第2工程：公式原典との個別照合（2026-11-22）

厚生労働省が公開する労働安全衛生規則・労働基準法・施行規則・安衛法・事務所衛生基準規則の本文および厚労省FAQを使用。表中の原典と上段の各問別誤肢排除理由を組み合わせて判定。閲覧日2026-11-22。e-Govは法令IDのみ特定できたが本文の取得ができず、e-Gov本文を直接読んだとは扱わない。

| No | 直接根拠URL（厚労省） | 結果 |
|---:|---|---|
| 1 | [s1](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1)・[faq](https://www.mhlw.go.jp/seisakunitsuite/bunya/koyou_roudou/roudoukijun/faq/5.html) | PASS |
| 2 | [s1](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1)・[faq](https://www.mhlw.go.jp/seisakunitsuite/bunya/koyou_roudou/roudoukijun/faq/5.html) | PASS |
| 3 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0) | PASS |
| 4 | [s1](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1)・[faq](https://www.mhlw.go.jp/seisakunitsuite/bunya/koyou_roudou/roudoukijun/faq/5.html) | PASS |
| 5 | [s2](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | PASS |
| 6 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0) | PASS |
| 7 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0) | PASS |
| 8 | [s2](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | PASS |
| 9 | [s1](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1) | PASS |
| 10 | [s2](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | PASS |
| 11 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0) | PASS |
| 12 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0)・[tel](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/faq/faq_kijyunhou.html) | PASS |
| 13 | [s2](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | PASS |
| 14 | [s2](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | PASS |
| 15 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0) | PASS |
| 16 | [s2](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | PASS |
| 17 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0) | PASS |
| 18 | [lr](https://www.mhlw.go.jp/web/t_doc?dataId=73023000&dataType=0&pageNo=1) | PASS |
| 19 | [s2](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | PASS |
| 20 | [s2](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | PASS |
| 21 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0) | PASS |
| 22 | [act](https://www.mhlw.go.jp/web/t_doc?dataId=74001000) | PASS |
| 23 | [s2](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | PASS |
| 24 | [s2](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | PASS |
| 25 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0) | PASS |
| 26 | [s1](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1) | PASS |
| 27 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0)・[lr](https://www.mhlw.go.jp/web/t_doc?dataId=73023000&dataType=0&pageNo=1) | PASS |
| 28 | [s1](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1) | PASS |
| 29 | [s1](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1) | PASS |
| 30 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0) | PASS |
| 31 | [s1](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1) | PASS |
| 32 | [s1](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1) | PASS |
| 33 | [s2](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | PASS |
| 34 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0) | PASS |
| 35 | [s2](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2) | PASS |
| 36 | [s2](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2)・[el](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/denshishinsei_00002.html) | PASS |
| 37 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0) | PASS |
| 38 | [s1](https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=1) | PASS |
| 39 | [off](https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1) | PASS |
| 40 | [lb](https://www.mhlw.go.jp/web/t_doc?dataId=73022000&dataType=0) | PASS |

## 結論

- **内容照合PASS：40/40問、計200肢。内容HOLD：0問。** 各問5肢の正誤の根拠は上表、公式法令URLは本節に記録。正答・設問の改修不要。
- PASSは2026-11-22時点の設問条件に限る。個々の附則を含む法令改正履歴の全期間保証、権利侵害不存在、将来改正の適用、Q0総合ゲートPASSとは異なる。
- 他セッションのレビュー・DC・監査台帳の判定は参照せず、対象IDの取得以外のレビュー結果を入力にしていない。配布bankは前節固定のGit blobを対象とする。
- 問題本体・生成元・提出ゲート変更なし。App Review提出・TestFlight配信なし。
