# 看護師国家試験｜学びスプリント 統括・3班編集境界

更新日: 2026-08-09

## 目的

開発連番#3 看護師国家試験｜学びスプリントを、A 必修150問、B 一般390問、C 状況設定180問の3作業チャットで並行処理し、統括チャットが最終的に720問・UI・模試・課金・リリースへ統合する。

GitHub `main` を現在値の正本とし、過去チャットの数値は監査結果と一致する場合のみ採用する。

## ループ原則

変更 → 対応品質ループ起動 → 監査 → FAIL箇所修正 → 再監査 → PASSまで反復 → 次工程。

一度PASSした監査でも対象データが変更された時点でPASSを失効し、対応する監査を再発火する。

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

## 3班が編集してはいけない共通ファイル

以下は統括チャットだけが編集する。

- `kangoshi-sprint/product-content/enriched-draft/**`
- `kangoshi-sprint/product-content/manifest.json`
- `kangoshi-sprint/product-content/enrichment-trigger.json`
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
- 720/720 L3完了後にメディア権利監査・専門監査を統合する。
- 専門監査前の問題は製品データへ解放しない。
- 240問模試は各回240問が実際に解放可能になった場合のみ完成扱いする。
- Golden Master v2.1にUIを統合する。
- 模試エンジン、StoreKit 2、課金監査、リリース監査、TestFlight準備を担当する。
- Notion正本をGitHubの監査結果へ同期する。

## 現在のゲート

2026-08-09時点の直近確定監査は L3 102/720、`pass=false`、`releaseAllowed=false`。その後に第115回午後の追加バッチがmainへ積まれているため、統括がチェックポイント監査を再発火して収束させる。

全3班がPASSし、720問統合監査・権利監査・専門監査がPASSするまで、製品版全体を完成扱いしない。
