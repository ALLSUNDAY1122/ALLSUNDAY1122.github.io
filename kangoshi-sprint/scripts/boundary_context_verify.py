#!/usr/bin/env python3
"""Independent question-page alignment and scenario context evidence.

This module never guesses unknown glyphs or certifies image/media rights.
"""
import re, unicodedata

def normalized(value):
    return re.sub(r"\s+", "", unicodedata.normalize("NFKC", str(value))).replace("～","~").replace("〜","~")

def number_lines(text, number):
    lines=text.splitlines()
    # A complete standalone printed item number, not numerals in a choice or dosage.
    pat=re.compile(r"^\s*(?:問\s*)?"+str(number)+r"\s*[.．。]?\s*$")
    return [i for i,line in enumerate(lines) if pat.fullmatch(line)]

def context_for_group(text, number):
    """Detect an explicit common case passage immediately preceding its first item."""
    lines=text.splitlines()
    markers=[i for i,s in enumerate(lines) if re.search(r"次の文を読み|次の文章を読み|次の事例を読み|次の文を読んで|次の事例について",s)]
    here=number_lines(text,number)
    if not markers or not here:
        return None
    idx=here[0]
    prior=[x for x in markers if x<idx and idx-x<=55]
    if not prior:return None
    start=prior[-1]
    passage="\n".join(lines[start:idx]).strip()
    return passage if len(normalized(passage))>=35 else None

def verify(doc, pdf, n, page_hint, stem, choices, poppler_text, clean_font, normalize):
    """Return (page, diagnostics, scenario_evidence); no policy decisions."""
    candidate_pages=range(max(1,(page_hint or 1)-3), min(len(doc),(page_hint or 1)+3)+1)
    full=[stem]+choices
    matches=[]
    for pg in candidate_pages:
        fitz_text=clean_font(doc[pg-1].get_text("text",sort=False))
        pop_text=clean_font(poppler_text(pdf,pg))
        if not number_lines(fitz_text,n) or not number_lines(pop_text,n):
            continue
        if not all(normalize(t) in normalize(fitz_text) and normalize(t) in normalize(pop_text) for t in full if t):
            continue
        matches.append((pg,fitz_text,pop_text))
    if len(matches)!=1:
        return None, ["BOUNDARY_NO_UNIQUE_DUAL_ENGINE_PAGE"], None
    pg,fitz_text,pop_text=matches[0]
    scenario=None
    if n>=91:
        # No blanket PASS for a scenario: common case passage must match two engines.
        candidates=[]
        for p in (pg-1,pg):
            if p<1:continue
            f=clean_font(doc[p-1].get_text("text",sort=False))
            alt=clean_font(poppler_text(pdf,p))
            passage=context_for_group(f,n)
            if passage and normalize(passage) in normalize(alt):
                candidates.append((p,passage))
        if candidates:
            p,passage=candidates[-1]
            scenario={"page":p,"commonText":passage,"normalizedLength":len(normalize(passage)),
                      "engines":["PyMuPDF","Poppler"],"status":"DUAL_ENGINE_CONTEXT_MATCH"}
        else:
            return pg,["SITUATION_GROUP_CONTEXT_NOT_VERIFIED"],None
    return pg, [], scenario
