# HM2 Q0代替基準・検証状態（2026-11-22 JST）

対象: `fix/hm2-priority123-regression-20261122`。App Review提出および新規TestFlight配信は禁止。

## ユーザー承認による基準変更
従来の「178問に対する外部専門家実名承認」を必須条件から外し、以下の全件充足をQ0判定条件とする。
1. 同一現行配布JSONの178問・各5肢について、当該セッションで独立再検証し、二重チェックの問題ID・肢別判断・実施者・根拠・日付・対象SHAを記録する。
2. 労働安全衛生法令、厚生労働省通達、試験実施団体の公表問題など、論点に直接対応する公式一次資料を照合する。施行日・適用範囲を確認する。
3. アプリ内表示・公開サポート・ストア説明で、非公式教材かつ専門家監修なしである旨を明示する。
4. 全対象の出典適合・権利利用条件・転載や派生表現のリスクを個別に確認する。

## このセッションで確認・変更できたこと
- 対象ブランチの存在と旧監査記録をGitHubで確認。
- `ios/health-manager-2/APP_STORE_METADATA_JA.md` に非公式・専門家監修なしの表示を追加（commit `d1ec1ab490d43ef8dcd14fadc5baca064c00251e`）。
- `health-manager-2/support.html` に同趣旨の説明を追加（commit `7051c37dffeb9e374b82fea01bb436cc2f466fb5`）。

## 未検証・判定
- 178問の逐肢独立再検証: このセッションで完了した証跡なし。**0/178を新基準で検証済みとして扱う**。
- 公式一次資料との逐問照合: 未完了。
- 300問の出典・権利最終判定: 未完了。
- アプリ本体内の表示と配布物への反映: 未確認。
- Node CLI/GitHub Actionsゲート: この変更後のPASS証跡なし。
- Q0: BLOCKED。Q1: BLOCKED（Q0未通過）。過去のPASSや技術的CI成功を新基準の合格に読み替えない。

## 次の必須作業
現行SHAを固定し、178問の各肢を公式根拠と照合して逐問台帳を作成する。誤りは生成元で修正し再生成、対象外差分なしを確認する。権利判定とアプリ本体表示の検査後に厳格ゲート・GHAを実行し、Q0から順に再判定する。未確認項目はPASSにしない。

## 継続作業（同日）
- 固定178問台帳 `FINAL_GATE_178_ID_EVIDENCE_MATRIX_20261112.md` を取得。法令44・衛生等の専門20・科目専門114の計178問という対象集合の定義を確認。ただし台帳の過去レビューをこのセッションの新基準での独立再検証に流用しない。
- `export-audit-data-core.cjs` の現行仕様を確認。旧 `requires-independent-*` と `publicationStatus` / `auditStatus` を根拠に BLOCKED となる。承認証跡なしにこの条件を解除しない。
- `scripts/hm2_submission_readiness.py` は旧 `HM2_FINAL_EXPERT_APPROVALS_178.json` の実名承認を要求しており、**新Q0基準への判定ロジック移行は未完了**。これはApp Store提出の安全停止検査でもあるため、当面変更しない。
- アプリ設定の「この教材について」に非公式・専門家監修なしを追加。commit `2ae6742caf60682e499b4ff43999c8bf9d423466`。配布済みiOSビルドへの反映は未確認。
- `.github/workflows/hm2-production-readiness.yml` に対象ブランチのpushと表示文言の静的チェック、`node --check` を追加。commit `17f5884e2dce51d41a772ba9ff859d50ea5c78a2`。GitHub Actionsの成功を確認できるまでPASSにしない。
- 対象コミットのcombined statusは空、PR起点workflow runsは0（照会時点）。**CI成功証跡なし**。
- 個別890肢の新たな直接原典再照合と300問の権利最終判定は未実施。したがってQ0/Q1はいずれもBLOCKEDを維持。

## 新基準の実装上の残課題
1. 178問各肢の独立二重検証を行い、対象SHA・2回の判断・一次資料URLと施行日・具体的根拠を個別に証跡化する。
2. 300問分の出典権利判断を別台帳に記録する。URLや `rightsBasis` の存在だけでは承認しない。
3. 旧専門家承認用エクスポートと提出前検査を、**完全な代替証跡がある場合のみ**通す実装へ改修する。新基準満たさない状態はfail-closedを維持。
4. GHA・Node CLIの結果とアプリ内同梱実物の表示を確認し、Q0→Q1の順で再判定する。

## 継続実装 第2期（2026-11-22 JST）
- 追加の5問25肢の一次確認を `HM2_INDEPENDENT_FIRST_PASS_20261122_BATCH02.md` に記録。累計10/178問の**一次確認**。二重チェック合格数は0/178問のまま。実出題JSON/正答の変更はなし。
- `scripts/hm2_alternative_q0_gate.py` を追加。固定178IDと現在の300問bank SHA-256に対して、各5肢の本文・判定・一次資料参照・二つのレビューと異なるreviewer_id、300問の個別権利判断、アプリ内・サポート・ストア説明の非公式表示を確認する。未提出証跡はFAIL。**形式検査であり、記載した資料や判断の真実性を自動認証するものではない**。
- `ios/health-manager-2/export-audit-data-core.cjs` に代替証跡が全件そろった場合のみ従来のレビュー待ちマーカーに代替する分岐を追加。現状は代替証跡が存在しないため `HM2_RELEASE_REVIEW_BLOCKED` を維持。法令関連に必要な `legalChecked`、300問の構造・難易度ゲートは維持。
- `scripts/hm2_submission_readiness.py` の旧専門家実名承認チェックを新代替Q0証跡チェックに置換。ビルド・権利・ASC・スクリーンショット等の他の申請保護は引き続き必須。
- `tests/test_hm2_alternative_q0_gate.py` に6つのテスト（正常な架空証跡、権利記録欠落、同一レビュアー、改変肢、古いSHA、非公式表示欠落）を追加し、対象ブランチの読み取り専用GHAに組み込んだ。
- ただしGitHub接続から対象HEADのチェックを照会した時点ではcombined status空、取得できたPR起点workflow runsは0。**実際のGHA実行・Node CLI実行のPASSは確認できていない**。技術テストは合格報告しない。
- 新Q0の最終合格には、2つのレビューの形式的ID相違に加えて、独立性・根拠と版の正確性・権利判断の中身を人手または独立工程で評価する必要がある。実名専門家資格は要求しない。形式検査だけでQ0をPASSとみなさない。

**再判定：Q0 BLOCKED / Q1 BLOCKED。App Review提出0、新規TestFlight配信0。**

## 継続実施 第3期（2026-11-22 JST）
- 配布JSONの次の法令5問、各5肢を現行データと照合して、厚労省の条文・FAQと突合する一次確認を実施：`sm2-5y-r05-law-04`・`05`・`07`・`08`・`09`。詳細は `HM2_INDEPENDENT_FIRST_PASS_20261122_BATCH03.md`。
- `sm2-5y-r05-law-08` では、安衛則44条3項の一般定期健診の「1年間」と45条3項の特定業務健診の「6か月」読替えを区別。既存正答index=3の変更理由なし。その他4問も正答位置に明白な矛盾なし。
- 一次確認累計15/178問（75肢）。**二重チェック完了0/178問、権利最終判定0/300問**。
- 旧レビュー保留のマーカーを機械的に消すだけでゲートを迂回できないよう、`export-audit-data-core.cjs` で新Q0証跡検査を常時呼び出すように修正（commit `1892b289369122205ff48588983f032573a9c521`）。証跡検査が未合格なら既存の `HM2_RELEASE_REVIEW_BLOCKED` を維持。
- 最終ゲートの形式的PASSだけでは資料内容の真実性・レビュー独立性を保証できない。2回の実質判断・著作権・施行日・差分整合を別途確認する。
- 対象コミットについてGitHubのcombined statusは空、取得可能なPR関連workflow runは0。**GHAの実行結果PASSとは認定しない**。CI・Node CLIの実地実行証跡は未取得。
- App Review提出0、新規TestFlight配信0。
- 最終判定：**Q0 BLOCKED / Q1 BLOCKED**。

