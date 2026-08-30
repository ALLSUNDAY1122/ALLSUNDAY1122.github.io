from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "project.godot",
    "export_presets.cfg",
    "Main.tscn",
    "Integration/INTERFACE_CONTRACT.md",
    "Integration/Bootstrap.gd",
    "Integration/Adapters/CoreGameplayAdapter.gd",
    "Integration/Adapters/ProgressionWorldAdapter.gd",
    "Platform/Input/InputRouter.gd",
    "Platform/Input/MobileControls.gd",
    "Platform/iOS/IOSLayout.gd",
    "Platform/iOS/Lifecycle.gd",
]

def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)

for rel in REQUIRED:
    if not (ROOT / rel).is_file():
        fail(f"missing required file: {rel}")

project = (ROOT / "project.godot").read_text(encoding="utf-8")
for setting in (
    'size/viewport_width=1280',
    'size/viewport_height=720',
    'handheld/orientation=4',
    'ios/allow_high_refresh_rate=true',
):
    if setting not in project:
        fail(f"missing iOS/display setting: {setting}")

contract = (ROOT / "Integration/INTERFACE_CONTRACT.md").read_text(encoding="utf-8")
for token in ("lap_completed", "ability_unlocked", "register_lap", "serialize_state", "consume_pressed"):
    if token not in contract:
        fail(f"contract token missing: {token}")

export = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
if 'platform="iOS"' not in export:
    fail("iOS export preset missing")
if 'application/bundle_identifier="jp.allsunday1122.loopforge"' not in export:
    fail("bundle identifier missing or changed")

print("Loopforge bootstrap contract validation: PASS")
