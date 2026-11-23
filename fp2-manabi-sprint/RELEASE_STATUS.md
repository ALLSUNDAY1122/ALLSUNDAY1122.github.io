# FP2 現行リリース判定（2026-11-24／298問選抜）

> 現行の唯一の判定節。以下の2026-11-23以前の309/300、312/300、Q53 HOLD等は監査経緯を示す**履歴**であり、現行値として参照・再利用しない。

- 正規バンク310問＝公式逐語監査PASS298問＋独自予備12問。選抜298問（公式のみ）、予備12問、隔離FAIL2問（2024-09 Q07・2024-05 Q08）、HOLD0問。Q53・Q55はPASS。300問への独自・言い換え補充は禁止。全310問 publishable=false。
- 分野別選抜48/50/50/50/50/50。PR #5717 Draft、main未マージ、App Review未提出。公開許可0問。
- CI実測の既知証跡：0b1dc287b5a6f2f8d39c1b4560e30411f730cf0cでFP2関連8ジョブSUCCESS（audit/FP2_PREFLIGHT_298_SELECTED_CI8_20261124.md）。**c1cf40cおよび本記録更新コミットの8ジョブSUCCESSを意味しない**。
- Q0 **BLOCKED**（逐語利用条件・出典／図版・法令の最終責任者承認未了）。Q1 **教材監査PASS298／出版BLOCKED**（FAIL2隔離済み、最終出版承認未了）。Q2 **ブラウザE2E PASS／実利用者受入未了**。Q3 **Chromium・Golden Master検査PASS／実機・アクセシビリティ未了**。Q4 **NOT TESTED**（第三者・受験者相当の受入未完）。Q5 **BLOCKED**（unsigned Simulatorのみ確認、署名IPA・TestFlight・ASC実値・審査資料未確認）。
- 総合 **NOT_SUBMISSION_READY / NOT_SUBMITTED**。本審査提出、公開、課金契約は実施しない。

---

## 過去の監査・構成履歴（現行判定ではない）

## 2026-11-24｜最新正本：選抜298のみ・0b1dc28のFP2 CI 8/8 SUCCESS

**この追記は旧312/300/12・309/300/9・古いCI未完了の記載に優先する。** 正規310＝公式逐語PASS298＋独立監査済みオリジナル予備12、選抜298のみ（2024-05:59、2024-09:59、2025-01:60、2025-05:60、2026-05:60。6分野48/50/50/50/50/50）。オリジナル・言い換えによる不足2問の補充禁止。2024-09 Q07・2024-05 Q08はFAILとして隔離、HOLD0。公開許可0。

対象HEAD `0b1dc287b5a6f2f8d39c1b4560e30411f730cf0c` のGitHub Check Runsを直接読戻し、**FP2関連8/8 completed/success**。内訳：Preflight静的×2、unsigned Simulator×2、Chromium E2E×2、Registry audit×1、Golden Master migration×1。証拠：`audit/FP2_PREFLIGHT_298_SELECTED_CI8_20261124.md`。この追記コミットより新しいソースについて成功を保証しない。

**AUTO-FIX:** CI失敗なし／旧300・312固定の誤表示・検査が再発すれば298へ整合。**BUILD-REQUIRED:** 署名済み298問IPAとSHA照合、TestFlight、サポート・Privacy公開HTTP200。**HUMAN-REQUIRED:** App Store Connect実物のApp ID/Bundle/Version/Build/IAP/Privacy/AppIcon/スクショ/URL、iOS実機受入、公式逐語原題・二次利用主体・法令・出典表示/図版の責任者承認。**FINAL-APPROVAL:** Q0〜Q5全通過後のユーザー明示的App Review提出許可。

**Q0 BLOCKED／Q1 CONTENT AUDIT PASS298（出版BLOCKED）／Q2 Chromium PASS・実機受入待ち／Q3 Golden Master移行・Chromium PASS・実機待ち／Q4 NOT COMPLETED／Q5 unsigned Simulator PASS・署名IPA/ASC/配信 BLOCKED。** PR #5717 Draft、main未マージ、TestFlight/App Review未提出、**NOT_SUBMISSION_READY / NOT_SUBMITTED**。

---

## 2026-11-23｜最新正本：5回分の逐語PASS298のみ選抜（補充禁止）

**この節が旧309/300/9・310/300/10・旧HOLD1等の履歴記述に優先する。**
- 正規バンク **310** = 公式逐語監査PASS **298** + 独立監査済みオリジナル予備 **12**。
- 選抜 **298**（2024-05:59、2024-09:59、2025-01:60、2025-05:60、2026-05:60）。6分野内訳 **48/50/50/50/50/50**。
- 独自オリジナルL01・L02・S01を含む **12件は全件予備**。オリジナル・言い換えによる300問への補充は禁止。選抜に非公式問題は **0**。
- 2024-09 Q07・2024-05 Q08は2026-04-01基準でFAIL（選抜・正規外、quarantineへ継続記録）。HOLD **0**。2024-05 Q53と2026-05 Q55は独立監査PASS、元PDF切り出し図版PNGを同ブランチに保管。
- 公開承認 **0**、全310件 `publishable=false`。PR #5717はDraft、mainマージ・TestFlight/App Review送信なし。
- Web/iOSデータは298問を選別するよう更新。従来の「300問固定」「各分野50問固定」は現行方針には適用しない。元の目標300問との差 **2問** は監査FAILによる不足として残す。
- 証拠SHA：2024-05監査JSONがQ53のHOLD→PASSで改訂されたため、旧SHA参照58件を最新監査Git Blob SHAへ照合・更新。静的ロックもデータ・アダプタ変更と同時に再固定。
- 残る公開障壁：Q0 出典二次利用条件・全問の逐語原PDF照合、Q1 教材内容の最終出版承認、Q2 実際の学習者テスト、Q3 実機と図版の画面表示・アクセシビリティ、Q4 独立受入テスト、Q5 署名付きIPA・TestFlight・ASC審査資料。ChromiumやSimulatorの成功だけで公開可能とは判定しない。

# FP2 RELEASE STATUS（正本・2026-11-23・Q20第2次独立PASS反映）

## 2026-11-23｜逐語版300問・配布前技術CIの実測PASS（最新追記）

**監査済み正規309／選定300（公式学科297＋独自補充3）／監査済み予備9／隔離3（Q07・Q08 FAIL、Q53 HOLD）／公開承認0**の構成は維持。

- **PASS [Chromium学習・オフラインE2E](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45176802420)**：法令監査2件の逐語版117 PASS・2 FAIL・1 HOLDを個別突合、正規309/選定300/予備9、300問オフラインJSONと埋込HTMLの内容/ハッシュ一致、学習操作・バックアップ復元・Service Workerオフライン復帰PASS。
- **PASS [macOS unsigned iOS Simulator](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45176802436)**：コード生成、署名なしSimulatorコンパイル、ビルド後バンドル内Info.plistと300問実データ読戻しが全ステップSUCCESS。バンドル証拠はcanonical309・selected300・reserves9。
- **PASS [監査コミット55ddf49のChromium E2E](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45173608313)**：このSUCCESSは監査保存時点に限定。今回はその後の逐語版差替後に別途Chromium/Simulatorを成功させている。
- **PASS** 対応コミットの静的canonical/Web・UI Golden Master移行・Release Registry静的監査。後続の文書更新コミットのCI完了は別途追跡。
- **製品Q0・Q4・Q5配布承認は未達**。Q53親族関係図のGitHub PNG未保存・公式原図比較/再監査未了、逐語版の公式PDF全字差分、原題転載/利用条件、実機TestFlight、署名IPA/ASCの確認は別ゲート。Q5の**unsigned Simulator技術サブゲートPASS**と**署名IPA配布ゲートBLOCKED**を区別する。

**最終判定：BLOCKED / NOT_SUBMISSION_READY / NOT_SUBMITTED。** PR #5717 Draft、mainマージ・App Review提出禁止。

---


## 2026-11-23｜逐語版2024年過去問へ差替・法改正FAIL2／図版HOLD1の隔離（最新・正本）

