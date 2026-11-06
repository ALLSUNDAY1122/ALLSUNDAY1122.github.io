# MOI-REF-002 — Current iPhone Entitlement / Advanced Scope

Captured: 2026-08-22 JST
Task: `MOI-REF-002`
Attempt: `task/MOI-REF-002/attempt-1`
Worker: `Moises-Worker-3`
Purpose: distinguish current iPhone-native functionality from account/subscription benefits that are executed only on Web/Desktop. Unknown behavior is kept UNKNOWN rather than inferred.

## Decision summary

| Area | Free | Premium | Pro | Current iPhone-native scope | Confidence |
|---|---|---|---|---|---|
| Standard stem separation | 2-track / 4-track free core; current verified free limits remain governed by MOI-REF-001 | Advanced custom instrument separation | Premium + Hi-Fi + professional stem modules | YES | HIGH |
| AI Stem Generation | Available; credits limited | Available; credit allocation differs | Available; credit allocation differs | YES — mobile/iOS explicitly documented | HIGH |
| Video Recording | Available | Available | Available | YES — mobile-only feature; iOS/Android explicitly documented | HIGH |
| AI Studio | Account can use according to tier | Account can use according to tier | Account can use according to tier; some AI Studio controls are Pro-gated | NO current native-iPhone execution evidence; official product says Web + Desktop | HIGH |
| Voice Studio / AI voice conversion | Account may process/test subject to current credit/export policy | Account may process/test subject to current credit/export policy | Full/export benefits associated with Pro | NO current native-iPhone execution evidence; official current workflow says Web or Desktop | HIGH |

## P005 — Advanced instrument separation is current iPhone scope

Current Japanese/US App Store listing for the iOS app separates the plans as follows:
- Free: core vocals/drums/bass separation plus core practice features.
- Premium: unlimited AI audio separation, advanced instrument separation including Lead/Rhythm Guitar, Acoustic/Electric Guitar, and Main/Background Vocals; practice tools unlocked.
- Pro: Premium benefits plus Hi-Fi separation, professional stem modules such as drum parts and multimedia stems, and longer per-upload duration.

The current device recording already captured custom separation UI and a Hi-Fi toggle. Therefore `MOI-P005` remains an in-scope iPhone parity row. This research does not promote its state; it remains MISSING until actual implementation/quality evidence exists.

Official Help's instrument inventory is consistent with the plan split: Premium exposes custom instrument families; Pro adds detailed drum components and Dialogue/Soundtrack/Effects.

## P025 — AI Stem Generation

Current official evidence explicitly says AI Stem Generation is available on mobile, web, and desktop apps for Free, Premium, and Pro users, with credit limits varying by tier. The current Moises App product page also states that context-aware stems can be created in the mobile app.

Result:
- `MOI-P025` is confirmed CURRENT_ADVANCED iPhone scope.
- It must remain tracked for functional parity.
- Exact current credit counts are deliberately not hard-coded here because public marketing/help surfaces can change and the task acceptance only requires tier/scope separation. A future implementation task should capture the in-app credit UI at test time.

## P026 — Video Recording / performance capture

Official Help states Video Clip Recording is designed for mobile use only and is available for all subscription plans. Moises' release documentation explicitly states availability on iOS and Android for Free, Premium, and Pro users.

Observed official behavior contract to carry into later implementation/reference work:
- Entry via camera icon in the app.
- Record performance over a song/backing track.
- Headphones are required.
- Bluetooth monitoring latency is handled as a known limitation.
- Smart sync correction aligns recorded performance with backing track; manual sync adjustment is available.
- Post-recording audio enhancement/mix controls are documented.
- Picture-in-Picture allows continued access to features such as lyrics/chords while recording.

Result:
- `MOI-P026` is confirmed CURRENT_ADVANCED iPhone scope.
- All three tiers have access according to current official documentation.
- It remains MISSING until an independent implementation and device evidence exist.

## P027 — AI Studio

Current official AI Studio product FAQ says AI Studio works on Web and Desktop. Moises' product announcement describes the launch as a web-based DAW, and current product/release material describes AI Studio as desktop/web rather than a native iPhone workspace.

