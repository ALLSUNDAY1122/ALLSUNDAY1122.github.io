# L4-W41 Validation

Status: **NON_PARITY integrity / transfer verification evidence**

## Canonical refresh

At the start of W41 the latest Notion/GitHub state was re-read.

- Operating model remains v4 / 4 Autonomous Independent Lanes / Late Integration.
- Worker 4 ownership remains `Analysis/**`, `Package.swift`, `Tests/**`, `iOS/**`, and worker-4 status only.
- Integration PR #4431 had advanced to Epoch 26.
- Epoch 26 integrated L2 AW36-AW37 and L3 AW35-AW36; Lane 4 remained canonical through W38.
- W39+ remained post-Epoch26, so the Worker branch was not rebased.
- Frozen base compare at W41 start: ahead 421 / behind 0.
- MOI-P009, P011, P013, P016 and P021 remained MISSING; PARITY promotions remained zero.

## W41 implementation checks

W41 adds a post-publication audit and transferable evidence package above W39/W40.

The published-batch re-opener:

- reads the W40 publication control rather than enumerating evidence,
- reads all six W27/W38 documents,
- reads exactly eleven W27 singleton bytes,
- reopens every W39 run from its publication control and exact nine declared artifacts,
- rejects symlink/non-regular W39 controls or artifacts,
- recomputes every W39 bundle root,
- recomputes the W27 root and reconstructs the expected successful W27 report instead of trusting the cached report,
- recomputes the W38 root against the recomputed W27 root and reconstructs the expected successful W38 report,
- recomputes the W40 root,
- verifies that W27/W38 manifest entries exactly match the W39-derived projections and singleton set.

For N runs, the W41 source inventory is exactly `18 + 10N` files.

The transfer builder/exporter:

- copies exact source bytes into `transfers/<transferID>/payload/<source-relative-path>`,
- records source path, payload path, role/run binding, SHA-256 and byte length,
- computes a deterministic W41 transfer root,
- stages under `.w41-staging-<transferID>-<root-prefix>`,
- verifies the complete stage before same-parent publication,
- reopens source evidence immediately before and after publication,
- rejects a stale/foreign stage for the same transfer ID when its root-derived stage name differs,
- never overwrites an existing final transfer directory.

The destination verifier:

- validates every declared payload hash/length,
- rejects missing, truncated, replaced or undeclared regular files,
- rejects symbolic links,
- recomputes the W41 transfer root,
- reopens the transferred `payload/` as an independent archive root,
- recomputes W39 → W27 → W38 → W40 again,
- rebuilds the expected W41 manifest and requires exact equality.

## Durable XCTest source added

`Tests/MoisesAudioCoreTests/AnalysisPhysicalEvidenceTransferTests.swift` covers:

1. published W40 re-open with W39/W27/W38/W40 root recomputation,
2. transfer publication and verification,
3. verification after copying the final transfer directory to another destination,
4. truncated payload rejection,
5. unexpected payload file rejection,
6. W39 mutation after W40 publication rejection,
7. cached W27 report mutation rejection,
8. matching interrupted-stage recovery,
9. corrupt interrupted-stage preservation as ambiguous.

The production stage guard also rejects a same-transfer-ID stale stage with a different root-derived name; this condition was exercised in the portable filesystem mirror below.

## Canonical SwiftPM status

Fresh full Worker-branch SwiftPM/XCTest: **NOT_OBSERVED**.

The Worker container still could not resolve GitHub:

```text
fatal: unable to access 'https://github.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io.git/': Could not resolve host: github.com
```

No full-branch test pass is claimed from this environment.

## Swift 6.2.1 portable source-shaped transfer mirror

Compilation:

```text
swiftc -warnings-as-errors ...
COMPILE_PASS
```

Completed run:

```text
W41_SWIFT_MIRROR_PASS checks=1500 filesystem_checks=120 elapsed=6.911719323000001 seconds
```

`/usr/bin/time -v`:

- maximum RSS: 22,184 kB
- exit status: 0

The 1,500 inventory/tamper checks include valid transfer validation, payload-byte tamper rejection and source-path rebinding rejection.

The 120 real temporary-filesystem checks cover exact manifest inventory, unexpected-file rejection, payload truncation rejection and same-transfer-ID foreign-stage rejection.

An earlier intentionally larger Swift mirror combined compile with 20,000 SHA-heavy iterations plus 120 filesystem transactions and exceeded the 45-second execution limit. It is **TIMEOUT_NOT_COUNTED_AS_PASS**.

## SHA-256 transfer-root mirror

Completed:

```text
W41_ROOT_MIRROR_PASS mutations=60000 elapsed=9.753s maxrss_kb=109992
```

`/usr/bin/time -v` separately reported maximum RSS 110,224 kB and exit status 0.

10,000 independent packages were checked. For each package, changing each of the following failed to preserve the W41 root:

- W40 root,
- W27 root,
- W38 root,
- one W39 run root,
- one transfer-item hash,
- one transfer-item source path.

An earlier 50,000-package setting exceeded 45 seconds and is **TIMEOUT_NOT_COUNTED_AS_PASS**.

## Explicit non-claims

W41 does not prove:

- physical iPhone execution,
- selected Xcode / Apple ARM compile,
- APFS hardware durability,
- genuine Lane-2 bounded decoder behavior,
- real RSS / physical-footprint / thermal / battery / cancellation acceptance,
- current-Moises differential behavior,
- hardware-origin attestation,
- Secure Enclave provenance,
- a signature or trusted timestamp,
- MOI-P021 PARITY.

A coordinated rewrite of an entirely unanchored W39/W40 source tree before W41 can produce a new internally consistent transfer package. HQ must retain an independently anchored prior root set, or use an external signing/timestamp mechanism if stronger provenance is required.

## Result

W41 materially removes the post-publication/copy integrity gap: the exact evidence package can now be copied and independently re-opened at the destination without trusting cached W27/W38 reports or source directory enumeration.

PARITY state is intentionally unchanged.
