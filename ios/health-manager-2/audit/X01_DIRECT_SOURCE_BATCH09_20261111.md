# 第二種衛生管理者 横断監査 X-01 第9バッチ（2026-11-11）

- 対象ブランチ: `audit/hm2-quality-20261110`。
- 第8バッチ記録 `X01_DIRECT_SOURCE_BATCH08_20261111.md` 末尾から引継ぎ。開始時の旧一覧URL残存47問を配布JSONから実測し、先頭10問 `sm2-5y-r06-phy-04` から `sm2-5y-r07-phy-03` までを固定。
- 出典選定方針: 設問の正答肢を直接裏付ける医学・生理学資料へ置換し、その他の設問フィールドは変更しない。

## 個別根拠

| 問題ID | 正答を裏付ける資料の記述・論点 | 出典 |
|---|---|---|
| `sm2-5y-r06-phy-04` | 延髄のpre-Bötzinger complexによる呼吸リズム形成 | [資料本体](https://www.ncbi.nlm.nih.gov/books/NBK537306/) |
| `sm2-5y-r06-phy-05` | PaCO₂の変化が中枢化学受容器・換気駆動に影響 | [資料本体](https://www.ncbi.nlm.nih.gov/books/NBK482414/) |
| `sm2-5y-r06-phy-06` | 腎臓による浸透圧・電解質・酸塩基平衡調節 | [資料本体](https://www.ncbi.nlm.nih.gov/books/NBK538339/) |
| `sm2-5y-r06-phy-07` | 高浸透圧→ADH分泌→集合管AQP2・水再吸収増加 | [資料本体](https://www.ncbi.nlm.nih.gov/books/NBK544365/) |
| `sm2-5y-r06-phy-08` | 酸素を電子伝達系の最終電子受容体としてATP生成 | [資料本体](https://www.ncbi.nlm.nih.gov/books/NBK553192/) |
| `sm2-5y-r06-phy-09` | 低浸透圧→ADH抑制→腎臓からの水排泄増加 | [資料本体](https://www.ncbi.nlm.nih.gov/books/NBK544365/) |
| `sm2-5y-r06-phy-10` | 洞房結節→心房→房室結節→ヒス束・脚→プルキンエ線維 | [資料本体](https://www.ncbi.nlm.nih.gov/books/NBK594995/) |
| `sm2-5y-r07-phy-01` | アルドステロンによる遠位ネフロンNa再吸収・K排泄 | [資料本体](https://www.ncbi.nlm.nih.gov/books/NBK470339/) |
| `sm2-5y-r07-phy-02` | インスリン抵抗性によるGLUT4膜輸送の低下 | [資料本体](https://pubmed.ncbi.nlm.nih.gov/37248992/) |
| `sm2-5y-r07-phy-03` | 血小板の粘着・活性化・凝集による一次止血 | [資料本体](https://www.ncbi.nlm.nih.gov/books/NBK545263/) |

- `r06-phy-04/05` の呼吸中枢・CO₂調節は別の直接説明資料に対応。`r06-phy-07/09` は高浸透圧と低浸透圧の反対方向のADH反応を同一資料で照合。
- `r07-phy-02` はインスリン刺激のGLUT4輸送と抵抗性を論じる査読済み総説で照合。
- 出典URLを置き換えることは全誤答肢の独立医学査読が完了したことを意味しない。

## 実装・検証

1. 生成元 `apps/sanitary-manager-2/audit-fixes.js` 末尾に `HM2_X01_EXAM_LIST_DIRECT_SOURCE_BATCH09_20261111` を追加。対象ID・問題文・選択肢数（5）・正答肢文字列と旧/新URLをガードし `sourceUrl` だけ変更。生成元コミット **`cca39510389efead6fb00ac0ddb2e982f1c2c4f3`**。
2. 配布JSON `ios/health-manager-2/release-questions.json` の対象10問の `source_url` のみ同期。コミット **`536b7dc7cb4cb73e7f58ce0dba4759aaa9b35c8d`**。
3. 配布JSON変更前blob `6bedf8c1699b4c242dd67dfb5f2844796181754e` と変更後blob `00ba834da9650cbc814e37903135ff438690fa8f` を全300問、全フィールドで比較。変更は10 IDの `source_url` 各1か所のみ。他290問・対象10問のその他フィールドは不変。**限定差分PASS**。
4. 生成元パッチに固定した対象10問のID・設問・正答肢・URLを配布JSONと突合して **10/10一致（静的整合PASS）**。
5. **未確認**: Node生成スクリプト18本の実行による再生成結果と現在の配布JSONの完全一致。静的照合PASSと再生成PASSを混同しない。X-03生成再現性および独立レビュー178問の公開ゲートも今回の判定対象外。

## 累計進捗と次の開始ID

- 初期対象127問。第1〜8バッチまで80問＋今回10問＝**累計90/127問**。
- 旧URL `https://www.exam.or.jp/lckohyo/` 残存 **37問**（更新後配布JSON実測）。
- **次の開始ID: `sm2-5y-r07-phy-04`**。最新JSONの旧URL残存一覧を再取得し、次のまとまりを固定する。カイロミクロンのリンパ輸送に関しては次バッチで直接根拠 `https://www.ncbi.nlm.nih.gov/books/NBK343489/` を候補として確認する。
- 本記録の対象は `r07-phy-03` までの10問。`r07-phy-04` は未対応のまま。