**現行コンテンツ＝正規承認バンク309問（全問内容監査PASS）、選定300問、内容監査PASSの予備9問、別隔離3問（FAIL2・HOLD1）、公開許可0問。** 旧312問・300問・予備12問は**言い換え版2024問を含む履歴状態**であり、現行の正規出題バンクではない。

- 逐語版2024-09：60問の独立法令監査PASS59、FAIL1＝Q07、HOLD0（監査コミット `b3f415feed0bcd88f82a62a797df8f72df4c477f`）。
- 逐語版2024-05：60問の独立法令監査PASS58、FAIL1＝Q08、HOLD1＝Q53（監査コミット `55ddf49bdf0e947495cebaf46fd855979b8d31b3`）。
- 旧2024言い換え版120件を承認バンクから削除し、逐語版の**117件だけ**を独立内容PASSとして受入れ。回収180件と既存独自作成PASS12件を合わせて **180＋117＋12＝309件**。
- 選定300件＝既存の学科180件＋逐語版117件＋独立監査済み独自作成補充3件。補充元は `FP2-ORIG-20261123-L01`・`FP2-ORIG-20261123-L02`・`FP2-ORIG-20261123-S01`。予備9件は独自作成の残り。分野は6×50問維持。
- **5回分の公式出題300問そのものではなく**、2024-05＝58、2024-09＝59、2025-01＝60、2025-05＝60、2026-05＝60の公式学科297問＋独自3問の合計300問。販促・ASC表示で「公式学科過去問300問」と誤称しない。
- Q07（2024-09）・Q08（2024-05）は企業型DCマッチング拠出制度の2026-04-01法令変更によって原題の単一正答が崩れ、出題禁止。Q53（2024-05）は親族関係図のPNGがGitHubに保存されておらず原PDFとの照合も未了のため、**HOLD継続**。3件を `questions/quarantine/fp2-verbatim-2024-legal-fail-and-q53-hold-20261123.json` に原文・理由とともに隔離し、承認バンク・iOS/Web出題バンドルから除外。
- 2024-05 B03の逐語JSONは監査後Q53メタデータ追加でBlob SHAが変更された。監査時 `27a08d04670a75f133076df5a86ee97dcf149e86`、現行 `066eadb5116e8430c8e7b2449078983e4e095bda`。独立監査PASSの他19件は本文・4肢・正答を監査原本と照合した。全問の公式PDF逐文字照合とQ0権利許諾は未完了。

**証拠正本：** `audit/FP2_VERBATIM_2024_LEGAL_SAFE_300_INTEGRATION_20261123.md`、2件の逐語法令監査JSON、6件の逐語JSON原本、`release/release-selection-300-20261123.json`。旧言い換え版の原本は履歴として `questions/draft/` に保存。

### 逐語版への差替後のCI

- **PASS** [FP2 Chromium学習・オフラインE2E](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45176802420)：独立監査の117/2/1をバッチ別に再突合、正規309・選定300・予備9・隔離3の判定、300問限定Web埋込/JSONとSHA一致、6分野×50・実ブラウザ学習/オフライン・JSON復元の全テストを成功と読戻し。
- **PASS** 逐語版統合後のソース静的検査、Golden Master移行ゲート、Registry監査は同系列CIでSUCCESSを確認。
- **旧コミット55ddf49のChromium E2EもSUCCESS**（run [45173608313](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45173608313)）。これは逐語版監査記録保存時点の結果であり、今回置換後のCI代用ではない。
- **macOS iOS Simulator：最新の逐語版300問構成のジョブ結果を別途読戻す**。実署名IPA/実機TestFlightは未確認で、Linux上の生成PASSだけをネイティブ完成とみなさない。

### 最新Q0〜Q5

| Gate | 判定 | 残るブロッカー |
|---|---|---|
| Q0 権利・法令・原図 | **BLOCKED** | 2026-04-01原典適用、2024全問の逐文字公式PDF照合、二次利用権限、画像原本／Q53未再監査、出典・改変表示の責任者承認 |
| Q1 内容監査 | **APPROVED CONTENT309／SELECTED300 PASS、3件隔離** | 独立監査PASS117を使用。逐語由来の正答一意性・法令FAIL2を除外済み、親族図HOLD1。問題改変/法令の最終引用根拠と元PDFの全面比較は残る |
| Q2 学習機能 | **CHROMIUM E2E PASS／DEVICE PENDING** | 300問出題、解答、履歴の実ブラウザ検査PASS、iPhone実機の受験者テスト未完 |
| Q3 UI/オフライン | **CHROMIUM OFFLINE/JSON PASS／DEVICE PENDING** | ブラウザでバックアップ・Service Worker復旧PASS、端末Safe Area・VoiceOver・長文/図表・Golden Master実機比較未了 |
| Q4 独立受入 | **NOT TESTED** | 第三者/受験者相当の実機検証・障害復旧・完了記録未取得 |
| Q5 ビルド/ストア | **BLOCKED** | 新309→300のmacOS Simulator読戻し、署名IPA/実機TestFlight、ASC Version/Build/IAP/Privacy、サポート/プライバシーURL・スクショ、Apple登録アイコンとの一致・最終提出承認 |

**状態：BLOCKED／NOT_SUBMISSION_READY／NOT_SUBMITTED**。PR #5717はDraft、mainマージ・App Review提出禁止。AppIconのApple側未確認は既知の未検証事項であり、今回の新規欠陥ではない。

---


## 2026-11-23｜最新312/300プリフライト再分類（初回120問記録を置換）

**現行対象：canonical312・学科5回×60＝選定300（6分野×50）・内容PASS予備12・publishable0。** 初回120問および5a72059fのCI8/8は過去履歴。証拠正本：`audit/FP2_PREFLIGHT_312_CANONICAL_300_SELECTED_20261123.md`。

ソース判定対象 `38eeaee1e05831b9ff29e55e4bab2ae0db4794a9` のGitHub Check Runs読戻し：8件中 **SUCCESS6／未完了2／FAIL0**（2026-11-23 JST時点）。Chromium E2E×2、source静的×2、migration、registry auditがPASS。**macOS unsigned Simulator×2 はqueued/in_progressであり最新ヘッドのPASS未確定**。先行300問Simulator [45171875787](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45171875787) は別コミットでSUCCESS、参考扱い。監査記録反映後の新しいcommitにSUCCESS判定を自動継承しない。

| プリフライト分類 | 未了・対応 |
|---|---|
| **AUTO-FIX** | 300問スコープの旧120固定値やWeb/監査/選定ロックの機械不整合を自動修正してCI再実行。問題内容・正答を独断変更しない |
| **BUILD-REQUIRED** | 最新ヘッドmacOS CIの終了確認、署名IPA・組込300問バンクSHA・TestFlight配信・公開URL HTTP200確認 |
| **HUMAN-REQUIRED** | ASC App ID 6797228406、Bundle、Version 1.0.0/Build1、IAPなし、Privacy、アイコン・スクショ・メタデータ/URLのApple側現物、iPhone/iPad実機受入、原題二次利用・出典/改変・運営責任の最終承認 |
| **FINAL-APPROVAL** | Q0〜Q5を全通過後、PR #5717 Draft解除・Apple審査提出・公開の明示的ユーザー許可。現時点では未承認・提出禁止 |

**ゲート：Q0 BLOCKED、Q1 CONTENT PASS312/SELECTED300・PUBLICATION BLOCKED、Q2/Q3 Browser E2E PASS（現ヘッド）／実機未了、Q4 NOT TESTED、Q5 最新Simulator未完了／署名・ASC・TestFlight未了。**
**NOT_SUBMISSION_READY／NOT_SUBMITTED**。PR Draft・main未マージを維持。

---



## 2026-11-23｜312問／300問／予備12問・下書きPASS180・Simulator不具合修正（最新判定）

**正規バンク312問（全問独立内容監査PASS）、選定300問（学科5回分×60、6分野×50）、監査済み独自作成予備12問、公開承認0件を維持。** 下書き `questions/draft/fp2-recovered-180-fulltext-20261123.json` に、正規バンク該当180問のID・本文・4肢・正答・解説を照合して独立監査PASS180／FAIL0／HOLD0を同期。改変説明4件を正規バンクと揃え、修正済み5問の二次監査履歴・`correction_prior`は保持。内容監査PASSは公開許可ではない。

