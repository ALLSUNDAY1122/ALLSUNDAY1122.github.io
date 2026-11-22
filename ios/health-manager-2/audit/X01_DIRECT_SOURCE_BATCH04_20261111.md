# 第二種衛生管理者 横断監査 X-01 第4バッチ（2026-11-11）

ブランチ: `audit/hm2-quality-20261110`。

## 対象と方針

試験協会の問題公表一覧 `https://www.exam.or.jp/lckohyo/` を出典としていた当初127問のうち、第1～3バッチ30問の次にあたる**10問**を対象に、設問の正答内容を直接説明する資料へ出典を差替えた。問題文・選択肢・正答・解説・そのほかのメタデータは変更しない。

## 個別根拠

| 問題ID | 監査対象 | 根拠資料 | 対応する記述・計算 |
|---|---|---|---|
| `sm2-r7o-027` | 自律神経と心拍・瞳孔・消化管 | [NCBI Bookshelf・自律神経機能表](https://www.ncbi.nlm.nih.gov/books/NBK430888/table/article-18030.table1/) | 交感神経は心拍増加・散瞳・腸管運動抑制 |
| `sm2-r7o-028` | 筋収縮とATP | [NCBI Bookshelf・Muscle Contraction](https://www.ncbi.nlm.nih.gov/sites/books/NBK537140/) | ミオシンの収縮サイクルにATP加水分解が必要。ATP再生の詳細は継続確認可能 |
| `sm2-r7o-029` | 体温調節 | [NCBI Bookshelf・Temperature Regulation](https://www.ncbi.nlm.nih.gov/books/NBK507838/) | 暑熱時の皮膚血流増加と発汗・蒸発放熱 |
| `sm2-r7o-030` | 急性ストレス反応 | [NCBI Bookshelf・Autonomic Nervous System](https://www.ncbi.nlm.nih.gov/books/NBK539845/) | 交感神経系の活性化により心拍・血圧上昇など |
| `sm2-r7a-013` | 労働衛生の3管理 | [厚労省・職場のあんぜんサイト](https://anzeninfo.mhlw.go.jp/yougo/yougo28_1.html) | 騒音源への防音囲いは有害因子を低減する作業環境管理 |
| `sm2-r7a-014` | 情報機器作業の休止 | [厚労省・令和3年改正後ガイドライン](https://www.mhlw.go.jp/web/t_doc?dataId=00tc6314&dataType=1) | 一連続作業1時間以内・10～15分休止・小休止1～2回 |
| `sm2-r7a-015` | 労働災害の強度率 | [厚労省・職場のあんぜんサイト](https://anzeninfo.mhlw.go.jp/yougo/yougo22_1.html) | 労働損失日数÷延べ実労働時間×1000＝0.5 |
| `sm2-r7a-017` | 脳梗塞と出血性脳卒中 | [国立循環器病研究センター](https://www.ncvc.go.jp/hospital/pub/knowledge/case/brain/) | 脳梗塞は血管閉塞、脳出血・くも膜下出血は血管破綻 |
| `sm2-r7a-019` | BMIと体重換算 | [厚労省e-ヘルスネット](https://kennet.mhlw.go.jp/information/information/food/e-02-001.html) | BMI22×1.60²＝56.32kg |
| `sm2-r7a-020` | 食中毒と温度管理 | [厚労省・家庭での食中毒予防](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/shokuhin/syokuchu/01_00008.html) | 菌を増やさないための冷却・短時間保存、やっつけるための加熱 |

- `sm2-r7o-028` の出典はATPと筋収縮の直接解説に対応する。クレアチンリン酸・解糖系・酸化系によるATP再合成の詳細については、より限定された生化学資料との追加照合余地がある。出典URLの置換を全知識要素の独立査読完了と混同しない。
- `sm2-r7o-030` は交感神経系の急性反応を扱う。HPA系の細部を出典のみで全選択肢検証したとは判断しない。
- 参照先は資料本体のページを選択した。法律・ガイドラインの記述と一般生理学的な説明を混同しない。

## 修正・差分検証

1. 生成元ファイル `apps/sanitary-manager-2/audit-fixes.js` に `HM2_X01_EXAM_LIST_DIRECT_SOURCE_BATCH04_20261111` を追加。旧／新出典URLに加え、対象ID・設問文・正答肢内容を確認してから `sourceUrl` のみ変更する。
2. 生成元コードコミット: **`321367fc165f6fbdab92a7b9db15db39e9122477`**。
3. 生成元18本（`q1.js`～`q12.js`、難易度パッチ、監査パッチ群、最終並べ替え）を依存順にJavaScript実行し、**300問の再構成に成功**。
4. **修正前の配布JSONとの比較:** 差分はこの10 IDの `source_url` のみ。対象外290問、対象10問の問題文・全選択肢・正答・解説の変更なし。
5. 配布JSONを同期しようとした段階で、別の並行更新がすでに対象10問を反映していることを検出。二重更新を避けて上書きせず、最新版の配布JSONを再取得した。
6. **最終再検証:** 生成スクリプト18本を再実行し、配布用マッピングの**全22フィールド・全300問の完全一致（差分0）**を確認。最終確認時の配布JSON blob SHA: `ee241c4b218b70a29d9ae37f6f9d0382d9ffa00d`。
7. 配布JSONについては今回のセッションから更新コミットを発行していない。並行更新のコミットIDと実行主体は本記録では未特定。Node CLI `export-audit-data.cjs` の公開レビュー178問ゲートの解除・正常終了は今回の検証対象外。

## 進捗・このセッションの引き継ぎ

- **X-01の開始時対象127問**
- 第1バッチ: 10問
- 第2バッチ: 10問
- 第3バッチ: 10問
- **第4バッチ（今回）: 10問**
- **累計対応40/127問、旧一覧URL残存87問**。
- **次の開始ID: `sm2-r7a-021`**。次セッションは最新版 `release-questions.json` から `source_url=https://www.exam.or.jp/lckohyo/` に一致する未対応10問を抽出して固定する。
- 論点別に、公的機関・専門学術情報のうち**直接内容を確認できる個別資料**を出典に採用。設問の数値・正答・全選択肢も必要に応じて点検し、根拠不足は未完扱いで残す。
- X-01の出典差替えはX-03の生成再現性と別項目。また独立レビュー178問の公開ゲートは残っており、X-01の進捗をもって自動的に解除しない。
