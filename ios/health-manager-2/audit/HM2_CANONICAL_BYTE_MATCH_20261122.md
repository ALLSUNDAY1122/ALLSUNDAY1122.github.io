# HM2生成元→配布JSON再現性・SHA固定・readiness技術照合（2026-11-22）

## 実測対象
- リポジトリ：`ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- ブランチ：`fix/hm2-priority123-regression-20261122`
- 配布：`ios/health-manager-2/release-questions.json`、更新後Git blob `54aceef12cdd3391920fff7847e83948868ab4dd`
- バイト列の SHA-256：`60e9be2037efd4e840decf75e097232d32cd3d1be3bb99464707439c46e9cad1`
- 検証は GitHub Contents API で取得した**22個の生成側JSをJavaScriptエンジンで正規ロード順に実行**して行った。ローカルGit cloneもNode CLIも使っていないため、GHA Nodeの完走とは分けて記録。

## 入力と正規生成手順
1. `q1.js`～`q12.js`（12件）
2. `difficulty-patch-v5.js`
3. `audit-patch-v2.js`, `audit-patch-v3.js`, `audit-patch-v4.js`, `audit-fixes.js`
4. `question-order-v1.js`
5. `hm2-source-precision-v1.js`
6. `hm2-c-replacements-v1.js`
7. `hm2-c-remaining-13-v1.js`
8. `hm2-source-evidence-v2.js`

`window={Q_PARTS:[]}`、`localStorage`スタブ上で全スクリプトを実行し、`export-canonical-snapshot.cjs`と同じ30群・13+項目のデータ射影順および`JSON.stringify(data,null,2)+'\\n'`で出力を再構成した。

## 実行した照合（GitHub現行ファイルを再取得して確認）
|検査|実測|
|---|---|
|22JSの全件実行と300問生成|**PASS**|
|difficultyパッチあり／なしの`question,choices,answer,quick,explanation,topic,sourceUrl,baselineDate`一致|**PASS、drift 0件**|
|生成JSONとコミット済み`release-questions.json`の**全文文字列・UTF-8バイト一致**|**PASS、差分0バイト**|
|300一意ID、5肢、30群×10問、各群正答位置1～5が各2問|**PASS**|
|旧配布JSONとの差分の限定|**3問の`content_review_status`付与だけ**|
|正規化前の問題文・5肢・正答・解説の差分|**0問**|
|新bank UTF-8バイト SHA-256を計算、readiness PINと一致|**PASS**|
|SHA-256実装を既知ベクトル`abc`で検算|**PASS**|
|readinessの300問構造・178ID・StoreKit価格・PrivacyInfo定義|**PASS**|
|現行法令契約17項目と法令関連`legalChecked`欠落|**17/17 PASS、欠落0**|
|`gm2.js`に「5年分相当」の表記|**PASS**|
|非公式・専門家監修なしのアプリ、サポート、ストア記載|**PASS**|

最初の差分は以下3件のJSONの`content_review_status`であり、正規生成元では`requires-independent-subject-expert-review`だったが、旧配布JSONからは当該フィールドが脱落していた。生成元の指示に従い追加した。
- `sm2-5y-r07-phy-04`
- `sm2-5y-r10-phy-02`
- `sm2-5y-r10-phy-10`

変更コミット：bank `5ccb3a030c5da6e883cf4ae91c08e0ba8d39afd5`、readiness pin `b2ee0defd0a9340d51757f5ec37d0aa15e6dc436`。再実行に使用した一時的なGitHub内入力束ファイルは検証後 `92176e3027a1bd9084a3d45137e1129cb319c50a` で削除済み。

## readiness technical_errors と未承認の区別
- `UNREVIEWED_BANK_SHA`：再生成後bankのSHA-256とPIN一致を直接検査済み（解消確認）。
- `CANONICAL_REGENERATION_FAILED`：GitHubで取得したJSを使った同等の正規射影では**バイト一致確認済み**。ただし`node ios/health-manager-2/export-canonical-snapshot.cjs`を実際にGitHub ActionsのOS/Node上で実行した成功証跡は未取得。
- `STRICT_EXPORT_UNEXPECTED_FAILURE`：法令関連`legalChecked`欠落は0、17件のlive law contractはPASS。ただし`export-audit-data-core.cjs`の独立Q0強制検査はDCの残件があるため **`HM2_RELEASE_REVIEW_BLOCKED` による期待どおりの停止**となる設計。これはreadinessの`submission_blockers`に入れるべきであり、権利・DC承認済みとの扱いにはしない。Node strict exporterの実行ログは未取得。
- この時点で判明している技術的原因は解消したが、**GHAの最新run報告書`technical_errors: []`の実物は未取得**。GHA完走PASSとは記録しない。

## Q0監査状況（ユーザー承認の運用基準）
- Slice C第9段階の再監査：差し替え16問の正答内容PASS16/16、権利・出典の**内部運用PASS16/16**。既存284問の運用PASSと合わせ、権利カテゴリは**運用300/300 PASS**。これは法的非侵害の保証ではない。
- 独立DC正本 `HM2_Q0_INDEPENDENT_DC_20261122.md`：固定178問中30問・150肢PASS、未実施148問。以前のbankのGit blobに固定された監査なので、最新bankでは問題文・肢・解説等が変わっていないことを内容同一性として検証する必要がある。
- 残る3問の`content_review_status`は独立専門的内容レビューの未済を示す。単にバイト整合が成立してもレビュー完了とはしない。
- **Q0 BLOCKED、Q1 BLOCKED**（法令・出典・独立内容二重検査の残件）。App Review提出・TestFlight新規配信は実施しない。