**PR #5717本文**を旧122/120・FAIL5未再監査から現行312/300/12・PASS180/0/0・拡充PASS120/0/0へ更新。PRは引き続きDraft、mainへのマージなし。

### `3116840cf6b7a3a4f88ac2ed172f40c999807ff5`のCI結果と修正

| CI | 実測 | Run |
|---|---|---|
| 正規バンク/静的Web | **SUCCESS** | [45169903628](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169903628) |
| Chromium学習フロー・300問・オフライン/JSON往復 | **SUCCESS** | [45169903733](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169903733) |
| Golden Master v2.1 migration | **SUCCESS** | [45169904527](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169904527) |
| App Release Registry audit | **SUCCESS** | [45169903611](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169903611) |
| macOS unsigned iOS Simulator | **FAIL（修正前）** | [45169903544](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169903544) |
| macOS unsigned iOS Simulator・300問payload | **SUCCESS（修正後）** | [45171875787](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45171875787) |

Simulator失敗理由①：旧120問選定JSONの `corrections_excluded_until_independent_reaudit` キーに必須アクセスし、300問台帳には当該キーがなく `KeyError`。安全な `.get(..., [])` の検証に変更。失敗理由②：iOSの生成スクリプトは実際に選定300問を内包したが、オフラインpayloadの `content_approved_questions=120` と `release_candidate_questions=120` が旧値のまま。両方300へ修正。**同一選定・同一正答のまま** 修正後CIで、オフラインバンク生成、XcodeGen、unsigned Simulator `xcodebuild`、コンパイル済みInfo.plist・同梱バンクのSHA/300件読戻しが**全ステップSUCCESS**。署名済IPA・配信済TestFlightの成功ではない。

### Q0–Q5更新後

- **Q0 BLOCKED**：日本FP協会等の公式問題二次利用許可条件への利用主体適合、出典・加工表記・第三者図版、2026-04-01法令・施行例外の最終承認。
- **Q1 CONTENT AUDIT PASS300/300、バンク312/312 PASS／RELEASE QUALITY BLOCKED**：独立監査証拠・改変記録・構造検査はPASS。試験原題との難易度同等性の追加疑義や表示/利用許諾は最終確認が必要。
- **Q2 CHROMIUM E2E PASS／DEVICE USER ACCEPTANCE PENDING**：実ブラウザで出題→回答→結果・目標・学習履歴まで成功。実際の学習者検証は未了。
- **Q3 CHROMIUM OFFLINE/JSON PASS／DEVICE UI PENDING**：35日ヒートマップ・JSONバックアップ往復・オフライン再読込成功。iPhone Safe Area/VoiceOver等未検証。
- **Q4 NOT TESTED**：独立利用者・iPhone実機の最終受入記録未取得。
- **Q5 UNSIGNED SIMULATOR TECHNICAL PASS／RELEASE BLOCKED**：最新実測の署名なしSimulatorビルドはPASS。署名IPAと実機TestFlight、ASC App ID `6797228406`、Bundle ID `com.allsunday1122.fp2manabisprint`、Version `1.0.0`／Build `1`、IAPなし、App Privacy、スクショ/URL・Apple側AppIcon一致の実物確認と明示的提出承認が残る。Apple側AppIconの未確認は既知事項で、新規欠陥とは扱わない。

**最終状態：BLOCKED / NOT_SUBMISSION_READY / NOT_SUBMITTED。** PR #5717 Draft維持、App Store Connect提出・mainマージなし。旧CIのPASSは固定したcommitに限る。実装変更後は当該新commitのCIを別途再確認する。

---


## 2026-11-23｜300問版・実測CI読戻し（前段の未実測記載を更新）

- **PASS** [FP2正規バンク/静的Webソース CI](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169448751)：ログでcanonical312、選定300、予備12、6分野×50、Git Blobピン及びソース整合、status=PASSを確認。
- **PASS** [Chromium学習・オフラインE2Eと7監査バッチ照合](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169448906)：実行ログに `batch_records=[20,20,20,20,20,17]` ＋再監査既存3、拡充PASS120/FAIL0/HOLD0、canonical312/selected300、原典5回×60、6分野×50、120問限定旧条件撤廃、埋込Web payload300とSHAの一致を記録。Chromium実画面操作はbank300/chapters6/sourceMetadata300、4問解答ループ・未着手優先・35日記録・JSONバックアップ往復・Service Workerオフライン再読み込み、pageErrors0、全PASS。
- **PASS** 同コミット [Golden Master v2.1静的移行ゲート](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169448763) および [Release Registry静的監査](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169448834)。
- **未確認** [iOS Simulator xcodebuildとコンパイル済みバンドル同一性](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169448845) は確認時queued。生成スクリプトの300問選定データとSHA/HTML埋込の比較は**Linux上でPASS**したが、macOS Simulatorからの成果物readbackはまだPASSとしない。
- 上記PASSは統合後の300問内容・Web実行のCI結果だが、実iPhone、署名IPA、Apple側AppIcon/ASC、Q0権利承認やQ4独立利用者受入には流用しない。**直近の表示ログ修正（E2Eの300問表記）のコミットでは別のCIが起動し得るため、常にコミットSHAとrun IDを対応付ける。**

**最新ゲート区分：** Q0=BLOCKED、Q1=CONTENT_AUDIT_PASS_300/300 + STATIC_INTEGRATION_PASS／PUBLICATION_BLOCKED、Q2=CHROMIUM_E2E_PASS／REAL_DEVICE_PENDING、Q3=WEB_OFFLINE_E2E_PASS／GOLDEN_MASTER_DEVICE_PENDING、Q4=NOT_TESTED、Q5=SIMULATOR_QUEUED／SIGNED_IPA_ASC_BLOCKED。全体 `NOT_SUBMISSION_READY`。

---


## 2026-11-23｜学科5回分300問の統合完了（最優先・旧120問履歴の上書きではない）

**最新版の実データ：canonical 312件、学科5回分の選定300件（5回分×60、6分野×50）、独自作成の内容監査PASS予備12件。** 現在までの監査は既存180問PASS180/FAIL0/HOLD0＋拡充120問PASS120/FAIL0/HOLD0＝**学科300/300内容監査PASS**。2024-05のQ01/Q02/Q06は既存正規3件を再監査して重複登録せず、新規のユニーク統合は117件。修正済2024-09 Q29は独立再監査PASS。全312件 `publishable=false`、公開承認0件。

**証拠の読戻し方法：** `audit/FP2_FIVE_EXAM_300_INTEGRATION_20261123.md` に6つの拡充ドラフトと7件の独立監査（2024-09 B01/02/03、2024-05 B01解消/B02/03/04）のGit Blob SHAと、**各itemsの件数・ID・正答・4肢・改変理由**の照合結果を記録。原題番号重複は2024-05 Q01/Q02/Q06の3件だけを既存側へ統合。新規117件は**modified=true**で、制作側改変説明と監査側の最終改変説明を両方保存し、監査側説明を正規バンクのmodification_noteに使用。公式PDFの全肢逐語比較や利用権限はQ0未完了。

| コンテンツ・実装 | 今回の実測・根拠 |
|---|---|
| 正規バンク | 312、blob `03b449dbe8a848b192bd970801846b18c486b1b4` |
| 正本選定 | `release/release-selection-300-20261123.json`、300件、5回×60・6分野×50 |
| 予備 | 独自作成12件、内容監査PASSだが非選定 |
| Webアダプタ | 300件、6分野×50を読み込む条件へ改修 |
| iOSオフライン生成 | canonical312を入力し、**選定300件のみ**をHTML・JSONへ書き出す設計（予備12件を含めない） |
| 静的ソースゲート | 312/300/12と5回分60件を判定するよう更新 |
| Chromium E2E | 300問ロード/各分野、解答・出典/改変・復習、35日履歴・JSONバックアップ/オフライン復元を検査するよう更新 |
| iOS Simulator CI | 312→300 payloadとSHA/正答レコード一致、Version 1.0.0/Build 1/IAPなしを検査するよう更新 |
| 新規監査回帰 | `scripts/fp2_five_exam_audit_gate.py` にバッチ7件のsource blob・改変判定・正答肢・監査証拠整合を固定 |
| AppIcon | Apple登録原本との一致は**既知未検証**。今回の新たな不具合ではない |

