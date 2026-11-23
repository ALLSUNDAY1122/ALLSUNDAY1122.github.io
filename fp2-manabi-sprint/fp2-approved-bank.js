/* Canonical FP2 content-review bank adapter. Never equate content PASS with release approval. */
(function(global){
"use strict";
const SOURCE="questions/canonical/approved-questions-20261123.json";
const isApproved=q=>Boolean(q && q.approved_for_content_bank===true && q.independent_audit_status==="PASS" && q.release_selected===true);
const pick=(...xs)=>xs.find(x=>typeof x==="string"&&x.trim())||"";
function normalize(q){
 const raw=q.choices||q.options||[];
 if(!Array.isArray(raw))return null;
 const choices=raw.map(v=>typeof v==="string"?v:(v&&v.text)||"");
 const correct=Number.isInteger(q.answer_index)?q.answer_index:Number.isInteger(q.correct_index)?q.correct_index:typeof q.a==="number"?q.a:raw.findIndex(v=>v && typeof v==="object"&&v.correct===true);
 if(!q.id||!pick(q.stem,q.question,q.q)||choices.length<2||choices.some(v=>typeof v!=="string"||!v.trim())||correct<0||correct>=choices.length)return null;
 return {
  id:q.id,domain:pick(q.domain,q.category,"その他"),exam_session:pick(q.exam_year_month,q.examDate,q.exam_date),
  exam_type:pick(q.exam_type,q.examType,q.source_exam_type),q:pick(q.stem,q.question,q.q),c:choices,a:correct,
  m:pick(q.memory,q.key_point,q.explanation),r:pick(q.reason,q.explanation),d:pick(q.detail,q.explanation),
  source_organization:pick(q.source_organization,q.attribution_display,q.origin_type==="original_from_primary_source"?"制度の公式一次資料（独自作成問題）":""),
  source_url:pick(q.source_original_question_url,q.source_question_url,q.primary_source_url,q.source_url,q.sourceUrl,q.primary_law_url),
  source_section:pick(q.source_section,q.primary_law_section),
  modified:q.modified,modification_note:pick(q.modification_note),
  legal_cutoff:pick(q.law_target_date,q.applicable_on,q.legal_cutoff_target),
  original_law_date:pick(q.source_original_law_date,q.original_exam_applicable_on,q.legalReferenceDate),
  rights_status:pick(q.rights_review_status,q.release_gate_status),
  data_version:pick(q.dataVersion)
 };
}
async function load(){
 const response=await fetch(SOURCE,{cache:"no-store"});
 if(!response.ok)throw new Error("Canonical bank HTTP "+response.status);
 const body=await response.json();
 if(!body || !Array.isArray(body.questions))throw new Error("Canonical bank structure invalid");
 if(body.content_approved_questions!==body.questions.length)throw new Error("Canonical approved count mismatch");
 const seen=new Set(),items=[];
 for(const q of body.questions){
  if(!isApproved(q))continue;
  const normalized=normalize(q);
  if(!normalized)throw new Error("Invalid approved question "+String(q.id));
  if(seen.has(q.id))throw new Error("Duplicate approved question "+q.id);
  seen.add(q.id);items.push(normalized);
 }
 if(body.release_candidate_questions!==items.length)throw new Error("Release candidate count mismatch");
 const domains=new Map();for(const x of items)domains.set(x.domain,(domains.get(x.domain)||0)+1);
 if(items.length!==298||domains.size!==6||[...domains.values()].sort((a,b)=>a-b).join(',')!=='48,50,50,50,50,50')throw new Error("Release selection must be 298 official questions in six domains");
 return {items,path:SOURCE,contentApproved:body.content_approved_questions,publishable:body.publishable_questions===items.length&&body.status==="RELEASE_APPROVED",releaseStatus:body.status};
}
global.FP2ApprovedBank={load,normalize,isApproved,SOURCE};
})(window);
