# 新ITパスポート｜ゼロベース開発

旧 `it-passport-swipe/` とは完全に独立した新規案件です。旧コード・旧問題DB・旧Bundle ID・旧StoreKit・旧監査結果を参照・継承しません。

## 正本
- Notion: `新ITパスポート｜ゼロベース開発 正本`
- Branch: `feature/it-passport-rebuild`
- Path: `apps/it-passport-rebuild/`
- Bundle ID candidate: `jp.allsunday1122.itpassportstudy`

## Product thesis
大量の問題を並べるのではなく、IT初心者が「今日何をやるか」を迷わず、弱点を反復して本試験合格水準に近づける学習ナビゲーションを作る。

## Current exam baseline
- Syllabus: IPA ITパスポート Ver.6.5
- CBT / 120 minutes / 100 questions / 4 choices
- Strategy ~35 / Management ~20 / Technology ~45
- Pass: total >= 600/1000 and each domain >= 300/1000
- 2027 new-system IT Passport syllabus: pending as of 2026-08-25

## MVP
1. 初回診断
2. 今日の学習
3. 問題演習
4. 20秒解説＋詳しい解説
5. 苦手自動蓄積
6. 復習キュー
7. 分野別mastery
8. 100問模試
9. 学習継続表示

## Data policy
公式公開問題と独自問題は `origin_type` で分離する。各問題に `syllabus_version`, `source_url`, `source_label`, `basis_date`, `copyright_note` を持たせる。公式問題は出典を表示し、改変時は改変を明記する。
