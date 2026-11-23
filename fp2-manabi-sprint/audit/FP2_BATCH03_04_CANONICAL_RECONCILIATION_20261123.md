# FP2｜Batch03・Batch04統合およびFAIL2問修正証跡（2026-11-23 JST）

## 正本・監査対象
- `audit/FP2_RECOVERED_180_INDEPENDENT_BATCH03_30_PLUS_FAIL2_20261123.md`: 新規30問 PASS29 / HOLD1、旧FAIL2問は修正後の独立PASS2
- `audit/FP2_RECOVERED_180_INDEPENDENT_BATCH04_30_20261123.md`: 新規30問 PASS26 / FAIL2 / HOLD2
- `questions/draft/fp2-recovered-180-fulltext-20261123.json`: 復旧180問、現在の内容監査ステータスを全件同期
- `questions/canonical/approved-questions-20261123.json`: 先行独立再監査15問と復旧PASS107問、合計122問を内容監査PASSとして隔離登録。公開承認はゼロ。

## 最新件数（回収180問の内訳）
| 判定 | 問数 | 備考 |
| --- | ---: | --- |
| PASS | 107 | Batch01 24 + Batch02 26 + Batch03 新規29 + 旧FAIL是正PASS2 + Batch04 26 |
| FAIL | 2 | 2025-05問36、問39。修正済みだが再独立監査未了 |
| HOLD | 11 | Batch01 4 / Batch02 4 / Batch03 1 / Batch04 2 |
| 未監査 | 60 | 独立監査台帳の個別判定なし |
| 合計 | **180** | 重複IDなし |

加えて2026-11-23の独立再監査で先行15問がPASS。現在のcanonicalは122件。これは内容監査の承認であり本番公開承認を意味しない。

## FAIL修正・原則
### fp2-2025-05-gakka-036
- 前：『給与収入がいくら高額であっても原則として確定申告は不要』という誤った一般化。
- 後：1か所の給与1,500万円、所定の年末調整済み・他に申告を要する所得なしという本問の**限定条件**で申告不要。ただし給与収入2,000万円超は確定申告が必要。②同族会社役員の賃貸料、③第二給与25万円、④申告期間は原則2/16～3/15を説明。
- 設問・4選択肢・正答①は変更なし。解説とQ0証拠を更新、修正前説明を `correction_prior` に保存。
- 国税庁No.1900 https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1900.htm
- 判定：FAIL_CORRECTED_REAUDIT_PENDING。**PASSとはしない**。

### fp2-2025-05-gakka-039
- 前：選択肢③『課税売上高と給与等支払額が両方1000万円超なら課税事業者』まで誤肢扱いし、①を『より基本的な誤り』とする一意性を損なう解説。
- 後：①の『個人の基準期間は前年』のみ不適切で、正しくは原則前々年。③は両指標1000万円超なら課税で適切。特定期間は課税売上高**に代えて**給与等支払額で判定可能であることを説明し、『一方だけが超過すれば必ず課税』とは断定しない。
- 設問・4選択肢・正答①は変更なし。修正前解説を `correction_prior` に保存。
- 国税庁 消費税基本通達1-5-23 https://www.nta.go.jp/law/tsutatsu/kihon/shohi/01/05.htm
- 判定：FAIL_CORRECTED_REAUDIT_PENDING。**PASSとはしない**。

## 整合検査と停止条件
- 正規バンク122問（先行15＋回収107）いずれも各自の独立監査証拠パスに紐づく。
- 復旧ドラフト180問のステータス内訳もPASS107 / FAIL2 / HOLD11 / 未監査60に同期。
- 回収PASSの `modified` 判定が完了していない26問は、改変状態未確認のまま維持し、公開クリアには加えない。既知の81問は個別加工判定済み。
- App UI のJSON接続による内容PASS122件の読込を想定するが、実機/E2Eの動作とUI Master v2.1完全準拠は未検証。
- Q0（権利・法令適用/実機表示）、Q1（更新後全体回帰）、Q3〜Q5、Apple Store掲載・App Privacy・IAP・署名ビルド・TestFlightなど未完了。
- **厳密な公開承認0件、SUBMISSION_READY=NO、PR #5717 Draft維持。App Review提出禁止。**
