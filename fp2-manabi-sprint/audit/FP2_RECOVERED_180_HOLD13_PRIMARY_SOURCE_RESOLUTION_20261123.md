# FP2復旧180問｜HOLD13件の一次資料による独立再判定（2026-11-23）

- 参照ブランチ：`feature/fp2-release-scope-20261123`。元問題バンク：`fp2-manabi-sprint/questions/draft/fp2-recovered-180-fulltext-20261123.json`／blob SHA `9ccf23febc574448169b04b50473ec0cc7c11fe0`。
- 法令基準日：**2026-04-01**。原題の作成基準日は2026-05公表分2025-04-01、2025-05公表分2024-04-01、2025-01公表分2024-10-01。
- 旧監査Batch01〜06に記録された固有HOLD13件を対象に再審査し、国税庁法令解釈通達、金融庁監督指針、ASBJ会計基準、年金法令、保険会社約款、公式試験PDF等を照合。
- **再判定結果 PASS12 / FAIL1 / HOLD0。HOLD解消13/13件。** 今回追加したHigh誤解説1件：2025-01問13。Critical0。
- 先行全180問の暫定内容判定 PASS163/FAIL4/HOLD13 から、**PASS175 / FAIL5 / HOLD0** へ更新。判定ID件数180/180を維持。
- **注意**：PASSは設問内容・登録正答の法令整合に限定。公式原題との改変有無、`modified:null`の解消、権利・利用表示、実アプリへの実装と回帰試験は未検査・未完了。厳格な公開申請承認数は0件。元JSONの値は変更しない。

## 個別13件の判定と一次根拠

