#!/usr/bin/env python3
"""Attach Review.storekit to the scheme TestAction after xcodegen generate.

Reuses the exact <StoreKitConfigurationFileReference ...> block emitted on
LaunchAction (when present) so path formatting always matches XcodeGen output.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

SCHEME = Path("KangoshiSprint.xcodeproj/xcshareddata/xcschemes/KangoshiSprint.xcscheme")
DEFAULT_REFERENCE = (
    "      <StoreKitConfigurationFileReference\n"
    '         identifier = "../../Review.storekit">\n'
    "      </StoreKitConfigurationFileReference>\n"
)
REF_RE = re.compile(
    r"[ \t]*<StoreKitConfigurationFileReference\b[^>]*Review\.storekit[^>]*>\s*</StoreKitConfigurationFileReference>\s*",
    re.S,
)


def action_slice(src: str, name: str) -> tuple[int, int, str]:
    start = src.index(f"<{name}")
    end = src.index(f"</{name}>", start) + len(f"</{name}>")
    return start, end, src[start:end]


def action_has_storekit(block: str) -> bool:
    return "StoreKitConfigurationFileReference" in block and "Review.storekit" in block


def patch_action(src: str, name: str, ref_xml: str) -> str:
    start, end, block = action_slice(src, name)
    if action_has_storekit(block):
        return src
    patched = block[: -len(f"</{name}>")] + ref_xml + f"   </{name}>"
    return src[:start] + patched + src[end:]


def main() -> None:
    scheme = Path(sys.argv[1]) if len(sys.argv) > 1 else SCHEME
    text = scheme.read_text(encoding="utf-8")
    _, _, launch_block = action_slice(text, "LaunchAction")
    match = REF_RE.search(launch_block)
    ref_xml = match.group(0) if match else DEFAULT_REFERENCE
    if not ref_xml.endswith("\n"):
        ref_xml += "\n"

    if "Review.storekit" not in text:
        for name in ("LaunchAction", "TestAction"):
            text = patch_action(text, name, ref_xml)
    else:
        text = patch_action(text, "TestAction", ref_xml)

    scheme.write_text(text, encoding="utf-8")
    _, _, test_block = action_slice(text, "TestAction")
    if not action_has_storekit(test_block):
        raise SystemExit("TestAction is missing StoreKitConfigurationFileReference for Review.storekit")
    print("TestAction StoreKit configuration attached")


if __name__ == "__main__":
    main()