## 継続実施 第4期（2026-11-22 JST）
- `HM2_INDEPENDENT_FIRST_PASS_20261122_BATCH04.md`：第6回法令の5問25肢を現行配布JSONと厚生労働省の法令本文・FAQに照合。聴力特例は35歳・40歳除外、一般定期健康診断は50人未満にも適用、衛生管理者専任は一般に1000人**超**であることを確認。
- 一次確認累計 **20/178問・100肢**。独立二重チェック合格 **0/178問**、権利最終判定 **0/300問**。一次確認を合格に読み替えない。問題データ・生成元・正答を変更していない。
- 新Q0ゲートに、配列等の不正なJSONトップレベル型を拒否しない欠陥を発見。二重チェック・権利ファイル双方について明示的にFAILを記録するよう修正した。証跡行がobjectでない場合も拒否する。
- 「公式」「監修」の単語があれば通るという弱い文言判定も修正し、非公式であること・監修なしであることの**否定形**を要求するようにした。『公式アプリ・専門家監修済み』の誤表示を拒否する回帰例を追加。
- 回帰テスト定義は従来6件に不正JSONスキーマ4件・誤表示1件を追加し **11件**。実行PASS証跡はまだ得られていない。
- コードはGitHubで更新済み。GHAの成功判定が可能な実測ログは取得できていないので実行テストをPASSとしては記録しない。
- 審査申請および新規TestFlight配信は実施していない。Q0・Q1はBLOCKED継続。

## 継続実施 第5期（2026-11-22 JST）
- `HM2_INDEPENDENT_FIRST_PASS_20261122_BATCH05.md` に追加5問（`sm2-5y-r06-law-07`・`08`・`09`・`10`、`sm2-5y-r07-law-02`）の25肢を記録。厚労省掲載の安衛法65条、安衛則45・51・51の2・52条、労基法36条と内容を照合。一次確認累計 **25/178問（125肢）**、二重確認完了 **0/178問**、権利最終判定 **0/300問**。
- 現行問題データの正答位置に明白な矛盾は見つからず、生成元・配布JSONの変更なし。
- この実行環境からGitHubのgit cloneはDNS解決失敗（`Could not resolve host: github.com`）。GitHub接続による読み出し・書込みは利用できるが、同一作業環境での全リポジトリcheckoutとNode CLIの実行はできていない。GHA結果もPR起点のワークフロー照会のみでは確認できず、PASSとは認定しない。
- 前期のゲート更新・回帰テスト11件はGitHubへコミット済み。**11件の実行結果は未確認**。
- 新基準の形式的完全性チェックだけでは独立性の実体や法令根拠の適合性を保証できない。最終Q0には別の実質照合が必要。
- Q0 BLOCKED / Q1 BLOCKED。App Review提出0・新規TestFlight配信0。

## 継続実施 第6期（2026-11-22 JST）
- 固定178問の次の5IDを公表一次資料で逐肢照合した：`sm2-5y-r07-law-03`〜`07`。詳細：`HM2_INDEPENDENT_FIRST_PASS_20261122_BATCH06.md`（GitHub commit `4b764f1839b746794525b733fe4cec2db6ebfca0`）。
- 単胎の産前休業請求6週間以内、産業医の巡視原則月1回と2か月例外、週4日・週28時間の年休比例付与、衛生推進者の氏名周知、産業医選任14日以内を厚生労働省公式ページで確認した。
- 正答indexと直接根拠の明白な矛盾なし。問題JSONと生成元データの変更なし。
- 一次確認：**30/178問（150肢）**。二重チェック完了：**0/178問**。権利最終判定：**0/300問**。残一次確認148問。
- 新Q0の実質承認は、独立した第2回確認と原資料の施行版・権利利用条件の判定を待つ。新Q0スクリプトの形式的PASSだけで合格としてはならない。
- App Review提出および新規TestFlight配信は実施せず。**Q0 BLOCKED / Q1 BLOCKED**。

## 継続実施 第7期（2026-11-22 JST）
- `HM2_INDEPENDENT_FIRST_PASS_20261122_BATCH07.md` に次の5問（`sm2-5y-r07-law-08`・`09`・`10`、`sm2-5y-r08-law-02`・`03`）の各5肢判定を記録。
- 厚労省掲載の安衛則13・43・44条、労基法56条、厚労省産業医・健康診断説明と逐問照合した。特に産業医の選任除外、専属要件（総数1000人以上／所定有害業務500人以上）、15歳到達後最初の3月31日までの児童就労制限を区別。
- 正答位置の明白な矛盾なし。配布JSON・生成元変更なし。
- 2026-11-22の検証環境で `git ls-remote` は `Could not resolve host: github.com` となり終了。**ローカルNode CLI・Pythonテストの実行PASSを確認していない**。GitHub接続によるコミットは継続可能。
- 一次確認累計 **35/178問（175肢）**、残143問。二重チェック済 **0/178問**、権利最終判定 **0/300問**。形式チェックを実質承認に読み替えない。
- App Review提出0件・新規TestFlight配信0件。**Q0 BLOCKED / Q1 BLOCKED**。

## 継続実施 第8期（2026-11-22 JST）
- `HM2_INDEPENDENT_FIRST_PASS_20261122_BATCH08.md` に次の5問25肢を記録：`sm2-5y-r08-law-04`〜`08`。厚労省公式FAQ（深夜25％割増）、安衛則44・52条（健診実施と報告の区別）、36協定月45時間、2025年1月からの電子報告義務、年休5日義務を照合。正答indexに明白な矛盾なし。内容の独立2回目と原著作物の権利調査は未了。
- 一次確認累計 **40/178問（200肢）**、残138問。二重確認完了 **0/178問**、権利判定 **0/300問**。現行問題データ・生成元・配布JSONは不変更。
- 新Q0ゲートの独立性判定を強化。JSON nullを証跡なしとして拒否し、異なるreviewer_idだけでなく独立セッション識別子・異なるSHA-256形式の証跡・事前の他レビュー非参照申告を求める。二つのレビューでreasoningと5肢判定本文の完全コピーが一致した場合はFAILにする。
- この形式検査は実質的な独立性の証明を完結しない。セッション記録の出所確認、実際に閲覧した公式版と著作権上の使用許諾判断は別途必要であり、Q0を形式チェックのみで承認しない。
- 既存11件にnull証跡2、同一セッション/アーティファクト2、レビュー複写1、独立性申告欠落1、偽SHA1の計7件を追加し、**回帰テストは18件**を定義。GitHub ActionsまたはNode CLIの実行PASSは未確認。テストを通過済みとは記載しない。
- **Q0 BLOCKED / Q1 BLOCKED**。App Review提出0件、新規TestFlight配信0件。

## 独立確認セッション追記（2026-11-22 11:31 JST）
- 指定ブランチの本台帳をGitHub接続から再取得し、直近記載の一次確認40/178、二重チェック0/178、権利判定0/300、回帰18件未確認を確認した。
- 指定コミット `8ce72a6` のcombined statusは空配列、取得可能なPR起点workflow runsも空配列。これらの照会だけではGHA未実行とは断定できないが、PASSの証拠は取得できなかった。
- 本セッションでは残138問の5肢原典照合、40問の独立二重照合、300問の権利個別判断を完了した証跡は作成していない。数値を増加させず、未検証を合格としない。
- GHAのworkflow_dispatchに相当する実行操作はこのGitHub接続では利用できず、18件の回帰テストの実測結果は未取得。PASSと記録しない。
- Q0 BLOCKED / Q1 BLOCKED。App Review提出と新規TestFlight配信は行っていない。

## 継続セッション：30問予備スクリーニング（2026-11-22 JST）
- `HM2_Q0_SCREENING_30_20261122.md` に固定178問台帳の明細41〜70行目から抽出した30IDの現行配布JSON対照を保存（commit `c5ab32ef269ce68dc2c87b143eed236dbe50b987`）。配布bank Git blob `72888a617ff17bf84b25e9d5a61f5cdec0d7493d`。全30問がbankに存在し、5肢・正答indexの形式は整合。
- 厚労省の一次資料について直接確認した限定事項：`sm2-5y-r09-law-05`（予定日超過分は産前休業）、`sm2-5y-r10-law-10`（産後6週経過後の請求と医師判断）、`sm2-5y-r09-law-08`（2025年1月の選任報告電子申請義務）。残る肢・各問題の出典版等まで確認完了したという意味ではない。
- 今回30問は予備スクリーニングであり、公式原典に基づく全150肢の独立一次確認や二重照合を完了した証跡ではない。既存40問とのID重複も未排除のため、一次確認の正式カウントは**40/178据置**。二重確認**0/178**、権利最終判定**0/300**。
- 配布JSON・生成元・正答の変更なし。回帰18件のGHA/Node実測PASS未取得。**Q0 BLOCKED / Q1 BLOCKED**。App Review提出・新規TestFlight配信なし。

