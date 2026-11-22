# 第二種衛生管理者 X-01 第6バッチ／直接出典照合（2026-11-11）

- ブランチ: `audit/hm2-quality-20261110`
- 引き継ぎ起点: `X01_DIRECT_SOURCE_BATCH05_20261111.md`。旧公表一覧URL残存77問の先頭10問を確定。
- 作業方針: 個別の正答を直接説明する資料を採用し、配布内容は出典URL以外変更しない。

## 個別照合

| 問題ID | 設問の直接根拠と正答との関係 | 資料 |
|---|---|---|
| `sm2-5y-r06-hyg-10` | 感度＝真陽性数÷疾病あり人数＝90/100＝90% | [出典](https://stacks.cdc.gov/view/cdc/193774) |
| `sm2-5y-r07-hyg-01` | 三次予防＝発症後の再発防止・機能回復・復職支援 | [出典](https://www.cdc.gov/mmwr/preview/mmwrhtml/00016403.htm) |
| `sm2-5y-r07-hyg-06` | 陽性的中率＝真陽性数÷検査陽性人数＝20/80＝25% | [出典](https://stacks.cdc.gov/view/cdc/198512) |
| `sm2-5y-r08-hyg-09` | 音の強さ10倍＝10 log10(10)＝10dB | [出典](https://www.osha.gov/otm/section-3-health-hazards/chapter-5) |
| `sm2-5y-r09-hyg-03` | 自由音場の点音源：距離2倍で音圧レベル約6dB低下 | [出典](https://www.osha.gov/otm/section-3-health-hazards/chapter-5) |
| `sm2-5y-r09-hyg-08` | 脊椎損傷の疑いでは不必要に動かさない | [出典](https://www.redcross.org/take-a-class/first-aid/performing-first-aid/first-aid-steps) |
| `sm2-5y-r10-hyg-06` | 水分不足・脱水により尿量低下・尿濃縮 | [出典](https://www.ncbi.nlm.nih.gov/books/NBK613065/) |
| `sm2-5y-r04-phy-01` | 高地の気圧低下によるPaO₂・Hb酸素飽和度低下 | [出典](https://www.ncbi.nlm.nih.gov/books/NBK539701/) |
| `sm2-5y-r04-phy-02` | 活動筋で酸素抽出増大→静脈血酸素含量低下・動静脈較差増大 | [出典](https://www.ncbi.nlm.nih.gov/books/NBK57139/) |
| `sm2-5y-r04-phy-03` | 心拍出量＝一回拍出量×心拍数＝70mL×70/分＝4.9L/分 | [出典](https://www.ncbi.nlm.nih.gov/books/NBK470455/) |

資料選定メモ: 感度・陽性的中率はCDCの定義、三次予防はCDCの予防段階整理、騒音2問はOSHA技術マニュアルの強さ比および距離減衰、脊椎損傷は米国赤十字の応急手当、脱水・高地・活動筋の酸素抽出・心拍出量はNCBI等の個別医学資料を根拠とした。複合選択肢の誤答肢をすべて独立に再査読したものではない。

## 変更・差分検証

1. `apps/sanitary-manager-2/audit-fixes.js` に `HM2_X01_EXAM_LIST_DIRECT_SOURCE_BATCH06_20261111` を追加（問題ID・問題文・正答肢・旧新URLを確認後に`sourceUrl`のみ置換）。生成元変更コミット `476a1c12f90707908f1151b9364ee49ea66c6b5e`。
2. 配布JSONへの書き込み時、並行更新ですでに対象10問が反映されていると判明したため上書きせず再取得。並行更新のコミットID・更新主体は未特定。
3. 旧配布JSON blob `5c20ae9ba91091b67dbc7c99b1600a019cb69bc7` と新配布JSON blob `f8e2bcd0d00091fa32e655c97e0948c5f5bc7523` の全300問をID・フィールド単位で比較。**差分は対象10問の `source_url` のみ（10フィールド）**。対象外290問および対象10問の他のフィールドに差分なし。限定差分PASS。
4. 最新の生成元パッチ10件の問題文・正答肢・URLを最新版の配布JSONへ静的突合し10/10件一致。静的整合PASS。
5. **未確認:** Node CLI / 生成スクリプト18本を実際に起動して得た再生成JSONと配布JSONとの完全一致。静的突合を再生成PASSとしない。独立レビュー178問の公開品質ゲートも未解除。

## 累計進捗と次の引き継ぎ

- X-01開始時の対象127問。第1～5バッチ計50件＋第6バッチ10件＝**累計60/127件**。
- 旧試験協会問題公表一覧URL残存 **67件**（最新配布JSONから実測）。
- **次の開始ID: `sm2-5y-r04-phy-04`**。次回は旧URL残存リストを最新版から再抽出し次の10問を固定する。
- 再生成一致は別実行環境で確認が必要。X-01の出典整備とX-03の生成再現性は別の判定として維持する。
