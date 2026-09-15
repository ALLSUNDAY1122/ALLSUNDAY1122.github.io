# 司法試験予備試験・短答式｜権利・問題化方針

更新日: 2026-08-14

## 判定

開発は継続する。`questions.preview.json` の8問はUI・学習ロジック検証専用で、全問 `releaseEligible=false` のまま維持する。

一方、e-Gov一次法令から独自作成し、基準日・正答・教材品質・重複監査を通過した正式練習問題は42問までRelease済み。内訳は foundation 14／standard 14／applied 14、各層とも法律7科目×2問である。これらは `contentUse=practice`、`examYear=null` とし、公式年度問題であるかのような表示を禁止する。

標準手順v2.3の3回分完成ゲートに対応するため、現行R8の構成だけを参照した**独自模試3回分**を別途作成する。各回は法律95問＋一般教養44題提示（20題選択）＝139題、3回で417題提示を完成条件とする。公式問題本文・選択肢は流用しない。既存42問はseedとしてのみ扱い、不足枠を言い換え水増しで埋めない。

R6・R7については、法務省公式問題PDF・正解及び配点PDF・試験結果PDFをGitHub Actions上で取得し、年度構成と採点正本を機械監査済み。これは「公式採点情報を正確に扱える」ことの確定であり、「公式問題本文を製品へ再利用してよい」という権利判定とは別である。

## 一次資料

- 令和6年司法試験予備試験問題: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00228.html
- 令和6年短答式試験結果: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00258.html
- 令和7年司法試験予備試験問題: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00287.html
- 令和7年短答式試験結果: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00289.html
- 令和8年司法試験予備試験問題: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00317.html
- 令和8年司法試験予備試験Q&A: https://www.moj.go.jp/jinji/shihoushiken/jinji07_00210.html
- 法務省ウェブサイトのコンテンツ利用条件: https://www.moj.go.jp/hisho06_00280.html
- 司法試験及び司法試験予備試験のデジタル化: https://www.moj.go.jp/jinji/shihoushiken/jinji08_00238.html
- 現行法令の独自作問根拠: https://laws.e-gov.go.jp/

## 公式構成・採点で確定したもの

- 法律基本科目はR6・R7・R8とも、憲法12、行政法12、民法15、商法15、民事訴訟法15、刑法13、刑事訴訟法13の合計95問。
- 法律基本科目は210点満点。
- 一般教養はR6が42題、R7・R8が44題。20題選択、1題3点、60点満点。
- 短答式総得点は270点満点。
- R6短答合格点は165点以上、R7は159点以上。
- R6・R7は問題単位の解答欄、正答、配点、順不同、部分点あり／なしまで `official-scoring-canonical.v1.json` に固定済み。
- R7一般教養第41・42問の共通英文23行目は `were` → `wire` の誤記。法務省は解答への影響なしとして特段の採点措置を行っていないため、正本では `no_special_measure` とする。
- R8は問題構成と法令基準日は確定済みだが、公式正答・配点・合格点は未確認のため推測しない。

法令基準日は、R6=2024-01-01、R7=2025-01-01、R8=2026-01-01。

## 著作権・利用条件

法務省サイトのコンテンツには、権利表記等がない限り公共データ利用規約（PDL1.0）が適用される。利用時は出典表示が必要で、編集・加工した場合は加工した旨も表示する。第三者が権利を持つ写真、図表、引用文、外部データ等はPDL1.0だけで再利用可能と判断しない。

法務省自身が別ルールを適用する「司法試験等CBTシステム（体験版）」は、練習目的以外の使用や内容・画像等の複製、転載、転用、改変等の二次利用が制限される。そのため本アプリでは、CBT体験版の画面、画像、問題本文、法文表示、操作マニュアル由来図版等を作問原稿・UI模倣・スクリーンショット素材として使用しない。UIは学びスプリントGolden Masterを正本とする。

本アプリの固定方針:

