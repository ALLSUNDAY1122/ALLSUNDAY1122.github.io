# FP2 HANDOFF — 2026-11-23

Read RELEASE_SCOPE_20261124.md and RELEASE_STATUS.md first. Use Notion v2.8, application procedure, Learning Sprint Skill v1.0, UI Master v2.1, question-audit loop v1.0. Target 2026-11-24 08:00 JST. Do not submit to App Review.

1. Inspect actual main/branch, existing FP2 canonical source/bank and scripts, prior source ledger; do not infer fresh readiness from 2026-09-16 matrix or the UI sample.
2. Confirm official FP2 examination requirements and publication rights; if verbatim transfer stops use original questions with primary sources. Fix maximum release scope to 120 questions, 6 fields x 20, reduce only with documented educational and gate reasons.
3. Generate canonical bank with unique ID, domain, 4 options, answer, full explanation including all distractors, source URL, effective date, origin, copyright basis, dataVersion and audit state. Isolate drafts and previous editions.
4. Independently audit every released item; run canonical-level validation and hash pin. Only approved data may reach product UI.
5. Integrate real bank with UI Master v2.1, not former FP2 v1.3. Check progress, weak remediation, resume, storage migration, offline, no double count, long text, 4/8/16 target, 4 navigation tabs.
6. Run actual tests, CI, iOS signed build and TestFlight device acceptance. Verify App Privacy, metadata, screen captures, URLs, rights and distribution controls. Save evidence in RELEASE_CHECKLIST.md, release-status.json, TEST_REPORT.md.
7. Only when all independent Q0-Q5 and submission preparation gates PASS set SUBMISSION_READY / WAITING_FINAL_APPROVAL. Never Add for Review / Submit for Review.

Write ownership: use one branch/worker by default. For parallel waves HQ+2 workers max, distinct branches, explicit owned files and integration retest.
