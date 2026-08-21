# MOI-REF-001 — Current iPhone Free-Core Reference Inventory

Captured: 2026-08-22 JST
Worker: Moises-Worker-3
Attempt: task/MOI-REF-001/attempt-1
Reference target: Moises: The Musician's App, current iPhone listing and official Moises Help/Product pages.

## Evidence hierarchy

1. Current Japan App Store listing for iPhone/iPad app id 1515796612.
2. Current official Moises product/feature pages.
3. Official Moises Help Center mobile-app articles. Help articles are treated as operational evidence, but where an article is older than the current App Store listing, tier/navigation details are not promoted beyond what the current listing corroborates.
4. Anything not directly established is marked UNKNOWN.

## Current Free-Core feature inventory

| Area | Current observable capability | Free boundary established | Confidence |
|---|---|---|---|
| Import | Upload audio/video; App Store lists Google Drive, Dropbox, iCloud, public URL, iTunes and files from other apps | App Store describes these as app import routes; exact per-route free quotas are not specified | HIGH for routes, UNKNOWN for per-route quota |
| Separation | Vocals, drums, bass stem separation | Japan App Store explicitly lists these in Free plan | HIGH |
| Mixer/player | Modify stem tracks, control volume, mute; current product pages also describe solo/listening to individual stems | No paid gate stated for basic mixer operation | HIGH for mute/volume, MEDIUM for exact solo control wording on current iPhone UI |
| BPM | Detect/display BPM | Japan App Store explicitly lists BPM detection in Free plan | HIGH |
| Speed | Real-time speed changer | Official Help states free subscribers are limited to 20% speed change; current feature page separately describes a small free adjustment range, so exact current numeric UI limit requires device verification | HIGH capability, MEDIUM numeric limit |
| Key/pitch | AI key detection and pitch shifting | Japan App Store lists pitch shifting in Free plan; exact current free semitone range is not established by current App Store text | HIGH capability, UNKNOWN exact range |
| Chords | AI chord detection, synced chord display; mobile supports regular/Grid views | Official Help says Free access is limited to first minute | HIGH |
| Metronome | AI-generated synchronized click track, 0.5x/1x/2x modes | Official Help says Free access is limited to first minute | HIGH |
| Count-in | Count-in period preceding playback | App Store lists feature; exact free limit not separately stated | HIGH capability, UNKNOWN entitlement detail |
| Trim/loop | Trim and loop parts; AI sections can support looping | Listed in App Store; exact free limits not specified | HIGH capability, UNKNOWN entitlement detail |
| Sections | Automatic song-section identification used for navigation/looping | Mobile Help confirms Sections exists; free entitlement not explicitly established in current listing | HIGH capability, UNKNOWN entitlement detail |
| Setlists | Collaborative setlists, invite collaborators | Japan App Store explicitly includes setlists in Free plan | HIGH |
| Export | Separated tracks or Audio Mix; mobile MP3/M4A; share/save-to-device; custom mix includes key/speed changes | Current App Store lists Export generally. Help documents mobile export; exact current Free export quotas/quality are not fully stated in current listing | HIGH capability, UNKNOWN exact free quota |
| Separation change | Change separation from Song Options without re-uploading | Help states each change consumes processing credit; free users are subject to monthly processing quota | HIGH |
| Lyrics | AI lyrics transcription exists on mobile | Current Japan App Store description lists AI Lyrics among product features but does not place it in Free plan block | HIGH capability, UNKNOWN free entitlement |

## Current iPhone screen / state / operation map

### A. Library / project list
- Entry state after login: user's song/project library.
- Primary operation: use the `+` upload control to add a track.
- Upload sources include local/files/cloud/public URL routes according to current product/App Store evidence.
- Next state: separation selection.

### B. Separation selection
- User chooses an available separation style according to plan.
- Free plan: current Japan App Store explicitly names vocals, drums, bass separation; official Help historically describes two free separation choices. Exact 2026 labels/order are UNKNOWN without live-device capture.
- Submit starts processing.
- Processing state exists between submit and editable song player; exact progress/cancel/retry screen affordances are UNKNOWN from the current public references and must be captured on device.

### C. Song editor / mixer-player
Official mobile Help identifies these controls/states:
1. Song options/settings at top right.
2. Chords display area.
3. Per-track settings with volume controls; track menu for additional actions.
4. Play/pause and forward/back controls.
5. Metronome + Speed Changer control.
6. Song Key control / pitch change.
7. Lyrics transcription.
8. Chords view selector (regular/Grid on mobile).
9. Sections control, including section looping.

