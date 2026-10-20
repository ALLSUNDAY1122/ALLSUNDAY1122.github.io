from pathlib import Path

workflow = Path(__file__).resolve().parents[2] / ".github/workflows/splat-native-ios.yml"
text = workflow.read_text()

required = [
    "SCANLAB_E2E_EMAIL: ${{ secrets.SCANLAB_E2E_EMAIL }}",
    "SCANLAB_E2E_PASSWORD: ${{ secrets.SCANLAB_E2E_PASSWORD }}",
    "- name: Live ScanLab auth/session/profile E2E gate",
    "if: ${{ env.SCANLAB_E2E_EMAIL != '' && env.SCANLAB_E2E_PASSWORD != '' }}",
    "- name: Live ScanLab auth E2E blocked by missing test identity",
    "if: ${{ env.SCANLAB_E2E_EMAIL == '' || env.SCANLAB_E2E_PASSWORD == '' }}",
    "LIVE_E2E_BLOCKED_BY_TEST_IDENTITY",
    "LIVE_E2E_PASS",
    "node splat-native-ios/scripts/scanlab_auth_e2e.mjs",
]
for needle in required:
    assert needle in text, f"missing auth workflow contract: {needle}"

live_start = text.index("- name: Live ScanLab auth/session/profile E2E gate")
blocked_start = text.index("- name: Live ScanLab auth E2E blocked by missing test identity")
live_block = text[live_start:blocked_start]
assert "exit 0" not in live_block, "live E2E must not convert a missing/failed identity into success"
assert "grep -q '\"status\":\"PASS\"'" in live_block, "live E2E must require explicit PASS"

print("PASS: D2-001 live Auth workflow distinguishes SKIPPED/BLOCKED from real E2E PASS")
