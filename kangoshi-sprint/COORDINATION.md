# 看護師国家試験｜学びスプリント 統括・3班編集境界

更新日: 2026-08-14
適用標準手順: AIアプリ開発 標準手順 v2.4

## 目的

開発連番#3 看護師国家試験｜学びスプリントを、A 必修150問、B 一般390問、C 状況設定180問の3作業チャットで並行処理し、統括チャットが最終的に720問・UI・模試・課金・リリースへ統合する。

GitHub `main` を現在値の正本とし、過去チャットの数値は監査結果と一致する場合のみ採用する。

## ループ原則

変更 → 対応品質ループ起動 → 監査 → FAIL箇所修正 → 再監査 → PASSまで反復 → 次工程。

一度PASSした監査でも対象データが変更された時点でPASSを失効し、対応する監査を再発火する。

### NO_PROGRESS｜処理停滞・自己復旧

同一・類似操作を繰り返しても新しい監査結果、ファイル変更、commit、PASS/FAIL確定、工程移動のいずれも得られない場合は、そのサブループを停滞と判定する。ユーザーへ「次」を要求して止まらず、次を実行する。

1. GitHub `main` とNotion正本を再取得する。
2. 既に完了済みの工程を再実行しない。
3. 停滞しているサブループだけを切り離す。
4. 方法を変更する。例: 同じチェックポイント再発火ではなくActions run/logを直接確認する。
5. 専門監査・メディア監査など隔離可能な待ち項目は並列キューへ移し、独立して進められる未完了内容を継続する。
6. 人間判断が本当に必要なゲートまで自動継続する。

専門監査待ち1問を理由に同カテゴリの未作成問題全体を停止してはならない。公式正答を保持して隔離し、他問題を先に進める。

## 2026-08-12 問題監査改訂｜canonical化

小分けバッチ・担当班内PASSは最終PASSとして流用しない。試験回、または試験回×大分類のcanonical JSONへ統合した後、そのcanonical JSONを対象に共通validatorとカテゴリ固有validatorを再実行する。統合後の件数、重複、正答、採点、解説、一次根拠、基準日、権利、隔離状態がPASSして初めてカテゴリの最終canonical PASSとする。

## 班の責任範囲

### A｜必修150問
- `category == "必修"` だけを担当。
- 独自解説、一次根拠、基準日、動的根拠、内容懸念候補を作成・監査。
- 新規バッチ: `kangoshi-sprint/product-content/explanation-batches/A-required-*.json`
- `batchId`: `A-REQUIRED-...`

### B｜一般390問
- `category == "一般"` だけを担当。
- 独自解説、一次根拠、基準日、動的根拠、内容懸念候補を作成・監査。
- 新規バッチ: `kangoshi-sprint/product-content/explanation-batches/B-general-*.json`
- `batchId`: `B-GENERAL-...`

### C｜状況設定180問
- `category == "状況設定"` だけを担当。
- 3問1症例の連続性を維持し、独自解説、一次根拠、基準日、動的根拠、症例整合、内容懸念候補を作成・監査。
- 新規バッチ: `kangoshi-sprint/product-content/explanation-batches/C-situation-*.json`
- `batchId`: `C-SITUATION-...`
- 専門確認が必要な症例は専門キューへ隔離するが、次の独立症例の作成を停止しない。

## 3班が編集してはいけない共通領域

以下は統括チャットだけが編集する。

- `kangoshi-sprint/product-content/enriched-draft/**`
- `kangoshi-sprint/product-content/manifest.json`
- `kangoshi-sprint/product-content/enrichment-trigger.json`
- `kangoshi-sprint/product-content/source-data-corrections.json`
- `kangoshi-sprint/product-content/normalize_raw_import.py`
- `kangoshi-sprint/product-content/apply_explanation_batches.py`
- `kangoshi-sprint/product-content/build_enrichment_queues.py`
- `kangoshi-sprint/product-content/validate_enrichment.py`
- `kangoshi-sprint/product-content/content-concerns.json`
- `kangoshi-sprint/product-content/questions/**`
- `kangoshi-sprint/product-content/build_*_canonical.py`
- `kangoshi-sprint/product-content/validate_*_canonical.py`
- `.github/workflows/kangoshi-*.yml`
- `kangoshi-sprint/index.html`
- `kangoshi-sprint/style.css`
- `kangoshi-sprint/app-*.js`
- `kangoshi-sprint/exam-config.js`
- `kangoshi-sprint/product-availability.js`
- 模試エンジン、課金、StoreKit 2、iOS、Privacy、申請・リリース関連ファイル

