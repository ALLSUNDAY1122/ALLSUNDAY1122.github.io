#!/usr/bin/env python3
"""Review-gated promotion of ten directly viewed safe ruby reconstructions, 375/430px browser QA.
No promotion of any other unreviewed candidate.
"""
import datetime,hashlib,json
from pathlib import Path
from playwright.sync_api import sync_playwright
from rebuild_ruby_comparison_120 import field_parts

B=Path(__file__).resolve().parent
ROOT=B.parents[1]
IOS=ROOT/"touroku-hanbaisha-ios"
BANK=B/"APPROVED_OFFICIAL_BANK.json"
ST=IOS/"release-status.json"
OUT=B/"TEN_RUBY_DIRECT_REVIEW_QA_20261124.json"
IDS=["KSAI-2022-008","KSAI-2022-010","KSAI-2022-011","KSAI-2022-029",
"KSAI-2023-051","KSAI-2023-059","KSAI-2023-064","KSAI-2024-060",
"KSAI-2025-047","KSAI-2026-034"]
assert len(set(IDS))==10
bank=json.loads(BANK.read_text())
status=json.loads(ST.read_text())
source=json.loads((B/"REMAINING_EVIDENCE_V3_20261124.json").read_text())
refs={r["id"]:r for r in source["records"] if r["category"]=="RUBY_COMPARISON_NEW"}
assert bank["count"]==status["question_bank"]["production_official_bank_count"]==476
assert len(bank["questions"])==len(set(bank["approvedIds"]))==476
assert all(id not in bank["approvedIds"] for id in IDS)
assert all(id in status["unapproved_id_reconciliation_after_image_v3"]["categories"]["ruby_outside_v2_pending_45"] for id in IDS)
candidates={};answers={};diff={};geometry={}
for y in range(2022,2027):
    candidates[y]=json.loads((B/f"QUESTIONS_{y}_APP_CANDIDATE.json").read_text())["questions"]
    answers[y]=json.loads((B/f"ANSWERS_{y}_OFFICIAL.json").read_text())["questions"]
    diff[y]=json.loads((B/f"AUTO_DIFF_{y}.json").read_text())["questions"]
    geometry[y]=json.loads((B/f"GEOMETRY_AUDIT_{y}.json").read_text())["questions"]
