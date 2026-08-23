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
CANONICAL_BUNDLE_ID = "jp.allsunday1122.rigakuryouhoushi"
CANONICAL_PRODUCT_ID = "jp.allsunday1122.rigakuryouhoushi.monthly"


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


def monetization_checks(canon: dict) -> list[str]:
    blockers: list[str] = []
    monetization = canon.get("monetization", {})

    if monetization.get("decision") != "subscription":
        blockers.append("#15課金方式が月額サブスクリプション正本と不一致")
    if monetization.get("productType") != "auto-renewable-subscription":
        blockers.append("IAP商品種別が自動更新サブスクリプションではない")
    if monetization.get("productId") != CANONICAL_PRODUCT_ID:
        blockers.append("IAP Product IDが#15正本値と不一致")
    if not concrete(monetization.get("pricePolicy")):
        blockers.append("月額200円の価格方針が未記録")
    if not concrete(monetization.get("premiumScope")):
        blockers.append("無料60問 / 月額600問の利用範囲が未記録")
    if monetization.get("registeredInAppStoreConnect") is not True:
        blockers.append("月額商品がApp Store Connectへ未登録・未確認")

    return blockers


def common_checks(canon: dict) -> list[str]:
    blockers: list[str] = []
    project = (IOS / "project.yml").read_text(encoding="utf-8")

    if not concrete(canon.get("appStoreConnectAppleId")):
        blockers.append("App Store Connect Apple IDが未確定")
    if canon.get("bundleId") != CANONICAL_BUNDLE_ID:
        blockers.append("Bundle IDが#15正本値と不一致")
    if f"PRODUCT_BUNDLE_IDENTIFIER: {CANONICAL_BUNDLE_ID}" not in project:
        blockers.append("XcodeGenのBundle IDが#15正本値と不一致")
    if f"RigakuPremiumProductID: {CANONICAL_PRODUCT_ID}" not in project:
        blockers.append("XcodeGenの月額Product IDが#15正本値と不一致")

    blockers.extend(monetization_checks(canon))

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

    if canon.get("appStoreSubmission", {}).get("approvedByUser") is not True:
        blockers.append("App Store最終提出のユーザー承認が未取得")

    return blockers


def internal_testflight_checks(canon: dict) -> list[str]:
    return common_checks(canon)


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
