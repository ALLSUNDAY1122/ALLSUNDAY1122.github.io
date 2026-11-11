'use strict';
const assert = require('assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const cp = require('child_process');
const ios = path.resolve(__dirname, '..'), repo = path.resolve(ios,'..','..');
const {applyContentOverrides} = require(path.join(ios,'apply-content-overrides.cjs'));
const entries = JSON.parse(fs.readFileSync(path.join(ios,'content-overrides-b-20261110.json'),'utf8'));
const targets = entries.map(e=>e.id).sort();
const dir = fs.mkdtempSync(path.join(os.tmpdir(),'hm1-b-revisions-'));
const fixtureIos = path.join(dir,'ios','health-manager-1');
fs.mkdirSync(path.join(fixtureIos,'Resources'),{recursive:true});
fs.mkdirSync(path.join(fixtureIos,'audit'),{recursive:true});
fs.mkdirSync(path.join(dir,'apps','sanitary-manager-2'),{recursive:true});
const baseText=fs.readFileSync(path.join(ios,'Resources','questions.json'),'utf8');
assert.equal(JSON.parse(baseText).length,132,'Canonical input must remain 132');
fs.writeFileSync(path.join(fixtureIos,'Resources','questions.json'),baseText);
for(const name of ['q1.js','q2.js','q3.js','q4.js','q5.js','q6.js','q7.js','q8.js','q9.js','q10.js','q11.js','q12.js','audit-patch-v2.js','audit-patch-v3.js','audit-patch-v4.js','audit-fixes.js','question-order-v1.js'])
  fs.copyFileSync(path.join(repo,'apps','sanitary-manager-2',name),path.join(dir,'apps','sanitary-manager-2',name));
for(const name of ['apply-content-overrides.cjs','content-overrides-b-20261110.json'])
  fs.copyFileSync(path.join(ios,name),path.join(fixtureIos,name));
const generator=fs.readFileSync(path.join(ios,'augment-to-264.cjs'),'utf8');
const call="const revisedIds = require('./apply-content-overrides.cjs').applyContentOverrides(added);";
assert.equal(generator.split(call).length,2,'Expected one HM1 revision hook');
const run = code=>{
  fs.writeFileSync(path.join(fixtureIos,'Resources','questions.json'),baseText);
  fs.writeFileSync(path.join(fixtureIos,'augment-to-264.cjs'),code);
  cp.execFileSync(process.execPath,[path.join(fixtureIos,'augment-to-264.cjs')],{stdio:'pipe',timeout:30000});
  return JSON.parse(fs.readFileSync(path.join(fixtureIos,'Resources','questions.json'),'utf8'));
};
const before=run(generator.replace(call,'const revisedIds = [];'));
const after=run(generator);
const again=run(generator);
assert.deepEqual(after,again,'Deterministic regeneration');
assert.equal(after.length,264);
assert.equal(new Set(after.map(q=>q.id)).size,264);
for(const round of ['2026-04','2025-10','2025-04','practice-A','practice-B','practice-C'])
  assert.equal(after.filter(q=>q.round===round).length,44);
const changed=after.filter((q,i)=>JSON.stringify(q)!==JSON.stringify(before[i])).map(q=>q.id).sort();
assert.deepEqual(changed,targets,'Only registered override rows may change');
assert.deepEqual(after.filter(q=>q.round!=='practice-B'),before.filter(q=>q.round!=='practice-B'),'Base/A/C unchanged');
for(const q of after){
  assert.equal(q.choices.length,5);
  assert(q.ans>=0&&q.ans<5);
  assert.equal(new Set(q.choices).size,5);
}
assert.equal(new Set(after.map(q=>q.stem.normalize('NFKC').replace(/[\s\p{P}\p{S}]/gu,'')) ).size,264);
const renal=after.find(q=>q.id==='practice-B-Q43');
assert.equal(renal.choices[renal.ans],'輸入細動脈 → 糸球体 → 輸出細動脈');
assert(!renal.choices.includes('腎臓')&&!renal.choices.includes('ネフロン'),'Remove nested answers');
const clone=x=>JSON.parse(JSON.stringify(x));
const input=before.filter(q=>q.round.startsWith('practice-'));
for(const corrupt of [
  e=>{e[6].expectedConceptKey+='-drift';},
  e=>{e[6].expectedStem+='-drift';},
  e=>{e[1]=clone(e[0]);},
  e=>{e[6].replacement.id='other';},
  e=>{e[6].replacement.ans=5;}
]){
  const qs=clone(input), snapshot=clone(qs), e=clone(entries); corrupt(e);
  assert.throws(()=>applyContentOverrides(qs,e));
  assert.deepEqual(qs,snapshot,'Rejected batch must not partially mutate');
}
assert.throws(()=>applyContentOverrides(input.filter(q=>q.id!=='practice-B-Q43'),entries));
const compact=JSON.stringify(after);
assert(!compact.toLowerCase().includes('</script>'));
const index=fs.readFileSync(path.join(ios,'Resources','index.html'),'utf8');
const re=/const QUESTIONS=\[.*?\];\nconst DOMAINS=/s;
assert(re.test(index),'Existing bundle embed marker');
const materialized=index.replace(re,'const QUESTIONS='+compact+';\nconst DOMAINS=');
const embedded=JSON.parse(materialized.match(/const QUESTIONS=(\[.*?\]);\nconst DOMAINS=/s)[1]);
assert.deepEqual(embedded,after,'Release embedding preserves revisions');
console.log(JSON.stringify({pass:true,total:264,changed,unchanged:227,deterministic:true,driftRejected:true,bundleRoundtrip:true,fixture:dir},null,2));
