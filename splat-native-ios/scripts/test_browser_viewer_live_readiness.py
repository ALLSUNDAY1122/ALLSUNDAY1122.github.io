#!/usr/bin/env python3
"""Live public-viewer readiness probe.

When production has no public published scan yet, report BLOCKED without failing CI.
Once a public scan exists, validate the real metadata and durable scene.spz delivery
contract so the remaining browser-render E2E can run without another code change.
"""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.parse
import urllib.request

API = "https://gybchnyqlqwmajwkhsly.supabase.co/functions/v1/scanlab-public"
ORIGIN = "https://allsunday1122.github.io"
TIMEOUT = 15


def request(url: str, *, method: str = "GET", headers: dict[str, str] | None = None):
    merged = {"Accept": "application/json", "Origin": ORIGIN}
    if headers:
        merged.update(headers)
    req = urllib.request.Request(url, method=method, headers=merged)
    try:
        return urllib.request.urlopen(req, timeout=TIMEOUT)
    except urllib.error.HTTPError as exc:
        body = exc.read(500).decode("utf-8", "replace")
        raise AssertionError(f"{method} {url} -> HTTP {exc.code}: {body}") from exc


def read_json(url: str) -> dict:
    with request(url) as response:
        assert response.status == 200, response.status
        assert response.headers.get("Access-Control-Allow-Origin") == ORIGIN
        return json.loads(response.read().decode("utf-8"))


feed = read_json(f"{API}?mode=feed&limit=1&includeModel=1")
items = feed.get("items") or []
if not items:
    print("browser viewer live readiness: BLOCKED (no public published scan)")
    sys.exit(0)

item = items[0]
scan_id = item.get("id")
model_url = item.get("modelUrl")
assert isinstance(scan_id, str) and scan_id, "feed item missing id"
assert isinstance(model_url, str) and model_url.startswith(API + "?mode=asset&"), model_url
assert urllib.parse.parse_qs(urllib.parse.urlparse(model_url).query).get("id") == [scan_id]

share = read_json(f"{API}?mode=share&id={urllib.parse.quote(scan_id)}")
shared = share.get("item") or {}
assert shared.get("id") == scan_id
assert shared.get("modelUrl") == model_url

with request(model_url, method="HEAD", headers={"Accept": "application/octet-stream"}) as response:
    assert response.status in (200, 206), response.status
    assert response.headers.get("Access-Control-Allow-Origin") == ORIGIN
    assert response.headers.get("Content-Type", "").split(";", 1)[0] == "application/octet-stream"
    content_length = response.headers.get("Content-Length")
    if content_length is not None:
        assert int(content_length) > 0

with request(
    model_url,
    headers={"Accept": "application/octet-stream", "Range": "bytes=0-1023"},
) as response:
    assert response.status == 206, f"Range request must return 206, got {response.status}"
    assert response.headers.get("Access-Control-Allow-Origin") == ORIGIN
    assert response.headers.get("Accept-Ranges", "").lower() == "bytes"
    content_range = response.headers.get("Content-Range", "")
    assert content_range.startswith("bytes 0-"), content_range
    payload = response.read(1024)
    assert payload, "scene.spz range response was empty"

print(f"browser viewer live readiness: PASS ({scan_id})")
