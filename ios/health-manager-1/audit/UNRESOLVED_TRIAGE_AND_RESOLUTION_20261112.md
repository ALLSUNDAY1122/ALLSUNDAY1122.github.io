# 第一種衛生管理者｜全264問・未解決事項3群仕分けと第1次代替原典追証（2026-11-12）

**ブランチ**：`codex/hm1-integrate-basic-a-b-c-20261111`。基準コミット`d56f0fb0c4889881357c4ebd6fbebda27c46504a`。

## 集計基準
統合残件台帳のPENDING 15 ID、PARTIAL 43 IDと、登録URL障害グループを問題IDに展開して和集合とし、後続の修正済み記録がある歴史IDを除外。重複はIDごと1回。以下の **a は「公開資料による対応が可能・見込みの項目」** であり解消済み数ではない。bは特定の不可欠な有料規格が確認された場合のみ、cは問題の条件自体に修正を要する場合のみ計上。分類は継続調査で更新可能。

| 分類 | 件数 | 内容 |
|---|---:|---|
| a：到達可能な代替一次資料・公開資料で追証／URL差替え可能な候補 | **84** | 未解決のまま残る項目も含む |
| b：特定の有料・制限規格への依存で到達自体が困難と確認した項目 | **0** | 現台帳に特定の有料JIS本文が必須と確定する項目はない |
| c：設問内容自体の修正が必要 | **1** | 基本2026-04-Q25の適用事業場区分 |
| **合計（重複なし）** | **85** | 全264問を再カウントした数ではなく追跡対象のID数 |

## 対象ID一覧
**a（84件）**：`2025-04-Q34`、`2025-04-Q36`、`2025-04-Q37`、`2025-04-Q38`、`2025-04-Q40`、`2025-04-Q43`、`2025-10-Q01`、`2025-10-Q02`、`2025-10-Q06`、`2025-10-Q10`、`2025-10-Q14`、`2025-10-Q15`、`2025-10-Q37`、`2025-10-Q39`、`2025-10-Q44`、`2026-04-Q02`、`2026-04-Q04`、`2026-04-Q08`、`2026-04-Q12`、`2026-04-Q13`、`2026-04-Q14`、`2026-04-Q15`、`2026-04-Q17`、`2026-04-Q19`、`2026-04-Q20`、`2026-04-Q28`、`2026-04-Q29`、`2026-04-Q30`、`2026-04-Q31`、`2026-04-Q33`、`2026-04-Q34`、`2026-04-Q41`、`2026-04-Q42`、`2026-04-Q43`、`2026-04-Q44`、`practice-A-Q08`、`practice-A-Q11`、`practice-A-Q13`、`practice-A-Q20`、`practice-A-Q21`、`practice-A-Q26`、`practice-A-Q27`、`practice-A-Q28`、`practice-A-Q33`、`practice-A-Q34`、`practice-A-Q37`、`practice-A-Q39`、`practice-B-Q08`、`practice-B-Q20`、`practice-B-Q27`、`practice-B-Q28`、`practice-B-Q31`、`practice-B-Q33`、`practice-C-Q01`、`practice-C-Q02`、`practice-C-Q03`、`practice-C-Q04`、`practice-C-Q05`、`practice-C-Q06`、`practice-C-Q07`、`practice-C-Q08`、`practice-C-Q09`、`practice-C-Q10`、`practice-C-Q14`、`practice-C-Q15`、`practice-C-Q17`、`practice-C-Q18`、`practice-C-Q19`、`practice-C-Q20`、`practice-C-Q21`、`practice-C-Q22`、`practice-C-Q26`、`practice-C-Q29`、`practice-C-Q30`、`practice-C-Q31`、`practice-C-Q32`、`practice-C-Q33`、`practice-C-Q34`、`practice-C-Q35`、`practice-C-Q36`、`practice-C-Q37`、`practice-C-Q41`、`practice-C-Q42`、`practice-C-Q44`。

**b（0件）**：該当確定なし。

**c（1件）**：`2026-04-Q25`。

なおJISはJISCで国内登録者の無料閲覧が可能だが、印刷・ダウンロード不可で商用複製等には許諾が必要（https://www.jisc.go.jp/site/kiyaku.html）。閲覧制限だけを理由に有料規格依存と断定しない。**この分類は全件をその場で追証完了したことを意味しない**。

## a群：今回着手した個別成果
1. **演習C Q29（教材生成元変更あり）**：登録の厚労省旧URLから現行Q&A `https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/shokuhin/syokuchu/campylobacterqa.html` へ、最終上書き元`audit/practice_c_fixes_21_30.json`の`sourceRef`と`auditSourceURL`のみを差替え。問題・選択肢・正答index・detailは不変。厚労省Q&Aで生肉器具経由の交差汚染と洗浄・消毒を確認。**264問Node CLI再生成と配布JSON限定差分は本担当未実施**。
2. **演習C Q34（問題データ変更なし）**：既存の副腎髄質原典に加え、NCBI `https://www.ncbi.nlm.nih.gov/sites/books/NBK539845/` の交感神経節後ノルアドレナリン放出、およびヒト心臓の局所神経分布の研究 `https://pmc.ncbi.nlm.nih.gov/articles/PMC12353864/` を追証。副腎髄質と心臓局所伝達を別資料で裏づけた中心命題追証であり、全5肢の独立逐語PASSではない。
3. **演習C Q42（問題データ変更なし）**：NCBI `https://www.ncbi.nlm.nih.gov/sites/books/NBK532978/` とOpenStax Biology 2e `https://openstax.org/books/biology-2e/pages/36-4-hearing-and-vestibular-sensation` で半規管の角加速度を直接確認。小脳の運動協調は既登録OpenStax16.5に依拠。中心命題追証まで、全肢直接PASSではない。

## c群：修正が必要な問題
- **基本2026-04-Q25**：問題文「屋内作業場」は事務所以外を含むが、根拠の事務所衛生基準規則第1条・第3条は「事務所」・「事務室」を対象とする。200㎡の1/20=10㎡、既存8㎡との差2㎡の計算自体は成立するが、対象条件を「事務作業従事者が主として使用する事務室」等に限定する必要がある。今回は**問題データを変更しない**。根拠本文：https://www.mhlw.go.jp/web/t_doc?dataId=74089000 。

## 未解決事項・引き継ぎ
- a群の未処理項目は引き続きOPEN。NCBI `/books/`のreCAPTCHA、e-GovのJavaScript本文抽出不可、RCPA 403、NRA PDF取得障害、教材で旧URLのままの箇所について、設問単位で実際の代替経路・条文と改正時点を確認して修正する。
- 過去の修正済みの解説肢番号（演習B Q09/Q12など）を新たな未修正として二重計上しない。a/c区分は初回台帳のスナップショットのため、閉鎖前に現行264問生成値との照合が必要。
- **問題データ変更は演習C Q29の出典参照2フィールドと監査状態のみ**。生成元1ファイル、追加監査JSON、追加監査Markdownの3ファイル更新。既存の巨大な`CONTENT_REAUDIT_264_20261110.md`は内容保持のため編集せず、この追加監査記録を第14バッチの続編として正本に準じる追記資料とする。
- Node CLI再生成・264問限定差分・Web/iOS配布バイト・SHA256・全1,320肢の逐語証明・商用権利・実機検証は未了。**リリースゲートFAIL/BLOCKED維持**。mainマージ・配信・審査申請なし。


## 続編第2回：Muse限定差分PASS追記、a群7問追証、基本Q25法令根拠訂正（2026-11-12）

### Muse側の検証結果（提供された実施記録）
- 比較基準`d56f0fb`と演習C Q29の修正後状態の両方で、Muse側ローカルNode CLI264問再生成成功。
- 差分は`practice-C-Q29`の**出典参照・監査ステータス・出典URL**の1問のみ。正答index不変、**他263問完全一致**、限定差分判定**PASS（Muse側ユーザー提供）**。
- 本担当でその実行ログ・264問出力・Web/iOS配布バイトを独立再実行していない。検証結果の情報源を区別。

