# HM2 production-readiness 最新版再確認（2026-11-22 12:54 JST）

## 対象と実測
- リポジトリ：`ALLSUNDAY1122/ALLSUNDAY1122.github.io` / branch `fix/hm2-priority123-regression-20261122`
- 最新確認の配布データ：`ios/health-manager-2/release-questions.json`、**Git blob `4ecbfea81e3a453aa6bf60e4647d880abf821c09`**
- **ファイル本体の SHA-256 `434de86ab795d369a1ef52f16a0cf57cab7054b72f6aac952aa7805fb3872177`**（605819 bytes）
- `scripts/hm2_submission_readiness.py` の `PIN` を上記に更新、**commit `b13e5aac5e5b5dbfcbbf0cf54437ff9a122c62f2`**。旧PIN `60e9be2037efd4e840decf75e097232d32cd3d1be3bb99464707439c46e9cad1` は前のbank用であり更新が必要だった。
- 使用したSHA-256 JavaScript実装を`abc`の既知SHA-256テストベクトルで検査PASS。
- 生成側22JS（`q1..q12`、`difficulty-patch-v5`、`audit-patch-v2/v3/v4`、`audit-fixes`、`question-order-v1`、`hm2-source-precision-v1`、`hm2-c-replacements-v1`、`hm2-c-remaining-13-v1`、`hm2-source-evidence-v2`）をGitHubから取得し、正規ロード順にJavaScript実行・正規exportのフィールド順でJSON文字列化。**生成300問と現行配布JSONがバイト一致（差分0）**。
- `difficulty-patch-v5` あり／なしの双方で300問を生成し、`export-canonical-snapshot.cjs`の比較対象8フィールド（question/choices/answer/quick/explanation/topic/sourceUrl/baselineDate）のドリフト **0**。法令内容固定の17テスト項目は**17/17 PASS**。
- `apps/sanitary-manager-2/gm2.js` 内の『5年分相当』表記を確認。必要な追加修正なし。
- `sm2-demo-001/002/003` は配布JSONで `legal_checked=2026-11-22`、生成元でも`legalChecked`設定を確認。**ただし `sm2-5y-r10-hyg-04` は最新B系列の再監査状態で `law_related=true` かつ `legal_checked=null`**。当該問を根拠なしに承認しない。厳格exportの`HM2_RELEASE_REVIEW_BLOCKED`により停止する見込みだが、これは期待される内容未承認であり、readinessでは`submission_blockers`に分類する設計。

## GHA技術失敗の扱い
- 技術原因`UNREVIEWED_BANK_SHA`：**本体SHAとPIN一致を実測、原因解消**。
- 技術原因`CANONICAL_REGENERATION_FAILED`：**GitHubの現行22生成元JSを実行し、配布JSONとバイト一致を実測、原因解消**。
- `STRICT_EXPORT_UNEXPECTED_FAILURE`：まだNode CLI本体をGHAで直接再実行できておらず、再確認未完。`sm2-5y-r10-hyg-04`の法令承認欠落による`HM2_RELEASE_REVIEW_BLOCKED`は設計どおりのブロッカーとして残す。
- GitHub connectorのcommit status APIはpin更新commitのstatus一覧0件、PR連動workflow run一覧0件。後者はPR起動のみを返すため、**GHAのpush実行不存在を示すものではない**。最新`hm2-production-readiness.yml`の実runレポート`technical_errors: []`は今回取得できない。**GHA green/technical_errors 0実測は未確認**。前回失敗原因のコードレベル解消確認と区別する。

## Q0代替基準と公開制限
- C担当の最終段階記録を正本として、差し替え16/16問は権利・出典の**内部運用PASS**、既存284問と合計して**権利カテゴリの内部運用最終判定300/300 PASS**。外部法律専門家の実名判定不要。これを法的非侵害の保証とは表現しない。
- 独立二重チェックは新設DCセッション`HM2_Q0_INDEPENDENT_DC_20261122.md`のみ正本として採用。**30/178問PASS、残148問**。旧bankに固定した証跡と最新bankの内容一致判定を要する。
- **Q0 BLOCKED / Q1 BLOCKED**。未承認問題を公開候補へ変更しない。App Review提出・TestFlight配信は禁止、実施していない。
