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
    lines=text.splitlines()
    markers=[i for i,s in enumerate(lines) if re.search(r"次の文を読み|次の文章を読み|次の事例を読み|次の文を読んで|次の事例について",s)]
    first=91+3*((number-91)//3)
    anchor=number_lines(text,first)
    if not markers or not anchor:return None
    prior=[x for x in markers if x<anchor[0] and anchor[0]-x<=55]
    if not prior:return None
    passage="\n".join(lines[prior[-1]:anchor[0]]).strip()
    return passage if len(normalized(passage))>=35 else None

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

def verify(doc,pdf,n,page_hint,stem,choices,poppler_text,clean_font,normalize):
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
        if not all(normalize(s) in normalize(region) and normalize(s) in normalize(alt) for s in five):
            continue
        matched.append((pg,region,geometry))
    if len(matched)!=1:
        return None,["COORDINATE_BOUNDARY_NOT_UNIQUELY_CONFIRMED"],None,None,None
    pg,region,geometry=matched[0]
    scenario=None
    if n>=91:
        matches=[]
        for p in range(max(1,pg-3),pg+1):
            f=clean_font(doc[p-1].get_text("text",sort=False))
            alt=clean_font(poppler_text(pdf,p))
            passage=context_for_group(f,n)
            if passage and normalize(passage) in normalize(alt):
                matches.append((p,passage))
        if not matches:
            return pg,["SITUATION_GROUP_CONTEXT_NOT_VERIFIED"],None,geometry,region
        p,passage=matches[-1]
        scenario={"page":p,"commonText":passage,"normalizedLength":len(normalize(passage)),
                  "engines":["PyMuPDF","Poppler"],"status":"DUAL_ENGINE_CONTEXT_MATCH"}
    geometry["verifiedPage"]=pg
    geometry["method"]="PyMuPDF word bounding boxes; next question anchor; Poppler full field cross-check"
    return pg,[],scenario,geometry,region
