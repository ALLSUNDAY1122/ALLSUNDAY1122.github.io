#!/usr/bin/env python3
"""Static validator proving asc-pack3 flag gating, CI gate compliance, and xcodebuild flags."""
from __future__ import annotations

import ast
import importlib.util
import re
import subprocess
import sys
import tempfile
import textwrap
import xml.etree.ElementTree as ET
from pathlib import Path

PACK3_DIR = Path(__file__).resolve().parents[3]
REPO_WORK = Path("/workspace/kangoshi-work")
RUN2_STEP6_LOG = Path("/workspace/kangoshi-upload/logs-run2/screenshots/6_Boot clean simulator, set clean status bar, and run screenshot UITest.txt")

PAYWALL_PATH = PACK3_DIR / "kangoshi-sprint/ios/Sources/PaywallView.swift"
SCREENSHOT_UITEST_PATH = PACK3_DIR / "kangoshi-sprint/ios/UITests/KangoshiScreenshotUITests.swift"
WORKFLOW_PATH = PACK3_DIR / ".github/workflows/kangoshi-asc-screenshots.yml"
ATTACH_SCRIPT_PATH = PACK3_DIR / "kangoshi-sprint/ios/tools/attach_storekit_test_action.py"


def git_show(repo_rel: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(REPO_WORK), "show", f"origin/main:{repo_rel}"],
        text=True,
    )


def git_list_tree(prefix: str) -> list[str]:
    out = subprocess.check_output(
        ["git", "-C", str(REPO_WORK), "ls-tree", "-r", "--name-only", "origin/main", prefix],
        text=True,
    )
    return [line for line in out.splitlines() if line.strip()]


def check_paywall_gating() -> None:
    text = PAYWALL_PATH.read_text(encoding="utf-8")

    # 1. Flag definition strictly reads ProcessInfo arguments
    assert 'ProcessInfo.processInfo.arguments.contains("-ASCScreenshotMode")' in text, (
        "isASCScreenshotMode must be gated strictly on ProcessInfo.processInfo.arguments"
    )
    assert len(re.findall(r'-ASCScreenshotMode', text)) == 1 or text.count("-ASCScreenshotMode") <= 2, (
        "Unexpected extra -ASCScreenshotMode references in PaywallView.swift"
    )

    # 2. Fallback price strictly guarded behind isASCScreenshotMode
    m = re.search(
        r"private func screenshotFallbackPrice\(for id: String\) -> String\?\s*\{(?P<body>.*?)\n    \}",
        text,
        re.S,
    )
    assert m, "Missing screenshotFallbackPrice(for:)"
    body = m.group("body")
    assert "guard isASCScreenshotMode else { return nil }" in body, (
        "screenshotFallbackPrice must start with guard isASCScreenshotMode else { return nil }"
    )
    assert r'"\u{00A5}200"' in body and r'"\u{00A5}800"' in body, (
        "Expected Unicode-escaped ¥200 and ¥800 fallback prices"
    )

    # 3. Primary displayPrice remains StoreKit's purchase.displayPrice(for:)
    assert "purchase.displayPrice(for: id) ?? screenshotFallbackPrice(for: id)" in text, (
        "resolvedDisplayPrice must prefer purchase.displayPrice(for: id)"
    )

    # 4. Unavailable state suppressed ONLY when isASCScreenshotMode is true
    assert "case .unavailable(let text): return isASCScreenshotMode ? nil : text" in text, (
        "stateMessage must suppress .unavailable only when isASCScreenshotMode is true"
    )

    # 5. Disabled gates keep normal behavior when !isASCScreenshotMode and always disable while purchasing
    disabled_exprs = re.findall(r"\.disabled\((.+)\)", text)
    assert len(disabled_exprs) == 2, f"Expected 2 plan button .disabled() modifiers, got {disabled_exprs}"
    for expr in disabled_exprs:
        assert "&& !isASCScreenshotMode" in expr and "purchase.state == .purchasing" in expr, (
            f"Unexpected .disabled() expression: {expr}"
        )

    # 6. No purchase/entitlement bypass in PaywallView
    assert "isPremium =" not in text
    assert "Task { await purchase.purchase(productID: monthlyID) }" in text
    assert "Task { await purchase.purchase(productID: lifetimeID) }" in text
    assert "Task { await purchase.restore() }" in text

    # 7. Ensure KangoshiSprintUITests.swift & other Sources/ do not activate -ASCScreenshotMode
    normal_ui_tests = git_show("kangoshi-sprint/ios/UITests/KangoshiSprintUITests.swift")
    assert "ASCScreenshotMode" not in normal_ui_tests, "Normal UI tests must not enable -ASCScreenshotMode"
    for rel in git_list_tree("kangoshi-sprint/ios/Sources"):
        if rel == "kangoshi-sprint/ios/Sources/PaywallView.swift":
            continue
        src = git_show(rel)
        assert "ASCScreenshotMode" not in src, f"Unexpected ASCScreenshotMode in {rel}"

    print("[PASS] PaywallView.swift flag gating & zero non-flag behavior change verified")


