'use strict';
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('node:assert/strict');
const IOS_DIR=__dirname,WEB=path.resolve(IOS_DIR,'../../apps/sanitary-manager-2');
const qs=global.window?.Q_PARTS;
if(!Array.isArray(qs)||qs.length!==300)throw Error('HM2 canonical 300-question corpus missing');
const stat=global.window.SM2_DIFFICULTY_PATCH_V5||{};
assert.equal(stat.generatedQuestions,210);
assert.equal(stat.manualQuestions,40);
assert.equal(stat.coveredQuestions,250);
assert.equal(qs.filter(q=>q.noCommonSenseShortcut===true&&q.difficultyModel).length,250);
const revised=qs.filter(q=>q.fiveYearExpansion&&q.stemRedesignBatch);
assert.equal(revised.length,192,'A-E cluster rewrites must remain applied');
const norm=s=>String(s).replace(/[\\s\\p{P}\\p{S}]/gu,'').toLowerCase();
assert.equal(new Set(qs.map(q=>norm(q.question))).size,300,'canonical stems must be unique');
for(const q of qs){
 assert.equal(q.choices.length,5,q.id);
 assert.equal(new Set(q.choices).size,5,q.id);
 assert.ok(q.answer>=1&&q.answer<=5,q.id);
 if(q.fiveYearExpansion&&!q.stemRedesignBatch){
  assert.equal(q.difficultyModel,'exam-paired-judgment-v1',q.id);
  assert.ok(q.choices.every(c=>c.includes(' ― ')),q.id);
  assert.ok(q.choices[q.answer-1].startsWith(q.topic+' ― '),q.id);
 }
}
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const patches=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js','question-order-v1.js'];
const load=(browser)=>{
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const name of [...base,...(browser?['difficulty-patch-v5.js']:[]),...patches])
  vm.runInContext(fs.readFileSync(path.join(WEB,name),'utf8'),ctx,{filename:name});
 return ctx.window.Q_PARTS;
};
const browser=load(true),release=load(false);
const rById=new Map(release.map(q=>[q.id,q]));
const fields=['question','choices','answer','quick','explanation'];
const drift=[];
for(const b of browser){
 const r=rById.get(b.id);if(!r){drift.push(b.id+':missing');continue;}
 for(const key of fields)if(JSON.stringify(b[key])!==JSON.stringify(r[key]))drift.push(b.id+':'+key);
}
assert.deepEqual(drift,[],'browser/release content drift: '+drift.join(', '));
const bById=new Map(browser.map(q=>[q.id,q]));
for(const q of qs){
 const b=bById.get(q.id);
 for(const key of fields)assert.deepEqual(q[key],b[key],q.id+':'+key);
}
const file=path.join(IOS_DIR,'release-questions.json');
const exported=JSON.parse(fs.readFileSync(file,'utf8'));
assert.equal(exported.length,300);
assert.equal(new Set(exported.map(q=>q.id)).size,300);
for(const q of exported){
 const original=bById.get(q.id);
 assert.ok(original,q.id);
 assert.equal(q.question,original.question,q.id);
 assert.deepEqual(q.choices,Array.from(original.choices),q.id);
 assert.equal(q.correct_index,original.answer-1,q.id);
 assert.equal(q.quick,original.quick,q.id);
 assert.equal(q.explanation,original.explanation,q.id);
}
console.log('PASS: canonical 300 questions, 192 cluster rewrites, browser/release parity and exported JSON exact match.');
