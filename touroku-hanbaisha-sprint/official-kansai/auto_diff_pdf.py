#!/usr/bin/env python3
"""Fail-closed independent PDF-byte / candidate normalization diff for Kansai registration exam.
Text alone cannot certify graphic elements, furigana layout, or printed answer tables.
"""
import argparse, collections, hashlib, json, re, unicodedata, urllib.request
from pathlib import Path
import fitz

B=Path(__file__).resolve().parent
HEAD=re.compile(r"^\s*問\s*([０-９0-9]{1,3})\s*$")
DIGITS=str.maketrans("０１２３４５６７８９","0123456789")
NUMS="１２３４５"
ROW=re.compile(r"(?m)^\s*([１２３４５1-5])\s+(?=\S)")
INLINE=re.compile(r"([１２３４５1-5])\s*[（(]([^）)\n]+)[）)]")
RUBY_LINE=re.compile(r"(?m)^\s*[ぁ-んァ-ン]{1,12}\s*$")
RISK_WORDS=re.compile(r"図|図表|下図|次の表|下表|配合成分\s*含量|配合成分\s*作用|表は|構造式|化学構造|添付文書の例|グラフ|フローチャート|模式図")
PRINT_PAGE=re.compile(r"^\s*-\s*[0-9０-９]{1,3}\s*-\s*$")
PRINT_HASH=re.compile(r"^\s*[♯＃#]{15,}\s*$")
def git_blob_sha(path):
    b=path.read_bytes()
    return hashlib.sha1(f"blob {len(b)}\0".encode()+b).hexdigest()
def norm(value):
    """NFC only; discard Unicode whitespace incl LF/U+3000; never remove kana, marks or punctuation."""
    return "".join(c for c in unicodedata.normalize("NFC",value) if not c.isspace())
def choice_digit(value):
    return str(NUMS.index(value)+1) if value in NUMS else value
def split_options(raw):
    rows=list(ROW.finditer(raw))
    for count in (5,4):
        if len(rows)==count and "".join(choice_digit(m.group(1)) for m in rows)=="12345"[:count]:
            return raw[:rows[0].start()].strip(),[
                raw[m.end():rows[i+1].start() if i<count-1 else len(raw)].strip()
                for i,m in enumerate(rows)],"row",rows
    inline=list(INLINE.finditer(raw))
    for count in (5,4):
        if len(inline)==count and "".join(choice_digit(m.group(1)) for m in inline)=="12345"[:count]:
            return raw[:inline[0].start()].strip(),[m.group(2) for m in inline],"inline",inline
    return None,None,"unparsed",[]
def download(url,target,expected_sha):
    if not target.exists():
        req=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0"})
        with urllib.request.urlopen(req,timeout=70) as response:
            target.write_bytes(response.read())
    binary=target.read_bytes()
    actual=hashlib.sha256(binary).hexdigest()
    if actual!=expected_sha or not binary.startswith(b"%PDF"):
        raise RuntimeError(f"PDF_HASH_MISMATCH {url}: {actual} != {expected_sha}")
    return fitz.open(stream=binary,filetype="pdf")
def source_pages(doc,start,end):
    """Fresh extraction directly from pinned official PDF, not from staging JSON."""
    chunks=[];current=None
    for i,page in enumerate(doc):
        for line in page.get_text("text",sort=True).splitlines():
            h=HEAD.match(line)
            if h:
                n=int(h.group(1).translate(DIGITS))
                if start<=n<=end:
                    if current:chunks.append(current)
                    current={"no":n,"lines":[],"pages":[i+1]}
                    continue
            if current is not None:
                if i+1 not in current["pages"]:current["pages"].append(i+1)
                current["lines"].append(line)
    if current:chunks.append(current)
    if [c["no"] for c in chunks]!=list(range(start,end+1)):
        raise RuntimeError(f"QUESTION_BOUNDARY_FAIL {start}-{end}: {[c['no'] for c in chunks]}")
    for c in chunks:
        c["raw"]="\n".join(x for x in c["lines"] if not PRINT_HASH.fullmatch(x) and not PRINT_PAGE.fullmatch(x)).strip()
    return chunks
def first_diff(a,b):
    return next((i for i,(x,y) in enumerate(zip(a,b)) if x!=y),min(len(a),len(b)))
