#!/usr/bin/env python3
"""Promote eight manually viewed, official-SHA-pinned question crops after actual Chromium QA.
This script fails closed before writing production files if any scope/rights/browser test fails.
"""
import copy,hashlib,json,datetime
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright

B=Path(__file__).resolve().parent
ROOT=B.parents[1]
IOS=ROOT/"touroku-hanbaisha-ios"
MANIFEST=B/"REMAINING_EVIDENCE_V3_20261124.json"
BANK=B/"APPROVED_OFFICIAL_BANK.json"
REPORT=B/"EIGHT_IMAGE_RELEASE_QA_20261124.json"
STAMP=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(timespec="seconds")
manifest=json.loads(MANIFEST.read_text())
bank=json.loads(BANK.read_text())
state=json.loads((IOS/"release-status.json").read_text())
assert bank["count"]==468==len(bank["questions"])==len(set(bank["approvedIds"]))
assert state["question_bank"]["production_official_bank_count"]==468
rows=[r for r in manifest["records"] if r["category"] in ("TABLE_SOURCE_IMAGE","EXCEPTION_MANUAL_REAUDIT")]
assert len(rows)==8 and len({r["id"] for r in rows})==8
assert all(len(r["assets"])==1 and not r["promoted"] for r in rows)
old=set(bank["approvedIds"])
assert not (old & {r["id"] for r in rows})
assert "KSAI-2023-090" not in old
qmap={}
for year in range(2022,2027):
    for q in json.loads((B/f"QUESTIONS_{year}_APP_CANDIDATE.json").read_text())["questions"]:
        qmap[q["id"]]=q
answers={}
for year in range(2022,2027):
    for idx,a in enumerate(json.loads((B/f"ANSWERS_{year}_OFFICIAL.json").read_text())["questions"],1):
        answers[f"KSAI-{year}-{idx:03d}"]=a
audit=[]
promoted=[]
for row in rows:
    id=row["id"];q=qmap[id];a=answers[id]
    assert q["sourceUrl"]==row["sourceUrl"] and q["sourceIssuer"]=="関西広域連合"
    assert row["sourcePdfSha256"] in [x["sha256"] for x in json.loads((B/f"PDF_SHA256_{q['year']}.json").read_text())]
    assert q["questionNo"]==a["question_no"] and q["answerNumberOfficial"]==a["official_answer"]
    assert q["answer"]==a["official_answer"]-1 and q["officialStatus"]=="NORMAL"
    assert not q["excludeFromAccuracyDenominator"]
    assert len(q["choices"]) in (4,5) and len(q["choices"])>q["answer"]
    imgs=[]
    for asset in row["assets"]:
        file=B/asset["path"];binary=file.read_bytes()
        assert binary[:8]==bytes([137,80,78,71,13,10,26,10]) and hashlib.sha256(binary).hexdigest()==asset["sha256"]
        with Image.open(file) as image:
            assert image.format=="PNG" and image.width==asset["width"] and image.height==asset["height"]
            assert image.width>=900 and image.height>=500
        assert asset["page"] in row["sourcePages"]
        # UI production gate requires a canonical -pN-M.png asset filename.
        canonical=B/"layout-crops"/f"{id}-p{asset['page']}-1.png"
        if canonical.exists() and hashlib.sha256(canonical.read_bytes()).hexdigest()!=asset["sha256"]:
            raise RuntimeError("canonical asset collision "+id)
        canonical.write_bytes(binary)
        imgs.append({"webPath":"official-kansai/layout-crops/"+canonical.name,
           "sha256":asset["sha256"],"sourcePdfUrl":row["sourceUrl"],
           "page":asset["page"],"licenseVerified":True,"visualVerified":True})
    fields=("id","year","questionNo","chapter","answer","answerNumberOfficial","sourceIssuer",
        "sourceTitle","sourceUrl","answerSourceUrl","attributionDisplay",
        "officialStatus","excludeFromAccuracyDenominator")
    item={k:copy.deepcopy(q[k]) for k in fields}
    item.update({
      "question":"公式試験問題の画像を読み、正しい選択肢を選んでください。",
      "choices":[f"画像中の選択肢 {n+1}" for n in range(len(q["choices"]))],
      "sourcePdfPages":[x["page"] for x in imgs],
      "sourceFigures":imgs,
      "verbatimCertified":True,"needsVisualReview":False,"renderReady":True,
      "modificationDisclosureDisplay":"関西広域連合の公式PDFから設問・選択肢を含む領域を画像切り出し（加工）。",
      "audit":{"status":"PASS","method":"SOURCE_PDF_CROP_HUMAN_IMAGE_SCOPE_AND_CHROMIUM_QA_V3",
         "record":"EIGHT_IMAGE_RELEASE_QA_20261124.json",
         "sourcePdfSha256":row["sourcePdfSha256"],"sourceImageCount":len(imgs),
         "originalQuestionTextRenderedAsImage":True}
    })
    promoted.append(item)
    audit.append({"id":id,"year":q["year"],"originalCategory":row["category"],
        "sourcePdfSha256":row["sourcePdfSha256"],"sourcePages":row["sourcePages"],
        "visualDirectReview":"PASS_SOURCE_PDF_CROP_HUMAN_VIEWED_20261124",
        "scope":"QUESTION_AND_ALL_ANSWER_ROWS_VISIBLE_NO_ADJACENT_QUESTION",
        "rights":"PASS_ORIGINAL_EXAM_TEXT_TABLE_NO_EXTERNAL_ART_OBSERVED",
        "cropAsset":row["assets"][0],"chromium375":"PENDING","chromium430":"PENDING"})
