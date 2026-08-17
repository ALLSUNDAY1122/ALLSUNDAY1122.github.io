#!/usr/bin/env python3
"""Static regression gates for the public browser viewer loading lifecycle."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / "viewer"
js = (VIEWER / "viewer.js").read_text(encoding="utf-8")
html = (VIEWER / "index.html").read_text(encoding="utf-8")
css = (VIEWER / "viewer.css").read_text(encoding="utf-8")

required_js = {
    "metadata timeout": "METADATA_TIMEOUT_MS",
    "scene timeout": "SCENE_TIMEOUT_MS",
    "manual retry": "retry.addEventListener('click'",
    "offline handling": "window.addEventListener('offline'",
    "online recovery": "window.addEventListener('online'",
    "HTTP 404/410 terminal handling": "response.status === 404 || response.status === 410",
    "authorization terminal handling": "response.status === 401 || response.status === 403",
    "rate limit handling": "response.status === 429",
    "no-store metadata fetch": "cache: 'no-store'",
    "abortable metadata request": "signal: controller.signal",
    "scene timeout race": "Promise.race([",
    "viewer cleanup before retry": "cleanupViewer();",
    "HTTPS model URL gate": "url.protocol !== 'https:'",
    "stale load generation guard": "generation !== loadGeneration",
    "progressive scene loading": "progressiveLoad: true",
}
for label, needle in required_js.items():
    assert needle in js, f"missing browser viewer contract: {label}"

required_html = [
    'id="retry"',
    'id="status-detail"',
    'aria-live="polite"',
    'aria-busy="true"',
]
for needle in required_html:
    assert needle in html, f"missing browser viewer UI contract: {needle}"

assert ".status.error" in css, "missing error visual state"
assert ".status.offline" in css, "missing offline visual state"
assert ".retry-button" in css, "missing retry button styling"
assert "prefers-reduced-motion" in css, "missing reduced-motion accommodation"

# Prevent regression to the original one-shot loader that hid all failures behind one message.
assert "async function main()" not in js, "legacy one-shot main loader returned"
assert "showLoadingUI: true" not in js, "library loading UI must not conflict with app lifecycle UI"

# Keep retry policy intentionally bounded: at most one automatic retry before user action.
match = re.search(r"AUTO_RETRY_DELAYS_MS\s*=\s*\[([^\]]+)\]", js)
assert match, "automatic retry policy missing"
assert len([p for p in match.group(1).split(',') if p.strip()]) <= 2, "automatic retry loop is unbounded/aggressive"

print("browser viewer contracts: PASS")
