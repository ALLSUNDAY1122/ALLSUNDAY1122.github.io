#!/usr/bin/env python3
"""AI Preflight Acceptance for registered seller, before Internal TestFlight.
Deterministic evidence-backed gates; no false claim of Xcode/physical iOS testing.
"""
from __future__ import annotations
import datetime, hashlib, json, os, re, struct, subprocess, sys
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
IOS=ROOT/"touroku-hanbaisha-ios"
WEB=ROOT/"touroku-hanbaisha-sprint"
B=WEB/"official-kansai"
OUT=IOS/"AI_PREFLIGHT_ACCEPTANCE_20261124.json"
EXPECTED="https://allsunday1122.github.io/touroku-hanbaisha-sprint/official-practice.html"
checks=[]
def gate(name, status, detail, evidence=None):
    checks.append({"id":name,"status":status,"detail":detail,"evidence":evidence or []})
def is_file(p):return p.is_file() and p.stat().st_size>0
def main():
    status=json.loads((IOS/"release-status.json").read_text())
    bank=json.loads((B/"APPROVED_OFFICIAL_BANK.json").read_text())
    rows=bank.get("questions",[])
    ids=[q.get("id") for q in rows]
    by_year=dict(Counter(q.get("year") for q in rows))
    source_ok=(bank.get("count")==599 and len(rows)==599 and len(set(ids))==599
        and by_year=={2022:120,2023:119,2024:120,2025:120,2026:120}
        and "KSAI-2023-090" not in ids)
    gate("Q0_CANONICAL_599","PASS" if source_ok else "FAIL",
        "599 source records; unique IDs; invalid 2023-Q90 excluded; counts by year "+str(by_year),
        [str(B.relative_to(ROOT)/"APPROVED_OFFICIAL_BANK.json")])
    invalid=[]; ordered=0; images=0; rich=0
    for q in rows:
        x=q.get("id","?")
        if not (q.get("officialStatus")=="NORMAL" and q.get("verbatimCertified") is True
                and q.get("renderReady") is True and q.get("needsVisualReview") is False
                and q.get("sourceIssuer")=="関西広域連合" and q.get("sourceUrl","").startswith("https://")
                and q.get("answerSourceUrl","").startswith("https://") and q.get("attributionDisplay")
                and len(q.get("choices",[])) in (4,5)
                and isinstance(q.get("answer"),int)
                and q["answer"]==q.get("answerNumberOfficial",0)-1):
            invalid.append(x)
        if "originalRubyReadings" in q:
            ordered+=1
            if not (q.get("rubyDisplayMode")=="SOURCE_ORDER_UNATTACHED"
                    and q.get("rubySourceVerified") is True
                    and q.get("originalRubyReadings")
                    and all(re.fullmatch(r"[ぁ-んァ-ンー]{1,20}",z) for z in q["originalRubyReadings"])
                    and q.get("questionParts") is None and q.get("choicesParts") is None):
                invalid.append(x+":RUBY")
        if q.get("questionParts") or q.get("choicesParts"):rich+=1
        for fig in q.get("sourceFigures",[]):
            images+=1
            web_path=fig.get("webPath","")
            if not web_path.startswith("official-kansai/layout-crops/") or not is_file(WEB/web_path):
                invalid.append(x+":FIGURE_MISSING")
            elif hashlib.sha256((WEB/web_path).read_bytes()).hexdigest()!=fig.get("sha256"):
                invalid.append(x+":FIGURE_SHA_MISMATCH")
    gate("Q1_CONTENT_AND_ATTRIBUTION","PASS" if not invalid else "FAIL",
        f"invalid records={len(invalid)}; unattached ruby={ordered}; image refs={images}; inline ruby records={rich}; examples={invalid[:15]}",
        [str(B.relative_to(ROOT)/"APPROVED_OFFICIAL_BANK.json")])
    app=json.loads((IOS/"app.json").read_text())["expo"]
    swift=(IOS/"native-ios/Sources/TouhanSprintApp.swift").read_text()
    js=(IOS/"App.js").read_text()
    ui=(WEB/"official-practice.html").read_text()
    ready=(app["extra"].get("webAppUrl")==EXPECTED and EXPECTED in swift and EXPECTED in js
           and "APPROVED_OFFICIAL_BANK.json" in ui and "renderRubySequence(q)" in ui
           and "official-practice.html" in (WEB/"app-v07.js").read_text()
           and app["ios"]["bundleIdentifier"]=="com.allsunday1122.tourokuhanbaisha"
           and "MN3D2ZM44N" in (IOS/"native-ios/project.yml").read_text())
    gate("Q2_NATIVE_WEBVIEW_INTEGRATION","PASS" if ready else "FAIL",
         f"both native entrypoints={EXPECTED}; web data URL relative; bundle/team anchored",
         ["touroku-hanbaisha-ios/App.js","touroku-hanbaisha-ios/native-ios/Sources/TouhanSprintApp.swift"])
    metadata=(IOS/"APP_STORE_METADATA.md").read_text()
    meta_ok=all(x in metadata for x in
        ("599問","2023年度問90","インターネット接続が必要","公式問題PDF","プライバシーポリシー"))
    gate("Q3_METADATA_DISCLOSURE","PASS" if meta_ok else "FAIL",
        "Store metadata must disclose 599 official past questions, invalid Q90, network dependency and source links",
        ["touroku-hanbaisha-ios/APP_STORE_METADATA.md"])
    # These evidence checks are intentionally not converted to PASS by static inspection.
    offline="source={{ uri: HOME_URL }}" in js and "webView.load(URLRequest(url: ReleaseConfig.homeURL" in swift
    gate("Q4_OFFLINE_RESILIENCE","FAIL" if offline else "NOT_TESTED",
        "Remote-only WebView loads GitHub Pages. No shipped offline app bundle; an unavailable network prevents studying."
        if offline else "Offline behavior requires native runtime verification.",
        ["touroku-hanbaisha-ios/App.js","touroku-hanbaisha-ios/native-ios/Sources/TouhanSprintApp.swift"])
    privacy=json.loads((IOS/"app.json").read_text())["expo"]
    privacyinfo=IOS/"native-ios/PrivacyInfo.xcprivacy"
    gate("Q5_PRIVACY_AND_NETWORK_DISCLOSURE","NOT_VERIFIED",
        "PrivacyInfo.xcprivacy exists, but actual remote page behavior and App Store Connect App Privacy answers were not independently verified.",
        ["touroku-hanbaisha-ios/native-ios/PrivacyInfo.xcprivacy"])
    # AI Preflight Acceptance is not an Xcode archive or iPhone/iOS simulator run.
    gate("Q6_IOS_BUILD_AND_LAUNCH","NOT_TESTED",
        "No successful native iOS simulator build, signed archive, physical-device launch, or TestFlight install observed in this run.",
        ["touroku-hanbaisha-ios/native-ios/project.yml"])
    gate("Q7_TESTFLIGHT_READY","BLOCKED",
        "Internal TestFlight distribution requires passing native build/launch and verification of signing/ASC setup. No upload or App Review submission performed.",
        ["touroku-hanbaisha-ios/eas.json"])
    gate("Q8_APP_REVIEW_SUBMISSION","PASS" if status.get("app_review_submitted") is False else "FAIL",
        "No App Review final submission authorized; must remain false.",
        ["touroku-hanbaisha-ios/release-status.json"])
    data={
      "schema":"touhan-ai-preflight-acceptance-v1",
      "timestampJST":datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(),
      "canonicalBank":bank["count"],"years":by_year,
      "scope":"Native entrypoint + 599 canonical app data + web UI + static readiness. Not iOS runtime attestation.",
      "overall":"PASS" if all(x["status"]=="PASS" for x in checks) else "BLOCKED",
      "checks":checks,
      "blocking":[x["id"] for x in checks if x["status"]!="PASS"],
      "explicitNoSubmission":True
    }
    OUT.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"overall":data["overall"],"bank":data["canonicalBank"],
                      "pass":sum(x["status"]=="PASS" for x in checks),
                      "blocking":data["blocking"]},ensure_ascii=False))
if __name__=="__main__":main()
