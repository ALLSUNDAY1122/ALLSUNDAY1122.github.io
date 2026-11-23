# 看護師国家試験｜RELEASE_STATUS

更新：2026-11-24 JST　**最終送信禁止／リリース判定 PREFLIGHT_BLOCKED**

## 現時点の問題バンク（全1,200問）

| 種別 | 件数 | 公開範囲 |
|---|---:|---|
| 既存第115〜113回ソースバンク | 720 | 既存ランタイム、厳格原典監査629 PASS／91 HOLD |
| 今回の監査前の検証済みソース拡張 | 251 | 履歴を保持、配信不可 |
| **今回の追加昇格** | **0** | 共通文・制御文字と二方式・公式正答の再検証 |
| **正規ソースバンク** | **971 / 1,200** | ソース拡張251問を含む |
| **未昇格** | **229問** | 原典の疑義と未合格ゲートは保持 |
| アプリへの今回の追加配信 | 0問 | 解説・図版権利・アプリ／iOSゲート未完了 |

- GitHub Actions Run：45262412566。先行再抽出22問のうち**0問**が引き続き保留。
- 正規ソース：\`product-content/verified-additions-20261124.json\`。保留：\`audit/dual-engine-hold-20261124.json\`。
- 昇格台帳：\`audit/dual-engine-promotion-ledger-20261124.json\`。全新規問の\`publishable=false\`、\`releaseEligible=false\`を維持。
- 制御文字について、両抽出方式が同一の壊れたPDF文字対応表を共有する危険があるため、未確認の原典文字は自動合格としない。

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

## 今回の状況設定共通文・制御文字再監査（Run 45252425096）

- 先行再抽出22問を優先し、公式PDFの共通文見出し・番号範囲・本文を確認。**10問が合格・昇格、12問が保留**。
- 昇格ID：`K112-AM091`、`K112-PM100`、`K112-PM109`、`K111-AM112`、`K111-AM118`、`K111-PM091`、`K111-PM094`、`K111-PM097`、`K111-PM109`、`K111-PM112`。
- 12問の残理由：原典C0制御文字3問、共通文の未確定グリフ8問、共通文の2方式本文差1問。未知の原典文字対応は自動補正せず保留。
- 残る全300問も同じ一連の抽出・2方式・公式正答・採点例外・共通文ゲートを実行。主要な残理由（重複あり）：座標の一意性不足261件、疑義文字176件、PyMuPDF問題文不一致172件など。
- 図版18件、既存720問の厳格原典監査91件、解説・権利・iOSの未完了ゲートは引き続き保留。
- 詳細証拠は `audit/dual-engine-hold-20261124.json` と `audit/dual-engine-promotion-ledger-20261124.json`。最終送信・契約・課金確定は行わない。


## 今回の独立共通文・制御文字監査（Run 45253735557）

- 追加昇格 **0問**、合計 **900/1,200問**。残り **300問**。
- 昇格ID：なし。
- 保留の多い理由（重複あり）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 261, COORDINATE_REGION_UNVERIFIED 261, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 176, PYMUPDF_FIELD_MISMATCH_0 172, PAGE_FOOTER_CONTAMINATION 141, POPPLER_FIELD_MISMATCH_0 137, PYMUPDF_FIELD_MISMATCH_4 108, CHOICE_COUNT_NOT_FOUR 89, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 48, POPPLER_FIELD_MISMATCH_4 46, OFFICIAL_ANSWER_NOT_SINGLE 38, INDEPENDENT_OFFICIAL_KEY_MISMATCH 38。
- 先行再抽出候補：22問のうち残存保留12問。権利・解説・アプリ配信ゲートの自動解除は行わない。


## 今回の独立共通文・制御文字監査（Run 45254606876）

- 追加昇格 **3問**、合計 **903/1,200問**。残り **297問**。
- 昇格ID：K112-AM073, K112-PM017, K112-PM052。
- 保留の多い理由（重複あり）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 261, COORDINATE_REGION_UNVERIFIED 261, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 176, PYMUPDF_FIELD_MISMATCH_0 172, PAGE_FOOTER_CONTAMINATION 141, POPPLER_FIELD_MISMATCH_0 137, PYMUPDF_FIELD_MISMATCH_4 108, CHOICE_COUNT_NOT_FOUR 89, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 48, POPPLER_FIELD_MISMATCH_4 46, OFFICIAL_ANSWER_NOT_SINGLE 38, INDEPENDENT_OFFICIAL_KEY_MISMATCH 38。
- 先行再抽出候補：22問のうち残存保留9問。権利・解説・アプリ配信ゲートの自動解除は行わない。


## 今回の独立共通文・制御文字監査（Run 45255576849）

- 追加昇格 **0問**、合計 **911/1,200問**。残り **289問**。
- 昇格ID：なし。
- 保留の多い理由（重複あり）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 253, COORDINATE_REGION_UNVERIFIED 253, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 176, PYMUPDF_FIELD_MISMATCH_0 168, POPPLER_FIELD_MISMATCH_0 133, PAGE_FOOTER_CONTAMINATION 133, PYMUPDF_FIELD_MISMATCH_4 100, CHOICE_COUNT_NOT_FOUR 89, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 48, POPPLER_FIELD_MISMATCH_4 45, OFFICIAL_ANSWER_NOT_SINGLE 38, INDEPENDENT_OFFICIAL_KEY_MISMATCH 38。
- 先行再抽出候補：22問のうち残存保留9問。権利・解説・アプリ配信ゲートの自動解除は行わない。


## 今回の独立共通文・制御文字監査（Run 45256648834）

- 追加昇格 **8問**、合計 **919/1,200問**。残り **281問**。
- 昇格ID：K112-AM095, K112-AM097, K112-AM112, K112-PM098, K112-PM103, K112-PM115, K111-AM094, K111-AM109。
- 保留の多い理由（重複あり）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 253, COORDINATE_REGION_UNVERIFIED 253, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 176, PYMUPDF_FIELD_MISMATCH_0 168, POPPLER_FIELD_MISMATCH_0 133, PAGE_FOOTER_CONTAMINATION 133, PYMUPDF_FIELD_MISMATCH_4 100, CHOICE_COUNT_NOT_FOUR 89, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 48, POPPLER_FIELD_MISMATCH_4 45, OFFICIAL_ANSWER_NOT_SINGLE 38, INDEPENDENT_OFFICIAL_KEY_MISMATCH 38。
- 先行再抽出候補：22問のうち残存保留1問。権利・解説・アプリ配信ゲートの自動解除は行わない。


## 今回の独立共通文・制御文字監査（Run 45257252230）

- 追加昇格 **1問**、合計 **920/1,200問**。残り **280問**。
- 昇格ID：K112-AM100。
- 保留の多い理由（重複あり）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 253, COORDINATE_REGION_UNVERIFIED 253, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 176, PYMUPDF_FIELD_MISMATCH_0 168, POPPLER_FIELD_MISMATCH_0 133, PAGE_FOOTER_CONTAMINATION 133, PYMUPDF_FIELD_MISMATCH_4 100, CHOICE_COUNT_NOT_FOUR 89, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 48, POPPLER_FIELD_MISMATCH_4 45, OFFICIAL_ANSWER_NOT_SINGLE 38, INDEPENDENT_OFFICIAL_KEY_MISMATCH 38。
- 先行再抽出候補：22問のうち残存保留0問。権利・解説・アプリ配信ゲートの自動解除は行わない。


## 今回の独立共通文・制御文字監査（Run 45258902188）

- 追加昇格 **0問**、合計 **920/1,200問**。残り **280問**。
- 昇格ID：なし。
- 保留の多い理由（重複あり）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 231, COORDINATE_REGION_UNVERIFIED 231, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 149, POPPLER_FIELD_MISMATCH_0 137, PYMUPDF_FIELD_MISMATCH_0 106, CHOICE_COUNT_NOT_FOUR 86, PAGE_FOOTER_CONTAMINATION 84, PYMUPDF_FIELD_MISMATCH_4 63, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 48, POPPLER_FIELD_MISMATCH_4 40, OFFICIAL_ANSWER_NOT_SINGLE 38, INDEPENDENT_OFFICIAL_KEY_MISMATCH 38。
- 先行再抽出候補：22問のうち残存保留0問。権利・解説・アプリ配信ゲートの自動解除は行わない。


## 今回の独立共通文・制御文字監査（Run 45259501753）

- 追加昇格 **20問**、合計 **940/1,200問**。残り **260問**。
- 昇格ID：K112-AM014, K112-AM029, K112-AM030, K112-AM049, K112-AM051, K112-PM028, K112-PM029, K112-PM054, K111-AM029, K111-AM032, K111-AM039, K111-AM043, K111-AM045, K111-AM051, K111-AM064, K111-AM073, K111-PM045, K111-PM049, K111-PM070, K111-PM072。
- 保留の多い理由（重複あり）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 210, COORDINATE_REGION_UNVERIFIED 210, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 149, POPPLER_FIELD_MISMATCH_0 117, PYMUPDF_FIELD_MISMATCH_0 106, CHOICE_COUNT_NOT_FOUR 86, PAGE_FOOTER_CONTAMINATION 84, PYMUPDF_FIELD_MISMATCH_4 63, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 48, POPPLER_FIELD_MISMATCH_4 39, OFFICIAL_ANSWER_NOT_SINGLE 38, INDEPENDENT_OFFICIAL_KEY_MISMATCH 38。
- 先行再抽出候補：22問のうち残存保留0問。権利・解説・アプリ配信ゲートの自動解除は行わない。


## 今回の独立共通文・制御文字監査（Run 45260033942）

- 追加昇格 **0問**、合計 **940/1,200問**。残り **260問**。
- 昇格ID：なし。
- 保留の多い理由（重複あり）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 210, COORDINATE_REGION_UNVERIFIED 210, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 149, POPPLER_FIELD_MISMATCH_0 117, PYMUPDF_FIELD_MISMATCH_0 106, CHOICE_COUNT_NOT_FOUR 86, PAGE_FOOTER_CONTAMINATION 84, PYMUPDF_FIELD_MISMATCH_4 63, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 48, POPPLER_FIELD_MISMATCH_4 39, OFFICIAL_ANSWER_NOT_SINGLE 38, INDEPENDENT_OFFICIAL_KEY_MISMATCH 38。
- 先行再抽出候補：22問のうち残存保留0問。権利・解説・アプリ配信ゲートの自動解除は行わない。

## 座標領域・独立2方式による280問再監査（2026-11-24）

- 監査前：正規ソース920問、保留280問。GitHub Actions Run `45259501753` **SUCCESS**。
- 過去の原典文字形状修復候補87問を読み戻し、候補内容を差分記録。採用を先決せず、問題番号座標による矩形範囲とPyMuPDF/Popplerの本文・4選択肢照合、厚労省公式正答PDF検証を再実行。
- 独立再抽出一致21問、**新規ソースバンク昇格20問**。**現行940/1200問・未昇格260問**。英語医学用語の併記がPDF抽出順で前後するケースは、日本語の全文一致と英語語句の出現集合一致を別々に検証。数字や日本語の欠落があれば不合格。
- 昇格IDと設問座標の凍結証拠：`audit/geometry-recovery-batch-20261124.json`。20問のPDF原典切出画像、PNG SHA-256、PDF SHA-256、公式解答PDF SHA-256、ページ番号・座標を`audit/geometry-recovery-image-index-20261124.json`に保存。画像証拠生成・再監査 Run `45260033942` **SUCCESS**。証拠画像は同RunのArtifacts `kangoshi-20-geometric-source-regions`（ID `14860970560`）へ格納。
- 画像20問分の出力を確認。画像生成と2方式照合は完了したが、**全字の独立目視一致を自動保証するものではない**。解説・媒体・アプリ・iOS等のゲートは継続保留。
- **一般公開不可**：既存ランタイム720問は別途原典文字列監査で629 PASS/91 HOLD。新規220問はすべて`publishable=false`、`releaseEligible=false`。Apple最終送信・課金契約確定は未実施。


## 今回の独立共通文・制御文字監査（Run 45261299978）

- 追加昇格 **0問**、合計 **940/1,200問**。残り **260問**。
- 昇格ID：なし。
- 保留の多い理由（重複あり）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 210, COORDINATE_REGION_UNVERIFIED 210, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 149, POPPLER_FIELD_MISMATCH_0 117, PYMUPDF_FIELD_MISMATCH_0 106, CHOICE_COUNT_NOT_FOUR 86, PAGE_FOOTER_CONTAMINATION 84, PYMUPDF_FIELD_MISMATCH_4 63, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 48, POPPLER_FIELD_MISMATCH_4 39, OFFICIAL_ANSWER_NOT_SINGLE 38, INDEPENDENT_OFFICIAL_KEY_MISMATCH 38。
- 先行再抽出候補：22問のうち残存保留0問。権利・解説・アプリ配信ゲートの自動解除は行わない。


## 今回の独立共通文・制御文字監査（Run 45261935811）

- 追加昇格 **5問**、合計 **971/1,200問**。残り **229問**。
- 昇格ID：K112-AM079, K112-AM081, K112-PM079, K112-PM084, K111-AM084。
- 保留の多い理由（重複あり）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 172, COORDINATE_REGION_UNVERIFIED 172, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 148, POPPLER_FIELD_MISMATCH_0 113, PYMUPDF_FIELD_MISMATCH_0 101, PAGE_FOOTER_CONTAMINATION 75, PYMUPDF_FIELD_MISMATCH_4 61, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 38, OFFICIAL_ANSWER_NOT_SINGLE 38, INDEPENDENT_OFFICIAL_KEY_MISMATCH 38, POPPLER_FIELD_MISMATCH_4 38, SOURCE_GLYPH_MAPPING_UNTRUSTWORTHY 33。
- 先行再抽出候補：22問のうち残存保留0問。権利・解説・アプリ配信ゲートの自動解除は行わない。


## 今回の独立共通文・制御文字監査（Run 45262412566）

- 追加昇格 **0問**、合計 **971/1,200問**。残り **229問**。
- 昇格ID：なし。
- 保留の多い理由（重複あり）：COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED 172, COORDINATE_REGION_UNVERIFIED 172, SUSPICIOUS_GLYPH_OR_CONTROL_IN_DRAFT 148, POPPLER_FIELD_MISMATCH_0 113, PYMUPDF_FIELD_MISMATCH_0 101, PAGE_FOOTER_CONTAMINATION 75, PYMUPDF_FIELD_MISMATCH_4 61, OFFICIAL_ANSWER_MISMATCH_OR_COMPLEX 38, OFFICIAL_ANSWER_NOT_SINGLE 38, INDEPENDENT_OFFICIAL_KEY_MISMATCH 38, POPPLER_FIELD_MISMATCH_4 38, SOURCE_GLYPH_MAPPING_UNTRUSTWORTHY 33。
- 先行再抽出候補：22問のうち残存保留0問。権利・解説・アプリ配信ゲートの自動解除は行わない。

## 残り260問からの4択・5択座標再監査（2026-11-24）

- 原典の4択・5択を区別し、公式解答PDFと全選択肢の独立照合を行うよう検証器・正規ソース昇格ゲートを改修。無回答や採点例外、図版疑義は従来どおり保留。
- 初回改修実行では正答null候補による例外を検出、保留扱いに修正して再実行。Run `45261935811` は **SUCCESS**。今回の個別新規昇格は **5問**：`K112-AM079`, `K112-AM081`, `K112-PM079`, `K112-PM084`, `K111-AM084`。5問の高解像度原典領域画像とSHA-256は`audit/latest-new-source-images-20261124.json`に収録。
- 作業開始時は940問、同じ期間に別セッションで26問の並行昇格あり。今回昇格5問を含む現況は**正規971/1200問、保留229問**。今回の追加昇格として並行作業分26問は二重計上しない。
- 続けて残229問の原典設問番号をPyMuPDFで座標確認し、各問を2倍拡大のPDF領域画像として再出力。Run `45262412566` **SUCCESS**、229問すべてに一意な設問番号アンカーがあり、画像・座標・PDF SHA-256・保留理由を`audit/residual-geometric-source-index-20261124.json`に保存。画像Artifactsは`kangoshi-residual-geometric-page-evidence`、ID `14861452631`。
- **設問番号の座標が一意であることは、本文と選択肢の文字・図版・正答が確定したことを意味しない**。この追加画像監査での昇格は0問。次工程は残229問のPDF CMap/本文と選択肢の差分をページ画像で照合し、2方式・正答が一致した問だけ昇格。
- 新規拡張のアプリへの配信は0問。公開ゲートは`PREFLIGHT_BLOCKED`。本審査送信・契約・課金は未実施。
