#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('node:assert/strict');
const web=path.resolve(__dirname,'../apps/sanitary-manager-2');
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const overlay=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js'];
const ids=['r04-02','r04-07','r05-02','r05-07','r06-02','r07-02','r07-07','r08-02','r08-07','r09-02'].map(v=>'sm2-5y-'+v.slice(0,3)+'-hyg-'+v.slice(4));
const norm=s=>String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
for(const [mode,files] of [['browser',[...base,'difficulty-patch-v5.js',...overlay]],['release-export',[...base,...overlay]]]){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const file of files)vm.runInContext(fs.readFileSync(path.join(web,file),'utf8'),ctx,{filename:file});
 const before=ctx.window.Q_PARTS;
 const correct=new Map(ids.map(id=>{const q=before.find(x=>x.id===id);assert.ok(q,id);return [id,q.choices[q.answer-1]];}));
 vm.runInContext(fs.readFileSync(path.join(web,'question-order-v1.js'),'utf8'),ctx,{filename:'question-order-v1.js'});
 const out=ctx.window.Q_PARTS;
 assert.equal(out.length,300);
 assert.equal(new Set(out.map(q=>q.id)).size,300);
 const stems=new Set();
 for(const id of ids){const q=out.find(q=>q.id===id);assert.equal(q.stemRedesignBatch,'2026-11-11-cluster-B-hyg-first10',id);assert.equal(q.subject,'労働衛生');assert.equal(q.difficultyModel,'hygiene-scenario-v2');assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5);assert.equal(q.choices[q.answer-1],correct.get(id));assert.ok(q.question.length>=25&&q.explanation.length>=25&&q.sourceUrl.startsWith('https://'));assert.ok(!stems.has(norm(q.question)));stems.add(norm(q.question));}
 const clusters=new Map();for(const q of out)clusters.set(norm(q.question),(clusters.get(norm(q.question))||0)+1);
 const duplicateSizes=[...clusters.values()].filter(x=>x>1).sort((a,b)=>b-a);
 assert.equal(clusters.size,mode==='browser'?284:300);
 if(mode==='browser')assert.deepEqual(duplicateSizes,[17]);else assert.deepEqual(duplicateSizes,[]);
 const groups=new Map();for(const q of out){const key=q.examSet+'|'+q.subject;groups.set(key,[...(groups.get(key)||[]),q]);}
 assert.equal(groups.size,30);
 for(const [key,group] of groups){assert.equal(group.length,10,key);const counts=[0,0,0,0,0];for(const q of group){assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5);assert.ok(q.answer>=1&&q.answer<=5);counts[q.answer-1]++;}assert.ok(counts.every(x=>x===2),key+' positions '+counts);}
 console.log('PASS',JSON.stringify({mode,questions:300,newBHygeineCases:10,uniqueStems:clusters.size,duplicateSizes,clusterBRemaining:0}));
}