### a群で今バッチ対処した7問（基本7問・40行の局所差分ではなく対象7問のみ）
- `2026-04-Q43`：登録根拠を`https://www.ncbi.nlm.nih.gov/sites/books/NBK27158/`へ差替え。NCBI Immunological memory 10-21〜10-23：記憶B細胞・迅速な二次抗体応答。変更は`auditSourceURL`・`auditStatus`のみ、正答index不変。
- `2025-10-Q37`：登録根拠を`https://openstax.org/books/anatomy-and-physiology-2e/pages/1-5-homeostasis`へ差替え。OpenStax 1.5：膵β細胞インスリンが筋・脂肪細胞の糖取込みを促進。変更は`auditSourceURL`・`auditStatus`のみ、正答index不変。
- `2025-10-Q39`：登録根拠を`https://openstax.org/books/anatomy-and-physiology-2e/pages/23-7-chemical-digestion-and-absorption-a-closer-look`へ差替え。OpenStax 23.7：胆汁酸ミセルが脂溶性ビタミンの腸管吸収に寄与。変更は`auditSourceURL`・`auditStatus`のみ、正答index不変。
- `2025-10-Q44`：登録根拠を`https://www.ncbi.nlm.nih.gov/books/NBK279116/`へ差替え。NCBI Endotext: 交感神経髄質系が先行しHPA軸のコルチゾール応答は遅れて生じる。変更は`auditSourceURL`・`auditStatus`のみ、正答index不変。
- `2025-04-Q38`：登録根拠を`https://openstax.org/books/anatomy-and-physiology-2e/pages/23-7-chemical-digestion-and-absorption-a-closer-look`へ差替え。OpenStax 23.7：胃ペプシンと小腸膵由来蛋白分解酵素・リパーゼの別機能。変更は`auditSourceURL`・`auditStatus`のみ、正答index不変。
- `2025-04-Q40`：登録根拠を`https://medlineplus.gov/lab-tests/bun-blood-urea-nitrogen/`へ差替え。NIH MedlinePlus：BUNは脱水・蛋白摂取の影響も受けクレアチニン・GFR等と併せる。変更は`auditSourceURL`・`auditStatus`のみ、正答index不変。
- `2025-04-Q43`：登録根拠を`https://www.cdc.gov/niosh/fatigue/about/index.html`へ差替え。NIOSH Fatigue and Work（2026-07-14）：夜勤・疲労・反応遅延・勤務設計評価を裏づける。変更は`auditSourceURL`・`auditStatus`のみ、正答index不変。
- 各問の中心命題は公開一次・教科書本文に照合した。ただし全5肢それぞれの独立逐語立証は未完了。旧URLの再CAPTCHAなどによる不達を「この登録先での追証で解消」と区分し、リリース承認は別。

### 基本2026-04-Q25の法令適用精査と最終修正方針
- **以前のc群分類「設問の屋内作業場を事務所則3条に合わせて書換え必須」は撤回。**事務所衛生基準規則第1・3条は事務室の規定だが、**安衛則第601条第1項は労働者を常時就業させる屋内作業場一般に同じ1/20の開口面積基準**を規定する。厚労省原典：`https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=10`。事務所則：`https://www.mhlw.go.jp/web/t_doc?dataId=74089000&dataType=0&pageNo=1`。
- **問題データへの反映を実施**：生成正本`Resources/questions.json`の`2026-04-Q25`について、`detail`を安衛則第601条直接根拠へ修正し、`auditSourceURL`を同条原典に差替え、`auditStatus`を更新した。**設問・5肢・短解説・正答index2・式（200/20=10㎡、8㎡との差2㎡）は維持**。再設計不要。
- 「正答の根拠が変わるか」への回答：**正答命題と計算根拠は不変だが、直接引用すべき法令条文が事務所則3条から安衛則601条へ変わる**。根拠条文差替えの意味で変更あり。元の公式回次に係る`sourceRef`は公表テーマ由来を残すため維持。
- c群は**1→0件、a群は84→85件**に再分類。a群のうち今回原典差替え・確認7問とQ25の法令根拠訂正1問を台帳に記録（前回C29 URL補修、C34/C42追証は別計上）。
- 新規基本8問を変更した今回の264問Node CLI再生成・限定差分・配布JSONバイト一致/SHA256は本担当では**未実施**。Muse側のQ29に対するPASSを今回の8問へ流用しない。公開ゲートFAIL/BLOCKED維持。


## 続編第3回：Muse基本8問限定差分PASS受領、a群基本6問追証（2026-11-12）

### 1. Muse側実施の前回基本8問再生成検証（ユーザー提供）
- 比較基準`4c32d7e`と修正後状態の**両方で264問Node CLI再生成成功**。差分は`2026-04-Q25、2026-04-Q43、2025-10-Q37、2025-10-Q39、2025-10-Q44、2025-04-Q38、2025-04-Q40、2025-04-Q43`の**8問のみ**。
- `2026-04-Q25`は解説・監査ステータス・出典URL、他7問は監査ステータス・出典URLのみ。**正答index全問不変、他256問完全一致、限定差分PASS**。
- これはMuse側ローカル検証の受領結果。本担当で生成コマンド、配布バイト差分、SHA256を独立実行したものではない。今回の次の6問にPASSを転用しない。

### 2. a群次バッチ6問・公開原典確認
- **`2026-04-Q13`**：NIOSH：二硫化炭素による中枢・末梢神経毒性、多発神経障害、精神症状を確認。確認原典：`https://www.cdc.gov/niosh/npg/npgd0104.html`。旧登録：`https://www.atsdr.cdc.gov/ToxProfiles/tp82-c2.pdf`。変更：`auditSourceURL、auditStatus`、正答index 0不変。
- **`2026-04-Q15`**：EPA：α線は皮膚を透過しにくく、吸入・経口の内部被ばくが重大。CDC説明でも一致。確認原典：`https://www.epa.gov/radiation/radiation-basics`。旧登録：`https://gnssn.iaea.org/main/bptc/BPTC%20Module%20Documents/Module02%20Radiation%20protection%20in%20nuclear%20facilities.pdf`。変更：`auditSourceURL、auditStatus`、正答index 1不変。
- **`2026-04-Q17`**：ATSDR登録の水銀ToxFAQsは今回本文に到達。蒸気吸入、振戦、記憶・気分の変化を確認。URLの変更は不要。確認原典：`https://wwwn.cdc.gov/TSp/ToxFAQs/ToxFAQsDetails.aspx?faqid=1195&toxid=24`。旧登録：`https://wwwn.cdc.gov/TSp/ToxFAQs/ToxFAQsDetails.aspx?faqid=1195&toxid=24`。変更：`auditStatus`、正答index 4不変。
- **`2025-04-Q34`**：FDA：ヒスタミン汚染品の製造・ロット記録による分別と検査を確認。日本法の個別回収判断は別途確認。確認原典：`https://www.fda.gov/regulatory-information/search-fda-guidance-documents/guidance-industry-reconditioning-fish-and-fishery-products-segregation`。旧登録：`https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/0000130677.html`。変更：`auditSourceURL、auditStatus`、正答index 3不変。
- **`2025-04-Q36`**：NCBI：PR間隔は心房から心室までの伝導・房室結節遅延を含み延長はAV伝導遅延で説明可能。確認原典：`https://www.ncbi.nlm.nih.gov/sites/books/NBK549803/`。旧登録：`https://www.msdmanuals.com/ja-jp/home/06-心臓と血管の病気/心臓と血管の生物学/心臓の生物学`。変更：`auditSourceURL、auditStatus`、正答index 1不変。
- **`2025-04-Q37`**：NCBI：肺胞換気=(1回換気量−死腔量)×呼吸数=(500−150)×12=4200mL/min。旧原典NBK539825は表面張力で誤題材。確認原典：`https://www.ncbi.nlm.nih.gov/sites/books/NBK482501/`。旧登録：`https://www.ncbi.nlm.nih.gov/sites/books/NBK482501/`。変更：`auditSourceURL、auditStatus`、正答index 4不変。
- **`2026-04-Q17`のATSDR元登録URLは今回直接本文取得に成功したため、URL自体は変更せず監査ステータスのみ更新。**`2025-04-Q37`の旧個別台帳には肺胞表面張力資料`NBK539825`の誤トピック指摘があるが、今回の修正開始時点で生成正本の`auditSourceURL`は既に肺胞換気の適切な`NBK482501`へ更新されていた。**今回はQ37の`auditStatus`のみ変更し、出典URLは不変**。
- 以上6問の中心命題を公開一次・専門医学資料から確認したが、全30肢について原典段落ごとの独立逐語証明は未完了。変更前後の基本132問を本セッション内のレコード単位で照合し、**指定6問以外は不変、全132問の設問・5肢・正答index・detailは不変**。
- 個別台帳`audit/PRIMARY_SOURCE_AUDIT_A_BATCH3_20261112.json`に元URL、代替URL、原典確認内容、変更フィールド、留保を保存。旧台帳のPENDING/PARTIALは履歴として保持。

