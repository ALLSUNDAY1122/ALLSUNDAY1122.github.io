# 登録販売者｜収束モード試験運用

実施日: 2026-08-14

このファイルは標準手順を変更せず、このチャットだけで「発見→修正→GitHub保存→対象再監査→完了固定」を試験運用するための固定リスト。

## ルール

- GitHubへcommitされていない修正は進捗に数えない。
- 既知FAILを閉じるまで新しい全体監査を開始しない。
- 対象再監査がPASSした問題は完了固定し、後続バッチで再調査しない。ただし対象問題自体を後から変更した場合のみPASSを失効させる。
- 全既知FAILを閉じた後に限り、360問統合監査を1回実行する。

## Batch 1｜既知FAILの収束

### PASS・完了固定

- RS26-065: プラセボ効果の重複を廃止。サリドマイド訴訟へ独立論点化。commit `141537cbe1d64163ca4db14985719d224a84c40f`
- RS26-074: 無菌性髄膜炎の明らかすぎる誤答肢を重大副作用の近接概念へ変更。commit `801a9adaac3d708ea78312de0218893add03760b`
- RS26-075: 間質性肺炎の明らかすぎる誤答肢を重大副作用の近接概念へ変更。同commit
- RS26-082: 乗物酔い防止薬の明らかすぎる誤答肢を近接した副作用候補へ変更。commit `07385733c8a41187004f62cb507aeedeac3b42fa`
- RS26-116: 副作用等報告の重複を廃止。安全性速報（ブルーレター）へ独立論点化。commit `f2494626bf75add56f8a7cde17fa6e343ae160f1`
- RS26-117: 救済制度の重複を廃止。医薬品・医療機器等安全性情報へ独立論点化。同commit
- RS26-118: 重複論点を廃止。PMDAホームページの安全性情報へ独立論点化。同commit
- RS26-119: 更新確認の重複を廃止。PMDAメディナビへ独立論点化。同commit
- RS26-120: 受診勧奨の重複を廃止。製造販売業者等からの安全性情報提供へ独立論点化。同commit

### 既に現行GitHubで修正済みだったため再修正しない

- RS26-109: 指定濫用防止医薬品の確認事項
- RS26-110: 18歳未満への販売時の追加確認
- RS26-114: 旧・緊急安全性情報の複数正解問題は既に「してはいけないこと」へ置換済み

## Batch 1一次根拠

- 厚生労働省「試験問題の作成に関する手引き」令和8年4月一部改訂
- 指定濫用防止医薬品の販売等について（令和7年12月26日）
- 指定濫用防止医薬品の数量告示の適用について（令和8年2月13日、令和8年5月1日適用）

## Batch 2｜R2/R3自動生成240問の実体化・直接重複収束

### R2 canonical 120問

- `questions/exam-2/chapter-1.json`：20問。直接重複修正 commit `d79ce6ecc7a1a47b91de67d2bc705f470d2b5a87`
- `questions/exam-2/chapter-2.json`：20問。直接重複修正 commit `758d53e5d29dd269cacbec372d5705ae7e7fba8e`
- `questions/exam-2/chapter-3.json`：40問。直接重複修正 commit `01b17f5b6dfd8c892c56fed11f2d8ab84782eab1`
- `questions/exam-2/chapter-4.json`：20問。R1基本制度問題との直接重複を廃止し、許可更新・構造設備・勤務体制・事故報告・手順書・配置販売体制へ差替え。commit `59aff724956aaca91bb98262dd8d768a909dd1b8`
- `questions/exam-2/chapter-5.json`：20問。R1安全性情報の名称当てとの直接重複を廃止し、救済給付・対象外・個人輸入・安全対策詳細へ差替え。commit `67aadaf2c79496b3464b7b1f36578ec3d57c7f07`

### R3 canonical 120問

- `questions/exam-3/chapter-1.json`：20問。症例・販売判断型。設計逸脱3問を事例判断へ修正。commit `bde92ca77e8cc47dfa1b85cf237b7e6f5a4df617`
- `questions/exam-3/chapter-2.json`：20問。薬物動態・剤形・重大副作用・既往歴を事例判断型で作成。設計逸脱2問を修正。commit `98e157460f0d82991a77f33fe30590f3635fd0b6`
- `questions/exam-3/chapter-3.json`：40問。重複服用・受診勧奨・既往歴・長期連用・誤使用の販売判断型。commit `91973135ca1cecdef65fb60cfa96a1b4f02c3489`
- `questions/exam-3/chapter-4.json`：20問。法規の事例判断型。commit `2e5ca7947676835285cd209d4ef82c1fbc02e2ae`
- `questions/exam-3/chapter-5.json`：20問。適正使用・安全対策の事例判断型。commit `a4705fa1f94ef5668864794943487d8384aa2aa8`

### 高リスク法規・救済制度の一次資料照合

2026-08-15に現行一次資料で再確認し、実質的な誤答は0件。

- 医薬品販売業許可：6年更新を確認。
- 店舗販売業の構造設備：おおむね13.2㎡以上、通常陳列・交付場所60ルクス以上を確認。
- 店舗販売業：要指導・第一類販売時間は常時薬剤師、第二類・第三類販売時間は常時薬剤師または登録販売者を確認。
- 配置販売業：一般用医薬品を配置する専門家の勤務時間総和1/2以上、第一類配置販売の薬剤師勤務時間総和1/2以上を確認。
- 指定濫用防止医薬品：2026-05-01施行。年齢、他薬使用状況、18歳未満の場合の氏名、他店等での購入状況、大容量・複数購入時の理由、適正使用確認等を確認。
- 指定濫用防止医薬品販売等手順書の作成義務を確認。
- 医薬品副作用被害救済制度：1980-05-01以降、7種類の給付、障害年金18歳以上、障害児養育年金18歳未満を養育する者を確認。
- 救済給付の支給可否は、厚生労働大臣の医学・薬学的判定結果をもとにPMDAが決定することを確認。TH-R2-5-002の「PMDAが支給を決定」は正答として成立するため変更せず、手続上の精密注記のみ残す。

一次根拠：
- https://www.mhlw.go.jp/web/t_doc?dataId=81004000&dataType=0
- https://www.mhlw.go.jp/web/t_doc?dataId=81009000&dataType=0
- https://www.mhlw.go.jp/web/t_doc?dataId=81011000&dataType=0
- https://www.mhlw.go.jp/web/t_doc?dataId=00tc9728&dataType=1&pageNo=1
- https://www.mhlw.go.jp/web/t_doc?dataId=81006000&dataType=0&pageNo=9
- https://www.pmda.go.jp/relief-services/adr-sufferers/0011.html
- https://www.pmda.go.jp/relief-services/adr-sufferers/0007.html
- https://www.pmda.go.jp/relief-services/adr-sufferers/0026.html

### CI

R2 canonical構造検査をGitHub Actions定義へ追加済み。commit `4db4cf84232b316cdb77ab5cc16692a73dfd17f5`。combined statusではActions check runを確認できていないため、CI成功とは記録しない。R3追加のCI更新はGitHub側の安全制限でブロックされたため、同一操作を反復せず保留。

## 次バッチ

R2/R3の既知直接重複と高リスク法規監査は収束。次は、公開版 `app-v06.js` が旧 `buildVariant()` 自動生成を使っている既知FAILを修正し、canonical R1/R2/R3の実データを読み込むv0.7へ置換する。公開版を切り替えた後にのみ、360問統合監査を1回実行する。
