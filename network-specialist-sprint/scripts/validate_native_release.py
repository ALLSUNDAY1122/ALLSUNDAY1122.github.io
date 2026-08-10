#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
from pathlib import Path

BUNDLE_ID = "jp.allsunday1122.networkspecialist"
TEAM_ID = "MN3D2ZM44N"
CODEMAGIC_PROFILE = "networkspecialist_appstore"
ICON_SHA256 = "5b53032021cea4a3e71e737c1a48e1aa8d6495b3647cb770b0e5d917bb0d8729"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def normalized_iap_id(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    value = value.strip()
    if not value or value.startswith("$("):
        return None
    return value


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--require-icon", action="store_true")
    parser.add_argument("--require-iap", action="store_true")
    args = parser.parse_args()
    root = args.root

    payload_path = root / "ios" / "NetworkSpecialist" / "Resources" / "questions.native.json"
    require(payload_path.exists(), "questions.native.json missing; run build_native_questions.py")
    payload = json.loads(payload_path.read_text(encoding="utf-8"))
    require(len(payload.get("questions", [])) == 75, "native payload must contain 75 occurrences")
    require(len(payload.get("uniqueIDs", [])) == 68, "native payload must contain 68 unique IDs")
    require("lawBaselineDate" in payload, "lawBaselineDate field must be retained even when canonical value is undefined")
    require("sourceCheckedAt" in payload, "sourceCheckedAt field missing")
    require(bool(payload.get("contentVersion")), "contentVersion missing")

    project = (root / "ios" / "project.yml").read_text(encoding="utf-8")
    require(BUNDLE_ID in project, "Bundle ID mismatch")
    require(f'DEVELOPMENT_TEAM: "{TEAM_ID}"' in project, "Apple Team ID mismatch")
    require("NetworkSpecialist/Resources/questions.native.json" in project, "generated native question JSON must be copied as an explicit resource")
    require("WebApp" not in project, "WebApp resource must not be bundled in native target")

    swift_dir = root / "ios" / "NetworkSpecialist"
    swift_files = list(swift_dir.glob("*.swift"))
    require(swift_files, "Swift source files missing")
    combined = "\n".join(path.read_text(encoding="utf-8") for path in swift_files)
    require("WKWebView" not in combined and "import WebKit" not in combined, "WebKit/WKWebView remains in native target")
    for marker in ("わからない", "3連続正解で解除", "JSONバックアップ", "ホーム", "模試", "記録", "設定"):
        require(marker in combined, f"native UX marker missing: {marker}")

    storekit_path = swift_dir / "PremiumPurchaseStore.swift"
    require(storekit_path.exists(), "StoreKit 2 purchase engine missing")
    storekit = storekit_path.read_text(encoding="utf-8")
    for marker in (
        "import StoreKit",
        "Product.products",
        ".displayPrice",
        ".purchase()",
        "Transaction.currentEntitlements",
        "Transaction.updates",
        "AppStore.sync()",
        ".unverified",
        ".pending",
        ".userCancelled",
        "revocationDate",
        ".nonConsumable",
    ):
        require(marker in storekit, f"StoreKit 2 audit marker missing: {marker}")

    info_path = root / "ios" / "NetworkSpecialist" / "Info.plist"
    with info_path.open("rb") as f:
        info = plistlib.load(f)
    iap_id = normalized_iap_id(info.get("PremiumProductID"))
    if args.require_iap:
        require(iap_id is not None, "#7 premium Product ID is not defined in the canonical specification; configure PremiumProductID before Release/TestFlight")

    codemagic = (root / "codemagic.yaml").read_text(encoding="utf-8")
    require(f"app_store_connect: {CODEMAGIC_PROFILE}" in codemagic, "Codemagic profile mismatch")
    require("testFlightInternalTestingOnly" in codemagic, "Internal Testing only export option missing")
    require("submit_to_testflight: false" in codemagic, "external TestFlight beta review submission must remain disabled")
    require("submit_to_app_store: false" in codemagic, "App Store auto-submit must be disabled")

    icon = root / "ios" / "NetworkSpecialist" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"
    if icon.exists():
        digest = hashlib.sha256(icon.read_bytes()).hexdigest()
        require(digest == ICON_SHA256, f"canonical AppIcon SHA mismatch: {digest}")
    elif args.require_icon:
        require(False, "canonical AppIcon missing")

    print("PASS native release static gate", {"iapConfigured": iap_id is not None})


if __name__ == "__main__":
    main()