new=[]
evidence=[]
for id in IDS:
    y=int(id[5:9]);n=int(id[-3:])
    q=candidates[y][n-1];a=answers[y][n-1];d=diff[y][n-1];g=geometry[y][n-1]
    r=refs[id]
    assert q["id"]==id==r["id"]==d["id"]==g["id"]
    assert not r["issues"] and r["fontValidated"] and r["rubyDomExpected"]==len(r["rubyMappings"])==r["sourceRubyGroups"]
    assert r["rubyDomExpected"]>0
    assert q["answerNumberOfficial"]==a["official_answer"] and q["answer"]==a["official_answer"]-1
    assert q["officialStatus"]=="NORMAL" and not q["excludeFromAccuracyDenominator"]
    assert q["sourceIssuer"]=="関西広域連合" and q["sourceUrl"]==r["sourceUrl"]
    assert d["candidateNormalizedSha256"]==d["sourceNormalizedSha256"] and d["sourceNormalizedSha256"]
    assert set(d["reasons"]).issubset({"RUBY_POSITION_REVIEW","ANSWER_TABLE_REVIEW"})
    assert set(g["reasons"]).issubset({"RUBY_RENDER_NOT_CERTIFIED","RUBY_XY_ASSOCIATION_INCONCLUSIVE"})
    if "ANSWER_TABLE_REVIEW" in d["reasons"]:assert g["table"]["status"]=="PASS"
    for k in ("sourceImage","candidateScreenshot","comparisonHtml"):
        assert (B/r[k]).is_file(),(id,k)
    assert (B/r["sourceImage"]).read_bytes()[:8]==bytes([137,80,78,71,13,10,26,10])
    assert (B/r["candidateScreenshot"]).read_bytes()[:8]==bytes([137,80,78,71,13,10,26,10])
    parts=[]
    for fi,text in enumerate([q["question"],*q["choices"]]):
        mappings=[x for x in r["rubyMappings"] if x["fieldIndex"]==fi]
        if mappings:
            p,reason=field_parts(text,mappings)
            assert reason is None and p is not None,(id,reason)
        else:p=[{"text":text}]
        parts.append(p)
    renderedCount=sum("rubyBase" in z for part in parts for z in part)
    assert renderedCount==r["rubyDomExpected"]
    fields=("id","year","questionNo","chapter","answer","answerNumberOfficial","sourceIssuer",
    "sourceTitle","sourceUrl","answerSourceUrl","attributionDisplay","officialStatus",
    "excludeFromAccuracyDenominator","sourcePdfPages")
    item={k:q[k] for k in fields}
    item.update({
       "questionParts":parts[0],"choicesParts":parts[1:],
       "question":"".join(v.get("text",v.get("rubyBase","")) for v in parts[0]),
       "choices":["".join(v.get("text",v.get("rubyBase","")) for v in part) for part in parts[1:]],
       "verbatimCertified":True,"needsVisualReview":False,"renderReady":True,
       "modificationDisclosureDisplay":"原典PDFのルビをNoto日本語フォント画面と照合のうえHTML ruby/rtへ再配置（加工）",
       "audit":{"status":"PASS","method":"DIRECT_SOURCE_IMAGE_AND_CHROME_RUBY_V3",
         "record":"TEN_RUBY_DIRECT_REVIEW_QA_20261124.json",
         "sourcePdfSha256":r["sourcePdfSha256"],"normalizedOriginalSha256":d["sourceNormalizedSha256"],
         "rubyCount":renderedCount,"sourceImage":r["sourceImage"],
         "candidateScreenshot":r["candidateScreenshot"]}
    })
    new.append(item)
    evidence.append({"id":id,"source":r["sourceImage"],"candidate":r["candidateScreenshot"],
       "humanDirectlyReviewed":"PASS_SOURCE_GLYPH_AND_RUBY_POSITION_VISUAL",
       "sourcePdfSha256":r["sourcePdfSha256"],"rubyMappings":r["rubyMappings"],
       "originalNormalizedSHA":d["sourceNormalizedSha256"],"chromium375":"PENDING","chromium430":"PENDING"})
assert len(new)==10
testBody=json.dumps({"count":10,"status":"TEST_ONLY","questions":new},ensure_ascii=False)
results=[]
with sync_playwright() as pw:
    browser=pw.chromium.launch(channel="chrome",headless=True)
    for width in (375,430):
        ctx=browser.new_context(viewport={"width":width,"height":800},device_scale_factor=2,is_mobile=True,has_touch=True)
        page=ctx.new_page()
        errors=[]
        page.on("pageerror",lambda e:errors.append(str(e)))
        page.route("**/official-kansai/APPROVED_OFFICIAL_BANK.json",lambda route:route.fulfill(
            status=200,content_type="application/json",body=testBody))
        page.goto("http://127.0.0.1:8765/official-practice.html",wait_until="networkidle")
        assert "10問" in page.locator("#available").inner_text(),page.locator("#available").inner_text()
        page.locator("#start").click()
        for item in new:
            id=item["id"]
            assert f"問{item['questionNo']}" in page.locator("#questionTitle").inner_text()
            assert page.locator("#attribution").inner_text().find(item["attributionDisplay"])>=0
            assert page.locator("#choices button").count()==len(item["choices"])
            js=page.evaluate("""() => ({
                rubies:[...document.querySelectorAll('ruby')].map(x=>({base:x.firstChild.textContent,reading:x.querySelector('rt').textContent})),
                scroll:document.documentElement.scrollWidth,client:document.documentElement.clientWidth})""")
            expected=[{"base":v["rubyBase"],"reading":v["rubyText"]}
                for parts in [item["questionParts"],*item["choicesParts"]] for v in parts if "rubyBase" in v]
            assert js["rubies"]==expected,(id,js,expected)
            assert js["scroll"]<=js["client"]+2,(id,width)
            page.locator("#choices button").nth(item["answer"]).click()
            assert "正解" in page.locator("#feedback").inner_text(),(id,width)
            page.locator("#next").click()
            results.append({"id":id,"width":width,"status":"PASS","rubyCount":len(expected),"scoreVerified":True})
        assert not errors,errors
        ctx.close()
    browser.close()
