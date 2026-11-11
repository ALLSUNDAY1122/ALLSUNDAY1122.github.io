#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../apps/sanitary-manager-2');
const files=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const overlays=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js'];
const ids=['r09-law-10','r10-law-05','r10-law-10','r04-hyg-05','r04-hyg-10','r05-hyg-05','r05-hyg-10','r06-hyg-05','r06-hyg-10','r07-hyg-05'].map(x=>'sm2-5y-'+x);
const norm=s=>String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
for(const [mode,inputs] of [['browser',[...files,'difficulty-patch-v5.js',...overlays]],['release-export',[...files,...overlays]]]){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const f of inputs)vm.runInContext(fs.readFileSync(path.join(root,f),'utf8'),ctx,{filename:f});
 const truths=new Map(ids.map(id=>{const q=ctx.window.Q_PARTS.find(x=>x.id===id);assert.ok(q,id);return [id,q.choices[q.answer-1]];}));
 vm.runInContext(fs.readFileSync(path.join(root,'question-order-v1.js'),'utf8'),ctx,{filename:'question-order-v1.js'});
 const qs=ctx.window.Q_PARTS;
 assert.equal(qs.length,300);assert.equal(new Set(qs.map(x=>x.id)).size,300);
 const seen=new Set();
 for(const id of ids){
  const q=qs.find(x=>x.id===id);
  assert.equal(q.subject,id.includes('-law-')?'関係法令':'労働衛生',id);
  assert.equal(q.stemRedesignBatch,'2026-11-11-cluster-C-next10-law-hyg',id);
  assert.equal(q.difficultyModel,'scenario-quantitative-v2',id);
  assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5,id);
  assert.equal(q.choices[q.answer-1],truths.get(id),id+' correct answer changed');
  assert.ok(q.question.length>=25&&q.explanation.length>=25&&q.sourceUrl.startsWith('https://'),id);
  assert.ok(!seen.has(norm(q.question)),id+' repeated stem');seen.add(norm(q.question));
 }
 const groups=new Map();for(const q of qs){const k=q.examSet+'|'+q.subject;groups.set(k,[...(groups.get(k)||[]),q]);}
 assert.equal(groups.size,30);
 for(const [k,g] of groups){assert.equal(g.length,10,k);const n=[0,0,0,0,0];for(const q of g){assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5);n[q.answer-1]++;}assert.ok(n.every(x=>x===2),k+' '+n);}
 const counts=new Map();for(const q of qs){const k=norm(q.question);counts.set(k,(counts.get(k)||0)+1);}
 const duplicateSizes=[...counts.values()].filter(x=>x>1).sort((a,b)=>b-a);
 assert.equal(counts.size,mode==='browser'?274:300);
 if(mode==='browser')assert.deepEqual(duplicateSizes,[27]);else assert.deepEqual(duplicateSizes,[]);
 console.log('PASS',JSON.stringify({mode,questionCount:qs.length,clusterCSecondBatch:10,uniqueStems:counts.size,duplicateSizes,clusterCRemaining:0}));
}
