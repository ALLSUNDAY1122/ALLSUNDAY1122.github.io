# L4-W55｜Normalized Ledger Access Runbook

Classification: **NON_PARITY**

W55 does not change any W49-W54 record/head/checkpoint/handoff/custody payload root. It adds a mandatory normalization barrier and an outer normalization certificate for the W55 production path.

## Canonical production entrypoints

1. Observe append authorization with `AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.observeAppendCAS`.
2. Append only with `AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore.append` and the exact retained CAS.
3. Obtain custody snapshots with `AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.observeSnapshot`.
4. Create HQ custody material with `makeCertifiedCustodyBundle`; retain both the W52 roots and the W55 normalization/certificate roots outside the mutable ledger directory.
5. On selected physical iPhone, create/prepare/reopen durability probes only through `AnalysisIOSBridgeNormalizedDurabilityProbeCoordinator`.

The older W51/W52/W53 public entrypoints remain source-compatible, but they do not emit the W55 normalization receipt/certificate. They are not the W55 production custody path.

## Required normalization order

Every W55 canonical entrypoint obtains the W51 writer lease and performs:

`secure bootstrap -> preflight ledger temp set -> preflight records temp set -> recheck both plans -> W54 identity-checked GC -> W50/W53 recovery -> secure full reopen -> lease revalidation`

The two temp sets are fully validated before any GC begins. This specifically prevents a pre-existing malformed records temp from allowing ledger temp cleanup to happen first.

## Normalization receipt

`AnalysisPhysicalRealAudioBridgeConsumptionNormalizedAccessReceipt` SHA-binds:

- ledger ID
- removed ledger temp count
- removed records temp count
- whether interrupted-append recovery executed
- final sequence
- final ledger root
- final latest-record root

A receipt is valid only against the exact reopened ledger state it describes.

## Certified custody bundle

`AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyCertificate` binds the exact:

- W55 normalization receipt root
- W52 snapshot root
- W49/W50 strict checkpoint root
- external handoff root
- W52 custody receipt root

Do not store these roots independently without the certificate. A certificate from one normalized custody transaction must not be attached to another transaction even when human-readable fields look similar.

## Fail-close conditions

Stop the operation and preserve evidence when any of the following occurs:

- unsafe ledger ID
- ledger or records directory symlink/non-directory/path substitution
- more than 32 interrupted publication temps in either directory
- temp symlink, non-regular temp, oversized temp
- either directory's preflight set changes before GC
- W54 identity mismatch during unlink
- ambiguous interrupted append recovery
- secure reopened head/root mismatch
- stale append CAS
- stale custody snapshot
- checkpoint prefix mismatch
- normalization receipt root mismatch
- normalization receipt state differs from W52 snapshot
- normalized custody certificate mismatch
- physical probe ticket does not match normalized pre-snapshot/device/build/session/certificate
- reopened physical probe state is neither exact pre nor exact post permitted by its ticket

## Evidence boundary

Portable filesystem/Swift harnesses demonstrate the protocol and local fail-close behavior. They do not establish:

- actual APFS power-loss guarantees
- successful `F_FULLFSYNC` on the selected iPhone
- iOS process termination/suspension/relaunch durability
- Apple attestation or trusted time
- rights-cleared real-audio execution
- current Moises reference/differential quality
- product PARITY

Keep `MOI-P009/P011/P013/P016/P021` MISSING until their independent physical/reference requirements are satisfied and HQ performs Late Integration judgment.