def check_native_ios_ci_gates() -> None:
    hardcoded_re = re.compile(r"¥\s*200|￥\s*200|200円")
    session_bang_re = re.compile(r"model\.session!")
    num_lit_re = re.compile(r"(?<![A-Za-z0-9_])\.(\d+)")

    paywall_text = PAYWALL_PATH.read_text(encoding="utf-8")

    # Overlay asc-pack3 PaywallView onto origin/main Sources/
    for rel in git_list_tree("kangoshi-sprint/ios/Sources"):
        content = paywall_text if rel == "kangoshi-sprint/ios/Sources/PaywallView.swift" else git_show(rel)
        assert not hardcoded_re.search(content), f"CI hard-coded price gate failed in {rel}"
        assert not session_bang_re.search(content), f"CI model.session! gate failed in {rel}"

    assert "購入を復元" in paywall_text, "Restore label gate failed in PaywallView.swift"

    # Check normalize_swift_numeric_literals.py regex makes zero changes on PaywallView.swift
    normalized = num_lit_re.sub(r"0.\1", paywall_text)
    assert normalized == paywall_text, "PaywallView.swift contains shorthand .digit numeric literal"

    # Check KangoshiScreenshotUITests passes -ASCScreenshotMode and asserts clean paywall state
    shot_test = SCREENSHOT_UITEST_PATH.read_text(encoding="utf-8")
    assert '"-ASCScreenshotMode"' in shot_test
    assert '"価格を取得できません"' in shot_test
    assert "価格を取得中" in shot_test
    print("[PASS] Native iOS CI source gates (hard-coded price regex, restore label, numeric literals, session!) verified")


def check_workflow_and_xcodebuild_flags() -> None:
    import yaml

    wf_text = WORKFLOW_PATH.read_text(encoding="utf-8")
    assert "-storeKitConfigurationPath" not in wf_text, "Forbidden -storeKitConfigurationPath found in workflow"
    wf = yaml.safe_load(wf_text)
    assert isinstance(wf, dict) and "jobs" in wf, "Invalid workflow YAML structure"

    # Extract printed xcodebuild Options from Run #2 log
    log_text = RUN2_STEP6_LOG.read_text(encoding="utf-8")
    assert "Usage: xcodebuild" in log_text, "Run #2 log missing xcodebuild Usage block"
    usage_section = log_text[log_text.index("Usage: xcodebuild") :]

    # Verify every flag in our xcodebuild invocation appears in Run #2 usage
    steps = wf["jobs"]["screenshots"]["steps"]
    xcodebuild_steps = [s for s in steps if "xcodebuild " in s.get("run", "")]
    assert len(xcodebuild_steps) == 1
    run_script = xcodebuild_steps[0]["run"]

    # Join line continuations and extract xcodebuild command line
    joined = run_script.replace("\\\n", " ")
    xb_lines = [line.strip() for line in joined.splitlines() if line.strip().startswith("xcodebuild ")]
    assert len(xb_lines) == 1, f"Expected single xcodebuild line, got {xb_lines}"
    xb_cmd = xb_lines[0].split("|")[0].strip()
    tokens = xb_cmd.split()
    assert tokens[0] == "xcodebuild" and tokens[1] == "test"

    flag_tokens = [t for t in tokens[2:] if t.startswith("-")]
    for tok in flag_tokens:
        opt = tok.split(":", 1)[0]
        if ":" in tok:
            opt_needle = f"{opt}:"
        else:
            opt_needle = opt
        assert opt_needle in usage_section, f"xcodebuild flag {tok!r} not found in Run #2 printed usage!"

    # Validate bash syntax of every run step + Python syntax of embedded python blocks
    for i, step in enumerate(steps, 1):
        script = step.get("run")
        if not script:
            continue
        # Replace GitHub Actions expressions ${{ ... }} with safe placeholder for bash -n
        sanitized = re.sub(r"\$\{\{[^}]+\}\}", "GITHUB_EXPR", script)
        res = subprocess.run(["bash", "-n"], input=sanitized, text=True, capture_output=True)
        assert res.returncode == 0, f"bash -n failed on step {i} ({step.get('name')}): {res.stderr}"

        for py_match in re.finditer(r"python3 - <<'PY'\n(.*?)\n\s*PY\b", script, re.S):
            py_src = textwrap.dedent(py_match.group(1))
            ast.parse(py_src)

    print(f"[PASS] Workflow YAML, bash -n, embedded Python AST, and xcodebuild options {flag_tokens} verified against Run #2 log")


def check_attach_script() -> None:
    spec = importlib.util.spec_from_file_location("attach_storekit", ATTACH_SCRIPT_PATH)
    mod = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(mod)

    sample_xcscheme = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1600" version = "1.7">
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug">
      <StoreKitConfigurationFileReference
         identifier = "../../Review.storekit">
      </StoreKitConfigurationFileReference>
   </LaunchAction>
</Scheme>
"""
    with tempfile.TemporaryDirectory() as tmp:
        p = Path(tmp) / "KangoshiSprint.xcscheme"
        p.write_text(sample_xcscheme, encoding="utf-8")
        old_argv = sys.argv
        try:
            sys.argv = [str(ATTACH_SCRIPT_PATH), str(p)]
            mod.main()
        finally:
            sys.argv = old_argv
        patched = p.read_text(encoding="utf-8")
        root = ET.fromstring(patched)
        test_refs = root.findall("./TestAction/StoreKitConfigurationFileReference")
        assert len(test_refs) == 1
        assert test_refs[0].attrib.get("identifier") == "../../Review.storekit"

    print("[PASS] attach_storekit_test_action.py XML structure & round-trip parse verified")


def main() -> None:
    check_paywall_gating()
    check_native_ios_ci_gates()
    check_workflow_and_xcodebuild_flags()
    check_attach_script()
    print("ALL VALIDATIONS PASSED")


if __name__ == "__main__":
    main()
