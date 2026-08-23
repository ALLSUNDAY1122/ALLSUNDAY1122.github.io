# SCAN-008 Evidence｜Frame→Correction→PageAudit E2E Fixture・Contract Bridge

更新: 2026-08-23 14:39 JST
Worker: worker2
Claim epoch: 1
Attempt branch: `task/SCAN-008/attempt-1`
Baseline: `1bb35c1070477fdc34d0082291e64e48a84abf91`

## 結果

`INTEGRATION_READY` 推奨。Golden原本を必要としないTaskであり `golden_status=NOT_APPLICABLE_WORKER`。

## 実装

- `scanner-parity/PipelineCore/PipelineAuditBridge.swift`
  - `PageCandidate` を保持したまま `PageAuditInput` へ接続。
  - `candidateID / bookID / sourceTimeMS / sourceRangeMS / source flags` を `PipelinePageLineage` へ保持。
  - `CorrectedPageMetadata.pageID/candidateID` のlineage mismatchを `reviewRequired` へ送る。
  - correction stage failureをページごと破棄せず、元時刻を持つ監査入力として残し `stage_failure:` reviewへ送る。
  - `lowBoundaryConfidence` または boundary confidence < 0.72 をreviewへ伝播。
  - Shared Contractおよび既存FrameExtraction/ImageCorrection/PageAudit型は変更していない。
- `scanner-parity/Tests/PipelineCore/PipelineAuditBridgeTests.swift`
  - lineage保持
  - 正常順
  - 重複
  - 欠落
  - 隣接逆転＋高信頼auto-fix
  - stage failure伝播
  - low confidence伝播
  - ID mismatch検出
- `scanner-parity/Tests/PipelineCore/run-fixtures.sh`
  - integration済み4 source file + bridge + fixtureを同一swiftc invocationで再現実行するrunner。

## 検証

### Remote scope read-back
`scanner-parity/integration` baselineとのcompare:

- attempt branch: 4 commits ahead / 0 behind
- changed paths:
  - `scanner-parity/PipelineCore/PipelineAuditBridge.swift`
  - `scanner-parity/PipelineCore/README.md`
  - `scanner-parity/Tests/PipelineCore/PipelineAuditBridgeTests.swift`
  - `scanner-parity/Tests/PipelineCore/run-fixtures.sh`
- write_scope外の実装変更なし。

### Swift型整合
GitHub connectorで取得した現行public signature（PageCandidate / CorrectedPageMetadata / PageAuditInput / PageAuditResult / PageIntegrityAuditor）と同一の最小fixtureをSwiftでcompile/run。

結果:
`PASS typecheck+lineage+review propagation`

### Fixture条件の独立検算
production `PageIntegrityAuditor` の閾値・分岐に対し以下を検算:

- identical perceptual hash => duplicate similarity 1.0
- page number 1 -> 3 => missing [2]
- timeline 1,3,2,4 => adjacent reversal条件成立
- confidence 0.999 / score 99.9 => swap confidence 0.999 >= 0.985
- correction boundary confidence 0.40 < bridge threshold 0.72

結果:
`PASS semantic-fixture-cases: duplicate/missing/reversal/failure/low-confidence/lineage-contract`

### 実行環境制約
現在のcontainerは `raw.githubusercontent.com` のDNS解決ができず、attempt branchから全production Swift sourceをcontainerへ直接downloadして `run-fixtures.sh` をその場で実行する経路は失敗した。これはコードcompile failureではなく取得経路の制約。再現runner自体をrepositoryへ保存し、HQ/CIで同一repo checkout上から実行可能にしている。

## Acceptance対応

1. PageCandidate→補正→監査でID/source_time/flagsを保持: 実装済み。
2. synthetic正常順/重複/欠落/逆転: fixture実装済み、条件検算済み。
3. stage failure/low-confidenceをreview_requiredへ伝播: 実装済み、Swift実行確認済み。
4. Shared Contractを変更しない: compareで確認済み。
5. Goldenなしで再現可能なE2E fixture/Evidence: runner + fixture + 本Evidenceを保存済み。

## 残余リスク

HQ統合前に、repo checkout環境で `scanner-parity/Tests/PipelineCore/run-fixtures.sh` を1回実行することを推奨する。Apple SDK依存ではなくSwift/Foundation中心のためGolden Dataset待ちは不要。
