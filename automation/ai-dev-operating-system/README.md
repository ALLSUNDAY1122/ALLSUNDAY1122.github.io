# AI Development Operating System

Purpose: operate the app portfolio without requiring the user to reopen individual sessions and type `次`, while keeping Codex usage and desktop load bounded.

## v0.2 architecture

The normal path MUST NOT be `Executive ChatGPT -> Codex -> every session`. Codex usage would scale with the number of sessions.

Normal path:

1. Executive ChatGPT (`専務`) reviews portfolio state in batches and writes only decision deltas.
2. GitHub stores those deltas, project queues/lane plans, session registry, claims, locks, checkpoints, and evidence.
3. A local non-LLM Chrome Dispatcher wakes eligible short-lived ChatGPT sessions according to each project's dispatch contract.
4. Each session reconstructs state from Notion/GitHub and executes one Macro Wave.
5. The Chrome extension Resource Governor limits concurrent wakes from actual system load.
6. Codex is an exception plane only: setup, dispatcher repair, schema/architecture changes, repeated non-progress, semantic conflicts, and difficult integration.

## Source of truth

- Notion: product requirements, app ledger, human-facing state
- GitHub: portfolio state, task queues/lane plans, claims, worker status, locks, checkpoints, evidence
- External systems: CI/TestFlight/App Store Connect actual state
- Conversation history is never canonical state

## Session policy

- Many sessions may be registered, but only a small bounded subset may generate simultaneously.
- Standard session lifetime: 3 Macro Waves. After the third dispatch, mark `ROTATE_AFTER_RESPONSE` and do not send a fourth automatically.
- Replacement sessions do not inherit the full old conversation; they reconstruct current state from canonical sources.
- Automatic successor-chat creation is not yet production-approved. It must be separately verified before enabling.

## Dispatcher v2.1 adapters

### fixed_role_queue
Used by app-development-2. A registered role is woken only when its queue task remains eligible. Human-required states are excluded.

### atomic_pool
Used by HomeCourt. The Dispatcher never pre-claims or assigns a specific READY task. It only wakes an idle pool worker. The worker must win the project's canonical CAS atomic claim and read back its `claim_token + claim_epoch` before work begins. The Dispatcher never wakes more atomic-pool workers in one tick than the current READY count.

### fixed_lane_plan
Used by Moises v3. Workers do not claim the Global Queue. The Dispatcher reads the lane plan plus worker-status files, wakes only lanes with unfinished Macro Bundles, and does not send `次` to `CHECKPOINT_READY` lanes. A registered HQ can be woken for Late Integration when lane checkpoints exist.

The Dispatcher MUST NOT overwrite project-specific claim, ownership, or lane contracts.

## Resource Governor

Initial conservative limits implemented in the Chrome extension:

- GREEN: concurrent ChatGPT generations <= 3
- WARN: <= 2
- THROTTLE: <= 1
- STOP: no new dispatch
- concurrent heavy upload/download tasks <= 1

Dynamic system gates:

- RAM >=70%: WARN
- RAM >=80%: THROTTLE
- RAM >=90%: STOP
- CPU >=75%: WARN
- CPU >=85%: THROTTLE
- CPU >=95%: STOP
- ChatGPT tabs >12: cap new active work at 2
- ChatGPT tabs >20: cap at 1
- recent 20 dispatch attempts with >=30% failure rate: reduce concurrency one step

Existing busy workers are counted before new dispatch. New wakes are limited to `maxActive - busyCount`, preventing old busy work plus new work from exceeding the cap.

On the first CPU sample, the extension takes two samples 500 ms apart rather than treating CPU load as zero.

The Resource Governor uses Chrome Manifest V3 `system.memory` and `system.cpu`; a separate Windows resident monitor is not required for the initial implementation.

## Network / heavy I/O policy

Exact line-rate measurement is not implemented. Heavy transfers are separately limited to one active worker, and repeated dispatch/transport failures reduce parallelism. Do not describe this as full network bandwidth shaping.

## Codex policy

Codex is not the normal dispatcher and must not confirm every Executive decision or write a separate prompt for every session.

Use Codex only when deterministic routing cannot safely decide the next action, including:

- initial setup / automation changes
- Local Dispatcher or Resource Governor failure
- queue/schema changes
- repeated non-progress threshold reached
- semantic conflicts / difficult integration
- exceptional release or architecture decisions

Codex calls MUST NOT scale linearly with registered ChatGPT sessions.

## Current Portfolio adapters

- app-development-2: ACTIVE / fixed_role_queue
- moises-parity: ACTIVE / fixed_lane_plan
- homecourt-parity: ACTIVE / atomic_pool
- scaniverse-parity: migration required before automatic dispatch

## Human Gate

Write only genuine human decisions to `ceo_inbox.json`. Timeout, stuck session, normal retry, session rotation, CI retry, and routine redispatch are not Human Gates.

## Core principle

Sessions are disposable; Codex is scarce; deterministic local orchestration is cheap. The system must keep progressing in normal operation even when Codex is not invoked.
