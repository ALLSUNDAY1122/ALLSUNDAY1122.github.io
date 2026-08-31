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
    "Platform/Input/PauseController.gd",
    "Platform/iOS/IOSLayout.gd",
    "Platform/iOS/Lifecycle.gd",
    "Platform/iOS/AppIcon.svg",
]

def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)

for rel in REQUIRED:
    if not (ROOT / rel).is_file():
        fail(f"missing required file: {rel}")

project = (ROOT / "project.godot").read_text(encoding="utf-8")
for setting in (
    'config/icon="res://Platform/iOS/AppIcon.svg"',
    'size/viewport_width=1280',
    'size/viewport_height=720',
    'handheld/orientation=4',
    'ios/allow_high_refresh_rate=true',
    'ios/hide_home_indicator=true',
    'ios/suppress_ui_gesture=true',
    'textures/vram_compression/import_etc2_astc=true',
    'common/physics_ticks_per_second=120',
    'common/max_physics_steps_per_frame=8',
    'PauseController="*res://Platform/Input/PauseController.gd"',
):
    if setting not in project:
        fail(f"missing iOS/display/runtime setting: {setting}")

contract = (ROOT / "Integration/INTERFACE_CONTRACT.md").read_text(encoding="utf-8")
for token in ("lap_completed", "ability_unlocked", "register_lap", "serialize_state", "consume_pressed"):
    if token not in contract:
        fail(f"contract token missing: {token}")

export = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
for setting in (
    'platform="iOS"',
    'application/bundle_identifier="jp.allsunday1122.loopforge"',
    'application/targeted_device_family=0',
    'application/export_project_only=true',
    'export_path="Build/iOS/Loopforge"',
    'privacy/file_timestamp_access_reasons=3',
    'privacy/system_boot_time_access_reasons=1',
    'privacy/disk_space_access_reasons=3',
):
    if setting not in export:
        fail(f"iOS export setting missing or changed: {setting}")

input_router = (ROOT / "Platform/Input/InputRouter.gd").read_text(encoding="utf-8")
mobile = (ROOT / "Platform/Input/MobileControls.gd").read_text(encoding="utf-8")
for token in ("set_touch_action", "_virtual_sources", "release_source"):
    if token not in input_router:
        fail(f"multi-touch router token missing: {token}")
for token in ("InputEventScreenTouch", "InputEventScreenDrag", "_finger_actions"):
    if token not in mobile:
        fail(f"mobile multi-touch token missing: {token}")

lifecycle = (ROOT / "Platform/iOS/Lifecycle.gd").read_text(encoding="utf-8")
for token in ("NOTIFICATION_APPLICATION_PAUSED", "NOTIFICATION_APPLICATION_RESUMED", "get_tree().paused = true"):
    if token not in lifecycle:
        fail(f"lifecycle token missing: {token}")

print("Loopforge iOS foundation validation: PASS")
