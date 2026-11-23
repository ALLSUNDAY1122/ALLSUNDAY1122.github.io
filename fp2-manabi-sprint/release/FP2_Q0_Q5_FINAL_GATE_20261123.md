# FP2｜Q0〜Q5最終ゲート・統合監査（2026-11-23 現行正本）

> 旧122問・旧120問選定に基づく前版を更新。内容PASSは公開承認と異なり、Apple提出は行わない。

## 1. 現行確定コンテンツ

| 指標 | 現行値・証拠 |
|---|---|
| 正規canonical | **312問、全問独立内容監査PASS、publishable=false** |
| 学科過去問リリース選定 | **300問＝2024-05／2024-09／2025-01／2025-05／2026-05各60問、6分野×50問** |
| 内容監査PASS予備 | **12問（独自作成）、配布予定バンドルには含めない** |
| 既存回収180問 | **PASS180／FAIL0／HOLD0**（訂正後の独立再監査PASS5を含む） |
| 2024年拡充120問 | **PASS120／FAIL0／HOLD0**（新規117、既存2024-05 Q01/Q02/Q06再監査3） |
| 2024-09 Q29 | 正答④、重複誤答肢を修正し再監査PASS |
| 改変判定 | 新規117問すべてmodified=true。制作時のnoteと監査最終noteを別保存 |
| 固定バンクGit Blob SHA | `03b449dbe8a848b192bd970801846b18c486b1b4` |
| 新リリース選定正本 | `fp2-manabi-sprint/release/release-selection-300-20261123.json` |
| 下書き回収180問 | `fp2-manabi-sprint/questions/draft/fp2-recovered-180-fulltext-20261123.json`：ID/本文/四肢/解説/正答一致でPASS180、FAIL0、HOLD0へ同期。原履歴correction_prior保持 |
| 公開許可 | **0問**。内容PASS・技術CI PASSだけではQ0/Q5の公開承認としない |

追加証拠：`audit/FP2_FIVE_EXAM_300_INTEGRATION_20261123.md`、七つの2024年バッチ別独立監査JSON、`scripts/fp2_five_exam_audit_gate.py`。Q20の第二次独立PASSは`audit/FP2_2025_01_Q20_SECOND_CORRECTION_REAUDIT_PASS_20261123.md`にある。

## 2. 実測CI：コミット3116840c（同期・追加修正前）

対象コミット：`3116840cf6b7a3a4f88ac2ed172f40c999807ff5`。

| 検証 | GitHub Actions | 結果 |
|---|---|---|
| 正規バンク/静的Web/出典・構造 | [45169903628](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169903628) | **SUCCESS** |
| Chromium 学習ループ/オフライン/JSON復元 | [45169903733](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169903733) | **SUCCESS** |
| UI Master v2.1 migration | [45169904527](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169904527) | **SUCCESS** |
| Release Registry audit | [45169903611](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169903611) | **SUCCESS** |
| macOS unsigned iOS Simulator | [45169903544](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45169903544) | **FAIL（修正前の原始結果）**：旧選定台帳キーへのアクセスによるKeyError |

macOS CI初回失敗は `selection['corrections_excluded_until_independent_reaudit']` という旧120問選定キーが300問選定JSONにないことに起因。`selection.get(..., [])`へ変更。その次のCIではnative payloadの `content_approved_questions` が旧120のままであることによるassertion failureを確認し、300へ修正。**どちらも出題正答・選定内容の変更ではない。** 修正後macOS Simulatorの**XcodeGen/コンパイル・コンパイル済みバンドル読戻し**は修正後のmacOS CIでSUCCESSを確認した。ただし署名IPAと実機は未確認。最新修正の追跡対象は`6723088bffec1f974961c3860f72d9b4f76abbb4`以降。

