#!/usr/bin/env python3
"""Visual/interaction preflight for the exact FP3 native web bundle and Swift bridge.

This does not replace the native simulator gate. It gives a runner-independent gate for
information completeness, the full learning loop, premium affordance, paywall visibility
and mobile rendering by loading the HTML produced by prepare-ios.sh and evaluating the
StoreKit bridge extracted verbatim from App.swift.
"""
from __future__ import annotations

import re
import struct
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "fp3-manabi-sprint" / "ios"
HTML = IOS / "Web" / "index.html"
SWIFT = IOS / "App.swift"
OUT = ROOT / "artifacts" / "fp3-browser-visual"


def bridge_script() -> str:
    source = SWIFT.read_text(encoding="utf-8")
    match = re.search(
        r'private static let storeKitBridgeScript = #"""\n(?P<script>.*?)\n\s*"""#',
        source,
        flags=re.S,
    )
    if not match:
        raise RuntimeError("StoreKit bridge raw string not found in App.swift")
    script = match.group("script")
    required = (
        "window.__nativeStoreKitUpdate",
        "Premiumで学習範囲を広げる",
        "purchase",
        "restore",
        "#years button",
    )
    missing = [marker for marker in required if marker not in script]
    if missing:
        raise RuntimeError(f"StoreKit bridge contract changed: missing {missing}")
    return script


def png_size(path: Path) -> tuple[int, int]:
    raw = path.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError(f"not a PNG: {path}")
    return struct.unpack(">II", raw[16:24])


def shown(locator) -> bool:
    return locator.evaluate("el => el.classList.contains('show')")


