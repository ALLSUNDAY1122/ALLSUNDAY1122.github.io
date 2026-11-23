#!/usr/bin/env python3
"""Strict source-geometry / browser-DOM automated ruby certification, fail closed."""
import collections,datetime,hashlib,html,json,re
from pathlib import Path
from playwright.sync_api import sync_playwright
from auto_diff_pdf import B,download
from geometry_second_gate import first_question_clip
from ruby_font_cluster_recovery import rawglyphs,clusters,certify
from rebuild_ruby_comparison_120 import field_parts,make_preview,source_glyph_candidates
IOS=B.parents[1]/"touroku-hanbaisha-ios"
OUT=B/"RUBY_113_AUTO_REBUILD_20261124.json"
BANK=B/"APPROVED_OFFICIAL_BANK.json"
STATE=IOS/"release-status.json"
TRIAGE=B/"RUBY_113_INDEPENDENT_TRIAGE_20261124.json"
def load(p): return json.loads(p.read_text())
def certify_unique_raw(q,doc,clips):
    """Raw PDF-only fallback, rejects all nonunique groups and source coordinates."""
    glyphs=rawglyphs(doc,clips)
    groups=clusters(glyphs)
    if not groups:return None,["RAW_GROUPS_MISSING"],groups
    fields=[q["question"],*q["choices"]]
    mappings=[]
    for group in groups:
        reading=group["reading"]
        options=[]
        for score,glyph in source_glyph_candidates(group,glyphs):
            base=glyph["c"]
            if not re.fullmatch(r'[\u3400-\u9fff々]',base):continue
            rx0,ry0,rx1,ry1=group["bbox"];x0,y0,x1,y1=glyph["bbox"]
            overlap=max(0,min(rx1,x1)-max(rx0,x0))
            if overlap<min(rx1-rx0,x1-x0)*0.4 or not -3<=y0-ry1<=12:continue
            for fi,field in enumerate(fields):
                if len(list(re.finditer(r'(?m)^[ \t]*'+re.escape(reading)+r'[ \t]*$',field)))!=1:continue
                if field.count(base)!=1:continue
                options.append((fi,base,glyph))
        unique={(fi,base,tuple(round(v,1) for v in glyph["bbox"])):(fi,base,glyph)
                for fi,base,glyph in options}
        if len(unique)!=1:return None,["RAW_BASE_OR_FIELD_AMBIGUOUS"],groups
        fi,base,glyph=next(iter(unique.values()))
        if any(x["fieldIndex"]==fi and x["reading"]==reading for x in mappings):
            return None,["RAW_READING_DUPLICATE"],groups
        mappings.append({"fieldIndex":fi,"base":base,"reading":reading,"page":group["page"],
          "glyphBBox":glyph["bbox"],"rubyBBox":group["bbox"]})
    parts=[]
    for fi,field in enumerate(fields):
        these=[m for m in mappings if m["fieldIndex"]==fi]
        if not these:parts.append([{"text":field}]);continue
        parsed,why=field_parts(field,these)
        if why:return None,["RAW_"+why],groups
        parts.append(parsed)
    if sum("rubyBase" in p for field in parts for p in field)!=len(groups):
        return None,["RAW_DOM_COUNT_MISMATCH"],groups
    placements=[{"field":m["fieldIndex"],"base":m["base"],"reading":m["reading"],
       "page":m["page"],"baseBBox":m["glyphBBox"],"rubyBBox":m["rubyBBox"]} for m in mappings]
    return {"questionParts":parts[0],"choicesParts":parts[1:],"placements":placements},[],groups

