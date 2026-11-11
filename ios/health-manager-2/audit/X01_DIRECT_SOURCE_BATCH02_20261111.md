# 第二種衛生管理者 横断監査X-01 第2バッチ — 2026-11-11

対象ブランチ: `audit/hm2-quality-20261110`。第1バッチ済み10問の後、現行JSONで試験協会の公表一覧 `https://www.exam.or.jp/lckohyo/` を参照していた**次の10問**を抽出。今回の作業対象は固定ID `sm2-demo-023`, `sm2-demo-024`, `sm2-demo-025`, `sm2-demo-026`, `sm2-demo-027`, `sm2-demo-028`, `sm2-demo-029`, `sm2-demo-030`, `sm2-r7o-014`, `sm2-r7o-016`。

## 個別出典照合

| ID | 論点 | 差替えた直接根拠資料 | 内容照合 |
|---|---|---|---|
| `sm2-demo-023` | 中枢神経核／末梢神経節 | [脳科学辞典（神経節）](https://bsd.neuroinf.jp/w/index.php?title=%E7%A5%9E%E7%B5%8C%E7%AF%80) | 中枢＝神経核、末梢＝神経節の用語区別 |
| `sm2-demo-024` | 肝臓の合成・解毒 | [MSDマニュアル プロフェッショナル版（肝臓の構造および機能）](https://www.msdmanuals.com/ja-jp/professional/02-%E8%82%9D%E8%83%86%E9%81%93%E7%96%BE%E6%82%A3/%E8%82%9D%E7%96%BE%E6%82%A3%E3%82%92%E6%9C%89%E3%81%99%E3%82%8B%E6%82%A3%E8%80%85%E3%81%B8%E3%81%AE%E3%82%A2%E3%83%97%E3%83%AD%E3%83%BC%E3%83%81/%E8%82%9D%E8%87%93%E3%81%AE%E6%A7%8B%E9%80%A0%E3%81%8A%E3%82%88%E3%81%B3%E6%A9%9F%E8%83%BD) | 肝臓は尿素・凝固因子・脂質等の代謝に関与、ヘモグロビンの主な合成臓器ではない |
| `sm2-demo-025` | 腎尿細管の再吸収 | [MSDマニュアル家庭版（腎臓）](https://www.msdmanuals.com/ja-jp/home/05-%E8%85%8E%E8%87%93%E3%81%A8%E5%B0%BF%E8%B7%AF%E3%81%AE%E7%97%85%E6%B0%97/%E8%85%8E%E8%87%93%E3%81%A8%E5%B0%BF%E8%B7%AF%E3%81%AE%E7%94%9F%E7%89%A9%E5%AD%A6/%E8%85%8E%E8%87%93) | ナトリウム等の電解質・水の再吸収と血中への回帰 |
| `sm2-demo-026` | A型の抗B抗体 | [日本赤十字社 兵庫県赤十字血液センター（血液型について）](https://www.bs.jrc.or.jp/kk/hyogo/donation/m2_02_01_00_bloodtype.html) | A型赤血球のA抗原／血清中の抗B抗体 |
| `sm2-demo-027` | 暗順応 | [人間生活工学研究センター（暗順応の計測）](https://www.hql.jp/database/cat/senior/funcdb2000/%E8%A8%88%E6%B8%AC%E3%83%87%E3%83%BC%E3%82%BF/%E6%9A%97%E9%A0%86%E5%BF%9C) | 明るい所から暗い所へ移る際の視覚順応 |
| `sm2-demo-028` | 不感蒸泄 | [MSDマニュアル プロフェッショナル版（水とナトリウムの平衡）](https://www.msdmanuals.com/ja-jp/professional/10-%E5%86%85%E5%88%86%E6%B3%8C%E7%96%BE%E6%82%A3%E3%81%A8%E4%BB%A3%E8%AC%9D%E6%80%A7%E7%96%BE%E6%82%A3/%E6%B0%B4%E4%BB%A3%E8%AC%9D/%E6%B0%B4%E3%81%A8%E3%83%8A%E3%83%88%E3%83%AA%E3%82%A6%E3%83%A0%E3%81%AE%E5%B9%B3%E8%A1%A1) | 皮膚および肺からの不感蒸泄があるため『呼気だけ』は誤り |
| `sm2-demo-029` | 体液性免疫 | [MSDマニュアル家庭版（主な原発性免疫不全症）](https://www.msdmanuals.com/ja-jp/home/multimedia/table/%E4%B8%BB%E3%81%AA%E5%8E%9F%E7%99%BA%E6%80%A7%E5%85%8D%E7%96%AB%E4%B8%8D%E5%85%A8%E7%97%87) | 液性免疫はB細胞と抗体産生に関係する |
| `sm2-demo-030` | 老人性難聴 | [MSDマニュアル家庭版（加齢による耳鼻咽喉への影響）](https://www.msdmanuals.com/ja-jp/home/19-%E8%80%B3-%E9%BC%BB-%E3%81%AE%E3%81%A9%E3%81%AE%E7%97%85%E6%B0%97/%E8%80%B3-%E9%BC%BB-%E3%81%AE%E3%81%A9%E3%81%AE%E7%94%9F%E7%89%A9%E5%AD%A6/%E5%8A%A0%E9%BD%A2%E3%81%AB%E3%82%88%E3%82%8B%E8%80%B3-%E9%BC%BB-%E3%81%AE%E3%81%A9%E3%81%B8%E3%81%AE%E5%BD%B1%E9%9F%BF) | 高音域から聴こえにくくなるため『低い周波数から』は誤り |
| `sm2-r7o-014` | メンタルヘルス4つのケア | [厚生労働省 東京労働局（健康の保持増進）](https://jsite.mhlw.go.jp/tokyo-roudoukyoku/hourei_seido_tetsuzuki/anzen_eisei/ae-kenkouhoji.html) | ラインによるケアは管理監督者の相談対応・職場環境改善 |
| `sm2-r7o-016` | 細菌性食中毒の3原則 | [厚生労働省（家庭での食中毒予防）](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/shokuhin/syokuchu/01_00008.html) | つけない・増やさない・やっつける：室温放置回避・冷却・加熱 |

対象10問では設問・選択肢・正答位置・解説を変更せず、`sourceUrl` → 配布用 `source_url` の出典情報だけ差替えた。資料選定は各設問の正誤判定の直接根拠を優先した。複合問題の全誤答肢を逐語的に個別検証する作業や独立専門家レビューの完了を意味しない。

## 生成・配布データ整合の実測

- 生成元コード修正: `apps/sanitary-manager-2/audit-fixes.js` に `HM2_X01_EXAM_LIST_DIRECT_SOURCE_BATCH02_20261111` を追加。**修正コミット `1d66821e7be63c29648bb78baabbec6d6034bbaf`**。
- 修正ガード: 対象ID、既存問題文、正答肢文字列、旧/新出典URLを照合し、予期しない入力では停止。変更は `q.sourceUrl=f.url` のみ。
- 生成スクリプト18本（`q1.js`〜`q12.js`、難易度パッチ、`audit-patch-v2/v3/v4.js`、`audit-fixes.js`、`question-order-v1.js`）を順にJavaScript実行: **PASS、300問**。
- `export-audit-data-core.cjs` に合わせて22フィールドの配布形式に変換し、最新 `release-questions.json` 300問をIDと全22フィールドで比較: **差異0件**。対象外290問、問題文・選択肢・正答・解説にも差異なし。
- 編集当初のJSONには旧URLが117件。生成元の修正コミット後、**配布JSONが別の並行更新によって既に新しい10件のURLを反映した状態になった**ため、二重更新は行わず再取得して照合した。比較時の配布JSON blob SHA: `afdaae2193ac391f38214df9b1869667c59bf8ca`。
- 最新配布JSONの試験協会旧一覧参照: **107問**。今回の10 IDの新出典は配布JSON側にも反映済み。
- このセッションがJSONを直接書き換えたとの主張はしない。更新主体と配布JSON更新コミットIDは未特定。
- Node CLI `export-audit-data.cjs` の全公開ゲート終了は未実行。生成本体はスクリプト実行と配布形式比較で検証済みだが、独立レビュー状態照合178問のゲートは別管理。

## 進捗と次の範囲

- X-01：開始時の試験協会公表一覧参照**127問**のうち、第1バッチ10件＋第2バッチ10件＝**20件対応、残107件**。
- 次は `release-questions.json` の `source_url=https://www.exam.or.jp/lckohyo/` に一致する残存107問の配列先頭から約10問を固定して対応。現行JSON基準で次は `sm2-r7o-017` 以降が候補。
- X-01の出典個別照合は、X-03の生成再現性PASSおよび独立レビュー178問のリリース状態ゲートとは別の管理項目とする。
