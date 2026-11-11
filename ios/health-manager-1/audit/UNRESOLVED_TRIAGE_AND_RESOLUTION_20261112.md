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
- **`2026-04-Q17`のATSDR元登録URLは今回直接本文取得に成功したため、URL自体は変更せず監査ステータスのみ更新。**`2025-04-Q37`の旧NCBI `NBK539825`は肺胞表面張力を説明しており、肺胞換気の直接原典に置換。
- 以上6問の中心命題を公開一次・専門医学資料から確認したが、全30肢について原典段落ごとの独立逐語証明は未完了。変更前後の基本132問を本セッション内のレコード単位で照合し、**指定6問以外は不変、全132問の設問・5肢・正答index・detailは不変**。
- 個別台帳`audit/PRIMARY_SOURCE_AUDIT_A_BATCH3_20261112.json`に元URL、代替URL、原典確認内容、変更フィールド、留保を保存。旧台帳のPENDING/PARTIALは履歴として保持。

### 3. 引継ぎと公開ゲート
- (a)群の母数85問は分類済IDの総数であり、今回以降も全件未解消という意味ではない。次は`practice-A-Q27` NRA PDF、`practice-A-Q33` RCPA 403、`practice-B-Q27` e-Gov本文障害、`practice-B-Q31` QRS、`practice-C-Q04` 安衛令業種を優先。
- **本コミットの基本6問についてはNode CLI264問再生成・Web/iOSバイト照合・SHA256を未実施**。前段Muse PASSは今回の基本6問を含まない。全1320肢の直接逐語証明・法令版／商用権利・実機検証も別の未解決課題。総合ゲート**FAIL/BLOCKED維持**。
