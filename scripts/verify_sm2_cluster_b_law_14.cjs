#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict'),fs=require('fs'),path=require('path'),vm=require('vm');
const web=path.resolve(__dirname,'../apps/sanitary-manager-2');
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const patches=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js'];
const ids=Array.from({length:7},(_,n)=>['02','07'].map(s=>'sm2-5y-r'+String(n+4).padStart(2,'0')+'-law-'+s)).flat();
const normalize=s=>String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
assert.equal(ids.length,14);
for(const [mode,files] of [['browser',[...base,'difficulty-patch-v5.js',...patches]],['release-export',[...base,...patches]]]){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const f of files)vm.runInContext(fs.readFileSync(path.join(web,f),'utf8'),ctx,{filename:f});
 const before=ctx.window.Q_PARTS,correct=new Map(ids.map(id=>{const q=before.find(q=>q.id===id);assert.ok(q,id);return [id,q.choices[q.answer-1]]}));
 vm.runInContext(fs.readFileSync(path.join(web,'question-order-v1.js'),'utf8'),ctx);
 const qs=ctx.window.Q_PARTS;
 assert.equal(qs.length,300);assert.equal(new Set(qs.map(q=>q.id)).size,300);
 const seen=new Set();
 for(const id of ids){
  const q=qs.find(x=>x.id===id);assert.ok(q,id);
  assert.equal(q.subject,'関係法令');assert.equal(q.difficultyModel,'statutory-application-v2');
  assert.equal(q.stemRedesignBatch,id.match(/-r0[45]-/)?'2026-11-11-cluster-B-law-first4':'2026-11-11-cluster-B-law-next10');
  assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5,id);
  assert.equal(q.choices[q.answer-1],correct.get(id),id+' order changed answer');
  assert.ok(q.question.length>=25&&q.explanation.length>=25&&q.sourceUrl.startsWith('https://'),id);
  const stem=normalize(q.question);assert.ok(!seen.has(stem),id+' repeated stem');seen.add(stem);
 }
 const groups=new Map();
 for(const q of qs){const k=q.examSet+'|'+q.subject;const list=groups.get(k)||[];list.push(q);groups.set(k,list);}
 assert.equal(groups.size,30);
 for(const [k,list] of groups){assert.equal(list.length,10,k);const count=[0,0,0,0,0];for(const q of list){assert.equal(q.choices.length,5);count[q.answer-1]++;}assert.ok(count.every(n=>n===2),k+': '+count);}
 const all=new Set(qs.map(q=>normalize(q.question)));
 assert.equal(all.size,mode==='browser'?210:300);
 console.log('PASS',JSON.stringify({mode,questions:qs.length,clusterBLawRedesigned:14,uniqueStems:all.size}));
}