|問題ID|旧→新|結論・四肢を考慮した再判定理由|一次資料URL|
|---|---|---|---|
|`fp2-2025-05-gakka-010`|HOLD→**PASS**|日本FP協会公式PDF表示6頁を画面確認。流動資産12000、流動負債1500、固定資産8000、固定負債2500、純資産16000、純利益800（百万円）がJSONと一致。①16000/20000=80%、②12000/1500=800%、③8000/(2500+16000)=43.24%で50%は誤り、④800/16000=5%。正答③。|https://www.jafp.or.jp/exam/mohan/files/g2_202505_qa.pdf#page=7|
|`fp2-2025-05-gakka-028`|HOLD→**PASS**|日本FP協会公式PDF表示15頁を画面確認。預金60%×0.1%=0.06%、債券10%×1%=0.10%、株式30%×7%=2.10%、合計2.26%で正答③。①0.32%、②1.10%、④2.70%は不一致。公式表にある標準偏差0%、5%、15%は復旧JSONでは省略されているためmodified=true等による省略表示を別途明示する必要あり。|https://www.jafp.or.jp/exam/mohan/files/g2_202505_qa.pdf#page=16|
|`fp2-2025-01-gakka-005`|HOLD→**PASS**|①企業型DC規約の承認は都道府県知事でなく厚生労働大臣、②退職一時金制度からの移換は所定期間・方法に基づき単年度一括不可、③DBから企業型DCへの移換で60歳前までの期間を通算加入者等期間に通算する旨は法令の条文と整合、④中退共から企業型DCへの所定の移換制度はある。正答③。|https://laws.e-gov.go.jp/law/413M60000100175/20260401_507M60000100110 ; https://www.mhlw.go.jp/web/t_doc?dataId=00tb1885&dataType=1|
|`fp2-2025-01-gakka-016`|HOLD→**PASS**|①法人受取終身保険は資産計上で全額損金不可、②養老保険で全員・遺族死亡受取、本人満期受取なら全額資産計上と断定不可、③特定役員を対象に遺族受取の定期保険料は原則役員への給与で正答、④2024年契約・終身払・解約返戻金なし第三分野保険を最高解約返戻率75%の定期保険に適用する60%資産計上区分とは同視できない。|https://www.nta.go.jp/law/tsutatsu/kihon/hojin/09/09_03.htm ; https://www.nta.go.jp/taxes/shiraberu/taxanswer/hojin/5364.htm|
|`fp2-2026-05-gakka-011`|HOLD→**PASS**|①共済は保険法の対象となるものがあり『一切非適用』が誤り、②保険法52条・53条の片面的強行規定で受取人不利の支払時期約款が無効（正答）、③保険期間1年以下は原則クーリングオフ適用除外、④早期是正措置の指標は300%でなく200%。|https://laws.e-gov.go.jp/law/420AC0000000056?occasion_date=20260202 ; https://www.fsa.go.jp/receipt/soudansitu/advice02.html ; https://www.fsa.go.jp/news/newsj/17/hoken/f-20050812-7.html|
|`fp2-2026-05-gakka-013`|HOLD→**PASS**|①加入同意は金融庁監督指針で求められ告知制度も存在、②総合福祉団体定期の保険期間は通常1年で5年まで個人別設定でない、③福利厚生型定期保険を機械的に1/2資産計上はしない、④ヒューマン・ヴァリュー特約の死亡保険金受取人は契約企業。正答④。会社・保険者の契約資料と監督指針で同意確認を照合。|https://www.fsa.go.jp/common/law/guide/ins/04.html ; https://www.sonylife.co.jp/contractor/fukushi/insured/ ; https://www.meijiyasuda.co.jp/corporation/product/service/shiori/pdf/003.pdf|
|`fp2-2026-05-gakka-037`|HOLD→**PASS**|①法人税本税還付金の益金不算入・還付加算金の益金算入、②完全子法人株式等の受取配当原則全額益金不算入、③資産譲渡収益は引渡時点認識が原則、④棚卸資産評価増に係る評価益は法人税法25条により原則益金不算入で誤肢。正答④。|https://www.nta.go.jp/about/organization/ntc/kohon/houjin/pdf/all.pdf ; https://www.nta.go.jp/law/tsutatsu/kihon/hojin/02/02_01_05.htm|
|`fp2-2026-05-gakka-038`|HOLD→**PASS**|①会社から役員への無利息貸付は原則認定利息の問題がある、②債務免除益は原則会社益金、③役員から会社への土地無償贈与は時価の1/2でなく時価全額の受贈益（誤肢）、④役員が会社から時価未満で譲り受ける差額は原則役員給与として経済的利益。正答③。①の経済的利益を認定する『原則』に低額貸付の例外があっても正答一意性は変わらない。|https://www.nta.go.jp/taxes/shiraberu/taxanswer/hojin/5202.htm ; https://www.nta.go.jp/about/organization/ntc/kohon/houjin/pdf/all.pdf|
|`fp2-2026-05-gakka-040`|HOLD→**PASS**|①税引前利益に減価償却・運転資本調整、②資金調達は原則総額表示、③企業が現金同等物とほぼ同様に利用する当座借越は負の現金同等物とする旨が会計基準移管指針第6号に明記、④固定資産増加は投資CFだが借入返済・配当支払は財務CFなので一括して投資CF減少は誤り。正答④。|https://www.asb-j.jp/jp/accounting_standards_system/details.html?topics_id=121|
|`fp2-2025-05-gakka-015`|HOLD→**PASS**|①養老保険で死亡受取人遺族・満期受取人法人の場合は原則半額資産・半額損金で全額損金とする記述が誤り、②法人受取終身保険は資産計上、③無解約返戻金・全期払の第三分野保険の保険料は原則期間対応損金、④最高返戻率75%は70%超85%以下の区分で前半40%期間に保険料60%資産計上と国税庁通達9-3-5の2の表に一致。正答①。|https://www.nta.go.jp/taxes/shiraberu/taxanswer/hojin/5363.htm ; https://www.nta.go.jp/law/tsutatsu/kihon/hojin/09/09_03.htm|
|`fp2-2025-05-gakka-018`|HOLD→**PASS**|①従業員全員を被保険者・受取人とする通常の普通傷害保険料は福利厚生の保険料として損金算入し得る、②5年一時払い火災保険料は前払分資産化・期間按分、③会社の受取保険金と修理費用は別々の経理処理、④棚卸資産の保険金は固定資産保険差益の圧縮記帳対象外。なお①は全員加入・均等な一般福利厚生・契約条件を前提とする。正答①。|https://www.nta.go.jp/law/tsutatsu/kihon/hojin/09/09_03.htm ; https://www.nta.go.jp/about/organization/ntc/kohon/houjin/pdf/all.pdf|
|`fp2-2025-01-gakka-013`|HOLD→**FAIL**|High：①確定年金の死亡給付金は年金受取総額そのままではない、②終身年金は通常平均余命長い女性が保険料高、③MVAは金利上昇時に解約返戻金が下がる一般的効果で登録正答③は維持、④円換算支払特約は契約から受取までの為替リスクを除去しない。しかし**解説④に『円換算支払特約は年金等受取時の円転換レートを固定するだけ』と書かれ、保険会社の円支払特約の当日所定レート・変動リスクと矛盾。レートは契約時に固定されない。誤指導を削除し、『受取時の所定日の為替レートで円換算されるため為替リスクは残る』へ要訂正。MVA商品類型も変額商品一般との誤認を防ぐ注記推奨。|https://www.jili.or.jp/knows_learns/q_a/life_insurance/134.html ; https://www.seiho.or.jp/data/billboard/market/ ; https://www.meijiyasuda.co.jp/contractor/myhoken/relation/ad_attention.html ; https://www.meijiyasuda.co.jp/my_web_yakkan/pdf/2024/4020070520241001.pdf|
|`fp2-2025-01-gakka-039`|HOLD→**PASS**|①役員が法人へ無利息で貸す場合は受け取っていない利息を自動的に役員雑所得へ算入する原則はなく誤り（正答①）、②役員からの債務免除は法人の益金、③役員無償社宅は賃貸料相当額が給与課税、④会社が時価超で資産を役員に売却した場合の超過受領分は受贈益に相当する（ただし取引実態による）。国税庁No.5202の『役員から時価超で資産を買い入れた場合』は逆方向であり、この設問④へ誤転用しない。|https://www.nta.go.jp/taxes/shiraberu/taxanswer/hojin/5202.htm ; https://www.nta.go.jp/about/organization/ntc/kohon/houjin/pdf/all.pdf|

## 追加の修正指示

- **High：`fp2-2025-01-gakka-013`**：登録正答③は変更不要。ただし解説④の『円換算支払特約は受取時の円転換レートを固定するだけ』は誤り。円換算には受取時点等に定めた所定日の為替レートを使い、為替リスクは残る。解説修正と再監査後にPASS可。
- 図表の`fp2-2025-05-gakka-010`および`fp2-2025-05-gakka-028`は公式PDFの該当ページを画像で照合済み。問28では標準偏差列が復旧JSONで省略されており、出典改変表示にその旨の記録が必要。
- 他の既存FAILはBatch04問36・問39およびBatch05問17・問20であり、この再判定で自動的に解消しない。修正元データ・テスト証跡と突合してから別監査が必要。
- 補正履歴を残すため先行6本の監査記録を改変せず、この再判定を最新の追記記録とする。
