# 薬剤師国家試験｜学びスプリント 本番申請監査 2026-11-05

## 最終結果
**BLOCKED / 正式提出未実行**。ユーザー指定の品質停止条件に該当するため、本番配布用ビルドの生成・審査提出を実行しなかった。追加承認で品質要件を省略する扱いにはしない。

## 対象とApple側読戻し
- App：薬剤師国家試験｜学びスプリント
- App ID：6799753724 / Bundle：jp.allsunday1122.yakuzaishi
- source version：1.0.0 / ASC versionString：**1.0**（相違を記録。未変更）
- ASC Version ID：430ba445-fae0-4d1d-9301-95d1ea342ac7
- 最新読戻し：**2026-11-05T13:09:02.438840Z（22:09 JST）**
- Apple状態：**PREPARE_FOR_SUBMISSION**
- reviewSubmissions：**0件**。提出日時・申請IDはなし。
- Codemagic Build ID：6aebcd99f5f3c51e569a2f3e
- 既存ビルドソース：82591fe0174f26df006271cd5ba267c38a8d7735
- Apple Build番号：20261105002905 / ID：0ed211f5-60c9-4fde-adad-3ba16c1601a5
- processing：VALID / expired：false / buildAudienceType：**INTERNAL_ONLY**
- 今回の修正を含むAPP_STORE_ELIGIBLEビルド：**未生成**
- 旧202611041633はAPP_STORE_ELIGIBLEだが修正前であり、申請対象へ流用しない。
- 無料・IAPなし。ASC copyrightはnullであり、提出前の補完も残る。
- 正本：../asc-results/pharmacist-release-status-20261105-resume.json
- 読取要求はGETのみ：cb27b90f60af54f1c671a461b8ef060f792a33cf
- 読戻し保存：68a4539c504fd5aa8fc0dfdb8cb999c460108c9e

## Q0〜Q5
|Gate|判定|証拠と未了事項|
|---|---|---|
|Q0|BLOCKED|第三者4問の権利キューALL_PENDING。法令107候補の個別時点照合が未完了。原B7のID別対応表を発見できず閉鎖を証明できない|
|Q1|FAIL|source-manifest fullProblemAuditComplete=false。全1035レコードのreviewStatusは内容監査待ち。画像154問の最終目視監査待ち|
|Q2|FAIL|画像問題の汎用的な説明が残る。例P111-220は正答番号・画像照合の案内のみで反応選択の学習上の根拠説明が不足|
|Q3|NOT_TESTED|今回の修正候補について全学習フロー・保存復元・オフライン・iPhone表示・クラッシュの最終通し確認は未実施|
|Q4|BLOCKED|内容の独立レビュー、修正候補の全機能実機受入証跡が不足。ユーザーの3画面確認を全フロー合格と扱わない|
|Q5|BLOCKED|上記未解決。最新修正の本番バイナリと必須ASCメタデータの最終監査も未完了|

