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
- Current live syllabus: IPA ITパスポート Ver.6.5（2026-01-08掲載）
- CBT / 120 minutes / 100 questions / 4 choices
- Strategy ~35 / Management ~20 / Technology ~45
- Pass: total >= 600/1000 and each domain >= 300/1000
- IPA published a **2027 new-system IT Passport draft syllabus Ver.0.1 on 2026-08-31**. It is a draft and must not silently replace the live Ver.6.5 content baseline.
- Until the 2027 system is finalized, every canonical question must explicitly declare its syllabus version. Content derived from the 2027 draft must use a draft-tagged version and must not be mixed into the live-exam pool without a release decision.
- Official reference pages: current syllabus `https://www.ipa.go.jp/shiken/syllabus/gaiyou.html`; 2027 draft `https://www.ipa.go.jp/shiken/syllabus/henkou/2026/20260630.html`.

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

## 2026-11-23 release contract: five IPA public exam sets

- Machine state: [release-status.json](release-status.json); human audit: [RELEASE_STATUS.md](RELEASE_STATUS.md).
- The requested five complete yearly IPA exams are **500 questions** (100/year), **not** the existing independent 240/300-question mock pool.
- Official content only: [official-verbatim.json](questions/official-verbatim.json), 2022–2026, one question at a time with IPA PDF citation and official answer audit.
- Legal basis directly confirmed at [IPA examination FAQ](https://www.ipa.go.jp/shiken/faq.html): attribution and explicit alteration notice required. This is not a reuse ruling derived from Notion.
- Release gate: `python3 quality/validate-official-release.py`; it intentionally blocks release until all 500 official questions have verified provenance, answers and figures.
- Preserve `original-mock.json` (240/300) and staged Batch13 in their independent training track; never label these as official IPA verbatim questions.
- The original iOS prototype still reads `starter-v1.json` (30 independent questions); it is **not an eligible release build**. The new Store app record must be separate from the legacy IT Passport app.
