# FP2｜全180問監査最終化・初回リリース120問固定（2026-11-23）

## 対象記録と差分統合
- Batch01〜Batch06の各30問、合計180ユニークIDの独立内容監査台帳を集計。Batch03の旧FAIL2件は修正後再監査PASSに更新。
- `audit/FP2_RECOVERED_180_HOLD13_PRIMARY_SOURCE_RESOLUTION_20261123.md` を後勝ちとしてHOLD13をPASS12/FAIL1へ更新。最終 **PASS175 / FAIL5 / HOLD0**。
- 先行15問の独立再監査PASSを追加し、canonical **190問**（回収175＋先行15）、うち初回候補 **120問（6分野各20）** と内容PASS予備 **70問**。
- canonical各問に `audit_evidence_path`, `audit_evidence_blob_sha`, `modified`, `modification_note`, `release_selected` を記録。全問 `publishable=false`。
- ドラフト全180問の最新ステータスをPASS175・修正後再監査待ちFAIL5へ同期、問題IDの重複なし。

## 分野別の初回候補（上限厳守）
| 学科分野 | 内容PASS総数 | 初回候補 | 監査済み予備 |
|---|---:|---:|---:|
| ライフプランニングと資金計画 | 35 | 20 | 15 |
| リスク管理 | 29 | 20 | 9 |
| 金融資産運用 | 32 | 20 | 12 |
| タックスプランニング | 30 | 20 | 10 |
| 不動産 | 32 | 20 | 12 |
| 相続・事業承継 | 32 | 20 | 12 |
| **合計** | **190** | **120** | **70** |

## 修正済みFAIL5件（正規バンク・初回候補には非収録）
| ID | 修正内容 | 現在の状態 |
|---|---|---|
| fp2-2025-05-gakka-036 | 給与1か所1,500万円では原則申告不要という設問条件を保持しつつ、給与収入2,000万円超は原則確定申告が必要と明示。以前の『いくら高額でも不要』を訂正。正答①維持。 | `FAIL_CORRECTED_REAUDIT_PENDING` |
| fp2-2025-05-gakka-039 | 消費税の特定期間で『売上・給与の両方1,000万円超』を誤肢扱いしていた誤解説を訂正。基準期間は前々年、③は適切、正答①維持。 | `FAIL_CORRECTED_REAUDIT_PENDING` |
| fp2-2025-01-gakka-017 | 火災保険の契約期間上限5年への変更時点を2015年10月と誤認していたものを、2022年10月以降の始期契約と訂正。正答①維持。 | `FAIL_CORRECTED_REAUDIT_PENDING` |
| fp2-2025-01-gakka-020 | 機械保険で『火災・落雷等の火災以外』という自己矛盾した解説を訂正。火災等の免責と機械的・電気的な不測事故を分離。約款による例外あり。正答③維持。 | `FAIL_CORRECTED_REAUDIT_PENDING` |
| fp2-2025-01-gakka-013 | 円換算支払特約を『受取時の換算レート固定』とする誤りを、受取時の所定日レート・為替リスク残存へ訂正。MVAの適用が商品・約款依存であることも追記。正答③維持。 | `FAIL_CORRECTED_REAUDIT_PENDING` |

各問の修正前解説・修正前判定、変更後解説、`modification_note`（解説のみの変更、原題/4肢/正答番号は変更なし）、根拠URLはドラフト `questions/draft/fp2-recovered-180-fulltext-20261123.json` に保存。独立再監査までPASSへ昇格禁止。

## modified判定と適用範囲
- すでに監査されていた回収107問と先行15問に加え、初回候補で未確定だった5問の公式PDF本文・4選択肢を追加で確認し、**初回候補120問には暫定判定のままの問題はない**。
- 全回収PASS175問のうち、実物対照・独立監査で差異を確認できるものを114問とし、残る**予備61問の `modified` は暫定分類**。`modified` 値と注記は保持するが `modification_verification=PROVISIONAL...` とし、全字・図表照合を経るまで公開許可にはしない。
- `modified=false`は原題の問題内容を維持し改行等の体裁だけ整えた分類。`modified=true`は資料の文章化、選択肢/基準の法令改正に伴う修正など。**解説だけの訂正を原題の変更と混同しない**よう FAIL5には `question_text_modified=false`, `explanation_modified=true` を別記。
- 先行15問は原作12＋公式2024-05加工3。回収PASS175の元の各試験回原典と現行法令基準日を混同しない。

## リリースとテスト
- UIアダプタは `release_selected=true` の120問だけをロード。6分野20問でなければ読み込みを拒否する。70問は正規JSON内の予備に隔離。
- `release/release-selection-120-20261123.json` は120 IDと予備70 IDを列挙し、canonical blob SHAをpin。
- ソース静的CIで、180最終判定、190正規バンク/120候補/70予備、正答0-base、重複、独立監査SHA、modified注記、バンドルWebソースSHA、JS構文を確認。
- 成功CI: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45147284570
- **Q0〜Q5全ゲートPASSではない。完全公開可能0問、App Review提出なし、PR #5717 Draft。** iOSバイナリ一致・TestFlight・実機受入・ASCプライバシー等は別途未完了。

## 参照正本
`questions/canonical/approved-questions-20261123.json` / `questions/draft/fp2-recovered-180-fulltext-20261123.json` / `release/release-selection-120-20261123.json` / `release/bundle-lock-20261123.json`。