**300問版の新規CIがSUCCESSとなった証拠は別途読み戻す必要がある。** 過去の `5a72059f` におけるFP2 CI8/8 PASSは**旧120問版**に対する結果であり、312件バンク・300問アプリに流用しない。Web/Simulator/生成コードの変更は実装・保存済だが、実ビルドの完了を確かめずPASSとはしない。署名IPA／ASC／TestFlightは未着手。

### 最新Q0–Q5判定（内容監査PASSと製品承認を区別）

| ゲート | 現行判定 | 未了 |
|---|---|---|
| Q0 | **BLOCKED** | 日本FP協会の利用許諾/改変表示/運用主体、2026-04-01時点の原典法律・図表 |
| Q1 | **CONTENT AUDIT PASS300/300、RELEASE QUALITY BLOCKED** | 統合300問の難易度/教育価値・出典逐語比較、最新CI証拠 |
| Q2 | **E2E CI RESULT PENDING** | 300問版解答・採点・弱点復習のブラウザ結果 |
| Q3 | **E2E/DEVICE NOT VERIFIED** | オフライン・復旧・300問データ/UI/Golden Masterの実際の結果 |
| Q4 | **NOT TESTED** | 独立利用者/実iPhoneによる300問版受入 |
| Q5 | **BLOCKED** | iOS Simulatorビルド、署名IPAとpayloadハッシュ/ASC・TestFlight・プライバシー・スクショ・AppIcon確認 |

**結論：BLOCKED / NOT_SUBMISSION_READY / NOT_SUBMITTED。** PR #5717 Draft、mainマージ・App Review提出・ASCログインなし。

---


## 2026-11-23 20:44 JST｜5a72059f CI 8/8 SUCCESS・preflight区分更新（今回の追記）

**検証対象固定：** `5a72059f69e77375dbfa6568f613362a2712cc75`。GitHub check-runsを実際に再取得し、FP2 **8ジョブすべてcompleted/success、queued=0** と確認。Chromium E2E×2、iOS unsigned Simulator×2、正規bank/Web静的×2、UI Master v2.1 migration×1、Registry audit×1。ジョブURL・8件の監査証拠：`audit/FP2_PREFLIGHT_CI8_HUMAN_REQUIRED_20261123.md`。対象コミット以後の変更に自動的にPASSを拡張しない。関係のないアプリのActions失敗はFP2 8ジョブの判定に含めない。

**CI部分ゲート：PASS（5a72059f）／製品Q0–Q5：未通過。** 初回版は正規195問（独立回収180 PASS＋先行15）、選定120問（6分野×20）、予備75問、公開許可0。300問への拡充は別ブランチの将来計画であり、このCIを新120問や300問版の合格証拠にしない。

| 分類 | 判定 | 証拠／残件 |
| --- | --- | --- |
| 問題バンク・静的Web・UI migration | **CI_PASS_AT_5a72059f** | GitHub 8ジョブ中の4件。権利許諾ではない |
| Chromium学習・オフライン | **CI_PASS_AT_5a72059f** | 実ブラウザE2E 2件。実iPhone受入とは別 |
| iOS Simulator | **CI_PASS_UNSIGNED_AT_5a72059f** | 2件。署名IPA・TestFlight・ASC readbackは未了 |
| Registry監査 | **CI_PASS_AT_5a72059f** | 1件。App Store Connect登録内容までは検証していない |
| AppIcon内部の旧FP2原典一致 | **INTERNAL_PASS** | Blob `ce0cb5bc61296d7ca2ebde213c729ae5d1e4ab9d`、SHA-256 `d456178b2a7b04f180e39b3ad62f5c194832e85aa15102bf6452751551db8033` |
| App Store Connect側AppIcon一致 | **HUMAN-REQUIRED** | Apple側現物との一致は未確認 |
| Q0 権利・利用主体・公開許可 | **BLOCKED** | 法令/公式過去問利用条件・改変注記/出典の運営者最終承認 |
| Q1 正規バンクの公開ゲート | **CONTENT CI PASS / RELEASE BLOCKED** | 195問中120選定済、公開許可0のまま |
| Q2/Q3 Web学習とUI | **BROWSER CI PASS / DEVICE ACCEPTANCE PENDING** | 実機Safe Area、長文、アクセシビリティ、利用者受入未了 |
| Q4 独立受入 | **NOT COMPLETED** | 第三者/実機・学習者受入記録未了 |
| Q5 配布・ストア | **BLOCKED** | 署名IPA/実機TestFlight/ASC/App Privacy/スクショ/公開URL |

**HUMAN-REQUIRED更新：** (1) ASC側のAppIcon一致とApp ID `6797228406`、Bundle ID、Version `1.0.0`／Build `1`、IAPなし、App Privacy、ストア表示、サポート/プライバシーURL、スクリーンショットの登録確認・責任者承認、(2) 署名・TestFlight配布後のiPhone/iPad実機受入と証拠、(3) 問題・出典/改変の二次利用権限と運営者責任の最終承認、(4) Q0–Q5を完了した後の明示的なApp Review提出許可。**既にCI PASSの8ジョブを人手で再実行することはHUMAN-REQUIREDから除外**。

**技術側で未了：** 署名IPAの生成と実配布物SHA照合、Apple連携経路、公開URL HTTP200、必要な実機/独立E2Eの証拠整備。**PR #5717はDraft維持／main未マージ／Apple未提出／NOT_SUBMISSION_READY**。

---


## 2026-11-23 19:42 JST｜5回分・学科過去問300問への拡充計画（最新方針）

**承認されたのは将来スコープの変更・受入計画の記録のみ。新規120問は未受領・未監査・未統合。現行120問リリース候補・出題数は凍結。** 正式詳細は RELEASE_SCOPE_20261124.md「拡充方針」を正本とする。

| 指標 | 現行・実績 | 将来計画 |
|---|---|---|
| 学科過去問回次 | 2026-05／2025-05／2025-01の3回 | 2024-09・2024-05を追加し**5回分** |
| 学科過去問の原題候補 | 180問＝60問×3、独立内容監査PASS180/FAIL0/HOLD0 | **300問＝60問×5、うち新規120問** |
| canonical監査PASS総数 | **195問＝回収180＋先行15** | **未確定**。既存15問に2024-05由来の加工3問があるため重複排除と内容/権利の再照合が必要 |
| リリース選定 | **120問＝6分野×20** | **監査PASSした5回分300問全問の選定を計画**。PASS不足・重複・権利問題があれば300達成とはせず再監査/選定再設計 |
| 監査済み予備 | **75問**（監査PASS） | 将来の余剰PASSや先行15問を再区分。FAIL/HOLD/未監査は**隔離/非採用・除外**（PASS予備扱い禁止） |
| 現行バンドル・CI | **120問限定**、各種CIの最終結果は直前の技術監査参照 | **300問版への固定数・キャッシュ・SHA・Simulator/ブラウザE2Eの明示的移行はまだ実施しない** |
| 公開可能 | **0問**、publishable=false | Q0–Q5及び権利/ASC最終承認を経るまで**0問扱い** |

**統合受入の前提**
- 新規2024-09/2024-05各60問は**別ブランチの拡充制作セッション**が原題データ化・一次資料と正答照合・改変/権利情報付与・独立監査を実施。完成後の**ブランチ・コミットSHA・証拠台帳・PASS/FAIL/HOLDのID一覧を読戻してから**、このリリースブランチを統合先として受け入れる。統合元ブランチ名/コミットは現時点で未確定。
- 失敗・未監査・HOLDは予備候補の隔離台帳に履歴保存してもよいが、**監査済みPASS予備にも出題選定にも算入しない**。監査PASSに修正されるまで選定不可。内容PASSでも二次利用条件と2026-04-01法令適用は別ゲート。
- 2024-05の先行加工3問との**原題ID・同一出題の重複**を検査し、総数を単純に195+120=315として確定しない。目標は「学科5回分300問」、補助問題15問は採否/別予備を独立管理する。
- 明示的なスコープ切替指示と検証完了まで、**release-selection-120-20261123.json、canonical195、iOS120問payload、Version 1.0.0／Build 1／IAPなし、PR #5717 Draftを変更しない**。App Review提出・mainマージをしない。

