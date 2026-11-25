#!/usr/bin/env python3
"""Chromium mobile-viewport smoke tests for approved official question UI.
Synthetic Q90 is injected ONLY into test HTTP response, never committed to public bank.
"""
import copy
import json
import os
from pathlib import Path
from playwright.sync_api import sync_playwright
BASE=Path(__file__).resolve().parents[1]
BANK=json.loads((BASE/"official-kansai/APPROVED_OFFICIAL_BANK.json").read_text())
SOURCE_2023=json.loads((BASE/"official-kansai/QUESTIONS_2023_APP_CANDIDATE.json").read_text())
URL="http://127.0.0.1:8765/official-practice.html"
def assert_no_overflow(page):
    actual=page.evaluate("() => ({scroll:document.documentElement.scrollWidth,client:document.documentElement.clientWidth})")
    assert actual["scroll"] <= actual["client"]+2, actual
def standard(page,width):
    page.set_viewport_size({"width":width,"height":800})
    page.goto(URL,wait_until="networkidle")
    page.locator("#available").get_by_text(str(BANK["count"])+"問",exact=False).wait_for()
    assert str(BANK["count"])+"問" in page.locator("#count").inner_text()
    assert_no_overflow(page)
    page.locator("#start").click()
    four_seen=False
    for i,q in enumerate(BANK["questions"]):
        assert f"問{q['questionNo']}" in page.locator("#questionTitle").inner_text()
        assert page.locator("#choices button").count()==len(q["choices"])
        assert q["attributionDisplay"] in page.locator("#attribution").inner_text()
        assert_no_overflow(page)
        if i==0:page.screenshot(path=f"/tmp/touhan_mobile_{width}.png",full_page=True)
        if len(q["choices"])==4:four_seen=True
        page.locator("#choices button").nth(q["answer"]).click()
        page.locator("#feedback .explanation").wait_for(state="visible")
        assert page.locator("#feedback .explanation").inner_text().strip()
        page.locator("#next").click()
    assert four_seen,"Four-option official sample missing"
    assert str(BANK["count"])+" / "+str(BANK["count"]) in page.locator("#summary").inner_text()
    assert "100%" in page.locator("#summary").inner_text()
def q90_mock(page):
    # Never commits or publishes the unreviewed Q90; use request interception for QA.
    candidate=SOURCE_2023["questions"][89]
    fake=copy.deepcopy(candidate)
    fake.update({"verbatimCertified":True,"needsVisualReview":False,"renderReady":True})
    body={"count":1,"status":"TEST_ONLY","questions":[fake]}
    def handle(route):
        route.fulfill(status=200,content_type="application/json; charset=utf-8",body=json.dumps(body,ensure_ascii=False))
    page.route("**/official-kansai/APPROVED_OFFICIAL_BANK.json",handle)
    page.goto(URL,wait_until="networkidle")
    assert "1問" in page.locator("#count").inner_text()
    page.locator("#start").click()
    page.locator("#choices button").first.click()
    assert "分母から除外" in page.locator("#feedback").inner_text()
    page.locator("#next").click()
    assert "採点対象なし" in page.locator("#summary").inner_text()
    assert "採点除外1問" in page.locator("#exclusion").inner_text()
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True)
    for width in (375,430):
        context=browser.new_context(viewport={"width":width,"height":800},device_scale_factor=2,is_mobile=True,has_touch=True)
        page=context.new_page()
        standard(page,width)
        context.close()
    context=browser.new_context(viewport={"width":375,"height":800},is_mobile=True)
    page=context.new_page()
    q90_mock(page)
    context.close()
    browser.close()
print("PASS: 375 and 430 px smartphone, all approved questions, four-option, source display, excluded Q90 simulated")
