# X-01 出典個別照合 — 第1バッチ（2026-11-11）

ブランチ: `audit/hm2-quality-20261110`。
対象: 調査開始時に `release-questions.json` の `source_url=https://www.exam.or.jp/lckohyo/` に該当する **127問**から、配布JSONの配列順で先頭10問を選定。

## 修正対象と直接根拠

| ID | 設問の焦点 | 差替後の直接資料 | 照合結果 |
|---|---|---|---|
| `sm2-demo-011` | 偽陽性率・偽陰性率 | [厚労省・スクリーニングとしての健診資料（p.7、感度・特異度）](https://www.mhlw.go.jp/file/05-Shingikai-10601000-Daijinkanboukouseikagakuka-Kouseikagakuka/0000104585.pdf) | 偽陽性率＝1－特異度、偽陰性率＝1－感度。95/950＝10%、10/50＝20% |
| `sm2-demo-012` | カンピロバクター食中毒 | [厚労省・カンピロバクター食中毒Q&A](https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/shokuhin/syokuchu/campylobacterqa.html) | 原因食品・菌による感染／発症を説明。「食品で産生済みの毒素だけを摂る型」の記述は誤り |
| `sm2-demo-013` | 成人胸骨圧迫の位置 | [消防庁・応急手当WEB講習](https://www.fdma.go.jp/relocation/kyukyukikaku/oukyu/05kobetsu/01/05_01_14.html) | 胸骨の下半分（胸の真ん中）が圧迫位置。「上半分」は誤り |
| `sm2-demo-016` | 副子による骨折部固定 | [消防庁・わたしの防災サバイバル手帳（応急手当編、p.37）](https://www.fdma.go.jp/relocation/syobodan/item/upload/tetyou2025.pdf) | 副子は骨折部の上下の関節より長くし、動きを抑える |
| `sm2-demo-017` | 心筋梗塞と心筋壊死 | [米国NIH/NHLBI・Heart Attack](https://www.nhlbi.nih.gov/health/heart-attack) | 心筋への血流遮断が持続すると心筋細胞が死滅し得る |
| `sm2-demo-018` | 腰部保護ベルトの一律強制 | [厚労省・職場における腰痛予防対策の推進について](https://www.mhlw.go.jp/web/t_doc?dataId=00tb9484&dataType=1&pageNo=1) | 個人ごとの効果を確認して適否を判断。一律使用は指針に反する |
| `sm2-demo-019` | 在室人数・CO₂必要換気量 | [労働安全衛生総合研究所・換気について](https://www.jniosh.johas.go.jp/publication/mail_mag/2021/153-column-1.html) | 定常CO₂収支の式を確認。600×(1000−400)×10⁻⁶÷0.018＝20人 |
| `sm2-demo-020` | 加齢・必要照度・グレア | [American Optometric Association・Adult Vision](https://www.aoa.org/healthy-eyes/eye-health-for-life/adult-vision-41-to-60-years-of-age) | 加齢に伴う必要な光量の増加と、まぶしさの問題を説明 |
| `sm2-demo-021` | 網膜の杆体・錐体 | [American Academy of Ophthalmology・Night Vision](https://www.aao.org/eye-health/anatomy/night-vision) | 杆体は暗所視、錐体は明所の色覚に関与 |
| `sm2-demo-022` | 小腸の絨毛・微絨毛 | [MSDマニュアル家庭版・小腸](https://www.msdmanuals.com/ja-jp/home/03-%E6%B6%88%E5%8C%96%E5%99%A8%E7%B3%BB%E3%81%AE%E7%97%85%E6%B0%97/%E6%B6%88%E5%8C%96%E5%99%A8%E7%B3%BB%E3%81%AE%E7%94%9F%E7%89%A9%E5%AD%A6/%E5%B0%8F%E8%85%B8) | 絨毛・微絨毛が吸収面積を増加させる |

本バッチでは、問題文・選択肢・正答・解説は変更せず、出典URLのみ10件を差替えた。文献の全選択肢への逐語的対応や原本の発行主体による正式な独立査読の完了は、この出典照合作業単独では保証しない。

## 生成元と配布JSONの整合

- 生成元: `apps/sanitary-manager-2/audit-fixes.js` に `HM2_X01_EXAM_LIST_DIRECT_SOURCE_BATCH01_20261111` を追記。ID・現在の設問・正答肢・旧または新URLを厳密照合してから `sourceUrl` のみ置換。
- 生成元修正コミット: `dd0354ca064d6ed79d3aba4a56d88375fcdfc600`。
- 当初の配布JSONの旧出典参照: **127件**。
- 生成スクリプト18本を依存順にJavaScript環境で実行: **PASS、300問**。
- 当初配布JSONとの差分（`question`、`choices`、`correct_index`、`explanation`、`source_url` を全300問照合）: **今回の10 IDの `source_url` のみ**。他290問はこれらの項目が一致。
- 配布JSON更新を試みた時点で、ブランチ先端のJSONが別途更新済みであることを検出（競合のため二重更新は未実施）。改めて取得した配布JSONの旧出典参照数は**117件**、対象10 IDのURLはすべて今回の修正内容に一致。
- **競合検出後の最終確認**: 18本の生成スクリプトを再取得・再実行し、現行配布JSONと**全300問・全22出力フィールドが完全一致（差異0件）**。再構成・既存JSONの同期は確認できた。
- 配布JSONの先行更新コミットIDと更新主体の特定は未了。誤ってこのセッションの更新として報告しない。
- Nodeの `export-audit-data.cjs` 全ゲート、独立レビュー178件の解除、App Store公開条件は本作業のPASSに含まれない。

## 進捗・引き継ぎ

- **X-01 試験協会一覧参照127問: 第1バッチ10問対応、残117問**。
- 次の配列順は `sm2-demo-023` 以降。最新版JSONからなお旧URLを参照するIDを固定して、同様に出題内容に直結する原典を選ぶこと。汎用索引へのリンク差替えのみでは完了扱いにしない。
- X-03生成再現性とX-01出典照合、独立レビュー178問の公開ゲートは別管理とする。
