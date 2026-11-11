#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../apps/sanitary-manager-2');
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const overlays=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js'];
const ids=['r06-phy-10','r07-phy-05','r07-phy-10','r08-phy-10','r09-phy-05','r09-phy-10','r10-phy-05','r10-phy-10'].map(s=>'sm2-5y-'+s);
const norm=s=>String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
for(const [mode,files] of [['browser',[...base,'difficulty-patch-v5.js',...overlays]],['release-export',[...base,...overlays]]]){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const file of files)vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),ctx,{filename:file});
 const truth=new Map(ids.map(id=>{const q=ctx.window.Q_PARTS.find(x=>x.id===id);assert.ok(q,id);return [id,q.choices[q.answer-1]];}));
 vm.runInContext(fs.readFileSync(path.join(root,'question-order-v1.js'),'utf8'),ctx,{filename:'question-order-v1.js'});
 const qs=ctx.window.Q_PARTS;assert.equal(qs.length,300);assert.equal(new Set(qs.map(q=>q.id)).size,300);
 const stems=new Set();
 for(const id of ids){
  const q=qs.find(x=>x.id===id);assert.ok(q,id);assert.equal(q.subject,'労働生理');
  assert.equal(q.stemRedesignBatch,'2026-11-11-cluster-C-final8-phy',id);
  assert.equal(q.difficultyModel,'physiological-scenario-v2',id);
  assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5,id);
  assert.equal(q.choices[q.answer-1],truth.get(id),id+' correct option changed');
  assert.ok(q.question.length>=25&&q.explanation.length>=25&&q.sourceUrl.startsWith('https://'),id);
  assert.ok(!stems.has(norm(q.question)),id+' repeated stem');stems.add(norm(q.question));
 }
 const counts=new Map();for(const q of qs){const k=norm(q.question);counts.set(k,(counts.get(k)||0)+1);}
 const duplicates=[...counts.values()].filter(n=>n>1).sort((a,b)=>b-a);
 assert.equal(counts.size,mode==='browser'?284:300);
 if(mode==='browser')assert.deepEqual(duplicates,[17]);else assert.deepEqual(duplicates,[]);
 assert.equal(qs.filter(q=>norm(q.question)===norm('次の5つの対応関係のうち、正しいものはどれか。')).length,0,'cluster C common stem remains');
 const groups=new Map();for(const q of qs){const key=q.examSet+'|'+q.subject;groups.set(key,[...(groups.get(key)||[]),q]);}
 assert.equal(groups.size,30);
 for(const [key,group] of groups){assert.equal(group.length,10,key);const pos=[0,0,0,0,0];for(const q of group){assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5);assert.ok(q.answer>=1&&q.answer<=5);pos[q.answer-1]++;}assert.ok(pos.every(x=>x===2),key+' positions '+pos);}
 console.log('PASS',JSON.stringify({mode,questions:qs.length,clusterCFinalEight:8,clusterCRemaining:0,uniqueStems:counts.size,duplicates}));
}
