# SCAN-006 Evidence｜200-page Long-run Stress / Memory / Recovery

Timestamp: 2026-08-23 14:35 JST
Worker: `worker4`
Claim token: `2be6f7e9-07af-4ddd-b6f1-c1e11a4d6532`
Claim epoch: `1`
Attempt branch: `task/SCAN-006/attempt-1`
Baseline: `1bb35c1070477fdc34d0082291e64e48a84abf91`

## Implementation
- `LongRunHarness.swift`: Sequence入力を1ページずつ処理し、完了集合とreview隔離をatomic JSON checkpointへ保存する。
- 再開時は完了済み/review済みindexをskipし、重複生成を防ぐ。
- 個別ページprocessor failureは冊子全体をcrashさせずreview itemへ隔離する。
- 各ページ処理後にcheckpointを保存し、中断後の再開単位をページ境界へ固定する。
- `LongRunReportRenderer.swift`: JSON/Markdown reportを再現可能に出力する。

## Fixture
Swift 6.2.1 Linuxで次を実行した。

```text
swiftc LongRunHarness.swift LongRunReportRenderer.swift LongRunFixture.swift -o fixture
./fixture
```

240ページsynthetic workloadを使用。
- page 37: synthetic failureとしてreview隔離
- 123新規attempt後に強制interrupt
- checkpointからresume
- page 199: synthetic failureとしてreview隔離

Observed:

```text
LongRunFixture PASS
total_input: 240
processed_this_run: 116
skipped_as_completed: 123
completed_total: 238
review_total: 2
peak_in_flight_pages: 1
peak_estimated_working_set_bytes: 1620000
resumed: true
```

中断前attempt集合と再開後attempt集合のintersectionは空で、再処理重複0をassertした。

## Acceptance
- 200ページ以上synthetic workload: PASS（240ページ）
- 全件を同時メモリ保持しない: PASS（Sequence逐次処理、peak in-flight=1）
- checkpoint/resumeで重複生成回避: PASS
- failure isolation: PASS（2ページ隔離、残り238完了）
- timing / peak working set相当 / failure件数Evidence: PASS
- reproducible JSON/Markdown report: PASS

## Limitations / Golden
これはsynthetic long-run/recovery acceptanceであり、実書籍Goldenや実機iOS RSSの正式測定ではない。Golden未完了だけを理由にWorker Taskを停止しない契約v0.3に従い、`golden_status=PENDING_HQ_GOLDEN`のままHQ Golden Gateへ送る。

## Remote scope audit
Baseline compareでattempt branchは3 commits ahead、変更は `scanner-parity/LongRun/**` と `scanner-parity/Tests/LongRun/**` のみ。Shared Contract/integrationは変更していない。

## Disposition
Non-Golden acceptance COMPLETE。`INTEGRATION_READY`を推奨する。