## コーディネーター統合（2026-11-22 JST）
- 担当分割A/B/Cの各ファイルをGitHubから受領し、現行300問配布bankに照合。既存一次40件、A 69件、B 69件のIDは相互重複0・和集合178件、bank内存在178/178件。詳細を `HM2_Q0_COORD_INTEGRATION_20261122.md` に保存（commit `52ce4e0d331c39adcbc3f7b260aa42350dce24f4`）。
- 既存40問の二次意味検査（計200肢）を `HM2_Q0_COORD_SECOND_PASS_40_PROVISIONAL_20261122.md` に保存（commit `184a836c65c656b0f55a548dd77e2cbd328561d6`）。全肢の2026年施行版と独立性証拠が不足するため、**二重チェック正式完了0件**に据え置く。
- Aは先頭30/69の机上評価、Bは69/69の机上評価（公式通達等への直接照合申告4/69）、Cは300/300件の権利メタデータ分類を追記。ただし既存記載の旧進捗と追加記載を区別し、正式な一次全肢原典合格や権利承認を自動加算しない。権利最終承認**0/300件**。
- `git ls-remote` は環境のDNS失敗。Node CLI・Python回帰18件の実地実行結果を取得できず。GitHub commit `184a836c` combined status空、PR起点workflow runs空。GHA成功と判定できない。
- **Q0 BLOCKED / Q1 BLOCKED**。審査・新規TestFlight配信なし。未確認を合格に見せる記録やゲート変更なし。

## コーディネーター：40問公式条文再照合・最新A/B/C取り込み（2026-11-22 JST）
- `HM2_Q0_COORD_40_LEGAL_SOURCE_RECHECK_20261122.md`（commit `a119e36c309762015484c2992e1c7bb683efee14`）に既存40問・200肢の正答位置、肢別の暫定○×、厚労省公式掲載の法令条項とURLを記録。安衛則7・23・44・45・51・51の2・52条等、労基法の主要条項を公式本文で再照合した。
- 2026年適用法令版を全40問の全肢に個別固定し、独立実施者・独立セッションを証明する作業は未了。**40問の正式二重チェック合格数は0件**とし、実質的根拠を伴わない自動承認は行わない。
- 最新A/B/Cを再取得。既存40+A69+B69の178問の重複0、bank一致178/178。Cの主一覧300IDもbankに全件一致。A/Bはいずれも全69問の5肢机上判定を作成したが、A自身の正式原典合格は0/69、Bは公式根拠への直接照合を4/69と申告。未完の逐肢根拠をQ0合格として加算しない。
- Cで初期30問に原典類似・出典不適合疑義：`sm2-demo-001`〜`003`、`sm2-demo-014`、`015`、`028`、`029`。要修正・追加原典精査。**権利最終判定0/300件**。
- 18件のPython回帰テストを実環境で実行するためのcheckoutは、この環境ではGitHub DNS解決失敗で不可。実測PASSとして報告しない。GitHub接続には新規workflow起動アクションがなく、GHA起動もできない。
- **Q0 BLOCKED / Q1 BLOCKED**。配布・生成元・正答変更なし。App Review提出・新規TestFlight配信なし。

## コーディネーター最新版統合・再判定（2026-11-22 JST）
- 更新時点のスライスA/B/Cを再取得し、`HM2_Q0_COORD_LATEST_SLICE_INTEGRATION_20261122.md` に個別blobと状態を固定（commit `e8244d9c5b08212921b09f42a0131bad529e2635`）。既存40 + A69 + B69 = 178件、重複0、配布bank一致178/178。C300件も全てbank内一致。
- Aの現段階自己申告は**52 PASS / 17 HOLD**。Bは内容点検69/69、公式根拠の全肢直接照合は未完了（従前直接4/69と追加探索）。Cは個別原典調査**90/300**まで進展、**権利最終承認0/300**。
- 既存40問について既存二次意味検査40問200肢と公式法令2026年適用版・厚労省の選任報告・電子化・労基法説明を再参照。ただし独立した別セッション・レビュアーの真正証拠、各肢版別原文、銀行SHA-256の固定が不足。**正式二重確認0/40**のまま。形式的に40件を承認済としない。
- AのHOLD17件は全件保留。Cで確認した原典類似・不適合・StatPearls商用利用・CC帰属条件などを最終権利PASSへ自動昇格させない。
- `git ls-remote` はDNS失敗。GitHub Actionsの手動起動機能がGitHub接続にないため回帰18件の実測PASS/GHA実行を取得できていない。
- **Q0 BLOCKED / Q1 BLOCKED**。App Review提出0、新規TestFlight配信0、問題bankと生成元は不変更。

## ユーザー指定・二次レビュー担当への役割変更後（2026-11-22 JST）
- **40問200肢の二次内容評価を実施**。現行bank全5肢と選択肢の正否を個別記録に保存：`HM2_Q0_COORD_SECOND_CHECK_40_CURRENT_CHOICES_20261122.md`（commit `7ee90b03cdb55f47387a9a09a6bca0c1dcc08c7f`）。現行正答と確定的な矛盾が立証された問は0。だが当該セッションは既存一次レビューにアクセスしているため「他レビュー未閲覧」を宣誓できない。**二次実施40問、正式独立二重承認0/178**と区別して記録。
- A/B/C最新取り込み：`HM2_Q0_COORD_ROLE_DOUBLE_CHECK_INTEGRATION_20261122.md`（commit `0b368686843decda50244d442749dd34a71786e7`）。Aは一次内容PASS**69/69**、Bは69/69の本文・5肢索引（公式直接根拠の全肢検証は未完）、Cは運用上**PASS284／要差し替え16**。CのPASSは最終的な著作権クリアランスではなく、正式権利承認0/300。
- **差し替えの未実装**：16件の作問・出典変更には生成元での改修後の300問再生成、差分制限、5肢正誤、適法性・独自性検証が必須。現時点の根拠・再生成ゲートが未完成のため、配布JSON単独の危険な書換えをしていない。問題データ修正コミット0件。
- GHAを新規起動できない理由：GitHub connectorがworkflow_dispatchを提供せず、実行環境はgithub.com DNS解決失敗。既存GHAの成功・Node再生成・元Python unittest18件の実測PASSは未取得。
- **代替静的テスト18件は実際に実施して18/18 PASS**。現行300問bankのID・5肢・正答範囲、A/B/Cの集合、ゲートコード上の独立性・権利チェック等を確認（`HM2_Q0_COORD_STATIC_REGRESSION_18_20261122.md`、commit `b8905b24712cab7091e7dccb4f8fc0d5a8aba6a3`）。このテストは**元Python回帰18件の代替的な静的検査であり、同一テストの実行ではない**。
- **Q0 BLOCKED / Q1 BLOCKED**。App Review提出なし／新規TestFlight配信なし。旧ゲートを弱める変更なし。

## 独立二次チェック正式担当指名後・追加作業（2026-11-22 JST）
- ユーザーは本セッションを二次担当として指定。現在の300問bank Git blobは `72888a617ff17bf84b25e9d5a61f5cdec0d7493d`。既存40、A69、B69の対象178一意IDと計890肢の現行本文・正答・出典URL・検証状態を再収集し、`HM2_Q0_COORD_SECOND_REVIEW_SCOPE_178_20261122.md`（commit `26beec8216164957908fb759818d9b6eaf58789d`）に保存。正式独立全肢承認ではなく照合範囲の索引。
- 既存40問200肢の二次内容評価を `HM2_Q0_COORD_SECOND_CHECK_40_CURRENT_CHOICES_20261122.md`（commit `7ee90b03cdb55f47387a9a09a6bca0c1dcc08c7f`）に記録。先行レビューにアクセス済みで、代替ゲートの `performed_without_prior_review_access` の真正な証跡を生成できない。**二次内容検査40/178、完全独立承認0/178**。Aは一次内容69PASS、Bは69問の5肢索引を整備したものの原典逐肢に残件。
- Cは運用分類PASS284/要差し替え16だが著作権最終承認0/300。16問のうちCが提供した9問の代替草案を、5肢数・正答範囲・重複ID等の5静的条件に合格した構造化JSON `HM2_Q0_C_REPLACEMENTS_16_STAGING_20261122.json`（commit `e86fe1bd03d81fc715323ee370c98e4bfe21a826`）として準備。残7問は `BLOCKED_NO_VALIDATED_REPLACEMENT`。**生成元への差し替え・配布JSON再生成・限定差分検査・公開用コミットは未実施**。草案JSONは本番データではなく、権利・根拠・重複・一意正答の再検証が必要。
- GHA新規workflow_dispatch操作がGitHub接続に存在せず、コンテナで `git ls-remote` が `Could not resolve host: github.com` となりcloneできないため、Node/Python本来の回帰や再生成を実行できない。代わりに前回の現行bank/スライス/ゲートコードに対する静的検査18/18 PASS（`HM2_Q0_COORD_STATIC_REGRESSION_18_20261122.md`, commit `b8905b24712cab7091e7dccb4f8fc0d5a8aba6a3`）と今回の草案構造5/5 PASSを確認。本来のPython unittest18件実測PASSやGHA成功とは異なる。
- **Q0 BLOCKED / Q1 BLOCKED**。現行データ、生成元、リリースゲートを改変せず、App Review提出・新規TestFlight配信なし。

