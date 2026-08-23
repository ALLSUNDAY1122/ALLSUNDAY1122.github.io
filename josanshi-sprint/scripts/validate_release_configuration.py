#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "ios"

EXPECTED = {
    "bundle": "jp.allsunday1122.josanshi",
    "team": "MN3D2ZM44N",
    "profile": "josanshi_appstore",
    "product": "jp.allsunday1122.josanshi.premium",
    "icon_sha": "07668a08a0703b76ecbeca38bbc5b396a248f822de594947ddccd383f0898579",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


base = (IOS / "xcodegen.yml").read_text(encoding="utf-8")
release = (IOS / "xcodegen-release.yml").read_text(encoding="utf-8")
codemagic = (IOS / "codemagic-josanshi.yml").read_text(encoding="utf-8")
icon = (IOS / "prepare-app-icon.sh").read_text(encoding="utf-8")
capability = (IOS / "apply-xcode-capabilities.py").read_text(encoding="utf-8")
metadata = (ROOT / "APP_STORE_METADATA_JA.md").read_text(encoding="utf-8")

for text, label in [(base, "base xcodegen"), (release, "release xcodegen"), (codemagic, "Codemagic")]:
    require(EXPECTED["bundle"] in text, f"{label} Bundle ID mismatch")
    require(EXPECTED["team"] in text, f"{label} Team ID mismatch")

require("Assets.xcassets" not in base, "simulator/base spec must not depend on release AppIcon")
require("ASSETCATALOG_COMPILER_APPICON_NAME" not in base, "base spec must not request AppIcon")
require("Assets.xcassets" in release, "release spec must include asset catalog")
require("ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon" in release, "release spec must select AppIcon")

for needle in [
    f"CODEMAGIC_PROFILE_REF: {EXPECTED['profile']}",
    f"IAP_PRODUCT_ID: {EXPECTED['product']}",
    f"APPICON_SHA256: {EXPECTED['icon_sha']}",
    "JOSANSHI_APPICON_BASE64",
    "xcodegen generate --spec xcodegen-release.yml",
    "testFlightInternalTestingOnly",
    "submit_to_testflight: false",
    "submit_to_app_store: false",
]:
    require(needle in codemagic, f"Codemagic safety contract missing: {needle}")

require("JOSANSHI_APPICON_BASE64" in icon, "secure AppIcon base64 staging missing")
require("JOSANSHI_APPICON_PATH" in icon, "authenticated staged AppIcon path support missing")
require(EXPECTED["icon_sha"] in icon, "AppIcon SHA mismatch")
require('ICON_EXPECTED_SIZE="590870"' in icon, "AppIcon byte-size gate mismatch")
require("com.apple.InAppPurchase" in capability and "enabled = 1" in capability, "IAP capability normalizer missing")

for needle in [
    f"`{EXPECTED['bundle']}`",
    f"`{EXPECTED['product']}`",
    "Non-Consumable",
    "Price: **未決定",
    "App Store Connect numeric App ID: Apple発行待ち・推測禁止",
]:
    require(needle in metadata, f"metadata contract missing: {needle}")

print("PASS: #14 release configuration safety gate")
print(f"  Bundle ID: {EXPECTED['bundle']}")
print(f"  Codemagic profile: {EXPECTED['profile']}")
print(f"  IAP: {EXPECTED['product']} / non-consumable")
print("  App Store numeric ID: Apple-issued only")
print("  Simulator AppIcon-independent; Release exact-icon-only")
print("  TestFlight/App Store auto-publish disabled")
