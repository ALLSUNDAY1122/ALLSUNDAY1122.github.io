#!/usr/bin/env python3
"""Set the generated Flutter iOS Runner app's single supported language to Japanese.

Run after flutter create --platforms=ios . and before flutter build ipa.
The iOS project isn't committed to this repository, so the setting must be
applied again if the platform files are regenerated.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import plistlib
import re
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Only validate settings")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    plist_path = root / "ios" / "Runner" / "Info.plist"
    pbx_path = root / "ios" / "Runner.xcodeproj" / "project.pbxproj"

    if not plist_path.is_file() or not pbx_path.is_file():
        print("ERROR: iOS project is missing; generate it with flutter create --platforms=ios .", file=sys.stderr)
        return 2

    with plist_path.open("rb") as f:
        settings = plistlib.load(f)
    project = pbx_path.read_text(encoding="utf-8")
    default_language = re.search(r"\bdevelopmentRegion\s*=\s*([^;]+);", project)
    known_languages = re.search(r"(?s)(\bknownRegions\s*=\s*\()([^)]+)(\)\s*;)", project)

    def split_regions(text: str) -> list[str]:
        return [s.strip().strip('"') for s in text.split(",") if s.strip()]

    valid = (
        settings.get("CFBundleDevelopmentRegion") == "ja"
        and settings.get("CFBundleLocalizations") == ["ja"]
        and default_language is not None
        and default_language.group(1).strip() == "ja"
        and known_languages is not None
        and "ja" in split_regions(known_languages.group(2))
        and "en" not in split_regions(known_languages.group(2))
    )
    if args.check:
        print("Japanese iOS locale: OK" if valid else "Japanese iOS locale: NEEDS_UPDATE")
        return 0 if valid else 1

    settings["CFBundleDevelopmentRegion"] = "ja"
    settings["CFBundleLocalizations"] = ["ja"]
    with plist_path.open("wb") as f:
        plistlib.dump(settings, f, sort_keys=False)

    if default_language is None or known_languages is None:
        print("ERROR: unexpected Xcode project structure; inspect localizations manually.", file=sys.stderr)
        return 2

    project = re.sub(r"(\bdevelopmentRegion\s*=\s*)[^;]+;", r"\g<1>ja;", project, count=1)
    # Keep Base (storyboard resources) and any other regions, but remove English.
    def adjust_known_regions(match: re.Match[str]) -> str:
        regions = split_regions(match.group(2))
        regions = ["ja"] + [r for r in regions if r not in ("ja", "en")]
        lines = "\n" + "".join(f"\t\t\t\t{r},\n" for r in regions) + "\t\t\t"
        return match.group(1) + lines + match.group(3)

    project = re.sub(r"(?s)(\bknownRegions\s*=\s*\()([^)]+)(\)\s*;)", adjust_known_regions, project, count=1)
    pbx_path.write_text(project, encoding="utf-8")
    print("Configured Runner iOS localization: Japanese (ja).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
