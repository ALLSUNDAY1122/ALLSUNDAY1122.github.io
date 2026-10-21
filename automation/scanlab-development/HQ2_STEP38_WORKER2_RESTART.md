# HQ2 STEP38 — Worker2 recovery restart / Native CI pending

Date: 2026-10-21 JST. HQ task: SCANLAB-HQ-001 epoch1. NO-GO for release.

## Independent GitHub readback
- Worker2 STEP37 recovery branch `attempt/scanlab-w2-recovery-step37-20261021-a2`: HEAD `7468a2113b010be14cccbba544e24c0e6edb5e1a`.
- PR #5639: https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/pull/5639 (Draft, unmerged per worker report).
- Source evidence `automation/scanlab-development/W2_STEP37_NATIVE_RECOVERY_EVIDENCE.md` fetched from exact SHA `7468a211...`.
- Diff from Worker2 native prior HEAD dbcc8ba02cff0daad56593fc36c733167664f0f0: only `SplatPreviousResultIntegrityRecovery.swift`, `SplatCompletionVerifierTests.swift`, and W2 evidence file.
- Verified current Worker2 Native base attempt HEAD `6046660061b25efec0029b9ee9b95c7af19d3a7d` (advanced independently; do not overwrite without comparing).
- Worker2 viewer attempt: current context last known `18987c29eda1ea4c4e49dda103f1e005d9b868d9`.
- Queue control `automation/scanlab-hq-control-20261020`, file `automation/scanlab-development/queue.json`, blob SHA `ebba8d4a793b53a0abfd4f18bad0c6144f17b4bd`: SCANLAB-W1-001 WORKER_2 epoch2 (Native), SCANLAB-W2-001 WORKER_2 epoch1 (viewer). Worker1 STOPPED, do not reuse.
- GitHub commit workflow runs query for exact `7468a211...` returned EMPTY. Combined commit statuses empty. Thus exact-head Native XCTest = NOT VERIFIED. Old native release-candidate run #39433258555 FAIL (251 XCTest, 2 assertions in one case); prior diagnostic #39533009521 CANCELLED. Neither certifies `7468a211...`.
- Provenance preflight #39512100373 SUCCESS; unrelated to Native XCTest.
- New release candidate remains `4f3a0de772df8e8d87e4d5b4932d717d596f17d8`; actual release source `release/scanlab-testflight` remains `3cbd4dcfe6505fb2fc9223062a7ec8feaeb0bf2a`.

## Worker2 restart instructions
1. New Worker2 chat should first load this file and canonical Queue and Worker contract. Treat all conversation claims as hints; independently fetch GitHub.
2. Verify Worker2 Native ownership epoch2 and viewer ownership epoch1; Worker1 is permanently stopped by user; do not take HQ release rights.
3. Inspect latest #5639 branch, source diff, and post-STEP37 head. Check whether `604666...` on prior Worker2 Native branch already incorporates fixes or represents concurrent work; use ancestry/diff before moving any branch.
4. Retrieve exact-head Native workflow runs (prefer PR check suite/Actions UI if workflow runs API only exposes PR runs), full logs, XCTest count, failures, SHA. Run the *exact* latest repair SHA through CI if absent. Do not classify CANCELLED/QUEUED as PASS.
5. If CI fails, isolate error and fix on a NEW claimed attempt branch within Worker2 Native lock; rerun full Native XCTest. Respect data-integrity and fail-closed restoration: no downgrade of SHA checks, preserved backup deletion on failure, or destructive rollback.
6. Save detailed evidence at `automation/scanlab-development/W2_STEP38_NATIVE_RECOVERY_EVIDENCE.md` on Worker2-owned branch and expose PR URL, SHA, run ID, total tests, failures. HQ independently validates.
7. Do NOT modify `release/scanlab-testflight`, trigger Codemagic, upload to Apple, assign TestFlight groups, submit App Review, or modify HQ governance claim. Worker2 handles T34-T39 only.
8. Update Queue task/lock only through atomic SHA compare-and-swap and record evidence; checkpoint remote readback at least every three implementation responses.
9. Do not use or send anything to Worker1.

## Evidence status
No exact-head Native CI PASS available. No new TestFlight build. No production App Review submission. HQ release NO-GO.
