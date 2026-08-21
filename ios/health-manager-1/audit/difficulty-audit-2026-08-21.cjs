'use strict';
const fs=require('fs');
const path=require('path');
const qpath=path.join(__dirname,'..','Resources','questions.json');
const qs=JSON.parse(fs.readFileSync(qpath,'utf8'));
const extreme=/(だけ|一切|全て|必ず|絶対|自由に|不要|なくてよい|しなくてよい)/;
const unrelated=/(普通救命|防火管理|潜水士免許|危険物乙4|産業医研修|市区町村|労働者代表の同意|一般作業帽|保護クリーム)/;
const rows=[];
for(const q of qs){
  let score=0; const reasons=[];
  const choices=q.choices||[];
  const wrong=choices.filter((_,i)=>i!==q.ans);
  const ex=wrong.filter(x=>extreme.test(String(x))).length;
  const ur=wrong.filter(x=>unrelated.test(String(x))).length;
  if(ex>=2){score+=2;reasons.push(`extreme_wrong=${ex}`)}
  if(ur>=1){score+=3;reasons.push(`unrelated_wrong=${ur}`)}
  const lens=choices.map(x=>String(x).length); const al=lens[q.ans]||0;
  const avg=lens.reduce((a,b)=>a+b,0)/Math.max(1,lens.length);
  if(al>avg*1.8 && al>=18){score+=1;reasons.push('answer_length_cue')}
  if((q.stem||'').length<24 && /どれか|何年|頻度|必要な/.test(q.stem||'')){score+=1;reasons.push('short_direct_recall')}
  if(wrong.some(x=>/衛生管理者自体を選任しなくてよい|事後報告だけ|届出だけ/.test(String(x)))){score+=3;reasons.push('obvious_dummy')}
  rows.push({id:q.id,round:q.round,label:q.label,score,reasons,stem:q.stem,choices:q.choices,ans:q.ans});
}
const flagged=rows.filter(r=>r.score>=2).sort((a,b)=>b.score-a.score||a.id.localeCompare(b.id));
const severe=rows.filter(r=>r.score>=4);
const report={generatedAt:'2026-08-21',total:qs.length,flagged:flagged.length,severe:severe.length,policy:'difficulty-policy-2026-08-21.md',items:flagged};
fs.writeFileSync(path.join(__dirname,'DIFFICULTY_AUDIT_2026-08-21.json'),JSON.stringify(report,null,2)+'\n');
const compact=flagged.map(r=>`${r.score}\t${r.id}\t${r.label}\t${r.stem}\t${r.choices.map((x,i)=>`${i===r.ans?'*':''}${i+1}:${String(x).replace(/\t|\n/g,' ')}`).join(' || ')}`).join('\n')+'\n';
fs.writeFileSync(path.join(__dirname,'DIFFICULTY_FLAGGED_2026-08-21.tsv'),compact);
console.log(`HM1 difficulty audit total=${qs.length} flagged=${flagged.length} severe=${severe.length}`);
if(severe.length) process.exitCode=2;
