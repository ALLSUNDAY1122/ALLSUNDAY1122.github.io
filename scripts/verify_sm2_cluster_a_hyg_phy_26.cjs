#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('node:assert/strict');
const web=path.resolve(__dirname,'../apps/sanitary-manager-2');
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const middle=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js'];
const targets={
 hyg:['r04-01','r04-06','r05-06','r06-01','r07-01','r07-06','r08-01','r08-06','r09-01','r09-06','r10-01','r10-06'],
 phy:['r04-01','r04-06','r05-01','r05-06','r06-01','r06-06','r07-01','r07-06','r08-01','r08-06','r09-01','r09-06','r10-01','r10-06']
};
const ids=Object.entries(targets).flatMap(([p,ss])=>ss.map(s=>'sm2-5y-'+s.slice(0,3)+'-'+p+'-'+s.slice(4)));
assert.equal(ids.length,26);
const norm=s=>String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
for(const [mode,files] of [['browser',[...base,'difficulty-patch-v5.js',...middle]],['release-export',[...base,...middle]]]){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const f of files)vm.runInContext(fs.readFileSync(path.join(web,f),'utf8'),ctx,{filename:f});
 const qs=ctx.window.Q_PARTS;
 assert.equal(qs.length,300);
 const truth=new Map(ids.map(id=>{const q=qs.find(x=>x.id===id);assert.ok(q,id+' missing');return [id,q.choices[q.answer-1]];}));
 vm.runInContext(fs.readFileSync(path.join(web,'question-order-v1.js'),'utf8'),ctx,{filename:'question-order-v1.js'});
 const out=ctx.window.Q_PARTS;
 assert.equal(new Set(out.map(q=>q.id)).size,300);
 const unique=new Set(out.map(q=>norm(q.question)));
 assert.equal(unique.size,mode==='browser'?264:300,mode+' unique count');
 const clusters=new Map();
 for(const q of out)clusters.set(norm(q.question),(clusters.get(norm(q.question))||0)+1);
 const duplicates=[...clusters.values()].filter(n=>n>1).sort((a,b)=>b-a);
 if(mode==='browser')assert.deepEqual(duplicates,[37]);
 else assert.equal(duplicates.length,0);
 const stems=new Set();
 for(const id of ids){
  const q=out.find(x=>x.id===id);
  assert.equal(q.stemRedesignBatch,'2026-11-11-cluster-A-hyg-phy',id);
  assert.equal(q.difficultyModel,'scenario-diagnostic-v2',id);
  assert.equal(q.choices.length,5,id);
  assert.equal(new Set(q.choices).size,5,id+' unique choices');
  assert.equal(q.choices[q.answer-1],truth.get(id),id+' correct choice changed by shuffle');
  assert.ok(q.question.length>=25,id+' stem too short');
  assert.ok(q.explanation.length>=20,id+' explanation too short');
  assert.ok(q.sourceUrl.startsWith('https://'),id+' evidence URL');
  assert.ok(!stems.has(norm(q.question)),id+' duplicate in 26');
  stems.add(norm(q.question));
 }
 assert.equal(stems.size,26);
 for(const group of new Set(out.map(q=>q.examSet+'|'+q.subject))){
  const list=out.filter(q=>q.examSet+'|'+q.subject===group);
  assert.equal(list.length,10,group);
  const n=[0,0,0,0,0];
  list.forEach(q=>{assert.equal(q.choices.length,5,q.id);assert.ok(q.answer>=1&&q.answer<=5,q.id);n[q.answer-1]++});
  assert.ok(n.every(x=>x===2),group+' balance '+n);
 }
 console.log('PASS',JSON.stringify({mode,all:out.length,clusterARewritten:26,uniqueStems:unique.size,remainingDuplicateCases:mode==='browser'?duplicates.reduce((a,b)=>a+b,0):0,duplicateClusterSizes:duplicates}));
}