### 3. 引継ぎと公開ゲート
- (a)群の母数85問は分類済IDの総数であり、今回以降も全件未解消という意味ではない。次は`practice-A-Q27` NRA PDF、`practice-A-Q33` RCPA 403、`practice-B-Q27` e-Gov本文障害、`practice-B-Q31` QRS、`practice-C-Q04` 安衛令業種を優先。
- **本コミットの基本6問についてはNode CLI264問再生成・Web/iOSバイト照合・SHA256を未実施**。前段Muse PASSは今回の基本6問を含まない。全1320肢の直接逐語証明・法令版／商用権利・実機検証も別の未解決課題。総合ゲート**FAIL/BLOCKED維持**。


## 続編第4回：基本6問Muse限定差分PASS受領、優先5問の直接原典追証（2026-11-12）

### A. ユーザー提供Muse側実施結果
- 比較基準`10be187`と前回基本6問の修正後状態の**双方で264問Node CLI再生成成功**。
- 差分は`2026-04-Q13、2026-04-Q15、2026-04-Q17、2025-04-Q34、2025-04-Q36、2025-04-Q37`の6問のみ。監査ステータス・出典URL関連の変更（GitHub上にはURL既存一致でステータスだけの問題もある）。**正答index全問不変、他258問完全一致、限定差分PASS**（Muse側ローカル実施・ユーザー提供）。本セッションでは再実行していない。今回の5問へPASSを転用しない。

### B. 次の優先5問：原典到達・適用範囲
- **`practice-A-Q27`：DIRECT_CENTRAL_CLAIM_US_PUBLIC_RESEARCH_WITH_MODEL_ASSUMPTIONS**。米国CDC収蔵の換気モデル研究論文：VdC/dt = Q(Cin−Cout)+G。完全混合・定常・他除去なしでQ=G/(Ci−Co)。0.03/0.0006=50m³/h。旧原子力規制委員会PDFは取得エラー。。旧登録`https://www.nra.go.jp/data/000464217.pdf` → 新登録`https://stacks.cdc.gov/view/cdc/190690/cdc_190690_DS1.pdf`。変更フィールド：`sourceRef、auditSourceURL、auditStatus`。正答index **2不変**。
- **`practice-A-Q33`：DIRECT_CENTRAL_CLAIM_ALTERNATIVE_NCBI**。NCBI StatPearls Neutrophilia：細菌感染・炎症・糖質コルチコイドを含む薬剤、血算/分画/過去の検査値と服薬歴を評価。登録RCPAは403で未到達。。旧登録`https://www.rcpa.edu.au/Manuals/RCPA-Manual/Clinical-Presentations-and-Diagnoses/N/Neutrophilia` → 新登録`https://www.ncbi.nlm.nih.gov/sites/books/NBK570571/`。変更フィールド：`sourceRef、auditSourceURL、auditStatus`。正答index **0不変**。
- **`practice-B-Q31`：TWO_PUBLIC_TEXTS_COVER_ELECTRICAL_AND_PERIPHERAL_PULSE**。OpenStax QRS complex=心室脱分極、Toronto Metropolitan Universityの看護教材=心尖脈と橈骨脈の差が脈拍欠損。QRS数と触知脈の同数を仮定せず同時計測を見直す。。旧登録`https://openstax.org/books/fundamentals-nursing/pages/7-1-indicators-of-physiologic-functioning` → 新登録`https://openstax.org/books/anatomy-and-physiology-2e/pages/19-key-terms`、補助`https://pressbooks.library.torontomu.ca/assessmentnursingmain/chapter/auscultation-of-the-apical-pulse/`。変更フィールド：`detail、sourceRef、auditSourceURL、auditStatus`。正答index **0不変**。
- **`practice-B-Q27`：DIRECT_STATUTE_WITH_VOLUNTARY_CONSULTATION_SCOPE_RESERVATION**。厚生労働省安衛法104条本文・施行通達：法定健康確保措置の情報の収集・保管・使用と適正管理。任意相談記録が常に104条に該当すると断定せず、情報の性質・目的・個人情報保護も検討。。旧登録`https://laws.e-gov.go.jp/law/347AC0000000057` → 新登録`https://www.mhlw.go.jp/web/t_doc?dataId=74001000`、補助`https://www.mhlw.go.jp/web/t_doc?dataId=00tc3656&dataType=1&pageNo=1`。変更フィールド：`sourceRef、auditSourceURL、auditStatus`。正答index **0不変**。
- **`practice-C-Q04`：DIRECT_GOVERNMENT_DECREE_AND_MHLW_GUIDANCE**。厚生労働省安衛法施行令2条1・2号・3条に製造業を含み銀行業を含まない。安衛法12条の2及び厚労省Q&Aで10人以上50人未満は業種に応じて安全衛生推進者/衛生推進者。銀行30人=衛生推進者、製造業30人=安全衛生推進者。。旧登録`https://laws.e-gov.go.jp/law/347AC0000000057?occasion_date=20261001` → 新登録`https://www.mhlw.go.jp/web/t_doc?dataId=74002000`、補助`https://www.mhlw.go.jp/stf/newpage_09980.html`。変更フィールド：`detail、sourceRef、auditSourceURL、auditStatus`。正答index **4不変**。
- **演習A Q27**：旧NRA PDF取得エラーは解消できなかったが、CDC収蔵の公開換気モデル原論文（生成・排気・外気濃度の物質収支式）を確認し、問題条件で`0.03/(0.0010-0.0004)=50m³/h`。原論文は特定用途の実験であるため、設問の完全混合・定常仮定以外には一般化しない。
- **演習A Q33**：旧RCPA URLは403。NCBI Neutrophilia（薬剤としてglucocorticoidsも列挙、感染性好中球増加の鑑別）本文を閲覧できた。
- **演習B Q31**：QRSの心室電気的興奮をOpenStax、脈拍欠損の評価を大学公開看護教材で別個に確認。心尖脈とQRS計数が常に等しいと証明したものではなく、設問の「脈拍欠損などを評価する」という慎重な表現を維持。
- **演習B Q27**：安衛法104条の厚労省公開原文へ到達。法定措置に関する心身情報の収集・保管・使用が条文上の対象であり、**任意の相談記録全件に104条が直接適用されると断定しない**。心の健康指針・個人情報保護の適用は別途照合が必要。
- **演習C Q04**：施行令**第2条第1・2号および第3条**を厚労省本文で直接確認。製造業は安全管理者対象業種、銀行業は対象外。安衛法12条の2・厚労省FAQで10〜49人の推進者区分。**登録正答index4は不変**。
- 5問の登録原典`sourceRef`と`auditSourceURL`を直接内容に対応する公開資料へ差替え、監査ステータスを更新。B31・C04は追加資料・条文を明確化するため`detail`も補完。全25肢の逐語独立証明は未達。内容根拠の留保を個別台帳`audit/PRIMARY_SOURCE_AUDIT_A_BATCH4_20261112.json`に保存。

### C. 引き継ぎ
- **今回の問題データ変更ID：演習A Q27・Q33、演習B Q27・Q31、演習C Q04の5問**。正答・設問・全選択肢は変更なし。B31・C04は解説フィールド変更。
- 本コミットの5問は264問Node CLI再生成・限定差分・Web/iOS配布JSONバイト比較・SHA256未実施。次にMuse側の独立検証を必須とする。a群の分類母数85件（未解消85件の意味ではない）。全肢逐語証明・商用権利・法令施行日・実機未了。**リリースゲートFAIL/BLOCKED維持**。


## 続編第5回：Muse演習5問限定差分PASS、（a）群基本Q02・Q04・Q08・Q12・Q14・Q20の6問（2026-11-12）

