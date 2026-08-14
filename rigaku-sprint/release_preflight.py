#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
IOS = ROOT / "ios"
CANON = ROOT / "release-canonical.json"
EXPECTED_ICON_SHA256 = "5ffc2de874d6f22b0fd6ee121e7c691ae7a7caee30844fad059439846dfefca9"


def load_canon() -> dict:
    return json.loads(CANON.read_text(encoding="utf-8"))


def concrete(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip()) and "$(" not in value and "${" not in value


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def common_checks(canon: dict) -> list[str]:
    blockers: list[str] = []
    project = (IOS / "project.yml").read_text(encoding="utf-8")

    if not concrete(canon.get("appStoreConnectAppleId")):
        blockers.append("App Store Connect Apple IDが未確定")
    if not concrete(canon.get("bundleId")):
        blockers.append("Bundle IDが未確定")

    icon_info = canon.get("appIcon", {})
    icon_path = ROOT.parent / str(icon_info.get("repositoryPath", ""))
    if not icon_path.exists():
        blockers.append("Drive正本AppIcon.pngがGitHubのAsset Catalogへ未投入")
    else:
        actual = sha256(icon_path)
        if actual != EXPECTED_ICON_SHA256:
            blockers.append(f"AppIcon SHA-256不一致: {actual}")
        if icon_path.stat().st_size != int(icon_info.get("expectedBytes", -1)):
            blockers.append("AppIconファイルサイズがDrive正本と不一致")
        if "ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon" not in project:
            blockers.append("AppIcon compiler設定が未有効化")

    if not (IOS / "PrivacyInfo.xcprivacy").exists():
        blockers.append("PrivacyInfo.xcprivacyが未配置")

    return blockers


def app_store_checks(canon: dict) -> list[str]:
    blockers = common_checks(canon)

    if not concrete(canon.get("sku")):
        blockers.append("SKUが未確定")
    if not concrete(canon.get("copyrightOwner")):
        blockers.append("Copyright ownerが未確定")

    pages = canon.get("publicPages", {})
    if pages.get("publishedFromMain") is not True:
        blockers.append("Support/Privacy/Termsページがmainから公開確認されていない")
    if pages.get("supportContactApproved") is not True:
        blockers.append("Support URLに公開してよい問い合わせ先が未承認")

    monetization = canon.get("monetization", {})
    decision = monetization.get("decision")
    if decision not in {"none", "iap"}:
        blockers.append("課金方針が未決定（none / iap）")
    elif decision == "iap":
        for key, label in (
            ("productType", "IAP商品種別"),
            ("productId", "IAP Product ID"),
            ("pricePolicy", "IAP価格方針"),
            ("premiumScope", "無料/有料範囲"),
        ):
            if not concrete(monetization.get(key)):
                blockers.append(f"{label}が未確定")

    if canon.get("appStoreSubmission", {}).get("approvedByUser") is not True:
        blockers.append("App Store最終提出のユーザー承認が未取得")

    return blockers


def internal_testflight_checks(canon: dict) -> list[str]:
    blockers = common_checks(canon)
    # 内部TestFlightは公開用メタデータや最終提出承認を要求しない。
    return blockers


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--phase",
        choices=("internal-testflight", "app-store"),
        default="internal-testflight",
    )
    args = parser.parse_args()

    canon = load_canon()
    blockers = (
        internal_testflight_checks(canon)
        if args.phase == "internal-testflight"
        else app_store_checks(canon)
    )

    print(f"RIGAKU RELEASE PREFLIGHT: {args.phase}")
    if blockers:
        print("BLOCKED")
        for blocker in blockers:
            print(f"- {blocker}")
        return 1

    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
