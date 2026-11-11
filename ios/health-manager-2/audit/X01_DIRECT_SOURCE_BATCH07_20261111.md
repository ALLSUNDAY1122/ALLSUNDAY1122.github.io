# 第二種衛生管理者 横断監査 X-01 第7バッチ（2026-11-11）

ブランチ `audit/hm2-quality-20261110`。前回の `X01_DIRECT_SOURCE_BATCH06_20261111.md` の末尾から引継ぎ、旧問題公表一覧URL残存67件の先頭10件を固定。設問の正答内容の直接根拠となる医学・生理学の個別資料へURLを変更。問題本文・選択肢・正答・解説・その他フィールドは不変。

## 個別出典の根拠照合

| ID | 根拠となる具体的な説明 | 個別出典 |
|---|---|---|
| `sm2-5y-r04-phy-04` | 運動時の心拍出量と筋血流 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK482280/) |
| `sm2-5y-r04-phy-05` | 肺静脈が左心房に流入 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK525948/) |
| `sm2-5y-r04-phy-06` | 血清は血漿よりフィブリノゲンが少ない | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK531504/) |
| `sm2-5y-r04-phy-07` | PT検査はクエン酸加血漿 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK544269/) |
| `sm2-5y-r04-phy-08` | 肺胞換気量=(500-150)×12=4.2L/分 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK493219/) |
| `sm2-5y-r04-phy-09` | 貧血では同じSaO2でもCaO2低下 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK525974/) |
| `sm2-5y-r04-phy-10` | 高二酸化炭素分圧で化学受容器刺激 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK482456/) |
| `sm2-5y-r05-phy-01` | 左心室から大動脈 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK554457/) |
| `sm2-5y-r05-phy-02` | 右心室から肺動脈 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK554457/) |
| `sm2-5y-r05-phy-03` | CO₂が肺胞へ拡散する分圧勾配 | [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK539907/) |

- `sm2-5y-r04-phy-08` は（500mL−死腔150mL）×12/分＝4,200mL/分と計算した。
- `sm2-5y-r04-phy-09` は酸素含有量の近似式（Hb×SaO2に比例）を根拠とする。SpO2と酸素含有量は同一ではない。
- `sm2-5y-r05-phy-03` は肺循環の一般説明ではなく、CO₂の肺胞・血液間分圧差に直接言及する `NBK539907` を採用した。個々の誤答肢まで独立再査読したことを意味しない。

## 変更と差分検証

1. `apps/sanitary-manager-2/audit-fixes.js` に `HM2_X01_EXAM_LIST_DIRECT_SOURCE_BATCH07_20261111` を追加。問題ID・設問文・全選択肢数・正答肢内容・旧または新URLをガードし `sourceUrl` のみ変更。初回コミット `61e5171e03dc2620fd95cce78454655459c148c3`。CO₂分圧差の直接資料へ修正したコミット `151ada2bfa842716fe77af24513043a71ab46842`。
2. 配布JSON更新時に並行処理による対象10問の先行反映を検知。追加でCO₂出典を調整し、`ios/health-manager-2/release-questions.json` にコミット `392c18bf03654b855c4d0035ee13326921791eb5`。他9問のJSON反映コミット/実行主体はこのセッションでは未特定。
3. 配布JSONの旧blob `f8e2bcd0d00091fa32e655c97e0948c5f5bc7523` と新blob `292c8abbd29e0cf5e9875498cd1590ab4fc1123a` を全300問全フィールドで比較。対象10問の `source_url` のみ計10フィールド差分、対象外290問完全一致。**限定差分PASS**。
4. 生成元パッチ10件のID・問題文・正答肢・出典URLと最新版配布JSONを静的に照合し **10/10一致（PASS）**。
5. **未確認**: Node生成スクリプトを実際に起動した再生成結果と配布JSONの全フィールド一致。静的照合は再生成検証と別物でありX-03の生成再現性PASSとはしない。独立レビュー178問の公開品質ゲートは未解除。

## 進捗・次の引き継ぎ

- X-01開始時127問。第1〜6バッチ累計60問＋今回10問＝**累計70/127問**。
- 旧試験協会一覧 `https://www.exam.or.jp/lckohyo/` 残存 **57問**（最新版JSON実測）。
- **次の開始IDは `sm2-5y-r05-phy-04`**。必ず最新版配布JSONを再取得し旧URLの残存順から約10問を固定する。
- 残る作業: 独立したNode環境で生成スクリプトの実行を確認し、全300問の再生成と配布JSONの一致を検証。X-01とX-03を混同しない。
