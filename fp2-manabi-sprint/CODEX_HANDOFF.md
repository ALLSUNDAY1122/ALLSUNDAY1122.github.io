# FP2 後継引き継ぎ・現行優先（2026-11-24）

従前の120問固定・600問契約・300問補充指示は**適用終了**。リリースブランチ `feature/fp2-release-scope-20261123` の正本は**正規310／公式逐語選抜298／独自予備12／FAIL2隔離／HOLD0**。Q53・Q55 PASS。補充禁止、全件publishable=false。CI 8/8 SUCCESSの確定証拠は0b1dc28時点のみ。Q0 BLOCKED、Q1教材監査PASS298/出版BLOCKED、Q2・Q3技術PASS/実機未了、Q4 NOT TESTED、Q5 BLOCKED、NOT_SUBMISSION_READY。最終提出なし。

下記は**2026-11-23時点の引き継ぎ履歴であり現行指示に用いない**。

---

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

## Confirmed official reuse policy (2026-11-23)
Read `audits/FP2_Q0_OFFICIAL_PAST_EXAM_RIGHTS_20261123.md` before authoring remaining batches. JAFP + Kinzai conditional permission permits their released 2級学科 exam questions without preapplication, requiring question-level official provenance and a visible modification notice when altered. JAFP and Kinzai share copyrights for 2級学科. Write all explanations independently. For each historic question verify the question's original law cut-off separately from current/app target law and revalidate all answers. Do not use or copy FP2級ドットコム（過去問道場） wording, explanations, datasets. The general rights-policy finding is CONDITIONAL_PASS but Q0 is still BLOCKED until per-question evidence. No App Review submission.