## コーディネーター：B 12 PASS／57 HOLDの統合・C3問改稿と2件出典修正（2026-11-22 JST）
- 受領した最終スライスのblob SHA：A `720b7187a9dada5e30131a1a5c0e118e7d87d580`、B `6dc900fea52e4d08cc87f4c9a9f7c98638a32778`、C `c75f38d7f9d94687d2b3464b43f3fe10bc8cfc9f`。Aは**一次内容PASS69/69**、Bは**一次PASS12/HOLD57**（日本厚労省一次資料だけに限定すればBの直接照合PASS6との申告）、Cは運用分類**PASS284・要差し替え16**。CのPASS284は著作権最終許諾承認ではなく、**最終権利承認0/300**。
- 既存40+A69+B69=178一意ID・890肢の現行値を`HM2_Q0_COORD_SECOND_REVIEW_SCOPE_178_20261122.md`（commit `26beec8216164957908fb759818d9b6eaf58789d`）に保存。既存40の200肢意味検査は`HM2_Q0_COORD_SECOND_CHECK_40_CURRENT_CHOICES_20261122.md`（commit `7ee90b03cdb55f47387a9a09a6bca0c1dcc08c7f`）。一次レビュー閲覧済みなので「先行レビューを見ずに独立レビューした」という虚偽の宣誓はできない。B57問はそもそも公式原典逐肢照合が未完成。**形式的二次対象索引178/178、実質二次内容検査40/178、正式独立二重PASS0/178**を区別。
- Cの要差し替え16問から、**sm2-demo-001／002／003**の3問について元公表問題の構成類似リスクを低減する新規状況判断型問題へ差し替え、生成元`apps/sanitary-manager-2/hm2-c-replacements-v1.js`（commit `42039f39df8e554eac105117ac1cc9d5ea150015`）とアプリ及びexporterのロード順・サービスワーカーキャッシュ、配布JSONに反映（配布commit `a448eb7341b8d216813e8d168e79b014af7149fd`）。Cの提案文案を独立再吟味し、正答肢位置は旧正答位置に維持して各10問セットの1〜5各2問分布を維持。**3問は旧legal_checkedをnullに戻しaudit_status=再監査待ち、publication_status=非公開とした。法令再確認や商用利用権利は未承認**。残13問のC差し替えは未実装・HOLD。
- Aが提案した**sm2-5y-r05-hyg-05／sm2-5y-r07-hyg-08**の2問は産総研2020-12-03の公式説明『換気回数=換気量÷室容積』を直接確認し、出典URLと解説根拠フィールドを改修。生成元パッチ`hm2-source-precision-v1.js`（commit `d98b77c045daa60c3e872d520ca72b0b31f643dd`）をアプリ・exporterに組み込み、配布JSONへ反映（commit `96ace2e80d30a3e31eb6002e06611a30d71ec0c0`）。2問の問題文・5肢・正答は不変。
- 元配布JSON Git blob `72888a617ff17bf84b25e9d5a61f5cdec0d7493d`→現行 `b954a6b8c0606f5c34589b7b7eafd269bbe65489`。**変更5IDのみ、他295問は完全一致**。300問・30群×10・5肢相異・正答位置均衡・修正3問非公開・旧法令監査無効などを含む**代替静的限定差分テスト28/28 PASS**（`HM2_Q0_COORD_LIMITED_DIFF_TEST_20261122.md`, commit `52f295c92b5c1dffece403d8e32e5846c7424173`）。これはNodeでの正規再生成バイト一致・Python unittest18件・GHAではない。
- 元のA/B/Cや二次レビューの銀行SHA証跡は更新前の配布bankを指すため、**SHA-256固定に基づくQ0形式合格に流用せず、現行bankでの再固定と承認が必要**。更新に伴う以前の独立レビュー件数を自動承認しない。
- GHA新規起動はこのGitHub接続にworkflow_dispatchアクションがない。ローカルgitは `Could not resolve host: github.com` でcheckout不能。正規のNode再生成・Python18回帰の実測PASSも未取得。
- **Q0 BLOCKED / Q1 BLOCKED**。C残13問の未実装、B57問の原典HOLD、レビュー独立性、権利最終承認0/300、再生成の正規PASS未取得が解除条件。App Review提出・TestFlight新規配信なし。

## 最新B（PASS15/HOLD54）・C要差し替え残13の実装・再判定（2026-11-22 JST）
- Bの最新版から**一次PASS15/HOLD54**を確認。A一次内容69/69 PASS、既存一次40問と合わせ対象178問、ID重複0。対象178問の二次レビュー用索引は `HM2_Q0_COORD_SECOND_REVIEW_SCOPE_178_20261122.md`、既存40問200肢の意味二次確認記録は `HM2_Q0_COORD_SECOND_CHECK_40_CURRENT_CHOICES_20261122.md` を参照。**正式な独立二重承認済0/178**。本セッションでは先行判定にアクセスしており、盲検「先行レビュー未閲覧」宣誓はできない。BのHOLD54を二重確認済PASSへ機械的変更しない。
- Cの残13問を新たな独自場面型・基礎概念型問題に再設計し、`apps/sanitary-manager-2/hm2-c-remaining-13-v1.js`（commit `4c9c131682d635dde8e2a43a8135fcf606ec1e2a`）に旧問題・正答文・出典の一致確認ガード付きで反映。 `export-audit-data-core.cjs`、`index.html`、Service Workerへ接続。新しい配布JSONをcommit `b796be432dc0c655cc8e04865e4b571ce3126c51` で保存。変更ID：`sm2-demo-014`, `015`, `022`, `027`, `028`, `029`, `sm2-r7o-015`, `026`, `027`, `028`, `sm2-r7a-016`, `030`, `sm2-5y-r09-phy-01`。
- 先行実装3問（`sm2-demo-001`〜`003`）と合わせて**C指定16/16問の代替設問を生成元パッチ・配布JSONへ反映**。16問全て `publication_status=非公開`、`audit_status=再監査待ち`、`legal_checked=null` とし、旧承認・公開候補を流用しない。16問の新たな原典逐肢照合と表現独自性・著作権最終判断は未実施。**内容差し替えの実装完了とQ0権利承認は別**。
- 配布JSON現行Git blob `fc2c1dd22bf0699bb1da2ce49b0ddb4400fce556`。GitHub連携でbank、A/B/C、Cの16問パッチ、画面、SW、exporter、独立性ゲート、Pythonテスト定義を取得して**代替静的検査28/28 PASS**（`HM2_Q0_C16_POST_REPLACEMENT_TEST_20261122.md`、commit `73548104222513a0bc2eb122d8658062a0b46e86`）。300問・30群10問・5肢一意・正答位置分布・16問再監査待ち非公開・独立Q0保護を確認。
- **GHA起動不可**：現GitHub接続には新規workflow_dispatch操作がなく、ローカルGitHub cloneはDNSエラー `Could not resolve host: github.com`。正規Node exporterによる再生成バイト一致、Python unittest18件、GHAのPASSは未取得。28件のJS静的検査はこれらの代用品ではあるが同等の総合品質テストではない。
- 16問の本文が変更されたため、一次・二次レビューの旧出題文面証跡は当該16問に再利用できない。新銀行のSHA-256を固定し、原典・正答・権利再判定後に記録をやり直す。C運用PASS284の権利最終クリアランスは**0/300**。
- **Q0 BLOCKED / Q1 BLOCKED**。App Review提出と新規TestFlight配信は実施していない。

## 【最新のユーザー決定】Q0代替基準の最終運用規則（2026-11-22 JST）

この節は、上記に残る履歴の「外部法律専門家の実名承認が必要」「権利の最終判定は個別の法律的許諾完了300件以外認めない」「このコーディネーターの既存の二次チェックだけが唯一の証跡」といった**旧基準の扱いに優先**する。過去の監査実績・未実行テストを遡及して合格にしない。

