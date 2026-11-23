# 看護師国家試験｜RELEASE_STATUS

更新：2026-11-24 JST　**最終送信禁止／リリース判定 PREFLIGHT_BLOCKED**

## 現時点の問題バンク（全1,200問）

| 種別 | 件数 | 公開範囲 |
|---|---:|---|
| 既存第115〜113回のソースバンク | 720 | 既存ランタイム範囲。ただし厳格原典文字列監査629 PASS/91 HOLD |
| 前回までの追加ソース検証済み | 67 | 新規アプリ配信不可 |
| 前回の追加ソース検証済み | **74** | 原典文字層再抽出／文字化け補完／公式正答照合に合格。新規配信不可 |
| 前回の境界・状況設定の追加昇格 | **3** | 2方式と公式正答照合に合格。新規配信不可 |
| **今回の座標境界方式による追加昇格** | **15** | 問題番号の座標一意性・本文と4選択肢の2方式照合・公式正答を検証。新規配信不可 |
| **正規ソースバンク** | **888 / 1,200** | ソース検証済み拡張168問を含む |
| **第112・111回の未検証** | **312問** | 要修復・監査保留 |
| 今回のアプリ配信追加 | **0問** | 解説独立監査／法令／UI／iOS／権利等の別ゲートが未完 |

上記件数はGitHub Actions Run 45249375273終了後の現行main実測値。今回の再抽出での追加昇格は0問（過去の別更新による増分は今回の成果としない）。以下の旧監査に関する数値は実施当時の履歴であり、最新件数ではない。

ソース拡張正本 `product-content/verified-additions-20261124.json`、`product-content/manifest.json`。昇格記録 `audit/dual-engine-promotion-ledger-20261124.json`。保留312問と理由 `audit/dual-engine-hold-20261124.json`。全168問の正規拡張は公開禁止フラグ `publishable=false`、`releaseEligible=false`。

## 保留413問の原因別検証と修復（理由は重複）

修復開始時の最多理由は `C0_SOURCE_GLYPH_MAPPING_UNTRUSTWORTHY` **227問**。次いでページ管理文字列混入195問、不自然文字194問、質問境界169問、Poppler問題文不一致124問、状況設定の共通文未確認120問。

1. ページ管理文字列 `DKIX-XX-前/後H-N` を原ページ番号に一致する場合のみ選択肢から切り離す方式を実装。152問の修正差分と前後の全文を記録。初回の合格追加は22問。
2. 最多原因のPDF制御文字を解消するため、第111・112回の埋込フォント `RyuminPr6-Regular` の元PDFを画像として読み、数字・括弧の9コードの字形を実地照合。誤ったUnicode割当を原典から修復して**全480問を再抽出**し、340問に本文・選択肢等の修正差分を記録。未知の `U+000E`・`U+000F` 等は推測しない。
3. 修復した本文・全選択肢を **PyMuPDF と Poppler** の別エンジン、問題番号／原典ページ、公式正答PDF、既知の採点例外で再監査。最終的に新規74問が基準を満たした（うち先行登録5問を重複排除）。**累計141問検証、339問保留**。
4. 保留内訳の主要な残件：不自然な文字147、原PDFグリフ対応未確定104、Poppler問題文照合109、選択肢4つに満たない等81、未知C0制御文字17、状況設定共通文未監査120。その他の理由・問題IDは全件を個別台帳に記録。※各理由は重複するため合算不可。
5. 制御文字の字形推定だけでの一括合格は行っていない。原典と双方のエンジンで問題文・全選択肢を確認し、公式正答が一致した問題のみソース昇格。修復前の文字列は監査台帳に保存。単純な文字・正答PASSは解説・iOSのリリースPASSではない。

検証： [GitHub Actions Run 45240759737](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45240759737) **SUCCESS**。成果物 Artifact `14851731484`、SHA-256 `b20a49e53cb7a5598797c52d4c9bd24cfe54cb85d74f51096c142309245c2ab2`。前後差分は `audit/staging-repair-evidence/glyph-map-repair-ledger.json`／`footer-repairs.json`。

## 図版：JPG15件の利用条件を確定