def main():
    bank=load(BANK);st=load(STATE);triage=load(TRIAGE)
    assert len(triage["records"])==113
    assert bank["count"]==st["question_bank"]["production_official_bank_count"]
    assert len(bank["approvedIds"])==len(set(bank["approvedIds"]))==bank["count"]
    ids={r["id"] for r in triage["records"]}
    previous_approved=ids.intersection(bank["approvedIds"])
    assert len(ids)==113 and bank["count"]==486+len(previous_approved)
    starting_bank_count=bank["count"]
    sources={x["year"]:x for x in load(B/"SOURCES_2022_2026.json")["years"]}
    docs={};questions={};geos={};diffs={};answers={};pdfsha={}
    for year in range(2022,2027):
        pdfsha[year]={x["half"]:x["sha256"] for x in load(B/f"PDF_SHA256_{year}.json")}
        docs[year]={}
        for half,key in [("first_half","question_pdf_first_half"),("second_half","question_pdf_second_half")]:
            docs[year][half]=download(sources[year][key], B/f".tmp_auto113_{year}_{half}.pdf",pdfsha[year][half])
        questions[year]=load(B/f"QUESTIONS_{year}_APP_CANDIDATE.json")["questions"]
        geos[year]=load(B/f"GEOMETRY_AUDIT_{year}.json")["questions"]
        diffs[year]=load(B/f"AUTO_DIFF_{year}.json")["questions"]
        answers[year]=load(B/f"ANSWERS_{year}_OFFICIAL.json")["questions"]
    evidence=[];new=[];outdir=B/"ruby-auto-113";outdir.mkdir(exist_ok=True)
    browser_results=[]
    with sync_playwright() as pw:
        browser=pw.chromium.launch(channel="chrome",headless=True)
        context=browser.new_context(viewport={"width":375,"height":850},device_scale_factor=2)
        page=context.new_page()
        for source in triage["records"]:
            id=source["id"]
            if id in previous_approved:
                evidence.append({"id":id,"status":"ALREADY_APPROVED","reasons":[],
                  "existingBank":True,"sourceImage":source["sourceImage"],"previousCandidate":source["candidateImage"]})
                continue
            y=int(id[5:9]);n=int(id[-3:]);q=questions[y][n-1];geo=geos[y][n-1];d=diffs[y][n-1];a=answers[y][n-1]
            row={"id":id,"originalIssues":source["issues"],"sourceImage":source["sourceImage"],
                 "previousCandidate":source["candidateImage"],"status":"HOLD","reasons":[]}
            assert q["id"]==geo["id"]==d["id"]==id
            half="first_half" if n<=60 else "second_half";doc=docs[y][half]
            clip=first_question_clip(doc,None,q)
            if not clip:row["reasons"].append("SOURCE_REGION_UNAVAILABLE")
            else:
                rich,reasons,groups=certify(q,geo,doc,clip)
                if not rich:
                    fresh,fresh_reasons,fresh_groups=certify_unique_raw(q,doc,clip)
                    if fresh:
                        rich,reasons,groups=fresh,[],fresh_groups
                        row["sourceMappingMode"]="RAW_GLYPH_FIELD_UNIQUE"
                    else:
                        row["rawFallbackIssues"]=fresh_reasons
                if reasons:row["reasons"]+=reasons
                if not rich:row["reasons"].append("RUBY_MAPPING_UNCERTIFIED")
                elif len(rich["placements"])!=len(groups) or not groups:
                    row["reasons"].append("SOURCE_RUBY_GROUP_COUNT_MISMATCH")
                else:
                    placements=rich["placements"]
                    for p in placements:
                        bx=p["baseBBox"];rx=p["rubyBBox"]
                        center_base=(bx[0]+bx[2])/2;center_rt=(rx[0]+rx[2])/2
                        if abs(center_base-center_rt)>max(4.0,(bx[2]-bx[0])*.36):
                            row["reasons"].append("SOURCE_PDF_HORIZONTAL_CENTER_MISMATCH")
                        if not (-4<=bx[1]-rx[3]<=16):
                            row["reasons"].append("SOURCE_PDF_VERTICAL_POSITION_MISMATCH")
                    if not row["reasons"]:
                        mappings=[{"fieldIndex":p["field"],"base":p["base"],"reading":p["reading"],"page":p["page"]} for p in placements]
                        preview,parts,count=make_preview({"id":id},q,mappings,[])
                        if count!=len(groups):
                            row["reasons"].append("RUBY_DOM_COUNT_MISMATCH")
                        else:
                            file=outdir/(id+"-candidate-auto.html");file.write_text(preview)
                            page.goto(file.resolve().as_uri(),wait_until="load")
                            page.evaluate("document.fonts.ready")
                            measured=page.evaluate("""() => ({font:document.fonts.check('16px "Noto Sans CJK JP"'),
                              rubies:[...document.querySelectorAll('ruby')].map(x=>{
                                let r=x.querySelector('rt'), b=x.getBoundingClientRect(), t=r.getBoundingClientRect();
                                return {base:x.firstChild.textContent,reading:r.textContent,
                                  horizontalDelta:Math.abs((t.left+t.right-b.left-b.right)/2),
                                  above:t.top<=b.top+10}}),
                              scroll:document.documentElement.scrollWidth,
                              width:document.documentElement.clientWidth})""")
                            expected=[{"base":p["base"],"reading":p["reading"]} for p in placements]
                            observed=[{"base":p["base"],"reading":p["reading"]} for p in measured["rubies"]]
                            if not measured["font"]:row["reasons"].append("JAPANESE_FONT_MISSING")
                            if observed!=expected:row["reasons"].append("DOM_RUBY_ORDER_OR_TEXT_MISMATCH")
                            if measured["scroll"]>measured["width"]+2:row["reasons"].append("MOBILE_HORIZONTAL_OVERFLOW")
                            if any(x["horizontalDelta"]>8 or not x["above"] for x in measured["rubies"]):
                                row["reasons"].append("RENDERED_RUBY_POSITION_MISMATCH")
                            shot=outdir/(id+"-candidate-auto.png")
                            page.screenshot(path=str(shot),full_page=True)
                            row["renderedScreenshot"]=str(shot.relative_to(B))
                            row["domGeometry"]=measured
                            if not shot.is_file() or shot.stat().st_size<3000:
                                row["reasons"].append("SCREENSHOT_UNAVAILABLE")
                            if not row["reasons"]:
                                valid=(q["answerNumberOfficial"]==a["official_answer"]
                                  and q["answer"]==a["official_answer"]-1
                                  and q["officialStatus"]=="NORMAL"
                                  and not q["excludeFromAccuracyDenominator"])
                                if not valid:row["reasons"].append("OFFICIAL_ANSWER_MISMATCH")
                                if d["sourceNormalizedSha256"]!=d["candidateNormalizedSha256"] or not d["sourceNormalizedSha256"]:
                                    row["reasons"].append("PDF_TEXT_HASH_MISMATCH")
                                if set(d["reasons"])-{"RUBY_POSITION_REVIEW","ANSWER_TABLE_REVIEW"}:
                                    row["reasons"].append("OTHER_SOURCE_DIFF")
                                if "ANSWER_TABLE_REVIEW" in d["reasons"] and geo["table"]["status"]!="PASS":
                                    row["reasons"].append("TABLE_NOT_CERTIFIED")
                                if set(geo["reasons"])-{"RUBY_RENDER_NOT_CERTIFIED","RUBY_XY_ASSOCIATION_INCONCLUSIVE"}:
                                    row["reasons"].append("OTHER_GEOMETRY_HOLD")
                                if not row["reasons"]:
                                    fields=("id","year","questionNo","chapter","answer","answerNumberOfficial",
                                      "sourceIssuer","sourceTitle","sourceUrl","answerSourceUrl","attributionDisplay",
                                      "officialStatus","excludeFromAccuracyDenominator","sourcePdfPages")
                                    item={k:q[k] for k in fields}
                                    item.update(questionParts=rich["questionParts"],choicesParts=rich["choicesParts"],
                                      question="".join(p.get("text",p.get("rubyBase","")) for p in rich["questionParts"]),
                                      choices=["".join(p.get("text",p.get("rubyBase","")) for p in field) for field in rich["choicesParts"]],
                                      verbatimCertified=True,needsVisualReview=False,renderReady=True,
                                      modificationDisclosureDisplay="公式PDFのルビの位置とHTML ruby/rtを自動照合して再配置（加工）",
                                      audit={"status":"PASS","method":"PDF_RAWDICT_GEOMETRY_AND_CHROMIUM_DOM_AUTO_V1",
                                        "record":OUT.name,"sourcePdfSha256":pdfsha[y][half],
                                        "normalizedOriginalSha256":d["sourceNormalizedSha256"],
                                        "rubyCount":len(placements),"candidateScreenshot":row["renderedScreenshot"]})
                                    new.append(item)
                                    row.update(status="AUTO_PASS",sourcePdfSha256=pdfsha[y][half],
                                        sourceGlyphMappings=placements)
                                    browser_results.append(id)
            row["reasons"]=sorted(set(row["reasons"]))
            if row["status"]=="HOLD" and not row["reasons"]:row["reasons"]=["UNKNOWN_UNRESOLVED"]
            evidence.append(row)
        context.close();browser.close()
    for year_docs in docs.values():
        for doc in year_docs.values():doc.close()
    assert len(evidence)==113 and len({r["id"] for r in evidence})==113
    assert sum(r["status"]=="AUTO_PASS" for r in evidence)==len(new)
    assert sum(r["status"]=="ALREADY_APPROVED" for r in evidence)==len(previous_approved)
    assert all(q["id"] in ids for q in new)
    reasons=collections.Counter(k for r in evidence if r["status"]=="HOLD" for k in r["reasons"])
    timestamp=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(timespec="seconds")
    new_hold_count=113-len(new)-len(previous_approved)
    result={"schema":"touhan-ruby-113-automatic-v2","generatedAt":timestamp,"baseline":starting_bank_count,
      "processed":113,"previouslyApproved":len(previous_approved),"autoPassed":len(new),
      "cumulativeAutoPassed":len(previous_approved)+len(new),"held":new_hold_count,
      "reasonCountsNonExclusive":dict(reasons),
      "limitations":"Source PDF coordinates, browser DOM, official answers and normalized text hashes checked. No human visual certification or iOS Safari hardware test.",
      "records":evidence}
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    if new:
        bank["questions"]=sorted(bank["questions"]+new,key=lambda q:(q["year"],q["questionNo"]))
        bank["approvedIds"]=[q["id"] for q in bank["questions"]]
        bank["count"]=len(bank["questions"])
        assert bank["count"]==starting_bank_count+len(new)==len(set(bank["approvedIds"]))
        for y in range(2022,2027):
            qty=sum(q["year"]==y for q in new)
            bank["byYear"][str(y)]["hold"]-=qty
            bank["byYear"][str(y)]["rubyAuto113"]=bank["byYear"][str(y)].get("rubyAuto113",0)+qty
    bank["releaseGate"]="BLOCKED_PENDING_APP_TESTS_AND_UNRESOLVED"
    st["question_bank"].update(production_official_bank_count=bank["count"],
      verified_official_imported=bank["count"],official_question_text_imported=bank["count"])
    st["ruby_113_auto_rebuild_20261124"]={"evidence":str(OUT.relative_to(B.parents[1])),
      "processed":113,"previouslyApproved":len(previous_approved),"autoPassed":len(new),
      "cumulativeAutoPassed":len(previous_approved)+len(new),"hold":new_hold_count,
      "holdReasonsNonExclusive":dict(reasons),"newBankCount":bank["count"],
      "remainingIncludingInvalid":600-bank["count"],"autoVerifiedNotHumanVisual":True}
    st["updated_at"]=timestamp
    st["release_gate"]="BLOCKED";st["app_review_submitted"]=False
    st["gates"]["official_source_import"]=f"PARTIAL_APPROVED_{bank['count']}_OF_600"
    st["gates"]["release_readiness"]="BLOCKED"
    st["gates"]["content_complete"]="BLOCKED"
    BANK.write_text(json.dumps(bank,ensure_ascii=False,indent=2)+"\n")
    STATE.write_text(json.dumps(st,ensure_ascii=False,indent=2)+"\n")
    md=IOS/"RELEASE_STATUS.md"
    md.write_text(md.read_text()+f"\n\n## 2026-11-24 自動ルビ再生成・座標/ブラウザ検査\n- 対象113問、PDF rawdict再抽出・サイズ/座標・Noto CJKブラウザDOM再描画照合。\n- 今回自動PASS {len(new)}、累計自動PASS {len(previous_approved)+len(new)}、HOLD {new_hold_count}、正式バンク {bank['count']}/600。目視PASSではなく自動検査PASS。\n- 保留理由（重複あり）: {json.dumps(dict(reasons),ensure_ascii=False)}。\n- 証跡: `official-kansai/{OUT.name}`。Apple実機未確認・本審査未送信・リリースBLOCKED。\n")
    print(json.dumps({"autoPassed":len(new),"previouslyApproved":len(previous_approved),"hold":new_hold_count,"bank":bank["count"],"reasons":dict(reasons)},ensure_ascii=False))
if __name__=="__main__": main()

# Actions rerun trigger: 2026-11-24; preserve fail-closed auto-promotion gates.

# Trigger verification after native multi-kanji ruby support; fail closed remains enabled.
