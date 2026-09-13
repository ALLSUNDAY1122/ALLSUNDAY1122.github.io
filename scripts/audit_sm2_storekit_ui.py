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
    require("homePremium.outerHTML=premiumCTA()" in body, "StoreKit status must update home CTA in place")
    for forbidden in ("settingsScreen(", "home(", "showPaywall(", "requestStoreStatus("):
        require(forbidden not in body, f"StoreKit update handler must not trigger recursive full-screen render: {forbidden}")

for fn in ("function home()", "function showPaywall()", "function settingsScreen()"):
    require(fn in gm2 or fn in gm4, f"required screen function missing: {fn}")

require(gm2.count("requestStoreStatus();") >= 2, "home/mock screens must request initial StoreKit state")
require(gm4.count("requestStoreStatus();") >= 2, "paywall/settings must request initial StoreKit state")
require("monthlyPrice" in gm4 and "lifetimePrice" in gm4, "both product prices must remain visible in premium UI")
require("購入を復元" in gm4, "restore purchase action must remain visible")

if errors:
    print("FAIL: HM2 StoreKit UI regression gate")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("PASS: HM2 StoreKit UI uses non-recursive partial rendering")
print("PASS: paywall/settings/home preserve product price and restore-purchase surfaces")
