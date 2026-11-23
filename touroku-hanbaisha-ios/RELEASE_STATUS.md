# 登録販売者｜学びスプリント RELEASE_STATUS

更新：2026-11-23 JST

**本番申請判定: BLOCKED**（App Review未提出）

## 今回の進捗

| 検証項目 | 実績 | 状態 |
|---|---:|---|
| 公式出典PDF個別URL | 5年度×3件＝15件 | URL確認済み |
| 利用規約 | 関西広域連合サイト利用ルール（2024-03-29制定・政府標準利用規約2.0準拠） | 商用利用、複製、公衆送信、加工の一般許可確認済み |
| 公式正答索引 | 2022〜2026年度 120件ずつ、計600件 | GitHub保存・読戻し件数照合済み |
| 単一正答が存在する問題の索引 | 599件 | 初回転記済み、独立二重照合待ち |
| 2023年度問90 | 1件 | 公式不適切問題：「解なし」・全受験者正解、模試の分母除外 |
| 問題文・選択肢の逐語取込 | **0/600件（アプリ統合）** | 不適切問90のみ別ファイルに原文転記・確認済み |
| 問題文・図表・正答の一体監査 | **0/600件** | 未実施 |
| PDFバイナリ取得／SHA-256照合 | **0/15件** | 未実施 |
| アプリ統合／iOSビルド／TestFlight | 未実施 | 未完了 |

## 一次資料と成果物

- 公式公開ページ：https://www.kouiki-kansai.jp/koikirengo/jisijimu/shikakumenkyo/touroku/7607.html
- 利用規約：https://www.kouiki-kansai.jp/site/221.html
- URL台帳：`touroku-hanbaisha-sprint/official-kansai/SOURCES_2022_2026.json`
- 正答索引：`touroku-hanbaisha-sprint/official-kansai/ANSWERS_{2022,2023,2024,2025,2026}_OFFICIAL.json`
- 法務・不適切問題監査：`touroku-hanbaisha-sprint/official-kansai/LICENSE_AND_AUDIT_20261123.md`

## ライセンス上の必須条件

各問題に実施年度・問番号・関西広域連合・原典PDF URLを表示する。加工時は別途その旨を明記し、独自解説が公式解説でないことを区別する。第三者著作物（ある場合）を個別確認する。東京都・神奈川県・青森県の実施回は使用しない。公式の当時正答は保持し、現行法令との差は独立注記。

## 次の優先実装

1. PDF全15件のバイナリ取得とSHA-256固定、図表も含む原文600問の転記。
2. 問題文・選択肢・表・図・正答を原典と突合し、2023年問90の特例を含めた二重監査。
3. 600問のアプリ統合と各問出典表示、モバイルUI検証。
4. Notion v2.8と申請手順の本文照合、CI・TestFlight・App Store情報整合。

Apple固定識別子: Bundle `com.allsunday1122.tourokuhanbaisha`、ASC `6802119268`、Version `1.0.0`。2FA・契約・実機・本審査最終送信以外のユーザー確認は不要。

**注意**：正答索引600件は問題本文600問の収録・監査が終わったことを意味しない。旧360問の合格結果を流用して申請PASSとしてはならない。

## 個別転記証跡

- 2023年度問90の公式告知記載の設問・5肢を `official-kansai/QUESTION_2023_Q090_INVALID.json` に保存。正式バンクへの統合は未実施のため、アプリ収録済み件数に算入しない。


## 2026年度（令和8年度）120問・取得と初期データ化（2026-11-23）

- **公式問題PDF前半・後半とも取得成功**。各51ページ。GitHub Actionsが実際のPDFバイナリを取得しSHA-256を記録。
  - 前半: 475,075 bytes / SHA-256 `02d32c72af83a8df143389ab251469f289a25bae2200107eaa4653e323af327a`
  - 後半: 448,716 bytes / SHA-256 `9d6a73071c1edfaa3d57d7ec18d04da882dbd4f1ea083d1f2e08f496d1f775a5`
