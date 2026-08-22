# MOI-REF-001 — Current iPhone Free-Core Reference Inventory

Captured: 2026-08-22 JST  
Worker: Moises-Worker-1  
Attempt: `task/MOI-REF-001/attempt-2`  
Reference target: current iPhone Moises experience, using user-provided current-device recording plus Apple/Moises public evidence.

## Scope and evidence hierarchy

This task records observable behavior only. It does not copy Moises UI assets, wording, code, models, or training data, and it does not raise any PARITY row.

Evidence precedence:

1. **Direct current-iPhone recording supplied by the user and transcribed into the Notion product requirements on 2026-08-22.** This is strongest for the exact screen/state/operation actually shown.
2. **Current Japan App Store listing** for app id `1515796612`, retrieved 2026-08-22.
3. **Official Moises Help Center**, favoring newer/mobile-specific articles. Article update dates are recorded where material.
4. Older or cross-platform help is supporting evidence only. If it conflicts with direct current-iPhone evidence or a newer source, the item remains `UNKNOWN` until re-captured.

## Reconciliation result

The stale attempt-1 inventory was directionally correct, but attempt-2 tightens entitlement boundaries and corrects one important parity assumption:

- Free processing is publicly documented as **5 songs/month, max 5 minutes per media file**.
- Free separation publicly documents both **2-track (vocals/instrumental)** and **4-track (vocals/drums/bass/other)** modes.
- Free key change is publicly documented as **up to 2 semitones**.
- Free count-in is publicly documented as **up to 4 clicks**.
- Free Smart Metronome and chord access are publicly documented as **first minute only**.
- Mobile export is publicly documented as **MP3/M4A** for separated tracks or Audio Mix; WAV is not established for mobile.
- A 2024 official cross-platform article says mobile cannot visualize the player in waveform form. The current user recording also did not establish a waveform. Therefore **MOI-P007's waveform-specific Reference behavior is not confirmed by this task** and should be reviewed by HQ rather than inferred.

## Current iPhone navigation / state / operation map

### 1. Library / import entry

**Direct current-iPhone evidence**

The user's 2026-08-22 recording shows `曲を追加` with these visible entry routes:

- Files app
- Camera roll
- Recording
- iTunes
- Cloud storage

The same recording visibly lists support including:

- MP3
- WAV
- FLAC
- M4A
- MP4
- MOV
- WMA

The cloud-storage explanation in the recording permits cloud/publicly reachable media and states that streaming links do not work.

**Official corroboration**

Moises' mobile upload guide documents public URL, iTunes on iOS, camera roll/gallery, and Files App. The App Store listing additionally names Google Drive, Dropbox, iCloud and public URL. The official accepted-format article lists a broader audio/video set including MP3, AAC-family, OGG, WMA, AIFF, FLAC, WAV, MP4, M4V, MOV, MKV, M4R/M4A, FLV, MPEG and WEBM.

**Reference rule**

Implement only routes/formats justified by product requirements and IO capability; do not infer that every historical help-center format is exposed identically in the current iPhone picker.

### 2. Separation selection

**Direct current-iPhone evidence**

Visible in the supplied recording:

- 4-track basic separation: vocals / drums / bass / other
- 2-track basic separation: vocals / instrumental
- custom separation screen containing at least vocals / guitar / bass
- a lock indicator on at least one custom instrument option
- `HI-FI` toggle before confirming separation

**Official corroboration / entitlement**

- Free: 2-track and 4-track basic separation are documented by Moises Help.
- Current Japan App Store Free block explicitly names vocals, drums and bass stem separation.
- Custom Track Separation is documented for Premium/Pro.
- Premium: up to 6 output tracks per custom upload including `Others` in the newer 2025 custom-upload article.
- Pro: unrestricted custom selection in that article and Hi-Fi quality.
- Current App Store Pro description includes Hi-Fi separation and professional stem modules.

Exact current lock placement and every instrument available to each tier are outside MOI-REF-001 and remain for entitlement-specific follow-up.

### 3. Upload / processing / project transition

**Direct current-iPhone evidence**

The recording shows:

