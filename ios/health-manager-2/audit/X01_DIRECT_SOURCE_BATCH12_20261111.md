# 第二種衛生管理者 横断監査 X-01 第12バッチ（2026-11-11）

- 対象ブランチ: `audit/hm2-quality-20261110`。
- 第11バッチ `X01_DIRECT_SOURCE_BATCH11_20261111.md` 末尾を引き継ぎ、試験協会公表一覧URLの残存17問から先頭10問 `sm2-5y-r09-phy-04`～`sm2-5y-r10-phy-03` を確定した。
- 正答を直接裏付ける個別資料へ出典URLを更新。問題文・選択肢・正答・解説・その他の項目は変更せず、分類不整合は別途課題として記録した。

## 個別出典の照合

| 問題ID | 内容の直接根拠 | 変更後URL |
|---|---|---|
| `sm2-5y-r09-phy-04` | 肺胞換気量＝（一回換気量－死腔量）×呼吸数。A=4.2L/分、B=3.0L/分 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK482501/) |
| `sm2-5y-r09-phy-05` | 肝・腎でアミノ酸などの非糖質基質からグルコースを産生する糖新生 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK541119/) |
| `sm2-5y-r09-phy-06` | 嫌気的解糖は酸素が不足しても短時間ATPを供給する | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK546695/) |
| `sm2-5y-r09-phy-07` | 酸素を最終電子受容体とするミトコンドリア酸化的リン酸化 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK553192/) |
| `sm2-5y-r09-phy-08` | 膵島β細胞のインスリンが筋・脂肪の糖取り込みを促進 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK459261/) |
| `sm2-5y-r09-phy-09` | 血圧低下による圧受容器反射・交感神経活性化で心拍数・血管抵抗を調節 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK538172/) |
| `sm2-5y-r09-phy-10` | 血小板の粘着・凝集は一次止血栓形成の基礎 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK470328/) |
| `sm2-5y-r10-phy-01` | 肝臓の胆汁生成と代謝機能（胆のうは貯蔵・濃縮） | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK542254/) |
| `sm2-5y-r10-phy-02` | 胆汁酸による乳化・ミセル形成は脂質消化吸収を補助し酵素そのものではない | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK470209/) |
| `sm2-5y-r10-phy-03` | 肺胞換気量＝（500－150）mL×20回/分＝7.0L/分 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK482501/) |

- 換気量の2問は同一の死腔・肺胞換気式から問題ごとの数値を再計算した。
- 正答内容の直接資料を採用したが、全ての誤答肢について独立医学査読を完了したという意味ではない。

## 分類メタデータの別課題

今回の対象には、現在の `topic` と問題文が一致しない問題が存在する。例：`sm2-5y-r09-phy-05` は `topic=クレアチンリン酸` だが設問は糖新生、`r09-phy-06` は嫌気的解糖で一致、`r09-phy-07` は `topic=基礎代謝` だが設問は酸化的リン酸化、`r09-phy-08` は `topic=唾液アミラーゼ` だが設問はインスリン、`r09-phy-09` は `topic=ペプシン` だが設問は圧受容器反射、`r09-phy-10` は `topic=小腸` だが設問は一次止血、`r10-phy-03` は `topic=胆汁` だが設問は肺胞換気量。今回のX-01限定変更では `topic` を編集せず、分類・品質監査の残件として引き継ぐ。

## 修正と検証

1. 生成元 `apps/sanitary-manager-2/audit-fixes.js` に `HM2_X01_EXAM_LIST_DIRECT_SOURCE_BATCH12_20261111` を追加。ID、問題文、選択肢数、正答肢内容、旧/新URLのガードを通過した場合のみ `sourceUrl` を更新。コミット **`065bc5be0e958755f741f0c7e71c8b600a5162ee`**。
2. 配布JSON `ios/health-manager-2/release-questions.json` の対象10件の `source_url` のみ変更。コミット **`da5a21bb9d881efef197545ef98c926c442cc5d5`**。
3. 更新前blob `d6703a2e389c1c13dd45eb4717edf1366fbea3ef` と更新後blob `1f16bb45d5507574b07d42f44a31e233ddad12e0` の全300問・全フィールドを比較。差分は対象10問の `source_url` だけ（10フィールド）で、他290問と対象10問のその他のフィールドは不変。**限定差分PASS**。
4. 生成元パッチの10件のID・設問文・正答肢・URLと配布JSONを静的に突合し、**10/10一致（PASS）**。
5. **未確認**：Nodeで生成スクリプト18本を実行して得られるJSONと配布JSONの全300問完全一致。今回の静的検証はX-03の実生成再現性を証明しない。独立レビュー178問の公開ゲートも未解除。

## 累計進捗と次の開始ID

- 初期対象127問。第1～11バッチ110問＋今回10問＝**累計120/127問**。
- 旧出典一覧URL `https://www.exam.or.jp/lckohyo/` の残存 **7問**（最新版配布JSONで実測）。
- **次の開始ID：`sm2-5y-r10-phy-04`**。最新版JSONから旧URL残存リストを再抽出し、最後の7問を照合する。
- 残存の `topic` と設問内容の不一致、Node実再生成未検証を明示的な引き継ぎ事項とする。
