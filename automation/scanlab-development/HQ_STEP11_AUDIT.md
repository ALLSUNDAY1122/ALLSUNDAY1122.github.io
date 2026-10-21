# STEP11 — HQ live CI audit and change-of-tactic
2026-10-20 JST. Integration HOLD.

- Queue control SHA 7196cc2776f38fe9260c6cf5fa244fba4c5563c0, HQ/W1/W2 tasks CLAIMED epoch1; resource locks intact.
- Integration baseline HEAD 2bcbbd6128863739ad168610cd2e3f8e3b01b458 unchanged.
- W1 HEAD 31ba91fdd7f6a550952ab0a814692377033783cf, 4 commits, unchanged, PR #5620. Native PR CI run 39354568521 FAILED static mesh durability source-structure contract (reset_block.index('FileManager.default.removeItem')), before XCTest. Repeated stagnant head -> HQ changed tactic: direct actionable PR comment 6281816710 demands behavior-based durability invariant and regression fixtures, not a blind retry.
- W2 HEAD 30b9a777fa268a50722141d4e56cff6e728f04ab, 11 commits, PR #5619. New T37 Swift publish logic removes destructive draft/asset cleanup on ambiguous ACK and adds test_scanlab_publish_ack_safety.py, plus previously updated read-only Library. Native CI run 39356743067 FAILED in Static checks before XCTest: Node assertion expects obsolete cleanupFailedDraft string, while new code intentionally removes that unsafe deletion. HQ direct PR comment 6281816314 demands replace obsolete source-shape assertion with no-delete-on-uncertain-ACK contract. Merely restoring delete is forbidden. W2's old full XCTest failure in SplatExportAdmissionTests (corrupt primary sidecar recovery) remains unresolved/unchecked by latest run.
- Other W2 targeted privacy/memory/smoke checks SUCCESS but do not override full CI failure.
- No evidence of full passing Native iOS CI for either Worker. No merge, Codemagic, Apple upload, Internal TestFlight update or App Store Review Submit.
- Next: fix W1 durability static contract without weakening behavior; W2 legacy cleanupFailedDraft contract + explicit export backup repair, then full native CI PASS, read fresh HEAD/lock and independently integrate.
Evidence:
https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/39356743067
https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/actions/runs/39354568521