1. library/list state showing the target as `アップロード中 (100%)`;
2. transition into Project/Player before stem preparation is complete;
3. Project/Player remaining usable enough for its transport time to advance while `ステムを準備しています…` remains visible.

This establishes an important state contract: **processing state and player/presentation state are not necessarily one blocking screen**.

**Still UNKNOWN**

The recording and public help do not establish the complete current-iPhone behavior for:

- cancel during processing;
- retry after model/network failure;
- automatic resume after app termination/background interruption;
- exact operations allowed before stems are ready;
- partial-result behavior.

MOI-P020 therefore remains unproven by Reference evidence.

### 4. Project / Player / Mixer

**Direct current-iPhone evidence**

The supplied recording shows:

- four stem-like rows;
- per-row icon, volume control and overflow menu;
- continuous volume changes during playback;
- observed vocal values including 49%, 0%, and 99%;
- the affected stem name displayed while adjusting volume;
- bottom transport entries corresponding at minimum to metronome/practice, previous/rewind, play/pause, next/forward, and key/pitch.

**Official corroboration**

The mobile edit guide documents:

- chords display;
- per-track volume controls;
- per-track overflow actions;
- play/pause plus forward/back;
- Metronome + Speed Changer;
- Song Key;
- Lyrics;
- Chords regular/Grid modes;
- Sections and section looping.

The same guide says tracks initialize at 75% volume, but this was not independently verified in the user's current recording, so treat **75% initial value as public-help evidence, not current-device observation**.

### 5. Chords / timeline presentation

**Direct current-iPhone evidence**

The current recording shows:

- chord tiles moving with playback time;
- visible examples including E, B, C#m, B/D#;
- current-position highlighting.

This confirms that chord output is not merely a static analysis result: the current iPhone presentation is synchronized to the playback clock.

Official mobile Chords Grid documentation also states that chord presentation is synchronized with bars/beats and that Free users have access to the first minute.

### 6. Practice controls and public Free boundaries

| Capability | Current/reference evidence | Free boundary supported by public evidence | Confidence |
|---|---|---:|---|
| Smart Metronome | synced click; 0.5x / 1x / 2x documented | first minute | HIGH capability/boundary |
| Speed changer | real-time tempo/speed change | official dedicated article: limited to 20% change | HIGH capability; MEDIUM exact current UI units |
| Key / pitch | real-time key change, each step 1 semitone | up to 2 semitones | HIGH |
| Count-in | pre-roll before playback | up to 4 clicks | HIGH |
| Chords | synced chord display, regular/Grid on mobile | first minute | HIGH |
| Sections | automatic section identification and section looping | exact Free boundary not separately established | HIGH capability, UNKNOWN tier limit |
| Trim / loop | mobile is publicly listed as supporting trim and loop | exact Free boundary not separately established | HIGH capability, UNKNOWN tier limit |
| Lyrics transcription | mobile feature publicly documented | maximum-length article documents first-minute limit for Free | HIGH capability/boundary |

The generic 2025 upload/edit article uses a different speed-control description for web/desktop (`-10/+10 speed changes`). Because the dedicated speed article describes Free as a 20% change and the user's current iPhone recording did not expose the numeric scale, **the exact current mobile control scale remains UNKNOWN even though Free-limited speed changing itself is confirmed**.

### 7. Library / setlists

Current App Store text includes setlists in the Free plan. A newer official Help article updated 2026-04-08 confirms Setlist Collaboration across Web/iOS/Android and states that collaboration is available to all users, while mixer capability still follows each member's own subscription.

Observed/public setlist behavior includes:

- setlists are private by default;
- owner can enable collaboration and generate/share an invite link;
- recent-contact invitations and push notifications are supported;
- access is revoked when the owner makes the setlist private;
- Free members do not inherit Premium separation/unlimited features simply by joining a Premium-originated setlist.

Exact current-iPhone list reordering gestures were not captured here.

### 8. Export / output

**Direct current-iPhone evidence**

The current recording shows export reachable from the Project/Player area; the small menu visibly includes `L & R` and `エクスポート`.

**Official mobile export behavior**

Official Help documents this mobile flow:

