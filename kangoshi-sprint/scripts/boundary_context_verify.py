#!/usr/bin/env python3
"""Geometric question boundaries from source PDF coordinates (not text stream order).

Evidence: PyMuPDF word boxes locate a unique numbered anchor in the left text
margin. A rectangle bounded by the next numbered anchor is independently
checked against Poppler page text and the official answer key upstream.
Do not approve uncertain glyphs, diagrams, or scenario contexts.
"""
import re, unicodedata

def normalized(value):
    return re.sub(r"\s+", "", unicodedata.normalize("NFKC", str(value))).replace("～","~").replace("〜","~")

def number_lines(text, number):
    lines=text.splitlines()
    pat=re.compile(r"^\s*(?:問\s*)?0*"+str(number)+r"(?=$|[\s.．。)）])")
    return [i for i,line in enumerate(lines) if pat.match(line)]

def context_for_group(text,number):
    """Printed situation-block range header and shared passage, not generic prose.
    Must identify exact 91-93 / 94-96 ... printed heading and first-question anchor.
    """
    lines=text.splitlines()
    first=91+3*((number-91)//3)
    last=first+2
    rx=re.compile(r"次の文を読み\s*"+str(first)+r"\s*[〜～~－−-]\s*"+str(last))
    headers=[i for i,line in enumerate(lines) if rx.search(line)]
    anchors=number_lines(text,first)
    candidates=[(h,a) for h in headers for a in anchors if a>h]
    if len(candidates)!=1:return None
    h,a=candidates[0]
    passage="\n".join(lines[h:a]).strip()
    if len(normalized(passage))<35:return None
    return {"first":first,"last":last,"passage":passage,"header":lines[h].strip()}

def equivalent_shared_context(a,b):
    """Compare exact Japanese/punctuation/numerical content plus a Latin token bag.
    PDF layout shifts English ruby/translation annotations without changing text.
    Latin tokens may move but never be dropped, added or rewritten.
    """
    words_a=sorted(re.findall(r"[A-Za-z]+",a,re.ASCII))
    words_b=sorted(re.findall(r"[A-Za-z]+",b,re.ASCII))
    japanese_a=normalized(re.sub(r"[A-Za-z]+","",a,flags=re.ASCII))
    japanese_b=normalized(re.sub(r"[A-Za-z]+","",b,flags=re.ASCII))
    return bool(japanese_a) and japanese_a==japanese_b and words_a==words_b, {
        "japaneseExactMatch":japanese_a==japanese_b,
        "latinTokenMultisetExactMatch":words_a==words_b,
        "japaneseChars":len(japanese_a),
        "latinTokens":len(words_a)
    }

def safe_context(raw,clean_font,visual_pairs=None):
    # Both parsers can share a wrong source CMap. Unmapped control bytes and
    # suspicious glyphs in context cannot be auto-cleared by parser agreement.
    fixed=set((2,4,5,6,7,8,11,12,31))
    bad=[ord(c) for c in raw if ord(c)<32 and ord(c) not in fixed and c not in "\n\r\t"]
    val=clean_font(raw)
    supported={"ï":"ñ","è":"ê","\u008d":"\u008f"}
    for left,right in supported.items():
        if (left in val or right in val) and (visual_pairs is not None and left in visual_pairs and right in visual_pairs):
            if val.count(left)!=val.count(right):return False,["UNPAIRED_VISUAL_SOURCE_GLYPHS"]
            val=val.replace(left,"（").replace(right,"）")
    return not bad and not re.search(r"[\ufffd઄¹¼ïñèêçâ\u0080-\u009f!?]",val),bad

def _anchors(page, n, clean_font):
    words=page.get_text("words",sort=True)
    width=float(page.rect.width)
    anchors=[]
    for x0,y0,x1,y1,value,*rest in words:
        token=clean_font(value).strip()
        if not re.fullmatch(r"(?:問)?0*"+str(n)+r"[.．。]?",token):
            continue
        # Printed question numbers appear in the left body margin;
        # avoid arbitrary numerals in body/answer choices.
        if x0>width*.16 or y0<page.rect.height*.055:
            continue
        # Adjacent text is allowed, but anchor must precede it geometrically.
        following=[w for w in words if abs(w[1]-y0)<(y1-y0)*1.5 and w[0]>x1]
        if not following:continue
        anchors.append((float(x0),float(y0),float(x1),float(y1)))
    return anchors

def _region(page,n,clean_font):
    import fitz
    a=_anchors(page,n,clean_font)
    if len(a)!=1:return None,None
    x0,y0,x1,y1=a[0]
    next_boxes=_anchors(page,n+1,clean_font)
    after=[b for b in next_boxes if b[1]>y0+2]
    bottom=min((b[1] for b in after),default=float(page.rect.height)*.96)
    if bottom<=y1+8:return None,None
    box=fitz.Rect(0,max(0,y0-3),float(page.rect.width),bottom)
    text=clean_font(page.get_text("text",clip=box,sort=False))
    return text,{"anchorBox":[round(z,2) for z in a[0]],"clip":[round(z,2) for z in box],"nextAnchorFound":bool(after)}

def verify(doc,pdf,n,page_hint,stem,choices,poppler_text,clean_font,normalize,visually_verified_fields=None,context_glyph_evidence=None):
    """Return (page, issues, scenario evidence, coordinate evidence, cropped text)."""
    pages=range(max(1,page_hint-3),min(len(doc),page_hint+3)+1)
    matched=[]
    for pg in pages:
        page=doc[pg-1]
        region,geometry=_region(page,n,clean_font)
        if region is None:continue
        # Verify every field is inside the geometrically bounded question
        # AND independently present in Poppler extraction of the same page.
        alt=clean_font(poppler_text(pdf,pg))
        five=[stem]+choices
        if len(choices)!=4:continue
        if not all(i in (visually_verified_fields or set()) or (normalize(s) in normalize(region) and normalize(s) in normalize(alt)) for i,s in enumerate(five)):
            continue
        matched.append((pg,region,geometry))
    if len(matched)!=1:
        return None,["COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED"],None,None,None
    pg,region,geometry=matched[0]
    scenario=None
    if n>=91:
        matches=[]
        rejected=[]
        for p in range(max(1,pg-3),pg+1):
            original=doc[p-1].get_text("text",sort=False)
            alt_raw=poppler_text(pdf,p)
            info=context_for_group(clean_font(original),n)
            if info is None:continue
            alt_info=context_for_group(clean_font(alt_raw),n)
            if alt_info is None:rejected.append("POPLER_SHARED_CONTEXT_NOT_FOUND");continue
            same,shared_evidence=equivalent_shared_context(info["passage"],alt_info["passage"])
            safe1,bad1=safe_context(original,clean_font)
            safe2,bad2=safe_context(alt_raw,clean_font)
            if not same:rejected.append("SITUATION_CONTEXT_TEXT_DIFFER");continue
            # Check the common passage itself, not unrelated text elsewhere on page.
            glyph_pairs=(context_glyph_evidence or {}).get("allowedPairedGlyphs",[]) if (context_glyph_evidence or {}).get("contextPage")==p else []
            safe_passage1,badpass1=safe_context(info["passage"],clean_font,glyph_pairs)
            safe_passage2,badpass2=safe_context(alt_info["passage"],clean_font,glyph_pairs)
            if not safe_passage1 or not safe_passage2:
                rejected.append("SITUATION_CONTEXT_UNRESOLVED_SOURCE_GLYPHS")
                continue
            common=info["passage"]
            if glyph_pairs:
                for l,r in (("ï","ñ"),("è","ê"),("\u008d","\u008f")):
                    if l in glyph_pairs and r in glyph_pairs:common=common.replace(l,"（").replace(r,"）")
            matches.append({"page":p,"groupFirst":info["first"],"groupLast":info["last"],
                            "commonText":common,"normalizedLength":len(normalized(common)),
                            "visualContextGlyphEvidence":context_glyph_evidence if glyph_pairs else None,
                            "method":"printed range header + first question position + exact Japanese content and Latin token multiset",
                            "comparison":shared_evidence,
                            "engines":["PyMuPDF","Poppler"],"status":"DUAL_ENGINE_CONTEXT_MATCH"})
        if len(matches)!=1:
            return pg,[rejected[0] if rejected else "SITUATION_GROUP_CONTEXT_NOT_VERIFIED"],None,geometry,region
        scenario=matches[0]
    geometry["verifiedPage"]=pg
    geometry["method"]="PyMuPDF word bounding boxes; next question anchor; Poppler full field cross-check"
    return pg,[],scenario,geometry,region
