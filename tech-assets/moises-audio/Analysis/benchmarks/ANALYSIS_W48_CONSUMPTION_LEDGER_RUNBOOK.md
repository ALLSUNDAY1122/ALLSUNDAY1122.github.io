# W49｜W48 bridge-certificate consumption ledger runbook

## Purpose

W49 prevents operators from manually transcribing the W48 `previouslyConsumedW47PackageRootSHA256s` inventory and makes successful W48 consumption history locally append-only and chain-verifiable.

This is NON_PARITY infrastructure. It does not establish Moises feature parity.

## Production flow

1. Execute W48 and retain the exact `AnalysisPhysicalRealAudioParityBridgeCertificate`.
2. Append that certificate exactly once with `AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.append` and HQ custody metadata.
3. Before the next W48 call, obtain the replay inventory only through `expectationUsingDurableConsumedInventory`. Do not hand-edit the consumed-root list.
4. After meaningful ledger advancement, create checkpoints through `makeStrictCheckpoint`. For checkpoint sequence > 1, provide the prior externally retained checkpoint. Strict mode requires that checkpoint to be the exact historical prefix of the current ledger, including prefix ledger root, latest record root and consumed package inventory.
5. Create the external custody artifact through `makeStrictExternalAnchorHandoff`. For sequence > 1, provide the prior externally retained handoff. The previous handoff must reference the checkpoint root that the new checkpoint names as its predecessor.
6. Persist the new checkpoint root and handoff root outside the W49 ledger directory under HQ custody. A local-only copy cannot prove whole-directory rollback resistance.
7. On reopen or before adjudication reuse, call `loadValidatedHead` and `verifyCurrentLedgerStrict` before trusting the ledger state.

## Fail-close conditions

Reject and investigate if any of these occur:

- reused bridge ID;
- reused W47 package root;
- reused W48 certificate root;
- record sequence discontinuity;
- record predecessor mismatch;
- record body/root mismatch;
- ledger head/root mismatch;
- record file not referenced by the head (fork/orphan history);
- stale checkpoint replay after the ledger advances;
- predecessor checkpoint that is valid in isolation but is not the exact historical prefix of the current ledger;
- checkpoint mutation with a reused declared root;
- external handoff whose predecessor does not correspond to the checkpoint predecessor chain.

## Recovery model

The ledger uses a pending marker, writes the immutable record, writes the new head, then removes the marker. Reopen repairs the record-written-before-head state only when the candidate record, previous head roots and predecessor relationship are unambiguous. Ambiguous recovery states fail closed.

## Required HQ custody

HQ should preserve outside the mutable ledger directory:

- current checkpoint JSON/root;
- current external handoff JSON/root;
- predecessor checkpoint and handoff roots;
- the corresponding W48 certificate;
- the W48 expectation and W46 adjudication report referred to by that certificate.

## Remaining gates

W49 does not replace:

- a genuine selected physical-iPhone W47 execution;
- rights-cleared real-audio corpus custody;
- current-iPhone Moises W19-W21 reference observations;
- W46 paired differential evidence;
- independent HQ PARITY judgment;
- canonical SwiftPM/XCTest and integrated Xcode/iphoneos execution.
