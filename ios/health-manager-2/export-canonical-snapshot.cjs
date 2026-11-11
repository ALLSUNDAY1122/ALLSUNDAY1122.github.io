#!/usr/bin/env node
'use strict';
/* Canonical audit snapshot, NOT legal/medical release approval. */
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),web=path.join(root,'apps/sanitary-manager-2');
const base=Array.from({length:12},(_,i)=>'q'+(i+1)+'.js');
const patches=['audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js','question-order-v1.js'];
function load(includeDifficulty){
 const c=vm.createContext({window:{Q_PARTS:[]},localStorage:{getItem:()=>null,setItem:()=>{}}});
 for(const name of [...base,...(includeDifficulty?['difficulty-patch-v5.js']:[]),...patches])
  vm.runInContext(fs.readFileSync(path.join(web,name),'utf8'),c,{filename:name});
 return c.window.Q_PARTS;
}
const browser=load(true),release=load(false);
const {verifyCurrentLawContent}=require('./verify-current-law-contract.cjs');
verifyCurrentLawContent(browser);
const keys=['question','choices','answer','quick','explanation','topic','sourceUrl','baselineDate'];
const byId=new Map(release.map(q=>[q.id,q]));
const normalized=s=>String(s).replace(/[\\s\\p{P}\\p{S}]/gu,'').toLowerCase();
assert.equal(browser.length,300);assert.equal(release.length,300);
assert.equal(byId.size,300);assert.equal(new Set(browser.map(q=>q.id)).size,300);
assert.equal(new Set(browser.map(q=>normalized(q.question))).size,300);
const mismatch=[];
for(const q of browser){
 const r=byId.get(q.id);if(!r){mismatch.push(q.id+':missing');continue;}
 for(const key of keys)if(JSON.stringify(q[key])!==JSON.stringify(r[key]))mismatch.push(q.id+':'+key);
}
assert.deepEqual(mismatch,[],'BROWSER_RELEASE_DRIFT '+mismatch.join(','));
const sets=['令和8年4月','令和7年10月','令和7年4月','5年分相当｜第4回','5年分相当｜第5回','5年分相当｜第6回','5年分相当｜第7回','5年分相当｜第8回','5年分相当｜第9回','5年分相当｜第10回'];
const round=Object.fromEntries(sets.map((x,i)=>[x,i+1]));
const groups=new Map();
for(const q of browser){
 assert.ok(q.id&&q.question&&q.explanation&&q.sourceUrl,q.id);
 assert.ok(q.choices?.length===5&&new Set(q.choices).size===5,q.id);
 assert.ok(Number.isInteger(q.answer)&&q.answer>=1&&q.answer<=5,q.id);
 assert.ok(round[q.examSet]&&['関係法令','労働衛生','労働生理'].includes(q.subject),q.id);
 const k=q.examSet+'|'+q.subject;
 if(!groups.has(k))groups.set(k,[]);
 groups.get(k).push(q);
}
assert.equal(groups.size,30);
for(const [group,questions] of groups){
 assert.equal(questions.length,10,group);
 const count=[0,0,0,0,0];for(const q of questions)count[q.answer-1]++;
 assert.deepEqual(count,[2,2,2,2,2],group);
}
const data=browser.map(q=>({
 id:q.id,round:round[q.examSet],exam_set:q.examSet,subject:q.subject,topic:q.topic,
 question:q.question,choices:Array.from(q.choices),correct_index:q.answer-1,quick:q.quick,explanation:q.explanation,
 primary_basis:q.basis,source_url:q.sourceUrl,baseline_date:q.baselineDate,origin_type:q.originType,
 rights_basis:q.rightsBasis,law_related:Boolean(q.lawRelated),legal_checked:q.legalChecked||null,
 audit_status:q.auditStatus,publication_status:q.publicationStatus,difficulty_model:q.difficultyModel||null,
 no_common_sense_shortcut:Boolean(q.noCommonSenseShortcut)
}));
const out=path.join(__dirname,'release-questions.json');
const raw=JSON.stringify(data,null,2)+'\n';
fs.writeFileSync(out,raw);
const reread=JSON.parse(fs.readFileSync(out,'utf8'));assert.equal(reread.length,300);
for(let i=0;i<300;i++){assert.equal(reread[i].id,browser[i].id);assert.equal(reread[i].question,browser[i].question);assert.deepEqual(reread[i].choices,Array.from(browser[i].choices));assert.equal(reread[i].correct_index,browser[i].answer-1);}
console.log('PASS HM2_CANONICAL_JSON',JSON.stringify({total:data.length,uniqueStems:300,choiceDrift:0,correctAnswerDrift:0,groups:30,sha256:crypto.createHash('sha256').update(raw).digest('hex'),bytes:Buffer.byteLength(raw),path:out}));
console.log('NOTE: Snapshot is not an independent legal/medical content review or iOS device test.');
