# 登録販売者｜次セッション引継ぎ（2026-11-24）

## 目的・不変条件
- 関西広域連合の公式過去問2022〜2026各120問、計600問。公式問題の原文・公式正答索引・PDF SHA-256を保持。
- 2023年度問90：公式不適切問題（解なし・全員正解扱い）。`answer=null`、正答率分母から除外、独立確認を終えるまで自動昇格しない。
- 第三者権利・原典レイアウト不一致・抽出不一致を無視して昇格させない。App Review提出は未承認で禁止。
- 正本：`touroku-hanbaisha-ios/release-status.json` と `RELEASE_STATUS.md`。

## 2026-11-24時点の実測
- 候補600、正式バンク **386**、未昇格 **214**。従来381から重複漢字の順序照合で **+5問**。
- 順序照合：2022年1、2023年0、2024年2、2025年1、2026年1。最初のルビ未確定135件のうち残る順序監査HOLD **130件**（他の例外と重複）。
- `ORDERED_RUBY_2022.json` ～ `ORDERED_RUBY_2026.json` に600問の判定記録。候補原典の重複漢字出現数とPDF字形座標順を厳格照合。 `ordered_ruby_recovery.py` が実装。内容変更をせずrich segmentsで `ruby`/`rt` を生成し、アプリに統合。
- 画像化対象49問すべてを公式PDFから実際に切り抜き、計 **51 PNG** を `official-kansai/layout-crops/` にGitHub保存。2022:13問13画像／2023:7問7画像／2024:12問13画像／2025:6問7画像／2026:11問11画像。SHA-256、原典URL、ページ番号、PDF SHA、領域bbox、出典文字列は `LAYOUT_CROPS_YYYY.json`。
- 49問中5問は既存の正式バンク収録済み、44問は未収録。**今回の画像による新規昇格は0件。** 画像は `rights=REVIEW_THIRD_PARTY_COMPONENTS`、`displayQA=PENDING`、`publishable=false` を維持。切り抜きだけで権利処理と判読性は証明されない。
- `official-practice.html` は `sourceFigures` の権利・表示QA両フラグtrueを必須とし、承認後のみ画像表示。画像はモバイル全幅、タップで原寸表示、出典／加工表記を併記。未承認画像を通常学習画面で表示しない。
- `.github/workflows/touhan-crop-mobile-qa.yml` と `test_crop_embed_ui.py` に、**既存合格問＋未承認画像のテスト限定仮承認をブラウザへ注入**するモバイル375/430px検証を用意。QA結果の有無は `CROP_EMBED_QA.json` を読戻して確定する（QAが成功しても法的権利確認ではない）。
- 従来のPyMuPDF/pdfplumber 50問交差検証は完全一致44・文字集合一致2・不一致4、異論4問は昇格させない。
- App Review申請可能判定はBLOCKED、実機・TestFlight未完了。

## 次の作業（優先順）
1. `CROP_EMBED_QA.json`（またはActions失敗ログ）をGitHubから読戻し、モバイル図版表示の実測を記録。 `RUBY_DOM_QA_RESULT.json` も読戻して不備があればテストとレンダラーを修正。
2. 図版44未承認のうち、真正の図表が含まれる問題を`LAYOUT_CROPS_YYYY.json`で再分類。特にPDFの問題境界がページまたぎの場合は画像2枚順序を確認。OCRではなく画像座標と視覚検査。図版が公式権利内か第三者権利か、関西広域連合の公開ルールの例外を元画像単位で確認。
3. 権利と画面忠実性が実際に確認できた画像のみ`sourceFigures`に `licenseVerified=true`,`visualVerified=true` とハッシュを記録して正式バンクへ昇格。確認がなければ昇格ゼロを維持。
4. ルビHOLD130件は、複数漢字にまたがる読み、PDFの字形位置が重複するケースを整理し、保守的に局所字形・読み対応を判定。順序のみの推測や文字削除による合格は禁止。
5. `build_approved_bank.py`, `write_auto_release_status.py`,`write_geometry_release_status.py`,`write_ruby_release_status.py`,`write_ordered_crop_status.py` で正本再生成、実ブラウザとiOS側の回帰確認。本審査は停止。

## GitHub参照
- 正規バンク：`touroku-hanbaisha-sprint/official-kansai/APPROVED_OFFICIAL_BANK.json`
- 元監査：`AUTO_DIFF_YYYY.json`,`GEOMETRY_AUDIT_YYYY.json`,`RUBY_RECON_YYYY.json`,`LAYOUT_TRIAGE_YYYY.json`
- 新監査：`ORDERED_RUBY_YYYY.json`,`LAYOUT_CROPS_YYYY.json`
- CI：`.github/workflows/touhan-ordered-ruby.yml`,`touhan-official-pdf-crops.yml`,`touhan-ordered-crop-status.yml`,`touhan-crop-mobile-qa.yml`
- ソース：`ordered_ruby_recovery.py`,`crop_official_layouts.py`,`test_crop_embed_ui.py`
- リリース状態：`touroku-hanbaisha-ios/release-status.json`・`RELEASE_STATUS.md`

## 留意
この引継ぎファイルはセッションを自動的に新規作成するものではない。新セッションでこのファイル名と最新mainを指定して作業を続ける。