**追加ゲート工数・依存**
- **Q0 BLOCKED**：2024-09/2024-05公式出典・模範解答・二次利用/改変条件、2026-04-01基準の法改正差分、図表・2024-05既存加工3問の関係を拡張確認。
- **Q1 現行180/180 CONTENT PASS／新120 NOT TESTED**：新120の4肢・正答一意・各肢根拠・重複/改変を独立監査し、全300の統合後監査を実施。300問版のQ1全通過はまだ成立しない。
- **Q2/Q3 現行E2E未確定／300問版NOT TESTED**：学習目標/回次別選択、未着手・復習・保存、端末負荷と35日ヒートマップ、PWA/オフラインの300問実操作検証が増える。
- **Q4 NOT TESTED**：300問版の独立受験者ユーザビリティ・復旧・実機受け入れを別途実施。
- **Q5 BLOCKED**：300問版の選定/発行ゲートに既存120固定のWeb/CI/iOS生成・容量・バンドルSHA/署名・TestFlightの更新が必要。現時点では**意図的に120固定のまま**。ASCのメタデータ・プライバシー・スクショ・最終承認も必要。
- AppIconの正規一致は既知未検証事項を継続し、新しい不具合扱いしない。

**全体判定：BLOCKED / NOT_SUBMISSION_READY / NOT_SUBMITTED。** スコープ決定はQ0–Q5の品質通過ではなく、300問配布の許可でもない。

---


## 2026-11-23 19:15 JST｜最新CI読戻し・安全修正（後続の最優先正本）

**対象ブランチ：** `feature/fp2-release-scope-20261123`。前回報告の先端 `b7495370d98019f7865856197a4875abab21f653` は今回の検査開始時も先端と一致していた。そのコミットのGitHub Actions 5件を直接再読込したところ、静的ソース検査 `45153039021`、Chromium学習/オフラインE2E `45153039020`、Golden Master移行ゲート `45153039061`、Release Registry監査 `45153039116`、iOS Simulator `45153039083` は全て **queued / conclusion=null** で、成功や失敗は未報告だった。**queued をPASS/FAILに置き換えない**。終了していないジョブに失敗ログがないことも確認。

**再点検で確定したテスト環境の不整合：** WebのService Worker登録条件はHTTPSまたはhostname=`localhost`だけだったが、Playwright E2Eは`http://127.0.0.1:8765`を使用していた。そのままだとWorkerが登録されず、オフライン復旧E2Eが誤って失敗・待機する。アプリ側でHTTPS/localhostに加え標準ループバック `127.0.0.1` を許可（安全なローカル検証範囲のみ）。`fp2-manabi-sprint/index.html` Git blob `6a927616d94252e0bebcbc2df694c60b360dfbb9`。source lockも同じblobへ更新。コードレビューでは修正確認済み、ブラウザでの実行PASSではない。

**修正後CI再起動：** `ffe4119dbe40f1d426f1b8e3f05622e39119cf97`（Service Worker条件修正）、`e93af7a915d2e51d307b882472e108b0075a792c`（bundle source SHA再固定）。GitHub Actionsはpush/PRトリガーで再実行される定義。**修正後の最新コミットの全ジョブがSUCCESSとなったことは未読戻し**。元のrunが未完了なので既知のビルドFAILの修正を行ったという意味ではない。最新のrun URLを後続で読み戻すこと。

**ソース構造検証の事実：** canonical195問／初回120／予備75、回収独立内容監査PASS180・FAIL0・HOLD0、公開承認0は前回と同一。ソースバンク `270b82b493f54a07316b1c7ed47fb196405e832d` は selection と bundle-lockのSHA固定値に一致（今回のHTML修正はバンク内容/出題120のIDを変更していない）。iOS生成スクリプトは120問だけを抽出・予備75問除外する設計だが、**実際の生成・ハッシュ照合とmacOS SimulatorビルドのCI完了結果は未確認**。

### CI結果（未完了を明記）

| 検査 | 最新実測 | 備考 |
|---|---|---|
| 静的ソース・全選定120品質 | **QUEUED / NOT VERIFIED** | 先端run `45153039021`。過去commitのPASSは現先端に代用しない |
| Chromium学習E2E | **QUEUED / NOT VERIFIED** | 先端run `45153039020`、Service Worker条件を修正して再トリガー |
| Webオフライン復旧/JSON復元 | **NOT VERIFIED** | 上記実ブラウザE2E内の検査、PASS報告なし |
| iOS Simulatorビルド | **QUEUED / NOT VERIFIED** | 先端run `45153039083`、署名IPAとは別 |
| iOS 120問生成・バンクSHA/埋込JSON検査 | **NOT VERIFIED** | CIに検査を実装、実行完了待ち |
| AppIcon | **KNOWN UNVERIFIED, NOT NEW DEFECT** | ユーザー指定どおり既知の不確定事項を維持 |

### Q0–Q5最新ゲート

- **Q0 BLOCKED**：権利利用主体・法令基準と実配布表示の承認未了。
- **Q1 CONTENT AUDIT PASS180/180、RELEASE GATE BLOCKED**：選定120の原典再検討・教育品質と現ブランチ最新CIは未確定。
- **Q2 NOT TESTED / E2E RESULT PENDING**：学習フローの実ブラウザ操作がSUCCESSと確証されていない。
- **Q3 STATIC PASS (older source only) / LATEST BROWSER E2E NOT VERIFIED**：オフライン条件バグのコード修正済、回帰テストが必要。
- **Q4 NOT TESTED**：実機受け入れ及び独立利用者の検証未了。
- **Q5 BLOCKED**：最新Simulator CI、署名IPA、TestFlight、ASC実物・プライバシー・スクショ未確認。

**Actual `BLOCKED / NOT_SUBMISSION_READY / NOT_SUBMITTED`**。ユーザーの最終承認待ちへ遷移させない。PR #5717 Draft、mainマージ・App Review提出・App Store Connectログインを行わない。

---

## 後継コーディネーター追加技術検証（2026-11-23・現行正本）

**Actual: BLOCKED / NOT_SUBMISSION_READY / NOT_SUBMITTED.** PR #5717 Draft。mainマージ・ASCログイン・App Review提出なし。

### 確認済みソース・品質

- 正規バンク195問、独立内容監査回収180/180 PASS、初回120問=6分野×20、予備75問、publishable=0。GitHubで正規bank blob `270b82b493f54a07316b1c7ed47fb196405e832d` とrelease-selectionおよびsource lock内のSHAが一致。
- 選定120問の追加構造検査：全問の独立監査PASS、4肢・正答indexとone-based番号、解説・改変理由、原典HTTPS・出典箇所・法令基準日、選定ID/6分野固定を読戻し確認。**これは内容監査の独立再実施ではない。** 似た一般設問文が2問存在するが選択肢/問番号は異なり、完全重複認定していない。
- 独自作成12問の出典団体名を明示するメタデータを補完。一次資料は従来のURL・出典箇所を保持。元の正答・問題内容・release selectionは変更なし。
- `index.html` の毎日スプリントを先頭固定n問から未着手優先へ改善し、Service Workerのキャッシュ名を `fp2-manabi-20261123-195-v2` に更新。Web index blob `ee488a452032b65f3934f20080a1718dc620bb3e` はsource lockに一致。
- iOSビルド元の検査矛盾（195問にもかかわらず194件を要求、Q20 PASSを誤って不許可）を修正。
- iOS生成方式を変更：GitHub canonical 195問を検証したうえで**配布用オフラインpayloadは選定120問だけ**に縮約し、予備75問はiOS資産へ同梱しない。source/selection/配布payloadのID+全レコード一致・埋込JSON一致・SHA256検証をCIに追加。これは **生成スクリプトとCIテストの実装完了**であり、最新ビルドの実測PASSと同義ではない。

### 実ブラウザ・iOS検証（CI実行状況）

