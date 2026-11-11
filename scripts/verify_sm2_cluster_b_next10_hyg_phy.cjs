#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../apps/sanitary-manager-2');
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const overlay=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js'];
const ids=['r09-hyg-07','r10-hyg-02','r04-phy-02','r04-phy-07','r05-phy-02','r05-phy-07','r06-phy-02','r06-phy-07','r07-phy-02','r07-phy-07'].map(x=>'sm2-5y-'+x);
const norm=s=>String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
assert.equal(ids.length,10);
for(const [mode,files] of [['browser',[...base,'difficulty-patch-v5.js',...overlay]],['release-export',[...base,...overlay]]]){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const file of files)vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),ctx,{filename:file});
 const correct=new Map(ids.map(id=>{const q=ctx.window.Q_PARTS.find(x=>x.id===id);assert.ok(q,id);return [id,q.choices[q.answer-1]];}));
 vm.runInContext(fs.readFileSync(path.join(root,'question-order-v1.js'),'utf8'),ctx,{filename:'question-order-v1.js'});
 const qs=ctx.window.Q_PARTS;
 assert.equal(qs.length,300);assert.equal(new Set(qs.map(q=>q.id)).size,300);
 const uniqueStems=new Set(qs.map(q=>norm(q.question))), seen=new Set();
 for(const id of ids){
  const q=qs.find(x=>x.id===id);assert.ok(q,id);
  assert.equal(q.stemRedesignBatch,'2026-11-11-cluster-B-next10-hyg-phy',id);
  assert.equal(q.subject,id.includes('-hyg-')?'労働衛生':'労働生理',id);
  assert.equal(q.difficultyModel,'mechanism-scenario-v2',id);
  assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5,id);
  assert.equal(q.choices[q.answer-1],correct.get(id),id+' answer changed by shuffle');
  assert.ok(q.question.length>=25&&q.explanation.length>=25&&q.sourceUrl.startsWith('https://'),id);
  assert.ok(!seen.has(norm(q.question)),id+' repeated stem');seen.add(norm(q.question));
 }
 assert.equal(uniqueStems.size,mode==='browser'?186:300);
 const counts=new Map();for(const q of qs){const n=norm(q.question);counts.set(n,(counts.get(n)||0)+1);}
 const dupe=[...counts.values()].filter(n=>n>1).sort((a,b)=>b-a);
 if(mode==='browser')assert.deepEqual(dupe,[38,38,37,5]);else assert.deepEqual(dupe,[]);
 const sets=new Map();for(const q of qs){const k=q.examSet+'|'+q.subject;sets.set(k,[...(sets.get(k)||[]),q]);}
 assert.equal(sets.size,30);
 for(const [key,items] of sets){assert.equal(items.length,10,key);const p=[0,0,0,0,0];for(const q of items){assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5);assert.ok(q.answer>=1&&q.answer<=5);p[q.answer-1]++;}assert.ok(p.every(n=>n===2),key+' '+p);}
 console.log('PASS',JSON.stringify({mode,questions:300,redesigned:10,uniqueStems:uniqueStems.size,duplicateClusters:dupe,clusterBRemaining:mode==='browser'?5:0}));
}
