#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../apps/sanitary-manager-2');
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const overlay=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js'];
const ids=['sm2-5y-r08-phy-02','sm2-5y-r09-phy-02','sm2-5y-r09-phy-07','sm2-5y-r10-phy-02','sm2-5y-r10-phy-07'];
const norm=s=>String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
for(const [mode,files] of [['browser',[...base,'difficulty-patch-v5.js',...overlay]],['release-export',[...base,...overlay]]]){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const file of files)vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),ctx,{filename:file});
 const truth=new Map(ids.map(id=>{const q=ctx.window.Q_PARTS.find(q=>q.id===id);assert.ok(q,id);return [id,q.choices[q.answer-1]];}));
 vm.runInContext(fs.readFileSync(path.join(root,'question-order-v1.js'),'utf8'),ctx,{filename:'question-order-v1.js'});
 const qs=ctx.window.Q_PARTS;
 assert.equal(qs.length,300);assert.equal(new Set(qs.map(q=>q.id)).size,300);
 const unique=new Set(qs.map(q=>norm(q.question)));
 assert.equal(unique.size,mode==='browser'?220:300);
 const counts=new Map();for(const q of qs){const k=norm(q.question);counts.set(k,(counts.get(k)||0)+1);}
 const duplicates=[...counts.values()].filter(x=>x>1).sort((a,b)=>b-a);
 if(mode==='browser')assert.deepEqual(duplicates,[38,37,8]);else assert.deepEqual(duplicates,[]);
 for(const id of ids){const q=qs.find(q=>q.id===id);assert.equal(q.subject,'労働生理');assert.equal(q.stemRedesignBatch,'2026-11-11-cluster-B-final5-phy');assert.equal(q.difficultyModel,'physiology-mechanism-v2');assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5);assert.equal(q.choices[q.answer-1],truth.get(id),id+' changed answer');assert.ok(q.question.length>=25&&q.explanation.length>=25&&q.sourceUrl.startsWith('https://'));}
 const bOld='次の用語・制度と説明の組合せのうち、適切なものはどれか。';
 assert.equal(qs.filter(q=>norm(q.question)===norm(bOld)).length,0,'cluster B common stem not eliminated');
 const groups=new Map();for(const q of qs){const k=q.examSet+'|'+q.subject;groups.set(k,[...(groups.get(k)||[]),q]);}
 assert.equal(groups.size,30);
 for(const [name,group] of groups){assert.equal(group.length,10,name);const n=[0,0,0,0,0];for(const q of group){assert.equal(q.choices.length,5);assert.equal(new Set(q.choices).size,5);n[q.answer-1]++;}assert.ok(n.every(k=>k===2),name+' '+n);}
 console.log('PASS',JSON.stringify({mode,total:qs.length,clusterBRemaining:0,finalFive:ids.length,uniqueStems:unique.size,remainingDuplicateClusters:duplicates}));
}
