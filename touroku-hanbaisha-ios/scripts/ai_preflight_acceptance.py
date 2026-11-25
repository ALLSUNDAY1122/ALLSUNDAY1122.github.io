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
def manual_visual_audit_pass(q):
    audit=q.get("audit") or {}
    if audit.get("method")!="MANUAL_VISUAL_REAUDIT" or audit.get("status")!="PASS":
        return False
    name=audit.get("record")
    if not isinstance(name,str) or Path(name).name!=name:
        return False
    evidence_path=B/"visual-reaudit-results"/name
    if not is_file(evidence_path):
        return False
    evidence=json.loads(evidence_path.read_text(encoding="utf-8"))
    rows=evidence.get("results") or evidence.get("records") or []
    record=next((r for r in rows if r.get("id")==q.get("id")),None)
    return bool(record and record.get("status")=="PASS")
def collect_ruby_text(value):
    found=[]
    if isinstance(value,dict):
        if isinstance(value.get("rubyText"),str):
            found.append(value["rubyText"])
        for key,child in value.items():
            if key!="rubyText":
                found.extend(collect_ruby_text(child))
    elif isinstance(value,list):
        for child in value:
            found.extend(collect_ruby_text(child))
    return found
def is_subsequence(items, sequence):
    pos=0
    for item in items:
        try:
            pos=sequence.index(item,pos)+1
        except ValueError:
            return False
    return True
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
            readings=q.get("originalRubyReadings")
            readings_ok=(isinstance(readings,list) and bool(readings)
                and all(isinstance(z,str) and re.fullmatch(r"[ぁ-んァ-ンー]{1,20}",z) for z in readings))
            mode=q.get("rubyDisplayMode")
            if mode=="SOURCE_ORDER_UNATTACHED":
                representation_ok=(q.get("rubySourceVerified") is True
                    and q.get("questionParts") is None and q.get("choicesParts") is None)
            elif mode=="POSITIONALLY_ATTACHED":
                attached=collect_ruby_text(q.get("questionParts"))+collect_ruby_text(q.get("choicesParts"))
                representation_ok=(bool(attached) and is_subsequence(attached,readings)
                    and manual_visual_audit_pass(q))
            else:
                representation_ok=False
            if not (readings_ok and representation_ok):
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
    project=(IOS/"native-ios/project.yml").read_text()
    prepare=(IOS/"scripts/prepare_offline_web.py").read_text()
    cm=(ROOT/"codemagic.yaml").read_text()
    native_local=("ReleaseConfig.root" in swift and "ReleaseConfig.homeURL" in swift
        and "webView.loadFileURL(home, allowingReadAccessTo: root)" in swift
        and "WKWebViewConfiguration()" in swift)
    bundled_resources=("path: OfflineWeb" in project and "buildPhase: resources" in project
        and "OUT=ROOT/'touroku-hanbaisha-ios/native-ios/OfflineWeb'" in prepare
        and "official-practice.html" in prepare and "manifest.json" in prepare)
    release_target=("XCODE_PROJECT: touroku-hanbaisha-ios/native-ios/TouhanSprint.xcodeproj" in cm
        and "XCODE_SCHEME: TouhanSprint" in cm and "prepare-ios.sh" in cm)
    ready=(native_local and bundled_resources and release_target
           and app["ios"]["bundleIdentifier"]=="com.allsunday1122.tourokuhanbaisha"
           and "MN3D2ZM44N" in project and "renderRubySequence(q)" in ui
           and "official-practice.html" in (WEB/"app-v07.js").read_text())
    gate("Q2_NATIVE_WEBVIEW_INTEGRATION","PASS" if ready else "FAIL",
         f"native WKWebView local file entry={native_local}; OfflineWeb Xcode resources={bundled_resources}; Codemagic release target={release_target}; legacy Expo App.js remote wrapper is not the App Store release target",
         ["touroku-hanbaisha-ios/native-ios/Sources/TouhanSprintApp.swift","touroku-hanbaisha-ios/native-ios/project.yml","codemagic.yaml"])
    metadata=(IOS/"APP_STORE_METADATA.md").read_text()
    meta_ok=all(x in metadata for x in
        ("599問","2023年度問90","通常の学習に通信は不要","外部リンク","公式PDF","プライバシーポリシー"))
    q3read=IOS/"ASC_METADATA_Q3_READBACK_20261125.json"
    q3data=json.loads(q3read.read_text()) if q3read.is_file() else {}
    q3_asc=(q3data.get("status")=="PASS" and q3data.get("descriptionMentions599") is True
        and q3data.get("descriptionMentionsInvalidQ90") is True
        and q3data.get("descriptionDisclosesOffline") is True
        and q3data.get("descriptionLinksOfficialSources") is True
        and q3data.get("promotionalTextMentions599") is True)
    gate("Q3_METADATA_DISCLOSURE","PASS" if meta_ok and q3_asc else ("NOT_VERIFIED" if meta_ok else "FAIL"),
        f"local listing copy accurate={meta_ok}; live ASC readback={q3_asc}; readback={q3data.get('readAtJST','MISSING')}",
        ["touroku-hanbaisha-ios/APP_STORE_METADATA.md","touroku-hanbaisha-ios/ASC_METADATA_Q3_READBACK_20261125.json"])
    # Require both a native local-file package and a current simulator run that inspected the packaged assets.
    q4report=IOS/"OFFLINE_Q4_20261125.json"
    q4data=json.loads(q4report.read_text()) if q4report.is_file() else {}
    offline_static=("webView.loadFileURL(home, allowingReadAccessTo: root)" in swift
        and "path: OfflineWeb" in project and "connect-src \\'none\\'" in prepare
        and "offlineExplanations" in prepare and "explanationsCount" in prepare)
    offline_runtime=(q4data.get("status")=="PASS" and q4data.get("nativeSimulatorOfflineBundleVerified") is True
        and q4data.get("bankCount")==599 and q4data.get("explanationsCount")==599
        and q4data.get("externalRequests")==[] and q4data.get("pageErrors")==[])
    gate("Q4_OFFLINE_RESILIENCE","PASS" if offline_static and offline_runtime else "NOT_VERIFIED",
        f"native local bundle/static CSP={offline_static}; simulator packaged offline proof={offline_runtime}; report={q4data.get('githubRunId','MISSING')}",
        ["touroku-hanbaisha-ios/native-ios/Sources/TouhanSprintApp.swift","touroku-hanbaisha-ios/OFFLINE_Q4_20261125.json"])
    import plistlib
    privacyinfo=IOS/"native-ios/PrivacyInfo.xcprivacy"
    plist=plistlib.loads(privacyinfo.read_bytes())
    native_privacy=(plist.get("NSPrivacyTracking") is False
        and plist.get("NSPrivacyCollectedDataTypes")==[]
        and "WKWebsiteDataStore.nonPersistent()" in swift
        and "studyRecord" in swift and "UserDefaults" in swift)
    q5report=IOS/"Q5_CURRENT_20261125.json"
    q5data=json.loads(q5report.read_text()) if q5report.is_file() else {}
    q5_source=(q5data.get("sourceAndBrowserAudit")=="PASS"
        and q5data.get("privacyPolicyURLMatched") is True
        and q5data.get("observedExternalHosts")==[])
    q5_asc=(q5data.get("questionnaireVerified") is True
        and q5data.get("questionnaireDataTypesReconciled") is True)
    gate("Q5_NATIVE_PRIVACY_IMPLEMENTATION","PASS" if native_privacy else "FAIL",
        f"tracking=false; collectedDataTypes=0; nonPersistent WKWebView; app-only UserDefaults={native_privacy}",
        ["touroku-hanbaisha-ios/native-ios/PrivacyInfo.xcprivacy","touroku-hanbaisha-ios/native-ios/Sources/TouhanSprintApp.swift"])
    gate("Q5_PRIVACY_AND_NETWORK_DISCLOSURE","PASS" if q5_source and q5_asc else "NOT_VERIFIED",
        f"source/browser and policy URL={q5_source}; actual ASC App Privacy questionnaire reconciled={q5_asc}; unavailable through documented ASC API unless UI evidence is supplied",
        ["touroku-hanbaisha-ios/Q5_CURRENT_20261125.json"])
    q6file=IOS/"IOS_SIMULATOR_Q6_20261125.json"
    q6=json.loads(q6file.read_text()) if q6file.is_file() else {}
    q6ok=(q6.get("status")=="PASS" and q6.get("build")=="success" and q6.get("installAndLaunch")=="success"
        and q6.get("learningPersistence")=="PASS"
        and q6.get("headSHA")==os.getenv("GITHUB_SHA"))
    gate("Q6_IOS_BUILD_AND_LAUNCH","PASS" if q6ok else "NOT_VERIFIED",
        f"Xcode build/install/launch + progress persistence on this exact workflow HEAD={q6ok}; evidenceHead={q6.get('headSHA','MISSING')}; workflowHead={os.getenv('GITHUB_SHA','UNAVAILABLE')}; offline bundle is evaluated separately by Q4; run={q6.get('githubRunId','MISSING')}",
        ["touroku-hanbaisha-ios/IOS_SIMULATOR_Q6_20261125.json"])
    q7file=IOS/"Q7_TESTFLIGHT_READBACK_20261125.json"
    q7=json.loads(q7file.read_text()) if q7file.is_file() else {}
    q7ok=(q7.get("status")=="PASS" and q7.get("signedIpaVerified") is True
        and q7.get("ascProcessingState")=="VALID" and q7.get("testFlightAvailable") is True
        and q7.get("testFlightDistributed") is True)
    gate("Q7_TESTFLIGHT_READY","PASS" if q7ok else "BLOCKED",
        f"signed IPA and App Store Connect/TestFlight processing readback={q7ok}; state={q7.get('ascProcessingState','MISSING')}; no App Review submission",
        ["touroku-hanbaisha-ios/Q7_TESTFLIGHT_READBACK_20261125.json"])
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
