# 看護師国家試験｜必修150問 専門チャット → 統括 引継ぎ

更新日: 2026-08-14

## 最終状態

**標準手順 v2.5 を再確認済み。問題データのcanonical正本ルールは継続し、必修150問の統合後canonical監査はPASSを維持する。**

v2.5で追加・優先された `NO_PROGRESS｜処理停滞・自己復旧ループ v2.0` を以後の運用規則として適用する。局所commit、transport chunk、同一状態の再取得だけでは進展扱いにせず、正常実行中の外部jobは `WAIT_EXTERNAL` として無意味に再実行しない。

作業用バッチ・`required-150`内の補正ファイル・旧監査結果は生成元／監査証跡であり、最終問題データの正本ではない。必修問題の最終正本は次の3ファイルとする。

- `kangoshi-sprint/product-content/questions/exam-115/required.json`
- `kangoshi-sprint/product-content/questions/exam-114/required.json`
- `kangoshi-sprint/product-content/questions/exam-113/required.json`

最終監査結果:

- `kangoshi-sprint/product-content/required-150/canonical-audit.json`
- canonical初回PASS結果コミット: `cd901b5763cfa3c7645cfdbe07af5c44b3e34695`
- GitHub Actions: `Kangoshi Required Canonical Audit`
- v2.5再確認時の最新自動再監査: run #40 / head `4ae097f4aa5ce6d1cf0cda64ef058e8f61fc5693` / SUCCESS
- run #40後のHEAD `53a63eb98557747f2911e43aca058c0efaa1f121` は状況設定監査ファイルのみの変更で、必修canonical・必修生成元への変更なし

## canonical監査結果

- 必修: 50問×3回＝150問
- 公式正答不整合: 0
- source answer token不整合: 0
- 解説欠損: 0
- 根拠URL欠損: 0
- evidenceCheckedDate欠損: 0
- 権利根拠欠損: 0
- 出典欠損: 0
- 大分類／小分類欠損: 0
- dynamic evidence pending: 0
- 本文完全重複: 0
- 高類似候補: 0
- 通常解放候補: 136
- 隔離ユニーク: 14

隔離内訳は図版依存8問、公式採点特例6問、専門確認2問。重複があるため合計ユニーク14問。

## canonical化で修正した事項

1. 公式PDF照合済み本文補正18件をcanonicalへ適用。
2. 解説・一次根拠を150/150へ統合。
3. `K115-PM001` / `K115-PM002` が2つの作業バッチへ重複登録されていることをcanonical初回監査で検出。冗長な `022-K115-PM001-PM005-verified.json` を削除し、一意化後に再監査PASS。
4. `K114-AM002` は厚生労働省の生命表定義を2026-08-14に再確認し、dynamic evidenceをverifiedへ更新。
5. `K113-PM004` は厚生労働省の身体拘束ゼロ関連一次資料を2026-08-14に再確認し、dynamic evidenceをverifiedへ更新。
6. 図版だけで構成される選択肢について、文字選択肢を新規作成しない。media依存として隔離し、validatorでも文字選択肢欠損を誤FAILにしない。

## 統括が守るrelease gate

1. `releaseEligible=false` の14問を通常出題・模試・復習へ解放しない。
2. 第113回の公式採点特例6問を通常の1問1点ロジックで上書きしない。特に `K113-PM021` は公式採点除外であり、独自正答を設定しない。
3. 図版依存8問は、図版の権利・表示・対応肢監査が完了してから解除可否を判断する。
4. 専門確認2問 `K115-PM025` / `K113-PM025` は公式正答を保持し、現行知識との区別を確定してから解除する。
5. canonicalまたはその生成元を変更した場合は、旧バッチPASSを流用せず `Kangoshi Required Canonical Audit` を再発火し、`canonical-audit.json` のPASSを確認する。
6. 外部workflowが正常に `queued` / `in_progress` の場合は同一runを再実行せず `WAIT_EXTERNAL` とし、別の独立作業を先に進める。

## final gate

最終ゲートは以下のworkflow／validatorを使用する。

- `.github/workflows/kangoshi-required-canonical.yml`
- `kangoshi-sprint/product-content/build_required_canonical.py`
- `kangoshi-sprint/product-content/apply_required_canonical_overrides.py`
- `kangoshi-sprint/product-content/validate_required_canonical_v2.py`

`validate_required_150.py` や旧バッチ単位のPASSは、過去の診断・監査証跡としてのみ扱い、v2.5の最終PASS判定には使用しない。

## 編集禁止を維持した領域

- 一般390問
- 状況設定180問
- 共通UI
- app本体
- StoreKit
- 模試エンジン
- `automation/learning-sprint-question-pipeline/` 配下の共通validator

本チャットは上記共通領域を変更していない。
