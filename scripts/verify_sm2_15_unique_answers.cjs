#!/usr/bin/env node
'use strict';
// Regression check for the 15 historically ambiguous SM2 questions.
// Verify BOTH execution orders: browser (difficulty-v5) and legacy release export.
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const root=path.resolve(__dirname,'..');
const web=path.join(root,'apps/sanitary-manager-2');
const ids=[
 'sm2-5y-r06-hyg-06','sm2-5y-r06-hyg-07','sm2-5y-r06-hyg-08',
 'sm2-5y-r09-hyg-08','sm2-5y-r09-hyg-09','sm2-5y-r09-hyg-10',
 'sm2-5y-r06-phy-03','sm2-5y-r06-phy-04','sm2-5y-r06-phy-05',
 'sm2-5y-r08-phy-03','sm2-5y-r08-phy-04','sm2-5y-r08-phy-05',
 'sm2-5y-r08-phy-07','sm2-5y-r08-phy-08','sm2-5y-r08-phy-09'
];
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const overlays=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js','question-order-v1.js'];
for(const [mode,files] of [
 ['browser',[...base,'difficulty-patch-v5.js',...overlays]],
 ['release-export',[...base,...overlays]]
]){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const file of files)vm.runInContext(fs.readFileSync(path.join(web,file),'utf8'),ctx,{filename:file});
 const qs=ctx.window.Q_PARTS;
 assert.equal(qs.length,300,mode+' total');
 const seen=new Set();
 for(const q of qs){assert.ok(!seen.has(q.id),mode+' duplicated ID '+q.id);seen.add(q.id);}
 const stems=new Set();
 for(const id of ids){
  const q=qs.find(v=>v.id===id);
  assert.ok(q,mode+' missing '+id);
  assert.equal(q.singleAnswerAudit,'2026-11-10-15-items',id);
  assert.equal(q.choices.length,5,id);
  assert.equal(new Set(q.choices).size,5,id);
  assert.ok(Number.isInteger(q.answer)&&q.answer>=1&&q.answer<=5,id);
  assert.ok(q.choices[q.answer-1].startsWith(q.topic+' ― '),id+' correct pair');
  assert.ok(q.explanation.includes(q.choices[q.answer-1]),id+' explanation consistency');
  assert.ok(!stems.has(q.question),id+' duplicated stem');
  stems.add(q.question);
 }
 assert.equal(stems.size,15);
 console.log('PASS',mode,'300 total; 15 IDs, correct indexed pair, 5 distinct choices, 15 unique stems');
}