State mutations observable in this screen:
- mute/unmute/volume adjustment per stem;
- playback position/control;
- speed change;
- key/pitch change;
- metronome enable/mode;
- chord/section display changes;
- loop/trim-related practice state.

### D. Song Options / Settings
Confirmed mobile operations include:
- Export;
- Separation / change track separation;
- additional song options whose exact 2026 ordering beyond the documented entries is UNKNOWN.

### E. Export flow
Mobile Help documents:
1. Song Settings (top-right).
2. Export.
3. Save to device or Share.
4. Choose Separated Tracks or Audio Mix.
5. Choose MP3 or M4A on mobile.
6. Audio Mix includes mix changes such as key/speed; separated stems do not inherit those edits.
7. Individual track export is also available from the per-track ellipsis menu.

## Entitlement boundaries — current evidence

### Explicitly Free in current Japan App Store listing
- vocals/drums/bass stem separation;
- chord detection and metronome click-track;
- pitch shifting;
- BPM detection;
- setlists.

### Explicit Premium/Pro distinctions in current sources
- Premium: unlimited AI separation/advanced instrument separation and fully unlocked practice tools according to current App Store listing.
- Premium custom separation: official Help documents up to six tracks per upload including Others.
- Pro: Hi-Fi separation and professional stem modules; current App Store also describes Pro-specific benefits.
- WAV availability is platform/tier-sensitive. Current Help documents mobile MP3/M4A, while App Store text says WAV is Desktop-only; do not assume mobile WAV.

## UNKNOWN / requires live iPhone capture before parity sign-off

- Exact 2026 tab-bar structure and visible labels on iPhone home/library.
- Exact upload-source ordering and whether all listed import routes appear in every account/region.
- Exact free monthly upload count and max track duration in the current build; old help/blog values are not accepted as current without device/account verification.
- Exact free pitch/semitone range.
- Exact current free speed numeric limit because official current/older pages expose conflicting representations.
- Processing UI details: progress representation, cancel, retry, resume, background/interruption behavior.
- Exact solo affordance in the current iPhone mixer UI.
- Exact free limits for count-in, sections, trim/loop, lyrics and export quantity/quality.
- Current error states for unsupported media, network loss, quota exhaustion, storage shortage and processing failure.

## PARITY-row implications

This reference task supplies current evidence for MOI-P001, P002, P003, P006-P020 and P022, but does not raise any row out of MISSING. It establishes observable reference behavior and entitlement boundaries only. P020 and P022 especially remain dependent on live-device processing-state/navigation capture.

## Sources

- Apple Japan App Store — Moises: https://apps.apple.com/jp/app/moises-%E3%83%9F%E3%83%A5%E3%83%BC%E3%82%B8%E3%82%B7%E3%83%A3%E3%83%B3%E3%82%A2%E3%83%97%E3%83%AA/id1515796612
- Moises product page: https://moises.ai/ja/products/moises-app/
- Mobile getting started: https://help.moises.ai/hc/en-us/articles/8472666994076-Welcome-to-Moises-Here-are-some-pointers-to-start-Android-
- Export mobile: https://help.moises.ai/hc/en-us/articles/360013691720-How-do-I-export-my-file
- Export with edits: https://help.moises.ai/hc/en-us/articles/10554030191004-How-do-I-export-my-song-with-the-changes-made
- Change separation: https://help.moises.ai/hc/en-us/articles/6564889454236-How-can-I-change-my-song-s-track-separation-without-re-uploading
- Custom separation: https://help.moises.ai/hc/en-us/articles/19247459645724-How-do-I-separate-my-tracks-using-the-Custom-Upload-on-the-Mobile-App
- Metronome: https://help.moises.ai/hc/en-us/articles/6582170661916-How-do-I-use-the-metronome
- Tempo: https://help.moises.ai/hc/en-us/articles/6582847813148-How-do-I-change-the-song-s-tempo
- Chords Grid mobile: https://help.moises.ai/hc/en-us/articles/9570133423772-How-to-use-the-new-Chords-view-Grid-Mode
- Cross-platform feature inventory: https://help.moises.ai/hc/en-us/articles/12156312650012-Is-Moises-different-across-platforms-and-devices
