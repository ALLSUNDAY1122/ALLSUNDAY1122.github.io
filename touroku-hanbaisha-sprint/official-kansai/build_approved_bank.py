#!/usr/bin/env python3
"""Official release bank: reviewed visual PASS plus strict normalized official-PDF AUTO_PASS.
Never silently promote a known HOLD or a diff tied to stale Git blobs.
"""
import hashlib,json
from pathlib import Path
B=Path(__file__).resolve().parent
manual=json.loads((B/"MANUAL_VISUAL_AUDIT_20261123.json").read_text())
reviews={r["id"]:r for r in manual["reviewedQuestions"]}
frozen=manual.get("auditSourceFrozenGitBlobs",{})
def blob(path):
    contents=path.read_bytes()
    return hashlib.sha1(f"blob {len(contents)}\0".encode()+contents).hexdigest()
accepted={}
status_by_year={}
for year in range(2022,2027):
    candidate_path=B/f"QUESTIONS_{year}_APP_CANDIDATE.json"
    answer_path=B/f"ANSWERS_{year}_OFFICIAL.json"
    candidates=json.loads(candidate_path.read_text())["questions"]
    answers=json.loads(answer_path.read_text())["questions"]
    expected_candidate_sha=blob(candidate_path)
    expected_answers_sha=blob(answer_path)
    if len(candidates)!=120 or len(answers)!=120:raise RuntimeError("incorrect lengths")
    report_file=B/f"AUTO_DIFF_{year}.json"
    report=json.loads(report_file.read_text()) if report_file.exists() else None
    if report is not None:
        if report["year"]!=year or report["total"]!=120 or len(report["questions"])!=120:
            raise RuntimeError(f"invalid auto report for {year}")
        if report["candidateGitBlob"]!=expected_candidate_sha or report["answerIndexGitBlob"]!=expected_answers_sha:
            raise RuntimeError(f"stale auto diff for {year}")
        if len({r["id"] for r in report["questions"]})!=120:
            raise RuntimeError(f"duplicate IDs {year}")
        byid={r["id"]:r for r in report["questions"]}
    else:byid={}
    geom_file=B/f"GEOMETRY_AUDIT_{year}.json"
    geom=json.loads(geom_file.read_text()) if geom_file.exists() else None
    geom_byid={}
    cross_file=B/f"CROSSCHECK_{year}.json"
    cross=json.loads(cross_file.read_text()) if cross_file.exists() else None
    disputed=set()
    if cross:
        if cross["year"]!=year or cross["samples"]!=10:raise RuntimeError("invalid cross engine evidence")
        disputed={x["id"] for x in cross["results"] if x["status"]=="REVIEW_EXTRACTOR_DISAGREEMENT"}
    if geom:
        if geom["year"]!=year or geom["total"]!=120 or len(geom["questions"])!=120:
            raise RuntimeError("invalid geometry audit for "+str(year))
        if not report or geom["priorAuditCandidateGitBlob"]!=expected_candidate_sha:
            raise RuntimeError("stale geometry audit for "+str(year))
        geom_byid={item["id"]:item for item in geom["questions"]}
        if len(geom_byid)!=120:raise RuntimeError("missing geometry records")
    ruby_file=B/f"RUBY_RECON_{year}.json"
    ruby_report=json.loads(ruby_file.read_text()) if ruby_file.exists() else None
    ruby_byid={}
    if ruby_report:
        if ruby_report["year"]!=year or ruby_report["total"]!=120 or ruby_report["candidateGitBlob"]!=expected_candidate_sha or len(ruby_report["records"])!=120:
            raise RuntimeError("invalid or stale ruby reconstruction for "+str(year))
        ruby_byid={r["id"]:r for r in ruby_report["records"]}
        if len(ruby_byid)!=120:raise RuntimeError("duplicate ruby IDs")
    ordered_file=B/f"ORDERED_RUBY_{year}.json"
    ordered=json.loads(ordered_file.read_text()) if ordered_file.exists() else None
    ordered_byid={}
    if ordered:
        if ordered["year"]!=year or ordered["total"]!=120 or ordered["candidateGitBlob"]!=expected_candidate_sha or len(ordered["records"])!=120:
            raise RuntimeError("invalid/stale ordered ruby report")
        ordered_byid={r["id"]:r for r in ordered["records"]}
        if len(ordered_byid)!=120:raise RuntimeError("duplicate ordered ruby IDs")
    layout_file=B/f"LAYOUT_TRIAGE_{year}.json"
    layout=json.loads(layout_file.read_text()) if layout_file.exists() else None
    layout_byid={}
    if layout:
        if layout["year"]!=year or layout["total"]!=120 or layout["candidateGitBlob"]!=expected_candidate_sha or len(layout["records"])!=120:
            raise RuntimeError("invalid or stale figure/structure triage for "+str(year))
        layout_byid={r["id"]:r for r in layout["records"]}
        if len(layout_byid)!=120:raise RuntimeError("duplicate layout IDs")
    stats={"auto":0,"geometry":0,"ruby":0,"rubyOrdered":0,"layout":0,"visual":0,"crossEngineHold":0,"hold":0,"pending":0}
    for idx,q in enumerate(candidates):
        id=q["id"];n=idx+1
        if id!=f"KSAI-{year}-{n:03d}" or q["questionNo"]!=n:
            raise RuntimeError("candidate order")
        k=answers[idx]
        if k["question_no"]!=n or k["official_answer"]!=q["answerNumberOfficial"]:
            raise RuntimeError("official key mismatch")
        manual_result=reviews.get(id)
        auto_result=byid.get(id)
        geometry_result=geom_byid.get(id)
        ruby_result=ruby_byid.get(id)
        ordered_result=ordered_byid.get(id)
        layout_result=layout_byid.get(id)
        if report and not auto_result:raise RuntimeError("missing diff")
        if auto_result and (auto_result["questionNo"]!=n or auto_result["officialAnswer"]!=k["official_answer"]):
            raise RuntimeError("diff key mismatch")
        if id in disputed:
            stats["hold"]+=1
            stats["crossEngineHold"]+=1
            continue
        if manual_result and manual_result["status"]=="HOLD":
            stats["hold"]+=1
            continue
        if manual_result and manual_result["status"]=="PASS":
            pin=frozen.get(str(year))
            if not pin or pin["candidate"]!=expected_candidate_sha or pin["officialAnswerIndex"]!=expected_answers_sha:
                raise RuntimeError("visual evidence source hash drift "+id)
            if manual_result["answer"]!=q["answerNumberOfficial"]:
                raise RuntimeError("manual answer mismatch")
            audit={"status":"PASS","method":"VISUAL","record":"MANUAL_VISUAL_AUDIT_20261123.json","pdfPage":manual_result["pdf_page"]}
            stats["visual"]+=1
        elif auto_result and auto_result["status"]=="AUTO_PASS" and not auto_result["reasons"]:
            if auto_result["candidateNormalizedSha256"]!=auto_result["sourceNormalizedSha256"]:
                raise RuntimeError("invalid normalized evidence")
            audit={"status":"PASS","method":"AUTO_SHA_PINNED_PDF_NFC_WHITESPACE_DIFF","record":f"AUTO_DIFF_{year}.json",
                   "sourcePdfSha256":auto_result["officialPdfSha256"],
                   "normalizedTextSha256":auto_result["sourceNormalizedSha256"]}
            stats["auto"]+=1
        elif geometry_result and geometry_result["status"]=="GEOMETRY_PASS" and not geometry_result["reasons"]:
            if not auto_result or auto_result["status"]!="HOLD":
                raise RuntimeError("geometry promotion must resolve known auto HOLD "+id)
            if auto_result["candidateNormalizedSha256"]!=auto_result["sourceNormalizedSha256"]:
                raise RuntimeError("unresolved raw mismatch "+id)
            if geometry_result.get("ruby") is not None:
                raise RuntimeError("ruby layout cannot be promoted without certified renderer "+id)
            if geometry_result.get("table",{}).get("status")!="PASS":
                raise RuntimeError("geometry evidence missing table coordinates "+id)
            if sorted(auto_result["reasons"])!=["ANSWER_TABLE_REVIEW"]:
                raise RuntimeError("unexpected geometry source reasons "+id)
            audit={"status":"PASS","method":"AUTO_SHA_PINNED_TABLE_XY_CELL_ALIGNMENT",
                "record":f"GEOMETRY_AUDIT_{year}.json",
                "sourcePdfSha256":auto_result["officialPdfSha256"],
                "normalizedTextSha256":auto_result["sourceNormalizedSha256"],
                "table":geometry_result["table"]}
            stats["geometry"]+=1
        elif ruby_result and ruby_result["status"]=="RUBY_PASS" and not ruby_result["reasons"]:
            if not auto_result or not geometry_result:
                raise RuntimeError("ruby source evidence missing "+id)
            if auto_result["status"]!="HOLD" or auto_result["candidateNormalizedSha256"]!=auto_result["sourceNormalizedSha256"]:
                raise RuntimeError("unresolved PDF text mismatch "+id)
            if geometry_result["reasons"]!=["RUBY_RENDER_NOT_CERTIFIED"]:
                raise RuntimeError("other layout hold cannot be overwritten "+id)
            if not ruby_result.get("placements") or len(ruby_result["questionParts"])!=0 and not isinstance(ruby_result["questionParts"],list):
                raise RuntimeError("invalid ruby DOM evidence "+id)
            allparts=[ruby_result["questionParts"],*ruby_result["choicesParts"]]
            if len(allparts)!=len(q["choices"])+1:
                raise RuntimeError("rich field length mismatch "+id)
            for parts in allparts:
                if not isinstance(parts,list) or not parts:raise RuntimeError("missing ruby rich parts "+id)
                if any(("text" in part)==("rubyBase" in part) for part in parts):
                    raise RuntimeError("ambiguous rich part "+id)
            audit={"status":"PASS","method":"AUTO_PDF_GLYPH_XY_RUBY_DOM_RECONSTRUCTION",
                   "record":f"RUBY_RECON_{year}.json",
                   "sourcePdfSha256":auto_result["officialPdfSha256"],
                   "glyphCount":len(ruby_result["placements"])}
            stats["ruby"]+=1
        elif ordered_result and ordered_result["status"]=="ORDERED_RUBY_PASS" and not ordered_result["reasons"]:
            if not ruby_result or ruby_result["status"]!="HOLD":
                raise RuntimeError("cannot overwrite first-stage certified ruby")
            if not auto_result or not geometry_result or auto_result["status"]!="HOLD":
                raise RuntimeError("ordered ruby lacks held PDF evidence")
            if auto_result["candidateNormalizedSha256"]!=auto_result["sourceNormalizedSha256"]:
                raise RuntimeError("ordered ruby PDF text diff unresolved")
            if geometry_result["reasons"]!=["RUBY_RENDER_NOT_CERTIFIED"]:
                raise RuntimeError("ordered ruby cannot override other holds")
            rich=[ordered_result["questionParts"],*ordered_result["choicesParts"]]
            if len(rich)!=len(q["choices"])+1 or not ordered_result["placements"]:
                raise RuntimeError("ordered ruby mapping invalid")
            for parts in rich:
                if not isinstance(parts,list) or not parts:raise RuntimeError("rich field absent")
                if any(("text" in v)==("rubyBase" in v) for v in parts):
                    raise RuntimeError("rich field invalid")
            audit={"status":"PASS","method":"AUTO_PDF_ORDERED_GLYPH_RUBY_DOM_RECONSTRUCTION",
                "record":f"ORDERED_RUBY_{year}.json",
                "sourcePdfSha256":auto_result["officialPdfSha256"],
                "glyphCount":len(ordered_result["placements"])}
            stats["rubyOrdered"]+=1
        elif layout_result and layout_result["status"]=="LAYOUT_FALSE_POSITIVE_PASS" and not layout_result["reasons"]:
            if not auto_result or not geometry_result:
                raise RuntimeError("missing source geometry for layout "+id)
            if auto_result["status"]!="HOLD" or auto_result["candidateNormalizedSha256"]!=auto_result["sourceNormalizedSha256"]:
                raise RuntimeError("original source mismatch for layout "+id)
            if geometry_result.get("ruby") is not None:
                raise RuntimeError("unexpected ruby in cleared layout "+id)
            if not set(geometry_result["reasons"]).issubset({"FIGURE_OR_FORM_REVIEW","TABLE_XY_NOT_PURE_TRUE_FALSE_TABLE"}):
                raise RuntimeError("unresolved layout flags "+id)
            if layout_result.get("subtype")=="BENIGN_FIGURE_VERB":
                if "FIGURE_OR_FORM_REVIEW" not in geometry_result["reasons"]:
                    raise RuntimeError("figure proof mismatch")
            elif layout_result.get("subtype")=="ORDINARY_PROSE_OPTIONS":
                if geometry_result["reasons"]!=["TABLE_XY_NOT_PURE_TRUE_FALSE_TABLE"]:
                    raise RuntimeError("special table proof mismatch")
            else:raise RuntimeError("unexpected layout proof subtype")
            audit={"status":"PASS","method":"AUTO_PDF_LAYOUT_FALSE_POSITIVE_TRIAGE",
                "record":f"LAYOUT_TRIAGE_{year}.json",
                "sourcePdfSha256":auto_result["officialPdfSha256"]}
            stats["layout"]+=1
        else:
            stats["hold" if auto_result else "pending"]+=1
            continue
        if q["sourceIssuer"]!="関西広域連合" or not q.get("sourceUrl") or not q.get("answerSourceUrl") or not q.get("attributionDisplay"):
            raise RuntimeError("source attribution absent "+id)
        if not isinstance(q["choices"],list) or len(q["choices"]) not in (4,5) or not all(q["choices"]):
            raise RuntimeError("choice structural failure "+id)
        if year==2023 and n==90:
            # Official invalid must never get automatic approval.
            if audit["method"]!="VISUAL" or q["answer"] is not None or not q["excludeFromAccuracyDenominator"]:
                raise RuntimeError("invalid Q90 promotion")
        elif not isinstance(q["answer"],int) or not 0<=q["answer"]<len(q["choices"]) or q["excludeFromAccuracyDenominator"]:
            raise RuntimeError("invalid answer "+id)
        fields=("id","year","questionNo","chapter","question","choices","answer","answerNumberOfficial",
                "sourceIssuer","sourceTitle","sourceUrl","answerSourceUrl","sourcePdfPages",
                "attributionDisplay","officialStatus","excludeFromAccuracyDenominator")
        item={field:q[field] for field in fields}
        item.update({"modificationDisclosureDisplay":q.get("modificationDisclosureDisplay") or "PDFを表示用に加工",
                     "verbatimCertified":True,"needsVisualReview":False,"renderReady":True,"audit":audit})
        if audit["method"] in ("AUTO_PDF_GLYPH_XY_RUBY_DOM_RECONSTRUCTION","AUTO_PDF_ORDERED_GLYPH_RUBY_DOM_RECONSTRUCTION"):
            rich_source=ruby_result if audit["method"]=="AUTO_PDF_GLYPH_XY_RUBY_DOM_RECONSTRUCTION" else ordered_result
            item["questionParts"]=rich_source["questionParts"]
            item["choicesParts"]=rich_source["choicesParts"]
            item["question"]="".join(p.get("text",p.get("rubyBase","")) for p in item["questionParts"])
            item["choices"]=["".join(p.get("text",p.get("rubyBase","")) for p in parts) for parts in item["choicesParts"]]
        accepted[id]=item
    status_by_year[str(year)]=stats
