# W56 Legacy bypass containment runbook

Classification: **NON_PARITY**.

## Production rule

New production bridge-consumption custody must use the W55 normalized APIs:

- `AnalysisPhysicalRealAudioBridgeConsumptionNormalizedConcurrentStore`
- `AnalysisPhysicalRealAudioBridgeConsumptionNormalizedCustodyManager.makeCertifiedCustodyBundle`
- `AnalysisIOSBridgeNormalizedDurabilityProbeCoordinator`

Retain the W55 normalization receipt and, for custody bundles, the normalized-custody certificate together with the existing W52 snapshot/checkpoint/handoff/custody roots outside the mutable ledger directory.

## Legacy API behavior

W51/W52/W53 compatibility entrypoints are not production custody APIs.

- Debug builds: legacy calls are migration shims that route through W55 normalized implementations, then project the result back into the historical return shape.
- Release builds: legacy calls fail closed before returning a value that silently omits W55 normalization/certificate evidence.
- `SecureCheckpointManager` keeps an internal core path only when the caller is already inside the authoritative internal writer lease. This is required by W55 normalized custody and is not externally callable as a writer-lock capability.

The build-mode guard is not a cryptographic security boundary. A modified binary can change local code. It exists to prevent accidental production use of old APIs in the supported build.

## Compatibility invariants

Do not change W49-W55 record, ledger, checkpoint, handoff, snapshot, custody-receipt, normalization-receipt, or normalized-custody-certificate hash payload formats as part of migration containment.

In particular, the four W52 `QuiescentCustodyManager.limitations` strings are part of the W52 custody receipt hash and must remain byte-for-byte unchanged.

Pure W52 model validation/root functions remain usable because W55 evidence is intentionally built on those unchanged formats.

## Verification

Before HQ integration:

1. Confirm every legacy API in the W56 inventory is either Debug-routed or Release-rejected.
2. Confirm writer-lease marker scope is false outside the critical section, true inside/nested, and false after exit.
3. Confirm Debug migration results are equal to W55 normalized results for W51 CAS/append, W52 snapshot/custody, and secure checkpoint.
4. Compile/run the policy harness with Swift warnings-as-errors in both Release-like and `-D DEBUG` configurations.
5. HQ must semantic-integrate W53, W54, W55, then W56 and run canonical SwiftPM/XCTest. Portable harnesses are not the project compile result.

## External gates

W56 does not prove physical iPhone/APFS durability, rights-cleared real-audio execution, genuine Lane2 decoder integration, current-iPhone Moises reference/differential, perceptual parity, performance parity, or product PARITY.