### A. 法令・専門家基準
- **外部法律専門家による監修・判定・実名承認はQ0必須条件としない**。ユーザー承認の代替条件は、対象問題の正誤・法令の施行日・適用範囲を公式一次資料と照合すること。
- アプリ内、サポート、ストア説明の「非公式・専門家監修なし」表示は維持する。未検証の正誤や法令解釈を専門家承認済みと表示しない。

### B. 権利基準（Cの運用二値判定を最終的な内部運用判定として採用）
- C担当が付けた**既存284問の運用PASS**をQ0権利カテゴリの**内部運用上の最終PASS**として採用する。これは公表問題・画像・出典全文の転載許諾や非侵害を法的に保証する表現ではない。
- C担当の**要差し替え16問**は、旧文面のPASSとして扱わない。生成元と配布bankへの代替設問実装が全16問完了していても、**差し替え後の新文面についての再監査PASS**（5肢の独自性、出典対応、利用条件、正答・重複等）が必要。16件の個別再監査PASSの証跡が揃った時点で、**284＋16＝300/300を権利カテゴリの最終運用PASS**とする。
- 現行bankの変更後Git blob `fc2c1dd22bf0699bb1da2ce49b0ddb4400fce556`。16問は `audit_status=再監査待ち`、`publication_status=非公開`、`legal_checked=null` にしており、この確認時点では**権利運用最終PASS：284/300（残16は再監査待ち）**。284件についても本節の内部運用定義を超えて権利侵害不存在を保証しない。
- Cの元スライス `HM2_Q0_SLICE_C_RIGHTS_300_20261122.md` には古い段階の「最終権利承認0/300」という**法的クリアランスを意味する表現**が残っている。これは本節の新しい**内部運用PASS284/300**と評価概念が異なり、数値の矛盾として扱わない。

### C. 独立二重チェック基準（新設DCセッションを正本とする）
- 二重チェックの採否は、コーディネーターの従前の再確認記録ではなく、別セッションの正本 `ios/health-manager-2/audit/HM2_Q0_INDEPENDENT_DC_20261122.md` の**実際の各問題ID・5肢・公式根拠・レビュー対象bank版・判定結果**によって認定する。
- DCセッションの問題別PASSはその検証対象と証拠を確認できた範囲だけ採用。**DC記録がない問、DCでHOLDの問、更新後bankと文面が異なる問はPASSに算入しない**。新規差し替え後の本文・5肢は、旧版DCの承認を流用せず再照合する。
- **2026-11-22の今回確認時点で、指定ブランチ上の `HM2_Q0_INDEPENDENT_DC_20261122.md` はGitHub Contents APIで404（NOT_FOUND）。GitHubファイル検索でも検出なし**。よってDCの個別PASS件数は**未確認**であり、0件と確定するものでも全178問PASSと仮定するものでもない。DC正本を取得できた時点でその記録により件数を再集計する。
- 旧記載「このコーディネーターは先行一次判定を参照したので独立性に問題」は従前のコーディネーター自身の記録の位置づけに関する注意であり、**新設DCの独立実施を否定するものではない**。新設DCの実績確認は正本に基づく。

### D. Q0→Q1判定・テスト
- **Q0通過**には、(1)上記DC正本の現行版178問の必要な内容二重チェック、(2)B等の公式根拠HOLDの解消、(3)Cの284＋再設計16問の再監査PASS、(4)非公式・監修なし表示、(5)既存の厳格な技術検査との整合が必要。
- GitHubにある従来の `scripts/hm2_alternative_q0_gate.py` は、レビュー証跡JSONと権利300件の構造を検査する**旧実装のまま**。今回の**運用基準変更をコード変更・自動ゲートPASSと混同しない**。今後、正本DCおよびC再監査結果を証拠JSONに反映してコードと整合を取る必要がある。承認省略やゲートの迂回は禁止。
- 現時点ではDC正本の取得不可、B公式原典HOLD、C16再監査未完、正規Node/Python/GHA実測PASS未確認のため、**Q0 BLOCKED → Q1 BLOCKED**と判定する。
- App Review提出、新規TestFlight配信は実施しない。

## production-readiness技術エラー対応（2026-11-22）
- ユーザー報告：既存GHA 84/87でunittest18/18 PASS、非公式表記PASS。一方で`UNREVIEWED_BANK_SHA`、`CANONICAL_REGENERATION_FAILED`、厳格exportの`legalChecked`欠落、gm2表示の疑義。**これらのGHA実測値はユーザー報告であり、本セッションで同じrunのログを再取得したものではない。**
- 現行配布JSON `ios/health-manager-2/release-questions.json` のUTF-8バイト列を独立SHA-256計算（既知ベクトル`abc`で実装検算）し、`95e394dfa8f7d8b8dd23b763c168e61ab71e4e452fc519f87111011fc4c34eef`と確認。`scripts/hm2_submission_readiness.py`の`PIN`をこの値に更新（commit `e10800cbdb57353c63833842686f36cc3b4f2b18`）。**この修正は当該時点のbank固定であり、後続コミットがbankを変更した場合は再計算必須**。
- 現行の`export-canonical-snapshot.cjs`と`export-audit-data-core.cjs`には`q1..q12`、difficulty patch、監査overlay、`hm2-source-precision-v1.js`、`hm2-c-replacements-v1.js`、`hm2-c-remaining-13-v1.js`、`hm2-source-evidence-v2.js`が組み込まれている。**旧18問への生成側戻りを示したGHAの状態からは更新されているが、今回Node CLIでバイト一致を実測していないためCANONICAL_REGENERATION_FAILED解消は未認定**。
- `export-audit-data-core.cjs`は法令関連で`legalChecked`がない場合`HM2_RELEASE_REVIEW_BLOCKED`を投げる。readiness scriptはこのコードを`submission_blockers`に分類する設計。ユーザー決定の外部専門家承認不要と、未監査の新設問を無条件承認しないことは両立する。**ゲートを迂回してtechnical_errorsを見かけ上0にする修正はしない**。
- 現行`apps/sanitary-manager-2/gm2.js`には`5年分相当の追加演習`の表記が存在。旧GHAの指摘は現行版と差異があり、追加変更は不要。
- **今回実際に修正・コミットしたのはPINのみ**。GitHub Actionsの更新後実行結果、Node canonical snapshotのバイト一致、厳格exportの分類結果は未取得。従って**technical_errors=0はまだ証明されていない**。unittest18/18 PASSと非公式表記PASSはユーザー報告に基づく。
- Q0/Q1の内容・権利承認は別。App Review提出・新規TestFlight配信は行わない。

## 2026-11-22 正規再生成・技術エラー追跡（追加実査）
- GitHub接続で現行の`release-questions.json`（300問、Git blob `1d416598f518a8631c177885b4a4356bd6a96696`）、`scripts/hm2_submission_readiness.py`、canonical exporter、strict exporter、C差し替えパッチ、DC正本を読み直した。
- **PINは既に `a37f2b6def74b97f71ac73cbbc73869f739201c1e5766a2247ce39fe742dcb69` に別更新されている**。前回の`95e394...`は旧bank版であり、再度上書きしてはならない。現在のPINとbankのバイト一致は、この確認では再計算・実測できていない。
- 16差し替え中、法令関連3問 `sm2-demo-001/002/003` は**現行配布JSON上で`legal_checked=2026-11-22`**。ほか13問は`law_related=false`かつ`legal_checked=null`で、`audit_status=再監査待ち`、`publication_status=非公開`。法令非該当13問の`null`を機械的に日付で埋めることはしない。法令関連3問も内容再監査・権利判定のPASSを意味しない。
- **独立DC正本 `HM2_Q0_INDEPENDENT_DC_20261122.md` は取得できた**。記録冒頭では固定178問中30問・150肢の独立PASS、未実施148問と明記されている。以前の「DC正本404」の記載は現時点で解消。DCの完了件数は30/178であり、全件合格と誤認しない。
- `export-canonical-snapshot.cjs`は16問差し替え、出典2問ほかのoverlayをロードする実装。実行環境からgithub.comへのDNS解決が失敗し、リポジトリのローカル取得不可。GitHub接続はファイル単位の読み書きに限定される。**Nodeでの正規再生成、現行bankとのバイト一致、最新GHA runの`technical_errors=[]`はこの作業では実測していない**。
- strict exporterの`lawRelated && !legalChecked`条件は法令関連設問の未確認を遮断するものであり、削除・緩和しない。Q0代替基準は外部専門家承認を要求しないが、公式一次資料照合と差し替え後の独立確認を省略しない。
- 結論：**技術エラーゼロは未確認**。追加確認を行うまでQ0/Q1 BLOCKED、App Review/TestFlight禁止。

