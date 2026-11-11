#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict'),fs=require('fs'),path=require('path'),vm=require('vm');
const root=path.resolve(__dirname,'../apps/sanitary-manager-2');
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const patches=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js'];
const ids=['r04-law-05','r04-law-10','r05-law-05','r06-law-05','r06-law-10','r07-law-05','r07-law-10','r08-law-05','r08-law-10','r09-law-05'].map(x=>'sm2-5y-'+x);
const norm=s=>String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
for(const [mode,files] of [['browser',[...base,'difficulty-patch-v5.js',...patches]],['release-export',[...base,...patches]]]){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const file of files)vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),ctx,{filename:file});
 const truths=new Map(ids.map(id=>{const q=ctx.window.Q_PARTS.find(x=>x.id===id);assert.ok(q,id);return [id,q.choices[q.answer-1]];}));
 vm.runInContext(fs.readFileSync(path.join(root,'question-order-v1.js'),'utf8'),ctx);
 const qs=ctx.window.Q_PARTS;
 assert.equal(qs.length,300);assert.equal(new Set(qs.map(q=>q.id)).size,300);
 const stems=new Set(),groups=new Map();
 for(const q of qs){const k=q.examSet+'|'+q.subject;groups.set(k,[...(groups.get(k)||[]),q]);}
 assert.equal(groups.size,30);
 for(const [k,group] of groups){assert.equal(group.length,10,k);const pos=[0,0,0,0,0];for(const q of group){assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5);assert.ok(q.answer>=1&&q.answer<=5);pos[q.answer-1]++;}assert.ok(pos.every(n=>n===2),k+' '+pos);}
 for(const id of ids){
  const q=qs.find(x=>x.id===id);assert.equal(q.subject,'関係法令',id);
  assert.equal(q.stemRedesignBatch,'2026-11-11-cluster-C-law-first10',id);
  assert.equal(q.difficultyModel,'scenario-numeric-legal-v2',id);
  assert.equal(q.choices[q.answer-1],truths.get(id),id+' answer moved');
  assert.ok(q.question.length>=25&&q.explanation.length>=25&&q.sourceUrl.startsWith('https://'),id);
  assert.ok(!stems.has(norm(q.question)),id+' duplicate redesigned stem');stems.add(norm(q.question));
 }
 const counts=new Map();for(const q of qs){const k=norm(q.question);counts.set(k,(counts.get(k)||0)+1);}
 const duplicateSizes=[...counts.values()].filter(n=>n>1).sort((a,b)=>b-a);
 assert.equal(counts.size,mode==='browser'?264:300);
 if(mode==='browser')assert.deepEqual(duplicateSizes,[37]);else assert.deepEqual(duplicateSizes,[]);
 console.log('PASS',JSON.stringify({mode,questions:qs.length,redesignedC:10,uniqueStems:counts.size,duplicateSizes,clusterCRemaining:0}));
}