- Chromium Playwright実画面E2EをGitHub Actionsに追加：120問ロード、6分野表示、4問設定、回答→正誤→解説/出典・改変表示→結果、未着手優先、35日ヒートマップ、JSONエクスポート/リセット/インポート、Service Workerオフライン再読み込みを実操作する。直接接続ブラウザは拡張コンテキスト未提供で操作できず、**GitHub Actions内の実ブラウザ実行に代替**。最終結果の成功読戻しまで **E2E NOT VERIFIED**。
- 選定120問品質の全件チェック `scripts/fp2_selected_quality_gate.py`、native 120-only payload/HTML embedded bytesチェックをブラウザCIの先行ステップに追加。これらも **最新CIの終了読戻しが必要**。
- 統合後macOS/iOS Simulator CIにpull_requestトリガーを追加し、Version 1.0.0／Build 1／IAPなし／Info.plist・120-onlyバンドルとcanonical 195の選定投影一致を確認する設定に変更。**実ビルドSUCCESSはまだ未確認**。署名済みIPA・TestFlight・iPhone実機は未検証。
- GitHub Actionの実行例：Browser E2E `45152519247`、Simulator `45152519257`（2026-11-23 19時前後の取得時点でqueued。完了結果未取得）。後続のcommitで再起動したジョブの最終状態を別途確認すること。
- AppIconの正規登録資産とのハッシュ一致は**既知の未検証事項**。今回の追加不具合として扱わない。

### 再判定

| Gate | 判定 | 最新の残留条件 |
|---|---|---|
| Q0 | **BLOCKED** | 権利利用主体・法令2026-04-01適用・原典加工の最終確認、実画面の最終承認 |
| Q1 | **CONTENT PASS180/180／追加データ構造チェックPASS、最終Q1 BLOCKED** | 全120問の二重の意味内容・難易度・同等性を独立最終検証。静的CI新コード読戻し |
| Q2 | **NOT TESTED（E2E実行中・完了未確認）** | Playwright実学習フローと実機の回答/復習受け入れ |
| Q3 | **STATIC PASS (prior source)／BROWSER-OFFLINE E2E NOT VERIFIED** | Chromium結果読戻し、iPhone/PWA/Golden Master実画面確認 |
| Q4 | **NOT TESTED** | 別担当者・利用者の独立受入、復旧/実機障害確認 |
| Q5 | **BLOCKED（native CI結果待ち）** | macOS Simulator PASSの読戻し、署名済IPA・実配布payload/ASC/スクショ・公開URL・プライバシー最終確認 |

**ChatGPT側の残作業**：最新CI E2E/Simulator/原典・source/payloadゲートの終了結果を読戻してFAILがあれば修正し再実行、残るブラウザGolden Master・復元/学習動線検証、初回120問の高リスク論点の追加内容独立検査、署名IPA以外のWeb・メタデータ整合の確認と記録。

**ユーザー・運用者の残作業**：権利/運用主体判断、ASCログイン/アプリ識別子・プライバシー・公開URL・IAP/Version/Buildの照合、署名済ビルド/TestFlightのiPhone実機受入と証拠、最終ビルドを特定した明示承認。これらをChatGPTの未検証コード修正と混同しない。

**旧CIの注意**：2026-11-23の静的検査SUCCESS（例 `45150492137`）は新しいnative 120-only資産とPlaywrightを検査したものではなく、最新commitのCI成功の代用に使わない。

---

**状態: BLOCKED / NOT_SUBMISSION_READY / NOT_SUBMITTED。** 目標期限 2026-11-24 08:00 JST。PR #5717 Draft維持。mainマージ、App Store Connectログイン、Apple審査提出は行わない。

## 監査済み最終コンテンツ状態

| 項目 | 最新値・証拠 |
| --- | --- |
| 回収180問の独立内容監査 | **PASS 180 / FAIL 0 / HOLD 0**（高リスク修正済み5問の再監査完了） |
| 先行独立PASS問題 | 15問 |
| 正規バンク | **195問**（180+15、全問 `publishable=false`） |
| 初回選定 | **120問＝6分野×20問（ID変更なし）** |
| 監査済み予備 | **75問**（Q20は予備のみ） |
| 本番公開承認済み | **0問**（内容PASSと権利・リリース承認は別） |
| Q20最終監査 | `audit/FP2_2025_01_Q20_SECOND_CORRECTION_REAUDIT_PASS_20261123.md`、blob `bccab94170391e9074b021fcee2125b3b5d64bf7`、第2次解説PASS |
| 固定識別子 | App ID `6797228406` / Bundle `com.allsunday1122.fp2manabisprint` / Version `1.0.0` / Build `1` / IAPなし（ASC未照合） |

Q20の登録正答③、原題4肢、修正履歴2件を維持し、下書きの再監査PASSおよび監査証拠SHAと、正規バンクの監査PASS・非公開の予備フラグを一致させた。

## Q0–Q5 現状

| ゲート | 最新判定 | 残る証拠 |
| --- | --- | --- |
| Q0 | **BLOCKED** | 使用主体・出典表示・改変の法的利用条件、2026-04-01制度適用、予備原題PDF対照 |
| Q1 | **CONTENT PASS 180/180、RELEASE QUALITY BLOCKED** | 初回120の難易度・カリキュラムと再現可能な出典点検、バンク及び表示挙動の独立受入 |
| Q2 | **NOT TESTED** | 出題→解答→解説→復習・保存の実操作検証 |
| Q3 | **静的ゲートPASS／実機E2E NOT TESTED** | 4/8/16問目標、5週間ヒートマップ、3/4タブ遷移、PWA/JSON/オフライン、Golden Master実画面 |
| Q4 | **NOT TESTED** | 独立ユーザー受け入れ・障害ケースと復旧テスト |
| Q5 | **BLOCKED** | 最終コミットのiOS Simulator/署名IPAと埋込バンク一致、TestFlight・ASC・プライバシー・公開URL・スクショ |

## ChatGPTがまだ実施できる作業（ユーザーの最終承認を必要としない）

1. 最終ブランチの静的CI・iOS Simulator CIを読戻し、落ちた検査・版固定不整合を修正する。特にcanonical Git Blob SHA/選定120・予備75/オフラインWebバンドルのバイト一致を検証する。
2. Webブラウザ・自動E2E（利用可能な環境範囲）の学習動線、出典/改変表示、バックアップとオフライン復元、エラー処理を検証・修正する。iPhone実機・署名IPAの検証済みと混同しない。
3. 初回120問について公式原典・現行法・学習難易度・出典表示の最終独立品質検査を可能な範囲で追加し、残留する権利判断事項を明文化する。
4. Release Registry、Release Scope、Q0–Q5、PR #5717とCI証拠、署名済みバンドルのSHAが一致するまで記録と自動検査を改善する。公開/提出・mainマージはしない。

## ユーザーによる確認・最終操作（または明示的権限を持つ運用者）

1. **権利・運用主体の最終判断**：日本FP協会等の問題使用条件、問題文・図表・出典・改変の実表示、アプリ提供主体、保険/法律関連解説を2026-04-01基準で採用することを承認。
2. **App Store Connectへログインして実物読戻し**：App ID `6797228406`、Bundle ID、Version 1.0.0、Build 1、IAPなし、App Privacy、サポート/プライバシーURL、公開メタデータ、必要サイズのスクリーンショットを確認。
3. **署名済みビルド/TestFlightの配信・実機受け入れ**：実際にiPhoneへインストールし、120問/6分野・回答/解説/復習・表示・オフライン・データ復旧・設定を確認。結果の画面・端末/ビルド識別子・不具合を証拠化する。署名と配信自体は利用可能な権限/CIの範囲でChatGPTが支援できるが、実機判断は代行できない。
4. **最終承認**：Q0–Q5が証拠付きで通過した後、App ID/Version/Buildと最終差分を特定して明示的に承認する。承認前のApp Review提出をしない。

**重要**：全問題の `publishable=false` を保ち、内容監査180/180 PASSだけで `SUBMISSION_READY` と宣言しない。

---

## 最終静的CI読戻し（Q20第2次PASS反映後）

コミット `f2ff66a22b8047c63dea8319c83ca164c0a36a99` で以下のPRチェックを確認。
- **PASS** FP2 canonical bank and web source preflight: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45150492137 （静的問題バンク・出典/証拠Blob SHA・source asset lock・6分野×20・web shell/JS）
- **PASS** FP2 Golden Master v2.1 migration gate: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45150492115
- **PASS** App Release Registry Audit: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45150492026
- バンク合計195、初回120、予備75、回収内容監査180/180の静的ゲート。**iOS署名済IPA・実配布バンドルのビット同一性・実機動作・ASC読戻しは未検証。** CI成功は公開可能判定を意味しない。

