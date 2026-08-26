from pathlib import Path
import plistlib

ROOT = Path(__file__).resolve().parents[1]

for p in [ROOT / "App/PrivacyInfo.xcprivacy", ROOT / "Widget/PrivacyInfo.xcprivacy", ROOT / "Widget/Info.plist"]:
    with p.open("rb") as f:
        plistlib.load(f)

for p in [ROOT / "App/PrivacyInfo.xcprivacy", ROOT / "Widget/PrivacyInfo.xcprivacy"]:
    with p.open("rb") as f:
        privacy = plistlib.load(f)
    assert privacy["NSPrivacyTracking"] is False
    assert privacy["NSPrivacyCollectedDataTypes"] == []
    assert privacy["NSPrivacyAccessedAPITypes"] == []

intent_text = (ROOT / "Shared/Phase0.swift").read_text()
assert 'UIPasteboard.general.string = PasteboardProbePayload.widgetExtension' in intent_text
assert 'WidgetExtensionCopyProbeIntent' in intent_text
assert 'allowedExecutionTargets' not in intent_text
assert 'supportedModes' in intent_text and '[.background]' in intent_text

all_swift = "\n".join(p.read_text() for p in ROOT.rglob("*.swift"))
for forbidden in ["UIPasteboard.general.string!", "UIPasteboard.general.strings", "UIPasteboard.general.items", "hasStrings", "detectPatterns", "UserDefaults(suiteName"]:
    assert forbidden not in all_swift, f"forbidden Phase 0 API found: {forbidden}"

project = (ROOT / "project.yml").read_text()
assert "jp.allsunday1122.clipboardwidget" in project
assert "jp.allsunday1122.clipboardwidget.widget" in project
assert "CODE_SIGN_ENTITLEMENTS" not in project
print("static_audit: PASS")
