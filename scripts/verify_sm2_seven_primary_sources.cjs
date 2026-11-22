#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const web=path.resolve(__dirname,'../apps/sanitary-manager-2');
const ids=['sm2-demo-015','sm2-r7o-015','sm2-r7a-016','sm2-5y-r10-hyg-07','sm2-demo-014','sm2-5y-r05-hyg-01','sm2-r7o-013'];
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const overlays=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js','question-order-v1.js'];
for(const [mode,files] of [['browser',[...base,'difficulty-patch-v5.js',...overlays]],['release-export',[...base,...overlays]]]){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const file of files)vm.runInContext(fs.readFileSync(path.join(web,file),'utf8'),ctx,{filename:file});
 const qs=ctx.window.Q_PARTS;
 assert.equal(qs.length,300,mode+' question count');
 assert.equal(new Set(qs.map(q=>q.id)).size,300,mode+' duplicate ID');
 const normalized=s=>String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
 const uniqueAllStems=new Set(qs.map(q=>normalized(q.question))).size;
 console.log('INFO',mode,'unique question stems globally',uniqueAllStems,'/300; pre-existing generated stems require separate remediation');
 const groups=new Map();
 for(const q of qs){
   const key=q.examSet+'|'+q.subject;
   groups.set(key,[...(groups.get(key)||[]),q]);
 }
 assert.equal(groups.size,30);
 for(const [key,items] of groups){
   assert.equal(items.length,10,key+' count');
   const pos=[0,0,0,0,0];
   for(const q of items){
     assert.equal(q.choices.length,5,q.id);
     assert.equal(new Set(q.choices).size,5,q.id);
     assert.ok(q.answer>=1&&q.answer<=5,q.id);
     pos[q.answer-1]++;
   }
   assert.ok(pos.every(n=>n===2),key+' distribution: '+pos);
 }
 const scopedStems=ids.map(id=>normalized(qs.find(q=>q.id===id).question));
 assert.equal(new Set(scopedStems).size,7,mode+' amended item duplicate stems');
 for(const id of ids){
   const q=qs.find(x=>x.id===id);
   assert.ok(q,mode+' missing '+id);
   assert.equal(q.primarySourceVerified,'2026-11-10',id);
   assert.equal(q.baselineDate,'2026-11-10',id);
   assert.ok(q.sourceUrl.startsWith('https://'),id);
   assert.ok(q.quick.length>15&&q.explanation.length>40,id);
   assert.ok(q.choices[q.answer-1],id);
   if(q.fiveYearExpansion)assert.equal(q.auditStatus,q.lawRelated?'一次資料照合済':'内容監査済',id);
 }
 const co2=qs.find(q=>q.id==='sm2-r7o-013');
 assert.match(co2.choices[co2.answer-1],/5,000ppm以下.*1,000ppm以下/);
 const et=qs.find(q=>q.id==='sm2-5y-r05-hyg-01');
 assert.match(et.choices[et.answer-1],/気温・湿度・気流/);
 for(const id of ids.filter(x=>!x.includes('demo')&&x!=='sm2-r7o-013')){
  assert.ok(qs.find(q=>q.id===id).choices.length===5,id);
 }
 console.log('PASS',mode,'300 questions / 30 groups; seven amended questions verified');
}