## 過去の履歴（以下は旧判定・旧件数であり現行状態を上書きしない）

## CI evidence after corrected PASS4 integration (2026-11-23 JST)

For commit `313d0614bb0640d71afe0abbc3fae68f04c81c3e` (bank and source-lock final), GitHub PR checks read-back:
- FP2 canonical bank and web source preflight **SUCCESS**: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45149246610. Log: content 194, selected 120, reserve 74, six domains x 20, seven pinned assets; `errors=[]`, `status=PASS`; JS syntax / v2.1 migration static check PASS.
- FP2 Golden Master v2.1 migration gate **SUCCESS**: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45149246573.
- App Release Registry Audit **SUCCESS**: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45149246631.
- iOS-native simulator push CI on this latest head, signed IPA and distributed payload **NOT VERIFIED**. Source static bundle-pin equality is verified; iOS executable bundle SHA and TestFlight remain **NOT TESTED**. This is not SUBMISSION_READY.

## Corrected FAIL5 follow-up / canonical 194 (2026-11-23 JST)

Independent re-audit: `audit/FP2_FAIL5_CORRECTED_INDEPENDENT_REAUDIT_20261123.md` (blob `26f92519480b8c32f44d246440b556a176b472af`). Recovered 180: **PASS179 / FAIL1 / HOLD0**. Four corrected PASS (2025-05 Q36/Q39, 2025-01 Q17/Q13) are admitted to the **content-reviewed reserve only**, not the 120-question release selection. Canonical **194** = 120 selected + 74 reserve; all `publishable=false`. Original 120 IDs unchanged.

2025-01 Q20 (`fp2-2025-01-gakka-020`) still **FAIL**. Explanation re-corrected to distinguish covered lightning loss and covered specified boiler explosion/rupture from excluded fire and fire-caused explosion/rupture; old text preserved in draft `correction_prior`; answer ③ unchanged. **Re-audit pending and excluded from canonical, release selection and bundle.** Prior PASS4 evidence must not be treated as Q20 PASS.

Q0 BLOCKED (operator rights, final provenance); Q1 BLOCKED FOR FINAL RELEASE (Q20 quarantined; release 120 content PASS, integrated CI verification pending); Q2 NOT TESTED; Q3 FAIL/DEVICE E2E NOT TESTED; Q4 NOT TESTED; Q5 BLOCKED (signed IPA, TestFlight/ASC and device evidence missing). CI workflow updated to assert 194/120/74, exact offline bank bytes and SHA256, but passing run after latest head must be independently read back. **NOT_SUBMISSION_READY / NOT_SUBMITTED.**


## Coordinator handoff / post-native integration (2026-11-23 18:34 JST)

**Actual: BLOCKED / NOT_SUBMITTED / NOT_SUBMISSION_READY.** Target: SUBMISSION_READY / WAITING_FINAL_APPROVAL by 2026-11-24 08:00 JST; target is not achieved or asserted.

- Native SwiftUI/WKWebView wrapper merged into release branch via PR #5718, merge commit `e27238a8f20f4d1f2377c67c1a46ae0eaa6b9a6b`. PR #5717 remains the only main-target release PR and must remain Draft.
- App ID 6797228406; bundle `com.allsunday1122.fp2manabisprint`; planned version 1.0.0/build 1; IAP none. Simulator CI success applies to the earlier native branch, **not** an attestation of the integrated commit, signed IPA or App Store Connect state.
- Canonical content PASS 190, release selected 120 (six domains x 20), reserve 70, publishable 0. Five corrected FAIL explanations remain isolated and pending independent re-audit. No unreviewed corrected question may enter the 120.
- Q0 **BLOCKED**: business rights holder/operator authorization, legal-currentness, visible source and modification disclosures not finally accepted.
- Q1 **BLOCKED**: five corrected FAIL re-audit pending; exact integrated release bank and offline payload consistency not yet revalidated.
- Q2 **NOT TESTED**: real learner answer/explanation/review loop not verified.
- Q3 **FAIL / DEVICE E2E NOT TESTED**: static UI success is not browser/iPhone Golden Master, 4/8/16, backup, or offline/PWA recovery verification.
- Q4 **NOT TESTED**: independent acceptance and actual-device evidence missing.
- Q5 **BLOCKED**: post-merge native CI, signed IPA/payload hash, ASC App ID/Version/Build/IAP/Privacy read-back, screenshots, live public URLs, TestFlight evidence missing.
- User-only final steps: (1) ASC login and App ID, bundle, version/build, IAP/privacy and public URLs verification; (2) signed build/TestFlight installation and iPhone acceptance with screenshots and evidence; (3) confirm reuse rights, source/modified notices and operating entity; (4) explicit final approval after Q0–Q5 pass. No ASC login, App Review submission, or main merge performed.


**Actual: BLOCKED / NOT_SUBMITTED / NOT_SUBMISSION_READY**。初回提出期限目標：2026-11-24 08:00 JST。
最終統合証拠：`audit/FP2_180_FINAL_175PASS_5FAIL_120_SELECTION_20261123.md`。以下に続く過去履歴の古い件数は現行状態ではない。

| Gate | 最新判定 | 根拠・未了 |
| --- | --- | --- |
| Q0 | BLOCKED | 官方公開原題の出典・加工注記は初回候補120に記録済み。権利利用主体の最終確認、現行法/図表/説明の最終証拠、実配布表示の立証未了 |
| Q1 | BLOCKED（内容監査PASS190） | 回収180の最終PASS175/FAIL5/HOLD0、先行15のPASSを含めcanonical190。初回6分野×20=120選定、内容PASS予備70。修正済FAIL5は再監査未了 |
| Q2 | NOT TESTED | 学習者の実練習/定着フローの操作検査未了 |
| Q3 | FAIL（静的検査PASS） | 4タブ・目標・PWA・JSON出入力は実装。ブラウザ/iPhone/Golden Master実画面検証未了 |
| Q4 | NOT TESTED | 製品全体の独立受け入れ/E2E未実施 |
| Q5 | BLOCKED | iOS専用署名IPA/本番バンドル一致/ASC Version Build IAP/Privacy/公開ページ/実スクショ未確定 |

**Canonical**: `questions/canonical/approved-questions-20261123.json` = 190 content-PASS, `release_selected=true` 120 (各分野20), reserve70, release_clear=0。
**変更判定**: 初回候補120は原典内容/改変確認の暫定項目なし。予備61問の modified は暫定分類でPDF全字比較未了。原典の改変は出典と具体的変更説明を記録。
**修正FAIL**: 2025-05 Q36/Q39, 2025-01 Q17/Q20/Q13 の5問を解説修正し独立再監査待ちへ隔離。問題文/4選択肢/正答番号は不変。
**初回選定正本**: `release/release-selection-120-20261123.json`（120 IDs, 70 reserves）。
**ソースSHA**: `release/bundle-lock-20261123.json`。IPA一致は未実証。
**CI**: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45147284570（内容・UI静的・JS構文SUCCESS）。
**PR**: #5717 Draft、mainマージ/Apple審査提出禁止。

---

## 過去履歴（現行判定ではない）

## 2026-11-23 read-only source inspection
Direct inspection of the current branch's `fp2-manabi-sprint/index.html` confirms obsolete v1.3 description, 8-question UI-only marker, 600-question placeholder, and missing v2.1 markers / 4-8-16 control / heatmap / JSON import. Q3 therefore FAIL, not merely an untested assertion. `scripts/fp2_v21_migration_gate.py` was updated on this branch to remove the obsolete hard-coded 600-question requirement; running the full Python validator in CI is still pending.

## Batch A evidence 2026-11-23
- Draft: `questions/draft/fp2-original-20261123-a.json` (6 domains x 2, 12 questions, not shipped)
- Audit: `audits/FP2_ORIGINAL_BATCH_A_AUDIT_20261123.md`
- Source desk-check provisional 12; rights final review and independent content review pending. No independent workers were launched. Current draft PR #5717 must not be merged as submission ready.

