# 追加演習B 修正バッチ5 — 最終7問（2026-11-11）

## 結果
- ブランチ: `fix/hm1-practice-b-reaudit-20261110`
- 今回対象: **Q37, Q38, Q39, Q40, Q41, Q42, Q44（7問）**。
- 修正済みのオーバーライドは **累計44/44問**、未修正データ0問。
- 全7問のstem、5選択肢、正答index、short、detail、出典、修正履歴を更新。
- 既存37件のオーバーライド、基本132問、追加A/C、HM2正本の変更は行わない構成。

## 再設計内容
| 問 | 修正後の測定対象 | 解説に含めた事項 |
|---|---|---|
| Q37 | 一回換気量500mLと毎分12回から毎分換気量6Lを計算 | 毎分換気量と肺胞換気量を区別、誤算選択肢の説明 |
| Q38 | TV0.5L、IRV2.5L、ERV1.0L、RV1.2Lから肺活量4.0Lを計算 | 肺活量に残気量を含めないこと、全肺気量との違い |
| Q39 | 延髄・橋の呼吸リズム調節と呼吸筋への運動出力 | 化学受容器からの入力との区別 |
| Q40 | 動脈血CO₂分圧上昇時の換気反応 | 化学受容系、pH・O₂などの関与 |
| Q41 | 原尿と最終尿量の違いの理由 | 濾過・再吸収・分泌、体液・電解質調節 |
| Q42 | ネフロン・腎小体・糸球体・ボーマン嚢・尿細管の構成 | 器官と機能単位の階層差、Q43との違い |
| Q44 | 尿細管再吸収と分泌の物質移動の方向 | 全量再吸収ではないこと、抗利尿ホルモンとの関係 |

## 出典（事実照合用。文章・図表・設問の転載なし）
- Q37・Q38: OpenStax Anatomy and Physiology 2e §22.3 https://openstax.org/books/anatomy-and-physiology-2e/pages/22-3-the-process-of-breathing
- Q39・Q40: NIH NHLBI How Your Body Controls Breathing https://www.nhlbi.nih.gov/health/lungs/body-controls-breathing
- Q41・Q44: NIH NIDDK Your Kidneys & How They Work https://www.niddk.nih.gov/health-information/kidney-disease/kidneys-how-they-work
- Q42: OpenStax Biology 2e §41.2 https://openstax.org/books/biology-2e/pages/41-2-the-kidneys-and-osmoregulatory-organs

## 検査と制限
- `apply-content-overrides.cjs` の期待ID一覧を44問へ更新。
- `test-b-revisions-20261110.cjs` の期待適用件数を44問・未変更件数を220問へ更新。再生成264問、ID・5肢・正答一意性（構造）、原版との差分、再生成決定性、改ざん入力の拒否、HTML埋め込み往復検査を実行する仕様。
- `.github/workflows/hm1-practice-b-revisions.yml` を追加し、指定ブランチへのpushでNode 22と上記の再生成テストを実行するCIを登録。
- **GitHubのcommit statusおよびPRトリガーのworkflow一覧からテスト結果を確認できていない。Node実行PASS、再生成264問PASSとは宣言しない。** 実際のテスト結果はGitHub Actionsログで確認する必要がある。
- 問題の選択肢一意性に関する構造検査と意味上の一意性判定は別。独立再監査・権利・実機・リリース判定は未完了。
- mainへのマージ、TestFlight・App Review提出、アプリ配信は未実施。