# Reproducible, fail-closed promotion of image-only questions already independently certified.
# Do not revert these 44 questions when the base bank is regenerated.
crop_audit_path=B/"CROP_INDEPENDENT_QA_20261124.json"
crop_mobile_path=B/"CROP_MOBILE_QA_RESULT.json"
if crop_audit_path.exists() and crop_mobile_path.exists():
    crop_audit=json.loads(crop_audit_path.read_text())
    crop_mobile=json.loads(crop_mobile_path.read_text())
    if crop_mobile.get("status")=="PASS" and crop_audit.get("totalPromoted")==44:
        records=crop_audit.get("records",[])
        rows=crop_mobile.get("records",[])
        if len(records)!=44 or len(rows)!=88 or len({r["id"] for r in records})!=44:
            raise RuntimeError("crop audit count or uniqueness mismatch")
        passes={(r["id"],r["width"]) for r in rows if r.get("result")=="PASS"}
        if len(passes)!=88:
            raise RuntimeError("real browser QA has missing or duplicate viewport cases")
        for rec in records:
            id=rec["id"];year=int(id.split("-")[1]);no=int(id.split("-")[2])
            # Some crop QA rows were included in the historical 44-row batch even
            # though the manifest already marks them as approved by an earlier
            # independent route. Preserve that prior approval; never replace its
            # text/ruby record with the image-only fallback generated below.
            if id in accepted:
                prior=accepted[id]
                if prior.get("audit",{}).get("status")!="PASS":
                    raise RuntimeError("existing approval lacks PASS audit: "+id)
                continue
            if not rec.get("promoted") or rec.get("result")!="PASS":
                raise RuntimeError("crop approval evidence missing: "+id)
            if (id,375) not in passes or (id,430) not in passes:
                raise RuntimeError("crop viewport not passed: "+id)
            if rec.get("mobile375")!="PASS_REAL_CHROMIUM" or rec.get("mobile430")!="PASS_REAL_CHROMIUM":
                raise RuntimeError("crop mobile evidence missing: "+id)
            if not rec.get("scopeCheck","").startswith("PASS_"):
                raise RuntimeError("crop scope was not approved: "+id)
            if rec.get("thirdPartyRightsCheck")!="PASS_EXAM_ORIGINAL_TEXT_TABLE_NO_EXTERNAL_ART_OBSERVED":
                raise RuntimeError("crop third-party rights not cleared: "+id)
            manifest=json.loads((B/f"LAYOUT_CROPS_{year}.json").read_text())
            meta=next((x for x in manifest["records"] if x["id"]==id),None)
            if not meta:
                raise RuntimeError("missing crop source manifest: "+id)
            # alreadyApproved is a historical manifest snapshot, not a veto.
            # This builder reconstructs the canonical bank from source evidence;
            # if an older approval is absent from the current accepted set, the
            # independently passing crop audit below is sufficient to reconstruct
            # the same record without lowering the visual/rights/mobile criteria.
            # Duplicate records already present in accepted were skipped above.
            # The historical flag does not waive any of the evidence checks below.
            assets=meta.get("displayAssets") or meta["assets"]
            if len(assets)!=1 or rec.get("effectiveCropAssets")!=[assets[0]["webPath"]]:
                raise RuntimeError("crop display source drift: "+id)
            asset=assets[0]
            binary=(B/asset["relativePath"]).read_bytes()
            if hashlib.sha256(binary).hexdigest()!=asset["sha256"]:
                raise RuntimeError("cropped PDF image sha mismatch: "+id)
            cand=json.loads((B/f"QUESTIONS_{year}_APP_CANDIDATE.json").read_text())["questions"][no-1]
            if cand["id"]!=id or cand["sourceUrl"]!=meta["sourcePdfUrl"]:
                raise RuntimeError("crop candidate source drift: "+id)
            if cand["answerNumberOfficial"]!=cand["answer"]+1 or len(cand["choices"]) not in (4,5):
                raise RuntimeError("crop official answer inconsistent: "+id)
            keys=("id","year","questionNo","chapter","answer","answerNumberOfficial",
                  "sourceIssuer","sourceTitle","sourceUrl","answerSourceUrl",
                  "attributionDisplay","officialStatus","excludeFromAccuracyDenominator")
            item={key:cand[key] for key in keys}
            item.update({
                "question":"以下の公式試験問題画像を読み、正しい選択肢を選んでください。",
                "choices":[f"画像中の選択肢 {i+1}" for i in range(len(cand["choices"]))],
                "sourcePdfPages":[asset["page"]],
                "modificationDisclosureDisplay":"関西広域連合の公式問題PDFから設問領域を切り出して掲載（表示用に加工）。設問・選択肢の文章は画像内の原典をご確認ください。",
                "verbatimCertified":True,"needsVisualReview":False,"renderReady":True,
                "sourceFigures":[{"webPath":asset["webPath"],"sha256":asset["sha256"],
                    "sourcePdfUrl":meta["sourcePdfUrl"],"page":asset["page"],
                    "licenseVerified":True,"visualVerified":True}],
                "audit":{"status":"PASS","method":"OFFICIAL_PDF_IMAGE_CROP_SCOPE_RIGHTS_MOBILE",
                    "record":"CROP_INDEPENDENT_QA_20261124.json",
                    "originalQuestionTextRenderedAsImage":True,
                    "sourcePdfSha256":meta["sourcePdfSha256"],"croppedPages":[asset["page"]]}
            })
            accepted[id]=item
            stat=status_by_year[str(year)]
            stat["cropImage"]=stat.get("cropImage",0)+1
            stat["hold"]-=1
            if stat["hold"]<0:raise RuntimeError("negative crop hold: "+id)

