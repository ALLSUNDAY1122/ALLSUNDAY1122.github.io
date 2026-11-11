# 追加演習B 修正バッチ4（2026-11-11）

## 対象・適用結果
- ブランチ: `fix/hm1-practice-b-reaudit-20261110`
- 今回変更: **10問（Q26・Q27・Q28・Q30・Q31・Q32・Q33・Q34・Q35・Q36）**
- 修正前27問＋今回10問＝**累計37問のオーバーライドデータをコミット**
- 未修正: **Q37・Q38・Q39・Q40・Q41・Q42・Q44（7問）**
- Q29・Q43を含む修正済み27問の内容は変更なし。基本132問とA/C、HM2の正本に変更なし。
- 設問、5肢、正答index、短解説、詳細解説、出典、修正履歴を10問すべてで更新。
- 最終独立再監査と実機検証、main統合・配信は未実施。データ適用のみで教材の公開合格とはしない。

## 設問の再設計
| ID | 主な判断軸 | 解説で補足した相違点 |
|---|---|---|
| Q26 | 衛生委員会審議後の事業者の役割 | 計画策定・実施・評価・見直しを一連の活動とし、委員会の審議と事業者の責任を区別 |
| Q27 | 相談記録を業務配分に用いる際の適正な取扱い | 目的、必要性、共有範囲、管理方法、本人同意を一律要件としない留意点 |
| Q28 | 主治医の復職可能診断書を受けた事業場の判断 | 業務遂行能力の評価、復帰計画、事業者の最終決定、復職後フォロー |
| Q30 | 血圧128/78の読取り・脈圧 | 動脈圧と心室内圧の違い、収縮期・拡張期、脈圧50 |
| Q31 | 心拍80・脈拍76の差の説明 | 脈波と血流速度の違い、心拍と末梢脈拍の不一致 |
| Q32 | 組織液がリンパ管を通る経路 | 血漿・組織液・リンパの区画と静脈還流 |
| Q33 | 肺胞におけるガス交換 | 伝導気道との違い、分圧勾配・拡散 |
| Q34 | 横隔膜の動きと胸腔容積 | 収縮・下降と吸息の因果、弛緩との区別 |
| Q35 | 安静吸息時に空気が流入する圧力条件 | 肺胞内圧が大気圧より低くなる機序（Q34の筋運動と役割分離） |
| Q36 | 安静呼息と努力性呼息 | 安静時の主として受動的な機序と努力性呼息の筋活動 |

## 根拠資料（問題本文には転載せず事実照合用）
- Q26: 厚労省「労働者の心の健康の保持増進のための指針」4, https://www.mhlw.go.jp/web/t_doc?dataId=00tc1466&dataType=1&pageNo=2
- Q27: 労働安全衛生法104条および心の健康指針7, https://www.mhlw.go.jp/web/t_doc?dataId=74002000&dataType=0
- Q28: 厚労省「心の健康問題により休業した労働者の職場復帰支援の手引き」, https://www.mhlw.go.jp/bunya/roudoukijun/anzeneisei28/index.html
- Q30: 国立循環器病研究センター「高血圧」1(1)(2), https://www.ncvc.go.jp/hospital/pub/knowledge/disease/hypertension/
- Q31: OpenStax Fundamentals of Nursing 7.1, https://openstax.org/books/fundamentals-nursing/pages/7-1-indicators-of-physiologic-functioning
- Q32: NCI SEER Lymphatic system, https://seer.cancer.gov/seertools/glossary/view/546a0b99e4b0d9658329250a/
- Q33: NIH NHLBI What Breathing Does for the Body, https://www.nhlbi.nih.gov/health/lungs/breathing-benefits
- Q34〜Q36: OpenStax Anatomy and Physiology 2e 22.3, https://openstax.org/books/anatomy-and-physiology-2e/pages/22-3-the-process-of-breathing

## 構造検証・リリース制限
- オーバーライド登録37件、ID重複なし、今回対象10件の5肢・正答index・解説・出典を確認。
- 適用モジュールの期待ID一覧とテストの変更件数を37件へ更新し、227問不変の検査を追加。
- データ反映と構造テストのコード修正はGitHubへ保存済み。**Node回帰テストの実行結果は未確認**であり、PASSとは記載しない。
- 修正後264問の再生成結果と意味的独立性は、CI/ローカルテスト実行および独立再監査を要する。審査申請やTestFlight配信を行わない。