厚労省ホームページの[利用規約](https://www.mhlw.go.jp/chosakuken/index.html)は特記・別権利表示がないコンテンツにPDL1.0を適用し、出典と加工の表示を必要とする。

- 以前から「PDL1.0対象」と記録された **JPG15件**の実画像を確認。いずれも表・グラフ・線画・文章等で、患者写真や第三者の写真素材は視認されず、元PDFの権利注記も0件。
- JPG15問の `raw/set1-raw.json`〜`set3-raw.json` の権利項目を `USABLE_UNDER_MHLW_PDL1_WITH_SOURCE_AND_EDIT_LABEL` に更新。各問に厚労省／回次／原典PDF URL／「切り出し・加工」を記録。以前の判定と更新後の内容は `audit/jpg15-pdl1-rights-approval-20261124.json`。
- **これは素材のPDL1.0再利用に関する条件付き利用可判定であり、問題そのものの正式公開合格・Apple本審査送信ではない。** 別途第三者著作物と判明した場合は撤回する。

## 不一致SVG5件を「公式PDFの画像切り出し」に切替

以前の独自SVGは原典画像の医学的意味・選択肢を忠実に再現できなかったため、再作画を中止。厚労省公式の問題PDFまたは別冊PDFの元画素からPNGを切り出し、全5ファイルをGitHub `media/official-crops/` に保存。

| 問題ID | 原典PDFの該当図 | 今回の元画像 |
|---|---|---|
| `K115-AM063` | 第115回午前・別冊No.1、4枚の器具写真 | `media/official-crops/K115-AM063.png` |
| `K115-PM020` | 第115回午後20問、呼吸波形4択 | `media/official-crops/K115-PM020.png` |
| `K114-AM013` | 第114回午前・別冊No.1、心電図4択 | `media/official-crops/K114-AM013.png` |
| `K114-AM051` | 第114回午前・別冊No.2、胸部CT画像 | `media/official-crops/K114-AM051.png` |
| `K114-AM107` | 第114回午前・別冊No.3、小児ベッドと医療機器配置 | `media/official-crops/K114-AM107.png` |

各ファイルの出典URL・PDFページ・切り出し矩形・PDF SHA-256・PNG SHA-256・加工注記は `audit/official-pdf-crop-replacements-20261124.json` に記録。5ファイルは元PDF画素そのものであり、元SVGより原図への忠実性が高い。なお `K114-AM107` は原典印刷が横向きのため表示時の90度回転が必要。

`product-content/media-redraw-resolutions.json` の5件を従来のSVGから公式PDF切り出しPNGへ**経路切替**し、権利と表示確認が完了するまで `hold_rights_and_crop_review` に固定。再構成SVGを完成品として扱わず、`media-runtime.js` は旧SVGの誤表示を抑止するガードを追加。既存SVGはロールバックのためGit履歴に残す。

- 原典切り出しには撮影画像・CT・装置図も含まれるため**5件の個別権利確認・アプリ表示確認待ち**。製品公開フラグは解除しない。
- 残り18件の独自SVGも原図との完全忠実性確認が終わっていないため公開ゲートは継続。
- メディア経路CI：[Run 45241710210](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45241710210) **SUCCESS**、Artifact `14852120867`。現物パス・PNGハッシュ・JPG15の出典加工表記・旧SVG無効化を検査。**38件中33件が従来の解決経路、5件は原典切り出しの保留経路**で、保留があるため最終公開判定はFAIL。

## 申請ゲート

- 既存720問の厳格PDF文字列監査は **629 PASS／91 HOLD** のまま（出典画像の別判定・図版の権利ゲートとは独立）。
- 追加168問のソース・正答チェックが済んでも、**解説の独立確認、法令/学説時点確認、アプリ統合、iOS回帰テスト、未検証312問の監査、図版5件の権利確認**が未完了。
- App ID `6801792293`、Bundle `jp.allsunday1122.kangoshi`。
- **App Store本審査の最終送信、課金登録、契約確定はいずれも行っていない**。いずれも別途明示承認が必要。

## 境界位置・状況設定の再検証（GitHub Actions Run 45244159028：成功）

- 正規ソースバンク：**864/1,200問**（追加144問、既存720問）。
- 追加480問の未昇格：**336問**。今回の自動昇格：**3問**。
- 番号境界を前後3ページで探索し、独立行または行頭の問題番号と問題文・4選択肢の両エンジン一致・候補一意性を確認する。状況設定の共通文も2エンジン一致がない限り保留。
- 主要保留理由（重複）：BOUNDARY_NO_UNIQUE_DUAL_ENGINE_PAGE 249, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 178, PYMUPDF_FIELD_MISMATCH_0 177, PYMUPDF_WRONG_QUESTION_BOUNDARY 177, PAGE_FOOTER_CONTAMINATION 151, POPPLER_FIELD_MISMATCH_0 142, PYMUPDF_FIELD_MISMATCH_4 115, SOURCE_GLYPH_MAPPING_UNTRUSTWORTHY 104, CHOICE_COUNT_NOT_FOUR 93, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 48, POPPLER_FIELD_MISMATCH_4 48, TOO_SHORT_FOR_UNIQUE_STEM 41。
- SVG18件は原典との比較画像を再生成するが、画像の意味・医学的所見の忠実性は自動合格にしない。**18件の詳細視覚確認が残存**。
- 解説・媒体権利・実機確認・本審査の公開ゲートは引き続き保留。

- 新規昇格ID：`K112-PM113`、`K111-AM106`、`K111-PM106`。証拠は個別昇格台帳に記録。
- SVG18件は本比較で問題PDFページ側に「別冊」参照があるものを確認。少なくとも `K113-AM023` は原図が別冊にあるため、この左右比較だけでは忠実性判定不可。原図別冊に基づく照合までHOLD継続。

## PDF座標による問題番号境界再監査（Run 45246704920：SUCCESS）

- 正規ソースバンク：**879/1,200問**（追加159問、既存720問）。
- 追加480問の未昇格：**321問**。今回の自動昇格：**15問**。
- 問題番号の実PDF座標（設問番号おおむねx=70〜82pt、選択肢はx=106pt付近）と次の設問番号位置で領域を設定。切出し領域に問題文と4選択肢が存在し、Poppler側の別抽出と公式正答PDFが一致することを確認。短文15問は一意の座標境界が証明されたため従来の18文字制限を解除して昇格。状況設定の共通文未確認など他の品質保留は解除していない。
- 主要保留理由（重複）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 277, COORDINATE_REGION_UNVERIFIED 277, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 178, PYMUPDF_FIELD_MISMATCH_0 177, PAGE_FOOTER_CONTAMINATION 151, POPPLER_FIELD_MISMATCH_0 142, PYMUPDF_FIELD_MISMATCH_4 115, CHOICE_COUNT_NOT_FOUR 93, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 48, POPPLER_FIELD_MISMATCH_4 48, OFFICIAL_ANSWER_NOT_SINGLE 38, INDEPENDENT_OFFICIAL_KEY_MISMATCH 38。
- SVG18件は原典との比較画像を再生成するが、画像の意味・医学的所見の忠実性は自動合格にしない。**18件の詳細視覚確認が残存**。
- 解説・媒体権利・実機確認・本審査の公開ゲートは引き続き保留。

- 今回昇格ID：`K112-AM013`、`K112-AM034`、`K112-AM036`、`K112-AM038`、`K112-AM058`、`K112-AM063`、`K112-PM009`、`K112-PM015`、`K112-PM055`、`K112-PM059`、`K111-AM049`、`K111-PM013`、`K111-PM014`、`K111-PM019`、`K111-PM053`。ソース検証済みであり、公開可能にはしていない。

## 境界位置・状況設定の再検証（自動実行記録）

- 正規ソースバンク：**900/1,200問**（追加180問、既存720問）。
- 追加480問の未昇格：**300問**。今回の自動昇格：**10問**。
- 番号境界を前後3ページで探索し、単独行の問題番号と問題文・4選択肢の両エンジン一致・候補一意性を確認する。状況設定の共通文も2エンジン一致がない限り保留。
- 主要保留理由（重複）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 261, COORDINATE_REGION_UNVERIFIED 261, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 176, PYMUPDF_FIELD_MISMATCH_0 172, PAGE_FOOTER_CONTAMINATION 141, POPPLER_FIELD_MISMATCH_0 137, PYMUPDF_FIELD_MISMATCH_4 108, CHOICE_COUNT_NOT_FOUR 89, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 48, POPPLER_FIELD_MISMATCH_4 46, OFFICIAL_ANSWER_NOT_SINGLE 38, INDEPENDENT_OFFICIAL_KEY_MISMATCH 38。
- SVG18件は原典との比較画像を再生成するが、画像の意味・医学的所見の忠実性は自動合格にしない。**18件の詳細視覚確認が残存**。
- 解説・媒体権利・実機確認・本審査の公開ゲートは引き続き保留。
\n## 状況設定共通文・制御文字の再監査（2026-11-24）\n\n- 新規正規ソース昇格：**10問**。現行 **900/1,200問**、未昇格 **300問**。\n- 先行再抽出22問のうち未昇格：**12問**。本文2方式一致の事実と、制御文字・状況設定共通文の最終ゲートは区別。\n- 全残件の保留理由（重複）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 261, COORDINATE_REGION_UNVERIFIED 261, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 176, PYMUPDF_FIELD_MISMATCH_0 172, PAGE_FOOTER_CONTAMINATION 141, POPPLER_FIELD_MISMATCH_0 137, PYMUPDF_FIELD_MISMATCH_4 108, CHOICE_COUNT_NOT_FOUR 89, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 48, POPPLER_FIELD_MISMATCH_4 46。\n- 正本：`audit/dual-engine-promotion-ledger-20261124.json`、`audit/dual-engine-hold-20261124.json`、`audit/coordinate-reextraction-evidence-20261124.json`。権利・解説・iOS・本審査のゲートは引き続き閉鎖。\n