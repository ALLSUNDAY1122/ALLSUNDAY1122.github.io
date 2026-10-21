# W2 STEP37 Native recovery — HQ2 independent-check handoff

Date: 2026-10-21 JST. Task SCANLAB-W1-001 WORKER_2 epoch 2; lock scanlab:native-capture-reconstruction-export epoch 2 (Queue sha ebba8d4a793b53a0abfd4f18bad0c6144f17b4bd at start). Worker1 STOPPED. New isolated branch attempt/scanlab-w2-recovery-step37-20261021-a2 based on verified W2 Native HEAD dbcc8ba02cff0daad56593fc36c733167664f0f0. PR #5639, draft, base is former W2 native attempt. No product/release/HQ-controlled branches edited.

HQ2 release candidate 4f3a0de772df8e8d87e4d5b4932d717d596f17d8 Native CI run 39433258555 FAILED: 251 executed tests, one testcase with two assertions (line 162 completionEvidenceMismatch; line 167 backup still present). This failure is not release-approved; prior W2 Native at dbcc8ba was green but does not prove candidate pass.

Changes on this short-lived branch:
- 525fc662fd6700e03c98abc6c5eade51bafa204a: independently witness sanitized snapshot decode, version, filename, size, three generation/timestamp predicates, regular-file status, backup size/SHA. Existing actual guards retained.
- 894978769def41388f1533076de8af99be6221d5: capture post-failure evidence identity, restored bytes, mtime and backup presence in XCTest (no asset bytes logged).
- d40126f59342de02565160b64c1b69f56fc5840e: log sanitized old/preserve/new ISO8601 dates and SHA predicate in XCTest.
- 361b0ed511c3fe7ffb75572c1e9af065d7decdd2: under verified backup SHA plus same-size/ordering gate, normalize only staged partial clone's later modification timestamp to the authenticated previous completedAt *before* atomic promotion. Reverify SHA after normalizing; do not modify preserved backup or weaken generation guard.
- 0969228c1f041efc7d1c0db1cbd952c7813a4b28: deterministic future-mtime backup fault injection in original positive recovery XCTest.
- 133c1e04643a158649a4ad0cd0e41b82acedccca: fail-closed staged SHA mismatch also cleans partial file, preserves original backup.

Important: the mtime mismatch is a concrete risk path, but was not proven to be the sole cause of candidate intermittent failure at writing. Must verify complete CI and fault tests on exact HEAD. Do not mark source repair accepted without full Native CI and direct test log readback. Previous diagnostic run39533009521 was CANCELLED due subsequent source commits and is NOT PASS.

Acceptance: positive old SHA-matched backup restores exact bytes and manifest recovery flag, removes backup only AFTER strong verification; altered SHA, altered evidence, wrong generation and interruption all fail closed without deleting trusted backup. Full XCTest must pass, then HQ2 independently audits, merges and releases. No Codemagic, Apple upload or App Review from Worker2.
