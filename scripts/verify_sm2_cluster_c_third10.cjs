#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../apps/sanitary-manager-2');
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const patches=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js'];
const ids=['r07-hyg-10','r08-hyg-05','r08-hyg-10','r09-hyg-05','r10-hyg-05','r10-hyg-10','r04-phy-05','r04-phy-10','r05-phy-05','r05-phy-10'].map(s=>'sm2-5y-'+s);
const norm=s=>String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
for(const [mode,files] of [['browser',[...base,'difficulty-patch-v5.js',...patches]],['release-export',[...base,...patches]]]){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const file of files)vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),ctx,{filename:file});
 const originalCorrect=new Map(ids.map(id=>{const q=ctx.window.Q_PARTS.find(x=>x.id===id);assert.ok(q,id);return [id,q.choices[q.answer-1]];}));
 vm.runInContext(fs.readFileSync(path.join(root,'question-order-v1.js'),'utf8'),ctx,{filename:'question-order-v1.js'});
 const qs=ctx.window.Q_PARTS;
 assert.equal(qs.length,300);assert.equal(new Set(qs.map(q=>q.id)).size,300);
 const newStems=new Set();
 for(const id of ids){
  const q=qs.find(x=>x.id===id);assert.ok(q,id);
  assert.equal(q.subject,id.includes('-hyg-')?'労働衛生':'労働生理',id);
  assert.equal(q.stemRedesignBatch,'2026-11-11-cluster-C-third10-hyg-phy',id);
  assert.equal(q.difficultyModel,'applied-mechanism-scenario-v2',id);
  assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5,id);
  assert.equal(q.choices[q.answer-1],originalCorrect.get(id),id+' correct choice changed after ordering');
  assert.ok(q.question.length>=25&&q.explanation.length>=25&&q.sourceUrl.startsWith('https://'),id);
  assert.ok(!newStems.has(norm(q.question)),id+' duplicate in redesigned batch');newStems.add(norm(q.question));
 }
 const groups=new Map();
 for(const q of qs){const k=q.examSet+'|'+q.subject;groups.set(k,[...(groups.get(k)||[]),q]);}
 assert.equal(groups.size,30);
 for(const [k,list] of groups){assert.equal(list.length,10,k);const p=[0,0,0,0,0];for(const q of list){assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5);assert.ok(q.answer>=1&&q.answer<=5);p[q.answer-1]++;}assert.ok(p.every(n=>n===2),k+' positions '+p);}
 const stems=new Map();for(const q of qs){const k=norm(q.question);stems.set(k,(stems.get(k)||0)+1);}
 const duplicates=[...stems.values()].filter(n=>n>1).sort((a,b)=>b-a);
 assert.equal(stems.size,mode==='browser'?227:300);
 if(mode==='browser')assert.deepEqual(duplicates,[38,37]);else assert.deepEqual(duplicates,[]);
 console.log('PASS',JSON.stringify({mode,total:qs.length,redesignedCThird10:10,uniqueStems:stems.size,remainingClusters:duplicates,clusterCRemaining:0}));
}