**修正後の実測SUCCESS：** [macOS unsigned iOS Simulator run 45171875787](https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/45171875787) にて、ソース一致/オフライン300問payload、XcodeGen生成、`xcodebuild -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO`、コンパイル済みInfo.plistと組込バンクの読戻しの全ステップSUCCESS。対象commit `b00b924c2ffd5c117f78bba88d74bbeff40aab9a`。新たなソース変更後は再CIを要する。\n\n## 3. Q0–Q5の最終判定

| Gate | 判定 | 次の証拠・不足 |
|---|---|---|
| **Q0 公式原典・権利・法令** | **BLOCKED** | 日本FP協会／きんざいの条件付き二次利用規定に対する利用主体適合、原題/図表と改変・出典の実際の表示、2026-04-01時点の法令適用と例外の最終責任者判断。原典逐語一致を全問自動的に保証したものではない |
| **Q1 問題内容・統合品質** | **CONTENT PASS300/300・バンク312/312 CONTENT PASS／PUBLICATION BLOCKED** | 七バッチ各問・回収180問の監査記録およびGit Blob一致を確認。難易度が原題から易化した疑い、教育上のカバー範囲、権利/内容の独立最終確認は別の品質判断 |
| **Q2 学習価値** | **CHROMIUM E2E PASS／REAL-DEVICE PENDING** | 回答・フィードバック・目標4/8/16・学習記録の実ブラウザ検証はPASS。実際の受験者による弱点復習・定着とiPhone操作受入は未了 |
| **Q3 UI/UX・オフライン** | **CHROMIUM OFFLINE/JSON E2E PASS／DEVICE NOT VERIFIED** | Service Workerのキャッシュ起動・オフライン再読み込み・JSON保存/復元・35日ヒートマップをブラウザで実操作PASS。iPhone Safe Area・長文/アクセシビリティとGolden Master30状態の実機比較は未了 |
| **Q4 独立利用者受入** | **NOT TESTED** | 別担当者・受験生相当者の300問版実利用と障害復旧、実機検証 |
| **Q5 最終品質・ストア** | **TECHNICAL SIMULATOR PASS／RELEASE BLOCKED** | SimulatorコンパイルおよびバンドルSHAはPASS。署名IPA/Build・TestFlight実機、App Store Connect実物照合（ID/Version/Build/IAP/Privacy/URL/スクショ）、最終許可 |

**バンドル元/配布区分：** WebソースとLinux CI上のiOSオフライン300問限定payload・SHA一致はPASS。予備12問は資産の出題バンクから除外。実署名済IPAのハッシュやTestFlight表示との一致を意味しない。

**AppIcon：** 旧FP2アイコンと現在の内部ファイルのハッシュ一致は過去検査済み。Apple App Store Connect登録原本とのハッシュ比較は既知のHUMAN-REQUIRED未検証で、新規欠陥にしない。

## 4. ChatGPT/人による残ゲート

**ChatGPT側：** macOS Simulator/300問バンドルCIは修正後SUCCESSを確認済み。追加のソース変更があれば再実行し、300問選定の一次資料・難易度/改変表示・発行物メタデータ整合を確認し、不十分な箇所は記録する。ブラウザ成功と実機受入を混同しない。

**運用者・ユーザー側：** 権利利用・運用主体の最終判定、App Store ConnectのアプリID `6797228406`／Bundle ID `com.allsunday1122.fp2manabisprint`／Version `1.0.0`／Build `1`／IAPなしの実物、App Privacy/サポート・プライバシーURL/スクショ、署名済TestFlightをiPhoneで受け入れ、最終提出の明示承認を行う。

**現行CI結果：** 静的検査・Golden Master・Registry・unsigned Simulator = SUCCESS、Chromium最新の完了結果は継続読戻し対象（先行3116840cではSUCCESS）。\n\n**最終判断：`BLOCKED / NOT_SUBMISSION_READY / NOT_SUBMITTED`。PR #5717はDraft、mainへのマージ・App Reviewへの提出は禁止。**
