#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
gm2 = (ROOT / "apps/sanitary-manager-2/gm2.js").read_text(encoding="utf-8")
gm4 = (ROOT / "apps/sanitary-manager-2/gm4.js").read_text(encoding="utf-8")

errors = []

def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)

require('id="home-premium-cta"' in gm2, "home premium CTA must have a stable partial-render target")
require('class="sec settings storekit-panel paywall"' in gm4, "paywall must expose storekit-panel")
require('<div class="storekit-panel">${premiumPlansHTML()}</div>' in gm4, "settings must expose storekit-panel")

match = re.search(r"window\.__storekitUpdate=function\(payload\)\{(?P<body>.*?)\n\};", gm4, re.S)
require(match is not None, "StoreKit update handler must exist")
if match:
    body = match.group("body")
    require("panel.innerHTML=premiumPlansHTML()" in body, "StoreKit status must update paywall/settings in place")
    require("previousPremium" in body, "StoreKit status must remember prior entitlement before DOM updates")
    require("previousPremium!==!!window.SM2_STORE.isPremium" in body, "home CTA replacement must be entitlement-change guarded")
    require("homePremium.outerHTML=premiumCTA()" in body, "entitlement changes must update home CTA")
    for forbidden in ("settingsScreen(", "home(", "showPaywall(", "requestStoreStatus("):
        require(forbidden not in body, f"StoreKit update handler must not trigger recursive full-screen render: {forbidden}")

show_match = re.search(r"function showPaywall\(\)\{(?P<body>.*?)\n\}", gm4, re.S)
require(show_match is not None, "paywall screen function must exist")
if show_match:
    require("requestStoreStatus();" not in show_match.group("body"), "paywall entry must not start a refresh that can replace purchase controls during a tap")

for fn in ("function home()", "function showPaywall()", "function settingsScreen()"):
    require(fn in gm2 or fn in gm4, f"required screen function missing: {fn}")

require(gm2.count("requestStoreStatus();") >= 2, "home/mock screens must request initial StoreKit state")
require(gm4.count("requestStoreStatus();") >= 1, "settings must request refreshed StoreKit state")
require("monthlyPrice" in gm4 and "lifetimePrice" in gm4, "both product prices must remain visible in premium UI")
require("購入を復元" in gm4, "restore purchase action must remain visible")

if errors:
    print("FAIL: HM2 StoreKit UI regression gate")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("PASS: HM2 StoreKit UI uses non-recursive partial rendering")
print("PASS: home premium CTA stays stable while entitlement is unchanged")
print("PASS: paywall entry does not start a control-replacing StoreKit refresh")
print("PASS: paywall/settings/home preserve product price and restore-purchase surfaces")