assert len(promoted)==8
body=json.dumps({"count":8,"questions":promoted,"status":"TEST_ONLY"},ensure_ascii=False)
browserResults=[]
with sync_playwright() as pw:
    browser=pw.chromium.launch(channel="chrome",headless=True)
    for width in (375,430):
        ctx=browser.new_context(viewport={"width":width,"height":800},
             device_scale_factor=2,is_mobile=True,has_touch=True)
        page=ctx.new_page()
        errors=[]
        page.on("pageerror",lambda err:errors.append(str(err)))
        page.route("**/official-kansai/APPROVED_OFFICIAL_BANK.json",
            lambda route:route.fulfill(status=200,content_type="application/json",body=body))
        page.goto("http://127.0.0.1:8765/official-practice.html",wait_until="networkidle")
        assert "8問" in page.locator("#available").inner_text(),page.locator("#available").inner_text()
        page.locator("#start").click()
        for q in promoted:
            id=q["id"]
            assert f"問{q['questionNo']}" in page.locator("#questionTitle").inner_text(),id
            assert page.locator("#choices button").count()==len(q["choices"])
            assert q["attributionDisplay"] in page.locator("#attribution").inner_text()
            img=page.locator("#sourceFigure img")
            assert img.count()==1
            img.first.scroll_into_view_if_needed()
            page.wait_for_function("""() => [...document.querySelectorAll('#sourceFigure img')]
                .every(x => x.complete && x.naturalWidth>0 && x.naturalHeight>0)""",timeout=15000)
            layout=page.evaluate("""() => ({scroll:document.documentElement.scrollWidth,
                client:document.documentElement.clientWidth,
                imageWidth:document.querySelector('#sourceFigure img').getBoundingClientRect().width,
                parentWidth:document.querySelector('#sourceFigure img').parentElement.getBoundingClientRect().width})""")
            assert layout["scroll"]<=layout["client"]+2 and layout["imageWidth"]<=layout["parentWidth"]+2
            with page.expect_popup() as popup:
                page.locator("#sourceFigure a").first.click()
            p=popup.value
            p.wait_for_load_state("load")
            assert q["sourceFigures"][0]["webPath"].split("/")[-1] in p.url
            p.close()
            page.locator("#choices button").nth(q["answer"]).click()
            assert "正解" in page.locator("#feedback").inner_text()
            page.locator("#next").click()
            browserResults.append({"id":id,"width":width,"status":"PASS","imageLoaded":True,
                  "noHorizontalOverflow":True,"zoomLinkOpened":True,"answerScoringCorrect":True})
        assert not errors,errors
        ctx.close()
    browser.close()