# Preserve independently certified raw-font ruby candidates across bank rebuilds.
font_evidence=B/"RUBY_FONT_CLUSTER_ALL_20261124.json"
if font_evidence.exists():
    font=json.loads(font_evidence.read_text())
    if font.get("reviewed")!=130 or len(font.get("records",[]))!=130:
        raise RuntimeError("invalid raw-font ruby evidence count")
    for r in font["records"]:
        if r["status"]!="FONT_CLUSTER_PASS":continue
        id=r["id"];year=r["year"];n=r["questionNo"]
        if id in accepted:raise RuntimeError("ruby font record already accepted by another method: "+id)
        q=json.loads((B/f"QUESTIONS_{year}_APP_CANDIDATE.json").read_text())["questions"][n-1]
        geo=json.loads((B/f"GEOMETRY_AUDIT_{year}.json").read_text())["questions"][n-1]
        ordered=json.loads((B/f"ORDERED_RUBY_{year}.json").read_text())["records"][n-1]
        if id!=q["id"] or id!=geo["id"] or id!=ordered["id"]:
            raise RuntimeError("ruby font source order mismatch: "+id)
        if geo["reasons"]!=["RUBY_RENDER_NOT_CERTIFIED"] or ordered["status"]!="HOLD":
            raise RuntimeError("another source hold prevents font ruby approval: "+id)
        if r["reasonCodes"] or not r.get("placements"):
            raise RuntimeError("missing font ruby evidence: "+id)
        if q["answerNumberOfficial"]!=q["answer"]+1 or q["excludeFromAccuracyDenominator"]:
            raise RuntimeError("official answer inconsistent: "+id)
        fields=("id","year","questionNo","chapter","answer","answerNumberOfficial","sourceIssuer",
          "sourceTitle","sourceUrl","answerSourceUrl","attributionDisplay","officialStatus",
          "excludeFromAccuracyDenominator","sourcePdfPages")
        parts=[r["questionParts"],*r["choicesParts"]]
        if len(parts)!=len(q["choices"])+1 or sum("rubyBase" in v for field in parts for v in field)!=len(r["placements"]):
            raise RuntimeError("ruby rich parts inconsistent: "+id)
        plain=["".join(v.get("text",v.get("rubyBase","")) for v in field) for field in parts]
        if not all(plain):raise RuntimeError("blank ruby content: "+id)
        item={field:q[field] for field in fields}
        item.update({"question":plain[0],"choices":plain[1:],"questionParts":r["questionParts"],
          "choicesParts":r["choicesParts"],"verbatimCertified":True,"needsVisualReview":False,
          "renderReady":True,
          "modificationDisclosureDisplay":"原典PDF座標からルビを照合してruby要素で再配置",
          "audit":{"status":"PASS","method":"PDF_RAW_FONT_CLUSTER_RUBY",
            "record":"RUBY_FONT_CLUSTER_ALL_20261124.json","placements":r["placements"]}})
        accepted[id]=item
        stats=status_by_year[str(year)]
        stats["rubyFontCluster"]=stats.get("rubyFontCluster",0)+1
        stats["hold"]-=1
        if stats["hold"]<0:raise RuntimeError("negative ruby font hold: "+id)

approved=sorted(accepted.values(),key=lambda q:(q["year"],q["questionNo"]))
out={"schema":"touroku-hanbaisha-official-approved-v2","issuer":"関西広域連合",
     "officialPastQuestionsOnly":True,"count":len(approved),"questionCountTarget":600,
     "approvedIds":[q["id"] for q in approved],"byYear":status_by_year,
     "status":"PARTIAL_APPROVED" if len(approved)<600 else "APPROVED_CONTENT",
     "releaseGate":"BLOCKED_PENDING_OTHER_170_QUESTIONS_AND_APP_TESTS" if len(approved)==430 else "BLOCKED_PENDING_APP_TESTS_AND_REVIEW","questions":approved}
(B/"APPROVED_OFFICIAL_BANK.json").write_text(json.dumps(out,ensure_ascii=False,indent=2)+"\n")
print(json.dumps({"approved":len(approved),"byYear":status_by_year},ensure_ascii=False))
