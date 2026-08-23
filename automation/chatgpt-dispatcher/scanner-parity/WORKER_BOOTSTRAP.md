# 書籍スキャナー同等化｜Worker契約 v0.5 AUTONOMOUS LANES

## 最終目的
動画で本を連続撮影・画面録画するだけで、完成ページ抽出、補正、ページ完全性監査、日本語OCR、検索可能PDF、ページ画像、TXT/Markdown、manifestまで自動生成し、人間にも生成AIにも読みやすい実用品質のBookPackageを作る。

PoC成功、compile成功、OCR単体成功、PDF単体生成だけを完成扱いにしない。

## 正本
- Notion「書籍スキャナー同等化｜動画式ブックスキャナー＋AIデータ化 正本」 page id `3c509c10-697d-8139-867e-c3f7605665ed`
- Notion「AIアプリ開発・公開フロー v2.7」
- Notion「分割セッション手順 v1.1｜AIアプリ開発のQueue駆動・並列化・統合運用」
- GitHub `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Integration `scanner-parity/integration`
- Dispatcher `automation/scanner-parity-dispatcher`
- Autonomous lanes `automation/chatgpt-dispatcher/scanner-parity/AUTONOMOUS_LANES.json`
- Shared contract `scanner-parity/SHARED_CONTRACT.md`
- Queue `automation/chatgpt-dispatcher/scanner-parity/queue.json` は履歴・既存Task状態の参照用。Autonomous Lane開始後の中間配車には使わない。

## 最優先ルール｜HQを律速にしない
`AUTONOMOUS_LANES.json.active=true` の間、Worker 1〜4は自分のlaneを最後まで自己完結で進める。

1. HQの中間Task発行、中間merge、中間レビューを待たない。
2. lane内のsubtask分解、優先順位付け、実装順はWorker自身が決める。
3. lane内で必要な追加fixture、adapter、test、EvidenceはWorker自身が追加する。
4. lane用の長期branchを使用し、milestoneごとにcommit/pushする。短命Task branchへ戻らない。
5. lane完了まで原則1つのbranchで進め、最後にintegration向けfinal PRを1本だけopenする。
6. Workerは自分のfinal PRをmergeしない。4 laneのfinal PRが揃った後、HQが一度だけ統合する。
7. 他laneの未完成を待たない。Shared Contractに沿ったadapter/stub/fixtureで前進し、最終統合時に必要なassumptionをEvidenceへ残す。
8. Queueのclaim/claim_epochは既存SCAN-010/011/012の履歴保全には使ってよいが、laneの次作業をHQからclaimする必要はない。
9. 既にclaim済みのSCAN-010/011/012は対応laneの最初のmilestoneとして吸収し、完了後そのまま次milestoneへ進む。
10. `FIXED_ASSIGNMENTS.json` はsuperseded。Autonomous lanesが優先する。

## Lane branch
- Worker 1: `scanner-parity/worker1-product-lane`
- Worker 2: `scanner-parity/worker2-privacy-lane`
- Worker 3: `scanner-parity/worker3-package-quality-lane`
- Worker 4: `scanner-parity/worker4-review-recovery-lane`

開始時に自分のlane branchのHEADを取得する。初回baselineは `fd9cb2ec7745a927fae80a82f5cfc514ebc40020`。既存Task branchに未統合commitがある場合は内容を監査してlane branchへ安全に取り込む。取り込み方法はcherry-pick相当でも再実装でもよいが、重複・脱落をEvidence化する。

## Scope
各Workerのwrite scopeは `AUTONOMOUS_LANES.json` を正とする。自分のlane外ファイルは原則変更しない。

例外は以下のみ。
- test/compileに不可欠で、既存Shared Contractを変えないadapter追加
- Evidence/READMEの補助
- CIの既存workflowを直接変更する必要がある場合は変更せずEvidenceへ要件を記録する。workflow統合はHQ final integrationで処理する。

Shared Contractそのもの、integration branch、他Worker lane branchは変更禁止。

## Autonomous Macro Loop
ユーザーが一度「次」または開始指示を出したら、その回答内で可能な限りlane完了まで連続して進める。

`read canonical -> inspect lane -> plan -> implement -> test -> self-review -> fix -> checkpoint push -> next milestone`

milestone完了ごとにユーザー確認を求めない。仕様選択が本当に人間判断を必要としない限り、自分で妥当な実装を選びEvidenceへ理由を書く。

プラットフォーム都合で応答が終了した場合、次回の「次」ではlane branchとEvidenceをread-backし、中断地点から再開する。HQへ戻してはいけない。

## Cross-lane依存
他lane未統合を理由に停止しない。

- Stable Shared Contractをinterfaceとして使う。
- 未実装部分はprotocol/adapter/stub/fixtureで置換する。
- final integrationで差し替える箇所を `LANE-*-FINAL.md` に列挙する。
- 他laneの具体的commitを取り込みたくても、原則final integrationまで待つ。どうしても必要な場合はread-onlyで参照し、コピーではなくinterface互換実装を作る。

## Golden Dataset
Golden Datasetの取得可否、canonical SHA、SHA mismatch解消、正式Golden実測、Golden PASS/FAILはHQ所有。

Golden未取得・SHA mismatch・未実測だけを理由に停止しない。laneの非Golden acceptanceを完了させ、Goldenで後から差し替え可能なharness/interfaceまで作る。

ユーザー提供書籍原本をGitHubへ保存しない。

## Privacy / Security
初期標準経路は端末内処理。書籍画像/OCR本文を第三者AIへ送る機能を独自判断で追加しない。外部AI/API/認証が必要になった場合は実装を止めず、optional adapterとして隔離し、既定OFF・明示同意前提とし、Security/Privacy要件をEvidenceへ残す。

## 品質目標
- page recall >= 99%
- mid-transition accepted = 0
- duplicate <= 0.5%
- ordering = 100% target
- missing/reversal/duplicate detection
- perspective/skew/crop/color/shadow、必要ならdewarp
- 日本語縦書き/横書きOCR
- searchable PDF + pages + TXT/Markdown + manifest
- 200ページ級でcrashしない
- failure/review/recovery導線がある

## Lane完了条件
自分の `AUTONOMOUS_LANES.json` の全milestoneとdone_whenを満たし、以下を揃える。

- reproducible tests/fixtures
- self-review後の修正
- `automation/chatgpt-dispatcher/scanner-parity/evidence/LANE-N-FINAL.md`
- final branch HEAD
- integration向けfinal PR 1本
- PR本文に changed scope / tests / known integration assumptions / human-only gates を記録

完了時は `LANE_READY_FOR_FINAL_INTEGRATION` と報告する。HQの中間確認は不要。

## Human Gate
本当に人間操作が必要なものだけ停止可：2FA、契約/税務/銀行、App Store Submit for Review、iPhone実機最終受入、仕様上の不可逆な製品判断。

Golden未取得、CI不足、他lane未完成、HQ未応答はHuman Gateではない。
