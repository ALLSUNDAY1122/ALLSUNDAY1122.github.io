import fs from 'node:fs';
import vm from 'node:vm';
const files=['questions.js','sources-v02.js','questions-v02-tb.js','questions-v02-ks1.js','questions-v02-ks2.js','questions-v02-ks3.js','questions-v02-ks4.js','questions-v02-jm1.js','questions-v02-jm2.js','questions-v02-jm3.js','questions-v02-jm4.js','sources-v03.js','questions-v03-tb.js','questions-v03-audit1.js','questions-v03-audit1-order.js','questions-v03-audit1-polish.js','questions-editorial-audit2-7.js'];
const ctx=vm.createContext({console});
for(const f of files)vm.runInContext(fs.readFileSync(new URL(`./${f}`,import.meta.url),'utf8'),ctx,{filename:f});
vm.runInContext('this.__Q=TSUKANSHI_QUESTIONS',ctx);
const Q=ctx.__Q||[],errors=[];const fail=(id,m)=>errors.push(`${id||'GLOBAL'}: ${m}`);
const decl=Q.filter(q=>q.answerType==='declaration'),study=Q.filter(q=>q.answerType!=='declaration');
if(Q.length!==492)fail(null,`expected 492 total, got ${Q.length}`);
if(study.length!==480)fail(null,`expected 480 study, got ${study.length}`);
if(decl.length!==12)fail(null,`expected 12 declarations, got ${decl.length}`);
for(const q of Q){
 if(q.editorialStatus!=='final')fail(q.id,'editorialStatus is not final');
 if(!/^2026-08-0[89]$/.test(q.editorialAuditDate||''))fail(q.id,'editorialAuditDate missing/outside current audit');
 if(String(q.point||'').length<18)fail(q.id,'point too short after final audit');
 if(String(q.detail||'').length<38)fail(q.id,'detail too short after final audit');
 if(!q.publicationAudit)fail(q.id,'publicationAudit missing');
}
const phaseCounts={};for(const q of study)phaseCounts[q.editorialPhase]=(phaseCounts[q.editorialPhase]||0)+1;
for(const [p,n] of [[1,60],[2,60],[3,60],[4,60],[5,55],[6,59],[7,126]])if((phaseCounts[p]||0)!==n)fail(null,`phase ${p} expected ${n}, got ${phaseCounts[p]||0}`);
const legacy=['税関手続とは無関係で、法令上の条件を受けない','輸入者が自由に内容を決め、税関への確認は不要','輸入許可後にしか扱えず、許可前の手続とは関係しない','貨物の所有権を税関へ移すためだけの制度','税関手続では法令の確認は原則不要である','輸出入者は申告内容を任意に省略できる','通関手続では客観資料より担当者の希望を優先する'];
for(const q of Q)for(const p of legacy)if((q.choices||[]).some(c=>String(c).includes(p)))fail(q.id,'legacy generic distractor remains');
for(let n=61;n<=240;n++){const id=`V03-S-${String(n).padStart(3,'0')}`,q=Q.find(x=>x.id===id);if(!q)fail(id,'missing');else{if(q.choices?.length!==4)fail(id,'must have 4 choices');if(!['curated-cross-topic-distractors'].includes(q.editorialMethod))fail(id,'curated distractor method missing');}}
for(let n=1;n<=55;n++){const id=`V03-M-${String(n).padStart(3,'0')}`,q=Q.find(x=>x.id===id);if(!q)fail(id,'missing');else{if(q.choices?.length!==5||q.answers?.length!==2)fail(id,'multi-choice must be 5 choose 2');if(!q.question.includes('対応するものを2つ'))fail(id,'targeted multi-choice stem missing');}}
for(let n=1;n<=59;n++){const id=`JM3N-${String(n).padStart(3,'0')}`,q=Q.find(x=>x.id===id);if(!q)fail(id,'missing');else for(const k of ['式：','代入：','答え：'])if(!q.detail.includes(k))fail(id,`numeric detail missing ${k}`);}
for(const q of decl){if(!Array.isArray(q.declarationFields)||q.declarationFields.length===0)fail(q.id,'declaration fields missing');if(q.editorialPhase!==6)fail(q.id,'declaration must be phase 6');}
const official=Q.filter(q=>q.sourceType==='officialPastExam');if(official.length)fail(null,`official past-exam bodies are bundled before per-PDF rights audit: ${official.length}`);
console.log(`Final editorial audit: ${study.filter(q=>q.editorialStatus==='final').length}/480 study questions`);
console.log(`Declaration editorial audit: ${decl.filter(q=>q.editorialStatus==='final').length}/12 sets`);
console.log('Study phase counts:',JSON.stringify(phaseCounts));
console.log(`Official past-exam bodies bundled: ${official.length}`);
if(errors.length){console.error('\nErrors:');errors.forEach(e=>console.error('- '+e));process.exit(1);}console.log('\nFinal editorial audit passed.');
