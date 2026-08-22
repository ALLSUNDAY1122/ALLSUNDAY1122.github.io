# Codex Exception Roles

Codex is NOT the normal per-session dispatcher. Routine wake, retry, rotation, queue polling, and resource gating belong to the local non-LLM Dispatcher/Resource Governor. The normal system must be able to progress with zero Codex calls.

## A. Terra Executive Recovery / Architecture

Invoke only when one of these conditions is present:

1. repeated non-progress beyond the configured threshold
2. semantic or logical-resource conflict that deterministic rules cannot resolve
3. queue/schema/dispatcher architecture change
4. difficult integration or parity/release judgment
5. evidence-complete escalation from a local/session worker

On each run:

- reconstruct state from Notion/GitHub/external evidence
- decide the smallest durable correction
- update canonical queue/contracts rather than writing bespoke prompts to many sessions
- prefer one policy/queue delta that many sessions can consume
- never remain running as a watchdog
- never individually confirm every Executive ChatGPT decision

## B. Luna Tooling Repair

Invoke for bounded technical repair of the Local Dispatcher, session registry, Resource Governor, or deterministic automation scripts.

- repair the mechanism, not individual sessions one-by-one
- write tests/evidence so the same failure becomes deterministic next time
- return normal operation to the local non-LLM path as soon as possible

## C. Release Exception

Invoke only when routine release automation cannot resolve the issue or when a genuine semantic/release decision is required.

Routine CI status checks, ordinary retries, queue rotation, and standard API-first release progress should not require Codex.

## Shared budget rule

GREEN: exception calls allowed when trigger conditions exist.
YELLOW: only high-priority recovery/release/architecture exceptions.
RED: no new Codex work except an explicitly approved emergency; persist evidence and let the local dispatcher pause/resume based on canonical state.

## Cost invariant

Codex calls MUST NOT scale linearly with the number of ChatGPT sessions. Increasing registered sessions from 10 to 100 should not create 10x routine Codex supervision work. If a proposed design does that, reject the design and move the repeated behavior into deterministic queue/dispatcher logic.
