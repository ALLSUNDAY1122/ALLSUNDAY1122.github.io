# HomeCourt同等化｜HQ_BOOTSTRAP v1.0

更新: 2026-08-22 JST

## 1. Operational Source of Truth

- Product / PARITY / human-readable specification: Notion `HomeCourt技術同等化｜リアルタイムスポーツCVアプリ 正本`
- Standard development procedure: Notion `AIアプリ開発・公開フロー v2.7`
- Split-session procedure: Notion `分割セッション手順 v1.1｜AIアプリ開発のQueue駆動・並列化・統合運用`
- Repository: `ALLSUNDAY1122/ALLSUNDAY1122.github.io`
- Integration mainline: `tech/homecourt-cv`
- Queue / claim branch: `ops/homecourt-queue`
- Draft integration PR: `#4432`
- Queue: `automation/homecourt-parity/queue.json` on `ops/homecourt-queue`
- PARITY matrix: `automation/homecourt-parity/PARITY_MATRIX.md`
- Resource locks: `automation/homecourt-parity/RESOURCE_LOCKS.md`
- Worker contract: `automation/homecourt-parity/WORKER_BOOTSTRAP.md`

Conversation history is never canonical. Every HQ wake-up and every finalize operation starts with a fresh read of Notion, integration HEAD, Queue HEAD, open PRs, and relevant evidence.

## 2. Current Integration Contract

- `integration_epoch`: 1
- Initial code baseline before HQ bootstrap: `f4efed49b57fa7d02f453d0014c0c5c489234c61`
- HQ-established SwiftPM/test baseline: `16b150c633e5817d0f1864223b03351b85003191`
- Existing implementation: trajectory-only `ShotEventDetector`; it is PARTIAL evidence for shot-event recognition only.
- Product PARITY is not achieved.

Any change to shared tracking contracts, session model, persistence schema, public event model, app state, or canonical APIs increments `integration_epoch`. Tasks from an older epoch must be re-evaluated before finalize.

## 3. HQ-only authority

Only HQ/finalizer may:

1. move the integration mainline;
2. define or change canonical shared contracts/data models;
3. change integration epoch;
4. define/modify logical resource taxonomy;
5. promote an attempt branch to canonical integration;
6. mark Queue tasks MERGED/VERIFIED;
7. make final PARITY decisions;
8. accept cross-feature regressions;
9. form a release candidate;
10. classify a gate as BLOCKED_HUMAN.

Workers may propose shared-contract changes only inside their fenced attempt branch/evidence. They may not directly redefine canonical contracts.

## 4. Finalizer fence

For a task to be promotable, all must hold:

- Queue row still points to the same `task_id`.
- `claim_epoch` is the latest epoch for that task.
- `claim_token` matches the current Queue value.
- lease has not expired, or HQ explicitly revalidates the attempt before promotion.
- attempt branch is `task/<task-id>/attempt-<claim_epoch>`.
- current integration epoch is compatible.
- declared resource locks match the work actually performed.
- acceptance evidence exists and is readable.
- integration tests appropriate to the change pass.

If any fence fails, classify the attempt `STALE_ATTEMPT` or `NEEDS_REBASE`; do not overwrite a newer attempt.

## 5. Risk-first technical path

Canonical implementation priority:

Camera -> Player/Pose -> Ball -> Rim/Court calibration -> Temporal fusion -> Event detection -> Metrics -> Real-time feedback -> Session persistence/history -> robustness/performance.

UI polish may proceed only where it does not consume ownership needed for the above critical path. A vertical slice is an acceleration milestone, not PARITY completion.

## 6. Differential testing policy

Reference = current publicly available HomeCourt iPhone experience. Compare equivalent real motion input wherever practical. Minimum comparison families:

- event detection rate, false positive, false negative;
- make/miss accuracy;
- release-time and shot-location error;
- dribble/crossover recognition;
- pose continuity;
- end-to-end latency/FPS;
- steps/time from launch to measurement;
- thermal/memory/battery behavior;
- long-session stability;
- pause/resume, foreground/background, interruption recovery;
- confidence/unknown behavior.

Synthetic fixtures can protect regressions but cannot establish product accuracy PARITY.

## 7. Baseline gate

The Swift algorithm core is machine-testable and locally green. The full iPhone product baseline is not yet green because there is no canonical AVFoundation/Vision app target or iOS-capable integration CI lane. Treat this as `BLOCKED_DEPENDENCY`, not `BLOCKED_HUMAN`. Research/design/isolated benchmark tasks that do not depend on a green iOS application may still be READY.

## 8. Evidence standard

Every task evidence package must record:

- baseline integration SHA and epoch;
- claim epoch/token;
- exact changed paths;
- test commands and results;
- metrics where applicable;
- fixture/source provenance;
- known failures/unknowns;
- parity rows affected;
- rebase/finalize notes.

No evidence = no VERIFIED state.