- PDFテキストから問1〜60・問61〜120の120設問境界を連番で取得。公式2026年度正答索引120件との番号・正答対応は構造チェックPASS。
- `touroku-hanbaisha-sprint/official-kansai/QUESTIONS_2026_RAW_STAGING.json`: 120問のPDF抽出テキスト・公式正答・原典URL・該当PDFページを保持。
- `touroku-hanbaisha-sprint/official-kansai/QUESTIONS_2026_APP_CANDIDATE.json`: スマホUI用に`question`/`choices[5]`/`answer`を全120問分生成。選択肢認識は縦5行97件・1行組合せ23件。120問とも5選択肢・一意ID・正答位置（0〜4）・非空テキストの構造検査PASS。
- `touroku-hanbaisha-sprint/official-kansai/PDF_SHA256_2026.json`: 原典2件の取得URL・サイズ・ハッシュ。
- `extract_2026.py`／`build_2026_app_candidate.py`／`.github/workflows/touhan-2026-extract.yml`: 再取得・抽出・候補化の再現パイプラインをGitHubに保存。最初の自動生成コミット：`676993777be3eca6352a642b903d808b8dffc0e9`。
- PDF原本のテキストにはルビが独立行に分かれる部分、表組み、印刷用ページが存在。自動的な5選択肢分離と正答紐付けは**逐語・視覚監査の合格を意味しない**。120問の独立目視監査は未完了で、候補各問は`verbatimCertified=false`・`needsVisualReview=true`・`renderReady=false`。
- 既存独自360問は変更せず。**2026年度の公式問題はアプリ本番バンクに0/120問統合、候補ファイルとして120/120問GitHub保存済み**。本番申請判定は引き続き**BLOCKED**。

## 次工程

1. 120問の原本ページと候補JSONを一問ずつ視覚照合（表、ルビ、選択肢、正答、原典出典）。問題ごとにPASS・FAIL・HOLDを記録。
2. PASSのみを公開用バンクに移し、アプリで実際に読み込む経路、法令時点の注記、出典・加工表示を追加してテスト。
3. 同じパイプラインを2022〜2025年度へ拡張。ただし正式公開用への採用は年度ごとの監査後。


## 2022〜2025年度・480問パイプライン（2026-11-23）

- 2026年度の手法を `official-kansai/extract_year.py` / `build_year_app_candidate.py` に一般化。
- `.github/workflows/touhan-2022-2025-extract.yml`: 4年度を別々の matrix job として取得・抽出・検査・コミットする。1年度の失敗で他年度の成功を隠さない。main push の競合を想定しリベース再試行。
- 原典は `SOURCES_2022_2026.json` の関西広域連合公式・各年前後半PDFのみ。選択肢は4肢または5肢に対応し、抽出失敗の問題は `UNPARSED_HOLD` として候補に保持（正式公開不可）。
- 2023年度問90は `answer=null` / `officialStatus=OFFICIALLY_INVALID_ALL_CANDIDATES_CORRECT` / `excludeFromAccuracyDenominator=true` / `scoringPolicy=ALL_CANDIDATES_CORRECT_NO_STANDARD_GRADING` を必須検査。
- 各年度ごとに `QUESTIONS_<year>_RAW_STAGING.json`、`QUESTIONS_<year>_APP_CANDIDATE.json`、`PDF_SHA256_<year>.json` の計3ファイルをGitHubへ書く設計。正答索引との1〜120問対応・2PDFのハッシュ・未監査のフラグをCIで判定。
- **現時点の読戻し確認：2022〜2025年度の候補JSONおよびPDF SHA記録はGitHubで未確認（0/480問・0/8 PDF）。** ワークフローは実装・保存済みだが、成功実行ログおよび成果コミットの証拠がない。実行成功として計上しない。
- 2026年度の候補120問は従前どおりステージング、公式5回600問の正式本番収録は0問で変わらない。

**リリース判定：BLOCKED。** 原典PDFの取得・抽出に加え、年度別120問の正答と選択肢の精密な目視監査が引き続き必要。
