#!/usr/bin/env python3
"""Attach Review.storekit to the scheme TestAction after xcodegen generate.

XcodeGen's scheme.storeKitConfiguration is written only on LaunchAction (Run).
UI tests launch the app through TestAction, so Product.products(for:) in the
app process never sees the configuration unless TestAction also references it.

Evidence: GitHub Actions run 45729899684 copied Review.storekit into the UITest
bundle and constructed SKTestSession, but the paywall buttons stayed at
'月額プラン, 価格を取得中' / '買い切りプラン, 価格を取得中' until timeout.
"""
from __future__ import annotations

import sys
from pathlib import Path

SCHEME = Path("KangoshiSprint.xcodeproj/xcshareddata/xcschemes/KangoshiSprint.xcscheme")
IDENTIFIER = "../../Review.storekit"
REFERENCE = (
    "      <StoreKitConfigurationFileReference\n"
    f'         identifier = "{IDENTIFIER}">\n'
    "      </StoreKitConfigurationFileReference>\n"
)


def action_slice(src: str, name: str) -> tuple[int, int, str]:
    start = src.index(f"<{name}")
    end = src.index(f"</{name}>", start) + len(f"</{name}>")
    return start, end, src[start:end]


def action_has_storekit(block: str) -> bool:
    return "StoreKitConfigurationFileReference" in block and "Review.storekit" in block


def patch_action(src: str, name: str) -> str:
    start, end, block = action_slice(src, name)
    if action_has_storekit(block):
        return src
    patched = block[: -len(f"</{name}>")] + REFERENCE + f"   </{name}>"
    return src[:start] + patched + src[end:]


def main() -> None:
    scheme = Path(sys.argv[1]) if len(sys.argv) > 1 else SCHEME
    text = scheme.read_text(encoding="utf-8")
    if "Review.storekit" not in text:
        for name in ("LaunchAction", "TestAction"):
            text = patch_action(text, name)
    else:
        text = patch_action(text, "TestAction")
    scheme.write_text(text, encoding="utf-8")
    _, _, test_block = action_slice(text, "TestAction")
    if not action_has_storekit(test_block):
        raise SystemExit("TestAction is missing StoreKitConfigurationFileReference for Review.storekit")
    print("TestAction StoreKit configuration attached")


if __name__ == "__main__":
    main()