### Muse側実施済みの演習5問・264問再生成（ユーザー提供）
- 比較基準`abf8d31`と前回修正後状態でそれぞれNode CLI264問再生成成功。
- 差分は`practice-A-Q27`・`practice-A-Q33`・`practice-B-Q27`・`practice-B-Q31`・`practice-C-Q04`の**5問のみ**。出典参照・監査ステータス・出典URL、一部の解説の変更。正答index全問不変、**他259問完全一致**。**限定差分PASS（Muse側報告）**。
- 今回の担当ではMuseローカルの再実行・Web/iOS配布バイトSHA256の独立照合をしていない。今回の新規基本6問の判定に前回PASSを転用しない。

### a群第5次・基本6問の登録原典照合
- **`2026-04-Q02`／DIRECT_CENTRAL_STATUTORY_STANDARD**：平成26年厚労省告示第455号（令和5年改正を含む）第1条・第5条：防じん用電動ファン付き呼吸用保護具の規格・18%未満酸素濃度の適用外・面体密着確認構造。検定・個別着用確認を一体視しない。。登録URL：`https://anzeninfo.mhlw.go.jp/yougo/yougo88_1.html`、今回採用の直接確認URL：`https://www.mhlw.go.jp/web/t_doc?dataId=74ab4390&dataType=0&pageNo=1`。変更：`auditSourceURL、auditStatus`、正答index 3 不変。**保留**：型式検定全要件・各選択肢の個別逐語反証は未完了。
- **`2026-04-Q04`／DIRECT_CENTRAL_OFFICIAL_LICENSE_REQUIREMENT**：厚労省『化学物質の製造許可手続き』が安衛法56条、特化則第一類物質の製造には厚生労働大臣の許可を必要と明記。所轄労基署は申請・相談窓口で許可主体ではない。。登録URL：`https://www.mhlw.go.jp/web/t_doc?dataId=74097000&dataType=0`、今回採用の直接確認URL：`https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/sekimen/other/pamph/index_00001.html`。変更：`auditSourceURL、auditStatus`、正答index 1 不変。**保留**：試験研究・少量製造等の例外全件と2026年適用施行版は未逐語照合。
- **`2026-04-Q08`／DIRECT_CENTRAL_OFFICIAL_QA**：厚労省ラベル/SDS Q&A Q11-1は小型容器にも個別ラベルまたはタグ、SDSのホームページアドレス伝達は容器ラベルの代替にはならないと明記。。登録URL：`https://www.mhlw.go.jp/stf/newpage_11237.html`、今回採用の直接確認URL：`https://www.mhlw.go.jp/stf/newpage_11237.html`。変更：`auditStatus`、正答index 1 不変。**保留**：全法定例外と適用製品区分は未照合。
- **`2026-04-Q12`／DIRECT_CENTRAL_OFFICIAL_RISK_ASSESSMENT_QA**：厚労省化学物質RA Q&A Q3-6は代替後の危険有害性・RA再評価、危険性が低いことが明らかな物質への代替を推奨。。登録URL：`https://www.mhlw.go.jp/stf/newpage_11389.html`、今回採用の直接確認URL：`https://www.mhlw.go.jp/stf/newpage_11389.html`。変更：`auditStatus`、正答index 0 不変。**保留**：全措置優先順位を一資料で逐語確認したわけではない。
- **`2026-04-Q14`／DIRECT_CENTRAL_OFFICIAL_NOISE_GUIDELINE**：令和5年改訂の騒音障害防止ガイドラインは85～90dB未満の設備・作業方法改善、必要に応じた聴覚保護具と測定結果の考慮を明記。設問88dBを包含。。登録URL：`https://www.mhlw.go.jp/web/t_doc?dataId=00tc7618&dataType=1`、今回採用の直接確認URL：`https://www.mhlw.go.jp/web/t_doc?dataId=00tc7618&dataType=1`。変更：`auditStatus`、正答index 4 不変。**保留**：保護具の公称遮音と個人実効遮音の関係は追加資料確認が必要。
- **`2026-04-Q20`／DIRECT_CENTRAL_SOLVENT_REGULATION**：厚労省有機溶剤中毒予防規則第29条・別表等にノルマルヘキサンでの尿中2,5-ヘキサンジオン検査が明記、キシレン・トルエン等との違いを直接確認。。登録URL：`https://www.mhlw.go.jp/web/t_doc?dataId=74090000&dataType=0&pageNo=1`、今回採用の直接確認URL：`https://www.mhlw.go.jp/web/t_doc?dataId=74090000&dataType=0&pageNo=1`。変更：`auditStatus`、正答index 3 不変。**保留**：採尿時間・分析法・法改正の全ての特例の独立逐語確認は未完了。
- Q02、Q04は登録URLが中心命題を直接説明する厚労省資料とは異なったため、公開一次資料へ置換。他のQ08、Q12、Q14、Q20は登録URLに直接説明が存在し、URLを維持し監査状態だけを更新。
- 生成元`Resources/questions.json`の変更は**上記6問のみ**。他126問不変、基本132問の全問題文・全5肢・正答index・解説は不変。原典の中心命題に関する照合ができたことと、各問題の全5肢独立逐語証明済み判定は異なる。
- 個別追証台帳：`audit/PRIMARY_SOURCE_AUDIT_A_BATCH5_20261112.json`。元URL、採用URL、原典上の根拠、保留、実変更キーを記録。
- 次はこのコミットの基本6問に対するMuse側の264問再生成・限定差分・配布SHA256確認。公開基準の独立全肢直接証明、法令施行日、商用利用権の検証は未了。**ゲートFAIL/BLOCKED維持**。


## 続編第6回：Muse基本6問PASS保存、a群基本Q28・Q30・Q34・Q42の4問追証（2026-11-12）

### 1. Muse側の前回基本6問264問再生成（報告受領）
- 比較基準`7d60cf9`と現在状態の**両方で264問再生成成功**。差分は`2026-04-Q02`・`2026-04-Q04`・`2026-04-Q08`・`2026-04-Q12`・`2026-04-Q14`・`2026-04-Q20`の**6問のみ**。監査ステータス・出典URL関連変更、正答index全問不変、**他258問完全一致**、**限定差分判定PASS**（Muse側ユーザー提供）。
- 先行コミットのGitHub正本を対象ID単位で照合した結果、出典URLはQ02・Q04のみ更新され、他4問は監査ステータスのみ。Muse報告の「出典URLの変更」は6問すべてのURLが変わったことを意味しない。
- 本セッションではMuse側のNode CLI再生成・バイト一致・SHA256を独立再実行していない。また今回の新規4問に先行PASSは転用しない。

### 2. a群次のまとまり（4問）
- **`2026-04-Q28`**：2026-03-18基発0318第1号『職場における熱中症防止対策のためのガイドライン』。旧2021-04-20要綱を廃止。新指針第3のWBGT基準、着衣補正、暑熱順化、作業・休憩・補水・報告体制に一致。。監査出典`https://www.mhlw.go.jp/content/001476821.pdf` → `https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1`、補助原典`https://jsite.mhlw.go.jp/kyoto-roudoukyoku/content/contents/002604006.pdf`。変更キー：`detail、auditStatus、auditSourceURL`。**正答index 1不変**。留保：新指針の条番号・JIS着衣補正細目と法的義務範囲は未全肢逐語検証。
- **`2026-04-Q30`**：米国NIH/NLM MedlinePlus『How to make a splint』は骨折部上下の関節をまたいで副子固定し、変形の無理な矯正を避け、末梢循環・色・感覚を再評価する旨を明記。旧RedCross一般骨折ページは副子詳細の直接性が弱い。。監査出典`https://www.redcross.org/take-a-class/resources/learn-first-aid/fractures` → `https://www.medlineplus.gov/ency/article/000040.htm`、補助原典`https://www.redcross.org/take-a-class/resources/learn-first-aid/fractures`。変更キー：`auditStatus、auditSourceURL`。**正答index 0不変**。留保：末梢血流消失や開放骨折は緊急医療対応、全5肢の独立逐語立証は未完。
- **`2026-04-Q34`**：厚労省2026年2月10日『高年齢者の労働災害防止のための指針』(4月1日適用)で照度確保・極端な明暗差解消を規定。旧厚労省職場改善マニュアルで反射グレアの防止を直接確認。。監査出典`https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/anzen/newpage_00007.html` → `https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/anzen/newpage_00010.html`、補助原典`https://www.mhlw.go.jp/new-info/kobetu/roudou/gyousei/anzen/dl/0903-1a_0007.pdf`。変更キー：`auditStatus、auditSourceURL`。**正答index 3不変**。留保：Q34の光沢部品の反射条件への機器配置の最適解は設計判断を含む。
- **`2026-04-Q42`**：NCBI MeSH D014870は不感蒸泄を皮膚拡散と呼吸路蒸発による水分喪失と直接定義。現行登録URLの原典到達を再確認。。監査出典`https://www.ncbi.nlm.nih.gov/mesh/68014870` → `https://www.ncbi.nlm.nih.gov/mesh/68014870`、補助原典`https://www.ncbi.nlm.nih.gov/mesh/68014870`。変更キー：`auditStatus`。**正答index 2不変**。留保：温熱性発汗の交感神経コリン作動性支配は補助原典NBK507838で確認し、全肢独立逐語PASSは未了。
- 特に**基本Q28**は2026年3月18日策定の新ガイドラインが2021年基本対策要綱を廃止したため、旧要綱への直接参照は古くなっていた。**設問・5肢・正答indexは維持して、`auditSourceURL`・`detail`・`auditStatus`を現行ガイドラインに修正**。
- 基本Q30はRedCrossの一般骨折ページをNIH MedlinePlusの副子固定直接手順へ出典変更。Q34は2026年適用の新指針の公式公示へ出典更新し、反射グレアを補強する厚労省マニュアルを台帳へ追加。Q42はNCBI MeSH原典本文に到達したためURLは不変で監査ステータスのみ更新。
- 本担当が生成元の基本132問を前後比較したところ**変更は今回の4問のみ**。問題文・5肢・正答indexは全132問不変。全20肢の個別原典逐語証明は未完。詳細は`PRIMARY_SOURCE_AUDIT_A_BATCH6_20261112.json`。

