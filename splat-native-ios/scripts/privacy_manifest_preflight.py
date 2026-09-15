#!/usr/bin/env python3
from __future__ import annotations

import plistlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "SplatNative"
MANIFEST = SOURCE_ROOT / "PrivacyInfo.xcprivacy"

EXPECTED_WHEN_USED = {
    "NSPrivacyAccessedAPICategoryFileTimestamp": {
        "reason": "C617.1",
        "tokens": (
            "attributesOfItem(atPath:",
            ".creationDate",
            ".contentModificationDate",
        ),
    },
    "NSPrivacyAccessedAPICategorySystemBootTime": {
        "reason": "35F9.1",
        "tokens": ("ProcessInfo.processInfo.systemUptime",),
    },
    "NSPrivacyAccessedAPICategoryDiskSpace": {
        "reason": "E174.1",
        "tokens": (
            ".volumeAvailableCapacityForImportantUsage",
            "attributesOfFileSystem(forPath:",
        ),
    },
    "NSPrivacyAccessedAPICategoryUserDefaults": {
        "reason": "CA92.1",
        "tokens": ("UserDefaults.", "@AppStorage("),
    },
}


def fail(message: str) -> None:
    print(f"privacy-preflight: FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if not MANIFEST.is_file():
        fail(f"missing {MANIFEST.relative_to(ROOT)}")

    try:
        with MANIFEST.open("rb") as handle:
            manifest = plistlib.load(handle)
    except Exception as exc:
        fail(f"invalid privacy manifest: {exc}")

    if manifest.get("NSPrivacyTracking") is not False:
        fail("NSPrivacyTracking must be false for the app-owned manifest")
    if manifest.get("NSPrivacyTrackingDomains", []) != []:
        fail("app-owned tracking domains must remain empty unless tracking is explicitly introduced")

    declared: dict[str, set[str]] = {}
    for entry in manifest.get("NSPrivacyAccessedAPITypes", []):
        category = entry.get("NSPrivacyAccessedAPIType")
        reasons = entry.get("NSPrivacyAccessedAPITypeReasons")
        if not isinstance(category, str) or not isinstance(reasons, list):
            fail("every NSPrivacyAccessedAPITypes entry needs a category and reasons array")
        declared.setdefault(category, set()).update(str(reason) for reason in reasons)

    swift_source = "\n".join(
        path.read_text(encoding="utf-8", errors="replace")
        for path in sorted(SOURCE_ROOT.rglob("*.swift"))
    )

    used_categories: set[str] = set()
    for category, contract in EXPECTED_WHEN_USED.items():
        if any(token in swift_source for token in contract["tokens"]):
            used_categories.add(category)
            required_reason = contract["reason"]
            if required_reason not in declared.get(category, set()):
                fail(f"{category} is used but reason {required_reason} is not declared")

    app_declared_categories = set(declared)
    unsupported = app_declared_categories - used_categories
    if unsupported:
        fail("manifest declares app-owned required-reason categories not detected in source: " + ", ".join(sorted(unsupported)))

    print("privacy-preflight: PASS")
    for category in sorted(used_categories):
        reasons = ",".join(sorted(declared[category]))
        print(f"  {category}: {reasons}")


if __name__ == "__main__":
    main()