1. 公式過去問は「論点・出題傾向・年度構成・公式採点規則」の一次資料として利用する。
2. 製品の中心問題はe-Gov法令等の一次資料から独自作問する。
3. 公式問題本文を収録・加工する場合は問題単位でPDL1.0適用と第三者権利を監査し、出典と加工表示を付ける。
4. 第三者著作物の疑いがある一般教養の文章・図表・写真等は、権利確認できない限り本文再利用しない。
5. 一般教養はリスク信号0件でも再利用可とは判定せず、設問単位の根拠がない限り `reuseEligible=false` とする。
6. CBT体験版固有の内容・画像・画面構成を再利用しない。
7. 正答、解説、一次根拠、根拠URL、法令基準日、作問由来、権利根拠を全問題に持たせる。
8. 公式年度模試へ公式問題本文を入れるのは、年度別採点監査と設問単位権利監査の両方がPASSした後だけとする。
9. 独自模試は `officialExamYear=null` とし、公式年度の再現問題であるかのように表示しない。

## 一般教養の権利トリアージ

`triage_general_education_rights.py` でR6=42題、R7=44題、R8=44題の計130題を設問単位で走査し、`official-general-education-rights-triage.v1.json` を生成済み。

- 出典・引用・原文変更、著者／作品名、図表・写真、出版物／Web、著作権表示、長い英文、共通文章などを手動確認優先度の信号として記録する。
- リスク信号0件でも再利用許諾の根拠にはしない。
- 全130題を `rightsReviewStatus=manual_review_required` / `reuseEligible=false` / `clearanceBasis=null` から開始する。
- 公式問題本文や第三者著作物の抜粋はトリアージJSONへ保存しない。
- このトリアージPASSは権利クリアランスPASSを意味しない。

## 独自模試3回分の作問ルール

- 構成のみR8の科目別問題数・一般教養選択数を参照する。
- 公式過去問の語順・選択肢の小変更で独自問題を作らない。
- 条文要件、例外、効果、適用、比較等、測定能力が異なる論点へ分解する。
- 1論点につき必要以上の言い換えを作らない。
- 法改正で答えが変わり得る法律問題は `reference_date=2026-01-01` を必須とし、e-Govの同日時点本文へmarker照合する。
- candidate → exact-date source audit → answer audit → distractor rationale → staging → 既存正本との横断重複 → editorial quality → release_passed の全ゲートを通過したものだけ正式mock-bankへ昇格する。
- `practice-mock-config.v1.json` と `audit_practice_mock_readiness.py` を完成判定の正本とし、417題の規定数一致までProduction Release preflightをBLOCKする。

## 確定済み

- 正式独自練習問題42問: foundation 14／standard 14／applied 14。
- Swift Validation #28: 42問契約、XCTest、XCUITest、Unsigned Release build、bundle検査までPASS。
- 独自模試3回分の完成ゲート: 1回139題、3回417題。
- 独自模試1追加法律batch-01: 候補14問のpreflight、2026-01-01 e-Gov照合、正答監査までPASS。正式昇格は教材品質・横断重複監査後に行う。
- R6・R7・R8: 法律基本科目95問の科目別内訳と一般教養出題数を公式PDFで確定。
- R6・R7: 公式正答・配点・複数解答欄・順不同・部分点をcanonical化。
- R6: 165/270、R7: 159/270の短答合格点を公式結果PDFで確定。
- R7訂正情報を反映。
- 一般教養R6-R8計130題: 権利リスクトリアージ済み、再利用許可0題。
- AppIcon #11: Google Drive正本 `11_司法試験予備試験_短答式.png` のSHA-256を固定し再生成しない。

## 未確定・ブロッカー

- 独自模試3回分: 完成ゲート417題に対し正式Release42題。追加batchは監査途中。規定数一致までProduction ReleaseをBLOCK。
- R8公式正答・配点・短答合格点: 一次資料公開／確認待ち。推測禁止。
- 公式問題各設問の第三者権利: トリアージ済みだが権利クリアランス未実施。特に一般教養は再利用BLOCKED。
- Bundle ID / App Store Connect App ID / IAP Product ID: 要確認。コードへ本番値を仮置きしない。
- StoreKit Sandbox実機確認 / Internal TestFlight実機確認: 本番識別子と完成ゲート後。

R6・R7公式採点canonicalは年度模試採点ロジックへ利用可能。一方、公式問題本文のReleaseと、独自模試3回分のProduction Releaseは、それぞれの独立ゲートが完了するまでBLOCKする。
