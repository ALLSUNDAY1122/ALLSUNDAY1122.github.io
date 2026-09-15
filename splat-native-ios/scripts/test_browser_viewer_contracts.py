#!/usr/bin/env python3
"""Static + real-browser regression gates for the public browser viewer lifecycle."""
from pathlib import Path
import contextlib, http.server, re, shutil, socketserver, subprocess, threading, time

ROOT = Path(__file__).resolve().parents[1]
VIEWER = ROOT / "viewer"
HARNESS = ROOT / "scripts" / "browser_viewer_runtime_harness"
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
for needle in ['id="retry"','id="status-detail"','aria-live="polite"','aria-busy="true"']:
    assert needle in html, f"missing browser viewer UI contract: {needle}"
assert ".status.error" in css and ".status.offline" in css and ".retry-button" in css
assert "prefers-reduced-motion" in css
assert "async function main()" not in js
assert "showLoadingUI: true" not in js
match = re.search(r"AUTO_RETRY_DELAYS_MS\s*=\s*\[([^\]]+)\]", js)
assert match and len([p for p in match.group(1).split(',') if p.strip()]) <= 2

chrome = shutil.which("chromium") or shutil.which("google-chrome") or "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
assert Path(chrome).exists() or shutil.which(chrome), "Chrome/Chromium required for D2 runtime viewer gate"

class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args): pass

with contextlib.ExitStack() as stack:
    server = socketserver.TCPServer(("127.0.0.1", 8765), Quiet)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    old = Path.cwd()
    import os
    os.chdir(ROOT)
    thread.start()
    stack.callback(server.shutdown)
    stack.callback(os.chdir, old)
    time.sleep(.2)
    def dom(scenario):
        url=f"http://127.0.0.1:8765/scripts/browser_viewer_runtime_harness/index.html?id=fixture&scenario={scenario}"
        return subprocess.check_output([chrome,"--headless","--disable-gpu","--no-sandbox","--virtual-time-budget=2500","--dump-dom",url],text=True,stderr=subprocess.STDOUT,timeout=20)
    success=dom("success")
    assert 'data-status="success"' in success and 'data-scene-started="true"' in success
    metadata_retry=dom("metadataRetry")
    assert 'data-status="success"' in metadata_retry and 'data-scene-started="true"' in metadata_retry
    scene_retry=dom("sceneRetry")
    assert 'data-status="success"' in scene_retry and 'data-viewer-disposed="true"' in scene_retry
    terminal=dom("terminal404")
    assert 'data-status="error"' in terminal and '非公開化または削除' in terminal

print("browser viewer static + Chromium runtime contracts: PASS")