### 3. a群残件集計（重複排除）
- 当初の分類母数**85 ID**のうち、これまでに中心命題に関して公開一次資料到達・追証・出典差替え・法令根拠訂正を記録した固有IDは**32件**。**中心命題の次の照合待ちは53件**。
- 残り53 ID：`2025-10-Q01`、`2025-10-Q02`、`2025-10-Q06`、`2025-10-Q10`、`2025-10-Q14`、`2025-10-Q15`、`2026-04-Q19`、`2026-04-Q29`、`2026-04-Q31`、`2026-04-Q33`、`2026-04-Q41`、`2026-04-Q44`、`practice-A-Q08`、`practice-A-Q11`、`practice-A-Q13`、`practice-A-Q20`、`practice-A-Q21`、`practice-A-Q26`、`practice-A-Q28`、`practice-A-Q34`、`practice-A-Q37`、`practice-A-Q39`、`practice-B-Q08`、`practice-B-Q20`、`practice-B-Q28`、`practice-B-Q33`、`practice-C-Q01`、`practice-C-Q02`、`practice-C-Q03`、`practice-C-Q05`、`practice-C-Q06`、`practice-C-Q07`、`practice-C-Q08`、`practice-C-Q09`、`practice-C-Q10`、`practice-C-Q14`、`practice-C-Q15`、`practice-C-Q17`、`practice-C-Q18`、`practice-C-Q19`、`practice-C-Q20`、`practice-C-Q21`、`practice-C-Q22`、`practice-C-Q26`、`practice-C-Q30`、`practice-C-Q31`、`practice-C-Q32`、`practice-C-Q33`、`practice-C-Q35`、`practice-C-Q36`、`practice-C-Q37`、`practice-C-Q41`、`practice-C-Q44`。
- **注意：これは中心命題の出典問題の解消状況を示す管理上の数字**。全5肢それぞれの独立逐語根拠が揃い、法令版・商用権利・配布一致を通過した問題の数ではない。全5肢無条件PASSの基準では今回の母数85件に未達項目が残る。
- 今回の4問の264問Node CLI再生成、他260問限定差分、Web/iOS配布バイト照合、SHA256は**未実施**。Muse側で検証後、差分を確定すること。公開ゲート**FAIL/BLOCKED維持**。


## 続編第7回：Muse基本4問限定差分PASS受領、a群基本4問追証（2026-11-12）

### 前回修正4問のMuse側ローカル検証（ユーザー提供）
- 比較基準 `a48f4b6` と修正後状態の双方で264問Node CLI再生成成功（Muse側報告）。差分は `2026-04-Q28`、`2026-04-Q30`、`2026-04-Q34`、`2026-04-Q42` の4問だけ。正答index全問不変、他260問完全一致、限定差分PASS。
- 当担当による独立再実行、Web/iOS配布バイト照合、SHA256検証は未実施。今回の新規修正4問へPASSを転用しない。

### a群中心命題・今回の4問
- **`2025-10-Q01`**（正答index 3不変）：安衛令第2条第2号：製造業は事業場ごと常時300人以上が対象。A300人・B200人ならAのみ該当。 出典 `https://anzeninfo.mhlw.go.jp/yougo/yougo35_1.html` → `https://www.mhlw.go.jp/web/t_doc?dataId=74002000&dataType=0`。変更：`auditSourceURL`、`auditStatus`のみ。留保：会社内の別事業場である前提に依拠。全5肢の独立逐語証明未完。
- **`2025-10-Q02`**（正答index 1不変）：安衛令第6条第1号の高圧室内作業、および同令別表第6第5号の石炭貯蔵ホッパー内部が中心命題の直接根拠。 出典 `https://anzeninfo.mhlw.go.jp/yougo/yougo34_1.html` → `https://www.mhlw.go.jp/web/t_doc?dataId=74002000&dataType=0`。変更：`auditSourceURL`、`auditStatus`のみ。留保：高圧則・酸欠則の詳細適用と全5肢の独立逐語証明未完。
- **`2025-10-Q06`**（正答index 2不変）：粉じん則第2条・別表第1・別表第2で粉じん作業と特定粉じん発生源を区分。袋詰め・目視のみから一律該当とせず、条件別に照合する。 出典 `https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0` → `https://www.mhlw.go.jp/web/t_doc?dataId=74107000&dataType=0`。変更：`auditSourceURL`、`auditStatus`のみ。留保：炭素質粉体の材質・設備条件未指定につき特定発生源の実体該当性は未確定。全5肢逐語証明未完。
- **`2025-10-Q10`**（正答index 2不変）：労基則第18条第1・2・4・6号には暑熱・低温・著しい粉じん・振動業務が列挙されるが、不活性ガスタンク内部という名称単独は列挙されない。 出典 `https://www.mhlw.go.jp/web/t_doc?dataId=74001000&dataType=0` → `https://www.mhlw.go.jp/web/t_doc?dataId=73023000&dataType=0`。変更：`auditSourceURL`、`auditStatus`のみ。留保：安衛令別表第6第11号の酸欠危険場所規制とは区別。他の有害要因と全5肢逐語証明は未完。

### 残件・引き継ぎ
- 管理上の中心命題照合は**36/85件**、次の照合待ちは**49件（53→49）**。全5肢の独立逐語証明とは別の集計であり、全肢無条件PASSは0件扱い。
- 変更対象ID：`2025-10-Q01`、`2025-10-Q02`、`2025-10-Q06`、`2025-10-Q10`。問題文・5肢・正答index・解説は不変。基本132問の構造差分で対象外128問不変を確認。
- 今回の変更の264問再生成、限定差分、Web/iOS配布SHA256一致は未実施。次は `2025-10-Q14`、`2025-10-Q15`、`2026-04-Q19`、`2026-04-Q29` などを順次照合。全5肢逐語証明・法令時点・商用利用権は未完、**ゲートFAIL/BLOCKED**、mainマージ・配信・審査申請なし。
- 個別根拠は `PRIMARY_SOURCE_AUDIT_A_BATCH7_20261112.json`、進捗は `PRIMARY_SOURCE_AUDIT_TRIAGE_264_20261112.json` を参照。


## 続編第8回：Muse前回基本4問限定差分PASS・a群4問中心命題追証（2026-11-12）

### 1. Muse側ローカル実施結果（ユーザー提供／独立再実行ではない）
- 比較基準 `8d906bf` とその後の修正状態の双方でNode CLI264問再生成成功。
- 差分は `2025-10-Q01`・`2025-10-Q02`・`2025-10-Q06`・`2025-10-Q10` の監査ステータスと出典URLのみ。正答index全問不変、他260問完全一致、限定差分PASS（Muse側報告）。
- Web/iOS配布バイト比較・SHA256を今回独立実行したものではない。今回の次の4問に以前のPASSを転用しない。