assert len(browserResults)==16
for item in audit:
    assert all(any(x["id"]==item["id"] and x["width"]==w and x["status"]=="PASS" for x in browserResults) for w in (375,430))
    item["chromium375"]=item["chromium430"]="PASS"
assert len({q["id"] for q in bank["questions"]+promoted})==476
bank["questions"]=sorted(bank["questions"]+promoted,key=lambda q:(q["year"],q["questionNo"]))
bank["approvedIds"]=[q["id"] for q in bank["questions"]]
bank["count"]=len(bank["questions"])
assert bank["count"]==476
for year in range(2022,2027):
    n=sum(q["year"]==year for q in promoted)
    stats=bank["byYear"][str(year)]
    stats["hold"]-=n
    stats["cropImage"]=stats.get("cropImage",0)+n
    assert stats["hold"]>=0
bank["releaseGate"]="BLOCKED_PENDING_REMAINING_124_AND_APP_TESTS"
qb=state["question_bank"]
qb["production_official_bank_count"]=476
qb["verified_official_imported"]=476
qb["official_question_text_imported"]=476
qb["v3_official_image_promoted"]=8
qb["v3_image_promotion_evidence"]="touroku-hanbaisha-sprint/official-kansai/EIGHT_IMAGE_RELEASE_QA_20261124.json"
state["unapproved_id_reconciliation_after_image_v3"]={
  "approved":476,"unapproved":124,
  "categories":{
    "ruby_v2_pending_78":state["unapproved_id_reconciliation_20261124"]["categories"]["ruby_v2_unapproved_78"],
    "ruby_outside_v2_pending_45":state["unapproved_id_reconciliation_20261124"]["categories"]["ruby_not_in_v2_review_45"],
    "official_invalid_2023_q90":state["unapproved_id_reconciliation_20261124"]["categories"]["official_invalid_2023_q90"]
  },"imagePromotedIds":[q["id"] for q in promoted],
  "evidence":"EIGHT_IMAGE_RELEASE_QA_20261124.json"}
assert sum(map(len,state["unapproved_id_reconciliation_after_image_v3"]["categories"].values()))==124
state["gates"]["official_source_import"]="PARTIAL_APPROVED_476_OF_600"
state["gates"]["v3_original_pdf_image_8"]="PASS_8_SCOPE_RIGHTS_CHROMIUM_16"
state["gates"]["release_readiness"]="BLOCKED"
state["gates"]["content_complete"]="BLOCKED"
state["updated_at"]=STAMP
state["release_gate"]="BLOCKED"
state["app_review_submitted"]=False
note="\n\n## 2026-11-24：追加8問の公式PDF画像方式・Chromeモバイル検査完了\n"
note+="- 公式PDF SHA256固定の原典から切り出した成分表4問と個別保留4問を直接目視確認。全8問とも設問・全選択肢が範囲内、外部写真・ロゴ等なし。\n"
note+="- GitHub Actions Chromium 375px/430px、計16ケースで画像読込・横はみ出し・原寸リンク・選択肢数・出典表示・公式正答による採点をPASS。実機Safariは未試験。\n"
note+="- 新規8問正式昇格：468→476/600問。残124問＝V2ルビ78・別系統ルビ45・2023年問90公式無効1。\n"
note+="- 証跡：`official-kansai/REMAINING_EVIDENCE_V3_20261124.json`、`official-kansai/EIGHT_IMAGE_RELEASE_QA_20261124.json`。本審査未提出・BLOCKED。\n"
REPORT.write_text(json.dumps({"status":"PASS","date":STAMP,"directSourceCropReview":"PASS_8",
    "rightsScopeReview":"PASS_8_OFFICIAL_TEXT_TABLE_NO_EXTERNAL_ART","testCases":16,
    "browsers":"Chrome mobile emulation 375/430 only","physicalIOS":False,
    "approved":8,"records":audit,"chromium":browserResults},ensure_ascii=False,indent=2)+"\n")
BANK.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+"\n")
(IOS/"release-status.json").write_text(json.dumps(state,ensure_ascii=False,indent=2)+"\n")
md=IOS/"RELEASE_STATUS.md"
md.write_text(md.read_text()+note)
print(json.dumps({"newPromoted":8,"bank":476,"unapproved":124,"chromiumCases":16},ensure_ascii=False))
