# L4-W54｜Durability namespace lifecycle runbook

Classification: **NON_PARITY**.

W54 hardens the local W53 durability namespace. It does not replace physical-iPhone/APFS evidence, current-Moises reference/differential evidence, rights-cleared real audio, or HQ final PARITY judgment.

## Required production order

All cooperating ledger operations that can consume or publish W53 state must remain under the W51 writer lease.

For W51 serialized append/CAS paths:

1. Acquire the W51 writer lease.
2. Validate the lease token/inode.
3. Bootstrap the canonical W50 ledger/records directories using secure no-symlink topology checks.
4. Run W54 interrupted-temp GC.
5. Run W50/W53 recovery.
6. Securely reopen the ledger and evaluate CAS.
7. Publish pending / immutable record / head through the W53 durable publication API.
8. Revalidate the writer lease and secure ledger state before return.

Do not delete `.w53-pub-*.tmp` using `FileManager.removeItem`, shell cleanup, wildcard deletion, or a path-only startup sweep.

## W54 GC rules

A temporary publication file is eligible for GC only when all conditions hold:

- name matches the W53 temporary namespace;
- its parent directory is opened and pinned with `O_DIRECTORY | O_NOFOLLOW`;
- the entry is inspected with `fstatat(..., AT_SYMLINK_NOFOLLOW)`;
- it is a regular file, not a symlink;
- it is within the per-file byte bound;
- the directory contains no more than 32 interrupted temporary files;
- immediately before deletion, device/inode/mode/size/link-count still equal the captured identity;
- deletion uses `unlinkat` on the pinned directory descriptor;
- the parent directory is `fsync`ed after deletion;
- the W51 writer lease still validates after GC.

A dangling symlink is an entry and must be rejected. It must not be interpreted as a missing file.

## W53 publication after W54

`replaceAtomically` and `createExclusive` pin the destination parent directory and use descriptor-relative namespace operations.

Mutable pending/head publication:

- capture the destination identity no-follow;
- create the same-directory temporary with `openat + O_EXCL + O_NOFOLLOW`;
- write all bytes;
- `F_FULLFSYNC` on Darwin when available, otherwise explicit `fsync` fallback;
- revalidate temporary identity;
- require destination identity to remain equal to the captured value;
- publish with `renameat`;
- sync the pinned parent directory;
- reopen through the pinned directory and verify exact bytes.

Immutable record publication:

- destination must be absent under `fstatat(..., AT_SYMLINK_NOFOLLOW)`;
- create/sync the temporary through the pinned parent;
- publish with exclusive `linkat` semantics;
- remove the temporary only if its identity is unchanged;
- sync the pinned records directory;
- reopen and compare exact bytes.

Durable deletion:

- pin the parent directory;
- inspect the target no-follow;
- reject symlink/non-regular targets;
- recheck exact entry identity;
- remove with `unlinkat`;
- sync the parent directory.

## Fail closed

Stop without guessing or replacing evidence when any of the following occurs:

- dangling or live symlink in the interrupted-temp namespace;
- non-regular or oversized temporary;
- >32 interrupted temporary files in one controlled directory;
- parent directory device/inode changes after pinning;
- entry identity changes between inspection and unlink;
- destination identity changes before `renameat`;
- immutable destination appears before `linkat`;
- writer lease token/inode mismatch;
- W50 secure topology/reopen failure;
- W51 CAS mismatch;
- W53 recovery yields an ambiguous state.

## Evidence boundary

Portable Linux/POSIX tests can establish namespace and recovery protocol behavior. They cannot establish actual APFS power-loss persistence or successful `F_FULLFSYNC` on the selected physical iPhone. The W53 physical probe remains required for those claims.