### 2. a群第8次：基本4問の中心命題追証
- **`2025-10-Q14`**：OSHA Technical Manual section III ch5: noise-related sensorineural hearing loss may show a notch at 3000–6000 Hz, most commonly 4000 Hz. The notch alone is not a confirmed diagnosis, and exposure history/other findings are necessary. 監査URL：`https://www.cdc.gov/niosh/noise/prevent/understand.html` → `https://www.osha.gov/otm/section-3-health-hazards/chapter-5`。変更フィールド：`auditSourceURL`、`auditStatus`。正答index `3` 不変。留保：全5肢の逐語反証、および他病因の除外診断は未実施。
- **`2025-10-Q15`**：厚労省化学物質リスクアセスメントQ&A Q6-1/Q6-5/Q11-13: handling method and exposure conditions affect assessment; enclosure is an engineering mitigation, and changes or remaining exposure require appropriate reassessment. The same hazardous chemical need not yield identical risk across open and enclosed processes. 監査URL：`https://www.mhlw.go.jp/stf/newpage_11389.html` → `https://www.mhlw.go.jp/stf/newpage_11389.html`。変更フィールド：`auditStatus`。正答index `2` 不変。留保：工程A/Bでの実測曝露値・残余リスクの定量、全5肢逐語証明は未実施。
- **`2026-04-Q19`**：ACGIH BEI Introduction, Specimen Collection: sampling time depends on determinant retention; end-of-shift means ASAP after exposure, while discretionary sampling may apply to long half-life determinants; urine concentration adjustment does not remove time-dependence. 監査URL：`https://www.acgih.org/science/tlv-bei-guidelines/biological-exposure-indices-bei-introduction/` → `https://www.acgih.org/science/tlv-bei-guidelines/biological-exposure-indices-bei-introduction/`。変更フィールド：`auditStatus`。正答index `1` 不変。留保：特定化学物質別BEI Documentationおよび日本の法定採尿条件は問題の一般論とは別に確認が必要。全5肢逐語証明未実施。
- **`2026-04-Q29`**：厚労省2026-10-19健康保持増進指針公示13号、2026-11-02訂正: explicitly includes secondary prevention, examination referrals, health insurance coordination and work-treatment support in THP. This does not replace legally required health examinations. 監査URL：`https://www.mhlw.go.jp/stf/newpage_76807.html` → `https://www.mhlw.go.jp/stf/newpage_76807.html`。変更フィールド：`auditStatus`。正答index `1` 不変。留保：法定健診の代替不可の根拠条文を別途突合する必要あり。全5肢逐語証明未実施。

### 3. 進捗と引継ぎ
- 固有ID85件を母数とした中心命題の照合済み**40件**、未照合**45件（49→45）**。これは全5肢逐語原典証明の合格数ではない。全5肢無条件PASSは0件扱い。
- 今回問題JSONの変更ID：`2025-10-Q14`、`2025-10-Q15`、`2026-04-Q19`、`2026-04-Q29`。Q14は`auditSourceURL`と`auditStatus`、他3問は`auditStatus`のみ変更。基本132問の構造比較で他128問不変、設問・5肢・正答index・解説全件不変を確認。
- 今回4問のNode CLI264問再生成、限定差分、Web/iOSバイト一致、SHA256は未実施。次にMuse側独立検証が必要。次の対象候補：`2026-04-Q31`、`Q33`、`Q41`、`Q44`。
- 出典はQ14：OSHA Technical Manual `https://www.osha.gov/otm/section-3-health-hazards/chapter-5`、Q15：厚労省化学物質RA Q&A `https://www.mhlw.go.jp/stf/newpage_11389.html`、Q19：ACGIH BEI Introduction `https://www.acgih.org/science/tlv-bei-guidelines/biological-exposure-indices-bei-introduction/`、Q29：厚労省2026年改正THP指針公示 `https://www.mhlw.go.jp/stf/newpage_76807.html`。
- 法令適用日・全5肢独立逐語・商用利用権・最終配布一致・実機検証は未完了。リリースゲート**FAIL/BLOCKED**維持。mainマージ・公開・審査申請なし。
- 個別台帳：`PRIMARY_SOURCE_AUDIT_A_BATCH8_20261112.json`、分類・残件正本：`PRIMARY_SOURCE_AUDIT_TRIAGE_264_20261112.json`。


## 続編第9回：Muse基本4問限定差分PASS受領、a群次4問の中心命題照合（2026-11-12）

### Muse側の前回基本4問再生成（ユーザー提供）
- 比較基準 `79a3175` および修正後状態の両方で264問Node CLI再生成成功。差分は `2025-10-Q14`・`2025-10-Q15`・`2026-04-Q19`・`2026-04-Q29` の4問だけ。正答index全問不変、他260問完全一致、限定差分PASS。
- 差分のキーは監査ステータスと出典URL（適用問のみ）。実際の前回修正ではQ14のみ出典URLも変更、Q15・Q19・Q29はステータスのみ。
- Muse側ローカル報告の転記であり、当担当による独立再生成・Web/iOS配布バイト比較・SHA256検証ではない。今回修正分へのPASS転用はしない。

### a群第9次：次4問の中心命題の直接追証
- **`2026-04-Q31`**（正答index `0` 不変）：急性脳卒中では最終健常確認時刻と抗凝固薬使用・最終服薬時刻が再灌流治療適否の評価に関係し、心房細動は心原性脳塞栓症の鑑別で重要。頭蓋内出血が初期画像で見られないことだけで塞栓症を確定してはならない。 登録先 `https://www.stroke.org/en/about-stroke/stroke-symptoms` → `https://www.ncbi.nlm.nih.gov/sites/books/NBK535369/`、追加根拠 `https://pmc.ncbi.nlm.nih.gov/articles/PMC13441289/`。変更キー：`auditSourceURL`、`auditStatus`。留保：原典は診療概要・臨床教育であり、2026年日本国内の全治療薬適応・更新ガイドラインとの完全同期、および全5肢逐語根拠は未確認。
- **`2026-04-Q33`**（正答index `4` 不変）：NISTIR5329 4.9.2（原本59頁、PDF表示ページ70）にQ=在室者数×1人当たりCO₂発生量/(室内平衡濃度−外気濃度)を明記。20人600m³/h→40人1200m³/hを直接導出。 登録先 `https://nvlpubs.nist.gov/nistpubs/Legacy/IR/nistir5329.pdf` → `https://nvlpubs.nist.gov/nistpubs/Legacy/IR/nistir5329.pdf`、追加根拠 `https://www.nist.gov/publications/investigating-uncertainty-relationship-between-indoor-steady-state-co2-concentrations`。変更キー：`auditStatus`。留保：均一混合・外気濃度と発生量一定・定常状態が必要。NIST自身が個室・非定常実測への単純適用を警告。全5肢逐語証明未完。
- **`2026-04-Q41`**（正答index `2` 不変）：NCBI『Physiology, Accommodation』で近見反応の構成要素を分け、輻輳は両眼内直筋の収縮・外直筋の弛緩、調節は毛様体筋による水晶体形状変更と明記。独立する生理機構を直接確認。 登録先 `https://www.ncbi.nlm.nih.gov/books/NBK553169/` → `https://www.ncbi.nlm.nih.gov/sites/books/NBK542189/`、追加根拠 `https://pmc.ncbi.nlm.nih.gov/articles/PMC6589714/`。変更キー：`auditSourceURL`、`auditStatus`。留保：近見反応の協調と臨床的分離障害の詳細鑑別、全5肢の逐語反証は未完。
- **`2026-04-Q44`**（正答index `4` 不変）：NIDCD加齢性難聴ページに両側で徐々に進む難聴と雑音下の聞き取り改善策（背景音を下げる、顔を向ける等）。同機関の突発性難聴ページは急な片側難聴を医療緊急事態として受診推奨。 登録先 `https://www.nidcd.nih.gov/health/age-related-hearing-loss` → `https://www.nidcd.nih.gov/health/age-related-hearing-loss`、追加根拠 `https://www.nidcd.nih.gov/health/sudden-deafness`。変更キー：`auditStatus`。留保：Aは加齢性難聴の典型に整合するが他疾患の除外診断は未完。全5肢逐語証明未完。

