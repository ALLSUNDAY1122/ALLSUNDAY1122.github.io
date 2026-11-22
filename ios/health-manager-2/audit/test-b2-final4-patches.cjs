#!/usr/bin/env node
'use strict';
/**
 * B2 final-four guarded-patch regression smoke test.
 *
 * Usage: node ios/health-manager-2/audit/test-b2-final4-patches.cjs
 *
 * Tests a question-level projection of the CURRENT distribution JSON against
 * the existing window.Q_PARTS patch code. This is NOT a canonical 300-question
 * generator test and does NOT approve publication.
 */
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../..');
const js=fs.readFileSync(path.join(root,'apps/sanitary-manager-2/hm2-source-precision-v1.js'),'utf8');
const bank=JSON.parse(fs.readFileSync(path.join(root,'ios/health-manager-2/release-questions.json'),'utf8'));
assert.equal(bank.length,300,'bank must contain 300 items');
const blocks=js.match(/\(function\(\)\{[\s\S]*?\}\)\(\);/g)||[];
const targets=[
 {id:'sm2-5y-r05-phy-04',choice:4,blocks:2,expected:'食後には肝臓からの糖放出が抑制される方向に働き、肝臓に取り込まれた余剰の糖はグリコーゲンとして貯蔵され得る。'},
 {id:'sm2-5y-r05-phy-06',choice:1,blocks:1,expected:'心臓が血液を送り出すときに生じる動脈の拍動を、手首で触知しているもの'},
 {id:'sm2-5y-r05-phy-08',choice:5,blocks:1,expected:'筋収縮により、安静時のインスリン作用とは別の仕組みでも筋のブドウ糖取り込みが増え得る。'},
 {id:'sm2-5y-r06-phy-08',choice:4,blocks:1,expected:'ミトコンドリアで酸素を利用し、ATP合成酵素がプロトンの流れのエネルギーを使ってATPを生成する。'}
];
function project(raw){
 return {id:raw.id,answer:raw.correct_index+1,sourceUrl:raw.source_url,question:raw.question,
 choices:[...raw.choices],quick:raw.quick,explanation:raw.explanation,basis:raw.primary_basis,
 topic:raw.topic,auditStatus:raw.audit_status,publicationStatus:raw.publication_status,
 lawRelated:raw.law_related,legalChecked:raw.legal_checked};
}
for(const target of targets){
 const raw=bank.find(q=>q.id===target.id);
 assert.ok(raw,'missing '+target.id);
 // No.131's preceding source patch also guards No.134; it must be in Q_PARTS.
 const scoped=[project(raw)];
 if(target.id==='sm2-5y-r05-phy-04')
  scoped.push(project(bank.find(q=>q.id==='sm2-5y-r05-phy-07')));
 const env={Q_PARTS:scoped};
 const relevant=blocks.filter(block=>block.includes(target.id));
 assert.equal(relevant.length,target.blocks,'expected source blocks '+target.id);
 for(const block of relevant)
  vm.runInNewContext(block,{window:env},{timeout:1000});
 const q=scoped[0];
 assert.equal(q.answer,target.choice,'answer index changed '+target.id);
 assert.equal(q.choices.length,5);
 assert.equal(new Set(q.choices).size,5);
 assert.equal(q.choices[target.choice-1],target.expected,'correct option '+target.id);
 assert.notEqual(q.sourceUrl,raw.source_url,'source did not change '+target.id);
 assert.equal(q.auditStatus,'再監査待ち');
 assert.equal(q.publicationStatus,'非公開');
 console.log('PASS '+target.id+' guarded blocks='+relevant.length+' answer='+target.choice+' status='+q.auditStatus);
}
console.log('PASS 4/4; this isolated smoke test does not establish canonical byte match or Q0/Q1.');
