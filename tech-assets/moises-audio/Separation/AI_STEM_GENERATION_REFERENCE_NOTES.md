# L1-A21｜AI Stem Generation Reference Notes

Captured: 2026-08-24 JST  
Evidence class: public official Reference research; not current-iPhone differential evidence; not PARITY.

## Confirmed public facts

Official Moises release material says AI Stem Generation can add generated drums, bass, guitar and more from an uploaded song/recording, and that the feature is available on mobile, web and desktop for Free, Premium and Pro users with credit limits that vary by tier.

Official product/feature material describes generated instrumental tracks as context-aware: they respond to the supplied audio and are intended to fit its timing/chords/style. Current public feature material also describes instrument selection, presets and optional text direction, and says stem generation can be used in the mobile app.

Current Moises Terms describe credit-based features, state that exact tier features/usage limits and monthly credit allocations are specified on the Pricing Page, and state that unused monthly credits expire rather than roll over. Therefore Lane 1 does not hard-code a monthly Free/Premium/Pro allowance.

## Sources

- https://moises.ai/blog/latest/improvements-latest-releases/ — AI Stem Generation release entry; mobile/web/desktop; Free/Premium/Pro; credit limits vary.
- https://moises.ai/products/moises-app/ — Moises mobile app product surface includes AI Stem Generation.
- https://moises.ai/features/stem-generation/ — public behavior/role/prompt/reference-audio description and mobile availability.
- https://help.moises.ai/hc/en-us/articles/7401394754962-Terms-of-Service — subscription usage limits/credits are controlled by current service/Pricing Page terms.

## What is deliberately NOT frozen from public cross-platform material

The following are not treated as exact current-iPhone facts until a current-iPhone capture or account/API capability snapshot proves them:

- exact instrument/role list visible on iPhone;
- exact generation modes and preset catalog visible on iPhone;
- exact per-generation credit consumption formula;
- exact monthly included-credit allowance by tier;
- purchased-credit behavior exposed by the iPhone UI;
- maximum source length, generated segment length or simultaneous generation limits;
- exact cancellation/refund semantics;
- exact entitlement messages and operation count.

`CapabilityPolicy.reference_confidence=OFFICIAL_CROSS_PLATFORM_ONLY` represents this state. A snapshot may move to `CURRENT_IPHONE_CAPTURED` only when its semantic fields are bound to current-iPhone evidence.

## Engineering interpretation

A21 therefore treats role/mode/tier/credit semantics as a versioned, hash-bound capability snapshot rather than constants. The entitlement snapshot separately records the account's current plan, current included/purchased credit balance and generation-enabled state without persisting a raw account identifier.

This prevents stale pricing/entitlement assumptions from silently changing production behavior and avoids converting cross-platform public documentation into a false iPhone PARITY claim.