Do not confuse AI Studio with AI Stem Generation:
- AI Stem Generation: individual generative stem capability, explicitly available in the mobile app.
- AI Studio: multi-track generative production environment/DAW, current official execution surface is Web/Desktop.

Result:
- No authoritative evidence was found that the current iPhone app contains the full AI Studio workspace.
- For iPhone-reference parity, `MOI-P027` should not be treated as a required native-iPhone feature unless later current-device evidence supersedes this finding.
- Worker does not delete or change the PARITY row. HQ should preserve the evidence and decide whether to mark the row out-of-current-iOS-scope / approved blocked, or revise its gate wording.

## P028 — Voice Studio / AI voice conversion

The current App Store description lists fully unlocked Voice Studio under Pro benefits. That proves subscription/account entitlement, not native-iPhone execution. Current Moises product documentation explicitly instructs users to open Voice Studio on the Moises Web or Desktop App. Moises also publishes a page specifically telling mobile users that their subscription grants additional Web/Desktop benefits such as Voice Studio.

Current plan behavior from official Voice Studio material:
- Free/Premium/Pro accounts can access or experiment with voice conversion under differing processing/export allowances.
- Pro is the tier associated with full export/unlocked Voice Studio benefits in current plan messaging.
- Execution surface in current official workflow: Web/Desktop.

Result:
- No authoritative evidence was found for a native iPhone Voice Studio screen/workflow.
- `MOI-P028` should not be implemented as an iPhone-native parity requirement solely because the App Store says the Pro subscription includes Voice Studio.
- Worker does not delete/change the row; HQ should retain it with explicit current-platform evidence and decide the canonical scope state.

## Tier interpretation rule

A subscription bought or advertised inside the iOS App Store can unlock capabilities elsewhere in the same Moises account. Therefore:

`plan entitlement != native iPhone feature availability`

A feature is classified as current iPhone scope only when an authoritative source explicitly identifies mobile/iOS execution or current-device evidence shows the UI/behavior.

## Authoritative sources reviewed

1. Apple App Store Japan — Moises current iOS listing / plan descriptions / current compatibility and version history:
   https://apps.apple.com/jp/app/moises-%E3%83%9F%E3%83%A5%E3%83%BC%E3%82%B8%E3%82%B7%E3%83%A3%E3%83%B3%E3%82%A2%E3%83%97%E3%83%AA/id1515796612
2. Moises Help — Which instruments can be separated on Moises?:
   https://help.moises.ai/hc/en-us/articles/360010972019-Which-instruments-can-be-separated-on-Moises
3. Moises Help — Video recording on Mobile:
   https://help.moises.ai/hc/en-us/articles/21169867017116-Video-recording-on-Mobile
4. Moises product/release update — AI Stem Generation / Video Recording / AI Studio platform statements:
   https://moises.ai/blog/latest/improvements-latest-releases/
5. Moises App product page — AI Stem Generation on the mobile app:
   https://moises.ai/products/moises-app/
6. Moises AI Studio product page — Web + Desktop statement:
   https://moises.ai/features/ai-studio-music-creation/
7. Moises AI Studio launch announcement — web-based DAW positioning:
   https://moises.ai/newsroom/product-announcements/launch-ai-studio/
8. Moises Voice Studio product page — workflow explicitly says Moises Web or Desktop App:
   https://moises.ai/features/ai-voice-models/
9. Moises Web/Desktop benefits for mobile subscribers — Voice Studio listed as Web/Desktop benefit:
   https://moises.ai/web-app-benefits/

## Remaining UNKNOWN / human-gated items

- Exact in-app 2026 credit counters for AI Stem Generation by Free/Premium/Pro tier were not directly observed on the user's account.
- Exact current paywall screens and any region/account experiments may differ from public marketing text.
- AI Studio or Voice Studio could later receive a native mobile release; current evidence must be invalidated and re-captured if that occurs.
- This task records Reference scope only. No implementation-quality or PARITY claim is made.