班で共通ファイルへの修正が必要と判断した場合は直接編集せず、班固有バッチまたは報告へ問題ID・理由・必要修正案を残す。

## 統括チャットの責任

- 3班のGitHub現在値を毎ループ再取得。
- 問題ID・batchId重複を0に維持。
- raw本文欠損は一次資料で確認した補正を再現可能な正規化工程へ組み込み、raw→L2→L3を再発火。
- 各カテゴリをcanonical JSONへ統合し、共通・固有validatorをPASSまで反復。
- メディア・採点例外・専門監査対象はcanonical正本から消さず、隔離状態を保持。
- 720/720 L3後にメディア権利監査・専門監査を統合。
- 240問模試は各回240問が実際に解放可能な場合のみ完成扱い。
- Golden Master v2.1へUI統合。
- 模試、StoreKit 2、課金監査、リリース監査、TestFlight準備を担当。
- Notion正本をGitHub監査結果へ同期。

## v2.4｜早期試用URL

中心体験が1経路以上成立した時点で公開試用URLを提示する。HTTP応答・主要HTML・スマートフォン向けviewportを確認し、ユーザーの初期試作品確認を経るまで「価値検証完了」としない。

試用URL: `https://allsunday1122.github.io/kangoshi-sprint/`

## v2.4｜課金・識別子

- 学びスプリントの許可価格は月額200円または買い切り800円のみ。
- 看護師国家試験は継続更新価値が大きいため、別指定がない限り月額200円を標準採用。
- StoreKit 2 `Product.displayPrice` を使用し、価格文字列を固定しない。
- verified transaction、対象Product ID一致、未取消のみ権利付与。購入復元必須。
- Bundle IDは既存値があれば変更しない。未設定ならChatGPTが決定し、人間確認ゲートにしない。
- 数値Apple IDはApp Store Connect実発行値以外を記録しない。

現在の識別子正本: `kangoshi-sprint/app-store/RELEASE_IDENTITY.json`

## 現在のゲート｜2026-08-14

- 第113回一般5問の公式PDF取込欠損は一次資料確認済み補正として `source-data-corrections.json` → `normalize_raw_import.py` に恒久反映済み。
- raw 720/720再監査: PASS。import/normalize/raw/media/common auditすべてexit 0。
- L2分類: 720 high、unclassified 0、警告32/32解決、PASS。
- 共通L3: 547/720説明済み、173 pending、動的根拠85中verified 66・pending 19。FAIL、releaseAllowed=false。
- A必修: **150/150 final canonical PASS_WITH_QUARANTINE**。各回50、正答不整合0、解説・根拠・分類・基準日欠損0、dynamic pending 0、完全重複0、高類似0。通常解放候補136・隔離14（図版8・採点特例6・専門2、重複あり）を維持。
- B一般: 担当班では390/390作成済み。一般canonical 390問は生成済みだが、第113回13問でdetail/一次根拠不足を検出しcanonical gate FAIL。内訳は図版依存8問＋修復済みraw5問。統括からB班へ差分引継ぎ済み。
- C状況設定: 30/180問、10/60症例まで内容監査済み。専門確認2問は隔離し、作成停止を解除。次カーソルはK115-PM-SC01（PM091〜093）。
- メディア権利、専門監査、模試240問、StoreKit実装、TestFlightは未PASS。

全3カテゴリの最終canonical PASS、720問L3、権利監査、専門監査がPASSするまで製品版全体を完成扱いしない。
