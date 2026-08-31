from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

class IOSFoundationTests(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding="utf-8")

    def test_ios_is_landscape_iphone_only_and_120hz_ready(self):
        project = self.read("project.godot")
        export = self.read("export_presets.cfg")
        self.assertIn('handheld/orientation=4', project)
        self.assertIn('ios/allow_high_refresh_rate=true', project)
        self.assertIn('common/physics_ticks_per_second=120', project)
        self.assertIn('application/targeted_device_family=0', export)

    def test_ios_privacy_manifest_required_api_reasons_are_explicit(self):
        export = self.read("export_presets.cfg")
        self.assertIn('privacy/file_timestamp_access_reasons=3', export)
        self.assertIn('privacy/system_boot_time_access_reasons=1', export)
        self.assertIn('privacy/disk_space_access_reasons=3', export)

    def test_touch_router_is_source_aware_for_simultaneous_fingers(self):
        router = self.read("Platform/Input/InputRouter.gd")
        mobile = self.read("Platform/Input/MobileControls.gd")
        self.assertIn("_virtual_sources", router)
        self.assertIn("set_touch_action", router)
        self.assertIn("InputEventScreenTouch", mobile)
        self.assertIn("_finger_actions", mobile)
        self.assertNotIn("Button.new()", mobile)

    def test_safe_area_and_background_pause_are_first_class(self):
        layout = self.read("Platform/iOS/IOSLayout.gd")
        lifecycle = self.read("Platform/iOS/Lifecycle.gd")
        bootstrap = self.read("Integration/Bootstrap.gd")
        self.assertIn("get_display_safe_area", layout)
        self.assertIn("safe_area_changed", bootstrap)
        self.assertIn("get_tree().paused = true", lifecycle)
        self.assertIn("_paused_before_background", lifecycle)

if __name__ == "__main__":
    unittest.main()
