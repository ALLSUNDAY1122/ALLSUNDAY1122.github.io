# Recovery Contract

## Required task fields

Every automatically recoverable task must expose:

- `task_id`
- `status`
- `priority`
- `dependencies`
- `baseline_sha`
- `integration_epoch`
- `resource_locks`
- `write_scope`
- `claimed_by`
- `claim_token`
- `claim_epoch`
- `lease_expires_at`
- `heartbeat_at`
- `last_progress_at`
- `attempt_count`
- `attempt_branch`
- `last_checkpoint_sha`
- `acceptance`
- `evidence`

## Stale detection

A task attempt is stale when its lease is expired and either heartbeat or observable progress is outside the configured tolerance. A worker must never decide that its own stale claim is still canonical.

## Fencing

Reclaim increments `claim_epoch`. Only the latest `(task_id, claim_epoch, claim_token)` may:

- update canonical task completion state;
- release canonical logical resource locks;
- merge/promote to canonical branches;
- trigger production/release side effects.

Revived older attempts may preserve evidence on their isolated attempt branch but may not promote it.

## Recovery ladder

1. Luna retries from canonical source of truth and latest valid checkpoint.
2. If repeated automated recovery fails, create a Terra recovery decision task with logs/evidence and failure history.
3. If Terra determines that AI cannot proceed without a genuine external human decision/input, create one item in `ceo_inbox.json`.

Routine timeout, stuck execution, CI failure, rebase, stale lease, and ordinary implementation failure are not human gates.

## Checkpoint discipline

Before an attempt ends or is likely to time out, persist every safe, meaningful change and the evidence needed by the next attempt. Never depend on local workspace survival or conversation memory.
