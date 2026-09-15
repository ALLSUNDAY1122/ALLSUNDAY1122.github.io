#!/usr/bin/env python3
"""Harden AI引継ぎ帳 v0.6 iOS project for first App Store submission."""

from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path

APP_NAME = "AI引継ぎ帳"
BUNDLE_ID = "jp.allsunday.aihandoverlog"
VERSION = "0.6.0"
BUILD = "6"

BUILD_FILE_ID = "A1B2C3D4E5F60718293A4B5C"
FILE_REF_ID = "A1B2C3D4E5F60718293A4B5D"


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def add_privacy_manifest_to_project(text: str) -> str:
    if "PrivacyInfo.xcprivacy in Resources" in text:
        return text

    build_line = (
        f"\t\t{BUILD_FILE_ID} /* PrivacyInfo.xcprivacy in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {FILE_REF_ID} /* PrivacyInfo.xcprivacy */; }};\n"
    )
    file_line = (
        f"\t\t{FILE_REF_ID} /* PrivacyInfo.xcprivacy */ = "
        "{isa = PBXFileReference; lastKnownFileType = text.plist.xml; "
        'path = PrivacyInfo.xcprivacy; sourceTree = "<group>"; };\n'
    )

    build_marker = "/* End PBXBuildFile section */"
    file_marker = "/* End PBXFileReference section */"
    if build_marker not in text or file_marker not in text:
        fail("PBX project sections were not found")

    text = text.replace(build_marker, build_line + build_marker, 1)
    text = text.replace(file_marker, file_line + file_marker, 1)

    info_child = re.compile(r"(\t+\w+ /\* Info\.plist \*/,)")
    text, count = info_child.subn(
        r"\1\n\t\t\t\t" + FILE_REF_ID + " /* PrivacyInfo.xcprivacy */,",
        text,
        count=1,
    )
    if count != 1:
        fail("Runner group Info.plist entry was not found")

    resources_block = re.compile(
        r"(\b97C146EC1CF9000F007C117D /\* Resources \*/ = \{.*?files = \(\n)",
        re.DOTALL,
    )
    text, count = resources_block.subn(
        r"\1\t\t\t\t" + BUILD_FILE_ID + " /* PrivacyInfo.xcprivacy in Resources */,\n",
        text,
        count=1,
    )
    if count != 1:
        fail("Runner resources build phase was not found")

    return text


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: harden_v06_ios_submission.py <flutter-project-root>")

    root = Path(sys.argv[1]).resolve()
    pubspec = root / "pubspec.yaml"
    info_path = root / "ios" / "Runner" / "Info.plist"
    project_path = root / "ios" / "Runner.xcodeproj" / "project.pbxproj"
    privacy_path = root / "ios" / "Runner" / "PrivacyInfo.xcprivacy"

    for path in (pubspec, info_path, project_path):
        if not path.exists():
            fail(f"missing file: {path}")

    pubspec_text = pubspec.read_text(encoding="utf-8")
    if f"version: {VERSION}+{BUILD}" not in pubspec_text:
        fail("unexpected pubspec version/build")

    with info_path.open("rb") as handle:
        info = plistlib.load(handle)

    info["CFBundleDisplayName"] = APP_NAME
    info["CFBundleName"] = APP_NAME
    info["ITSAppUsesNonExemptEncryption"] = False
    info["UISupportedInterfaceOrientations"] = ["UIInterfaceOrientationPortrait"]
    info.pop("UISupportedInterfaceOrientations~ipad", None)

    with info_path.open("wb") as handle:
        plistlib.dump(info, handle, fmt=plistlib.FMT_XML, sort_keys=False)

    privacy = {
        "NSPrivacyTracking": False,
        "NSPrivacyTrackingDomains": [],
        "NSPrivacyCollectedDataTypes": [],
        "NSPrivacyAccessedAPITypes": [],
    }
    with privacy_path.open("wb") as handle:
        plistlib.dump(privacy, handle, fmt=plistlib.FMT_XML, sort_keys=False)

    project = project_path.read_text(encoding="utf-8")
    project, replacements = re.subn(
        r'TARGETED_DEVICE_FAMILY = "?1,2"?;',
        "TARGETED_DEVICE_FAMILY = 1;",
        project,
    )
    if replacements == 0 and "TARGETED_DEVICE_FAMILY = 1;" not in project:
        fail("TARGETED_DEVICE_FAMILY setting was not found")
    if BUNDLE_ID not in project:
        fail(f"expected app bundle ID not found: {BUNDLE_ID}")

    project = add_privacy_manifest_to_project(project)
    project_path.write_text(project, encoding="utf-8")

    if re.search(r'TARGETED_DEVICE_FAMILY = "?1,2"?;', project):
        fail("iPad device family remains enabled")
    if project.count("PrivacyInfo.xcprivacy in Resources") != 2:
        fail("privacy manifest build reference count is unexpected")

    print("HARDENING_OK")
    print(f"bundle_id={BUNDLE_ID}")
    print("device_family=iPhone")
    print("orientations=portrait")
    print("privacy_manifest=ios/Runner/PrivacyInfo.xcprivacy")


if __name__ == "__main__":
    main()
