# FP2級 v1.3 UI直接比較監査

比較日: 2026-08-08  
正本: GitHub PR #4065 `feature/fp2-kakomon-coach` / `FP2_KAKOMON_COACH_v1.3.0.html`  
正本head: `cb60a00646315d02646ebe7f803e0f9799136c16`

## 結果
**PASS（資格固有差分を除く）**

## 直接踏襲したUI
- 背景 `#fdf6ef`、カード白、文字 `#231f1a`
- アクセント `#ee7d3f`、濃色 `#a8481c`、薄色 `#fdeee2`
- 18px / 14px角丸、同一シャドウ
- home-top / brand-tag / brand-title / brand-sub
- hero `.title` のサイズ・ウェイト・余白
- full-btn / emoji / txt / name / meta / count-badge
- resume-card / resume-lbl / resume-name / resume-meta
- 完答リング、課目カードの左アクセントと淡色背景
- quiz header / quiz-counter / quiz-top / domain-tag / qbar / qtext
- 番号付き5肢、タップ即時採点、正解・誤答配色
- `わからない`、同画面フィードバック、詳細解説、次問
- result-card / big / lbl / result-detail
- 学習記録・設定
- 下部3タブ（ホーム／学習記録／設定）のsticky配置
- 文字サイズ3段階、reduced-motion配慮

## 意図的に異なる資格固有差分
- FP2級: 年度×6分野。第一種衛生管理者: **3公表回×3課目＝9カード**（ユーザー指定）
- FP2級: 今日の10問。第一種衛生管理者: **今日の12問**
- 第一種衛生管理者は44問チャレンジ、法令監査日表示、StoreKitペイウォールを追加
- 9カードは1回につき3課目を同時に見せるため3列。カードの色・リング・タイポグラフィはFP2 v1.3を流用

「完全コピー」は資格固有の問題数・課目数・課金導線まで同一にする意味ではなく、**共通UIコンポーネントと操作仕様をFP2 v1.3と同一にし、資格固有情報だけ差し替える**基準で判定する。