assert len(results)==20 and all(x["status"]=="PASS" for x in results)
for r in evidence:
    assert all(any(x["id"]==r["id"] and x["width"]==w for x in results) for w in (375,430))
    r["chromium375"]=r["chromium430"]="PASS"
bank["questions"]=sorted(bank["questions"]+new,key=lambda q:(q["year"],q["questionNo"]))
bank["approvedIds"]=[r["id"] for r in bank["questions"]]
bank["count"]=len(bank["questions"])
assert bank["count"]==486==len(set(bank["approvedIds"]))
assert "KSAI-2023-090" not in bank["approvedIds"]
for y in range(2022,2027):
    n=sum(q["year"]==y for q in new)
    st=bank["byYear"][str(y)]
    st["hold"]-=n
    st["rubyVisualV3"]=st.get("rubyVisualV3",0)+n
    assert st["hold"]>=0
bank["releaseGate"]="BLOCKED_PENDING_REMAINING_114_AND_APP_TESTS"
qb=status["question_bank"]
qb.update({"production_official_bank_count":486,"verified_official_imported":486,
  "official_question_text_imported":486,
  "v3_ruby_visually_promoted":10,
  "v3_ruby_evidence":"touroku-hanbaisha-sprint/official-kansai/TEN_RUBY_DIRECT_REVIEW_QA_20261124.json"})
oldlist=status["unapproved_id_reconciliation_after_image_v3"]["categories"]["ruby_outside_v2_pending_45"]
left=[id for id in oldlist if id not in IDS]
assert len(left)==35
status["unapproved_id_reconciliation_after_ruby_v3"]={
    "approved":486,"unapproved":114,
    "categories":{"ruby_v2_pending_78":status["unapproved_id_reconciliation_after_image_v3"]["categories"]["ruby_v2_pending_78"],
    "ruby_outside_v2_pending_35":left,
    "official_invalid_2023_q90":["KSAI-2023-090"]},
    "rubyPromotedIds":IDS,"audit":"TEN_RUBY_DIRECT_REVIEW_QA_20261124.json"}
assert sum(len(x) for x in status["unapproved_id_reconciliation_after_ruby_v3"]["categories"].values())==114
status["updated_at"]=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(timespec="seconds")
status["gates"].update({"official_source_import":"PARTIAL_APPROVED_486_OF_600",
"v3_ruby_visual_10":"PASS_DIRECT_IMAGE_10_CHROMIUM_20",
"release_readiness":"BLOCKED","content_complete":"BLOCKED"})
status["release_gate"]="BLOCKED"
status["app_review_submitted"]=False
OUT.write_text(json.dumps({"status":"PASS","timestamp":status["updated_at"],
 "directlyViewedImages":10,"promoted":10,"browserCases":20,"physicalIOS":False,
 "records":evidence,"browserResults":results},ensure_ascii=False,indent=2)+"\n")
BANK.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+"\n")
ST.write_text(json.dumps(status,ensure_ascii=False,indent=2)+"\n")
md=IOS/"RELEASE_STATUS.md"
md.write_text(md.read_text()+"""
\n## 2026-11-24：比較対象外45問からルビ10問の直接目視PASS・昇格
- PDF原図と修復後375px Noto日本語フォント画面を10問それぞれ直接目視し、読みの文字・位置をPASS。原典PDFのSHA・normalized text hash・公式正答索引・既存重複もチェック。
- GitHub Actions Chromium 375px/430px各10件、合計20件でruby/rt DOM読みによる対応、出典、画面幅、選択肢と採点をPASS。iOS実機ではない。
- 新規昇格10問：正式バンク476→486/600。未収録114問＝旧V2ルビ78＋今回の追加比較の残35＋公式無効1。
- 監査：`official-kansai/REMAINING_EVIDENCE_V3_20261124.json`、`official-kansai/TEN_RUBY_DIRECT_REVIEW_QA_20261124.json`。全体ゲートBLOCKED、本審査未送信。
""")
print(json.dumps({"promoted":10,"bank":486,"remaining":114,"browserCases":20},ensure_ascii=False))