## 生成元完全一致の実測・readiness技術状態更新（2026-11-22 JST）
- 現行GitHubブランチの**22生成元JS**を正規ロード順でJavaScript実行し、`export-canonical-snapshot.cjs`と同じJSON射影・改行で300問を再生成。再取得した配布JSON Git blob `54aceef12cdd3391920fff7847e83948868ab4dd`との**バイト単位完全一致／差分0**を確認。difficultyあり／なしで問題文・5肢・正答・解説等のドリフト0、30群×10問・正答位置均等PASS。
- 差分の原因は`sm2-5y-r07-phy-04`, `sm2-5y-r10-phy-02`, `sm2-5y-r10-phy-10`の`content_review_status`欠落のみ（旧配布bankと生成元との差分）。生成側の`requires-independent-subject-expert-review`を配布JSONへ正規反映。問題文・正答は不変。配布JSON修正commit `5ccb3a030c5da6e883cf4ae91c08e0ba8d39afd5`。
- 正規bankの**SHA-256**：`60e9be2037efd4e840decf75e097232d32cd3d1be3bb99464707439c46e9cad1`。readiness `PIN`を同値に更新、commit `b2ee0defd0a9340d51757f5ec37d0aa15e6dc436`。SHA256実装は既知ベクトルで検算。GitHub内の一時入力束は検査終了後commit `92176e3027a1bd9084a3d45137e1129cb319c50a`で削除済み。
- `hm2_submission_readiness.py`の実体データに対する構造300問、178問ID、StoreKit現在価格、PrivacyInfo、17法令live pins、`gm2.js`の『5年分相当』、非公式表記の個別検査はPASS。法令関連`legalChecked`欠落0。
- Cの第9段階正本：**差替え16/16問の正答内容PASS、権利・出典の運用PASS16/16**。既存284運用PASSと合わせ、ユーザー決定の**権利の内部運用最終判定300/300 PASS**と記録。ただし法律上の転載許諾や非侵害を保証する表現ではない。C正本の判定とアプリ内の保留メタデータは別工程であり、無検証の一括公開ステータス操作は行わない。
- 独立DC正本：**30/178問・150肢PASS、残148問**。DC先行レビューの対象SHAと最新bank SHAの違いを自動合格扱いせず、問題文等の内容照合と記録継続が必要。
- **readinessの技術原因**：`UNREVIEWED_BANK_SHA`は新PIN一致で解消、`CANONICAL_REGENERATION_FAILED`はGitHub上の22JSを実行した同等再生成で実測差分0。だが**Node CLIのGHA run上での実測`technical_errors=[]`は未確認**。厳格exportの独立Q0未承認時の`HM2_RELEASE_REVIEW_BLOCKED`はreadinessの`submission_blockers`として扱い、`STRICT_EXPORT_UNEXPECTED_FAILURE`を隠すことやガード撤去はしない。
- 全検証明細：`HM2_CANONICAL_BYTE_MATCH_20261122.md`、commit `e00455ba9c52b3e4265a3f017e22beeabde35362`。**Q0 BLOCKED / Q1 BLOCKED**はDC残148問等の内容ゲートが未完であるため据置。App Review提出・TestFlight新規配信なし。

## 2026-11-22 12:54 JST：GHA production-readinessの技術失敗解消確認（最新版）
- 最新bank Git blob `4ecbfea81e3a453aa6bf60e4647d880abf821c09`、SHA-256 `434de86ab795d369a1ef52f16a0cf57cab7054b72f6aac952aa7805fb3872177`（605819 bytes）。前回の`60e9be20...` pinは後続のB内容変更で陳腐化したため、`scripts/hm2_submission_readiness.py`のPINを更新・commit **`b13e5aac5e5b5dbfcbbf0cf54437ff9a122c62f2`**。
- 現行22JS（q1～q12、difficulty、監査overlays、C16問差し替え、出典更新）をGitHub連携から再取得してJavaScript実行、**生成300問の正規フィールドJSONが配布bankとバイト完全一致／差分0**。difficultyあり／なしの主要8フィールドドリフト0。法令内容固定17/17 PASS。従前の18問不一致は現行生成側で解消済み。独立した実測結果と入力範囲は`HM2_READINESS_RECHECK_20261122_1254.md`（commit **`d660750058c65fc085e79cd1d30bb721532b136f`**）。
- `sm2-demo-001` の`legal_checked`は現行生成元・配布JSONに`2026-11-22`を確認。gm2に『5年分相当』あり。
- **新たな内容未承認1問**：`sm2-5y-r10-hyg-04`の`law_related=true, legal_checked=null`。法令確認を捏造せず、厳格exportの`HM2_RELEASE_REVIEW_BLOCKED`による停止を継続（readiness設計では`submission_blockers`）。ゲート弱体化なし。
- **技術失敗の原因の解消（SHA/再生成）は実測完了**。ただし、最新のGitHub Actions runから`technical_errors: []`という実レポートは取得不可。pin更新コミットのstatus取得は0件、PR起動workflow run検索は0件であり、push起動runの成功・失敗を確定できない。**GHA自体の成功・技術エラーゼロを実測済みと記載しない**。
- ユーザー代替Q0基準：権利カテゴリはCの284既存PASS＋差替え16再監査PASSで**運用最終300/300 PASS**。DCの独立二重チェック正本は`HM2_Q0_INDEPENDENT_DC_20261122.md`で**30/178 PASS、残148**。最新bankとの内容一致照合を要し、完全Q0承認はまだ行わない。
- **Q0 BLOCKED／Q1 BLOCKED**。App Review・TestFlightは実施禁止・未操作。

## 【2026-11-22 統合引継ぎ】独立DC 178/178完了・B2一次HOLD0・C権利運用300/300（Q0/Q1本判定は保留）
**今回のユーザー指定：Q0/Q1の本判定は14:00頃に再依頼。今回の工程は監査証跡の統合だけであり、合否再判定・App Review提出・TestFlight配信は行わない。過去の節にある「DC30/178」「権利284/300」「BのHOLD残件」は当時の履歴であり、この最新節を現時点の引継ぎ正本とする。**

### 1. 独立二重チェック（正本DC）
- ユーザー指定の最終commit **`b92c8ba89e93ce5b00cad4daeb5e33576e12eb4f`** をGitHubで実在確認（`audit(hm2): complete 178 independent Q0 reviews and revalidate pulse deficit No.134`）。
- `ios/health-manager-2/audit/HM2_Q0_INDEPENDENT_DC_20261122.md` の現行Git blob：`6e4eb7a5a232505b424c97caf533e7bec9acfb11`。正本の最終結論は、**独立178/178問・890肢を完了、正答PASS178、解説PASS178、総合PASS178、HOLD0、要修正0、未実施0**。No.134は追加根拠を確認してHOLDからPASSへ再判定済。
- この結果を**ユーザー承認のQ0代替基準の独立二重チェック結果として採用**する。以前のコーディネーターによる40問の非盲検チェックを独立DCの代わりに数えない。
- DC原票には作業中の旧時点の「今回30問・残148」「累計30/178」等の履歴文が残るが、原票冒頭と最終集計は178/178で整合。原票の対象bank版と現行bankの問題本文・肢・正答・解説の最終同一性照合は、14:00本判定で別途照合対象とする（証跡の継承を無条件の自動合格扱いしない）。
- DC No.134の根拠には政府機関サイトに収録された外部著者の研究・教材があり、政府自身の執筆資料のみという最狭義の出典基準とは区別する。ユーザーの代替Q0基準の適合性を14:00の本判定時に検討する。

### 2. B2一次内容とC権利の最終運用判定
- **B2の残HOLDは一次内容0件**としてユーザーが最新状態を通知。本セッションで取得した旧分割B台帳 `HM2_Q0_SLICE_B_FIRSTPASS_BACK69_20261122.md` の最終章には履歴上の`PASS47/HOLD22`が残存するが、**旧一次基準のHOLD22と、ユーザー通知の「B2追加対応後の一次内容HOLD0」を混同しない**。今回の統合ではB2の最新件数をユーザー報告として受け入れ、14:00本判定では更新後のB2改稿／原典対応の証跡と突合する。
- Slice Cの第9段階最終記録は、**差替え16問の正答・権利・出典の運用再監査PASS16/16（FAIL0／HOLD0）**。既存284問の運用PASSと合わせ、ユーザー承認の代替Q0基準上、**権利の内部運用最終PASS300/300**とする。外部法律専門家の判定は必須条件でなく、運用PASSは法的に非侵害を保証する意味ではない。
- B2の一次結果、独立DC結果、Cの運用権利最終PASSは、それぞれ異なる監査軸とする。権利の内部最終PASSをもって内容または法令の各ゲートを自動PASSにはしない。