機械検証のPASSを医学・薬学内容の正確性、権利適合の証明に使用しない。
適用手順： [SKILL｜学びスプリント・資格学習アプリ開発 v1.0](https://app.notion.com/p/40e09c10697d81969bcee2ec627c97e9)。
明示規則「未監査問題を本番教材へ混入させない。」に基づく。

## 現在の未解決事項（旧B7の番号との対応は未確定）
1. 全問の意味・正答・解説・画像の独立内容監査が未完了。reviewStatusはpending。一方explanationReviewRequired=falseのため構造検証でPASSになる。このフラグを監査完了の証拠にしない。
2. 画像154問のreleaseStatusはasset_ready_pending_final_visual_review。全件の最終目視証跡なし。
3. 第三者由来P109-025、P109-124、P110-122、P110-140の権利確認待ち。原図を使わず再構成したことのみでクリアとしない。根拠：third-party-rights-review-queue-v1.json。
4. 法令107候補：102 PENDING_MANUAL_REVIEW、3 CURRENT_OFFICIAL_TEXT_LOCATED; EXAM_DATE_VERSION_REVIEW_PENDING、1 POST_EXAM_AMENDMENT_IDENTIFIED; ANSWER_UNCHANGED; HISTORICAL_VERSION_REVIEW_PENDING、1 P110-140旧更新要求。107は候補であり107件の誤りと断定しない。根拠：legal-review-queue-v1.json。
5. P110-140：現在ソースでは試験日2025-02-23の正答2・5を保持し、2026年改正の注記がある。環境省一次資料で2026-01-30改正・2026-04-01適用を確認。古いキューの説明更新要求は現行ソースとずれるが、試験当時の法令版および独立レビューの完了とはしない。A1はソース・旧CIの対応までは確認、特定実機での再受入は未確認。
6. 第111回問220/221：本文の錠→カプセルは既存ソースに反映済みだが、問220の併載旧処方画像に「1回1錠／1日2錠」が残っていた。今回参照・同梱生成を修正済み。既存の内部TFビルドへは未反映であり、実配信解消済みとは報告しない。
7. 問220を含む画像問題の汎用解説、全機能実機受入、旧B7の個別閉鎖証跡が残る。

一次資料：
- MHLW訂正：https://www.mhlw.go.jp/content/001677936.pdf
- 環境省改正：https://www.env.go.jp/air/osen/pc_oxidant/kijun.html
- 利用条件：https://www.mhlw.go.jp/chosakuken/
権利キューの項目を推測で許諾済みへ変更していない。

## 修正とcommit
- a693c4067f365060f4277883d5dbc92c223bc478：media manifestの問220から旧処方画像q220-1.webpを除外。反応・選択肢q220-2.webpを保持。
- 791cf62effb8b356148f2c6ec3bc1b7881c09d29：メディア再生成時の旧画像再混入防止。
- b2a05a8bca1a0e6344e5507f27b1eff9bbd2127c：教材生成時の問220/221訂正URL、P110-140法令URL、画像参照検証。
- 48e28493c95ec7aa14efea1ac62c4c2586f2e964：native教材生成で旧画像参照を拒否し、反応選択肢の存在を検証。
- b8321ca6c1e6c491f6b3f03a528a3d8678f79438：既存自動化による教材再生成。
- 17130eb00c329cadd3983c16813f4f7b9f04d243、453194d391ae0ad63b2a220284535e08de24b1e2、2e3d8149cb482b747cc375e0d75e95726aef3b17：旧Build5指定、StoreKit説明、公開可否記録を更新。
- 問題データGit blob読戻し：8a480fd27c3161241abd4a5044f3ff5b73d8e4ef。1035件、問220画像はq220-2のみ、問220/221 correction_source_urlとP110-140 legal_source_urlが保存済み。

公式画像の内容を創作・改変していない。旧重複画像を表示対象から外し、訂正済み共通文を使用する。正答・特殊採点・除外条件を変更していない。

## 実施した検証と限界
- pinned main 740bc734e8ec0743edaabc0492dd5b5ed17ccf3aの446ファイルをサイズ・Git blobハッシュ照合して取得。以後の修正は別途上記commitで識別。
- ローカルassemble_product_bank.py実行成功。想定修正以外のJSON意味差分0（assembly-diff.json=[]）。
- validate_release.pyは修正前後ともPASS・エラー/警告なし。ただし構造検証に限定。
- prepare-ios.shの教材生成PythonをWindowsの独立した新規出力先へ実行。1035レコード、採点1031、除外4、特殊採点3、画像154問・290ファイル。全レコードの正答・accepted answers・採点状態の同一性を確認。
- 新規生成先にq220-1.webpなし、q220-2.webpあり。questions.native.json SHA256：641ab87205fd451be695bd92ec3f10b3fe68c742513cc30ddd718dbf74037bcf。
- [Learning Preflight run 42032922127](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/42032922127)：48e28493c95ec7aa14efea1ac62c4c2586f2e964に対してsuccess。
- Native Preflight run42032922027はcancelled。今回修正後のNative XCTest/署名Release成功とは扱わない。
- 既存Codemagic内部ビルドはunit test・signed IPA工程成功の過去証跡あり。今回変更の検証ではない。
- 旧署名IPAの非公開artifact取得は401。独立したIPA中身の確認はできなかった。認証情報・非公開artifact URLは証跡へ保存しない。
- 今回は全操作の実機確認、スクリーンショット全端末要件、年齢質問票、ASCプライバシー全項目、レビュー連絡先の最終完了を宣言しない。

## 再開条件・人間操作
追加の提出承認待ちではない。内容監査と独立した専門レビュー、第三者4問の権利根拠確認、法令時点・画像の個別監査と記録、解説改善、修正候補の実機通し受入が必要。
必須ゲート通過後に本番対象の新規Buildを生成し、Native XCTest/Release/CI、APP_STORE_ELIGIBLE、VALID、commit照合、実機受入を確認する。ASC versionString1.0と要求1.0.0の扱い、copyright等の必須項目を最終整備して手動リリース設定で正式Submit for Reviewを実行し、Appleの提出状態・IDを読み戻す。

## 2026-11-06 追記：P109-124 第三者元統計・出典表示の部分修正

- 総務省統計局「人口推計（2022年10月1日現在）」公式HTML（https://www.stat.go.jp/data/jinsui/2022np/index.htm）で4割合 15歳未満11.6％、15–64歳59.4％、65歳以上29.0％、75歳以上15.5％を確認。年少人口指数 11.6 ÷ 59.4 × 100 ≈ 19.5 も再計算。
- 利用条件（https://www.stat.go.jp/info/riyou.html）と統計データの引用・転載案内（https://www.stat.go.jp/data/jinsui/riyou.html）でPDL1.0準拠、商用利用可能、原資料の出典と加工表示が必要なことを確認。元グラフは転載しない方針。これは個別のデータ・利用条件の確認であり、全問の著作権・内容監査PASSを意味しない。
- 元の試験問題PDFのURLと、元統計資料のURLは異なる。ネイティブモデルに任意の originalDataSourceURL を追加し、教材生成時にP109-124の元統計URLを付与。問題画面と解説画面に元統計資料を表示。Web版の当該問題にも原資料URL・加工主体の表示を追加。
- 実装commit: 9bd8a3f0bd866e72e103d5ed5fb613dd61f819d9、20059cdbbaf192599e561ff6b52a30d2b7416f15、50c51d9687ca72c97f4917ec3ac7ead3b220f327、92c5302576090aa266447bb74caa90431740b599、15c3c8bf2f8630e4bd54c08d3c6ab30d4665870a。
- 回帰テストに元統計URLのモデル保持確認を追加。Pharmacist Learning Preflight 42115375988=SUCCESS、Pharmacist v0.6 Web Validation 42115384052=SUCCESS。
- Native iOS Preflight 42115375991 はCANCELLED（再実行もCANCELLED、コンパイル成功を証明できない）。署名IPAとiPhone実機の表示確認は未実施。該当問題のゲートは「公式値・規約確認済み／表示実装済み／Native最終検証待ち」。
- 4件の第三者素材キューのうち、P109-124のみ部分的に進展。残り3件と全体Q0〜Q5は引き続き未通過。本番申請と公開用ビルド生成は行っていない。
- ASC 2026-11-06 06:29 JST 読戻し：PREPARE_FOR_SUBMISSION、reviewSubmissions=0、審査Versionに旧Build202609140032が紐付いたまま。本番用の修正反映Buildはなし。証跡：automation/asc-results/pharmacist-asc-readback-20261106-0629-r2.json。
