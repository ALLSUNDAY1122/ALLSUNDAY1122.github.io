# SCAN-008 Evidence｜Frame→Correction→PageAudit E2E Fixture・Contract Bridge

- worker: `worker1`
- claim_token: `883a50de-f68a-4f89-ad44-dc546bbbd0a9`
- claim_epoch: `1`
- attempt_branch: `task/SCAN-008/attempt-1`
- baseline_sha: `1bb35c1070477fdc34d0082291e64e48a84abf91`
- integration_epoch: `2`
- golden_status: `NOT_APPLICABLE_WORKER`
- task_status_at_evidence: `INTEGRATION_READY`

## Ownership / branch fencing

Atomic claim後に `task/SCAN-008/attempt-1` がbaselineより4 commit先行した状態で既に存在することを検出した。Queue上のcanonical ownerは `worker1 / claim_epoch=1` だったため、先行成果を無条件採用せず、全変更をread-backし、既存integrated typeとの整合・fixture挙動を再監査した。

Worker 1による追加監査・修正後のみ、本attemptをcanonical integration candidateとして扱う。

## 実装

`scanner-parity/PipelineCore/PipelineAuditBridge.swift`

- `PageCandidate` をそのまま `PipelinePageRecord` に保持し、以下をstage横断で欠落させない。
  - `candidateID`
  - `bookID`
  - `sourceTimeMS`
  - `sourceRangeMS`
  - source `flags`
- `CorrectedPageMetadata` の `pageID / candidateID / flags / qualityScores` を既存型のまま参照する。
- PageAuditへ渡す `sourceTimeMs` は必ず元 `PageCandidate.sourceTimeMS` を使用する。
- correction失敗・metadata欠落をページごと破棄せず `reviewRequired` へ `stage_failure` として伝播する。
- `lowBoundaryConfidence` またはboundary confidence閾値未満を `reviewRequired` へ伝播する。
- correction側の `pageID / candidateID` lineage mismatchを `contract_mismatch` として検出する。
- 追加監査で検出した欠陥を修正：`PageNumberObservation.pageID` がpipeline `pageID` と異なる場合、その番号ObservationをAuditorへ渡さず、`contract_mismatch` としてreviewへ隔離する。誤った番号証拠が順序・重複の自動修復を駆動しない。
- Shared ContractおよびFrameExtraction/ImageCorrection/PageAudit既存型は変更していない。

## E2E fixture coverage

`scanner-parity/Tests/PipelineCore/PipelineAuditBridgeTests.swift` と `run-fixtures.sh` を用意。

`run-fixtures.sh` は独自コピー型ではなく、integration上の次の実sourceを直接compile対象にする。

- `FrameExtraction/FrameExtractionModels.swift`
- `ImageCorrection/CorrectionCore.swift`
- `PageAudit/PageAuditModels.swift`
- `PageAudit/PageIntegrityAuditor.swift`
- `PipelineCore/PipelineAuditBridge.swift`
- `Tests/PipelineCore/PipelineAuditBridgeTests.swift`

Worker実行面にはrepository checkoutが直接mountされていなかったため、GitHub read-backした上記integrated public contractとAuditorロジック、およびbranch Bridgeをisolated Swift 6.2 compile環境へ再現して同一fixture条件を実行した。

結果: **9 PASS / 0 FAIL**

1. candidate/source time/source range/source flags/correction flags lineage保持
2. 正常順保持
3. stage横断重複検出
4. stage横断欠落検出
5. 隣接逆転検出＋高信頼swap修復
6. correction stage failureを破棄せずreviewへ伝播
7. low boundary confidenceをreviewへ伝播
8. correction page/candidate ID mismatchを検出
9. page-number observation ID mismatchをAudit入力から隔離しreviewへ伝播

## Critical review improvement

先行成果をそのまま採用した場合、`PageNumberObservation.pageID` が別ページを指していても `PageIntegrityAuditor` に渡り、誤番号が高confidenceなら順序自動修復を誤駆動し得る問題があった。

Worker 1で以下へ修正した。

- `makeAuditInput`: page-number observationのpage ID一致時のみ採用。
- mismatch時: `PageReviewReason.conflictingEvidence` + `contract_mismatch` を追加。
- fixtureを追加し、mismatch番号が `pageNumberObservations` に入らず、元pageが保持されることを確認。

## Scope audit

baseline `1bb35c1070477fdc34d0082291e64e48a84abf91` との差分は次の4ファイルのみ。

- `scanner-parity/PipelineCore/PipelineAuditBridge.swift`
- `scanner-parity/PipelineCore/README.md`
- `scanner-parity/Tests/PipelineCore/PipelineAuditBridgeTests.swift`
- `scanner-parity/Tests/PipelineCore/run-fixtures.sh`

Task write scope外のshared contract / integration / upstream stage sourceは変更していない。

## Golden / Privacy

- Golden原本不要のsynthetic E2E Task。
- 正式Golden PASS/FAIL、SHA採否判断は行っていない。
- 外部AI/API、ネットワーク送信、secret追加なし。
- 書籍画像原本をGitHubへ保存していない。

## Worker 1 commits

- `340e293215f79049b27303050c00fa31f0b1a29f` mismatched page-number evidence quarantine
- `e3124504216f7aa0d234d064fcefd61df8bb2b40` regression fixture追加
- `86bfb9ff24fddab25488ce190b1b212b7c9c1b89` contract documentation更新

以上により非Golden acceptanceは完了し、`INTEGRATION_READY` とする。
