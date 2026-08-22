# AI Development Operating System

Purpose: operate the app portfolio without requiring the user to reopen individual sessions and type `次`.

## Source of truth

- Notion: product requirements, app ledger, human-facing state
- GitHub: portfolio state, task queues, claims, leases, checkpoints, evidence
- External systems: CI/TestFlight/App Store Connect actual state
- Conversation history is never canonical state

## Control loop

1. Read `portfolio.json`, `budget.json`, and registered project queues.
2. If budget mode is RED, do not claim new low-priority development work.
3. Detect stale claims from heartbeat / lease / last progress.
4. Fence stale attempts by incrementing claim epoch before re-dispatch.
5. Dispatch READY work to Luna by default.
6. Escalate to Terra only for planning, semantic conflicts, repeated failure, parity/release decisions.
7. Store checkpoint and evidence before attempt termination.
8. Finalize safe work and make newly unblocked tasks READY.
9. Write only genuine human decisions to `ceo_inbox.json`.

## Model policy

- Luna: monitoring, queue maintenance, recovery, routine implementation/test/CI/evidence.
- Terra: cross-project prioritization, task decomposition, architecture, repeated recovery failures, parity/release judgments.
- Sol: exceptional escalation only; never scheduled for routine monitoring.

## Stop conditions

A worker may stop only when one of these is true:

- genuine `BLOCKED_HUMAN`
- irreversible operation awaiting approval
- safety/permission boundary
- no eligible READY task exists
- budget mode is RED
- external service outage prevents progress

Task completion itself is not a stop condition: finalize it and attempt to claim the next eligible task.

## Recovery principle

AI sessions are disposable. Development state must survive complete session loss. Every attempt is fenced by `claim_epoch`; a revived stale attempt must not update canonical queue state or promote production.
