# FP2｜300問プリフライト分類・最新ヘッドCI読戻し（2026-11-23 JST）

## 固定した対象と証拠
- Release branch: `feature/fp2-release-scope-20261123`
- Source head when checked: `38eeaee1e05831b9ff29e55e4bab2ae0db4794a9`
- 正規canonical: **312問＝公式学科過去問300問＋独自予備12問**。独立内容監査PASS312/312、公開許可0。
- 初回リリース選定：**300問（2024-05、2024-09、2025-01、2025-05、2026-05各60問／6分野各50問）**。選定正本`fp2-manabi-sprint/release/release-selection-300-20261123.json`、canonical Git Blob `03b449dbe8a848b192bd970801846b18c486b1b4`。予備12問は配布選定外。
- 旧初回120問・予備75問のpreflight、5a72059fの8/8 CIは**過去履歴**。新しい300問版の合否根拠へ流用しない。
- 300問版Simulatorの過去成功：run [45171875787](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45171875787)、commit `b00b924c2ffd5c117f78bba88d74bbeff40aab9a`。現ヘッドの署名なしビルド成功を意味しない。
- 出典：`audit/FP2_FIVE_EXAM_300_INTEGRATION_20261123.md`、`release/FP2_Q0_Q5_FINAL_GATE_20261123.md`、`RELEASE_STATUS.md`。
- GitHub `commits/38eeaee1e05831b9ff29e55e4bab2ae0db4794a9/check-runs` 実読戻し：**8ジョブ／SUCCESS 6／未完了 2／FAIL 0**（取得時点のスナップショット）。CI状態は変更され得るため、この数値を永続的なPASSとはしない。監査記録の更新コミット自身も対象ヘッドではない。

| ジョブ | 読戻し状態 | run |
|---|---|---|
| `static-and-native-simulator` | `queued/NOT_FINISHED` | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45175673423 |
| `chromium-e2e` | `completed/success` | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45175673589 |
| `static-content-and-web-shell` | `completed/success` | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45175673437 |
| `audit` | `completed/success` | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45175672522 |
| `chromium-e2e` | `completed/success` | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45175672580 |
| `migration-gate` | `completed/success` | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45175672642 |
| `static-and-native-simulator` | `queued/NOT_FINISHED` | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45175672498 |
| `static-content-and-web-shell` | `completed/success` | https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45175672446 |

## 4分類（新規300問を基準）

| 分類 | 項目 | 判定・所要証拠 |
|---|---|---|
| **AUTO-FIX** | 最新ヘッドのpreflight/CIエラー、旧120問固定値・台帳/文書の陳腐化 | 自動修正可、ただし問題文・正答・選定IDを独断で変更しない。修正した場合はソースハッシュ更新→CI再実行→ヘッドの合否証拠を固定 |
| **AUTO-FIX** | 300問Web E2E・原典ID・選定SHA・6分野×50・予備12隔離の再照合 | ソース一意性/元データ整合の機械検査は自動可能。旧120問版CIの流用は不可 |
| **BUILD-REQUIRED** | 現ヘッドunsigned iOS SimulatorのCI完了 | 最新ヘッドチェックの `queued/in_progress` をSUCCESSへ仮昇格しない。先行300問runは参考のみ |
| **BUILD-REQUIRED** | 署名済みIPA、組込300問実バイトSHA、署名/Provisioning、TestFlight配信 | 未完了。ソース/unsigned Simulator成功は署名・配布成功の代替でない。配布後の実機試験素材を確保する |
| **BUILD-REQUIRED** | サポート/プライバシーURL公開HTTP200、最終300問UI素材/署名済みビルド整合 | 技術側で検証・修正。Apple側に入力された値の最終確認はHUMAN-REQUIRED |
| **HUMAN-REQUIRED** | ASC App ID `6797228406`、Bundle ID `com.allsunday1122.fp2manabisprint`、Version `1.0.0`、Build `1`、IAPなし、App Privacy | **必ず残す**。Apple側で登録された値・申告の実物確認／責任者承認。source registry/CIのみでは済まさない |
| **HUMAN-REQUIRED** | ASC登録AppIconの原画像一致、ストア説明、スクショ、サポート/プライバシーURL | GitHub内部アイコンの一致はPASS（blob `ce0cb5bc61296d7ca2ebde213c729ae5d1e4ab9d`、SHA-256 `d456178b2a7b04f180e39b3ad62f5c194832e85aa15102bf6452751551db8033`）。Apple側の画像一致は人手確認を保持 |
| **HUMAN-REQUIRED** | 署名/TestFlight後のiPhone実機受入、利用主体・公式過去問二次利用権限、第三者図版/出典改変表示、2026-04-01法令基準・運営主体 | 利用者/権利者側の責任判断と実機証跡。技術CIだけで承認不可 |
| **FINAL-APPROVAL** | Q0〜Q5、300問公開許可、App Store Connect/実機/法的承認の全証拠、PR #5717 Draft解除/公開提出の決裁 | **未承認**。ユーザー明示許可までApp Review提出禁止。mainマージしない |

## Q0〜Q5
- Q0 **BLOCKED**：二次利用主体・公式原典/図版・改変表示・現行法適用の責任者承認。
- Q1 **CONTENT PASS 312 / SELECTED 300・RELEASE BLOCKED**：内容監査合格と公開許可は異なる。
- Q2 **CHROMIUM E2E既存PASS／現ヘッドE2E未完了／実機受入待ち**。
- Q3 **Webオフライン/JSON既存PASS／現ヘッドE2E未完了／実機Golden Master・アクセシビリティ待ち**。
- Q4 **NOT TESTED / HUMAN DEVICE ACCEPTANCE PENDING**。
- Q5 **旧300問Simulator PASS／現ヘッドCI未完了／SIGNED_IPA, TESTFLIGHT, ASC HUMAN REQUIRED**。

**最終分類：CONTENT_312_PASS / RELEASE_300_SELECTED / RESERVE_12_PASS / LATEST_HEAD_CI_PARTIAL / AUTO_FIX_AND_BUILD_REQUIRED / HUMAN_REQUIRED / FINAL_APPROVAL_PENDING / NOT_SUBMISSION_READY / NOT_SUBMITTED**。
