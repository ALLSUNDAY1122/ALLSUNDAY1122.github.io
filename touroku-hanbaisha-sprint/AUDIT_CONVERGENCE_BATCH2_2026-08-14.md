# 登録販売者｜収束モード試験運用 Batch 2

基準日: 2026-08-14

## 目的
旧 v0.6 の R2/R3 自動変換240問を独立問題へ置換する。標準手順そのものは変更せず、この案件だけで「既知FAIL固定 → 実ファイル修正 → 対象再監査 → 完了固定」を試行する。

## 実体化済み候補
- R2: 120問（20/20/40/20/20）
  - `questions/exam-2/chapter-1.json`
  - `questions/exam-2/chapter-2.json`
  - `questions/exam-2/chapter-3.json`
  - `questions/exam-2/chapter-4.json`
  - `questions/exam-2/chapter-5.json`
- R3: 120問（20/20/40/20/20）
  - `questions/exam-3/chapter-1.json`
  - `questions/exam-3/chapter-2.json`
  - `questions/exam-3/chapter-3.json`
  - `questions/exam-3/chapter-4.json`
  - `questions/exam-3/chapter-5.json`

## このバッチで閉じた既知FAIL
### R2
- R1の基本知識を同じ正解根拠で繰り返していた直接重複を差し替え。
- 第4章20問を、許可更新、構造設備、勤務体制、相談体制、事故報告、手順書、配置販売体制などの詳細法規へ再設計。
- 第5章20問を、救済給付の種類・年齢区分・対象外・個人輸入・外箱表示・市販後安全対策の詳細へ再設計。
- 第1〜3章の既知直接重複を個人差、添加物、内耳、骨髄、外用薬全身移行、個別成分・副作用等へ差し替え。

### R3
- 基本知識の再掲ではなく、症例・販売判断・例外判断を中心に120問を実体化。
- 純粋な知識逆引きになっていた5問を事例・適用判断へ差し替え。

## 高リスク一次監査
現行一次資料で以下を再確認し、現時点で修正必須の不整合なし。
- 医薬品販売業許可: 6年更新
- 店舗販売業構造設備: おおむね13.2平方メートル以上、通常の医薬品陳列・交付場所60ルクス以上、換気・清潔、区画・閉鎖構造
- 店舗販売業の勤務体制: 要指導/第一類は薬剤師、第二/第三類は薬剤師または登録販売者が販売時間内に勤務
- 配置販売業の専門家勤務時間に関する2分の1基準
- 指定濫用防止医薬品: 2026-05-01施行の年齢・購入状況・多量購入理由等の確認
- 副作用被害救済: 障害年金18歳以上、障害児養育年金は18歳未満を養育する者、個人輸入医薬品は原則救済制度対象外

主な一次資料:
- https://www.mhlw.go.jp/web/t_doc?dataId=81004000&dataType=0
- https://www.mhlw.go.jp/web/t_doc?dataId=81009000&dataType=0
- https://www.mhlw.go.jp/web/t_doc?dataId=81011000&dataType=0&pageNo=1
- https://www.mhlw.go.jp/web/t_doc?dataId=00tc9728&dataType=1&pageNo=1
- https://www.mhlw.go.jp/web/t_doc?dataId=04aa4242&dataType=0&pageNo=1
- https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/iyakuhin/kojinyunyu/index.html

## 未完了・完了扱い禁止
- R2/R3の全問内容監査は未完了。候補120問ずつの作成だけでPASSとはしない。
- R1はまだcanonical JSON化されていない。
- R1/R2/R3の統合重複・高類似監査は未完了。
- GitHub ActionsのR3/クロスラウンド監査追加はGitHub連携の安全制限でブロック。CI PASSとは扱わない。
- 公開版はまだ旧 `app-v06.js` の自動変換R2/R3を使用している。ユーザー向け表示は未更新。

## 次の固定処理
1. R1 120問をcanonical JSONへ変換し、既存の修正版をそのまま保持する。
2. canonical R1/R2/R3に対して有限の統合構造監査を実施する。
3. FAILだけ修正し、PASS後に旧自動生成ロジックを廃止して v0.7 へ接続する。
4. 公開URLを確認して人間試用ゲートへ進む。
