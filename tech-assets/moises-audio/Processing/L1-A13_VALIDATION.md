# L1-A13 Validation — Audio Artifact Integrity Deep Validation

Captured: 2026-08-23 JST
Worker: `Moises-Worker-1`
Branch: `moises/wp1-separation-processing`
Result: `COMPLETE_NON_PARITY`

## Goal

Prevent a successful vendor download, plausible filename, or previously cached result from being mistaken for a trustworthy project-visible stem.

A13 extends the existing M03 output-assurance transaction rather than replacing it. The existing path already enforced role/count identity, declared audio metadata, SHA-256/byte binding, staging, full-set commit and final-file hash verification. A13 closes deeper file-structure, decoded-sample, cross-stem timing/container and cached-manifest identity gaps.

## Implementation

### `Separation/Sources/SeparationOutputIntegrity.swift`

`WAVInspection.read` now performs a bounded-memory full-file validation pass.

Hard structural checks:

- actual file size is read before parsing;
- RIFF/WAVE magic is sniffed from bytes, not inferred from filename;
- RIFF-declared size must exactly match the stored file;
- every chunk must fit inside the RIFF boundary;
- duplicate `fmt ` or `data` chunks are rejected;
- required `fmt ` and `data` chunks must exist;
- PCM, IEEE float and WAVE_FORMAT_EXTENSIBLE subformat handling is explicit;
- supported PCM widths: 8/16/24/32-bit;
- supported float widths: 32/64-bit;
- channel count, sample rate, bits/sample, block-align and byte-rate must be internally consistent;
- data bytes must be positive and frame aligned;
- the complete data chunk is streamed and decoded; a seek over a truncated body can no longer masquerade as a valid file;
- observed sample count must equal frame-count × channels;
- float NaN/Inf is rejected;
- implausible float amplitude outside the defensive bound is rejected;
- numeric accumulation must remain finite.

Inspection metrics:

- absolute peak;
- RMS;
- zero-sample fraction;
- clipped-sample fraction;
- analyzed sample count.

Quality/pathology flags:

- `DIGITAL_SILENCE`;
- `NEAR_SILENCE`;
- `PATHOLOGICAL_CLIPPING`.

These three are deliberately flags rather than unconditional corruption failures. A valid separator can legitimately output silence or an extremely sparse stem when the requested instrument is absent. Converting those observations to hard quality failures requires rights-cleared real-audio evidence and role-aware thresholds, not a synthetic assumption.

The existing streaming `SHA256FileHasher` remains the cryptographic file binding used by the assurance ledger.

### `Separation/Sources/SeparationArtifactSetIntegrity.swift`

Adds pre-promotion set-level validation:

- declared WAV/WAVE container only;
- URL extension is checked when present; `.mp3` or another conflicting extension cannot be labeled as WAV;
- extensionless signed URLs remain valid because the bytes are sniffed after download;
- declared frame/rate/duration consistency;
- cross-stem sample-rate consistency;
- cross-stem frame alignment within the configured timing tolerance;
- cross-stem duration alignment;
- invalid timing tolerance fails closed.

It also binds cached/prepared results to immutable logical artifact identity. For the same job, the following must remain stable before a cached result may be reused:

- project/job identity;
- provider identity/kind;
- model name/version;
- quality profile;
- requested role set;
- each role-to-stem ID mapping.

Signed output URLs, expiry data and cost telemetry are intentionally not part of this immutable identity because those values may legitimately rotate while the actual job/artifact identity remains the same.

### `Separation/Sources/AssuredSeparationProvider.swift`

`result()` now performs, before any cached/prepared ledger reuse:

1. requested job-ID check;
2. artifact-set integrity validation;
3. the existing complete manifest validation;
4. cached-manifest identity validation when a ledger already exists.

Only after those checks does it enter the existing M03 assurance flow:

`download -> project staging copy -> deep WAV scan -> declared metadata comparison -> size/SHA binding -> full-set prepared ledger -> atomic commit -> final hash verification -> StemArtifact`.

This closes the path where a malformed new manifest could otherwise inherit a previously trusted committed ledger.

## Machine verification

Compiler/runtime environment:

- Swift compiler: `6.2.1` (`x86_64-unknown-linux-gnu`).
- New `AssuredSeparationProvider` + `SeparationArtifactSetIntegrity` connection typechecked successfully in Swift language mode 6 using lane-local contract stubs.

Executed deep-WAV suite against the exact A13 `SeparationOutputIntegrity.swift` implementation:

- **22 / 22 PASS**.

Coverage includes valid PCM 8/16/24/32, float32/float64, RIFF size truncation/trailing bytes, duplicate chunks, byte-rate/block-align failures, digital silence, near-silence, pathological clipping, NaN, extreme float samples, unsupported codec/sample width, zero data and a known SHA-256 vector.

Executed artifact-set baseline suite:

- **10 / 10 PASS**.

Executed post-cached-identity regression suite:

- **11 / 11 PASS**.

The regression suite includes stable cached identity plus provider/model identity change, requested-role change and role-to-stem identity change fail-close behavior, while rechecking set alignment paths.

Total machine test executions recorded for this Wave: **43**, failures: **0**. Some set scenarios are intentionally repeated in the regression suite after the cached-identity change.

Durable test source:

`Separation/Tests/L1_A13_ArtifactIntegritySelfTest.swift`

Machine-readable ledger:

`Processing/Tests/L1-A13_ARTIFACT_INTEGRITY_MATRIX.json`

## Start-time boundary

The frozen `VendorStemOutputDescriptor` contains frame count and duration but no authoritative source-relative start-time field. A13 therefore enforces the timing information that actually exists—cross-stem frame/duration alignment—and does **not** invent a source-relative onset value.

If a future provider exposes trustworthy non-zero media start timestamps, that value should be added through the HQ-owned contract process or retained in a Lane 1 provider-specific manifest before a start-time parity claim is made. Audible onset alignment still belongs in the real-audio differential gate.

## Regression / promotion reasoning

A corrupt or mislabeled vendor response now fails before project-visible promotion when any of these occurs:

- zero/truncated/extra bytes inconsistent with RIFF;
- invalid or unsupported WAV structure;
- impossible sample properties;
- NaN/Inf/pathological numeric values;
- declared-vs-observed sample-rate/channel/frame/duration mismatch;
- declared byte-count/SHA mismatch from the existing M03 gate;
- conflicting URL extension/container claim;
- multi-stem timing mismatch;
- changed cached provider/model/role/stem identity;
- incomplete/duplicate role set or duplicate stem identity from the existing M03 gate.

All checks remain server/project controlled; no vendor filename or HTTP success code is treated as proof of artifact correctness.

## Remaining external/live evidence

A13 does not prove:

- real provider output quality;
- that silence/clipping flag thresholds correspond to audible failure for each role/genre;
- source-relative onset parity because the frozen descriptor does not carry start-time metadata;
- current-iPhone Moises artifact quality;
- P003/P004/P005 PARITY.

Those remain real-provider, rights-cleared real-audio and HQ differential gates.

## PARITY

`parity_state = NON_PARITY_EVIDENCE_ONLY`.

No `PARITY_MATRIX.json` row is promoted by A13. This Wave closes the lane-engineering integrity gap required to ensure corrupt/partial/mislabeled audio cannot be accepted merely because it downloaded or because an older ledger exists.
