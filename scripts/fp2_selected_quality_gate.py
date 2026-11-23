#!/usr/bin/env python3
"""FP2 selected-298 verbatim legal exclusion structural/provenance regression gate. This is not legal sign-off."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import re
import sys

root=Path(__file__).resolve().parents[1]
base=root/"fp2-manabi-sprint"
bank=json.loads((base/"questions/canonical/approved-questions-20261123.json").read_text())
selection=json.loads((base/"release/release-selection-300-20261123.json").read_text())
selected=[q for q in bank["questions"] if q.get("release_selected") is True]
reserved=[q for q in bank["questions"] if q.get("release_selected") is False]
errors=[]
domains=Counter(q.get("domain") for q in selected)
answers=Counter()
source_groups=Counter()
def git_blob(blob):
    return hashlib.sha1(b"blob "+str(len(blob)).encode()+b"\x00"+blob).hexdigest()
if len(bank["questions"])!=310 or len(selected)!=298 or len(reserved)!=12:
    errors.append("canonical/selection/reserve count mismatch")
if (bank.get("recovered_pass_count"),bank.get("recovered_fail_count"),bank.get("recovered_hold_count"))!=(180,0,0):
    errors.append("recovered180 audit count mismatch")
if len(domains)!=6 or sorted(domains.values())!=[48,50,50,50,50,50]:
    errors.append("six domains x 50 violated")
exam_counts=Counter(q.get("exam_year_month") or q.get("examDate") or "independently-authored" for q in selected)
if dict(exam_counts)!={"2026-05":60,"2025-05":60,"2025-01":60,"2024-09":59,"2024-05":59}: errors.append("2024 law-excluded 298 official with no original backfill session distribution violated")
if (bank.get("expansion_audit_pass_count"),bank.get("expansion_audit_fail_count"),bank.get("expansion_audit_hold_count"))!=(118,2,0): errors.append("verbatim audit 118/2/0 mismatch")
scope={}
for group in selection["domains"]:
    for i in group["selected_ids"]:
        if i in scope: errors.append("duplicate release selected id "+i)
        scope[i]=group["domain"]
if set(scope)!={q.get("id") for q in selected}: errors.append("selection ledger differs from canonical")
for q in selected:
    ident=q.get("id","MISSING")
    stem=q.get("question") or q.get("stem")
    opts=q.get("choices")
    a=q.get("answer_index")
    if not isinstance(stem,str) or not stem.strip():errors.append(ident+": stem missing")
    if not isinstance(opts,list) or len(opts)!=4 or any(not isinstance(v,str) or not v.strip() for v in opts):errors.append(ident+": choices invalid")
    if not isinstance(a,int) or a not in range(4) or q.get("answer_one_based")!=a+1:errors.append(ident+": answer numbering mismatch")
    else:answers[a+1]+=1
    if not q.get("explanation") or not q.get("modification_note"):errors.append(ident+": explanation/modification note missing")
    if q.get("modified") not in (True,False):errors.append(ident+": unclassified modification")
    if q.get("independent_audit_status")!="PASS" or q.get("approved_for_content_bank") is not True:
        errors.append(ident+": independent content PASS missing")
    if q.get("publishable") is not False:errors.append(ident+": unauthorized release flag")
    if not q.get("source_organization") or not q.get("source_section"):errors.append(ident+": exact attribution metadata missing")
    url=next((q[k] for k in ("source_original_question_url","source_question_url","primary_law_url","source_url","sourceUrl") if q.get(k)),None)
    if not isinstance(url,str) or not url.startswith("https://"):errors.append(ident+": source URL missing")
    if not (q.get("law_target_date") or q.get("applicable_on")):errors.append(ident+": law reference date missing")
    path=q.get("audit_evidence_path")
    f=root/path if isinstance(path,str) and path.startswith("fp2-manabi-sprint/audit/") else None
    if not f or not f.is_file() or git_blob(f.read_bytes())!=q.get("audit_evidence_blob_sha"):
        errors.append(ident+": audit evidence hash mismatch")
    if re.search(r"<script|onerror\s*=|onload\s*=", " ".join([stem or ""]+(opts or [])),re.I):
        errors.append(ident+": active HTML in authored content")
    source_groups[q.get("source_organization","UNSPECIFIED")]+=1
result={"status":"FAIL" if errors else "PASS","canonical":len(bank["questions"]),"selected":len(selected),"reserves":len(reserved),
        "recovered_independent_audit":"180 PASS / 0 FAIL / 0 HOLD","expansion_independent_audit":"298 PASS / 2 FAIL / 0 HOLD (two quarantined; 12 original reserves)",
        "domain_counts":domains,"answer_choice_distribution":answers,
        "primary_authority_distribution":source_groups,
        "modified_selected":sum(q["modified"] is True for q in selected),
        "errors":errors,
        "scope":"structural and recorded evidence/metadata only, not full independent current-law review or rights clearance"}
print(json.dumps(result,ensure_ascii=False,indent=2))
sys.exit(bool(errors))
