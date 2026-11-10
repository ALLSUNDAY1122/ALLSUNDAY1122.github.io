#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),vm=require('vm');
const web=path.resolve(__dirname,'../apps/sanitary-manager-2');
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const overlays=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js','question-order-v1.js'];
function load(mode){
 const files=mode==='browser'?[...base,'difficulty-patch-v5.js',...overlays]:[...base,...overlays];
 const ctx=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const file of files)vm.runInContext(fs.readFileSync(path.join(web,file),'utf8'),ctx,{filename:file});
 return ctx.window.Q_PARTS;
}
function normalize(s){return String(s).replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase()}
function clusters(qs){const map=new Map();
 for(const q of qs){const n=normalize(q.question);if(!map.has(n))map.set(n,[]);map.get(n).push(q)}
 return [...map.values()].sort((a,b)=>b.length-a.length||a[0].question.localeCompare(b[0].question,'ja'));
}
const variants=[];
for(const mode of ['browser','release-export']){
 const qs=load(mode),rows=clusters(qs);
 variants.push({mode,qs});
 const dupe=rows.filter(x=>x.length>1),unique=rows.length;
 console.log('SUMMARY',JSON.stringify({mode,total:qs.length,unique,duplicateClusters:dupe.length,duplicateQuestions:dupe.reduce((n,x)=>n+x.length,0),surplus:qs.length-unique,sizeDistribution:Object.fromEntries([...new Set(dupe.map(x=>x.length))].sort((a,b)=>b-a).map(s=>[s,dupe.filter(x=>x.length===s).length]))}));
 dupe.forEach((row,i)=>{
  const subjects=Object.fromEntries([...new Set(row.map(q=>q.subject))].map(s=>[s,row.filter(q=>q.subject===s).length]));
  console.log('CLUSTER',JSON.stringify({mode,rank:i+1,size:row.length,stem:row[0].question,subjects,ids:row.map(q=>q.id)}));
 });
}

const [browser,release]=variants.map(v=>new Map(v.qs.map(q=>[q.id,q])));
const diff={question:[],choices:[],answer:[],explanation:[]};
for(const [id,bq] of browser){const rq=release.get(id);if(!rq)throw Error('release missing '+id);for(const field of Object.keys(diff)){if(JSON.stringify(bq[field])!==JSON.stringify(rq[field]))diff[field].push(id);}}
console.log('COMPARISON',JSON.stringify({questionCount:diff.question.length,choiceCount:diff.choices.length,answerCount:diff.answer.length,explanationCount:diff.explanation.length,sampleQuestionIds:diff.question.slice(0,10)}));