## 2026-11-23 Q0 rights-policy update
Both official entities affirm conditional reuse of publicly released common 2nd-grade academic exam questions, with source attribution, modification disclosure, and exclusions. Remaining batches should prioritize authorized official past questions. Third-party FP2過去問道場 content, explanations, wording and datasets must not be copied. This policy verification does NOT approve any specific new question; current Q0 remains BLOCKED. Source: `audits/FP2_Q0_OFFICIAL_PAST_EXAM_RIGHTS_20261123.md`.

## 2026-11-23 second batch update
- Original draft A 12 records: L02 now cites Japan Pension Service's direct `合算対象期間` explanation; all 12 `source_section` descriptions made specific, including correction of E01's previously inapposite source.
- First official past-exam draft B01 3 records, sourced to JAFP 2024-05-26 second-grade academic examination Q1,Q2,Q6 with original law cutoff 2023-10-01 and target 2026-04-01; question-level source, modification notices and original explanations included.
- New records are only in `questions/draft/fp2-official-202405-b01.json`; audit `audits/FP2_OFFICIAL_BATCH_B01_AUDIT_20261123.md`. No UI integration, no independent review, no release approval. Q0 and Q1 remain BLOCKED.

## 2026-11-23 Drive 180 source-only import
Live Google Sheet `AUDIT_MATRIX_FP2.csv` A1:I181 yielded 180 IDs (2026-05, 2025-05, 2025-01 each 60). All have historical answer/source URLs and legacy transcription/explanation flags, but source sheet lacks question stem, option texts and actual explanations. **180 metadata records imported; 0 complete questions imported; 180 current-law reviews NOT TESTED.** Quarantined `questions/draft/fp2-drive-matrix-180-source-index-20261123.json`, audit `audits/FP2_DRIVE_180_REUSE_EVALUATION_20261123.md`. Never count these 180 source-only entries toward release bank; Q0/Q1 BLOCKED and no submission readiness.

## 2026-11-23 full-text corpus recovered (supersedes source-only import as available draft data)
Actual source: `feature/fp2-kakomon-coach:fp2-kakomon-coach/questions/question_bank_fp2.json`. 180 complete structured questions matched 180 Drive source-index IDs with **zero metadata discrepancies**. Draft import: `questions/draft/fp2-recovered-180-fulltext-20261123.json`. Audit: `audits/FP2_180_FULLTEXT_RECOVERY_AUDIT_20261123.md`. Legacy audit flags are not independently reverified; all `modified` values remain null until official PDF text comparison; all current-law review statuses `NOT_TESTED`; 11 figure/exhibit keywords flagged. **180 recovered / 0 independently approved / 0 in app.** Q0/Q1 BLOCKED, no submission.

## 2026-11-23 2 corrections and fail-closed canonical bank
- 2026-05 Q14: official premium table restored (old general 10万円, old + new individual pension 10万円 each, no nursing medical); correct answer 3=10万円, original bank's erroneous 12万円 rationale removed; modification=true with precise note.
- 2025-01 Q34: original spouse income threshold 48万円 changed to 58万円 per 2025 reform, answer 4 retained; modification=true with precise note.
- Both original errors preserved in `correction_prior` and are `FAIL_CORRECTION_AWAITING_REVIEW`, not approved.
- Specified independent audit `audits/FP2_RECOVERED_180_INDEPENDENT_BATCH01_30_20261123.md`: 404 on target branch. Prior 15 draft questions remain HOLD. No source evidence of the 28 other purported PASS IDs; therefore cannot certify their modified status or release inclusion.
- Canonical approval placeholder: `questions/canonical/approved-questions-20261123.json`: verified count **0**, BLOCKED_INDEPENDENT_EVIDENCE_MISSING. This is not a shipped question bank. Full 180 draft has 2 individually documented modified=true, 178 modification flags still unverified/null, all quarantined.
- Audit record: `audits/FP2_FAIL2_CORRECTION_20261123.md`. Q0/Q1 blocked, SUBMISSION_READY prohibited.

## 2026-11-23 canonical content-PASS rebuild from singular audit/ folder
- Independent review files: `audit/FP2_INDEPENDENT_REAUDIT_15_20261123.md` (15 PASS), `audit/FP2_RECOVERED_180_INDEPENDENT_BATCH01_30_20261123.md` (24 PASS/2 FAIL/4 HOLD), `audit/FP2_RECOVERED_180_INDEPENDENT_BATCH02_30_20261123.md` (26 PASS/0 FAIL/4 HOLD). Together: **65 independent CONTENT-PASS**, 10 excluded (2 corrected FAIL awaiting new review, 8 HOLD), 120 unreviewed recovered questions.
- Canonical `questions/canonical/approved-questions-20261123.json` now contains **65 distinct content-PASS records** (15+24+26); each records its audit evidence path and blob SHA. `publishable=false` for all records; content approval does not imply final release approval.
- 50 recovered PASS still require source-vs-PDF `modified`/`modification_note` confirmation (not fabricated), plus legal/rights/attribution/UI/bundle gates. This replaces the earlier zero-question fail-closed placeholder, which was based on the incorrect plural `audits/` location.
- Q0/Q1 final release gate remains BLOCKED, no App Review submission.

## Coordinator integration and provenance finalization (2026-11-23)
- UI branch `feature/fp2-ui-master21-integration-20261123` file-level integrations into this release branch: `index.html`, `fp2-approved-bank.js`, `audit/FP2_UI_INTEGRATION_HANDOFF_20261123.md`. Canonical JSON was already byte-identical between UI and release refs before coordinator modifications; maintain release canonical as only source. UI preview text no longer falsely claims public approval.
- Source comparison for 50 recovered independently content-PASS questions completed against official JAFP PDF and independent review logs: **42 materially verbatim question/choice sets (PDF line wrapping and typography reflow only), 8 adapted exhibit/table/diagram text renderings, 0 provenance null**. Per-item `modified` and `modification_note` in both canonical and recovered draft. Evidence: `audit/FP2_RECOVERED_PASS50_SOURCE_MODIFICATION_AUDIT_20261123.md`.
- Canonical content-review PASS **65**, but individual fully release-approved **0** (`publishable_questions=0`), product status remains `CONTENT_AUDIT_PASS_PROVENANCE_50_VERIFIED_RELEASE_BLOCKED`.
- Q0 final business-rights/license, original-law/current-law cutoffs, user-visible source display screenshot, Q3 mobile E2E and exact UI Master v2.1, offline recovery, Q4/Q5 final gate, CI, Apple Store metadata/IAP/privacy and bundle SHA remain unverified. PR #5717 stays Draft. No App Review submission.

## 2026-11-23 Batch03+Batch04 reconciliation (current)
- Independent audits: Batch03 new 29 PASS / 1 HOLD plus previously corrected 2 PASS; Batch04 26 PASS / 2 FAIL / 2 HOLD. Across recovered 180 **107 content PASS / 2 FAIL (corrected pending independent re-review) / 11 HOLD / 60 NOT TESTED**.
- Canonical `questions/canonical/approved-questions-20261123.json`: **122 content-PASS records = 107 recovered + 15 independently approved originals/previously adapted**, all with individual audit evidence paths, `publishable=false`, `publishable_questions=0`, release_clear_count=0.
- Recovered draft `questions/draft/fp2-recovered-180-fulltext-20261123.json`: 180 records reconciled to PASS107/FAIL2/HOLD11/NOT_TESTED60. Batch04 Q36 and Q39 source explanations corrected, preceding incorrect texts saved in correction_prior. Answers both stay choice 1. **These two remain excluded until a new independent audit PASS.**
- Among recovered canonical 107, original-vs-modified provenance reviewed 81; **26 remain modified=null**, quarantined for individual official PDF comparison. Remaining release blockers Q0 rights/legal/source display, Q1 integration regression, Q3 UI Master v2.1 device/browser/offline, Q4/Q5 real build/screenshot, App Privacy/IAP/ASC, and 60 unreviewed questions.
- Full audit trace: `audit/FP2_BATCH03_04_CANONICAL_RECONCILIATION_20261123.md`. PR #5717 stays Draft and **SUBMISSION_READY=NO**. No App Review submit.
