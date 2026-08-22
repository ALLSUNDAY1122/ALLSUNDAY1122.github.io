'use strict';
const fs=require('fs');
const path=require('path');
const qpath=path.join(__dirname,'..','Resources','questions.json');
const qs=JSON.parse(fs.readFileSync(qpath,'utf8'));

const absurd=/(虫歯だけ|骨折だけ|胆石だけ|聴力改善|尿を逆流|血液凝固を完全停止|色覚だけ|普通救命講習|防火管理講習|潜水士免許|危険物乙4|産業医研修|市区町村への届出だけ|労働者代表の同意だけ)/;
const absolute=/(だけ|一切|全て|必ず|絶対|不要|なくてよい|しなくてよい|常に)/;
const rows=[];
for(const q of qs){
  let score=0; const reasons=[];
  const choices=q.choices||[];
  if(choices.length!==5){score+=10;reasons.push('choice_count')}
  const wrong=choices.filter((_,i)=>i!==q.ans).map(String);
  const absurdN=wrong.filter(x=>absurd.test(x)).length;
  const shortAbsolute=wrong.filter(x=>x.length<=18 && absolute.test(x)).length;
  if(absurdN){score+=4+Math.min(2,absurdN-1);reasons.push(`absurd_dummy=${absurdN}`)}
  if(shortAbsolute>=2){score+=2;reasons.push(`short_absolute=${shortAbsolute}`)}
  const lens=choices.map(x=>String(x).length), al=lens[q.ans]||0;
  const wrongLens=lens.filter((_,i)=>i!==q.ans).sort((a,b)=>b-a);
  const wavg=wrongLens.reduce((a,b)=>a+b,0)/Math.max(1,wrongLens.length);
  let answerLengthCue=false;
  if(al>=22 && al>wavg*1.65 && al-(wrongLens[0]||0)>=8){score+=2;reasons.push('answer_length_cue');answerLengthCue=true}
  const direct=(q.stem||'').length<25 && /(どれか|何年|何人|頻度|必要な|場所は)/.test(q.stem||'');
  if(direct) reasons.push('direct_recall_review');
  const severe=(choices.length!==5) || absurdN>0 || shortAbsolute>=2 || (answerLengthCue && shortAbsolute>=1);
  rows.push({id:q.id,round:q.round,label:q.label,score,severe,reasons,stem:q.stem,choices:q.choices,ans:q.ans});
}
const flagged=rows.filter(r=>r.score>=2 || r.reasons.includes('direct_recall_review')).sort((a,b)=>Number(b.severe)-Number(a.severe)||b.score-a.score||a.id.localeCompare(b.id));
const severe=rows.filter(r=>r.severe);
const directReview=rows.filter(r=>r.reasons.includes('direct_recall_review')&&!r.severe);
const report={generatedAt:'2026-08-22',total:qs.length,flagged:flagged.length,severe:severe.length,directRecallReview:directReview.length,knowledgeFreeEliminationRisk:severe.length,policy:'difficulty-policy-2026-08-21.md',items:flagged};
fs.writeFileSync(path.join(__dirname,'DIFFICULTY_AUDIT_2026-08-21.json'),JSON.stringify(report,null,2)+'\n');
const compact=flagged.map(r=>`${r.severe?'SEVERE':'REVIEW'}\t${r.score}\t${r.id}\t${r.label}\t${r.stem}\t${r.choices.map((x,i)=>`${i===r.ans?'*':''}${i+1}:${String(x).replace(/\t|\n/g,' ')}`).join(' || ')}`).join('\n')+'\n';
fs.writeFileSync(path.join(__dirname,'DIFFICULTY_FLAGGED_2026-08-21.tsv'),compact);
console.log(`HM1 difficulty audit total=${qs.length} review=${flagged.length} knowledge_free_risk=${severe.length} direct_recall_review=${directReview.length}`);
for(const r of severe) console.log(`BLOCKER\t${r.id}\t${r.reasons.join(',')}\t${r.stem}\t${r.choices.join(' || ')}`);
if(severe.length) process.exitCode=2;