### 残件と引き継ぎ
- 当初（a）群85 IDのうち中心命題追証の累計 **44件**、次の照合待ち **41件**（45→41）。全5肢独立逐語PASSの件数とは区別し、全肢無条件PASSは0件扱い。
- **問題データ変更IDは `2026-04-Q31`、`2026-04-Q33`、`2026-04-Q41`、`2026-04-Q44`。** Q31・Q41は出典URLと監査状態、Q33・Q44は監査状態のみ。問題文、選択肢、解説、正答indexは不変。基本132問について他128問不変を構造差分で確認。
- NIST原典は PDF表示ページ70（冊子59頁）を画像でも確認。Q33のモデル仮定は実測時の制約として監査留保に残す。
- 今回の4問に対する264問Node CLI再生成・限定差分・Web/iOS配布一致・SHA256は未実施。次の対象は `practice-A-Q08`、`practice-A-Q11`、`practice-A-Q13`、`practice-A-Q20` など。
- 全5肢直接逐語証明・法令版・商用権利・実機検証は未完了。**リリースゲートFAIL/BLOCKED維持**、mainマージ・公開・審査申請なし。
- 詳細は `PRIMARY_SOURCE_AUDIT_A_BATCH9_20261112.json`、残件は `PRIMARY_SOURCE_AUDIT_TRIAGE_264_20261112.json`。


## 続編第10回：Muse基本4問再生成PASS受領、a群演習A4問の中心命題照合（2026-11-12）

### A. Muse側実施済み264問再生成の受領
- 比較基準 `3ba09ca` と現行修正後の双方で264問Node CLI再生成が成功（Muse側ローカルのユーザー提供結果）。差分は基本 `2026-04-Q31`・`Q33`・`Q41`・`Q44` の4問のみ。監査ステータス・適用問の出典URL変更、正答index全問不変、他260問完全一致、限定差分PASS。
- 前回のQ31/Q41は出典URLと監査状態、Q33/Q44は監査状態のみ変更。GitHub当担当で両状態の再生成・配布Web/iOSバイト・SHA256を独立実行していない。今回の演習A4問へPASS転用をしない。

### B. （a）群の演習A4問・原典追証
- **`practice-A-Q08`**（正答index `3` 不変）：安衛則45条2項は前回健診で44条1項6〜9号および11号を受診し医師が不要と認めるときに定期の特定業務健診で該当項目を省略可能とする。3項は44条3項の『一年間』を『六月間』に読み替え、正答肢3と一致。 登録原典 `https://laws.e-gov.go.jp/law/347M50002000032?occasion_date=20261101` → `https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0`。補助資料 `https://laws.e-gov.go.jp/law/347M50002000032?occasion_date=20261101`。変更フィールド：`auditSourceURL`、`auditStatus`。留保：医師の個別判断・他健診への準用条件を含む全5肢逐語証明は独立完了していない。
- **`practice-A-Q11`**（正答index `0` 不変）：安衛則52条の2第1〜3項は休憩除く週40時間超過分の月80時間超判定、毎月1回以上の一定期日での算定、超過労働者への速やかな通知を明記。指定の4週間は(60-40)+(58-40)+(55-40)+(52-40)=65時間となり、80時間超通知の閾値未満。 登録原典 `https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2` → `https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0&pageNo=2`。補助資料 `https://laws.e-gov.go.jp/law/347M50002000032?occasion_date=20261101`。変更フィールド：`auditStatus`。留保：指定された算定期間が法定の1か月期間とされる設問条件に依拠。月跨ぎ・変形労働時間制・休日労働の詳細および全5肢逐語証明は別途検証。
- **`practice-A-Q13`**（正答index `4` 不変）：安衛則52条の5は事業者指定以外の希望医師による法定面接指導相当の結果証明について、実施年月日・本人/医師氏名・疲労蓄積状況・心身状況の記載を要求。同52条の6はその場合も事業者の記録保存義務を定める。 登録原典 `https://laws.e-gov.go.jp/law/347M50002000032/20260101_507M60000100097/` → `https://laws.e-gov.go.jp/law/347M50002000032/20260101_507M60000100097/`。補助資料 `https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0`。変更フィールド：`auditStatus`。留保：2026-11現在の規定に依拠。2027年以降改正案の条文とは混同しない。全5肢逐語証明および66条の8第4項の意見聴取の網羅検査は未完。
- **`practice-A-Q20`**（正答index `0` 不変）：厚労省『熱中症のおそれのある者に対する処置の例』では、作業離脱・身体冷却後、返事がおかしい/ぼーっとする等の意識異常は救急隊要請、異常がなく自力摂取できるときに水分摂取・経過観察と区分。Bは嚥下安全性が不明で経口摂取を強制せず救急連絡、Aは水分塩分補給と休憩を継続。 登録原典 `https://www.mhlw.go.jp/content/11303000/001618734.pdf` → `https://www.mhlw.go.jp/content/001476821.pdf`。補助資料 `https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1`。変更フィールド：`auditSourceURL`、`auditStatus`。留保：臨床的重症度・各誤答肢の全逐語証明、およびガイドライン細目は未完。

### C. 進捗と引継ぎ
- 中心命題の累計公開原典照合・記録 **48/85 ID**、次の照合待ち **37 ID**（41→37）。全5肢の独立逐語根拠・法令施行日・配布一致の完全合格とは別。全5肢無条件PASSはまだ0件扱い。
- **生成元変更ID：`practice-A-Q08`、`practice-A-Q11`、`practice-A-Q13`、`practice-A-Q20`。** 演習A正本上書きファイル `audit/practice_a_fixes_01_10.json` でQ08/Q20は`auditSourceURL`と`auditStatus`、Q11/Q13は`auditStatus`のみ変更。問題文・5肢・正答index・解説は不変。上書きファイルの対象外40問は構造比較で不変。
- 今回の4問の264問Node CLI再生成・限定差分、配布Web/iOSのバイト・SHA256比較は未実施。次はMuse側独立検証後、`practice-A-Q21`、`Q26`、`Q28`、`Q34`を中心に追証。
- 原典の中心命題追証と全5肢の独立逐語PASSは異なる。商用権利・法令適用時点の横断審査・実機は未了。**リリースゲートFAIL/BLOCKED**、mainマージ・App Store申請・公開なし。
- 個別証跡：`audit/PRIMARY_SOURCE_AUDIT_A_BATCH10_20261112.json`、累積残件：`audit/PRIMARY_SOURCE_AUDIT_TRIAGE_264_20261112.json`。


## 続編第11回：Muse演習A4問PASSの追記と（a）群演習A4問中心命題照合（2026-11-12）

### 1. Muse側での前回演習A4問264問再生成（提供された実施結果）
- 比較基準 `e3e62cb` と修正後状態の両方で264問Node CLI再生成成功。差分は `practice-A-Q08`・`Q11`・`Q13`・`Q20` の4問のみ。監査ステータスと適用対象の出典URLの変更、正答index全問不変、他260問完全一致、限定差分PASS。
- 差分内訳はQ08/Q20で監査URLとステータス、Q11/Q13ではステータスのみ。本担当でNode CLI両状態・Web/iOS配布バイト・SHA256を独立再実行したものではない。今回修正4問へPASS転用はしない。