def check_year(year):
    entry=next(x for x in json.loads((B/"SOURCES_2022_2026.json").read_text())["years"] if x["year"]==year)
    expected=json.loads((B/f"PDF_SHA256_{year}.json").read_text())
    answer=json.loads((B/f"ANSWERS_{year}_OFFICIAL.json").read_text())["questions"]
    candidate=json.loads((B/f"QUESTIONS_{year}_APP_CANDIDATE.json").read_text())["questions"]
    raw_staging=json.loads((B/f"QUESTIONS_{year}_RAW_STAGING.json").read_text())["questions"]
    if len(expected)!=2 or len(candidate)!=120 or len(answer)!=120 or len(raw_staging)!=120:
        raise RuntimeError("LENGTH_MISMATCH")
    halves=[("first_half",entry["question_pdf_first_half"],1,60),("second_half",entry["question_pdf_second_half"],61,120)]
    rows=[];passed=[];distribution=collections.Counter();advisory_counts=collections.Counter()
    for (half,url,first,last),e in zip(halves,expected):
        if e["half"]!=half or e["url"]!=url:raise RuntimeError("SOURCE_URL_MISMATCH")
        doc=download(url,B/f".tmp_{year}_{half}.pdf",e["sha256"])
        source=source_pages(doc,first,last)
        for n in range(first,last+1):
            ref=source[n-first];q=candidate[n-1];a=answer[n-1];old=raw_staging[n-1]
            if q["id"]!=f"KSAI-{year}-{n:03d}" or q["questionNo"]!=n or a["question_no"]!=n:
                raise RuntimeError(f"QUESTION_KEY_ERROR {year}/{n}")
            if q["sourceUrl"]!=url or q["answerNumberOfficial"]!=a["official_answer"]:
                raise RuntimeError(f"ANSWER_OR_SOURCE_ERROR {year}/{n}")
            if n==90 and year==2023:
                if q["answer"] is not None or not q["excludeFromAccuracyDenominator"]:
                    raise RuntimeError("Q90_SCORING_REGRESSION")
            elif q["answer"]!=a["official_answer"]-1 or q["excludeFromAccuracyDenominator"]:
                raise RuntimeError(f"ANSWER_ERROR {year}/{n}")
            flags=[];advisories=[]
            actual=norm(ref["raw"]);raw=norm(q["rawOriginalText"])
            if raw!=actual:flags.append("PDF_RAW_DIFF")
            if norm(old["rawOriginalText"])!=actual:advisories.append("LEGACY_STAGING_PDF_DRIFT")
            stem,choices,mode,matches=split_options(ref["raw"])
            if stem is None:flags.append("PDF_OPTION_PARSE")
            elif q.get("choices") is None:flags.append("CANDIDATE_OPTIONS_MISSING")
            else:
                if norm(q["question"])!=norm(stem):flags.append("STEM_DIFF")
                if len(q["choices"])!=len(choices):flags.append("CHOICE_COUNT_DIFF")
                elif any(norm(x)!=norm(y) for x,y in zip(q["choices"],choices)):
                    flags.append("CHOICE_DIFF")
            if RUBY_LINE.search(ref["raw"]):flags.append("RUBY_POSITION_REVIEW")
            if RISK_WORDS.search(ref["raw"]):flags.append("FIGURE_OR_FORM_REVIEW")
            # Truth tables, 4/5-row statement-by-statement answer grids are 2-D layouts.
            if mode=="row" and len(matches)>=4 and any(re.search(r"[正誤]",x) for x in (choices or [])):
                flags.append("ANSWER_TABLE_REVIEW")
            # Scanned images, vector drawings or embedded graphics may not appear in extracted text.
            pages=ref["pages"]
            for p in pages:
                page=doc[p-1]
                if page.get_images(full=True):
                    flags.append("PAGE_EMBEDDED_IMAGE_REVIEW");break
            if year==2023 and n==90:flags.append("OFFICIAL_INVALID_Q90_REVIEW")
            flags=list(dict.fromkeys(flags))
            status="AUTO_PASS" if not flags else "HOLD"
            distribution.update(flags)
            advisory_counts.update(advisories)
            evidence={"id":q["id"],"year":year,"questionNo":n,
              "status":status,"reasons":flags,"advisories":advisories,"officialPdfSha256":e["sha256"],"sourcePdfUrl":url,
              "sourcePages":ref["pages"],"sourceNormalizedSha256":hashlib.sha256(actual.encode()).hexdigest(),
              "candidateNormalizedSha256":hashlib.sha256(raw.encode()).hexdigest(),
              "sourceRawCharacterCount":len(ref["raw"]),"candidateRawCharacterCount":len(q["rawOriginalText"]),
              "firstDifferentNormalizedCharacter":first_diff(actual,raw) if actual!=raw else None,
              "choiceCount":len(choices) if choices else 0,"officialAnswer":a["official_answer"]}
            rows.append(evidence)
            if status=="AUTO_PASS":
                if not isinstance(q.get("choices"),list) or len(q["choices"]) not in (4,5):
                    raise RuntimeError("EMPTY_PASS")
                passed.append(q["id"])
        doc.close()
    assert len(rows)==120 and len(set(x["id"] for x in rows))==120
    output={"year":year,"method":"FRESH_OFFICIAL_PDF_SHA256_PINNED_NORMALIZED_DIFF",
      "normalization":"NFC Unicode, remove only Unicode whitespace including line breaks and fullwidth spaces. Ruby characters are never removed. No punctuation/symbol/kana/kanji deletion.",
      "caveat":"Source text extracted with PyMuPDF is not an independent second transcription; nontext artwork and answer tables are always held for manual review. Legacy raw staging drift is tracked but never substitutes for direct fresh PDF-to-app comparison.",
      "total":120,"autoPass":len(passed),"held":120-len(passed),
      "candidateGitBlob":git_blob_sha(B/f"QUESTIONS_{year}_APP_CANDIDATE.json"),
      "answerIndexGitBlob":git_blob_sha(B/f"ANSWERS_{year}_OFFICIAL.json"),
      "reasonCounts":dict(sorted(distribution.items())),"advisoryCounts":dict(sorted(advisory_counts.items())),"passedIds":passed,"questions":rows}
    output_file=B/f"AUTO_DIFF_{year}.json"
    output_file.write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"year":year,"PASS":len(passed),"HOLD":120-len(passed),"reasons":dict(distribution)},ensure_ascii=False))
if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--year",type=int,choices=range(2022,2027),required=True)
    args=parser.parse_args()
    check_year(args.year)
