'use strict';
(function(){
  if(typeof QUESTIONS==='undefined') throw new Error('QUESTIONS is not loaded');
  const errors=[];
  const warnings=[];
  const expect={total:360,subjects:{'法令':144,'物理・化学':96,'性質・消火':120}};
  const counts={};
  const ids=new Set();
  const exact=new Map();
  const stem=new Map();
  for(const q of QUESTIONS){
    counts[q.subject]=(counts[q.subject]||0)+1;
    if(ids.has(q.id)) errors.push(`duplicate id: ${q.id}`); else ids.add(q.id);
    if(!Array.isArray(q.choices)||q.choices.length!==5) errors.push(`${q.id}: choices != 5`);
    if(new Set(q.choices||[]).size!==5) errors.push(`${q.id}: duplicate choices`);
    if(!Number.isInteger(q.answer)||q.answer<0||q.answer>4) errors.push(`${q.id}: invalid answer index`);
    if(!q.point||!q.detail) errors.push(`${q.id}: missing explanation`);
    if(!q.sourceTitle||!q.sourceURL||!q.sourceCheckedAt) errors.push(`${q.id}: missing source metadata`);
    if(q.subject==='法令' && !q.legalEffectiveDate) errors.push(`${q.id}: missing legalEffectiveDate`);
    const sig=q.question+'\u0000'+(q.choices||[]).join('\u0001')+'\u0000'+q.answer;
    exact.set(sig,(exact.get(sig)||0)+1);
    const ns=q.question.replace(/（比較セット\d+）/g,'').replace(/\s+/g,'').trim();
    stem.set(ns,(stem.get(ns)||0)+1);
  }
  if(QUESTIONS.length!==expect.total) errors.push(`total ${QUESTIONS.length} != ${expect.total}`);
  for(const [s,n] of Object.entries(expect.subjects)) if(counts[s]!==n) errors.push(`${s}: ${counts[s]} != ${n}`);
  const exactDup=[...exact.entries()].filter(([,n])=>n>1);
  if(exactDup.length) errors.push(`exact duplicate question signatures: ${exactDup.length}`);
  const stemDup=[...stem.entries()].filter(([,n])=>n>1);
  if(stemDup.length) warnings.push(`wording variants sharing a stem: ${stemDup.length} groups`);
  const lawSource=QUESTIONS.filter(q=>q.subject==='法令' && /e-gov|fdma|shoubo-shiken/.test((q.sourceURL||'').toLowerCase())).length;
  if(lawSource!==expect.subjects['法令']) warnings.push(`law questions with primary/official URL: ${lawSource}/${expect.subjects['法令']}`);
  const report={ok:errors.length===0,errors,warnings,total:QUESTIONS.length,counts,contentVersion:typeof CONTENT_VERSION==='undefined'?null:CONTENT_VERSION,lawBaseline:typeof LAW_BASELINE==='undefined'?null:LAW_BASELINE,checkedAt:new Date().toISOString()};
  if(typeof window!=='undefined') window.OTSU4_AUDIT_REPORT=report;
  if(typeof console!=='undefined') console.table(counts),console.log('OTSU4_AUDIT_REPORT',report);
  if(errors.length) throw new Error('Otsu4 content audit failed: '+errors.join(' | '));
})();
