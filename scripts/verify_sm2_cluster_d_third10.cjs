#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../apps/sanitary-manager-2');
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const patches=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js'];
const ids=['r07-hyg-04','r07-hyg-09','r08-hyg-04','r08-hyg-09','r09-hyg-04','r10-hyg-04','r10-hyg-09','r04-phy-04','r04-phy-09','r05-phy-04'].map(s=>'sm2-5y-'+s);
const norm=s=>String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
assert.equal(ids.length,10);
for(const [mode,files] of [['browser',[...base,'difficulty-patch-v5.js',...patches]],['release-export',[...base,...patches]]]){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const file of files)vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),ctx,{filename:file});
 const initial=new Map(ids.map(id=>{const q=ctx.window.Q_PARTS.find(x=>x.id===id);assert.ok(q,id);return [id,q.choices[q.answer-1]];}));
 vm.runInContext(fs.readFileSync(path.join(root,'question-order-v1.js'),'utf8'),ctx,{filename:'question-order-v1.js'});
 const qs=ctx.window.Q_PARTS;
 assert.equal(qs.length,300);assert.equal(new Set(qs.map(q=>q.id)).size,300);
 const replaced=new Set();
 for(const id of ids){
  const q=qs.find(q=>q.id===id);assert.equal(q.subject,id.includes('-hyg-')?'労働衛生':'労働生理',id);
  assert.equal(q.stemRedesignBatch,'2026-11-11-cluster-D-third10-hyg-phy',id);
  assert.equal(q.difficultyModel,'workplace-physiology-scenario-v2',id);
  assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5,id);
  assert.equal(q.choices[q.answer-1],initial.get(id),id+' answer changed by ordering');
  assert.ok(q.question.length>=25&&q.explanation.length>=25&&q.sourceUrl.startsWith('https://'),id);
  assert.ok(!replaced.has(norm(q.question)),id+' duplicate stem inside batch');replaced.add(norm(q.question));
 }
 const groups=new Map();for(const q of qs){const key=q.examSet+'|'+q.subject;groups.set(key,[...(groups.get(key)||[]),q]);}
 assert.equal(groups.size,30);
 for(const [key,group] of groups){assert.equal(group.length,10,key);const counts=[0,0,0,0,0];for(const q of group){assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5);assert.ok(q.answer>=1&&q.answer<=5);counts[q.answer-1]++;}assert.ok(counts.every(n=>n===2),key+' answer distribution '+counts);}
 const stems=new Map();for(const q of qs){const s=norm(q.question);stems.set(s,(stems.get(s)||0)+1);}
 const duplicates=[...stems.values()].filter(n=>n>1).sort((a,b)=>b-a);
 assert.equal(stems.size,mode==='browser'?274:300);
 if(mode==='browser')assert.deepEqual(duplicates,[27]);else assert.deepEqual(duplicates,[]);
 console.log('PASS',JSON.stringify({mode,questions:qs.length,clusterDThird10:ids.length,uniqueStems:stems.size,duplicateClusterSizes:duplicates,clusterDRemaining:mode==='browser'?8:0}));
}
