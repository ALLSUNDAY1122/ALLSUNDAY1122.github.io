from pathlib import Path
import plistlib

ROOT = Path(__file__).resolve().parents[1]
GROUP = "group.jp.allsunday1122.clipboardwidget"

for p in [
    ROOT / "App/ClipboardWidget.entitlements",
    ROOT / "Widget/ClipboardWidgetExtension.entitlements",
    ROOT / "App/PrivacyInfo.xcprivacy",
    ROOT / "Widget/PrivacyInfo.xcprivacy",
    ROOT / "Widget/Info.plist",
]:
    with p.open("rb") as f:
        plistlib.load(f)

for p in [ROOT / "App/ClipboardWidget.entitlements", ROOT / "Widget/ClipboardWidgetExtension.entitlements"]:
    with p.open("rb") as f:
        data = plistlib.load(f)
    assert GROUP in data["com.apple.security.application-groups"]

for p in [ROOT / "App/PrivacyInfo.xcprivacy", ROOT / "Widget/PrivacyInfo.xcprivacy"]:
    with p.open("rb") as f:
        privacy = plistlib.load(f)
    assert privacy["NSPrivacyTracking"] is False
    assert privacy["NSPrivacyCollectedDataTypes"] == []
    user_defaults = next(x for x in privacy["NSPrivacyAccessedAPITypes"] if x["NSPrivacyAccessedAPIType"] == "NSPrivacyAccessedAPICategoryUserDefaults")
    assert "1C8F.1" in user_defaults["NSPrivacyAccessedAPITypeReasons"]

intent_text = (ROOT / "Shared/Phase0.swift").read_text()
assert 'PasteboardProbePayload.widgetExtension' in intent_text
assert 'WidgetExtensionCopyProbeIntent' in intent_text
assert 'allowedExecutionTargets' not in intent_text
assert 'supportedModes' in intent_text and '[.background]' in intent_text

all_swift = "\n".join(p.read_text() for p in ROOT.rglob("*.swift"))
for forbidden in ["UIPasteboard.general.string!", "UIPasteboard.general.strings", "UIPasteboard.general.items", "hasStrings", "detectPatterns"]:
    assert forbidden not in all_swift, f"pasteboard read-like API found: {forbidden}"

project = (ROOT / "project.yml").read_text()
assert "jp.allsunday1122.clipboardwidget" in project
assert "jp.allsunday1122.clipboardwidget.widget" in project
print("static_audit: PASS")
