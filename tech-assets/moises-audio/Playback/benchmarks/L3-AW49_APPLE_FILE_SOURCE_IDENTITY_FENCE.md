# L3-AW49 | Apple File Source Identity Fence

Result: `COMPLETE_NON_PARITY`

## Why this Wave exists

AW46 freezes protocol-visible `channels/sampleRate/frameCount` during long PCM identity hashing. Audit of the selected Apple path showed that `Lane3AppleFilePCMChunkSource` stores one immutable `private let AVAudioFile`, and `Lane3AppleRepresentativeCodecReadable` stores one immutable `let base`; there is no adapter API that swaps the decoder instance during a traversal.

The remaining selected-runtime gap is below those protocol getters: the filesystem object at the opened URL can be replaced atomically or modified in place while keeping the same decoded channel count, sample rate and nominal frame count. Without an additional fence, a long evidence traversal could theoretically consume chunks from different file generations while the generic AW46 metadata fence still sees the same values.

## Implementation

`Lane3FileSourceIdentityFence` captures a path-free, process-local snapshot containing:

- filesystem/system number,
- filesystem file number (inode-equivalent),
- byte size,
- creation timestamp when exposed,
- modification timestamp,
- process-local Foundation file-resource identifier hash when exposed,
- process-local Foundation generation identifier hash when exposed.

No URL/path, raw compressed bytes or identity snapshot is persisted in public evidence.

`Lane3AppleFilePCMChunkSource` now:

1. captures identity before `AVAudioFile` open,
2. opens the decoder,
3. captures identity again and rejects an open-race change,
4. requires the original identity before every non-empty PCM read,
5. rechecks immediately after each decoder read,
6. prefers a source-stability failure when a decoder operation failed while the backing file also changed.

The existing AW43 durable failure enum is intentionally not expanded. Apple `sourceIdentityChanged` folds into the existing path-free `sourceMetadataChanged` report code, while identity-unavailable during open folds into `openRejected`.

## Portable focused verification actually executed

Environment: Swift 6.2.1, Linux x86_64, language mode 6, `-strict-concurrency=complete`, `-warnings-as-errors`, optimized build.

- unchanged regular file: PASS,
- same-inode / same-size in-place rewrite: rejected; inode and size stayed equal while mtime changed,
- same-size atomic replacement: rejected,
- directory input: rejected as non-regular,
- missing file: rejected as identity unavailable,
- stress: 1,000 stable checks PASS and 100/100 same-size atomic replacements rejected,
- 10,000 unchanged identity validations: about 27 microseconds per validation in the focused Linux run.

The Linux timing is only a portable cost proxy. It is not iPhone/APFS/AVFAudio performance evidence.

## Repository-native coverage authored

- `Playback/Tests/L3_AW49_FileSourceIdentityFenceSelfTest.swift`
- `Playback/Tests/L3_AW49_FileSourceIdentityFenceStress.swift`
- `Playback/Tests/L3_AW49_FileSourceIdentityFenceBenchmark.swift`
- `Playback/Tests/L3_AW49_AppleFileSourceIdentitySelfTest.swift`

The Apple self-test writes two same-format/same-length WAVs, opens the first through `Lane3AppleFilePCMChunkSource`, atomically replaces the live path with the second while the source's protocol-visible metadata remains constant, and requires the next PCM read to throw `sourceIdentityChanged`.

## Explicit limits

This is an operational source-generation fence, not a cryptographic authenticity signature. A hostile actor able to rewrite the same inode while restoring every compared stat field, on a filesystem that exposes no useful generation identifier, is outside this fence's proof. AW44-AW48 decoded PCM content binding remains separately required; a higher-level compressed-file digest/provenance manifest is still necessary if cryptographic compressed-source lineage becomes a product requirement.

No Xcode compile, selected AVFAudio execution, physical iPhone/APFS evidence, rights-cleared >=30-minute real codec run, RSS/thermal/battery measurement, current-Moises differential or listening evidence is claimed by this Wave. No PARITY row may be promoted from AW49 alone.
