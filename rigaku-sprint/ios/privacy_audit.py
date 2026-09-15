#!/usr/bin/env python3
from __future__ import annotations

import plistlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
APP_SOURCES = ROOT / "Sources"
CORE_SOURCES = ROOT.parent.parent / "native-ios" / "LearningSprintCore" / "Sources"
MANIFEST = ROOT / "PrivacyInfo.xcprivacy"

# Apple Required Reason API categories that this app does not currently need.
# If a marker appears, CI fails until the implementation and PrivacyInfo.xcprivacy
# are reviewed together and an approved reason is deliberately declared.
REQUIRED_REASON_MARKERS = {
    "UserDefaults": "UserDefaults",
    "ProcessInfo.processInfo.systemUptime": "system boot time",
    ".systemUptime": "system boot time",
    "mach_absolute_time": "system boot time",
    "volumeAvailableCapacity": "disk space",
    "volumeAvailableCapacityForImportantUsage": "disk space",
    "volumeAvailableCapacityForOpportunisticUsage": "disk space",
    "systemFreeSize": "disk space",
    "systemSize": "disk space",
    "statfs(": "disk space",
    "statvfs(": "disk space",
    "activeInputModes": "active keyboard",
    "creationDateKey": "file timestamp",
    "contentModificationDateKey": "file timestamp",
    "attributeModificationDate": "file timestamp",
}


def swift_text() -> str:
    paths = list(APP_SOURCES.rglob("*.swift")) + list(CORE_SOURCES.rglob("*.swift"))
    return "\n".join(path.read_text(encoding="utf-8") for path in paths)


def plist_dict(path: Path) -> dict:
    with path.open("rb") as handle:
        value = plistlib.load(handle)
    if not isinstance(value, dict):
        raise ValueError("privacy manifest root must be a dictionary")
    return value


def main() -> int:
    errors: list[str] = []

    if not MANIFEST.exists():
        errors.append("PrivacyInfo.xcprivacy missing")
        manifest = {}
    else:
        try:
            manifest = plist_dict(MANIFEST)
        except Exception as exc:  # plistlib surfaces syntax/type issues
            errors.append(f"PrivacyInfo.xcprivacy invalid: {exc}")
            manifest = {}

    text = swift_text()
    detected: list[tuple[str, str]] = []
    for marker, category in REQUIRED_REASON_MARKERS.items():
        if marker in text:
            detected.append((marker, category))

    accessed = manifest.get("NSPrivacyAccessedAPITypes", [])
    if not isinstance(accessed, list):
        errors.append("NSPrivacyAccessedAPITypes must be an array")
        accessed = []

    if detected:
        for marker, category in detected:
            errors.append(
                f"Required Reason API marker detected ({category}): {marker}; "
                "review implementation and declare an Apple-approved reason before release"
            )
    elif accessed:
        errors.append(
            "Privacy manifest declares Required Reason APIs but source scan found none; "
            "remove stale declarations or extend the scanner with an evidence-backed exception"
        )

    if manifest.get("NSPrivacyTracking") is not False:
        errors.append("NSPrivacyTracking must be false for the current offline/no-tracking implementation")

    tracking_domains = manifest.get("NSPrivacyTrackingDomains", [])
    if tracking_domains != []:
        errors.append("NSPrivacyTrackingDomains must be empty for the current implementation")

    collected = manifest.get("NSPrivacyCollectedDataTypes", [])
    if collected != []:
        errors.append("NSPrivacyCollectedDataTypes must be empty for the current implementation")

    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    if "PrivacyInfo.xcprivacy" not in project:
        errors.append("PrivacyInfo.xcprivacy is not registered as an app resource")

    banned_network_tokens = (
        "URLSession.shared.data",
        "URLSession.shared.upload",
        "URLSession.shared.download",
        "NWConnection(",
        "WKWebView",
    )
    for token in banned_network_tokens:
        if token in text:
            errors.append(
                f"network/tracking review required before keeping no-collected-data declaration: {token}"
            )

    if errors:
        print("RIGAKU PRIVACY AUDIT: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("RIGAKU PRIVACY AUDIT: PASS")
    print("tracking: false")
    print("collected data types: 0")
    print("Required Reason API markers: 0")
    print("network/tracking API markers: 0")
    return 0


if __name__ == "__main__":
    sys.exit(main())