def main() -> None:
    if not HTML.exists():
        raise RuntimeError("native Web/index.html missing; run prepare-ios.sh first")
    html = HTML.read_text(encoding="utf-8")
    if 'id="fp3-bundled-bank"' not in html:
        raise RuntimeError("native bundle does not contain the audited embedded question bank")

    OUT.mkdir(parents=True, exist_ok=True)
    home_png = OUT / "01-home.png"
    result_png = OUT / "02-learning-result.png"
    paywall_png = OUT / "03-paywall.png"

    with sync_playwright() as p:
        browser = p.chromium.launch()
        context = browser.new_context(
            viewport={"width": 430, "height": 932},
            device_scale_factor=3,
            locale="ja-JP",
        )
        page = context.new_page()
        console_errors: list[str] = []
        page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)
        page.on("pageerror", lambda err: console_errors.append(str(err)))
        page.goto(HTML.resolve().as_uri(), wait_until="load")
        page.wait_for_selector("#years button", timeout=10000)

        # Evaluate the exact bridge shipped by the Swift host; only webkit messaging is mocked.
        page.evaluate("window.webkit={messageHandlers:{storeKit:{postMessage:()=>{}}}}")
        page.evaluate(bridge_script())
        page.evaluate(
            "window.__nativeStoreKitUpdate({native:true,premium:false,displayPrice:'¥800',status:'known'})"
        )

        body = page.locator("body").inner_text()
        for required_text in ("FP3級 学科", "2026", "2025", "2024", "CBT対策"):
            if required_text not in body:
                raise RuntimeError(f"home information missing: {required_text}")
        if "教材読込エラー" in body or "読み込みエラー" in body:
            raise RuntimeError("native bundle rendered an error state")

        locked = page.locator("#years button", has_text="2024").first
        if not locked.is_visible():
            raise RuntimeError("2024 Premium entry is not visible")
        aria = locked.get_attribute("aria-label") or ""
        if "Premium" not in aria:
            raise RuntimeError(f"2024 Premium affordance missing from accessibility label: {aria!r}")
        page.screenshot(path=str(home_png), full_page=False)

        # Learning Acceptance Contract: start -> understand -> progress -> result -> review -> retry.
        start = page.locator("#start12")
        if not start.is_visible() or not start.is_enabled():
            raise RuntimeError("12-question learning entry is not usable")
        start.click()
        page.wait_for_selector("#quiz.active", timeout=5000)

        for i in range(12):
            qtext = page.locator("#qtext").inner_text().strip()
            if not qtext:
                raise RuntimeError(f"question text missing at item {i + 1}")
            counter = page.locator("#counter").inner_text().strip()
            if not counter:
                raise RuntimeError(f"progress counter missing at item {i + 1}")
            unknown = page.locator("#unknown")
            if not unknown.is_visible() or not unknown.is_enabled():
                raise RuntimeError(f"unknown-answer path unusable at item {i + 1}")
            unknown.click()

            feedback = page.locator("#feedback")
            if not shown(feedback):
                raise RuntimeError(f"immediate feedback missing at item {i + 1}")
            remember = page.locator("#remember").inner_text().strip()
            if not remember:
                raise RuntimeError(f"understanding aid missing at item {i + 1}")

            if i == 0:
                detail = page.locator("#detailBtn")
                if not detail.is_visible() or not detail.is_enabled():
                    raise RuntimeError("detailed-explanation control is unavailable")
                detail.click()
                details = page.locator("#details")
                if not shown(details):
                    raise RuntimeError("detailed explanation did not open")
                if not page.locator("#explanation").inner_text().strip():
                    raise RuntimeError("detailed explanation content is empty")

            nxt = page.locator("#next")
            if not nxt.is_visible() or not nxt.is_enabled():
                raise RuntimeError(f"next-question control unavailable at item {i + 1}")
            nxt.click()
            if i < 11:
                page.wait_for_selector("#quiz.active", timeout=5000)

        page.wait_for_selector("#result.active", timeout=5000)
        if not page.locator("#resultScore").inner_text().strip():
            raise RuntimeError("result score is missing")
        result_meta = page.locator("#resultMeta").inner_text().strip()
        if not result_meta:
            raise RuntimeError("result progress summary is missing")
        result_weak = page.locator("#resultWeak").inner_text().strip()
        if not result_weak:
            raise RuntimeError("result review summary is missing")
        page.screenshot(path=str(result_png), full_page=False)

        review = page.locator("#reviewWrong")
        if not review.is_visible() or not review.is_enabled():
            raise RuntimeError("review/retry control is unavailable after result")
        review.click()
        page.wait_for_selector("#quiz.active", timeout=5000)
        if not page.locator("#qtext").inner_text().strip():
            raise RuntimeError("review/retry did not reopen a question")
        if not page.locator("#counter").inner_text().strip():
            raise RuntimeError("review/retry progress is not visible")
        page.locator("#quizHome").click()
        page.wait_for_selector("#home.active", timeout=5000)

        # Premium affordance/paywall and StoreKit state transition.
        locked = page.locator("#years button", has_text="2024").first
        locked.click()
        paywall = page.locator("#fp3-native-paywall")
        if not paywall.is_visible():
            raise RuntimeError("Premium paywall did not become visible")
        text = paywall.inner_text()
        for required_text in (
            "Premiumで学習範囲を広げる",
            "全178問",
            "¥800でPremiumを購入",
            "購入を復元",
            "今はしない",
        ):
            if required_text not in text:
                raise RuntimeError(f"paywall information missing: {required_text}")
        page.screenshot(path=str(paywall_png), full_page=False)

        # State transition: becoming premium must close the paywall and remove the lock.
        page.evaluate(
            "window.__nativeStoreKitUpdate({native:true,premium:true,displayPrice:'¥800',status:'known'})"
        )
        if paywall.is_visible():
            raise RuntimeError("paywall remains visible after premium entitlement update")
        if "Premium" in (locked.get_attribute("aria-label") or ""):
            raise RuntimeError("premium lock remains after entitlement update")

        browser.close()

    for shot in (home_png, result_png, paywall_png):
        if png_size(shot) != (1290, 2796):
            raise RuntimeError(f"unexpected mobile screenshot size for {shot}: {png_size(shot)}")

    if console_errors:
        raise RuntimeError("browser console/page errors: " + " | ".join(console_errors[-10:]))
    print("PASS: FP3 learning-cycle + bundled mobile visual + premium interaction preflight")


if __name__ == "__main__":
    main()
