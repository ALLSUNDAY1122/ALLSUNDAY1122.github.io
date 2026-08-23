# L3-AW16｜Production Token Dispatch / Coalescing Adapter

Result: `COMPLETE_NON_PARITY`

## Goal

Reduce avoidable generation churn from rapid seek / loop / tempo controls without weakening the fail-closed generation authority established by AW12-AW15.

The core rule is structural: **coalescing happens before a Playback reschedule token is generated**. A token represents an externally advanced Playback generation. Discarding or cancelling an intent after token generation cannot be treated as a harmless UI debounce because that generation may already supersede the current Playback/DSP replacement authority.

## Production implementation

`Playback/Sources/Lane3ProductionIntentDispatcher.swift`

`Lane3ProductionIntentDispatcher` is a project-scoped upstream adapter around one `RescheduleFencedPlaybackBackend` and one `PracticeDSPGenerationCoordinator`.

Continuous coalescing families:
- `seek`
- `loop`
- `tempo`

Default quiet period is 16 ms for each family. This is a provisional production-safe starting value, **not** a final iPhone UX tuning claim. HQ must tune it on the target device against response latency and generation churn.

### Routing audit

| Playback reason | Required coordinator path |
| --- | --- |
| `tempoChange` | `PracticeDSPGenerationCoordinator.applyTempoRatio` |
| `recovery` | `PracticeDSPGenerationCoordinator.recover` |
| seek / loopChange / play / pause / media / interruption | transport binding path where applicable |

`Lane3ProductionTokenRouting` makes this mapping explicit so tempo and recovery tokens cannot accidentally be routed through generic transport binding.

## Coalescing semantics

1. Obvious invalid input is rejected before token generation.
2. Within a family, only the latest pending intent survives the quiet period.
3. Superseded pending intents complete as `superseded` and consume no Playback generation.
4. Different families may be pending simultaneously, but actual token generation and coordinator mutation are serialized globally.
5. Once actual token dispatch starts, caller cancellation does not abort a half-issued generation. The operation is allowed to reach a safe commit/failure boundary and records `callerCancellationObservedAfterDispatch`.
6. A pending caller cancellation before dispatch consumes no token.

This is intentionally different from cancelling an already-started AW15 coordinator operation. Upstream coalescing prevents most continuous-control churn from reaching that lower-level fail-closed machinery at all.

## Backend failure after token generation

`RescheduleFencedPlaybackBackend` advances its generation before delegating to the backend. Therefore `seekAndReturnToken` or `setLoopAndReturnToken` can throw after a new Playback generation exists without returning the token to the caller.

The AW16 dispatcher handles this by:
1. snapshotting the Playback fence before the mutation;
2. snapshotting it again after the throw;
3. accepting the post-failure snapshot as the failed token only if generation advanced and the expected reason matches;
4. immediately issuing a newer `.recovery` Playback token;
5. calling `PracticeDSPGenerationCoordinator.recover` with that newer token.

This prevents an older DSP replacement binding from remaining authoritative after a Playback backend failure.

## Recovery blocking

If automatic recovery fails, the dispatcher sets `recoveryBlocked=true` and rejects all new continuous controls **before token generation**. It does not continue consuming generations in a known-poisoned state.

HQ/integration can call `retryRecovery()`. Continuous dispatch resumes only after that recovery succeeds.

A `failedAfterDispatch` outcome with `automaticRecovery.succeeded=true` means the requested user operation failed, but combined generation authority is safe again. The UI may retry the latest intent; it must not treat the original operation as successful.

## Portable validation

Environment:
- Swift 6.2.1
- Linux x86_64
- exact AW16 dispatcher source with interface-compatible Playback/coordinator types

### Basic rapid seek

500 concurrent seek intents:
- executed: 1
- superseded before token: 499
- actual Playback tokens/backend seeks: 1

Invalid NaN tempo was rejected with no generation change.

Forced seek backend failure:
- failed seek generation: 2
- automatic recovery Playback generation: 3
- recovery succeeded

A subsequent tempo mutation executed at Playback generation 4.

Pending caller cancellation generated no token.

### Mixed-family burst

300 simultaneous intents:
- 100 seek
- 100 loop
- 100 tempo

Results:
- executed: 3 (latest one per family)
- superseded before token: 297
- actual Playback tokens: 3

Invalid seek/loop/tempo inputs consumed no generation.

Failure/recovery probe:
- failed control generation 4 -> automatic recovery generation 5
- later failed control generation 6 -> forced automatic recovery failure generation 7
- dispatcher became recovery-blocked and generated no further continuous-control token
- explicit recovery retry generation 8 succeeded

### Stress burst

500 bursts × 30 intents = 15,000 intents:
- executed: 1,500
- superseded before token: 13,500
- actual Playback tokens: 1,500

The 90% token reduction is only the result of this deterministic stress shape. It is not a product-traffic reduction claim.

### Portable benchmark

20 rounds × 2,000 concurrent seek intents, 2 ms benchmark quiet period:
- median: 19.838 ms / round
- p95: 24.113 ms
- max: 25.193 ms
- checksum: 40,810

Each round generated exactly one actual Playback token/backend seek and superseded 1,999 intents before token generation.

Benchmark excludes AVAudioEngine, AudioUnit, real Playback backend cost, production DSP controller cost, device IO, real audio and current-Moises execution.

## Repository validation prepared

- `Playback/Tests/L3_AW16_ProductionIntentDispatcherSelfTest.swift`
- `Playback/Tests/L3_AW16_ProductionIntentDispatcherBenchmark.swift`

The repository self-test covers:
- explicit reason routing;
- 500-intent seek coalescing;
- invalid input with zero generation consumption;
- backend failure token reconstruction + automatic recovery;
- tempo path routing;
- pending cancellation before token generation;
- automatic recovery failure and recovery-blocked behavior;
- explicit recovery retry;
- final exact replacement-binding validation.

Full selected Lane-3 / Xcode execution remains an HQ Late Integration gate because the build harness is Lane 4/HQ-owned.

## HQ integration requirements

- Instantiate one project-scoped dispatcher around the same project-scoped `RescheduleFencedPlaybackBackend` and `PracticeDSPGenerationCoordinator`.
- Route continuous seek / loop / tempo UI intents through this dispatcher **before** calling any token-producing Playback method.
- Never pre-generate a Playback token and then send the request to this dispatcher; that defeats coalescing safety.
- Keep discrete lifecycle controls such as media replacement and interruption on their required direct paths; serialize them against continuous dispatch at the integration boundary.
- Tempo tokens must use `applyTempoRatio`; recovery tokens must use `recover`.
- When `failedAfterDispatch` reports successful automatic recovery, retry the latest desired control if appropriate; do not report the failed operation as applied.
- When `recoveryBlocked=true`, do not bypass the dispatcher by issuing more continuous-control tokens. Recover first.
- Tune the default 16 ms quiet period on the target iPhone using both user-perceived responsiveness and generation-churn evidence.

## Claim boundary

This Wave proves portable routing/coalescing/recovery semantics only. It does not prove:
- Apple SDK compile/runtime;
- real AVAudioEngine scheduling behavior;
- physical-iPhone control latency;
- audible click/pop freedom;
- real-track stability;
- current-Moises UX or audio parity.

`parityPromotionAllowed = false`.