### 2. （a）群の次4問
- **`practice-A-Q21`**（正答index `4` 不変）：厚労省令和8年3月18日付け新熱中症ガイドライン：作業強度・暑熱順化・着衣補正によるWBGT基準照合と、作業時間短縮・休憩・衣服調整を明記。同じWBGTでも重量物運搬＋防護衣のB班を高リスクと評価する中心命題を確認。 URL `https://www.mhlw.go.jp/content/11303000/001618734.pdf` → `https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1`。補助原典 `https://neccyusho.mhlw.go.jp/heat_index/`。変更キー：`auditSourceURL`、`auditStatus`。留保：同一WBGT31℃での定量休憩配分や衣服別補正数値は未確認。全5肢独立逐語立証は未完。
- **`practice-A-Q26`**（正答index `0` 不変）：NIOSH 2016-106 Glossaryは従来ETを気温・湿度・気流の主観的温熱感覚指標と定義。WBGTは自然湿球温度・黒球温度（屋外日射時は乾球温度も）を用い、炉のふく射の評価にも適用する。 URL `https://www.cdc.gov/niosh/docs/2016-106/pdfs/2016-106.pdf` → `https://www.cdc.gov/niosh/docs/2016-106/pdfs/2016-106.pdf`。補助原典 `https://www.mhlw.go.jp/web/t_doc?dataId=00tc9896&dataType=1&pageNo=1`。変更キー：`auditStatus`。留保：NIOSH PDFテキスト到達と検索抜粋確認。ただしPDF画像スクリーンショット取得は502で失敗、詳細の独立視覚確認は未了。ET/ET*/CETの区別や全5肢逐語立証は継続。
- **`practice-A-Q28`**（正答index `1` 不変）：CDC/NIOSH換気FAQ：CO₂測定は換気の状態把握に使えるが、発生源の種類や局所的汚染・他の空気中物質濃度を直接予測できない。EPA室内空気質技術資料も人由来でない汚染源をCO₂のみでは評価できないと明記。1400→800ppmの低下は条件が揃えば換気改善を示唆する一方、溶剤蒸気を別途評価する正答肢1を支持。 URL `https://www.mhlw.go.jp/content/10900000/000896863.pdf` → `https://www.cdc.gov/niosh/ventilation/faq/`。補助原典 `https://19january2017snapshot.epa.gov/sites/production/files/2016-09/documents/text_modules_diagnosing.pdf`。変更キー：`auditSourceURL`、`auditStatus`。留保：在室人数だけでなく活動・外気CO₂・位置・換気の時間推移・清掃溶剤の実測濃度に依存。全5肢逐語立証は未完。
- **`practice-A-Q34`**（正答index `4` 不変）：NCBI Bookshelf『Biochemistry, Clotting Factors』で一次止血＝血小板の粘着・活性化・凝集、二次止血＝凝固因子を介したフィブリン形成による血小板栓の安定化と直接定義。血小板減少Aと凝固因子低下Bの機序を区別する正答肢4に一致。 URL `https://www.ncbi.nlm.nih.gov/books/NBK507850/` → `https://www.ncbi.nlm.nih.gov/books/NBK507850/`。補助原典 `https://www.ncbi.nlm.nih.gov/books/NBK507850/`。変更キー：`auditStatus`。留保：実臨床の点状出血と凝固異常の鑑別診断、全5肢の独立逐語立証は未完。

### 3. 集計・品質ゲート・次セッション
- 中心命題への直接追証済み **52/85 ID**、次の照合待ち **33件（37→33）**。全5肢逐語立証・商用権利・法令時点・配布バイト一致の合格とは区別し、全5肢無条件PASSは0件として管理。
- **生成元変更ID：`practice-A-Q21`・`practice-A-Q26`・`practice-A-Q28`・`practice-A-Q34`**。Q21/Q28は`auditSourceURL`・`auditStatus`、Q26/Q34は`auditStatus`のみ。設問・5肢・解説・正答indexは不変。上書きファイル44問のうち他40問不変をJSON構造差分で確認。
- 264問Node CLI再生成・新規4問限定差分・Web/iOS配布JSONバイト・SHA256は**未実施**。次はMuse側で検証、続いて`practice-A-Q37`・`Q39`・`practice-B-Q08`・`Q20`を検討。
- **リリースゲートFAIL/BLOCKED維持**。mainマージ・審査申請・公開なし。
- 詳細：`PRIMARY_SOURCE_AUDIT_A_BATCH11_20261112.json`、進捗：`PRIMARY_SOURCE_AUDIT_TRIAGE_264_20261112.json`。


## 続編第12回：Muse演習A4問PASS追記、（a）群演習A/B計4問中心命題照合（2026-11-12）

### Muse側再生成報告の受領（独立再実行ではない）
- 比較基準 `c5df1dd` と現在状態の双方でNode CLI264問再生成成功。差分は `practice-A-Q21`・`Q26`・`Q28`・`Q34` だけ。正答index全問不変、他260問完全一致、限定差分PASS。
- Q21/Q28は監査ステータス・出典URL、Q26/Q34は監査ステータスのみの変更。Muse側から提供された実施報告の転記であり、当担当による264問再生成・配布バイト/SHA256照合の独立再検証ではない。今回の修正4問へのPASS転用はしない。

### （a）群・今回の中心命題照合
- **`practice-A-Q37`**（正答index `2` 不変）：NCBI StatPearls Physiology, Cardiac Cycle: during ventricular systole the mitral valve closes; once left ventricular pressure exceeds aortic pressure, aortic valve opens and rapid ventricular ejection begins. Hence choice 2. 監査URL `https://www.ncbi.nlm.nih.gov/books/NBK459327/` → `https://www.ncbi.nlm.nih.gov/sites/books/NBK459327/`。変更フィールド：`auditSourceURL`、`auditStatus`。留保：僧帽弁閉鎖不全等の病的例や全5肢独立逐語証明は未検証。
- **`practice-A-Q39`**（正答index `3` 不変）：NCBI StatPearls Physiology, Pulmonary Circulatory System: entire right-heart cardiac output passes through pulmonary circulation, low-pressure/low-resistance arrangement enables gas exchange. Hence choice 3. 監査URL `https://www.ncbi.nlm.nih.gov/books/NBK525948/` → `https://www.ncbi.nlm.nih.gov/sites/books/NBK525948/`。変更フィールド：`auditSourceURL`、`auditStatus`。留保：各病態での肺血管抵抗や全5肢独立逐語反証は未完了。
- **`practice-B-Q08`**（正答index `0` 不変）：安衛則7条1項1号の14日以内の選任義務と7条3項の遅滞ない所轄監督署長への報告義務を区別。厚労省は2025年1月1日から選任報告の原則電子申請および資格証明記録の添付を案内。肢0の中心命題は直接裏付けられる。 監査URL `https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0` → `https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0`、補助 `https://jsite.mhlw.go.jp/nara-roudoukyoku/content/contents/Health-and-safety-handbook2025_.pdf`。変更フィールド：`auditStatus`。留保：原則電子申請の経過措置として書面報告が可能。添付方法・適用時点・全5肢独立逐語確認は残る。
- **`practice-B-Q20`**（正答index `2` 不変）：厚労省の腰痛予防指針は手かぎ・吸盤等の補助具を推奨するが、COVAL製造者技術資料は粗面・多孔質表面で空気漏れが起こり保持力が表面と真空流量等に依存すると明記。対象素材ごとの実使用条件検証と把持方式選定を求める肢2の中心命題を支持。 監査URL `https://www.mhlw.go.jp/web/t_doc?dataId=00tb9484&dataType=1` → `https://www.coval.com/en-us/technologies/vacuum-technology/suction-cup-performance`、補助 `https://www.mhlw.go.jp/web/t_doc?dataId=00tb9484&dataType=1`。変更フィールド：`auditSourceURL`、`auditStatus`。留保：COVALは製造者の技術資料（公的法令そのものではない）。12kg袋物の製品固有の実測保持力は未確認。全5肢独立逐語証明未完。

### 集計、出典区分と引継ぎ
- （a）群中心命題の固有ID照合 **56/85件**、次の照合待ち **29件（33→29）**。全5肢独立逐語PASSは0件扱いを維持。
- **生成元変更IDは `practice-A-Q37`・`practice-A-Q39`・`practice-B-Q08`・`practice-B-Q20`。** A Q37/Q39は`auditSourceURL`と`auditStatus`、B Q08は`auditStatus`のみ、B Q20は`auditSourceURL`と`auditStatus`。問題文・5肢・解説・正答index不変。演習A上書き44問中他42問、演習B上書き44問中他42問を構造差分確認。
- B Q20のCOVAL資料は製造者一次技術資料であり公的法令とは異なる。腰痛予防の国内公的根拠を補助資料で保持。吸盤の安全な使用には製品・対象物・条件別の性能試験が必要。
- 今回の修正4問の264問Node CLI再生成・限定差分、Web/iOS配布バイト・SHA256は未実施。次はMuse側独立確認後、`practice-B-Q28`・`Q33`・`practice-C-Q01`・`Q02`から追証。
- 法令版・商用利用権・全5肢直接証明・実機検証未了、**リリースゲートFAIL/BLOCKED**、mainマージ・審査申請・公開なし。
- 新規個別台帳：`audit/PRIMARY_SOURCE_AUDIT_A_BATCH12_20261112.json`、累計台帳：`audit/PRIMARY_SOURCE_AUDIT_TRIAGE_264_20261112.json`。
