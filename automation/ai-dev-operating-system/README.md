# AI Development Operating System

Purpose: operate the app portfolio without requiring the user to reopen individual sessions and type `次`, while keeping Codex usage and desktop load bounded.

## v0.2 architecture

The normal path MUST NOT be `Executive ChatGPT -> Codex -> every session`. Codex usage would scale with the number of sessions.

Normal path:

1. Executive ChatGPT (`専務`) reviews portfolio state in batches and writes only decision deltas.
2. GitHub stores those deltas, project queues, session registry, leases, locks, checkpoints, and evidence.
3. A local non-LLM Dispatcher wakes eligible short-lived ChatGPT sessions according to the queue.
4. Each session reconstructs state from Notion/GitHub and executes one Macro Wave.
5. A local Resource Governor limits concurrent wakes from actual desktop/network load.
6. Codex is an exception plane only: setup, dispatcher repair, schema/architecture changes, repeated non-progress, semantic conflicts, and difficult integration.

## Source of truth

- Notion: product requirements, app ledger, human-facing state
- GitHub: portfolio state, task queues, session registry, claims, leases, checkpoints, evidence
- External systems: CI/TestFlight/App Store Connect actual state
- Conversation history is never canonical state

## Session policy

- Many sessions may be registered, but only a small bounded subset may generate simultaneously.
- Standard session lifetime: 3 Macro Waves. Rotate before a 4th unless explicitly classified safe.
- Replacement sessions do not inherit the full old conversation; they reconstruct current state from canonical sources.
- Session completion/timeout is not portfolio failure. The queue remains canonical and another session may resume.

## Local Dispatcher policy

- LLM cost: zero for normal routing.
- Reads compact queue/session metadata instead of asking Codex to produce per-session instructions.
- Sends only a standardized wake command to a session whose bootstrap contract is already installed.
- Does not continuously watch a generating tab. If busy, schedule a retry and exit.
- Obeys repository/logical-resource write locks.
- Performs deterministic session rotation and retry bookkeeping.

## Resource Governor

Initial conservative limits:

- concurrent ChatGPT generations: 3
- concurrent heavy upload/download tasks: 1
- concurrent Codex exception jobs: 1

Dynamic RAM gates:

- GREEN <70% used: allow configured concurrency
- YELLOW 70-80%: suppress new low-priority wakes and reduce concurrency
- RED >80%: stop new wakes; allow running work to finish/checkpoint
- CRITICAL >90% or sustained system responsiveness degradation: pause dispatcher and unload/close low-priority tabs where safe

Network governor:

- separate heavy-transfer concurrency from normal text generation
- reduce concurrency after repeated transport/retry errors or sustained latency degradation
- never wake all registered sessions at once

The exact safe concurrency is empirical. Record RAM peak, active sessions, transport retries, timeout rate, and completed waves; tune upward only after stable runs.

## Codex policy

Codex is not the normal dispatcher and must not confirm every Executive decision or write a separate prompt for every session.

Use Codex only when deterministic routing cannot safely decide the next action, including:

- initial setup / automation changes
- Local Dispatcher or Resource Governor failure
- queue/schema changes
- repeated non-progress threshold reached
- semantic conflicts / difficult integration
- exceptional release or architecture decisions

## Human Gate

Write only genuine human decisions to `ceo_inbox.json`. Timeout, stuck session, normal retry, session rotation, CI retry, and routine redispatch are not Human Gates.

## Core principle

Sessions are disposable; Codex is scarce; local deterministic orchestration is cheap. The system must keep progressing in normal operation even when Codex is not invoked.