### 3. 生成元・配布データ・pinの現行状態（コミット済み）
- 最新の配布JSON：`ios/health-manager-2/release-questions.json`、Git blob **`4ecbfea81e3a453aa6bf60e4647d880abf821c09`**、300問。
- 最新bank SHA-256：**`434de86ab795d369a1ef52f16a0cf57cab7054b72f6aac952aa7805fb3872177`**。readiness側 `scripts/hm2_submission_readiness.py` の現行PINと一致。PIN修正済コミット **`b13e5aac5e5b5dbfcbbf0cf54437ff9a122c62f2`**。
- 前回、最新22生成JS（q1～q12、difficulty、各監査overlay、C16差し替え）をGitHub取得して実行、300問JSONと**バイト一致／差分0**。証跡は`HM2_READINESS_RECHECK_20261122_1254.md`、commit `d660750058c65fc085e79cd1d30bb721532b136f`。生成元とbank全体の一致は確認済みだが、最新GHA runで`technical_errors=[]`を実測したと主張しない。
- `sm2-demo-001`の`legal_checked`および`gm2.js`の『5年分相当』表記は反映済み。直近確認では`sm2-5y-r10-hyg-04`の`law_related=true, legal_checked=null`が残存する。承認日を捏造せず、14:00本判定の確認対象として引継ぐ。

### 4. 判定時刻と禁止事項
- **今回Q0/Q1は新たに本判定しない。直前のBLOCKEDを暫定維持し、14:00頃のユーザー再依頼で公式原典・現行bank整合・技術証跡・適用ゲートを統合判定する**。
- App Review申請、TestFlight新規配信、公開設定変更、リリースゲート弱体化は**行わない**。


## 2026-11-22 Coord継続：ゲートスキーマ実査によるQ0→Q1再判定

- 判定基準はユーザー承認の代替Q0（外部専門家承認不要／運用権利判定を最終扱い）とする。外部専門家がいないこと自体を不合格理由にしない。
- 独立DC原票 `HM2_Q0_INDEPENDENT_DC_20261122.md` の最終結論：178/178問・890肢、正答／解説／総合PASS178、HOLD0。No.134は再判定PASS。
- C権利台帳 `HM2_Q0_SLICE_C_RIGHTS_300_20261122.md` の最終運用結論：既存284＋差替え16/16＝300/300 PASS、権利運用HOLD0。法律上の非侵害保証ではない。
- B2一次内容HOLD0は前Coord統合記録とユーザー通知に基づく。旧B分割の履歴上のHOLD22を最新状態と取り違えない。
- 現行bank記録：300問、Git blob `4ecbfea81e3a453aa6bf60e4647d880abf821c09`、SHA-256 `434de86ab795d369a1ef52f16a0cf57cab7054b72f6aac952aa7805fb3872177`。正規再生成バイト一致、PIN一致は既存実測証跡による。
- ユーザー提示の追加実測：GHA `hm2-production-readiness` run160 success、技術エラー0、unittest18/18。今回このrunログの直接再取得・`--enforce`ローカル実行は未実施なので、独立実測とは表示しない。

### ゲートJSONについて確認した厳格条件

`scripts/hm2_alternative_q0_gate.py` は次の2ファイルを要求し、markdown台帳そのものでは代用できない。
1. `audit/HM2_INDEPENDENT_DOUBLE_CHECK_178.json`：178件の `reviews`、各行で**2つの実在する独立レビュー**が必要。それぞれ別 `reviewer_id`・`independent_session_id`・`evidence_artifact_sha256`、現行bank SHA、5肢本文・肢別正誤・根拠・一次資料箇所、先行レビュー非閲覧の真実の宣誓、照合後最終承認が必要。
2. `audit/HM2_RIGHTS_CLEARANCE_300.json`：300件の `decisions`、個別 `source_url`・`rights_holder`・`license_or_exception`・`originality_comparison`・`decision_rationale`・`reviewer_id`・`reviewed_at` を要する。

DC原票の完了178件は**一つの独立セッションによるレビュー**。既存Coord記録 `HM2_Q0_COORD_ROLE_DOUBLE_CHECK_INTEGRATION_20261122.md` は40件が非ブラインドであると明記し、`performed_without_prior_review_access=true` とすることを禁じている。残り138件についても、別々の独立レビューが実際に完成した証跡をこの実査では確認できていない。**単一DCの記録を2回分に複製したり、レビューID・実施日時・独立性宣誓・権利者・原典比較を捏造して機械的PASSを得ない**。そのため、2つのJSONは未作成のまま保持する。

### legalCheckedと再判定

- `sm2-5y-r10-hyg-04` は前回確認で `law_related=true` かつ `legal_checked=null`。DC-112の内容PASSだけでは生成元に対する法令確認メタデータの更新を自動認可したことにはならない。生成元の該当箇所への証跡付き反映、正規再生成、SHA/PIN更新、strict export実測が残る。
- 現時点の内容一次判定HOLDは0、権利運用HOLDも0。一方、**ゲートが要求する二重独立証跡・個別機械可読権利証跡は未充足**。これは内容HOLDの数と混同しない。
- **Q0 BLOCKED（証跡JSON未充足、法令メタデータ要修復）→Q1 BLOCKED（Q0未通過）**。ゲート定義は弱体化しない。
- App Review申請・TestFlight新規配信・公開設定変更は実施しない。


## 2026-11-22 JSON実体作成・R40取り込みの再判定（最新）

- 二重チェックの機械可読移植：`HM2_INDEPENDENT_DOUBLE_CHECK_178.json` を178/178行作成。DC原票から5肢判断・肢別理由を178行抽出。review1=A69＋B69＋R40 40、review2=DC178。R40原票のGit blob `031d14b24686c7f4294dab6df08a289763c55e13` を発見後、40件の逐肢暫定判断を追加（最終JSON更新commit `fc4f8c166560b780053e530523e0ab6362fe3891`）。
- **R40原票自身の最終結論は、内容整合40/40の暫定判定だが、法令施行版・公式本文逐肢の正式PASS0/40、HOLD40**。この区別をJSONに保存。異なる原票Git blobがあることと独立性・現行SHA一致の実証は同義ではない。
- 権利の機械可読移植：`HM2_RIGHTS_CLEARANCE_300.json` を300/300行作成（commit `f829bb8b0b88c974d047618ee9bd292bc99e405b`）。C運用最終PASS300を`cleared=true`として明記したが、原票から個別権利者・具体的license/exceptionの一対一対応が確定できていないため、権利者はnullのまま。**許諾主体を捏造してゲートを通さない**。
- スキーマ静的検査：review行178/178、二つのpass欄178/178（中身の不足あり）、現行bank SHAを各レビューの個別照合で確証した行0/178、`approved_after_reconciliation` 0/178、権利権利者空欄300/300。この時点でゲートの`--enforce`がPASSする条件を満たしていない。
- 法令メタデータ：配布bankを再解析し、`law_related=true && !legal_checked` は **`sm2-5y-r10-hyg-04` 1問のみ**。生成元・bank・PINの一括更新を試みたが、GitHub更新ツールの安全チェックにより最初の生成元変更が拒否されたため、部分変更を防ぐため後続更新も未実施。残件1。更新コミットなし。
- 実行環境からGitHubへのDNS解決が失敗し、現時点ではリポジトリをローカル取得してPython `--enforce` を実測できていない。**ゲートの実測結果を捏造しない**。現行ファイルのスキーマ静的解析では確実にFAIL。合格判定はしない。
- **Q0 BLOCKED、Q1 BLOCKED**。App Review提出・TestFlight配信・公開設定変更なし。


## 2026-11-22 R40正式成果物受領後・Q0/Q1再判定

