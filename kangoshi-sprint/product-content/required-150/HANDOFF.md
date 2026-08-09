# 看護師国家試験｜必修150問 専門チャット → 統括 引継ぎ

更新日: 2026-08-09

## 専門チャットで完了した範囲

- 第115・114・113回の必修50問×3回＝150問を対象に監査。
- 公式本文・公式正答・公式採点取扱いを照合。
- 通常140問に独自解説、ここだけ覚える、一次根拠、evidenceCheckedDateを整備。
- 隔離10問にも解説ドラフト・一次根拠・evidenceCheckedDateを整備。ただし解放不可状態を維持。
- PDF取込時の数字・語句欠損18件を `text-corrections.json` に必修専用オーバーレイとして記録。raw原本は変更していない。
- 図版依存8問、公式採点特例6問、現行知識との齟齬疑い2問を `special-cases.json` に分離。
- 必修150問専用ゲート `validate_required_150.py` を追加。共通validatorは未変更。

## 統括で必要な共通領域反映

1. 製品データ組立時、必修問題に限り `required-150/text-corrections.json` をraw本文より後、解説統合より前に適用する。
2. `required-150/special-cases.json` の隔離対象を、共通出題・模試・復習導線から無条件に解放しない。
3. 第113回の公式採点特例6問は、通常の1問1点ロジックで上書きしない。特にPM21は公式採点除外であり、独自正答を設定しない。
4. 図版依存8問は、図版の権利・表示・対応肢の監査完了後にのみ解放する。
5. 専門監査キュー2問（K115-PM025、K113-PM025）は公式正答を維持したまま、現在の臨床・薬剤情報と区別する注記を確定してから解放する。
6. 統合後に `python3 kangoshi-sprint/product-content/required-150/validate_required_150.py` を再実行し、PASSを確認する。

## 編集禁止を維持した領域

- 一般390問
- 状況設定180問
- 共通UI
- app本体
- StoreKit
- 模試エンジン
- `automation/learning-sprint-question-pipeline/` 配下の共通validator

本チャットは上記共通領域を変更していない。
