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

## 班の責任範囲

### A｜必修150問

- `category == "必修"` の問題だけを担当する。
- 独自解説、一次根拠、基準日、動的根拠、担当内の内容懸念候補を作成・監査する。
- 新規バッチは `kangoshi-sprint/product-content/explanation-batches/A-required-*.json` とする。
- `batchId` は `A-REQUIRED-...` で一意にする。

### B｜一般390問

- `category == "一般"` の問題だけを担当する。
- 独自解説、一次根拠、基準日、動的根拠、担当内の内容懸念候補を作成・監査する。
- 新規バッチは `kangoshi-sprint/product-content/explanation-batches/B-general-*.json` とする。
- `batchId` は `B-GENERAL-...` で一意にする。

### C｜状況設定180問

- `category == "状況設定"` の問題だけを担当する。
- 3問1症例の連続性を壊さず、独自解説、一次根拠、基準日、動的根拠、症例整合、担当内の内容懸念候補を作成・監査する。
- 新規バッチは `kangoshi-sprint/product-content/explanation-batches/C-situation-*.json` とする。
- `batchId` は `C-SITUATION-...` で一意にする。
- 専門確認が必要な症例は専門キューへ隔離するが、次の独立症例の作成を停止しない。

## 3班が編集してはいけない共通ファイル

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
- `.github/workflows/kangoshi-*.yml`
- `kangoshi-sprint/index.html`
- `kangoshi-sprint/style.css`
- `kangoshi-sprint/app-*.js`
- `kangoshi-sprint/exam-config.js`
- `kangoshi-sprint/product-availability.js`
- 模試エンジン、課金、StoreKit 2、iOS、Privacy、申請・リリース関連ファイル

班で共通ファイルへの修正が必要と判断した場合は、そのファイルを直接編集せず、班固有のバッチまたは報告に問題ID・理由・必要修正案を残し、統括へ引き渡す。

## 統括チャットの責任

- 3班のGitHub現在値を再取得して進捗を判定する。
- バッチ間の問題ID・batchId重複を0に保つ。
- チェックポイント単位でL3適用・監査を再発火する。
- FAILを修正し、再監査する。
- raw本文の欠損が見つかった場合、一次資料で確認した補正を再現可能な正規化工程へ組み込み、raw→分類→L3の影響ループを再発火する。
- 720/720 L3完了後にメディア権利監査・専門監査を統合する。
- 専門監査前の問題は製品データへ解放しない。
- 240問模試は各回240問が実際に解放可能になった場合のみ完成扱いする。
- Golden Master v2.1にUIを統合する。
- 模試エンジン、StoreKit 2、課金監査、リリース監査、TestFlight準備を担当する。
- Notion正本をGitHubの監査結果へ同期する。

## v2.4｜早期試用URL

中心体験が1経路以上成立しているため、GitHub Pagesの公開試用URLを維持し、HTTP応答・主要画面・スマートフォン向けviewportを確認したうえでユーザーへ明示する。ユーザーの初期試作品確認を経るまで「価値検証完了」とは扱わない。

試用URL: `https://allsunday1122.github.io/kangoshi-sprint/`

## v2.4｜課金・識別子

- 学びスプリントの許可価格は月額200円または買い切り800円のみ。
- 看護師国家試験は問題・統計・制度・ガイドラインの継続更新価値が大きいため、ユーザーから別指定がない限り **月額200円** を標準採用する。
- アプリ内価格文字列は固定せず、StoreKit 2 `Product.displayPrice` を使用する。
- verified transaction、対象Product ID一致、未取消のみ権利付与し、購入復元を実装する。
- Bundle IDは既存値があれば変更しない。未設定の場合は標準手順v2.4に従いChatGPTが決定し、ユーザー確認ゲートにしない。
- App Store Connectが発行する数値Apple IDは推測しない。

## 現在のゲート

- A必修: PASS_WITH_QUARANTINE。
- B一般: 390/390 PASS_WITH_QUARANTINE_AND_COORDINATOR_HANDOFF。
- B監査で第113回一般5問のraw取込欠損を検出したため、過去の共通raw PASSは失効。統括で公式PDF確認済み補正を正規化工程へ組み込み、raw監査を再発火中。
- C状況設定: 内容監査は途中。専門確認対象を隔離したまま、残り症例の作成を並行継続する。
- 共通L3の直近materialize済み値は102/720、`pass=false`、`releaseAllowed=false`。新しい統合監査が生成されるまで推測値へ置換しない。

全3班がPASSし、720問統合監査・権利監査・専門監査がPASSするまで、製品版全体を完成扱いしない。