- R40作成コミット `446444b76a93cf069b055b355a859f6933cad8ea` の実在をGitHubで確認。原票：`HM2_Q0_INDEPENDENT_R40_20261122.md`、Git blob `031d14b24686c7f4294dab6df08a289763c55e13`。
- R40は作業として40/40問・200/200肢を完了、既存正答との明白な矛盾0、**公式原典逐肢正式PASS0/40・正式HOLD40/40**。原票がこの留保を明記しているため、形式上二つのレビュー欄があることだけで最終承認に変更しない。
- `HM2_INDEPENDENT_DOUBLE_CHECK_178.json`：R40 40行のステータスを「レビュー作業完了、公式原典HOLD」に変更し、原票ファイル名・commit SHA・Git blob・集計情報を付加。更新コミット `87d8f29d3b80ae8a335f0028df3d29f328959c19`。178行と独立DC 178件の取り込みは維持。
- `HM2_RIGHTS_CLEARANCE_300.json`：権利運用300/300は維持。ただし個別権利者属性の未確定箇所など、厳格スキーマ上の未充足は解消していない。
- `sm2-5y-r10-hyg-04` の `legal_checked` 欠落1件は前回の更新拒否後も残る。生成元・bank・pinを実測一致のまま維持し、証拠なしの一括承認は行わない。
- Q0代替条件自体は変更なし。**Q0 BLOCKED（R40公式原典HOLD40、二重証跡と権利JSONの未充足、法令メタデータ欠落）／Q1 BLOCKED（Q0未通過）**。
- 今回はGitHub上のJSONと監査台帳の更新であり、ローカルPython `--enforce` 実行・GHA再実行を完了したとの主張はしない。現行スキーマでは依然FAILとなる。
- App Review提出・TestFlight新規配信なし。


## 2026-11-22 証跡JSONスキーマ修復・再判定（最終追記）

- 現行release bankのSHA-256は `4a49b2bbdef30f1d99b721629e3309443b96565476c2dfd817a912ee88558bdc`。readinessのPINと一致。従来 `434de86a...` は旧bank版。対象 `sm2-5y-r10-hyg-04` の `legal_checked=2026-11-22` を現行bankで確認、法令関連のnull残0。生成元 `hm2-source-precision-v1.js` のガード付きパッチは `3b7a5735...` で反映済み。
- `HM2_INDEPENDENT_DOUBLE_CHECK_178.json` の178行・356レビュー欄に `applicable_on`（現行設問の基準日を明記し、個別法令施行日の実証とは区別）、現行bank SHA、各原票から独立に計算した64桁SHA-256を登録。R40原票の最新版SHA-256 `58ef0d42bfb0e7c96d292fff07e5a95dee6c6db61fbf7aa1d5684eee3752185c`、DC `99cbd7aba3d4866fb88da57925bc54fa652cd04e56baa4658e9788f2a1758981`、A `ab4cddb72e8b3501749ada4cc83d7a8f41923c772d8de2ed559458d89971245a`、B `086671135eda160cbd3607d870f101fc0c68553e04f2f27efa67c48d04f04899`。各SHAは取得したUTF-8原票のバイト相当を使う実測計算で、Git blob SHA-1とは区別する。レビュー対象bankの旧版と現行版の差は法令メタデータ1項目である。
- R40原票には後続で正式の厚労省原典照合結果が追記され、**公式原典・内容PASS40/40・200肢、HOLD0**に更新されている。R40/ DCの現行五肢文字列と正誤が双方一致した40問は `approved_after_reconciliation` に更新（commit `b6214771c24d01b2493a3f30da57edb48b672c76`）。全改正附則の通史照合を保証するものではない。
- A/Bの138問のpass1については、原票が確認できない独立性宣誓 `performed_without_prior_review_access=true` と肢別5件を**創作して埋めていない**。pass1は該当2項目未充足、最終照合も保留138問。
- `HM2_RIGHTS_CLEARANCE_300.json` の `rights_holder` に、自作設問の制作主体 `ALLSUNDAY1122` を300件追記。ただし掲載元の法令・出版物・画像等の第三者権利者を所有するという意味ではない。権利運用判定300/300と個別権利の法的保証を区別する。
- 現行スキーマの静的再現により残りの形式エラーは **138×3=414件見込み**：A/Bの独立性宣誓138、五肢選択肢証跡138、最終照合未承認138。SHA不一致0、artifact digest形式エラー0、権利JSONの必須項目不足0、法令関連legalChecked欠落0。**これは実際のPython `--enforce` ローカル実行ではなく同一条件に基づく予測値。**
- Q0はA/Bの第1レビュー証跡未完のためBLOCKED、Q1もBLOCKED。ゲート弱体化なし、App Review提出・TestFlight配信なし。


## 2026-11-22 P1a/P1b実JSON統合・再判定

- 実在する独立pass1ファイルを取得：`HM2_PASS1_A_20261122.json`（69問、実ファイルSHA-256 `6188a1677cd3c39ca51d111e5e70dea55d413c2aab6a6e3410fd6dadf328eb14`）、`HM2_PASS1_B_20261122.json`（69問、実ファイルSHA-256 `75a9df0c6bc72f2c5feb35c08ff0ac085a31466f8d281e9653c038b5f1f3683d`）。
- 両原票に各69問×5肢の判定と理由、正式のレビュー属性が記録されている。これらを`HM2_INDEPENDENT_DOUBLE_CHECK_178.json`の該当138問pass1として統合。DC pass2とは138問すべて5肢のtext・correctが一致。R40の40問も一致。更新commit `ae9215f8a2b1c878f2b59fa7c92d8552e1b1a023`。
- **重要**：P1a自身の`note`と69件のpassに「先行レビューを含む統合証拠JSONを閲覧した」と明記され、`performed_without_prior_review_access:false`。そのためA69問は、内容が一致しても独立証跡と正式照合を承認できない。pass1の`false`を変更せず、`HOLD_PASS1_A_INDEPENDENCE_UNPROVEN`のまま。P1b69問は`true`の証跡あり、DCと一致するため`approved_after_reconciliation`に変更。
- 現状は`approved_after_reconciliation` **109/178**（R40 40＋P1b 69）、正式HOLD **69/178**（P1a 69）。権利JSONは300/300の機械的必須欄を維持。
- ゲートスクリプトと同項目の静的照合による`--enforce`予測：`PASS1_INDEPENDENCE_ATTESTATION_MISSING` **69件**と`RECONCILIATION_REQUIRED` **69件**、合計 **138件**（R40・B・権利等に他の予期しない差異がない前提）。この集計はPythonの実行ログではなく、既存JSONのフィールド再検査からの予測である。
- **Q0 BLOCKED / Q1 BLOCKED**。理由はA69問の独立性要件未充足であり、P1aの否定的な自己申告を上書きしない。ゲート要件の変更、App Review、TestFlightは実施していない。


## 2026-11-22 P1c 69問差替え統合・Q0/Q1判定

- `HM2_PASS1_C_20261122.json` の69問を読み取り、P1aの69問に対応するID、現行bankの各5肢本文・正答位置、およびDC pass2の5肢正誤と照合。**69/69問・345/345肢一致、独立性申告true 69/69、必須レビュー属性69/69**。P1c原票の説明は「先行Aの対象IDのみ取得し、先行判定・理由を参照しない」。内容確認の有無や実際の独立性は原票に依拠し、機械検査のみで現実の独立性を保証しない。
- 原票の実SHA-256（UTF-8内容）`c115837f8dd733b416bd0b6b1efd5184bfa00fef076dab850a2739ed27fdc287`、Git blob `2b1a91940c2c33a3a78e3b8973110b6105d8027d`をpass1各行に記録。P1aによるレビューをP1cへ置換しても、旧P1aの独立性が承認されたという扱いにはしない。
- `HM2_INDEPENDENT_DOUBLE_CHECK_178.json` の最終`approved_after_reconciliation` **178/178**、HOLD **0/178**（R40 40＋P1b69＋P1c69）。統合コミット `085a66887855623240f6506a17712dd49c851281`。
- 取得したデータによるゲートスキーマ同等の静的照合：独立性宣誓・レビュー属性・5肢照合・実SHA長形式・レビュー差異チェック・権利300件の必須属性・非公式表示いずれもエラー **0件見込み**。法令関係`legal_checked`のnull残0。bankとレビュー・権利のbank SHAは整合。**Python `scripts/hm2_alternative_q0_gate.py --enforce`の実行ログではない**（GitHubコネクタによる読み取りとJavaScript静的照合）。
- **Q0：ユーザー代替基準の「機械的証跡ゲート」についてPASS見込み。ただし実行ログと原典根拠の独立した真偽確認を未取得のため、運用上は最終PASS確定保留／CONDITIONAL**。権利の運用300/300は第三者原典ライセンスを包括保証するものではない。
- **Q1：BLOCKED／未再実測**。Q0正式実行の確認、canonical再生成・回帰テスト・strict exportの現行HEADでの実行を要する。過去の成功実績を新HEADの成功と混同しない。
- App Review提出、新規TestFlight配信なし。Q0条件を弱める変更なし。