1. Song Settings at top right.
2. Export.
3. Save to device or Share.
4. Choose Separated Tracks or Audio Mix.
5. Choose MP3 or M4A on mobile.
6. Audio Mix contains audio edits such as key/speed changes.
7. Separated Tracks are individual stems and do not inherit those key/speed edits.
8. Individual tracks may also be exported from the per-track overflow menu.

WAV is documented for Web/Desktop rather than Mobile in current public help. Do not assume iPhone WAV export.

### 9. Input / processing quotas and failure boundaries

Public Help updated 2025-06-11 documents:

- Free: 5 processed songs per month, up to 5 minutes each.
- Premium: unlimited songs up to 20 minutes in that help article.
- Pro: the same article says up to 20 minutes, while the current App Store Pro description says up to 180 minutes per upload.

Because the **current App Store and 2025 Help disagree for Pro maximum duration**, this task records:

- Free quota: 5/month, 5 minutes — established.
- Premium max duration: 20 minutes — supported by Help.
- Pro max duration: **CONFLICT / UNKNOWN for current iPhone** until entitlement-specific Reference capture resolves 20 vs 180 minutes.

Official upload-error guidance establishes at least these failure classes:

- over-duration input;
- DRM-protected media not processable;
- upload/network/account state issues;
- remediation through sign-out/in, test file, reinstall and support escalation.

It does not establish the exact in-app error strings/state machine required for parity.

## Entitlement boundary summary

### Confirmed Free

- 2-track basic separation: vocals / instrumental.
- 4-track basic separation: vocals / drums / bass / other.
- 5 processed songs/month.
- maximum 5 minutes per Free separation input.
- Smart Metronome first minute.
- chord detection first minute.
- lyrics transcription first minute (per maximum-length help article).
- key/pitch change up to 2 semitones.
- count-in up to 4 clicks.
- setlists, including collaboration availability across iOS.

### Confirmed Premium/Pro distinctions relevant to current iPhone

- Custom Track Separation is Premium/Pro.
- Premium custom separation: up to 6 tracks including `Others` according to the 2025 mobile custom-upload article.
- Pro custom separation: unrestricted selection in that article, with Hi-Fi quality.
- Premium/Pro unlock unlimited metronome and chord use in official help.
- Pro current App Store description includes Hi-Fi separation and professional stem modules.

### Deliberately not finalized in MOI-REF-001

- exact complete Premium/Pro/current-advanced iOS feature matrix;
- AI Stem Generation / Video Recording / AI Studio / Voice Studio iOS availability and tiering;
- exact current Pro maximum duration because current public sources conflict;
- exact current custom-instrument lock map.

These belong to `MOI-REF-002` or HQ entitlement review.

## Waveform / MOI-P007 caution

The parity ledger currently names MOI-P007 `waveform timeline seek`. This Reference task did **not** observe an iPhone waveform in the supplied current recording. An official cross-platform article updated 2024-01-12 explicitly lists `visualize the player in wave format` among functions unavailable on Mobile/iPad at that time.

Therefore:

- seek/timeline behavior remains in product scope where independently required;
- **waveform as a current Moises-iPhone Reference feature is not established here**;
- Worker does not edit `PARITY_MATRIX.json`; HQ should review whether P007's wording represents current iPhone Reference behavior or an independent product-quality target.

## Remaining UNKNOWNs that block full Reference sign-off for affected rows

- exact 2026 iPhone tab/navigation labels outside the recorded flow;
- exact supported route ordering across accounts/regions;
- exact processing cancel/retry/resume/background/interruption UX;
- exact operations available while `ステムを準備しています…`;
- exact current solo/mute gesture/state in the user's iPhone build;
- exact trim/loop gesture and numeric limits;
- exact speed-control scale shown on current iPhone UI;
- exact current error screens for corrupt input, network loss, quota exhaustion, storage shortage and processing failure;
- exact export quality/bitrate and naming conventions;
- exact current Pro max duration and full Premium/Pro/Advanced entitlement matrix.

UNKNOWN means unverified, not absent.

## PARITY implications

This task provides Reference evidence for MOI-P001, P002, P003, P006-P020 and P022. It does not move any row from `MISSING`.

