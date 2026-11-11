#!/usr/bin/env node
'use strict';
const assert=require('assert/strict'),fs=require('fs'),path=require('path'),vm=require('vm');
const web=path.resolve(__dirname,'../apps/sanitary-manager-2');
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const overlays=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js'];
const target=[
'sm2-5y-r04-law-01','sm2-5y-r04-law-06','sm2-5y-r05-law-01','sm2-5y-r05-law-06',
'sm2-5y-r06-law-01','sm2-5y-r06-law-06','sm2-5y-r07-law-01','sm2-5y-r07-law-06',
'sm2-5y-r08-law-01','sm2-5y-r08-law-06','sm2-5y-r09-law-01','sm2-5y-r09-law-06',
'sm2-5y-r10-law-01','sm2-5y-r10-law-06'
];
const normal=s=>String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
for(const [mode,files] of [['browser',[...base,'difficulty-patch-v5.js',...overlays]],['release-export',[...base,...overlays]]]){
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const file of files)vm.runInContext(fs.readFileSync(path.join(web,file),'utf8'),ctx,{filename:file});
 const truth=new Map(ctx.window.Q_PARTS.filter(q=>target.includes(q.id)).map(q=>[q.id,q.choices[q.answer-1]]));
 vm.runInContext(fs.readFileSync(path.join(web,'question-order-v1.js'),'utf8'),ctx,{filename:'question-order-v1.js'});
 const qs=ctx.window.Q_PARTS;
 assert.equal(qs.length,300,mode+' count');
 assert.equal(new Set(qs.map(q=>q.id)).size,300,mode+' duplicate ID');
 const groups=new Map();
 for(const q of qs){const k=q.examSet+'|'+q.subject;groups.set(k,[...(groups.get(k)||[]),q]);}
 assert.equal(groups.size,30,mode+' groups');
 for(const [k,items] of groups){assert.equal(items.length,10,k);const pos=[0,0,0,0,0];for(const q of items){assert.equal(q.choices.length,5,q.id);assert.equal(new Set(q.choices).size,5,q.id);assert.ok(q.answer>=1&&q.answer<=5,q.id);pos[q.answer-1]++}assert.ok(pos.every(n=>n===2),k+' positions '+pos);}
 const seen=new Set();
 for(const id of target){const q=qs.find(x=>x.id===id);assert.ok(q,id);assert.equal(q.difficultyModel,'law-case-comparison-v2',id);assert.ok(q.answer>=1&&q.answer<=5,id);assert.equal(q.choices[q.answer-1],truth.get(id),id+' correct option moved by ordering');assert.equal(q.subject,'関係法令',id);assert.ok(q.question.length>28,id);assert.ok(q.choices[q.answer-1].length>2,id);assert.ok(q.explanation.length>=30,id);const key=normal(q.question);assert.ok(!seen.has(key),id+' duplicate redesign stem');seen.add(key)}
 assert.equal(seen.size,14);
 const clusters=new Map();for(const q of qs){const n=normal(q.question);clusters.set(n,(clusters.get(n)||0)+1)}
 const largest=Math.max(...clusters.values());
 const clusterCounts=[...clusters.values()].filter(n=>n>1).sort((a,b)=>b-a);
 if(mode==='browser'){assert.equal(largest,38,'largest remaining cluster');assert.equal(clusters.size,237,'first ten D law cases redesigned');assert.deepEqual(clusterCounts,[37,28]);}
 if(mode==='release-export'){assert.equal(clusters.size,300);}
 console.log('PASS',mode,JSON.stringify({questions:qs.length,uniqueStems:clusters.size,largest,clusterCounts,redesigned:seen.size}));
}