Particularly:

- P001/P002: routes/formats/quotas are substantially better defined, but actual self-app import still needs implementation/device evidence.
- P003: basic separation choices are confirmed, but output quality is not evaluated here.
- P006: current volume/mixer behavior is directly observed; full solo/mute behavior remains incomplete.
- P007: waveform-specific current-iPhone Reference support is not established and is flagged to HQ.
- P009-P016: capability and several Free boundaries are established; algorithmic quality remains untested.
- P017/P018: setlist behavior is publicly confirmed, but persistence/resume reliability is not established by this Reference task.
- P019: export route/types/formats are well defined; output synchronization/quality still needs self-app and differential testing.
- P020/P022: current recording establishes non-blocking processing-to-player transition, but cancel/retry/resume and full E2E state coverage remain UNKNOWN.

## Authoritative/public sources used

Retrieved 2026-08-22 unless stated otherwise.

- Apple Japan App Store, Moises app id 1515796612: https://apps.apple.com/jp/app/id1515796612
- Moises Help — Upload/Edit mobile, updated 2025-01-16: https://help.moises.ai/hc/en-us/articles/8583454469276-How-to-Upload-and-Edit-your-track-using-Moises
- Moises Help — Accepted file formats: https://help.moises.ai/hc/en-us/articles/360013289060-Accepted-file-formats
- Moises Help — Upload count, updated 2025-06-11: https://help.moises.ai/hc/en-us/articles/360010972039-How-many-songs-can-I-upload
- Moises Help — Maximum file length: https://help.moises.ai/hc/en-us/articles/360010855680-What-is-the-maximum-file-length
- Moises Help — Instruments/separation options: https://help.moises.ai/hc/en-us/articles/360010972019-What-instruments-can-I-separate-on-Moises
- Moises Help — Custom Upload mobile, updated 2025-03-28: https://help.moises.ai/hc/en-us/articles/19247459645724-How-do-I-separate-my-tracks-using-the-Custom-Upload-on-the-Mobile-App
- Moises Help — Change separation: https://help.moises.ai/hc/en-us/articles/6564889454236-How-can-I-change-my-song-s-track-separation-without-re-uploading
- Moises Help — Export mobile, updated 2025-01-21: https://help.moises.ai/hc/en-us/articles/360013691720-How-do-I-export-my-file
- Moises Help — Export with edits, updated 2025-01-11: https://help.moises.ai/hc/en-us/articles/10554030191004-How-do-I-export-my-song-with-the-changes-made
- Moises Help — Smart Metronome: https://help.moises.ai/hc/en-us/articles/6582170661916-How-do-I-use-the-metronome
- Moises Help — Speed changer: https://help.moises.ai/hc/en-us/articles/6582847813148-How-do-I-change-the-song-s-tempo
- Moises Help — Key/Pitch changer: https://help.moises.ai/hc/en-us/articles/6582517238044-How-do-I-use-the-Key-Detection-with-the-Pitch-Changer
- Moises Help — Count-in: https://help.moises.ai/hc/en-us/articles/6580752102044-How-do-I-set-up-the-count-in
- Moises Help — Chords Grid mobile: https://help.moises.ai/hc/en-us/articles/9570133423772-How-to-use-the-new-Chords-view-Grid-Mode
- Moises Help — Setlist collaboration, updated 2026-04-08: https://help.moises.ai/hc/en-us/articles/12731092152476-How-do-I-enhance-my-music-Setlists-through-collaboration
- Moises Help — Platform differences, updated 2024-01-12: https://help.moises.ai/hc/en-us/articles/12156312650012-Is-Moises-different-across-platforms-and-devices
- Moises Help — Upload troubleshooting: https://help.moises.ai/hc/en-us/articles/360014112059-Error-uploading-my-file-What-should-I-do
- Moises Help — Public URL restrictions: https://help.moises.ai/hc/en-us/articles/360020130539-My-URL-isn-t-working-Why

## Current-device evidence source

Notion: `Moises同等化｜製品要件定義 v1.0`, section `2026-08-22｜ユーザー提供iPhone画面録画から確定したReference挙動`.
